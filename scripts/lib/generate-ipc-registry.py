#!/usr/bin/env python3
"""Generate scripts/lib/ipc-registry.sh from QML IpcHandler declarations + docs/IPC.md metadata.

QML is the ground truth for targets and functions.
IPC.md enriches with descriptions, keybind examples, and family scope.

Usage:
    python3 scripts/lib/generate-ipc-registry.py           # generate
    python3 scripts/lib/generate-ipc-registry.py --check    # check if output is stale
"""

import hashlib
import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
QML_DIRS = [
    REPO_ROOT / "modules",
    REPO_ROOT / "services",
    REPO_ROOT / "GlobalStates.qml",
    REPO_ROOT / "shell.qml",
]
IPC_MD = REPO_ROOT / "docs" / "IPC.md"
OUTPUT = REPO_ROOT / "scripts" / "lib" / "ipc-registry.sh"

# Targets under this IPC.md heading are waffle-only.
WAFFLE_SECTION_HEADING = "## Waffle-Specific Targets"

# Known waffle-only QML paths (for family detection from QML when IPC.md has no entry).
WAFFLE_PATH_MARKERS = ("modules/waffle/",)

# Known duplicate targets (both families register the same target name).
# LazyLoader prevents both from loading at runtime.
KNOWN_DUPLICATES = {"bar", "session", "clipboard"}


@dataclass
class IpcFunction:
    name: str
    args: list[str] = field(default_factory=list)  # param names
    description: str = ""


@dataclass
class IpcTarget:
    name: str
    functions: list[IpcFunction] = field(default_factory=list)
    description: str = ""
    family: str = "shared"  # shared | ii | waffle
    keybind_example: str = ""
    qml_file: str = ""

    def function_names(self) -> list[str]:
        return [f.name for f in self.functions]


# ---------------------------------------------------------------------------
# QML scanner
# ---------------------------------------------------------------------------

_RE_IPC_HANDLER = re.compile(r"IpcHandler\s*\{")
_RE_TARGET = re.compile(r'target\s*:\s*"([^"]+)"')
_RE_FUNCTION = re.compile(r"function\s+(\w+)\s*\(([^)]*)\)")
_RE_CLOSING_BRACE = re.compile(r"^\s*\}")


def _scan_qml_file(path: Path) -> list[IpcTarget]:
    """Extract IpcHandler blocks from a single QML file."""
    text = path.read_text(errors="replace")
    lines = text.splitlines()
    targets: list[IpcTarget] = []

    i = 0
    while i < len(lines):
        if _RE_IPC_HANDLER.search(lines[i]):
            target_name = None
            functions: list[IpcFunction] = []
            brace_depth = 0
            # Count braces from the opening line
            for ch in lines[i]:
                if ch == "{":
                    brace_depth += 1
                elif ch == "}":
                    brace_depth -= 1
            j = i + 1
            while j < len(lines) and brace_depth > 0:
                line = lines[j]
                for ch in line:
                    if ch == "{":
                        brace_depth += 1
                    elif ch == "}":
                        brace_depth -= 1
                        if brace_depth == 0:
                            break

                m = _RE_TARGET.search(line)
                if m:
                    target_name = m.group(1)

                m = _RE_FUNCTION.search(line)
                if m and brace_depth >= 1:
                    fname = m.group(1)
                    raw_args = m.group(2).strip()
                    args = []
                    if raw_args:
                        for part in raw_args.split(","):
                            part = part.strip()
                            # QML style: "name: type" or just "name"
                            arg_name = part.split(":")[0].strip()
                            if arg_name:
                                args.append(arg_name)
                    functions.append(IpcFunction(name=fname, args=args))

                j += 1

            if target_name:
                rel = str(path.relative_to(REPO_ROOT))
                targets.append(
                    IpcTarget(name=target_name, functions=functions, qml_file=rel)
                )
            i = j
        else:
            i += 1

    return targets


def scan_qml() -> dict[str, IpcTarget]:
    """Scan all QML files for IpcHandler declarations."""
    all_targets: dict[str, IpcTarget] = {}

    paths: list[Path] = []
    for entry in QML_DIRS:
        if entry.is_file():
            paths.append(entry)
        elif entry.is_dir():
            paths.extend(entry.rglob("*.qml"))

    for path in sorted(paths):
        for target in _scan_qml_file(path):
            if target.name in all_targets:
                if target.name in KNOWN_DUPLICATES:
                    # Merge functions from duplicate registrations.
                    existing = all_targets[target.name]
                    existing_names = set(existing.function_names())
                    for fn in target.functions:
                        if fn.name not in existing_names:
                            existing.functions.append(fn)
                else:
                    print(
                        f"WARNING: duplicate IPC target '{target.name}' "
                        f"in {target.qml_file} (first: {all_targets[target.name].qml_file})",
                        file=sys.stderr,
                    )
            else:
                all_targets[target.name] = target

    return all_targets


# ---------------------------------------------------------------------------
# IPC.md parser
# ---------------------------------------------------------------------------


@dataclass
class IpcMdEntry:
    name: str
    description: str = ""
    functions: dict[str, str] = field(default_factory=dict)  # name -> desc
    keybind_example: str = ""
    is_waffle: bool = False


def parse_ipc_md() -> dict[str, IpcMdEntry]:
    """Parse docs/IPC.md for target metadata."""
    if not IPC_MD.exists():
        print(
            f"WARNING: {IPC_MD} not found, skipping metadata enrichment",
            file=sys.stderr,
        )
        return {}

    text = IPC_MD.read_text(errors="replace")
    lines = text.splitlines()
    entries: dict[str, IpcMdEntry] = {}

    current: IpcMdEntry | None = None
    in_waffle_section = False
    in_table = False
    in_code_fence = False
    code_fence_lang = ""
    code_block_lines: list[str] = []
    desc_lines: list[str] = []
    collecting_desc = False

    for line in lines:
        stripped = line.strip()

        # Track waffle section
        if stripped == WAFFLE_SECTION_HEADING:
            in_waffle_section = True
            continue

        # Track code fences
        if stripped.startswith("```"):
            if in_code_fence:
                # Closing fence
                if current and code_fence_lang == "kdl":
                    current.keybind_example = "\n".join(code_block_lines).strip()
                in_code_fence = False
                code_fence_lang = ""
                code_block_lines = []
            else:
                # Opening fence
                in_code_fence = True
                code_fence_lang = (
                    stripped[3:].strip().split()[0] if len(stripped) > 3 else ""
                )
                code_block_lines = []
            continue

        if in_code_fence:
            code_block_lines.append(line)
            continue

        # New h3 target heading
        m = re.match(r"^###\s+(\w+)\s*$", stripped)
        if m:
            # Save previous description
            if current and collecting_desc:
                current.description = " ".join(desc_lines).strip()

            target_name = m.group(1)
            current = IpcMdEntry(name=target_name, is_waffle=in_waffle_section)
            entries[target_name] = current
            in_table = False
            collecting_desc = True
            desc_lines = []
            continue

        # h2 resets current target
        if stripped.startswith("## ") and not stripped.startswith("### "):
            if current and collecting_desc:
                current.description = " ".join(desc_lines).strip()
            current = None
            in_table = False
            collecting_desc = False
            continue

        if not current:
            continue

        # Table rows: | `funcName` | Description |
        if stripped.startswith("|"):
            if "---" in stripped:
                in_table = True
                collecting_desc = False
                if desc_lines:
                    current.description = " ".join(desc_lines).strip()
                continue
            if in_table:
                parts = [p.strip() for p in stripped.split("|")]
                # parts[0] is empty (before first |), parts[1] is function, parts[2] is desc
                if len(parts) >= 3:
                    func_cell = parts[1].strip("`").strip()
                    func_name = func_cell.split()[0] if func_cell else ""
                    func_desc = parts[2].strip()
                    if func_name and func_name.lower() != "function":
                        current.functions[func_name] = func_desc
            else:
                # Header row
                if "Function" in stripped and "Description" in stripped:
                    pass  # next line will be ---
            continue

        # Collect description lines (between ### and first table/fence)
        if collecting_desc and stripped and not stripped.startswith("---"):
            desc_lines.append(stripped)

    # Save last entry's description
    if current and collecting_desc and desc_lines:
        current.description = " ".join(desc_lines).strip()

    return entries


# ---------------------------------------------------------------------------
# Merge + classify
# ---------------------------------------------------------------------------


def _infer_family_from_path(qml_file: str) -> str:
    """Infer family from QML file path."""
    if any(marker in qml_file for marker in WAFFLE_PATH_MARKERS):
        return "waffle"
    if "modules/ii/" in qml_file:
        return "ii"
    # Services and shared modules
    return "shared"


def merge(
    qml_targets: dict[str, IpcTarget], md_entries: dict[str, IpcMdEntry]
) -> list[IpcTarget]:
    """Merge QML ground truth with IPC.md metadata."""
    result: list[IpcTarget] = []

    for name, target in sorted(qml_targets.items()):
        md = md_entries.get(name)

        if md:
            target.description = md.description

            # Enrich function descriptions from IPC.md
            for fn in target.functions:
                if fn.name in md.functions:
                    fn.description = md.functions[fn.name]

            target.keybind_example = md.keybind_example

            # Family from IPC.md section
            if md.is_waffle:
                target.family = "waffle"
            elif name in KNOWN_DUPLICATES:
                target.family = "shared"
            else:
                target.family = _infer_family_from_path(target.qml_file)
        else:
            # No IPC.md entry — infer family from path
            target.family = _infer_family_from_path(target.qml_file)
            print(
                f"WARNING: target '{name}' found in QML ({target.qml_file}) "
                f"but missing from docs/IPC.md",
                file=sys.stderr,
            )

        result.append(target)

    # Check for IPC.md entries not in QML
    for name in sorted(md_entries):
        if name not in qml_targets:
            print(
                f"WARNING: target '{name}' documented in docs/IPC.md "
                f"but not found in any QML IpcHandler",
                file=sys.stderr,
            )

    return result


# ---------------------------------------------------------------------------
# Kebab-case alias generation
# ---------------------------------------------------------------------------


def _camel_to_kebab(name: str) -> str:
    """Convert camelCase to kebab-case."""
    result = []
    for i, ch in enumerate(name):
        if ch.isupper() and i > 0:
            result.append("-")
        result.append(ch.lower())
    return "".join(result)


def generate_aliases(targets: list[IpcTarget]) -> dict[str, str]:
    """Generate kebab-case aliases for camelCase target names."""
    aliases: dict[str, str] = {}
    for t in targets:
        kebab = _camel_to_kebab(t.name)
        if kebab != t.name:
            aliases[kebab] = t.name
    return aliases


# ---------------------------------------------------------------------------
# Output generation
# ---------------------------------------------------------------------------


def _bash_escape(s: str) -> str:
    """Escape a string for bash double-quoted context."""
    return (
        s.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("$", "\\$")
        .replace("`", "\\`")
    )


def _bash_single_escape(s: str) -> str:
    """Escape for single-quoted bash string."""
    return s.replace("'", "'\\''")


def generate_bash(targets: list[IpcTarget], aliases: dict[str, str]) -> str:
    """Generate the bash registry file content."""
    lines: list[str] = []

    # Compute source hashes for staleness check
    qml_files = set()
    for t in targets:
        if t.qml_file:
            qml_files.add(t.qml_file)
    md_hash = ""
    if IPC_MD.exists():
        md_hash = hashlib.sha256(IPC_MD.read_bytes()).hexdigest()[:16]

    lines.append("#!/usr/bin/env bash")
    lines.append(
        "# Auto-generated from QML IpcHandler declarations + docs/IPC.md metadata."
    )
    lines.append("# Do not edit manually.")
    lines.append(f"# Regenerate: python3 scripts/lib/generate-ipc-registry.py")
    lines.append(f"# IPC.md hash: {md_hash}")
    lines.append(f"# Targets: {len(targets)}")
    lines.append("")

    # Target descriptions
    lines.append("declare -gA IPC_TARGET_DESC=(")
    for t in targets:
        desc = _bash_escape(t.description) if t.description else ""
        lines.append(f'  [{t.name}]="{desc}"')
    lines.append(")")
    lines.append("")

    # Target family
    lines.append("declare -gA IPC_TARGET_FAMILY=(")
    for t in targets:
        lines.append(f'  [{t.name}]="{t.family}"')
    lines.append(")")
    lines.append("")

    # Target functions (space-separated list)
    lines.append("declare -gA IPC_TARGET_FUNCTIONS=(")
    for t in targets:
        fnames = " ".join(t.function_names())
        lines.append(f'  [{t.name}]="{fnames}"')
    lines.append(")")
    lines.append("")

    # Function descriptions (key is always "target:function", no args in key)
    lines.append("declare -gA IPC_FUNCTION_DESC=(")
    for t in targets:
        for fn in t.functions:
            desc = _bash_escape(fn.description) if fn.description else ""
            lines.append(f'  ["{t.name}:{fn.name}"]="{desc}"')
    lines.append(")")
    lines.append("")

    # Function argument hints (for display)
    lines.append("declare -gA IPC_FUNCTION_ARGS=(")
    for t in targets:
        for fn in t.functions:
            if fn.args:
                arg_hint = " ".join(f"<{a}>" for a in fn.args)
                lines.append(f'  ["{t.name}:{fn.name}"]="{arg_hint}"')
    lines.append(")")
    lines.append("")

    # Keybind examples
    lines.append("declare -gA IPC_TARGET_EXAMPLE=(")
    for t in targets:
        if t.keybind_example:
            lines.append(f"  [{t.name}]='{_bash_single_escape(t.keybind_example)}'")
    lines.append(")")
    lines.append("")

    # Flat target lists
    all_names = [t.name for t in targets]
    shared = [t.name for t in targets if t.family == "shared"]
    ii = [t.name for t in targets if t.family == "ii"]
    waffle = [t.name for t in targets if t.family == "waffle"]

    lines.append(f"IPC_ALL_TARGETS=({' '.join(all_names)})")
    lines.append(f"IPC_SHARED_TARGETS=({' '.join(shared)})")
    lines.append(f"IPC_II_TARGETS=({' '.join(ii)})")
    lines.append(f"IPC_WAFFLE_TARGETS=({' '.join(waffle)})")
    lines.append("")

    # Kebab-case aliases
    lines.append("declare -gA IPC_KEBAB_ALIASES=(")
    for kebab, camel in sorted(aliases.items()):
        lines.append(f"  [{kebab}]={camel}")
    lines.append(")")
    lines.append("")

    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main():
    check_mode = "--check" in sys.argv

    qml_targets = scan_qml()
    md_entries = parse_ipc_md()
    targets = merge(qml_targets, md_entries)
    aliases = generate_aliases(targets)
    content = generate_bash(targets, aliases)

    if check_mode:
        if not OUTPUT.exists():
            print(
                f"FAIL: {OUTPUT} does not exist. Run the generator first.",
                file=sys.stderr,
            )
            sys.exit(1)
        existing = OUTPUT.read_text()
        if existing == content:
            print(f"OK: {OUTPUT} is up to date ({len(targets)} targets)")
            sys.exit(0)
        else:
            print(f"FAIL: {OUTPUT} is stale. Regenerate with:", file=sys.stderr)
            print(f"  python3 scripts/lib/generate-ipc-registry.py", file=sys.stderr)
            sys.exit(1)
    else:
        OUTPUT.write_text(content)
        print(
            f"Generated {OUTPUT} ({len(targets)} targets, {sum(len(t.functions) for t in targets)} functions)"
        )


if __name__ == "__main__":
    main()
