#!/usr/bin/env python3
"""TDD: privileged GUI argv adapter + browser openUrl argv launch."""

from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
HELPER = REPO_ROOT / "scripts" / "lib" / "privileged-gui-argv.py"
SHELL_EXEC = REPO_ROOT / "modules" / "common" / "functions" / "ShellExec.qml"
APP_SEARCH = REPO_ROOT / "services" / "AppSearch.qml"
APP_LAUNCHER = REPO_ROOT / "services" / "AppLauncher.qml"
GLOBAL_ACTIONS = REPO_ROOT / "services" / "GlobalActions.qml"
WRAPPER = "/tmp/inir/scripts/launch-privileged-gui.sh"


def load_helper():
    spec = importlib.util.spec_from_file_location("privileged_gui_argv", HELPER)
    if spec is None or spec.loader is None:
        raise FileNotFoundError(HELPER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class PrivilegedGuiArgvTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not HELPER.is_file():
            raise unittest.SkipTest(f"missing {HELPER}")
        cls.mod = load_helper()

    def test_gparted_is_wrapped(self):
        out = self.mod.privileged_gui_argv(["/usr/sbin/gparted"], WRAPPER)
        self.assertEqual(out, [WRAPPER, "/usr/sbin/gparted"])

    def test_plain_app_passthrough(self):
        out = self.mod.privileged_gui_argv(["firefox", "https://example"], WRAPPER)
        self.assertEqual(out, ["firefox", "https://example"])

    def test_ventoygui_injects_qt5_and_wraps(self):
        out = self.mod.privileged_gui_argv(["ventoygui"], WRAPPER)
        self.assertEqual(out, [WRAPPER, "ventoygui", "--qt5"])

    def test_ventoygui_prefix_match(self):
        out = self.mod.privileged_gui_argv(["/opt/ventoygui.gtk3"], WRAPPER)
        self.assertEqual(out, [WRAPPER, "/opt/ventoygui.gtk3", "--qt5"])

    def test_ventoygui_keeps_existing_frontend(self):
        out = self.mod.privileged_gui_argv(["ventoygui", "--gtk3"], WRAPPER)
        self.assertEqual(out, [WRAPPER, "ventoygui", "--gtk3"])

    def test_empty_command(self):
        self.assertEqual(self.mod.privileged_gui_argv([], WRAPPER), [])


class QmlWiringTests(unittest.TestCase):
    def test_shellexec_defines_privileged_gui_argv_table(self):
        text = SHELL_EXEC.read_text(encoding="utf-8")
        self.assertIn("function privilegedGuiArgv", text)
        self.assertIn("gparted", text)
        self.assertIn("ventoygui", text)
        self.assertIn("launch-privileged-gui.sh", text)

    def test_appsearch_uses_adapter(self):
        text = APP_SEARCH.read_text(encoding="utf-8")
        self.assertIn("privilegedGuiArgv", text)
        self.assertGreaterEqual(text.count("privilegedGuiArgv"), 2)

    def test_app_launcher_has_extra_args_or_launch_url(self):
        text = APP_LAUNCHER.read_text(encoding="utf-8")
        has_launch_url = "function launchUrl" in text
        has_extra = "extraArgs" in text and "function launch(" in text
        self.assertTrue(has_launch_url or has_extra, "need launchUrl or launch(slotId, extraArgs)")

    def test_open_url_does_not_interpolate_execcmd(self):
        text = GLOBAL_ACTIONS.read_text(encoding="utf-8")
        start = text.find("function openUrl")
        self.assertGreaterEqual(start, 0)
        end = text.find("function open(", start + 1)
        if end < 0:
            end = text.find("IpcHandler", start + 1)
        chunk = text[start:end if end > start else start + 400]
        self.assertNotIn("execCmd", chunk)
        self.assertNotIn('commandFor("browser")', chunk)
        self.assertTrue("launchUrl" in chunk or "AppLauncher.launch(" in chunk)


if __name__ == "__main__":
    failures = 0
    if not HELPER.is_file():
        print(f"FAIL: missing helper {HELPER}", file=sys.stderr)
        sys.exit(1)
    result = unittest.main(verbosity=2, exit=False).result
    sys.exit(0 if result.wasSuccessful() else 1)
