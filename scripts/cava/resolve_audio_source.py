#!/usr/bin/env python3
"""Pick a cava [input] source that follows music, not VoIP/system mix.

Prefers an uncorked PipeWire/Pulse stream belonging to the active MPRIS
player, then other active music streams. Falls back to the default sink
monitor when nothing better exists.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass


EXCLUDED_APP_NAMES = (
    "quickshell",
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
    "quickshell",
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

PREFERRED_PLAYBACK_TOKENS = (
    "spotify",
    "chromium",
    "chrome",
    "brave",
    "firefox",
    "zen",
    "mpv",
    "vlc",
    "strawberry",
    "audacious",
    "rhythmbox",
    "clementine",
    "haruna",
    "youtube music",
    "youtube-music",
    "youtube_music",
    "ytmusic",
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
    "youtube-music": ("youtube-music", "youtube_music", "ytmusic", "mpv"),
    "youtube_music": ("youtube-music", "youtube_music", "ytmusic", "mpv"),
    "ytmusic": ("youtube-music", "youtube_music", "ytmusic", "mpv"),
    "com.github.th_ch.youtube_music": ("youtube-music", "youtube_music", "ytmusic"),
}


@dataclass
class SinkInput:
    index: int
    client_id: str
    node_name: str
    object_serial: str
    media_role: str
    media_name: str
    app_name: str
    app_id: str
    binary: str
    corked: bool


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
                object_serial=block.get("object.serial", ""),
                media_role=block.get("media.role", "").lower(),
                media_name=block.get("media.name", "").lower(),
                app_name=(block.get("application.name")
                    or (client.app_name if client else "")).lower(),
                app_id=block.get("application.id", "").lower(),
                binary=(block.get("application.process.binary")
                    or (client.binary if client else "")).lower(),
                corked=(block.get("Corked", block.get("pulse.corked", "false"))
                    .lower() in ("yes", "true", "1")),
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
        corked_match = re.match(r"^\s+Corked:\s+(yes|no)$", line, re.IGNORECASE)
        if corked_match and sink_index:
            block["Corked"] = corked_match.group(1)
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
    if not entry or entry == "__inir_music_player__":
        return set()
    hints: set[str] = set()
    for key, binaries in DESKTOP_ENTRY_BINARIES.items():
        if key.lower() in entry or entry in key.lower():
            hints.update(binaries)
    base = entry.split(".")[-1]
    if base and base not in ("desktop", "client"):
        hints.add(base)
    if "chrom" in entry or "brave" in entry:
        hints.update(("chromium", "chrome", "google-chrome", "google-chrome-stable", "brave", "electron"))
    if "firefox" in entry or "zen" in entry:
        hints.update(("firefox", "zen"))
    if "youtube" in entry or "ytmusic" in entry or "yt-music" in entry:
        hints.update(("youtube-music", "youtube_music", "ytmusic", "mpv", "electron"))
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
    if stream.corked:
        return -5_000

    score = 180
    if stream.media_role == "music":
        score += 120
    elif stream.media_role in ("video", "multimedia"):
        score += 50
    elif stream.media_role:
        score -= 20

    identity = " ".join((
        stream.node_name.lower(), stream.media_name, stream.app_name,
        stream.app_id, stream.binary,
    ))
    hint_match = not hint_binaries or (
        stream.binary in hint_binaries
        or stream.node_name.lower() in hint_binaries
        or stream.app_id in hint_binaries
        or any(hint in identity for hint in hint_binaries)
    )
    if not hint_match:
        return -1_000

    if hint_binaries:
        if stream.binary in hint_binaries:
            score += 500
        if stream.node_name.lower() in hint_binaries or stream.app_id in hint_binaries:
            score += 420
        if any(h in identity for h in hint_binaries):
            score += 260

    if any(token in identity for token in PREFERRED_PLAYBACK_TOKENS):
        score += 40

    return score


def _default_sink_monitor() -> str:
    sink = _run(["pactl", "get-default-sink"]).strip()
    if sink:
        return f"{sink}.monitor"
    return "auto"


def resolve_source(desktop_entry: str = "") -> str:
    server_info = _run(["pactl", "info"])
    if not server_info:
        return "auto"
    is_pipewire = "pipewire" in server_info.lower()

    clients = _parse_clients(_run(["pactl", "list", "clients"]))
    streams = _parse_sink_inputs(_run(["pactl", "list", "sink-inputs"]), clients)
    hint_binaries = _hint_binaries(desktop_entry)

    ranked = sorted(
        ((_score_stream(stream, hint_binaries), stream) for stream in streams),
        key=lambda item: (item[0], item[1].index),
        reverse=True,
    )

    for score, stream in ranked:
        if score > 0 and stream.node_name:
            if is_pipewire and stream.object_serial:
                return stream.object_serial
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
