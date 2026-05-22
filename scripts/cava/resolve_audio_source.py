#!/usr/bin/env python3
"""Pick a cava [input] source that follows music, not VoIP/system mix.

Prefers PipeWire/Pulse streams tagged media.role=music, then streams whose
client binary matches the active MPRIS desktop entry. Falls back to the
default sink monitor when nothing better exists.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass


EXCLUDED_APP_NAMES = (
    "discord",
    "vesktop",
    "webRTC",
    "webrtc",
    "teams",
    "zoom",
    "slack",
    "telegram-desktop",
    "element",
    "speech-dispatcher",
    "speech-dispatcher-dummy",
    "steam voice",
)

EXCLUDED_BINARIES = (
    "discord",
    "vesktop",
    "teams",
    "zoom",
    "slack",
    "sd_dummy",
)

EXCLUDED_MEDIA_ROLES = (
    "communication",
    "phone",
    "notification",
    "alert",
    "game",
    "production",
)

DESKTOP_ENTRY_BINARIES: dict[str, tuple[str, ...]] = {
    "spotify": ("spotify",),
    "mpv": ("mpv",),
    "vlc": ("vlc",),
    "firefox": ("firefox", "zen"),
    "chromium": ("chromium", "chrome", "brave", "google-chrome", "google-chrome-stable"),
    "chrome": ("chrome", "google-chrome", "google-chrome-stable", "brave"),
    "brave": ("brave",),
    "org.chromium.Chromium": ("chromium", "chrome"),
    "com.google.Chrome": ("chrome", "google-chrome", "google-chrome-stable"),
    "org.mozilla.firefox": ("firefox",),
    "strawberry": ("strawberry",),
    "audacious": ("audacious",),
    "deadbeef": ("deadbeef",),
    "rhythmbox": ("rhythmbox",),
    "clementine": ("clementine",),
    "haruna": ("haruna",),
    "com.github.thitzekai.Mooz": ("mooz",),
}


@dataclass
class SinkInput:
    index: int
    client_id: str
    node_name: str
    media_role: str
    app_name: str
    binary: str


@dataclass
class PulseClient:
    index: int
    app_name: str
    binary: str


def _run(cmd: list[str]) -> str:
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ""


def _parse_clients(text: str) -> dict[str, PulseClient]:
    clients: dict[str, PulseClient] = {}
    block: dict[str, str] = {}
    client_index = ""

    def flush() -> None:
        nonlocal block, client_index
        if not client_index:
            block = {}
            return
        clients[client_index] = PulseClient(
            index=int(client_index),
            app_name=block.get("application.name", ""),
            binary=block.get("application.process.binary", ""),
        )
        block = {}
        client_index = ""

    for line in text.splitlines():
        match = re.match(r"^Client #(\d+)$", line.strip())
        if match:
            flush()
            client_index = match.group(1)
            continue
        prop = re.match(r"^\s+([^=]+) = \"(.*)\"$", line)
        if prop and client_index:
            block[prop.group(1)] = prop.group(2)
    flush()
    return clients


def _parse_sink_inputs(text: str, clients: dict[str, PulseClient]) -> list[SinkInput]:
    streams: list[SinkInput] = []
    block: dict[str, str] = {}
    sink_index = ""

    def flush() -> None:
        nonlocal block, sink_index
        if not sink_index:
            block = {}
            return
        node_name = block.get("node.name", "")
        if not node_name:
            sink_index = ""
            block = {}
            return
        client_id = block.get("client.id", block.get("Client", ""))
        client = clients.get(client_id)
        streams.append(
            SinkInput(
                index=int(sink_index),
                client_id=client_id,
                node_name=node_name,
                media_role=block.get("media.role", "").lower(),
                app_name=(client.app_name if client else "").lower(),
                binary=(client.binary if client else "").lower(),
            )
        )
        block = {}
        sink_index = ""

    for line in text.splitlines():
        match = re.match(r"^Sink Input #(\d+)$", line.strip())
        if match:
            flush()
            sink_index = match.group(1)
            continue
        prop = re.match(r"^\s+([^=]+) = \"(.*)\"$", line)
        if prop and sink_index:
            block[prop.group(1)] = prop.group(2)
        client_match = re.match(r"^\s+Client:\s+(\d+)$", line)
        if client_match and sink_index:
            block["Client"] = client_match.group(1)
    flush()
    return streams


def _hint_binaries(desktop_entry: str) -> set[str]:
    entry = desktop_entry.strip().lower()
    if not entry:
        return set()
    hints: set[str] = set()
    for key, binaries in DESKTOP_ENTRY_BINARIES.items():
        if key.lower() in entry or entry in key.lower():
            hints.update(binaries)
    base = entry.split(".")[-1]
    if base and base not in ("desktop", "client"):
        hints.add(base)
    return hints


def _is_excluded(stream: SinkInput) -> bool:
    if any(token in stream.app_name for token in EXCLUDED_APP_NAMES):
        return True
    if stream.binary in EXCLUDED_BINARIES:
        return True
    if stream.media_role in EXCLUDED_MEDIA_ROLES:
        return True
    if "voice" in stream.app_name and "steam" in stream.app_name:
        return True
    return False


def _score_stream(stream: SinkInput, hint_binaries: set[str]) -> int:
    if _is_excluded(stream):
        return -10_000

    score = 0
    if stream.media_role == "music":
        score += 100
    elif stream.media_role in ("video", "multimedia"):
        score += 40
    elif stream.media_role:
        score -= 20

    if hint_binaries:
        if stream.binary in hint_binaries:
            score += 80
        if any(h in stream.app_name for h in hint_binaries):
            score += 40

    if stream.binary in ("spotify", "mpv", "vlc", "strawberry", "clementine", "rhythmbox"):
        score += 15

    return score


def _default_sink_monitor() -> str:
    sink = _run(["pactl", "get-default-sink"]).strip()
    if sink:
        return f"{sink}.monitor"
    return "auto"


def resolve_source(desktop_entry: str = "") -> str:
    if not _run(["pactl", "info"]):
        return "auto"

    clients = _parse_clients(_run(["pactl", "list", "clients"]))
    streams = _parse_sink_inputs(_run(["pactl", "list", "sink-inputs"]), clients)
    hint_binaries = _hint_binaries(desktop_entry)

    ranked = sorted(
        ((_score_stream(stream, hint_binaries), stream) for stream in streams),
        key=lambda item: item[0],
        reverse=True,
    )

    for score, stream in ranked:
        if score > 0 and stream.node_name:
            return stream.node_name

    # VoIP/system streams only — don't fall back to the full sink mix (Discord voices, etc.)
    if streams:
        return ""

    return _default_sink_monitor()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--desktop-entry", default="")
    args = parser.parse_args()
    print(resolve_source(args.desktop_entry))


if __name__ == "__main__":
    main()
