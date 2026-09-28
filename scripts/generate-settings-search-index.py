#!/usr/bin/env python3
from __future__ import annotations

import ast
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "modules/settings/SettingsPageRegistry.qml"
OUTPUT = ROOT / "modules/settings/settings-search-index.generated.json"

PAGE_RE = re.compile(r'component:\s*"(modules/settings/[^"]+\.qml)"')
TR_RE = re.compile(r'Translation\.tr\(("(?:\\.|[^"\\])*")\)')
OBJECT_RE = re.compile(r'^\s*([A-Za-z_][A-Za-z0-9_.]*)\s*\{')
TASK_RE = re.compile(r'activeSection\s*===\s*"([^"]+)"')
SECTION_TASK_RE = re.compile(r'settingsTaskSection\s*:\s*"([^"]+)"')
PROPERTY_RE = re.compile(r'^\s*(title|text|placeholderText|mainText|displayName|label|settingsSearchLabel|description)\s*:')
SOURCE_RE = re.compile(r'^\s*source\s*:\s*"([^"]+\.qml)"')

TITLE_TYPES = {
    "SettingsCardSection", "CollapsibleSection", "ContentSection", "ContentSubsection",
    "SettingsTaskNavigator", "PagePlaceholder", "WindowDialogSectionHeader"
}
SECTION_TYPES = {"SettingsCardSection", "CollapsibleSection", "ContentSection", "ContentSubsection"}
TEXT_TYPES = {
    "SettingsSwitch", "ConfigSwitch", "ConfigSpinBox", "ContentSubsectionLabel",
    "SettingsNote", "NoticeBox", "RippleButtonWithIcon", "DialogButton",
    "MaterialTextField", "MaterialTextArea", "StyledComboBox"
}
BUTTON_TYPES = {"RippleButtonWithIcon", "DialogButton"}
FIELD_TYPES = {"MaterialTextField", "MaterialTextArea"}


def decode_literal(token: str) -> str:
    try:
        return ast.literal_eval(token)
    except Exception:
        return ""


def brace_delta(line: str) -> int:
    # Good enough for iNiR QML: ignore braces inside quoted strings and line comments.
    clean = re.sub(r'//.*$', '', line)
    clean = re.sub(r'"(?:\\.|[^"\\])*"', '""', clean)
    return clean.count('{') - clean.count('}')


def page_paths() -> list[str]:
    text = REGISTRY.read_text(encoding="utf-8")
    return PAGE_RE.findall(text)


def task_ranges(lines: list[str]) -> list[tuple[int, int, str]]:
    ranges: list[tuple[int, int, str]] = []
    stack: list[tuple[int, str | None]] = []
    depth = 0
    pending_loader: tuple[int, int, str | None] | None = None

    for index, line in enumerate(lines):
        stripped = line.strip()
        if re.search(r'\bSettingsTaskLoader\s*\{', stripped):
            pending_loader = (index, depth, None)

        if pending_loader is not None:
            match = TASK_RE.search(line)
            if match and pending_loader[2] is None:
                pending_loader = (pending_loader[0], pending_loader[1], match.group(1))

        before = depth
        depth += brace_delta(line)

        if pending_loader is not None and depth <= pending_loader[1] and index > pending_loader[0]:
            start, _, task = pending_loader
            if task:
                ranges.append((start, index, task))
            pending_loader = None

    return ranges


def task_for_line(index: int, ranges: list[tuple[int, int, str]]) -> str:
    for start, end, task in ranges:
        if start <= index <= end:
            return task
    return ""


def family_ranges(lines: list[str]) -> list[tuple[int, int, str]]:
    ranges: list[tuple[int, int, str]] = []
    depth = 0
    pending_loader: tuple[int, int, str] | None = None

    for index, line in enumerate(lines):
        if re.search(r'\b(?:SettingsTaskLoader|LazySection)\s*\{', line):
            pending_loader = (index, depth, "")

        if pending_loader is not None and "requested:" in line:
            family = ""
            if re.search(r'!\s*[A-Za-z0-9_.]+\.isWaffle\b|\bisIiActive\b|panelFamily[^\n]*!==?\s*"waffle"', line):
                family = "ii"
            elif re.search(r'\bisWaffle(?:Active)?\b|panelFamily[^\n]*===?\s*"waffle"', line):
                family = "waffle"
            pending_loader = (pending_loader[0], pending_loader[1], family)

        depth += brace_delta(line)
        if pending_loader is not None and depth <= pending_loader[1] and index > pending_loader[0]:
            start, _, family = pending_loader
            if family:
                ranges.append((start, index, family))
            pending_loader = None

    return ranges


def family_for_line(index: int, ranges: list[tuple[int, int, str]]) -> str:
    for start, end, family in ranges:
        if start <= index <= end:
            return family
    return ""


def section_ranges(lines: list[str]) -> list[tuple[int, int, str, str]]:
    ranges: list[tuple[int, int, str, str]] = []
    depth = 0
    active: list[dict[str, int | str]] = []

    for index, line in enumerate(lines):
        object_match = OBJECT_RE.match(line)
        if object_match:
            object_type = object_match.group(1).split('.')[-1]
            if object_type in SECTION_TYPES:
                active.append({"start": index, "depth": depth, "title": "", "task": ""})

        if active:
            if not active[-1]["title"]:
                prop_match = PROPERTY_RE.match(line)
                tr_match = TR_RE.search(line)
                if prop_match and prop_match.group(1) == "title" and tr_match:
                    active[-1]["title"] = decode_literal(tr_match.group(1)).strip()
            if not active[-1]["task"]:
                task_match = SECTION_TASK_RE.search(line)
                if task_match:
                    active[-1]["task"] = task_match.group(1)

        depth += brace_delta(line)
        while active and depth <= int(active[-1]["depth"]) and index > int(active[-1]["start"]):
            item = active.pop()
            title = str(item["title"])
            if title:
                ranges.append((int(item["start"]), index, title, str(item["task"])))

    return ranges


def section_for_line(index: int, ranges: list[tuple[int, int, str, str]]) -> str:
    matches = [(start, title) for start, end, title, _ in ranges if start <= index <= end]
    if not matches:
        return ""
    matches.sort(key=lambda item: item[0], reverse=True)
    return matches[0][1]


def section_task_for_line(index: int, ranges: list[tuple[int, int, str, str]]) -> str:
    matches = [(start, task) for start, end, _, task in ranges if start <= index <= end and task]
    if not matches:
        return ""
    matches.sort(key=lambda item: item[0], reverse=True)
    return matches[0][1]


def component_ranges(lines: list[str]) -> list[tuple[int, int, str]]:
    ranges: list[tuple[int, int, str]] = []
    declaration = re.compile(r'^\s*component\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*[^\{]+\{')
    for start, line in enumerate(lines):
        match = declaration.match(line)
        if not match:
            continue
        local_depth = brace_delta(line)
        end = start
        while local_depth > 0 and end + 1 < len(lines):
            end += 1
            local_depth += brace_delta(lines[end])
        ranges.append((start, end, match.group(1)))
    return ranges


def component_tasks(lines: list[str], sections: list[tuple[int, int, str, str]],
                    loader_ranges: list[tuple[int, int, str]],
                    components: list[tuple[int, int, str]]) -> dict[str, list[str]]:
    out: dict[str, list[str]] = {}
    for start, end, name in components:
        usage = re.compile(r'^\s*' + re.escape(name) + r'\s*\{')
        tasks: list[str] = []
        for index, line in enumerate(lines):
            if start <= index <= end or not usage.match(line):
                continue
            task = section_task_for_line(index, sections) or task_for_line(index, loader_ranges)
            if task and task not in tasks:
                tasks.append(task)
        out[name] = tasks
    return out


def component_families(lines: list[str], families: list[tuple[int, int, str]],
                       components: list[tuple[int, int, str]]) -> dict[str, list[str]]:
    out: dict[str, list[str]] = {}
    for start, end, name in components:
        usage = re.compile(r'^\s*' + re.escape(name) + r'\s*\{')
        values: list[str] = []
        for index, line in enumerate(lines):
            if start <= index <= end or not usage.match(line):
                continue
            family = family_for_line(index, families)
            if family and family not in values:
                values.append(family)
        out[name] = values
    return out


def component_tasks_for_line(index: int, components: list[tuple[int, int, str]],
                             tasks_by_component: dict[str, list[str]]) -> list[str]:
    for start, end, name in components:
        if start <= index <= end:
            return tasks_by_component.get(name, [])
    return []


def component_families_for_line(index: int, components: list[tuple[int, int, str]],
                                families_by_component: dict[str, list[str]]) -> list[str]:
    for start, end, name in components:
        if start <= index <= end:
            return families_by_component.get(name, [])
    return []


def direct_description(lines: list[str], object_start: int) -> str:
    local_depth = 1
    for line in lines[object_start + 1:]:
        if local_depth == 1:
            prop_match = PROPERTY_RE.match(line)
            tr_match = TR_RE.search(line)
            if prop_match and prop_match.group(1) == "description" and tr_match:
                return decode_literal(tr_match.group(1)).strip()
        local_depth += brace_delta(line)
        if local_depth <= 0:
            break
    return ""


def extract_entries(path: Path, page_index: int, forced_task: str = "", forced_section: str = "",
                    forced_family: str = "",
                    visited: set[Path] | None = None) -> list[dict[str, str | int]]:
    if visited is None:
        visited = set()
    resolved_path = path.resolve()
    if resolved_path in visited:
        return []
    visited.add(resolved_path)
    lines = path.read_text(encoding="utf-8").splitlines()
    ranges = task_ranges(lines)
    families = family_ranges(lines)
    sections = section_ranges(lines)
    components = component_ranges(lines)
    tasks_by_component = component_tasks(lines, sections, ranges, components)
    families_by_component = component_families(lines, families, components)
    entries: list[dict[str, str | int]] = []
    context_by_section: dict[tuple[str, str], list[str]] = {}
    object_stack: list[tuple[str, int, int]] = []
    depth = 0

    for index, line in enumerate(lines):
        while object_stack and depth < object_stack[-1][1]:
            object_stack.pop()

        object_match = OBJECT_RE.match(line)
        if object_match:
            object_type = object_match.group(1).split('.')[-1]
            object_stack.append((object_type, depth + 1, index))

        prop_match = PROPERTY_RE.match(line)
        tr_match = TR_RE.search(line)
        if prop_match and tr_match:
            prop = prop_match.group(1)
            value = decode_literal(tr_match.group(1)).strip()
            object_type = object_stack[-1][0] if object_stack else ""
            object_start = object_stack[-1][2] if object_stack else index
            line_task = section_task_for_line(index, sections) or task_for_line(index, ranges) or forced_task
            line_section = section_for_line(index, sections) or forced_section
            line_family = family_for_line(index, families) or forced_family
            if line_section and 2 < len(value) <= 240:
                key = (line_task, line_section)
                bucket = context_by_section.setdefault(key, [])
                if value not in bucket:
                    bucket.append(value)
            searchable = (
                prop == "title"
                or prop == "label"
                or prop == "settingsSearchLabel"
                or (prop == "text" and object_type in TEXT_TYPES)
                or (prop == "mainText" and object_type in BUTTON_TYPES)
                or (prop == "placeholderText" and object_type in FIELD_TYPES)
                or prop == "displayName"
            )
            informative = any(ch.isalnum() for ch in value)
            if searchable and informative and 2 < len(value) <= 120:
                task = line_task
                section = line_section
                description = direct_description(lines, object_start)
                tasks = [task] if task else component_tasks_for_line(index, components, tasks_by_component)
                if not tasks:
                    tasks = [""]
                component_family_values = component_families_for_line(index, components, families_by_component)
                resolved_family = line_family or (component_family_values[0] if len(component_family_values) == 1 else "")
                for resolved_task in tasks:
                    entries.append({
                        "pageIndex": page_index,
                        "task": resolved_task,
                        "section": section,
                        "label": value,
                        "description": description,
                        "kind": prop,
                        "panelFamily": resolved_family,
                    })

        depth += brace_delta(line)

    for entry in entries:
        section = str(entry["section"])
        if section and str(entry["label"]).casefold() == section.casefold():
            entry["context"] = context_by_section.get((str(entry["task"]), section), [])

    for index, line in enumerate(lines):
        source_match = SOURCE_RE.match(line)
        if not source_match:
            continue
        child = path.parent / source_match.group(1)
        if not child.exists():
            continue
        child_task = section_task_for_line(index, sections) or task_for_line(index, ranges) or forced_task
        child_section = section_for_line(index, sections) or forced_section
        child_family = family_for_line(index, families) or forced_family
        entries.extend(extract_entries(child, page_index, child_task, child_section, child_family, visited))

    return entries


def dedupe(entries: list[dict[str, str | int]]) -> list[dict[str, str | int]]:
    seen: set[tuple[int, str, str, str, str]] = set()
    out: list[dict[str, str | int]] = []
    for entry in entries:
        key = (
            int(entry["pageIndex"]),
            str(entry["task"]),
            str(entry["section"]),
            str(entry["label"]).casefold(),
            str(entry.get("panelFamily", "")),
        )
        if key in seen:
            continue
        seen.add(key)
        out.append(entry)
    return out


def render(entries: list[dict[str, str | int]]) -> str:
    data = []
    for entry in entries:
        task = str(entry["task"])
        section = str(entry["section"])
        description = str(entry.get("description", ""))
        context = [str(value) for value in entry.get("context", [])]
        data.append({
            "pageIndex": int(entry["pageIndex"]),
            "task": task,
            "section": section,
            "label": str(entry["label"]),
            "keywords": [value for value in (task, section, description, *context) if value],
            "panelFamily": str(entry.get("panelFamily", "")),
        })
    return json.dumps(data, ensure_ascii=False, separators=(",", ":")) + "\n"


def main() -> None:
    all_entries: list[dict[str, str | int]] = []
    for page_index, relative in enumerate(page_paths()):
        path = ROOT / relative
        if path.exists():
            all_entries.extend(extract_entries(path, page_index))
    entries = dedupe(all_entries)
    OUTPUT.write_text(render(entries), encoding="utf-8")
    print(f"generated {len(entries)} entries -> {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
