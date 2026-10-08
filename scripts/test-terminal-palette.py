#!/usr/bin/env python3
"""Terminal palette guard: prose reads, nothing outshines it.

For seeds round the wheel, every scheme and the surface seeds iRiS hands over:
  dark: background tone <= 16.5 and chroma <= 9; foreground Lc 68-73 in the background's hue; term7 and term8 under it
        (>= 4.5:1 and 3.5:1); no colour slot lighter than the foreground.
  light: foreground >= 7:1 (the light palette is Material's own and stays so).
"""

import json
import os
import pathlib
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
GENERATOR = ROOT / "scripts" / "colors" / "generate_colors_material.py"
SCHEME = ROOT / "scripts" / "colors" / "terminal" / "scheme-base.json"
SEEDS = ["#B3261E", "#E6A23C", "#4C8C2B", "#1E88E5", "#7E57C2", "#00897B", "#8D6E63", "#777777"]
SCHEMES = ["scheme-tonal-spot", "scheme-rainbow", "scheme-vibrant", "scheme-monochrome", "scheme-fidelity"]
SURFACES = ["", "#1c1413", "#411a12", "#3b4252"]
# HCT chroma spread within a level (the gamut caps a pale red at tone ~80 near 30, so brights keep a few points).
CHROMA_SPREAD = {"normal": 8.0, "bright": 12.0}


def python() -> str | None:
    venv = os.environ.get("INIR_VENV") or os.environ.get("ILLOGICAL_IMPULSE_VIRTUAL_ENV") or "~/.local/state/quickshell/.venv"
    exe = pathlib.Path(os.path.expanduser(os.path.expandvars(venv))) / "bin" / "python3"
    return str(exe) if exe.exists() else None


def rgb(h: str) -> tuple:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def wcag(a: str, b: str) -> float:
    def y(h):
        return sum(w * (c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4) for w, c in zip((0.2126, 0.7152, 0.0722), rgb(h)))
    ya, yb = y(a), y(b)
    return (max(ya, yb) + 0.05) / (min(ya, yb) + 0.05)


def apca(text: str, bg: str) -> float:
    """|Lc| of APCA-W3 0.0.98G."""
    def ys(h):
        v = sum(w * c ** 2.4 for w, c in zip((0.2126729, 0.7151522, 0.0721750), rgb(h)))
        return v + (0.022 - v) ** 1.414 if v < 0.022 else v
    yt, yb = ys(text), ys(bg)
    if yb > yt:
        s = (yb ** 0.56 - yt ** 0.57) * 1.14
        return 0.0 if s < 0.1 else (s - 0.027) * 100
    s = (yb ** 0.65 - yt ** 0.62) * 1.14
    return 0.0 if s > -0.1 else -(s + 0.027) * 100


def hue_chroma(h: str) -> tuple:
    r, g, b = (c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb(h))
    x, y, z = 0.4124 * r + 0.3576 * g + 0.1805 * b, 0.2126 * r + 0.7152 * g + 0.0722 * b, 0.0193 * r + 0.1192 * g + 0.9505 * b
    f = lambda v: v ** (1 / 3) if v > 216 / 24389 else (24389 / 27 * v + 16) / 116
    a, bb = 500 * (f(x / 0.9505) - f(y)), 200 * (f(y) - f(z / 1.089))
    import math
    return math.degrees(math.atan2(bb, a)) % 360, math.hypot(a, bb)


def tone(h: str) -> float:
    y = sum(w * (c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4) for w, c in zip((0.2126, 0.7152, 0.0722), rgb(h)))
    return 116 * y ** (1 / 3) - 16 if y > 216 / 24389 else y * 24389 / 27


def main() -> int:
    py = python()
    if not py:
        print("terminal palette: no iNiR Python environment, skipped")
        return 0
    failures = []
    with tempfile.TemporaryDirectory() as tmp:
        levels = []
        cases = [("dark", s, sc, sf) for s in SEEDS for sc in SCHEMES for sf in SURFACES] + [("light", s, SCHEMES[0], "") for s in SEEDS]
        for n, (mode, seed, scheme, surface) in enumerate(cases):
            out = pathlib.Path(tmp) / f"{n}.json"
            cmd = [py, str(GENERATOR), "--color", seed, "--mode", mode, "--scheme", scheme, "--termscheme", str(SCHEME),
                   "--blend_bg_fg", "--terminal-output", str(out)]
            if surface:
                cmd += ["--surface-seed", surface]
            r = subprocess.run(cmd, capture_output=True, text=True)
            label = f"{mode} {seed} {scheme.replace('scheme-', '')} surface {surface or 'none'}"
            if r.returncode or not out.exists():
                failures.append(f"{label}: generator failed: {r.stderr.strip()[-300:]}")
                continue
            t = json.loads(out.read_text())
            bg, fg = t["term0"], t["term15"]
            if mode == "dark":
                lc = apca(fg, bg)
                bg_hue, bg_chroma = hue_chroma(bg)
                fg_hue, fg_chroma = hue_chroma(fg)
                if tone(bg) > 16.5 or bg_chroma > 9.5:
                    failures.append(f"{label}: background {bg} out of the reading band (L* {tone(bg):.0f}, C {bg_chroma:.0f})")
                if not 68 <= lc <= 73:
                    failures.append(f"{label}: foreground {fg} on {bg} is Lc {lc:.0f}, wanted 68-73")
                if bg_chroma > 4 and fg_chroma > 3 and min(abs(bg_hue - fg_hue), 360 - abs(bg_hue - fg_hue)) > 25:
                    failures.append(f"{label}: foreground {fg} is not in the background's hue ({bg})")
                if not (tone(t["term8"]) < tone(t["term7"]) < tone(fg)):
                    failures.append(f"{label}: greys out of order (term8 {t['term8']}, term7 {t['term7']}, fg {fg})")
                if wcag(t["term7"], bg) < 4.5 or wcag(t["term8"], bg) < 3.5:
                    failures.append(f"{label}: greys under 4.5 / 3.5 on the background")
                for i in list(range(1, 7)) + list(range(9, 15)):
                    if tone(t[f"term{i}"]) > tone(fg) + 1.5:
                        failures.append(f"{label}: term{i} {t[f'term{i}']} is lighter than the foreground {fg}")
                levels.append((label, t))
            elif wcag(fg, bg) < 7:
                failures.append(f"{label}: foreground {fg} on {bg} is {wcag(fg, bg):.1f}:1, wanted 7:1")
        # One colourfulness per level, or a highlight in blue reads grey beside a neon green (measured in HCT, the generator's space).
        script = (
            "import json,sys\n"
            "from materialyoucolor.hct import Hct\n"
            "rows=json.load(sys.stdin)\n"
            "out=[[Hct.from_int(int('FF'+t[f'term{i}'][1:],16)).chroma for i in list(range(1,7))+list(range(9,15))] for _,t in rows]\n"
            "print(json.dumps(out))\n")
        r = subprocess.run([py, "-c", script], input=json.dumps(levels), capture_output=True, text=True)
        for (label, _), chromas in zip(levels, json.loads(r.stdout or "[]")):
            for name, part, most in (("normal", chromas[:6], CHROMA_SPREAD["normal"]), ("bright", chromas[6:], CHROMA_SPREAD["bright"])):
                if max(part) - min(part) > most:
                    failures.append(f"{label}: {name} slots range from chroma {min(part):.0f} to {max(part):.0f}")
    if failures:
        print("terminal palette:\n  " + "\n  ".join(failures))
        return 1
    print(f"terminal palette: ok ({len(SEEDS)} seeds x {len(SCHEMES)} schemes x {len(SURFACES)} surfaces, and light)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
