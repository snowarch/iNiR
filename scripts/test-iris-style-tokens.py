#!/usr/bin/env python3
"""iRiS style token guard.

iRiS surfaces read colour, translucency and corner values from
modules/iris/style/IrisStyle.qml (tokens and appearance presets). This guard
fails when a literal slips back into an iRiS consumer:

- hex colours ("#rrggbb") and numeric Qt.rgba(...) colours;
- decimal alpha literals in ColorUtils.applyAlpha(...), including conditional
  branches and variable inks (use fill/text tokens or tintFill/secondaryOf...);
- corner radii written as `N * density` instead of a radius token;
- text sizes from 10 to 17 px written as `N * typeScale` instead of a type token;
- more spacing off the 2·d grid than the recorded baseline;
- Qt5Compat.GraphicalEffects imports (use QtQuick.Effects MultiEffect).

A line that genuinely needs a literal (an illustration, a mock preview that
mirrors a style value) carries `// iris-literal: <reason>`. Only iRiS is
checked; ii and Waffle own their own systems.
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
IRIS = ROOT / "modules" / "iris"
EXEMPT_DIRS = {IRIS / "style"}

RULES = [
    ("hex colour", re.compile(r'"#[0-9a-fA-F]{3,8}"')),
    ("numeric Qt.rgba", re.compile(r"Qt\.rgba\(\s*[\d.]+\s*,\s*[\d.]+\s*,\s*[\d.]+\s*,")),
    # Any decimal alpha literal inside applyAlpha(...), also inside a condition
    # or on a variable ink: states and label steps are tokens or IrisStyle helpers.
    ("literal alpha", re.compile(r"applyAlpha\((?:[^()]|\([^()]*\))*?[,?:]\s*0?\.\d*[1-9]\d*\s*[):]")),
    # Effects are QtQuick.Effects (MultiEffect): Qt5Compat chains offscreen
    # passes and its hideSource toggles are fragile inside clipping chassis.
    ("Qt5Compat effect", re.compile(r"^\s*import\s+Qt5Compat\.GraphicalEffects")),
    ("literal corner radius", re.compile(
        r"\b\w*[Rr]adius\w*\s*:\s*(?:Math\.round\()?\s*\d+(?:\.\d+)?\s*\*\s*(?:root\.d|stage\.d|IrisStyle\.density)\b")),
    # Text from 10 to 17 px is the type ladder (typeCaption … typeTitle). Figures, clocks and
    # sizes scaled by something else (clockScale) stay free.
    ("type size off the ladder", re.compile(
        r"pixelSize\s*:\s*(?:Math\.round\()?\s*(?:9\.5|1[0-57](?:\.\d+)?|16\.\d+)\s*\*\s*IrisStyle\.typeScale\s*\)?\s*(?:$|[;}])")),
]

# Spacing sits on the 2·d grid. Odd or half steps that predate the rule are counted, never added to.
SPACING = re.compile(r"\b\w*(?:spacing|[Mm]argins?|[Pp]adding)\w*\s*:\s*Math\.round\(\s*(\d+(?:\.\d+)?)\s*\*\s*(?:\w+\.)?(?:d|density)\b")
SPACING_OFF_GRID_BASELINE = 29


# A property named on + Capital whose lowercase twin is declared in the same file (`onAccent` beside `accent`) is read
# from outside as the twin's handler: it comes back black, and hid the white ink on every accent fill of the light scheme.
ON_PROPERTY = re.compile(r"^\s*(?:readonly\s+)?property\s+\w+\s+on([A-Z]\w*)\s*:", re.M)


def on_twins(text: str) -> list[str]:
    names = []
    for match in ON_PROPERTY.finditer(text):
        twin = match.group(1)[0].lower() + match.group(1)[1:]
        if re.search(rf"^\s*(?:readonly\s+)?property\s+\w+\s+{twin}\s*:", text, re.M):
            names.append(f"on{match.group(1)} beside {twin}")
    return names


def main() -> int:
    failures = []
    off_grid = []
    for path in sorted(IRIS.rglob("*.qml")):
        for name in on_twins(path.read_text(encoding="utf-8")):
            failures.append(f"{path.relative_to(ROOT)}: on+Capital property reads black from outside ({name}); "
                            "name it for what it is, e.g. inkOnAccent")
    for path in sorted(IRIS.rglob("*.qml")):
        if any(parent in EXEMPT_DIRS for parent in path.parents):
            continue
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if "iris-literal:" in line:
                continue
            for match in SPACING.finditer(line):
                step = float(match.group(1))
                if step != int(step) or int(step) % 2:
                    off_grid.append(f"{path.relative_to(ROOT)}:{number}: {line.strip()[:140]}")
            for name, pattern in RULES:
                if pattern.search(line):
                    failures.append(f"{path.relative_to(ROOT)}:{number}: {name}: {line.strip()[:140]}")
    if len(off_grid) > SPACING_OFF_GRID_BASELINE:
        failures.append(f"spacing off the 2·d grid: {len(off_grid)} lines, baseline {SPACING_OFF_GRID_BASELINE}"
                        " (use an even step; lower the baseline when you fix one)")
        failures.extend("  " + line for line in off_grid)
    elif len(off_grid) < SPACING_OFF_GRID_BASELINE:
        print(f"note: spacing off the grid dropped to {len(off_grid)}; lower SPACING_OFF_GRID_BASELINE")
    if failures:
        print("FAIL: iRiS consumers must use IrisStyle tokens (or mark `// iris-literal: reason`):", file=sys.stderr)
        for failure in failures:
            print("  " + failure, file=sys.stderr)
        return 1
    print("iRiS style tokens: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
