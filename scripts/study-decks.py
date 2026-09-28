#!/usr/bin/env python3
"""Small curated study-deck catalog for iNiR.

Deck bytes stay upstream. iNiR only discovers the latest GitHub release asset,
downloads it into the user's Downloads directory, and optionally opens it.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

CATALOG = {
    "kaishi": {
        "title": "Kaishi 1.5k",
        "studyLanguage": "ja",
        "baseLanguage": "en",
        "repo": "donkuri/Kaishi",
        "description": "Beginner Japanese vocabulary with sentences, audio, furigana and pitch data.",
        "licenseNote": "Downloaded from the upstream project release; deck content retains upstream terms.",
        "assetPrefer": [r"\.apkg$"],
    },
    "manabi": {
        "title": "Manabi 2.7k",
        "studyLanguage": "ja",
        "baseLanguage": "en",
        "repo": "fafner8/Manabi",
        "description": "Frequency-sorted i+1 Japanese vocabulary and sentences with audio and furigana.",
        "licenseNote": "Downloaded from the upstream project release; deck content retains upstream terms.",
        "assetPrefer": [r"\.apkg$"],
    },
    "niponismo": {
        "title": "Niponismo",
        "studyLanguage": "ja",
        "baseLanguage": "es",
        "repo": "andresangelini/niponismo",
        "description": "Japanese grammar decks for Spanish speakers.",
        "licenseNote": "Project is CC BY-SA 4.0; third-party example material keeps its credited licenses.",
        "assetPrefer": [r"Niponismo.*\.apkg$", r"\.apkg$"],
    },
}


def emit(data):
    json.dump(data, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


def api_json(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": "iNiR-study-decks/1"})
    with urllib.request.urlopen(req, timeout=15) as response:
        return json.loads(response.read().decode("utf-8"))


def downloads_dir() -> Path:
    config = Path.home() / ".config/user-dirs.dirs"
    if config.exists():
        text = config.read_text(errors="ignore")
        match = re.search(r'^XDG_DOWNLOAD_DIR="([^"]+)"', text, re.M)
        if match:
            return Path(match.group(1).replace("$HOME", str(Path.home()))).expanduser()
    return Path.home() / "Downloads"


def select_asset(release, deck):
    assets = release.get("assets") or []
    for pattern in deck.get("assetPrefer", []):
        rx = re.compile(pattern, re.I)
        for asset in assets:
            name = str(asset.get("name") or "")
            if rx.search(name):
                return asset
    return None


def list_catalog():
    return {"ok": True, "decks": [{"id": key, **value} for key, value in CATALOG.items()]}


def download(deck_id: str, open_after: bool):
    deck = CATALOG.get(deck_id)
    if not deck:
        raise ValueError(f"Unknown study deck: {deck_id}")
    repo = deck["repo"]
    try:
        release = api_json(f"https://api.github.com/repos/{repo}/releases/latest")
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        return {
            "ok": False,
            "error": f"Could not query the latest upstream release: {exc}",
            "sourceUrl": f"https://github.com/{repo}/releases",
        }
    asset = select_asset(release, deck)
    if not asset:
        return {
            "ok": False,
            "error": "The latest upstream release has no compatible .apkg asset",
            "sourceUrl": release.get("html_url") or f"https://github.com/{repo}/releases",
        }
    url = asset.get("browser_download_url")
    name = asset.get("name") or f"{deck_id}.apkg"
    dest_dir = downloads_dir()
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / name
    tmp = dest.with_name(dest.name + ".part")
    req = urllib.request.Request(url, headers={"User-Agent": "iNiR-study-decks/1"})
    try:
        with urllib.request.urlopen(req, timeout=30) as response, tmp.open("wb") as out:
            while True:
                block = response.read(1024 * 1024)
                if not block:
                    break
                out.write(block)
        tmp.replace(dest)
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        tmp.unlink(missing_ok=True)
        return {"ok": False, "error": f"Deck download failed: {exc}", "sourceUrl": url}

    if open_after:
        try:
            subprocess.Popen(["xdg-open", str(dest)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        except OSError:
            pass
    return {
        "ok": True,
        "id": deck_id,
        "title": deck["title"],
        "path": str(dest),
        "asset": name,
        "sourceUrl": release.get("html_url") or f"https://github.com/{repo}/releases",
    }


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("list")
    dl = sub.add_parser("download")
    dl.add_argument("id")
    dl.add_argument("--no-open", action="store_true")
    args = parser.parse_args()
    try:
        if args.command == "list":
            emit(list_catalog())
        elif args.command == "download":
            payload = download(args.id, not args.no_open)
            emit(payload)
            return 0 if payload.get("ok") else 1
    except (ValueError, OSError) as exc:
        emit({"ok": False, "error": str(exc)})
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
