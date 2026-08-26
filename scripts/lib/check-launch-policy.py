#!/usr/bin/env python3
"""Enforce the process-launch policy: no long-running process may bypass ShellExec.

Scans QML for raw Quickshell.execDetached() calls that reference binaries or
identifiers the shell must only launch through ShellExec.launch()/launchDaemon()
(transient systemd scopes/services so they survive shell death/restart).

Usage:
    python3 scripts/lib/check-launch-policy.py            # scan
    python3 scripts/lib/check-launch-policy.py --check    # accepted alias (same scan)

Exit codes: 0 = pass, 1 = policy violations, 2 = error (bad args / IO).
"""

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
QML_DIRS = [
    REPO_ROOT / "modules",
    REPO_ROOT / "services",
    REPO_ROOT / "GlobalStates.qml",
    REPO_ROOT / "shell.qml",
    REPO_ROOT / "ShellIiPanels.qml",
    REPO_ROOT / "ShellWafflePanels.qml",
]
SKIP_FILES = {REPO_ROOT / "modules" / "common" / "functions" / "ShellExec.qml"}

_RE_EXECDETACHED = re.compile(r"Quickshell\.execDetached\s*\(")

SIGNATURES = {
    "swaylock": "lock screen must go through ShellExec.launch (scope \"lock\")",
    "hyprlock": "lock screen must go through ShellExec.launch (scope \"lock\")",
    "wlsunset": "night light daemon must go through ShellExec.launchDaemon (scope \"wlsunset\")",
    "hyprsunset": "night light daemon must go through ShellExec.launchDaemon (scope \"hyprsunset\")",
    "awww-daemon": "wallpaper daemon must go through ShellExec.launchDaemon (scope \"awww-daemon\")",
    "awww": "wallpaper backend must go through ShellExec.launchDaemon (scope \"awww-daemon\")",
    "easyeffects": "audio daemon must go through ShellExec.launchDaemon (scope \"easyeffects\")",
    "com.github.wwmm.easyeffects": "flatpak audio daemon must go through ShellExec.launchDaemon (scope \"easyeffects\")",
    "record.sh": "screen recording must go through ShellExec.launch (scope \"record\")",
    "recordScriptPath": "screen recording must go through ShellExec.launch (scope \"record\")",
    "wf-recorder": "screen recording must go through ShellExec.launch (scope \"record\")",
    "gnome-keyring-daemon": "keyring daemon is owned by scripts/keyring/unlock.sh, never QML",
}

def _is_qs_p_call(tokens: set[str]) -> bool:
    has_qs = any(tok == "qs" or tok.endswith("/qs") for tok in tokens)
    return has_qs and "-p" in tokens

_STOP_FLAGS = ("--stop",)

_RE_PROCESS_REGION_REC = re.compile(
    r"command\s*:\s*\[[^\]]*recordScriptPath[^\]]*--region", re.S
)

_RE_UPDATE_PAYLOAD = re.compile(r'["\']-c["\']', re.S)

_ALLOW_MARKER_RE = re.compile(r"//\s*launch-policy:\s*allow\b")

_RE_LAUNCHDAEMON_DEF = re.compile(r"function\s+launchDaemon\s*\(")
_RE_DAEMON_UNIT_NAME = re.compile(r"inir-")
_RE_DAEMON_PID_SUFFIX = re.compile(r"-\\\$\\\$|-\\$\\$|-\$\$")


def iter_qml_files():
    """Yield every QML file under the scanned dirs, in deterministic order."""
    paths = []
    for entry in QML_DIRS:
        if entry.is_file():
            paths.append(entry)
        elif entry.is_dir():
            paths.extend(sorted(entry.rglob("*.qml")))
    return sorted(set(paths))


def extract_call_args(text: str, start: int) -> str:
    """Return the argument text of the execDetached call at `start`."""
    depth = 1
    in_string = None
    i = start
    n = len(text)
    while i < n:
        ch = text[i]
        if in_string:
            if ch == "\\":
                i += 2
                continue
            if ch == in_string:
                in_string = None
        else:
            if ch in ('"', "'", "`"):
                in_string = ch
            elif ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
                if depth == 0:
                    return text[start:i]
        i += 1
    return ""


def call_tokens(args: str) -> list[str]:
    """Extract string literals and bare identifiers from call args."""
    tokens = []
    for m in re.finditer(r'"((?:[^"\\]|\\.)*)"|\'((?:[^\'\\]|\\.)*)\'', args):
        lit = m.group(1) if m.group(1) is not None else m.group(2)
        tokens.append(lit)
        if "/" in lit:
            tokens.append(lit.rsplit("/", 1)[-1])
    tokens += re.findall(r"\b[a-zA-Z_][a-zA-Z0-9_]*\b", args)
    return tokens


def line_of(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def scan_file(path: Path) -> list[tuple[int, str]]:
    """Return [(line, reason)] violations for one QML file."""
    text = path.read_text(errors="replace")
    lines = text.splitlines()
    violations: list[tuple[int, str]] = []

    for m in _RE_EXECDETACHED.finditer(text):
        call_line = line_of(text, m.start())
        call_idx = call_line - 1  # 0-based
        if call_idx >= 0 and _ALLOW_MARKER_RE.search(lines[call_idx]):
            continue
        if call_idx - 1 >= 0 and _ALLOW_MARKER_RE.search(lines[call_idx - 1]):
            continue

        args = extract_call_args(text, m.end())
        if not args:
            continue

        tokens = set(call_tokens(args))
        reasons = []
        for sig, reason in SIGNATURES.items():
            if sig in tokens:
                reasons.append(reason)
        if _is_qs_p_call(tokens):
            reasons.append("qs -p panel must go through ShellExec.launch (scope \"killdialog\")")
        stop_call = any(flag in tokens for flag in _STOP_FLAGS)
        if "recordScriptPath" in tokens and stop_call:
            reasons = [r for r in reasons if "recording must go through" not in r]
        if _RE_UPDATE_PAYLOAD.search(args) and any("updat" in tok.lower() for tok in tokens):
            reasons.append("update payload must go through ShellExec.launch (scope \"update\")")

        for reason in reasons:
            violations.append((call_line, reason))

    for m in _RE_PROCESS_REGION_REC.finditer(text):
        violations.append((line_of(text, m.start()),
                           "region recording must go through ShellExec.launch (scope \"record\")"))

    return violations


def check_naming(shell_exec: Path) -> list[str]:
    """LS-2: ShellExec.launchDaemon must exist with stable inir- naming."""
    if not shell_exec.is_file():
        return [f"FAIL: {shell_exec.relative_to(REPO_ROOT)} not found"]
    text = shell_exec.read_text(errors="replace")
    m = _RE_LAUNCHDAEMON_DEF.search(text)
    if not m:
        return ["ShellExec.qml lacks `function launchDaemon` (LS-2)"]
    daemon_body = text[m.start():]
    problems = []
    if not _RE_DAEMON_UNIT_NAME.search(daemon_body):
        problems.append("launchDaemon body lacks stable `inir-` unit prefix (LS-2)")
    if _RE_DAEMON_PID_SUFFIX.search(daemon_body):
        problems.append("launchDaemon body must NOT use a `-$$` PID suffix (LS-2)")
    return problems


def main():
    check_mode = "--check" in sys.argv
    unknown = [a for a in sys.argv[1:] if a != "--check"]
    if unknown:
        print(f"usage: {Path(sys.argv[0]).name} [--check]", file=sys.stderr)
        return 2

    violations: list[tuple[str, int, str]] = []
    for path in iter_qml_files():
        if path in SKIP_FILES:
            continue
        for line, reason in scan_file(path):
            violations.append((str(path.relative_to(REPO_ROOT)), line, reason))

    naming = check_naming(REPO_ROOT / "modules" / "common" / "functions" / "ShellExec.qml")

    if violations or naming:
        for rel, line, reason in sorted(violations):
            print(f"{rel}:{line}: {reason} — route via ShellExec.launch()/launchDaemon() or add '// launch-policy: allow <reason>'")
        for problem in naming:
            print(f"ShellExec.qml: {problem}")
        return 1

    if check_mode:
        print(f"OK: launch policy clean ({len(list(iter_qml_files()))} files scanned)")
    return 0


if __name__ == "__main__":
    sys.exit(main())