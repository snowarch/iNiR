#!/usr/bin/env python3
"""Inject CSS into Pear Desktop (YouTube Music) via Chrome DevTools Protocol.

Pear Desktop must be launched with --remote-debugging-port=9222 for this to work.
The script reads a CSS file and injects it as a <style> element into every
open page context, producing an instant live theme update.

Usage: pear-css-inject.py <css-file> [--port PORT]
Exit 0 on success (at least one context injected), 1 on failure.
"""

import json
import sys
import asyncio
import argparse

DEFAULT_PORT = 9222
STYLE_ID = "inir-pear-theme"


async def inject_into_page(ws_url: str, css: str) -> bool:
    """Inject CSS into a single page context via WebSocket."""
    try:
        import websockets
    except ImportError:
        return False
    try:
        async with websockets.connect(ws_url, max_size=2**20, open_timeout=2) as ws:
            # JavaScript to inject/replace our style element
            js = (
                "(function(){"
                f"var e=document.getElementById('{STYLE_ID}');"
                "if(e)e.remove();"
                "var s=document.createElement('style');"
                f"s.id='{STYLE_ID}';"
                f"s.textContent={json.dumps(css)};"
                "if(document.head)document.head.appendChild(s);"
                "return !!document.head;"
                "})()"
            )
            await ws.send(
                json.dumps(
                    {
                        "id": 1,
                        "method": "Runtime.evaluate",
                        "params": {"expression": js, "returnByValue": True},
                    }
                )
            )
            resp = json.loads(await asyncio.wait_for(ws.recv(), timeout=3))
            val = resp.get("result", {}).get("result", {}).get("value", False)
            return bool(val)
    except Exception:
        return False


async def main(css_file: str, port: int) -> int:
    """Main injection routine."""
    try:
        import websockets  # noqa: F401
    except ImportError:
        print("websockets not installed", file=sys.stderr)
        return 1

    try:
        with open(css_file) as f:
            css = f.read()
    except IOError as e:
        print(f"Cannot read CSS file: {e}", file=sys.stderr)
        return 1

    import urllib.request

    cdp_url = f"http://127.0.0.1:{port}/json"
    try:
        with urllib.request.urlopen(cdp_url, timeout=2) as r:
            pages = json.loads(r.read())
    except Exception:
        # CDP not available — pear-desktop probably not running with debug port
        return 1

    # Filter to only YouTube Music pages (avoid injecting into random tabs)
    tasks = []
    for page in pages:
        ws_url = page.get("webSocketDebuggerUrl", "")
        url = page.get("url", "")
        # Inject into music.youtube.com pages and the main app frame
        if ws_url and (
            "music.youtube.com" in url
            or "youtube-music" in url.lower()
            or url.startswith("about:blank")
        ):
            tasks.append(inject_into_page(ws_url, css))

    if not tasks:
        return 1

    results = await asyncio.gather(*tasks)
    injected = sum(1 for r in results if r)
    return 0 if injected > 0 else 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Inject CSS into Pear Desktop via CDP")
    parser.add_argument("css_file", help="Path to CSS file to inject")
    parser.add_argument(
        "--port",
        type=int,
        default=DEFAULT_PORT,
        help=f"CDP port (default: {DEFAULT_PORT})",
    )
    args = parser.parse_args()
    sys.exit(asyncio.run(main(args.css_file, args.port)))
