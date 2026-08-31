#!/usr/bin/env python3
"""Stream live MangoHud log samples for a compositor-selected process tree.

MangoHud writes its CSV log from inside the instrumented game process. The
shell cannot read frame timing from the compositor, so this helper finds the
CSV file held open by the focused game's process tree, then falls back to
configured log directories for XWayland clients whose compositor PID is the
shared XWayland server. Discovery and static metadata are cached while the
selected target remains active; each output line is the latest sample as JSON.
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
DEFAULT_DISCOVERY_INTERVAL_MS = 2000
IGNORED_IDENTITY_TOKENS = {
    "app",
    "com",
    "game",
    "gamescope",
    "net",
    "org",
    "proton",
    "steam",
    "wine",
}


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


def _read_log(
    path: Path,
    header: list[str] | None = None,
    static_metadata: dict[str, object] | None = None,
) -> dict[str, object]:
    header = header if header is not None else _header_for_log(path)
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

    if static_metadata is None:
        values.update(_metadata_for_log(path))
        values["mangoHudVersion"] = _mangohud_version(path)
    else:
        values.update(static_metadata)

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


def _is_xwayland_process(pid: int) -> bool:
    try:
        name = Path(f"/proc/{pid}/comm").read_text(encoding="ascii").strip().lower()
    except (OSError, UnicodeError):
        name = ""
    command = _process_command(pid).lower()
    return name.startswith("xwayland") or re.search(
        r"(?:^|/)xwayland(?:-satellite)?(?:\s|$)", command
    ) is not None


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


def _identity_tokens(*values: str) -> set[str]:
    return {
        token
        for value in values
        for token in re.findall(r"[a-z0-9]+", value.lower())
        if len(token) >= 3
        and any(character.isalpha() for character in token)
        and token not in IGNORED_IDENTITY_TOKENS
    }


class TelemetryMonitor:
    """Cache log discovery and target metadata across periodic samples."""

    def __init__(
        self,
        pid: int,
        target_key: str,
        target_app_id: str,
        target_name: str,
        allow_directory_fallback: bool,
        allow_title_match: bool,
        log_file: str | None,
        log_directories: list[str],
        discovery_interval_ms: int = DEFAULT_DISCOVERY_INTERVAL_MS,
    ) -> None:
        self.pid = pid
        self.target_key = target_key
        self.target_identity = _identity_tokens(
            target_app_id,
            target_name if allow_title_match else "",
        )
        self.allow_directory_fallback = allow_directory_fallback
        self.log_file = log_file
        self.log_directories = log_directories
        self.discovery_interval = max(0.1, discovery_interval_ms / 1000)
        self.path: Path | None = None
        self.header: list[str] = []
        self.static_metadata: dict[str, object] = {}
        self.process_details: dict[str, object] = {}
        self.last_discovery = 0.0
        self.ambiguous = False

    def _payload(self) -> dict[str, object]:
        return {
            "pid": self.pid,
            "targetKey": self.target_key,
            "available": False,
            "logAgeMs": -1,
        }

    def _clear_path(self) -> None:
        self.path = None
        self.header = []
        self.static_metadata = {}
        self.process_details = {}

    def _cache_path(self, path: Path, process_owned: bool) -> bool:
        header = _header_for_log(path)
        if not header:
            return False

        metadata: dict[str, object] = _metadata_for_log(path)
        metadata["mangoHudVersion"] = _mangohud_version(path)
        details: dict[str, object] = {}
        _attach_process_details(
            details,
            path,
            self.pid,
            scan_owners=not process_owned,
        )
        self.path = path
        self.header = header
        self.static_metadata = metadata
        self.process_details = details
        return True

    def _discover(self, now: float) -> None:
        self.last_discovery = now
        self.ambiguous = False

        if self.log_file:
            self._cache_path(Path(self.log_file), process_owned=False)
            return

        process_candidates = _unique_paths(_open_log_files(self.pid))
        newest_process_log = _newest_path(process_candidates)
        if newest_process_log is not None and self._cache_path(
            newest_process_log, process_owned=True
        ):
            return

        if not self.allow_directory_fallback or not _is_xwayland_process(self.pid):
            return

        directory_candidates = _unique_paths(
            candidate
            for directory in self.log_directories
            for candidate in _directory_log_files(directory)
        )
        directory_candidates = [
            candidate
            for candidate in directory_candidates
            if any(
                token in re.sub(r"[^a-z0-9]", "", candidate.stem.lower())
                for token in self.target_identity
            )
        ]
        fresh_candidates = _fresh_paths(directory_candidates, now)
        valid_candidates = [
            candidate for candidate in fresh_candidates if _header_for_log(candidate)
        ]
        if len(valid_candidates) == 1:
            self._cache_path(valid_candidates[0], process_owned=False)
        elif len(valid_candidates) > 1:
            self.ambiguous = True

    def snapshot(self) -> dict[str, object]:
        now = time.time()
        if self.path is None and now - self.last_discovery >= self.discovery_interval:
            self._discover(now)

        payload = self._payload()
        if self.ambiguous:
            payload["ambiguous"] = True
        if self.path is None:
            return payload

        sample = _read_log(self.path, self.header, self.static_metadata)
        sample.update(self.process_details)
        payload.update(sample)
        age = payload.get("logAgeMs", -1)
        if (
            payload.get("available") is not True
            or not isinstance(age, int)
            or age > MAX_FRESH_LOG_AGE_MS
        ):
            self._clear_path()
        return payload


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pid", type=int, required=True)
    parser.add_argument("--target-key", default="")
    parser.add_argument("--target-app-id", default="")
    parser.add_argument("--target-name", default="")
    parser.add_argument("--allow-directory-fallback", action="store_true")
    parser.add_argument("--allow-title-match", action="store_true")
    parser.add_argument("--log-file")
    parser.add_argument("--log-dir", action="append", default=[])
    parser.add_argument("--watch", action="store_true")
    parser.add_argument("--interval-ms", type=int, default=500)
    parser.add_argument(
        "--discovery-interval-ms",
        type=int,
        default=DEFAULT_DISCOVERY_INTERVAL_MS,
    )
    args = parser.parse_args()

    monitor = TelemetryMonitor(
        args.pid,
        args.target_key,
        args.target_app_id,
        args.target_name,
        args.allow_directory_fallback,
        args.allow_title_match,
        args.log_file,
        args.log_dir,
        args.discovery_interval_ms,
    )
    interval = max(0.05, args.interval_ms / 1000)
    while True:
        started = time.monotonic()
        try:
            result = monitor.snapshot()
        except Exception as error:  # Keep the QML stream valid if procfs changes mid-read.
            result = {
                "pid": args.pid,
                "targetKey": args.target_key,
                "available": False,
                "error": str(error),
            }
        print(json.dumps(result, separators=(",", ":")), flush=True)
        if not args.watch:
            break
        time.sleep(max(0, interval - (time.monotonic() - started)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
