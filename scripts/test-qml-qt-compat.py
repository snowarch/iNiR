#!/usr/bin/env python3
"""Keep QML parseable on the Qt versions distributions still ship.

Up to Qt 6.10 the QML lexer turns the old Java-style reserved words (long, int, short, ...) into a
reserved-word token, so a property, id, parameter or variable with one of those names fails the
whole file with "Expected token `identifier'". Qt 6.11 accepts them, which hides the break on
rolling distributions while Ubuntu, Debian and Fedora cannot load the file at all.
"""

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RESERVED = ("abstract boolean byte char double float goto implements int interface long native "
            "package private protected short synchronized throws transient volatile").split()
WORD = "(?:" + "|".join(RESERVED) + ")"
NAME_SITES = [
    re.compile(rf"\bproperty\s+[\w.<>]+\s+({WORD})\b"),
    re.compile(rf"\balias\s+({WORD})\b"),
    re.compile(rf"^\s*id\s*:\s*({WORD})\b"),
    re.compile(rf"\bon\s+({WORD})\s*\{{"),
    re.compile(rf"\b(?:var|let|const)\s+({WORD})\b"),
    re.compile(rf"\b(?:function|signal)\s+\w+\s*\(([^)]*)\)"),
]
PARAM = re.compile(rf"(?:^|,)\s*({WORD})\s*(?::|,|$)")
# ES2019+ built-ins QML's V4 engine lacks: the call throws a TypeError at runtime, the file still parses.
# Measured on Qt 6.11.2 / Quickshell 0.3.1.
MISSING_JS = re.compile(r"\bObject\.fromEntries\b|\.(?:flat|flatMap|replaceAll|at)\s*\(|\bstructuredClone\s*\(")
STRING = re.compile(r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'|`[^`]*`')


def main() -> int:
    listed = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard", "*.qml", "*.js"], cwd=ROOT, capture_output=True, text=True)
    files = listed.stdout.split() if listed.returncode == 0 and listed.stdout.strip() \
        else [str(path.relative_to(ROOT)) for pattern in ("*.qml", "*.js") for path in ROOT.rglob(pattern) if ".git" not in path.parts]
    failures = []
    for rel in files:
        path = ROOT / rel
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        # A file's own `function at(...)` is not Array.prototype.at.
        own = set(re.findall(r"\bfunction\s+(\w+)\s*\(", text))
        for number, line in enumerate(text.splitlines(), 1):
            code = STRING.sub('""', line).split("//", 1)[0]
            missing = next((m for m in MISSING_JS.finditer(code) if m.group(0).strip(".( ") not in own), None)
            if missing:
                failures.append(f"{rel}:{number}: `{missing.group(0).strip('.(')}` does not exist in QML's JS engine")
            if not rel.endswith(".qml"):
                continue
            for site in NAME_SITES:
                for match in site.finditer(code):
                    names = PARAM.findall(match.group(1)) if site is NAME_SITES[-1] else [match.group(1)]
                    for name in names:
                        failures.append(f"{rel}:{number}: `{name}` is reserved in QML up to Qt 6.10")
    if failures:
        print("QML that fails to parse on Qt 6.10 and older, or calls JS the engine lacks:")
        for failure in failures:
            print(f"  {failure}")
        return 1
    print(f"QML Qt compatibility: {len(files)} files use no reserved names and no missing JS built-ins")
    return 0


if __name__ == "__main__":
    sys.exit(main())
