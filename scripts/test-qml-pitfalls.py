#!/usr/bin/env python3
"""QML that parses and then fails to load its whole component.

A component that fails to load takes down every surface built on it, and the only trace is one
warning in the log. Each check below was confirmed to fail on the Qt 6.9 floor and on Qt 6.11. The scan reads one
declaration per line, as this codebase is formatted:

- Two handlers for the same signal in one object ("Property value set multiple times").
- `Behavior on` a readonly property of the same object ("Invalid property assignment").
- `component X: …` inside another inline component ("Nested inline components are not supported").
- A JS method named `escape` ("Illegal method name").
- A property of a visual object named like a FINAL member of `Item` (`top`, `left`, `width`, `visible`…:
  "Cannot override FINAL property"). The list is QQuickItem's `isFinal` set in Qt's qmltypes.

And three that load but misbehave: `Connections { target: Hyprland }` is evaluated even when the
Connections is disabled, so it connects to the Hyprland socket on Niri; `Notifications.notify(…)` emits the
arrived-notification signal and shows nothing (post with `Notifications.send`); a child of a `ClippingRectangle`
sits in its content item, a plain Item, so `parent.radius`, `parent.color` or `parent.border` there read undefined
(name the rectangle by its id); a `StyledToolTip`/`PopupToolTip` inside an object with no `hovered` (a Rectangle,
Item, icon or text) takes its parent's hover as always true and floats on screen for as long as it exists.
"""

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STRING_OR_COMMENT = re.compile(r'"(?:[^"\\\n]|\\.)*"|\'(?:[^\'\\\n]|\\.)*\'|`(?:[^`\\]|\\.)*`|//[^\n]*|/\*.*?\*/', re.S)
OBJECT_OPEN = re.compile(r"(?:^|[\s;:])(?:component\s+\w+\s*:\s*)?([A-Z][\w.]*)\s*\{\s*$")
ITEM_FINAL = set("parent x y z width height opacity visible childrenRect anchors left right horizontalCenter top "
                 "bottom verticalCenter baseline focus activeFocus activeFocusOnTab transform layer".split())
NOT_ITEM = re.compile(r"^(?:\w*Window|WlSessionLock\w*|QtObject|Scope|Singleton|ShellRoot|Variants|Connections|Timer|Binding|Process|"
                      r"\w*Handler|\w*Animation|Behavior|State|Transition|PropertyChanges|FileView|JsonAdapter|"
                      r"JsonObject|Region|LazyLoader|Loader|Repeater|Instantiator|ListModel|ListElement|ScriptModel|"
                      r"FrameAnimation|IpcHandler|Shortcut|GlobalShortcut|StdioCollector|SplitParser|\w*Model|\w*Proxy)$")
PROPERTY = re.compile(r"\bproperty\s+[\w.<>]+\s+(\w+)\b")
HANDLER = re.compile(r"^\s*(on[A-Z]\w*)\s*:")
READONLY = re.compile(r"\breadonly\s+property\s+[\w.<>]+\s+(\w+)")
BEHAVIOR = re.compile(r"\bBehavior\s+on\s+(\w+)\s*\{")
COMPONENT = re.compile(r"^\s*component\s+(\w+)\s*:")
ESCAPE_METHOD = re.compile(r"\bfunction\s+escape\s*\(")
HYPRLAND_TARGET = re.compile(r"^\s*target\s*:\s*Hyprland\w*\s*$")
NOTIFY_CALL = re.compile(r"\bNotifications\.notify\s*\(")
CLIP_PARENT = re.compile(r"(?<!\.)\bparent\.(radius|color|border)\b")
TOOLTIP = re.compile(r"\b(?:StyledToolTip|PopupToolTip)\s*\{")
NO_HOVER = {"Rectangle", "Item", "MaterialSymbol", "StyledText", "Text", "Row", "Column", "RowLayout", "ColumnLayout",
            "Image", "StyledImage", "Shape", "Flow", "GridLayout"}
ONE_LINE_OBJECT = re.compile(r"^\s*[A-Z][\w.]*\s*\{.*\}\s*$")


def blank(text: str) -> str:
    """Strings and comments replaced by spaces, so braces and words inside them don't count."""
    return STRING_OR_COMMENT.sub(lambda m: re.sub(r"[^\n]", " ", m.group(0)), text)


def tooltip_gated(lines: list, start: int) -> bool:
    """Whether the tooltip block opening on lines[start] sets its own visibility."""
    depth, body = 0, []
    for line in lines[start:start + 40]:
        body.append(line)
        depth += line.count("{") - line.count("}")
        if depth <= 0:
            break
    return bool(re.search(r"\b(?:extraVisibleCondition|alternativeVisibleCondition|visible)\s*:", "\n".join(body)))


def scan(rel: str, text: str) -> list:
    out = []
    # Open blocks: an object block holds its handlers, readonly properties and whether it is an inline component's body;
    # JS blocks are None, so a handler-like key inside a JS object literal does not count.
    stack = []
    lines = blank(text).splitlines()
    for number, line in enumerate(lines, 1):
        obj = stack[-1] if stack and stack[-1] is not None else None
        handler = HANDLER.match(line)
        if handler and obj is not None:
            first = obj["handlers"].setdefault(handler.group(1), number)
            if first != number:
                out.append(f"{rel}:{number}: second `{handler.group(1)}` handler in one object (first at line "
                           f"{first}): the component fails to load")
        if obj is not None:
            obj["readonly"].update(READONLY.findall(line))
            obj["props"].update(PROPERTY.findall(line))
            if obj["item"]:
                for name in PROPERTY.findall(line):
                    if name in ITEM_FINAL:
                        out.append(f"{rel}:{number}: property `{name}` overrides a FINAL member of Item: the component "
                                   "fails to load")
        component = COMPONENT.match(line)
        if component and any(b is not None and b["component"] for b in stack):
            out.append(f"{rel}:{number}: inline component `{component.group(1)}` inside another inline "
                       "component fails to load; declare it at file level")
        for match in BEHAVIOR.finditer(line):
            if obj is not None and match.group(1) in obj["readonly"]:
                out.append(f"{rel}:{number}: `Behavior on {match.group(1)}`, a readonly property of this object: "
                           "the component fails to load")
        if ESCAPE_METHOD.search(line):
            out.append(f"{rel}:{number}: method named `escape` (a JS global): the component fails to load")
        if HYPRLAND_TARGET.match(line):
            out.append(f"{rel}:{number}: `target: Hyprland` connects on Niri too; use "
                       "`target: CompositorService.isHyprland ? Hyprland : null`")
        if NOTIFY_CALL.search(line):
            out.append(f"{rel}:{number}: `Notifications.notify(…)` only emits a signal and shows nothing; "
                       "use `Notifications.send(summary, body, urgency, timeoutMs)`")
        if obj is not None and CLIP_PARENT.search(line):
            one_line = bool(ONE_LINE_OBJECT.match(line))
            if (one_line and obj["kind"] == "ClippingRectangle") or (not one_line and obj["parent"] == "ClippingRectangle"):
                out.append(f"{rel}:{number}: `parent.{CLIP_PARENT.search(line).group(1)}` in a child of a ClippingRectangle "
                           "reads its content item (undefined): name the rectangle by its id")
        if obj is not None and TOOLTIP.search(line) and not component and obj["kind"] in NO_HOVER \
                and not obj["props"] & {"hovered", "buttonHovered"} and not tooltip_gated(lines, number - 1):
            out.append(f"{rel}:{number}: tooltip inside a {obj['kind']}, which has no `hovered`: it shows all the time; "
                       "put it in the hoverable control (a button, a MouseArea's parent with `hovered`) or drop it")
        opens, closes = line.count("{"), line.count("}")
        opened = OBJECT_OPEN.search(line) if opens == 1 and closes == 0 else None
        if opened:
            kind = opened.group(1).split(".")[-1]
            stack.append({"handlers": {}, "readonly": set(), "props": set(), "component": bool(component),
                          "item": not NOT_ITEM.match(kind), "kind": kind, "parent": obj["kind"] if obj else ""})
        else:
            stack.extend([None] * max(0, opens - closes))
            del stack[len(stack) - min(len(stack), max(0, closes - opens)):]
    return out


def main() -> int:
    listed = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard", "*.qml"], cwd=ROOT, capture_output=True, text=True)
    files = listed.stdout.split() if listed.returncode == 0 and listed.stdout.strip() \
        else [str(p.relative_to(ROOT)) for p in ROOT.rglob("*.qml") if ".git" not in p.parts]
    failures = []
    for rel in files:
        path = ROOT / rel
        if path.is_file():
            failures += scan(rel, path.read_text(encoding="utf-8", errors="replace"))
    if failures:
        print("QML that parses and then fails to load its component:")
        for failure in failures:
            print(f"  {failure}")
        return 1
    print(f"QML pitfalls: {len(files)} files load past the checks")
    return 0


if __name__ == "__main__":
    sys.exit(main())
