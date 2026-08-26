#!/usr/bin/env python3
"""Table-driven privileged GUI argv adapter.

Adding a privileged GUI is adding a table row. QML ShellExec.privilegedGuiArgv
mirrors this table.
"""

from __future__ import annotations

import re
from typing import Sequence

PRIVILEGED_GUI = (
    {"basename": "gparted", "wrap": True, "inject_qt5": False, "prefix": False},
    {"basename": "ventoygui", "wrap": True, "inject_qt5": True, "prefix": True},
)

_FRONTEND_RE = re.compile(r"^--(gtk[234]|qt[456])$")


def privileged_gui_argv(command: Sequence[str], wrapper_script: str) -> list[str]:
    argv = [str(arg) for arg in (command or []) if str(arg)]
    if not argv:
        return []
    base = argv[0].rsplit("/", 1)[-1].lower()
    match = None
    for row in PRIVILEGED_GUI:
        name = row["basename"]
        if base == name or (row.get("prefix") and base.startswith(f"{name}.")):
            match = row
            break
    if not match or not match.get("wrap"):
        return argv
    graphical = list(argv)
    if match.get("inject_qt5"):
        has_frontend = any(_FRONTEND_RE.match(arg.lower()) for arg in graphical[1:])
        if not has_frontend:
            graphical = [graphical[0], "--qt5", *graphical[1:]]
    return [wrapper_script, *graphical]
