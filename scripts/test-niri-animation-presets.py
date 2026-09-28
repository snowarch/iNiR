#!/usr/bin/env python3
"""Regression guard for Niri animation presets in scripts/niri-config.py.

Every preset in defaults/niri-animation-presets.json must apply to the shipped
60-animations.kdl, pass `niri validate` when niri is installed, be detected back
as active, and keep `off` and `slowdown`. The shipped default must match its preset.
Runs against a throwaway XDG_CONFIG_HOME, never the user's niri config.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "niri-config.py"
SHIPPED = ROOT / "defaults" / "niri" / "config.d" / "60-animations.kdl"
REGISTRY = ROOT / "defaults" / "niri-animation-presets.json"


def run(env, *args):
    out = subprocess.run([sys.executable, str(SCRIPT), *args], env=env, capture_output=True, text=True)
    return json.loads(out.stdout.strip().splitlines()[-1])


def main() -> int:
    failures = []
    registry = json.loads(REGISTRY.read_text())
    ids = [preset["id"] for preset in registry["presets"]]
    if len(ids) != len(set(ids)):
        failures.append(f"duplicate preset ids: {ids}")
    if registry.get("default") not in ids:
        failures.append(f"default {registry.get('default')!r} is not a preset")

    with tempfile.TemporaryDirectory() as tmp:
        niri = Path(tmp) / "niri"
        (niri / "config.d").mkdir(parents=True)
        (niri / "config.kdl").write_text('include "config.d/60-animations.kdl"\n')
        anim = niri / "config.d" / "60-animations.kdl"
        shutil.copy(SHIPPED, anim)
        env = dict(os.environ, XDG_CONFIG_HOME=tmp)

        active = run(env, "get-animation-presets")["active"]
        if active != registry["default"]:
            failures.append(f"shipped 60-animations.kdl reads as {active!r}, expected {registry['default']!r}")

        for preset_id in ids:
            result = run(env, "apply-animation-preset", preset_id)
            if not result.get("success"):
                failures.append(f"{preset_id}: apply failed: {result.get('error')}")
                continue
            active = run(env, "get-animation-presets")["active"]
            if active != preset_id:
                failures.append(f"{preset_id}: detected as {active!r}")

        run(env, "set", "animations", "slowdown", "1.3")
        run(env, "set", "animations", "enabled", "off")
        run(env, "apply-animation-preset", ids[0])
        state = run(env, "get-animations")
        if state.get("enabled") is not False or state.get("slowdown") != 1.3:
            failures.append(f"apply dropped off/slowdown: enabled={state.get('enabled')} slowdown={state.get('slowdown')}")

        run(env, "set", "animations", "window-movement.stiffness", "123")
        if run(env, "get-animation-presets")["active"] != "":
            failures.append("a hand-tuned spring still reads as a preset")

        if run(env, "apply-animation-preset", "no-such-preset").get("success"):
            failures.append("an unknown preset id was accepted")

        user_dir = Path(tmp) / "inir"
        user_dir.mkdir()
        mine = {"id": "mine", "name": "Mine", "description": "A user preset.",
                "types": {"window-open": {"duration-ms": 180, "curve": "ease-out-cubic"}}}
        (user_dir / "niri-animation-presets.json").write_text(json.dumps({"presets": [mine]}))
        listed = run(env, "get-animation-presets")["presets"]
        if [p["id"] for p in listed][: len(ids)] != ids or listed[-1].get("id") != "mine" or not listed[-1].get("user"):
            failures.append("a preset in ~/.config/inir/niri-animation-presets.json is not listed after the shipped ones")
        if not run(env, "apply-animation-preset", "mine").get("success") or run(env, "get-animation-presets")["active"] != "mine":
            failures.append("a user preset does not apply or is not detected back")

    for failure in failures:
        print(f"FAIL: {failure}")
    if failures:
        return 1
    print(f"niri animation presets: ok ({len(ids)} presets)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
