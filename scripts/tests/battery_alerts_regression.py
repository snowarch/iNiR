#!/usr/bin/env python3
"""Isolated qs-rs regression for battery warning sounds; no live shell changes.

Run from a Wayland session with:
    python3 scripts/tests/battery_alerts_regression.py

Uses the repository's real services/Battery.qml, mocked notifications/audio/suspend
and an invalid session D-Bus address so notify-send cannot reach the desktop.
"""
from __future__ import annotations

import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import textwrap


ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(os.getenv("INIR_BATTERY_SOURCE", str(ROOT / "services/Battery.qml")))


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(textwrap.dedent(content).lstrip(), encoding="utf-8")


def shell_binary() -> Path:
    override = os.getenv("INIR_QS_BIN")
    candidates = [
        Path(override).expanduser() if override else None,
        Path.home() / ".local/share/inir/runtime/0.1.0/bin/qs",
        Path(shutil.which("qs")) if shutil.which("qs") else None,
    ]
    for candidate in candidates:
        if candidate and candidate.is_file() and os.access(candidate, os.X_OK):
            return candidate
    raise RuntimeError("qs-rs binary not found; set INIR_QS_BIN")


def fixture(directory: Path) -> None:
    write(
        directory / "services/qmldir",
        """
        module qs.services
        singleton Battery 1.0 Battery.qml
        singleton Audio 1.0 Audio.qml
        singleton Session 1.0 Session.qml
        """,
    )
    shutil.copyfile(SOURCE, directory / "services/Battery.qml")
    write(
        directory / "services/Audio.qml",
        """
        pragma Singleton
        import QtQuick
        QtObject {
            function playEvent(name) { console.log("[BATTERY_TEST] AUDIO " + name) }
        }
        """,
    )
    write(
        directory / "services/Session.qml",
        """
        pragma Singleton
        import QtQuick
        QtObject {
            function suspend() { console.log("[BATTERY_TEST] WOULD_SUSPEND") }
        }
        """,
    )
    write(
        directory / "modules/common/qmldir",
        """
        module qs.modules.common
        singleton Config 1.0 Config.qml
        singleton Translation 1.0 Translation.qml
        """,
    )
    write(
        directory / "modules/common/Config.qml",
        """
        pragma Singleton
        import QtQuick
        QtObject {
            property var options: ({
                battery: { low: 15, critical: 5, suspend: 3,
                           automaticSuspend: false, full: 101,
                           chargeLimit: { enable: false, threshold: 90 } },
                sounds: { battery: true }
            })
        }
        """,
    )
    write(
        directory / "modules/common/Translation.qml",
        """
        pragma Singleton
        import QtQuick
        QtObject { function tr(message) { return message } }
        """,
    )
    write(
        directory / "modules/common/functions/qmldir",
        """
        module qs.modules.common.functions
        singleton Dummy 1.0 Dummy.qml
        """,
    )
    write(
        directory / "modules/common/functions/Dummy.qml",
        """
        pragma Singleton
        import QtQuick
        QtObject {}
        """,
    )
    write(
        directory / "shell.qml",
        """
        import QtQuick
        import Quickshell
        import qs.services
        ShellRoot {
            // Simulated percentage is written before charging status, exactly
            // as the real battery IPC does. Neither notice should sound here.
            Timer {
                interval: 150
                running: true
                repeat: false
                onTriggered: {
                    console.log("[BATTERY_TEST] A charging 2%")
                    Battery.simulatedPercentage = 0.02
                    Battery.simulatedState = "charging"
                }
            }
            Timer {
                interval: 1950
                running: true
                repeat: false
                onTriggered: {
                    console.log("[BATTERY_TEST] B discharging 14%")
                    Battery.simulatedPercentage = 0.14
                    Battery.simulatedState = "discharging"
                }
            }
            Timer {
                interval: 4300
                running: true
                repeat: false
                onTriggered: {
                    console.log("[BATTERY_TEST] C discharging 2%")
                    Battery.simulatedPercentage = 0.02
                }
            }
            Timer {
                interval: 6300
                running: true
                repeat: false
                onTriggered: {
                    console.log("[BATTERY_TEST] D end")
                    Battery.simulatedPercentage = -1
                    Qt.quit()
                }
            }
        }
        """,
    )


def main() -> None:
    env = os.environ.copy()
    runtime = Path(env.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
    if not env.get("WAYLAND_DISPLAY"):
        sockets = sorted(p.name for p in runtime.glob("wayland-*") if p.is_socket())
        if not sockets:
            raise RuntimeError("Requires a live Wayland session for qs-rs")
        env["WAYLAND_DISPLAY"] = sockets[0]
    env["XDG_RUNTIME_DIR"] = str(runtime)
    env["QT_QPA_PLATFORM"] = "wayland"
    # No desktop notifications/sounds; Audio and Session are local mocks.
    env["DBUS_SESSION_BUS_ADDRESS"] = "unix:path=/tmp/inir-battery-regression-no-bus"
    with tempfile.TemporaryDirectory(prefix="inir-battery-qmltest-") as temp:
        directory = Path(temp)
        fixture(directory)
        logfile = directory / "log.txt"
        with logfile.open("w", encoding="utf-8") as out:
            try:
                subprocess.run(
                    [str(shell_binary()), "--no-color", "-p", str(directory)],
                    stdout=out, stderr=subprocess.STDOUT,
                    env=env, timeout=7.2, check=False,
                )
            except subprocess.TimeoutExpired:
                # ShellRoot is a daemon; reaching timer D is the success signal.
                pass
        output = logfile.read_text(encoding="utf-8")
        markers = [f"[BATTERY_TEST] {label}" for label in
                   ("A charging 2%", "B discharging 14%",
                    "C discharging 2%", "D end")]
        positions = [output.find(marker) for marker in markers]
        if any(position < 0 for position in positions) or positions != sorted(positions):
            raise AssertionError("Incomplete QML test run:\n" + output[-4000:])
        sections = [output[positions[i]:positions[i + 1]] for i in range(3)]
        stages = [
            re.findall(r"\[BATTERY_TEST\] AUDIO (\w+)", section)
            for section in sections
        ]
        # The legitimate unplug sound can be absent depending on the mock's
        # power-state startup timing; only battery warnings are asserted.
        warnings = [[name for name in stage if name.startswith("battery")]
                    for stage in stages]
        if warnings != [[], ["batteryLow"], ["batteryCritical"]]:
            raise AssertionError(f"Wrong battery warnings: {warnings}\n{output[-4000:]}")
        if stages[0] or "[BATTERY_TEST] WOULD_SUSPEND" in output:
            raise AssertionError(f"Unexpected startup audio/suspend: {stages[0]}\n{output[-4000:]}")
        if " ERROR" in output or " FATAL" in output:
            raise AssertionError("QML runtime error:\n" + output[-4000:])
        print("PASS: charging 2% has no startup sound/notice")
        print("PASS: discharging 14% emits exactly one low-battery warning")
        print("PASS: discharging 2% emits exactly one critical warning")
        print("PASS: no suspend attempted; isolated shell and mocked audio")


if __name__ == "__main__":
    main()
