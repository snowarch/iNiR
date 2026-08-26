#!/usr/bin/env python3
"""Extract the launchDaemon bash wrapper from ShellExec.qml."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

_ENV_RE = re.compile(r"readonly property string _envRestoreScript:\s*`([^`]+)`")
_DAEMON_RE = re.compile(
    r"function launchDaemon\(opts:\s*var\):\s*void\s*\{.*?const script = root\._envRestoreScript \+\s*`([^`]+)`",
    re.DOTALL,
)


def extract_launch_daemon_script(qml_path: str | Path) -> str:
    path = Path(qml_path)
    content = path.read_text(encoding="utf-8")
    env_match = _ENV_RE.search(content)
    if not env_match:
        raise ValueError(f"_envRestoreScript not found in {path}")
    daemon_match = _DAEMON_RE.search(content)
    if not daemon_match:
        raise ValueError(f"launchDaemon script not found in {path}")
    full_script = env_match.group(1) + "\n" + daemon_match.group(1)
    return re.sub(r"\\(\$|`)", r"\1", full_script)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("qml_path", type=Path, help="Path to ShellExec.qml")
    args = parser.parse_args(argv)
    try:
        sys.stdout.write(extract_launch_daemon_script(args.qml_path))
    except (OSError, ValueError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
