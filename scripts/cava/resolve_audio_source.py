#!/usr/bin/env python3
"""Pick a cava [input] source that follows music, not VoIP/system mix.

Prefers an uncorked PipeWire/Pulse stream belonging to the active MPRIS
player, then other active music streams. User-blocked applications are always
excluded, including after MPRIS track changes. Falls back to the default sink
monitor only when there are no live streams and no explicit blocklist.
"""
from __future__ import annotations

import argparse
import json
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
    "ncspot",
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
    "ncspot": ("ncspot",),
    "com.github.th_ch.youtube_music": ("youtube-music", "youtube_music", "ytmusic"),
}


@dataclass
class SinkInput:
    index: int
    client_id: str
    node_name: str
    media_role: str
    media_name: str
    app_name: str
    app_id: str
    binary: str
    corked: bool
    sink_id: str = ""


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
                media_name=block.get("media.name", "").lower(),
                app_name=(block.get("application.name")
                    or (client.app_name if client else "")).lower(),
                app_id=block.get("application.id", "").lower(),
                binary=(block.get("application.process.binary")
                    or (client.binary if client else "")).lower(),
                corked=(block.get("Corked", block.get("pulse.corked", "false"))
                    .lower() in ("yes", "true", "1")),
                sink_id=block.get("Sink", ""),
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
        sink_match = re.match(r"^\s+Sink:\s+(\d+)$", line)
        if sink_match and sink_index:
            block["Sink"] = sink_match.group(1)
    flush()
    return streams


def _parse_sink_monitors(text: str) -> dict[str, str]:
    monitors: dict[str, str] = {}
    sink_id = ""
    monitor = ""

    def flush() -> None:
        nonlocal sink_id, monitor
        if sink_id and monitor:
            monitors[sink_id] = monitor
        sink_id = ""
        monitor = ""

    for line in text.splitlines():
        match = re.match(r"^Sink #(\d+)$", line.strip())
        if match:
            flush()
            sink_id = match.group(1)
            continue
        monitor_match = re.match(r"^\s+Monitor Source:\s+(.+?)\s*$", line)
        if monitor_match and sink_id:
            monitor = monitor_match.group(1)
    flush()
    return monitors


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


def _normalize_identity(value: str) -> str:
    return re.sub(r"[^a-z0-9]", "", value.lower())


def _filter_hints(apps: list[str]) -> tuple[set[str], set[str]]:
    tokens: set[str] = set()
    aliases: set[str] = set()
    for app in apps:
        normalized = _normalize_identity(app)
        if normalized:
            tokens.add(normalized)
        # Only use aliases from an exact known desktop-entry key. The active
        # player resolver intentionally expands browser families (Firefox ↔ Zen,
        # Chromium ↔ Electron), but a user blocklist must stay app-specific.
        entry = str(app).strip().lower()
        if entry.endswith(".desktop"):
            entry = entry[:-8]
        if "." in entry:
            for key, binaries in DESKTOP_ENTRY_BINARIES.items():
                if key.lower() == entry:
                    aliases.update(binaries)
                    break
    return tokens, aliases


def _matches_blocked(stream: SinkInput, blocked_apps: list[str]) -> bool:
    if not blocked_apps:
        return False

    tokens, aliases = _filter_hints(blocked_apps)
    identity = " ".join((
        stream.node_name, stream.media_name, stream.app_name,
        stream.app_id, stream.binary,
    )).lower()
    normalized_identity = _normalize_identity(identity)
    if any(token in normalized_identity for token in tokens):
        return True
    normalized_fields = {
        _normalize_identity(value) for value in (
            stream.node_name, stream.app_name, stream.app_id, stream.binary,
        ) if value
    }
    return any(_normalize_identity(alias) in normalized_fields for alias in aliases if alias)


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


def _score_stream(stream: SinkInput, hint_binaries: set[str], blocked_apps: list[str]) -> int:
    if _is_excluded(stream):
        return -10_000
    if stream.corked:
        return -5_000
    if _matches_blocked(stream, blocked_apps):
        return -10_000

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


def _stream_monitor(stream: SinkInput, sink_monitors: dict[str, str]) -> str:
    """Return the playback sink monitor, never the app stream itself.

    Cava's PipeWire input accepts capture-capable nodes/devices. A playback
    Stream/Output/Audio object serial is not such a source and can make
    WirePlumber auto-connect Cava to the default microphone instead.
    """
    return sink_monitors.get(stream.sink_id, "")


def resolve_source(desktop_entry: str = "", blocked_apps: list[str] | None = None) -> str:
    blocked_apps = blocked_apps or []
    server_info = _run(["pactl", "info"])
    if not server_info:
        return "" if blocked_apps else "auto"
    clients = _parse_clients(_run(["pactl", "list", "clients"]))
    streams = _parse_sink_inputs(_run(["pactl", "list", "sink-inputs"]), clients)
    sink_monitors = _parse_sink_monitors(_run(["pactl", "list", "sinks"]))
    hint_binaries = _hint_binaries(desktop_entry)

    ranked = sorted(
        ((_score_stream(stream, hint_binaries, blocked_apps), stream) for stream in streams),
        key=lambda item: (item[0], item[1].index),
        reverse=True,
    )

    for score, stream in ranked:
        if score > 0 and stream.node_name:
            monitor = _stream_monitor(stream, sink_monitors)
            if monitor:
                return monitor

    # If the active MPRIS player belongs to a blocked app, its identity hint
    # must not prevent another eligible playback stream from driving the
    # visualizer. Retry without the player hint, while keeping the user blocklist
    # authoritative. This is what lets "block Firefox" survive YouTube track
    # changes while another player can still feed Cava.
    if blocked_apps and hint_binaries:
        fallback_ranked = sorted(
            ((_score_stream(stream, set(), blocked_apps), stream) for stream in streams),
            key=lambda item: (item[0], item[1].index),
            reverse=True,
        )
        for score, stream in fallback_ranked:
            if score > 0 and stream.node_name:
                monitor = _stream_monitor(stream, sink_monitors)
                if monitor:
                    return monitor

    # VoIP/system streams only — don't fall back to the full sink mix (Discord voices, etc.)
    if streams or blocked_apps:
        return ""

    return _default_sink_monitor()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--desktop-entry", default="")
    parser.add_argument("--blocked-apps-json", default="[]")
    args = parser.parse_args()
    try:
        parsed = json.loads(args.blocked_apps_json)
        blocked_apps = [str(value).strip() for value in parsed if str(value).strip()] \
            if isinstance(parsed, list) else []
    except (json.JSONDecodeError, TypeError):
        blocked_apps = []

    source = resolve_source(args.desktop_entry, blocked_apps)
    if blocked_apps and not source:
        raise SystemExit(3)
    print(source)


if __name__ == "__main__":
    main()
