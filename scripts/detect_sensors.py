#!/usr/bin/env python3
"""Discover stable sysfs paths used by ResourceUsage."""

import glob
import os
import re

CPU_HWMON = {"coretemp", "k10temp", "zenpower", "fam15h_power", "cpu_thermal", "via_cputemp"}
GPU_HWMON = {"amdgpu", "radeon", "nouveau", "nvidia", "i915", "xe", "panfrost", "lima", "v3d", "vc4"}
BOARD_HWMON = {"nct6775", "it87", "w83627ehf", "lm75", "lm78", "lm85"}


def get_content(path):
    try:
        with open(path, "r") as stream:
            return stream.read().strip()
    except (OSError, UnicodeError):
        return ""


def _temp_inputs(hwmon_path):
    return sorted(glob.glob(os.path.join(hwmon_path, "temp*_input")))


def _label(input_path):
    return get_content(input_path[:-6] + "_label")


def _explicit_cpu_label(label):
    words = set(re.findall(r"[a-z0-9]+", label.lower()))
    return not (words & {"vrm", "vr", "soc", "pch"}) and bool(words & {"cpu", "package", "tdie", "tctl", "processor"})


def _cpu_sensor_input(hwmon_path, name):
    """Return (input, label), without reading any temperature value."""
    labelled = [(path, _label(path)) for path in _temp_inputs(hwmon_path)]
    lowered = [(path, label, label.lower()) for path, label in labelled]
    if name == "coretemp":
        matches = [(p, original) for p, original, lower in lowered if "package" in lower]
        return matches[0] if matches else (labelled[0] if labelled else (None, ""))
    if name in {"k10temp", "zenpower", "fam15h_power"}:
        for needle in ("tdie", "tctl"):
            matches = [(p, original) for p, original, lower in lowered if needle in lower]
            if matches:
                return matches[0]
        return labelled[0] if labelled else (None, "")
    matches = [(p, original) for p, original, lower in lowered if _explicit_cpu_label(lower)]
    return matches[0] if matches else (labelled[0] if labelled else (None, ""))


def _gpu_sensor_input(hwmon_path):
    """Prefer edge; reject hotspot/memory labels unless an input is unlabeled."""
    labelled = [(path, _label(path)) for path in _temp_inputs(hwmon_path)]
    edge = [(p, l) for p, l in labelled if "edge" in l.lower()]
    if edge:
        return edge[0]
    generic = [(p, l) for p, l in labelled if l.strip().lower() in {"", "gpu", "gpu core", "core"}]
    return generic[0] if generic else (None, "")


def _drm_cards(root):
    cards = []
    for card in sorted(glob.glob(os.path.join(root, "class", "drm", "card[0-9]*"))):
        match = re.fullmatch(r"card(\d+)", os.path.basename(card))
        device = os.path.join(card, "device")
        if not match or not os.path.isdir(card) or not os.path.exists(device):
            continue
        cards.append({"card": card, "number": int(match.group(1)),
                      "device": os.path.realpath(device),
                      "vendor": get_content(os.path.join(device, "vendor")).lower(),
                      "busy": os.path.isfile(os.path.join(device, "gpu_busy_percent"))})
    return cards


def _hwmon_device(hwmon):
    device = os.path.join(hwmon, "device")
    return os.path.realpath(device) if os.path.exists(device) else ""


def _gpu_hwmon(card, hwmons):
    matches = []
    for hwmon in hwmons:
        if get_content(os.path.join(hwmon, "name")).lower() not in GPU_HWMON:
            continue
        if _hwmon_device(hwmon) == card["device"]:
            matches.append(hwmon)
    return sorted(matches)


def _thermal_cpu(root):
    for zone in sorted(glob.glob(os.path.join(root, "class", "thermal", "thermal_zone*"))):
        zone_type = get_content(os.path.join(zone, "type")).lower()
        if not os.path.isfile(os.path.join(zone, "temp")):
            continue
        if (zone_type in {"x86_pkg_temp", "cpu", "cpu_thermal", "processor", "package"}
                or re.fullmatch(r"cpu\d+", zone_type)):
            return os.path.join(zone, "temp"), zone_type
    return None, ""


def _board_cpu(root, hwmons):
    for hwmon in hwmons:
        name = get_content(os.path.join(hwmon, "name")).lower()
        if name not in BOARD_HWMON:
            continue
        candidate, label = _cpu_sensor_input(hwmon, "board")
        if candidate and _explicit_cpu_label(label):
            return candidate, label
    return None, ""


def detect(sysfs_root="/sys"):
    """Return discovered paths/metadata; discovery does not read temperatures."""
    root = os.path.abspath(sysfs_root)
    hwmons = sorted(glob.glob(os.path.join(root, "class", "hwmon", "hwmon*")))
    cpu_path = cpu_label = None
    for preferred in ("coretemp", "k10temp", "zenpower", "fam15h_power", "cpu_thermal", "via_cputemp"):
        for hwmon in hwmons:
            name = get_content(os.path.join(hwmon, "name")).lower()
            if name == preferred:
                candidate, label = _cpu_sensor_input(hwmon, name)
                if candidate:
                    cpu_path, cpu_label = candidate, label
                    break
        if cpu_path:
            break
    if not cpu_path:
        cpu_path, cpu_label = _thermal_cpu(root)
    if not cpu_path:
        cpu_path, cpu_label = _board_cpu(root, hwmons)

    cards = _drm_cards(root)
    cards.sort(key=lambda c: (c["vendor"] != "0x10de", not c["busy"], c["number"]))
    selected = cards[0] if cards else None
    gpu_path = gpu_label = None
    if selected:
        for hwmon in _gpu_hwmon(selected, hwmons):
            candidate, label = _gpu_sensor_input(hwmon)
            if candidate:
                gpu_path, gpu_label = candidate, label
                break

    result = {}
    if cpu_path:
        result["cpu"] = os.path.realpath(cpu_path)
        if cpu_label:
            result["cpuLabel"] = cpu_label
    if selected:
        result["gpuDevice"] = selected["device"]
        result["gpuVendor"] = selected["vendor"]
        result["gpuCard"] = selected["card"]
        runtime = os.path.join(selected["device"], "power", "runtime_status")
        if os.path.exists(runtime):
            result["gpuRuntime"] = os.path.realpath(runtime)
    if gpu_path:
        result["gpu"] = os.path.realpath(gpu_path)
        if gpu_label:
            result["gpuLabel"] = gpu_label
    return result


def main():
    for key, value in detect().items():
        print(f"{key}:{value}")


if __name__ == "__main__":
    main()
