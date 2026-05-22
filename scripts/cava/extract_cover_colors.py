#!/usr/bin/env python3
"""Extract dominant colors from an album art image for cava gradient.

Usage: extract_cover_colors.py <image_path> [count] [output_path]

Writes a JSON array of hex colors to output_path (default: cover-colors.json
in the quickshell state dir). Falls back gracefully if PIL is unavailable.
"""
import colorsys
import json
import os
import sys
from collections import Counter
from pathlib import Path


def _hex(rgb: tuple[int, int, int]) -> str:
    return "#%02x%02x%02x" % rgb


def _saturate(rgb: tuple[int, int, int], factor: float = 1.35) -> tuple[int, int, int]:
    r, g, b = (c / 255.0 for c in rgb)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    s = min(1.0, s * factor)
    v = min(1.0, v * 1.08)
    r2, g2, b2 = colorsys.hsv_to_rgb(h, s, v)
    return int(r2 * 255), int(g2 * 255), int(b2 * 255)


def _brightness(rgb: tuple[int, int, int]) -> float:
    r, g, b = rgb
    return (r * 299 + g * 587 + b * 114) / 1000


def _rank_palette(palette: list[int], pixel_counts: Counter, count: int, min_b: float, max_b: float) -> list[str]:
    ranked: list[str] = []
    seen: set[str] = set()
    for idx, _freq in pixel_counts.most_common():
        r, g, b = palette[idx * 3], palette[idx * 3 + 1], palette[idx * 3 + 2]
        bness = _brightness((r, g, b))
        if bness < min_b or bness > max_b:
            continue
        hex_color = _hex(_saturate((r, g, b)))
        if hex_color in seen:
            continue
        seen.add(hex_color)
        ranked.append(hex_color)
        if len(ranked) >= count:
            break
    return ranked


def quantize_colors(image_path: str, count: int = 8) -> list[str]:
    """Extract dominant colors using PIL quantization."""
    from PIL import Image

    img = Image.open(image_path).convert("RGB")
    img = img.resize((150, 150), Image.LANCZOS)
    quantized = img.quantize(colors=max(count * 3, 12), method=Image.Quantize.MEDIANCUT)
    palette = quantized.getpalette()
    if not palette:
        return []

    pixel_counts = Counter(quantized.getdata())
    for min_b, max_b in ((20, 240), (10, 250), (0, 255)):
        ranked = _rank_palette(palette, pixel_counts, count, min_b, max_b)
        if len(ranked) >= min(2, count):
            return ranked[:count]

    return []


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: extract_cover_colors.py <image_path> [count] [output_path]", file=sys.stderr)
        sys.exit(1)

    image_path = sys.argv[1]
    count = int(sys.argv[2]) if len(sys.argv) > 2 else 8
    count = max(2, min(8, count))

    state_dir = os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state"))
    default_output = Path(state_dir) / "quickshell" / "user" / "generated" / "cover-colors.json"
    output_path = sys.argv[3] if len(sys.argv) > 3 else str(default_output)

    if not os.path.isfile(image_path):
        print(f"Image not found: {image_path}", file=sys.stderr)
        sys.exit(1)

    try:
        colors = quantize_colors(image_path, count)
    except ImportError:
        print("PIL not available, cannot extract colors", file=sys.stderr)
        sys.exit(1)
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)

    if len(colors) < 2:
        print("Not enough distinct colors found", file=sys.stderr)
        sys.exit(1)

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as handle:
        json.dump(colors, handle)

    print(json.dumps(colors))


if __name__ == "__main__":
    main()
