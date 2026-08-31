#!/usr/bin/env python3
"""Read one live MangoHud log sample for a game process tree.

MangoHud writes its CSV log from inside the instrumented game process. The
shell cannot read frame timing from the compositor, so this helper finds the
CSV file held open by the focused game's process tree, then falls back to
configured log directories for XWayland clients whose compositor PID is the
shared XWayland server. It returns the latest complete row as JSON.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import os
import re
import sys
import time
from pathlib import Path


METRIC_FIELDS = (
    "fps",
    "frametime",
    "cpu_load",
    "cpu_power",
    "gpu_load",
    "cpu_temp",
    "gpu_temp",
    "gpu_core_clock",
    "gpu_mem_clock",
    "gpu_vram_used",
    "gpu_power",
    "gpu_voltage",
    "ram_used",
    "swap_used",
    "process_rss",
    "cpu_mhz",
    "elapsed",
)
METADATA_FIELDS = {
    "os": "osName",
    "cpu": "cpuName",
    "gpu": "gpuName",
    "kernel": "kernelVersion",
    "driver": "gpuDriver",
    "cpuscheduler": "cpuScheduler",
}
MAX_FRESH_LOG_AGE_MS = 3000


def _parse_csv_line(line: str) -> list[str]:
    try:
        return next(csv.reader([line]))
    except (csv.Error, StopIteration):
        return []


def _number(value: str | None) -> float | None:
    if value is None or value.strip() == "":
        return None
    try:
        number = float(value.strip())
    except ValueError:
        return None
    return number if math.isfinite(number) else None


def _process_tree(root_pid: int) -> list[int]:
    """Return root_pid and all descendants visible in procfs."""

    pending = [root_pid]
    seen: set[int] = set()
    result: list[int] = []

    while pending:
        pid = pending.pop()
        if pid in seen or pid <= 0:
            continue
        seen.add(pid)
        result.append(pid)

        children_file = Path(f"/proc/{pid}/task/{pid}/children")
        try:
            children = children_file.read_text(encoding="ascii").split()
        except (OSError, UnicodeError):
            continue
        for child in children:
            try:
                pending.append(int(child))
            except ValueError:
                continue

    return result


def _process_ancestors(root_pid: int) -> list[int]:
    """Return root_pid and its visible parent chain."""

    result = []
    current = root_pid
    seen: set[int] = set()
    while current > 0 and current not in seen:
        seen.add(current)
        result.append(current)
        try:
            status = Path(f"/proc/{current}/status").read_text(encoding="ascii")
        except (OSError, UnicodeError):
            break
        parent = next(
            (line.split("\t", 1)[1] for line in status.splitlines() if line.startswith("PPid:\t")),
            "0",
        )
        try:
            current = int(parent)
        except ValueError:
            break
    return result


def _open_log_files(root_pid: int) -> list[Path]:
    """Find non-summary CSV files held open by root_pid or its descendants."""

    candidates: dict[str, Path] = {}
    for pid in _process_tree(root_pid):
        fd_dir = Path(f"/proc/{pid}/fd")
        try:
            entries = list(os.scandir(fd_dir))
        except OSError:
            continue

        for entry in entries:
            try:
                target = os.readlink(entry.path)
            except OSError:
                continue
            if target.endswith(" (deleted)") or not target.lower().endswith(".csv"):
                continue
            path = Path(target)
            if path.name.endswith("_summary.csv") or not path.is_file():
                continue
            candidates[str(path)] = path

    return list(candidates.values())


def _directory_log_files(directory: str) -> list[Path]:
    """Find non-summary CSV logs in a configured MangoHud directory."""

    if not directory:
        return []

    result = []
    try:
        for path in Path(directory).expanduser().glob("*.csv"):
            if path.name.endswith("_summary.csv"):
                continue
            if path.is_file():
                result.append(path)
    except OSError:
        pass
    return result


def _header_for_log(path: Path) -> list[str]:
    try:
        with path.open("rb") as handle:
            prefix = handle.read(65536).decode("utf-8", errors="replace")
    except OSError:
        return []

    for line in prefix.splitlines():
        fields = [field.strip() for field in _parse_csv_line(line)]
        if len(fields) >= 2 and fields[0] == "fps" and fields[1] == "frametime":
            return fields
    return []


def _metadata_for_log(path: Path) -> dict[str, str]:
    try:
        with path.open("rb") as handle:
            prefix = handle.read(65536).decode("utf-8", errors="replace")
    except OSError:
        return {}

    lines = prefix.splitlines()
    for index, line in enumerate(lines[:-1]):
        header = [field.strip() for field in _parse_csv_line(line)]
        if not header or header[0] != "os":
            continue
        values = [field.strip() for field in _parse_csv_line(lines[index + 1])]
        metadata = {}
        for field_index, field_name in enumerate(header):
            output_key = METADATA_FIELDS.get(field_name)
            if output_key is not None and field_index < len(values):
                metadata[output_key] = values[field_index]
        return metadata
    return {}


def _mangohud_version(path: Path) -> str:
    try:
        with path.open("rb") as handle:
            prefix = handle.read(4096).decode("utf-8", errors="replace")
    except OSError:
        return ""

    for line in prefix.splitlines():
        value = line.strip()
        if re.fullmatch(r"v\d+(?:\.\d+)+", value):
            return value
    return ""


def _latest_row(path: Path, header: list[str]) -> list[str]:
    try:
        with path.open("rb") as handle:
            handle.seek(0, os.SEEK_END)
            size = handle.tell()
            handle.seek(max(0, size - 131072))
            tail = handle.read().decode("utf-8", errors="replace")
    except OSError:
        return []

    header_length = len(header)
    for line in reversed(tail.splitlines()):
        fields = [field.strip() for field in _parse_csv_line(line)]
        if len(fields) < header_length or _number(fields[0]) is None:
            continue
        if _number(fields[1]) is None:
            continue
        return fields
    return []


def _read_log(path: Path) -> dict[str, object]:
    header = _header_for_log(path)
    if not header:
        return {"available": False}

    row = _latest_row(path, header)
    if not row:
        return {"available": False}

    values: dict[str, object] = {"available": True}
    for field in METRIC_FIELDS:
        try:
            index = header.index(field)
        except ValueError:
            values[field] = None
            continue
        values[field] = _number(row[index] if index < len(row) else None)

    values.update(_metadata_for_log(path))
    values["mangoHudVersion"] = _mangohud_version(path)

    try:
        stat = path.stat()
        values["sampleId"] = f"{stat.st_ino}:{stat.st_size}:{stat.st_mtime_ns}"
        values["logAgeMs"] = max(0, int((time.time() - stat.st_mtime) * 1000))
    except OSError:
        values["available"] = False
    return values


def _process_command(pid: int) -> str:
    try:
        raw = Path(f"/proc/{pid}/cmdline").read_bytes()
    except OSError:
        return ""
    return " ".join(
        part.decode("utf-8", errors="replace") for part in raw.split(b"\0") if part
    )


def _process_maps(pid: int) -> str:
    try:
        return Path(f"/proc/{pid}/maps").read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def _process_details(pid: int) -> dict[str, object]:
    if pid <= 0:
        return {}

    pids = _process_tree(pid)
    for ancestor in _process_ancestors(pid):
        if ancestor not in pids:
            pids.append(ancestor)
    commands = [_process_command(candidate) for candidate in pids]
    command_text = "\n".join(command for command in commands if command)
    maps = "\n".join(_process_maps(candidate) for candidate in pids)
    lower_commands = command_text.lower()
    lower_maps = maps.lower()

    if "libvulkan" in lower_maps or "winevulkan" in lower_maps:
        graphics_api = "Vulkan"
    elif any(token in lower_maps for token in ("libgl.so", "libglx", "libgles")):
        graphics_api = "OpenGL"
    else:
        graphics_api = ""

    wine_proton = ""
    for command in commands:
        lower = command.lower()
        if "proton" in lower:
            match = re.search(r"(proton[^/\s]*)", lower)
            wine_proton = match.group(1) if match else "Proton"
            break
        if "wine" in lower:
            wine_proton = "Wine"

    fex_stats = "FEX detected" if "fex" in lower_commands or "fex" in lower_maps else ""
    return {
        "sourcePid": pid,
        "graphicsApi": graphics_api,
        "wineProton": wine_proton,
        "fexStats": fex_stats,
    }


def _log_owner_pids(path: Path) -> list[int]:
    owners: set[int] = set()
    try:
        proc_entries = list(os.scandir("/proc"))
    except OSError:
        return []

    wanted = str(path)
    for proc_entry in proc_entries:
        if not proc_entry.name.isdigit():
            continue
        try:
            fd_entries = os.scandir(f"/proc/{proc_entry.name}/fd")
        except OSError:
            continue
        with fd_entries:
            for fd_entry in fd_entries:
                try:
                    target = os.readlink(fd_entry.path)
                except OSError:
                    continue
                if target == wanted:
                    owners.add(int(proc_entry.name))
                    break
    return sorted(owners)


def _attach_process_details(
    sample: dict[str, object], path: Path, fallback_pid: int, scan_owners: bool = True
) -> None:
    owners = _log_owner_pids(path) if scan_owners else []
    if owners:
        sample.update(_process_details(owners[0]))
    elif fallback_pid > 0:
        sample.update(_process_details(fallback_pid))


def _unique_paths(paths: list[Path]) -> list[Path]:
    unique: dict[str, Path] = {}
    for path in paths:
        unique[str(path)] = path
    return list(unique.values())


def _fresh_paths(paths: list[Path], now: float) -> list[Path]:
    result = []
    for path in paths:
        try:
            age_ms = (now - path.stat().st_mtime) * 1000
        except OSError:
            continue
        if 0 <= age_ms <= MAX_FRESH_LOG_AGE_MS:
            result.append(path)
    return result


def _newest_path(paths: list[Path]) -> Path | None:
    newest: Path | None = None
    newest_mtime = -1.0
    for candidate in paths:
        try:
            mtime = candidate.stat().st_mtime
        except OSError:
            continue
        if mtime > newest_mtime:
            newest = candidate
            newest_mtime = mtime
    return newest


def snapshot(
    pid: int,
    log_file: str | None,
    log_directories: list[str],
) -> dict[str, object]:
    payload: dict[str, object] = {
        "pid": pid,
        "available": False,
        "logAgeMs": -1,
    }

    process_owned = False
    if log_file:
        candidates = [Path(log_file)]
    else:
        process_candidates = _unique_paths(_open_log_files(pid))
        if process_candidates:
            candidates = process_candidates
            process_owned = True
        else:
            directory_candidates = _unique_paths(
                candidate
                for directory in log_directories
                for candidate in _directory_log_files(directory)
            )
            fresh_candidates = _fresh_paths(directory_candidates, time.time())
            fresh_samples: list[tuple[Path, dict[str, object]]] = []
            for candidate in fresh_candidates:
                sample = _read_log(candidate)
                if sample.get("available") is True:
                    fresh_samples.append((candidate, sample))
            if len(fresh_samples) == 1:
                candidate, sample = fresh_samples[0]
                payload.update(sample)
                _attach_process_details(payload, candidate, pid)
                return payload
            if len(fresh_samples) > 1:
                payload["ambiguous"] = True
                return payload
            candidates = directory_candidates

    newest = _newest_path(candidates)
    if newest is not None:
        payload.update(_read_log(newest))
        _attach_process_details(payload, newest, pid, scan_owners=not process_owned)
    return payload


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pid", type=int, required=True)
    parser.add_argument("--log-file")
    parser.add_argument("--log-dir", action="append", default=[])
    args = parser.parse_args()

    try:
        result = snapshot(args.pid, args.log_file, args.log_dir)
    except Exception as error:  # Keep the QML stream valid if procfs changes mid-read.
        result = {"pid": args.pid, "available": False, "error": str(error)}
    print(json.dumps(result, separators=(",", ":")), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
