#!/usr/bin/env python3
"""Fetch synchronized lyrics from LRCLIB."""

from __future__ import annotations

import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://lrclib.net/api"
TIMEOUT = 12
REQUEST_DELAY = 0.25
USER_AGENT = "iNiR/2.29.2 (https://github.com/snowarch/inir)"

STAMP = re.compile(r"\[(\d{1,3}):(\d{2}(?:[.:]\d{1,3})?)\]")


def emit(payload: dict, request_id: str = "") -> None:
    if request_id:
        payload["requestId"] = request_id
    sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def get_json(url: str):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        response = urllib.request.urlopen(request, timeout=TIMEOUT)
    except urllib.error.HTTPError as exc:
        if exc.code != 429:
            raise
        retry_after = float(exc.headers.get("Retry-After", "1"))
        time.sleep(max(0, retry_after))
        response = urllib.request.urlopen(request, timeout=TIMEOUT)
    with response:
        return json.loads(response.read().decode("utf-8", "replace"))


def parse_lrc(lrc: str) -> list:
    out = []
    for raw in lrc.splitlines():
        stamps = list(STAMP.finditer(raw))
        if not stamps:
            continue
        text = raw[stamps[-1].end():].strip()
        for stamp in stamps:
            minutes = int(stamp.group(1))
            seconds = float(stamp.group(2).replace(":", "."))
            out.append({"t": round(minutes * 60 + seconds, 3), "text": text})
    out.sort(key=lambda line: line["t"])
    return out


def normalize(value: str) -> str:
    return re.sub(r"[^\w\s]", " ", (value or "").lower()).strip()


def looks_like(candidate: dict, title: str, artist: str) -> bool:
    if not candidate.get("syncedLyrics"):
        return False

    def overlaps(wanted: str, got: str) -> bool:
        wanted, got = normalize(wanted), normalize(got)
        if not wanted or not got:
            return False
        if wanted in got or got in wanted:
            return True
        wanted_words = {w for w in wanted.split() if len(w) > 3}
        return bool(wanted_words & set(got.split()))

    return (overlaps(title, candidate.get("trackName", ""))
            and overlaps(artist, candidate.get("artistName", "")))


def find_lyrics(title: str, artist: str, album: str, duration) -> list:
    q = urllib.parse.quote

    attempts = []
    if album and duration:
        attempts.append(
            "%s/get?track_name=%s&artist_name=%s&album_name=%s&duration=%d"
            % (API, q(title), q(artist), q(album), int(duration))
        )
    attempts.extend([
        "%s/search?track_name=%s&artist_name=%s" % (API, q(title), q(artist)),
        "%s/search?q=%s" % (API, q("%s %s" % (title, artist))),
    ])

    had_response = False
    last_error = None
    for index, url in enumerate(attempts):
        if index > 0:
            time.sleep(REQUEST_DELAY)
        try:
            payload = get_json(url)
            had_response = True
        except (urllib.error.URLError, ValueError, OSError) as exc:
            last_error = exc
            continue

        candidates = payload if isinstance(payload, list) else [payload]
        for candidate in candidates:
            if not isinstance(candidate, dict):
                continue
            if not looks_like(candidate, title, artist):
                continue
            lines = parse_lrc(candidate.get("syncedLyrics") or "")
            if lines:
                return lines

    if not had_response and last_error is not None:
        raise last_error
    return []


def main() -> None:
    args = sys.argv[1:]
    title = args[0].strip() if len(args) > 0 else ""
    artist = args[1].strip() if len(args) > 1 else ""
    album = args[2].strip() if len(args) > 2 else ""
    request_id = args[4].strip() if len(args) > 4 else ""

    if not title or not artist:
        emit({"status": "no_info"}, request_id)
        return

    try:
        duration = float(args[3]) if len(args) > 3 and args[3] else None
    except ValueError:
        duration = None

    try:
        lines = find_lyrics(title, artist, album, duration)
    except Exception as exc:
        emit({"status": "error", "message": str(exc)}, request_id)
        return

    emit({"status": "ok", "lines": lines} if lines else {"status": "not_found"}, request_id)


if __name__ == "__main__":
    main()
