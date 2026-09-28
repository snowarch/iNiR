#!/usr/bin/env python3
import builtins
import importlib.util
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


SCRIPT = Path(__file__).with_name("detect_sensors.py")
SPEC = importlib.util.spec_from_file_location("detect_sensors", SCRIPT)
DETECT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(DETECT)


class SensorFixture:
    def __init__(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / "class/hwmon").mkdir(parents=True)
        (self.root / "class/drm").mkdir(parents=True)

    def hwmon(self, number, name, labels=()):
        path = self.root / "class/hwmon" / f"hwmon{number}"
        path.mkdir()
        (path / "name").write_text(name)
        for index, label in enumerate(labels, 1):
            (path / f"temp{index}_input").write_text("")
            if label is not None:
                (path / f"temp{index}_label").write_text(label)
        return path

    def card(self, number, vendor, busy=False, runtime=None):
        device = self.root / "devices" / f"gpu{number}"
        device.mkdir(parents=True)
        (device / "vendor").write_text(vendor)
        if busy:
            (device / "gpu_busy_percent").write_text("")
        if runtime:
            (device / "power").mkdir()
            (device / "power/runtime_status").write_text(runtime)
        card = self.root / "class/drm" / f"card{number}"
        card.mkdir()
        os.symlink(device, card / "device")
        return device

    def link_gpu_hwmon(self, number, device, name="amdgpu", labels=("Edge",)):
        path = self.hwmon(number, name, labels)
        os.symlink(device, path / "device")
        return path

    def close(self):
        self.tmp.cleanup()


class DetectSensorsTests(unittest.TestCase):
    def setUp(self):
        self.fixture = SensorFixture()

    def tearDown(self):
        self.fixture.close()

    def test_amd_tdie_precedes_tctl_and_does_not_read_inputs(self):
        self.fixture.hwmon(0, "k10temp", ("Tctl", "Tdie"))
        original_open = builtins.open

        def guarded_open(path, *args, **kwargs):
            if str(path).endswith("_input"):
                raise AssertionError("temperature input was read during discovery")
            return original_open(path, *args, **kwargs)

        with patch("builtins.open", guarded_open):
            result = DETECT.detect(self.fixture.root)
        self.assertTrue(result["cpu"].endswith("temp2_input"))
        self.assertEqual(result["cpuLabel"], "Tdie")

    def test_intel_package_wins_and_acpi_is_ignored(self):
        self.fixture.hwmon(0, "coretemp", ("Core 0", "Package id 0"))
        zone = self.fixture.root / "class/thermal/thermal_zone0"
        zone.mkdir(parents=True)
        (zone / "type").write_text("acpitz")
        (zone / "temp").write_text("42000")
        result = DETECT.detect(self.fixture.root)
        self.assertTrue(result["cpu"].endswith("temp2_input"))
        self.assertEqual(result["cpuLabel"], "Package id 0")

    def test_old_dedicated_cpu_sensor_without_labels_uses_first_input(self):
        self.fixture.hwmon(0, "k10temp", (None,))
        result = DETECT.detect(self.fixture.root)
        self.assertTrue(result["cpu"].endswith("temp1_input"))

    def test_board_cpu_label_is_accepted_after_explicit_thermal_fallback(self):
        self.fixture.hwmon(0, "nct6775", ("CPU", "System"))
        result = DETECT.detect(self.fixture.root)
        self.assertTrue(result["cpu"].endswith("temp1_input"))
        self.assertEqual(result["cpuLabel"], "CPU")

    def test_multigpu_prefers_nvidia_and_correlates_its_hwmon(self):
        amd = self.fixture.card(0, "0x1002", busy=True)
        nvidia = self.fixture.card(1, "0x10de", runtime="suspended")
        self.fixture.link_gpu_hwmon(0, amd, labels=("Edge",))
        self.fixture.link_gpu_hwmon(1, nvidia, name="nvidia", labels=("Hotspot", "Memory"))
        result = DETECT.detect(self.fixture.root)
        self.assertEqual(result["gpuVendor"], "0x10de")
        self.assertEqual(result["gpuCard"], str(self.fixture.root / "class/drm/card1"))
        self.assertNotIn("gpu", result)
        self.assertIn("gpuRuntime", result)

    def test_missing_devices_returns_empty_result(self):
        self.assertEqual(DETECT.detect(self.fixture.root), {})


if __name__ == "__main__":
    unittest.main(verbosity=2)
