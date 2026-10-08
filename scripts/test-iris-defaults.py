#!/usr/bin/env python3
"""iRiS defaults guard.

An iRiS option has three copies of its default: the schema in
modules/common/Config.qml, the fresh-install value in defaults/config.json and
the `fallback` of its row in modules/iris/settings/IrisOptions.qml (what
Settings' *Restore defaults* writes). This guard fails when they disagree or
when an `iris.*` schema key is missing from defaults/config.json.
"""

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CONFIG = ROOT / "modules" / "common" / "Config.qml"
DEFAULTS = ROOT / "defaults" / "config.json"
OPTIONS = ROOT / "modules" / "iris" / "settings" / "IrisOptions.qml"

TOKEN = re.compile(
    r"property JsonObject (\w+): JsonObject \{"
    r"|property [\w<>]+ (\w+): ([^;{}]+?)\s*(?=;|$|\})"
    r"|(\})"
)


def literal(text):
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return text


def iris_schema():
    lines = CONFIG.read_text(encoding="utf-8").splitlines()
    start = next(i for i, line in enumerate(lines) if "property JsonObject iris: JsonObject {" in line)
    schema, stack = {}, []
    for line in lines[start:]:
        code = line.split("//")[0]
        for match in TOKEN.finditer(code):
            if match.group(1):
                stack.append(match.group(1))
            elif match.group(2):
                schema[".".join(stack[1:] + [match.group(2)])] = literal(match.group(3).strip())
            elif match.group(4):
                stack.pop()
        if not stack:
            return schema
    raise SystemExit("iris schema block not closed in Config.qml")


def lookup(tree, path):
    node = tree
    for key in path.split("."):
        if not isinstance(node, dict) or key not in node:
            return KeyError
        node = node[key]
    return node


def main():
    schema = iris_schema()
    defaults = json.loads(DEFAULTS.read_text(encoding="utf-8"))["iris"]
    failures = []

    for path, value in schema.items():
        fresh = lookup(defaults, path)
        if fresh is KeyError:
            failures.append(f"defaults/config.json lacks iris.{path} (schema {value!r})")
        elif fresh != value:
            failures.append(f"iris.{path}: schema {value!r} but defaults/config.json {fresh!r}")

    rows = re.finditer(
        r'path: "iris\.([\w.]+)"(?: \+ side \+ "([\w.]+)")?([^\n]*?)fallback: ?(\[[^\]]*\]|"[^"]*"|[\w.\-]+)',
        OPTIONS.read_text(encoding="utf-8"),
    )
    for row in rows:
        # An icon row is keyed by its piece inside one shared list, so its fallback is
        # the empty per-piece choice, not the list the path holds.
        if 'kind: "icon"' in row.group(3):
            continue
        fallback = literal(row.group(4))
        paths = [row.group(1) + side + row.group(2) for side in ("left", "right")] if row.group(2) else [row.group(1)]
        for path in paths:
            if path not in schema:
                failures.append(f"IrisOptions row iris.{path} has no schema key")
            elif schema[path] != fallback:
                failures.append(f"iris.{path}: schema {schema[path]!r} but IrisOptions fallback {fallback!r}")

    if failures:
        print("iRiS defaults out of sync:")
        for failure in failures:
            print(f"  {failure}")
        return 1
    print(f"iRiS defaults: {len(schema)} schema keys in sync")
    return 0


if __name__ == "__main__":
    sys.exit(main())
