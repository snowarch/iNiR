#!/usr/bin/env python3
"""Inject CSS into all Steam CEF browser contexts via Chrome DevTools Protocol.

Steam runs steamwebhelper with --remote-debugging-port=8080 by default on Linux.
This script reads a CSS file and injects it as a <style> element into every
open Steam page, producing an instant live theme update without killing
steamwebhelper (which causes ~3s flicker and doesn't reliably reload CSS
from disk anyway due to steamloopback.host caching).

Usage: steam-css-inject.py <css-file>
Exit 0 on success (at least one context injected), 1 on failure.
"""

import json
import sys
import asyncio

CDP_URL = "http://127.0.0.1:8080/json"
STYLE_ID = "inir-theme"


async def inject_into_page(ws_url: str, css: str) -> bool:
    try:
        import websockets
    except ImportError:
        return False
    try:
        async with websockets.connect(ws_url, max_size=2**20, open_timeout=2) as ws:
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


async def main(css_file: str) -> int:
    try:
        import websockets  # noqa: F401
    except ImportError:
        print("websockets not installed", file=sys.stderr)
        return 1

    with open(css_file) as f:
        css = f.read()

    import urllib.request

    try:
        with urllib.request.urlopen(CDP_URL, timeout=2) as r:
            pages = json.loads(r.read())
    except Exception:
        return 1

    tasks = []
    for page in pages:
        ws_url = page.get("webSocketDebuggerUrl", "")
        if ws_url:
            tasks.append(inject_into_page(ws_url, css))

    if not tasks:
        return 1

    results = await asyncio.gather(*tasks)
    injected = sum(1 for r in results if r)
    return 0 if injected > 0 else 1


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <css-file>", file=sys.stderr)
        sys.exit(1)
    sys.exit(asyncio.run(main(sys.argv[1])))
