#!/usr/bin/env python3
"""Auto light/dark guard.

switchwall.sh reads the brightness of the image the palette is drawn from and picks the mode. `fx:mean` averages every
channel, alpha included, so a PNG that carries an alpha channel (opaque or not) read (L + 1) / 2 and turned light
whatever it showed. This runs the command the script really contains on a dark and a light image, each with alpha.
"""

import pathlib
import re
import shlex
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "colors" / "switchwall.sh"


def luminance(args: list[str], path: pathlib.Path) -> float:
    out = subprocess.run(["magick", f"{path}[0]", *args, "info:"], capture_output=True, text=True, check=True)
    return float(out.stdout.strip())


def main() -> int:
    if not shutil.which("magick"):
        print("wallpaper mode: magick not installed, skipped")
        return 0
    match = re.search(r'magick "\$\{lum_source\}\[0\]" (.*?) info:', SCRIPT.read_text(encoding="utf-8"))
    if not match:
        print("FAIL: switchwall.sh no longer reads the brightness with magick ... info:", file=sys.stderr)
        return 1
    args = shlex.split(match.group(1).replace("\\!", "!"))
    failures = []
    with tempfile.TemporaryDirectory() as tmp:
        for name, colour, dark in (("dark", "#504D3C", True), ("light", "#E8E4D8", False)):
            image = pathlib.Path(tmp) / f"{name}.png"
            subprocess.run(["magick", "-size", "64x64", f"xc:{colour}", "-alpha", "on", f"PNG32:{image}"], check=True)
            channels = subprocess.run(["magick", "identify", "-format", "%[channels]", str(image)],
                                      capture_output=True, text=True, check=True).stdout
            if "a" not in channels.split()[0][-1:]:
                failures.append(f"could not make a {name} PNG with an alpha channel (got {channels!r})")
                continue
            level = luminance(args, image)
            if (level < 0.5) != dark:
                failures.append(f"a {name} image with an alpha channel reads {level:.3f}: the mode would be "
                                f"{'dark' if level < 0.5 else 'light'}")
    if failures:
        print("FAIL: Auto light/dark reads the wrong brightness:", file=sys.stderr)
        for failure in failures:
            print("  " + failure, file=sys.stderr)
        return 1
    print("wallpaper mode: brightness ignores the alpha channel")
    return 0


if __name__ == "__main__":
    sys.exit(main())
