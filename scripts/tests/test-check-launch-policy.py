#!/usr/bin/env python3
"""TDD: launch-policy scanner signatures and check_naming return-early."""

from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = REPO_ROOT / "scripts" / "lib" / "check-launch-policy.py"


def load_module():
    spec = importlib.util.spec_from_file_location("check_launch_policy", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise FileNotFoundError(MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class CheckLaunchPolicyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = load_module()

    def test_signatures_include_hyprsunset_and_awww_daemon(self):
        names = set(self.mod.SIGNATURES)
        self.assertIn("hyprsunset", names)
        self.assertIn("awww-daemon", names)

    def test_check_naming_missing_function_returns_only_that(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "ShellExec.qml"
            path.write_text("pragma Singleton\nSingleton { id: root }\n", encoding="utf-8")
            problems = self.mod.check_naming(path)
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("launchDaemon", problems[0])
        joined = " ".join(problems).lower()
        self.assertNotIn("inir-", joined)
        self.assertNotIn("unit prefix", joined)


if __name__ == "__main__":
    result = unittest.main(verbosity=2, exit=False).result
    sys.exit(0 if result.wasSuccessful() else 1)
