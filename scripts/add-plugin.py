#!/usr/bin/env python3
"""Add a plugin to the iNiR plugin directory.

Usage:
    add-plugin.py --url URL [--name NAME] [--icon ICON]
"""

import argparse
import html.parser
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

PLUGINS_DIR = os.path.expanduser("~/.config/illogical-impulse/plugins")
TIMEOUT = 8

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    )
}


# ---------------------------------------------------------------------------
# HTML parsers
# ---------------------------------------------------------------------------


class _TitleParser(html.parser.HTMLParser):
    def __init__(self):
        super().__init__()
        self.title: str = ""
        self._in_title: bool = False

    def handle_starttag(self, tag, attrs):
        if tag.lower() == "title":
            self._in_title = True

    def handle_endtag(self, tag):
        if tag.lower() == "title":
            self._in_title = False

    def handle_data(self, data):
        if self._in_title:
            self.title += data


class _IconParser(html.parser.HTMLParser):
    """Collect <link rel="icon"> / <link rel="shortcut icon"> hrefs."""

    def __init__(self):
        super().__init__()
        self.icon_hrefs: list[str] = []

    def handle_starttag(self, tag, attrs):
        if tag.lower() != "link":
            return
        attr_dict = dict(attrs)
        rel = attr_dict.get("rel", "").lower()
        if "icon" in rel:
            href = attr_dict.get("href", "").strip()
            if href:
                self.icon_hrefs.append(href)


# ---------------------------------------------------------------------------
# Network helpers
# ---------------------------------------------------------------------------


def _get(url: str, binary: bool = False):
    """Fetch URL, return (content, final_url) or raise on error."""
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        data = resp.read()
        final_url = resp.url
    if binary:
        return data, final_url
    charset = "utf-8"
    ct = resp.headers.get_content_charset()
    if ct:
        charset = ct
    return data.decode(charset, errors="replace"), final_url


def fetch_title(url: str) -> str | None:
    """Return <title> text for *url*, or None on failure."""
    try:
        html_text, _ = _get(url)
        parser = _TitleParser()
        parser.feed(html_text)
        title = parser.title.strip()
        return title if title else None
    except Exception:
        return None


def _resolve_icon_url(href: str, base_url: str) -> str:
    """Resolve a possibly-relative icon href against the page base URL."""
    return urllib.parse.urljoin(base_url, href)


def fetch_favicon(url: str) -> bytes | None:
    """Try to fetch a favicon for *url*.

    Strategy:
    1. {origin}/favicon.ico
    2. Parse HTML for <link rel="icon"> or <link rel="shortcut icon">

    Returns raw bytes of the image, or None if nothing could be fetched.
    """
    parsed = urllib.parse.urlparse(url)
    origin = f"{parsed.scheme}://{parsed.netloc}"

    # Strategy 1: /favicon.ico
    favicon_ico = f"{origin}/favicon.ico"
    try:
        data, _ = _get(favicon_ico, binary=True)
        if data and len(data) > 16:
            return data
    except Exception:
        pass

    # Strategy 2: parse <link rel="icon"> from the page HTML
    try:
        html_text, final_url = _get(url)
        icon_parser = _IconParser()
        icon_parser.feed(html_text)
        for href in icon_parser.icon_hrefs:
            icon_url = _resolve_icon_url(href, final_url)
            try:
                data, _ = _get(icon_url, binary=True)
                if data and len(data) > 16:
                    return data
            except Exception:
                continue
    except Exception:
        pass

    return None


# ---------------------------------------------------------------------------
# Image conversion helpers
# ---------------------------------------------------------------------------


def _save_icon(data: bytes, dest_path: str) -> bool:
    """Save icon bytes as PNG to *dest_path*.

    Tries PIL first (handles ICO → PNG conversion).
    Falls back to writing raw bytes (works for SVG, PNG already, etc.).
    Returns True on success.
    """
    # Try PIL
    try:
        from PIL import Image
        import io

        img = Image.open(io.BytesIO(data))
        img.save(dest_path, "PNG")
        return True
    except ImportError:
        pass
    except Exception:
        pass

    # Raw fallback — just write whatever we got, QML's Image can handle
    # many formats natively (PNG, WebP, SVG, even ICO on some builds)
    try:
        with open(dest_path, "wb") as f:
            f.write(data)
        return True
    except OSError:
        pass

    return False


# ---------------------------------------------------------------------------
# ID / name helpers
# ---------------------------------------------------------------------------


def id_from_url(url: str) -> str:
    """Derive a filesystem-safe id from the hostname.

    github.com       → github
    www.youtube.com  → youtube
    sub.example.co   → sub_example_co  (multi-part TLD stripped of dots)
    """
    parsed = urllib.parse.urlparse(url)
    host = parsed.hostname or parsed.netloc or "plugin"
    # Strip www.
    host = re.sub(r"^www\.", "", host)
    # Use just the first label (SLD) when it's meaningful
    parts = host.split(".")
    if len(parts) >= 2:
        label = parts[0]
    else:
        label = host
    # Sanitise to alphanumeric + hyphen/underscore
    label = re.sub(r"[^a-zA-Z0-9_-]", "_", label)
    return label or "plugin"


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main():
    parser = argparse.ArgumentParser(
        description="Add a web plugin to the iNiR plugin directory."
    )
    parser.add_argument("--url", required=True, help="URL of the plugin")
    parser.add_argument(
        "--name", default=None, help="Display name (auto-fetched if omitted)"
    )
    parser.add_argument(
        "--icon", default=None, help="MaterialSymbol icon name (default: language)"
    )
    args = parser.parse_args()

    url: str = args.url
    # Normalise: ensure scheme
    if not url.startswith(("http://", "https://")):
        url = "https://" + url

    plugin_id = id_from_url(url)

    # --- name ---
    name: str = args.name
    if not name:
        print(f"[add-plugin] Fetching title from {url} ...", file=sys.stderr)
        name = fetch_title(url)
        if not name:
            name = plugin_id.capitalize()
            print(
                f"[add-plugin] Could not fetch title, using '{name}'", file=sys.stderr
            )
        else:
            print(f"[add-plugin] Title: {name}", file=sys.stderr)

    # --- plugin directory ---
    plugin_dir = os.path.join(PLUGINS_DIR, plugin_id)
    os.makedirs(plugin_dir, exist_ok=True)

    # --- favicon ---
    icon_field: str = args.icon or "language"
    icon_path_field: str | None = None

    print(f"[add-plugin] Fetching favicon ...", file=sys.stderr)
    favicon_data = fetch_favicon(url)
    if favicon_data:
        dest = os.path.join(plugin_dir, "icon.png")
        if _save_icon(favicon_data, dest):
            icon_path_field = "icon.png"
            print(f"[add-plugin] Favicon saved to {dest}", file=sys.stderr)
        else:
            print("[add-plugin] Could not save favicon, skipping", file=sys.stderr)
    else:
        print("[add-plugin] No favicon found, using symbol fallback", file=sys.stderr)

    # --- manifest ---
    manifest: dict = {
        "id": plugin_id,
        "name": name,
        "url": url,
        "icon": icon_field,
        "version": "1.0",
        "display": "tab",
    }
    if icon_path_field:
        manifest["iconPath"] = icon_path_field

    manifest_path = os.path.join(plugin_dir, "manifest.json")
    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")

    # Print result to stdout
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
