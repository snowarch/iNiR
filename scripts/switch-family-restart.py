#!/usr/bin/env python3
"""Safely switch panel family by restarting the supervised shell.

Qt 6.11 + Quickshell 0.3.1 can crash while layer-shell windows are torn down
and recreated in-process.  This helper stops the supervised shell first,
updates the persisted config atomically, then starts the service again.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time


VALID_FAMILIES = {"ii", "waffle", "iris"}


def _inir_path() -> str:
    override = os.environ.get("INIR_FAMILY_SWITCH_INIR", "").strip()
    if override:
        return override

    xdg_bin = Path(os.environ.get("XDG_BIN_HOME", Path.home() / ".local/bin")) / "inir"
    if xdg_bin.is_file() and os.access(xdg_bin, os.X_OK):
        return str(xdg_bin)

    resolved = shutil.which("inir")
    if resolved:
        return resolved

    local = Path(__file__).resolve().with_name("inir")
    if local.is_file() and os.access(local, os.X_OK):
        return str(local)

    raise RuntimeError("inir launcher not found")


def _config_path() -> Path:
    base = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    return base / "illogical-impulse" / "config.json"


def _merged_panels(current: object, base: list[str]) -> list[str]:
    values = list(current) if isinstance(current, list) else []
    if not values:
        return list(base)
    for panel in base:
        if panel not in values:
            values.append(panel)
    return values


def _qt_json(value: object, depth: int = 0) -> str:
    """JSON the way the shell's own writer lays it out (Qt's indented form).

    The shell rewrites config.json in its own layout as soon as it starts; matching it byte for byte keeps a family
    switch from rewriting the whole file twice (Python writes empty containers as `[]`, Qt as `[` newline `]`).
    """
    pad, inner = "    " * depth, "    " * (depth + 1)
    if isinstance(value, dict):
        if not value:
            return "{\n" + pad + "}"
        items = (f"{inner}{json.dumps(k, ensure_ascii=False)}: {_qt_json(v, depth + 1)}" for k, v in value.items())
        return "{\n" + ",\n".join(items) + "\n" + pad + "}"
    if isinstance(value, list):
        if not value:
            return "[\n" + pad + "]"
        return "[\n" + ",\n".join(inner + _qt_json(v, depth + 1) for v in value) + "\n" + pad + "]"
    return json.dumps(value, ensure_ascii=False)


def _write_atomic(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = path.stat().st_mode & 0o777 if path.exists() else 0o600
    fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    tmp_path = Path(tmp_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(_qt_json(data) + "\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(tmp_path, mode)
        os.replace(tmp_path, path)
    finally:
        try:
            tmp_path.unlink()
        except FileNotFoundError:
            pass


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: switch-family-restart.py <family> <base-panels-json>", file=sys.stderr)
        return 2

    family = sys.argv[1]
    if family not in VALID_FAMILIES:
        print(f"invalid panel family: {family}", file=sys.stderr)
        return 2

    try:
        base_panels = json.loads(sys.argv[2])
    except json.JSONDecodeError as exc:
        print(f"invalid panel list: {exc}", file=sys.stderr)
        return 2
    if not isinstance(base_panels, list) or not all(isinstance(item, str) for item in base_panels):
        print("base panels must be a JSON string array", file=sys.stderr)
        return 2

    config_path = _config_path()
    try:
        config = json.loads(config_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"cannot read config: {exc}", file=sys.stderr)
        return 3
    if not isinstance(config, dict):
        print("config root is not an object", file=sys.stderr)
        return 3

    inir = _inir_path()
    stopped = False
    result = 0
    try:
        stop = subprocess.run([inir, "service", "stop"], check=False)
        if stop.returncode != 0:
            print("could not stop supervised iNiR service", file=sys.stderr)
            return 4
        stopped = True

        current_enabled = config.get("enabledPanels", [])
        config["panelFamily"] = family
        config["enabledPanels"] = _merged_panels(current_enabled, base_panels)

        # Match shell.qml's normal family bookkeeping: once a non-empty panel
        # set exists, newly introduced family panels become known as well.
        if isinstance(current_enabled, list) and current_enabled:
            config["knownPanels"] = _merged_panels(config.get("knownPanels", []), base_panels)

        _write_atomic(config_path, config)
    except (OSError, RuntimeError) as exc:
        print(f"family switch failed: {exc}", file=sys.stderr)
        result = 5
    finally:
        if stopped:
            restarted = False
            for attempt in range(2):
                try:
                    start = subprocess.run([inir, "service", "start"], check=False)
                    restarted = start.returncode == 0
                except OSError:
                    restarted = False
                if restarted:
                    break
                if attempt == 0:
                    time.sleep(0.25)
            if not restarted:
                print("could not restart supervised iNiR service", file=sys.stderr)
                if result == 0:
                    result = 6

    return result


if __name__ == "__main__":
    raise SystemExit(main())
