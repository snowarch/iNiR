#!/usr/bin/env python3
"""Extract dominant colors from an album art image for cava gradient.

Usage: extract_cover_colors.py <image_path> [count] [output_path]

Writes a JSON array of hex colors to output_path (default: cover-colors.json
in the quickshell state dir). Falls back gracefully if PIL is unavailable.
"""
import sys
import json
import os
from pathlib import Path
from collections import Counter

def quantize_colors(image_path: str, count: int = 8) -> list[str]:
    """Extract dominant colors using PIL quantization."""
    from PIL import Image

    img = Image.open(image_path).convert("RGB")
    # Resize for speed
    img = img.resize((150, 150), Image.LANCZOS)
    # Quantize to palette
    quantized = img.quantize(colors=count * 2, method=Image.Quantize.MEDIANCUT)
    palette = quantized.getpalette()
    if not palette:
        return []

    # Count pixel frequency per palette index
    pixel_counts = Counter(quantized.getdata())
    # Build (count, color) pairs
    ranked = []
    for idx, freq in pixel_counts.most_common():
        r, g, b = palette[idx * 3], palette[idx * 3 + 1], palette[idx * 3 + 2]
        # Skip very dark or very light colors (not useful for gradients)
        brightness = (r * 299 + g * 587 + b * 114) / 1000
        if brightness < 20 or brightness > 240:
            continue
        ranked.append(f"#{r:02x}{g:02x}{b:02x}")
        if len(ranked) >= count:
            break

    return ranked

def main():
    if len(sys.argv) < 2:
        print("Usage: extract_cover_colors.py <image_path> [count] [output_path]", file=sys.stderr)
        sys.exit(1)

    image_path = sys.argv[1]
    count = int(sys.argv[2]) if len(sys.argv) > 2 else 8

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
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    if len(colors) < 2:
        print("Not enough distinct colors found", file=sys.stderr)
        sys.exit(1)

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(colors, f)

    # Print for callers that want stdout
    print(json.dumps(colors))

if __name__ == "__main__":
    main()
