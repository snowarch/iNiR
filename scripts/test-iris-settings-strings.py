#!/usr/bin/env python3
"""iRiS Settings strings guard.

Every word iRiS Settings shows from its registries (row labels and descriptions,
group names, section titles and tips, piece labels and descriptions) is a
literal in modules/iris/settings/IrisOptions.qml or modules/iris/pieces/IrisPieces.qml
that reaches the screen through Translation.tr(). A literal with no entry in a
catalogue shows in English in that language (2026-10-11: every bubble description
under Settings › Bubbles and Anime › Airing was in English in all 18 catalogues).
This guard fails when a complete catalogue lacks one of them. The surface's own
words (every Translation.tr("…") literal in modules/iris/settings and the iRiS
wallpaper gallery) are checked the same way: "Fine-tune" shipped in English once
because only the registries were read.
"""

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCES = [
    ROOT / "modules" / "iris" / "settings" / "IrisOptions.qml",
    ROOT / "modules" / "iris" / "pieces" / "IrisPieces.qml",
]
# Catalogues still being filled in; checked for nothing here.
PARTIAL = {"kl_GL"}
FIELDS = r"(?:label|description|tip|subtitle|title|group|note)"
LITERAL = re.compile(FIELDS + r': "((?:[^"\\]|\\.)*)"')
TR = re.compile(r'Translation\.tr\("((?:[^"\\]|\\.)*)"\)')
SURFACES = sorted((ROOT / "modules" / "iris" / "settings").glob("*.qml")) + [
    ROOT / "modules" / "iris" / "wallpaper" / "IrisWallpaperPicker.qml",
]
# Literals that are names, not words (a font family shown in its own face).
NAMES = {"Montserrat"}


def strings() -> dict[str, str]:
    found: dict[str, str] = {}
    for path in SOURCES:
        text = path.read_text(encoding="utf-8")
        for match in LITERAL.finditer(text):
            value = json.loads('"' + match.group(1) + '"')
            if value and value not in NAMES and not value.startswith("iris."):
                line = text.count("\n", 0, match.start()) + 1
                found.setdefault(value, f"{path.relative_to(ROOT)}:{line}")
    for path in SURFACES:
        text = path.read_text(encoding="utf-8")
        for match in TR.finditer(text):
            value = json.loads('"' + match.group(1) + '"')
            if value and value not in NAMES:
                line = text.count("\n", 0, match.start()) + 1
                found.setdefault(value, f"{path.relative_to(ROOT)}:{line}")
    return found


def main() -> int:
    wanted = strings()
    failures = []
    for catalogue in sorted((ROOT / "translations").glob("*.json")):
        if catalogue.stem in PARTIAL:
            continue
        entries = json.loads(catalogue.read_text(encoding="utf-8"))
        for value, where in wanted.items():
            if value not in entries:
                failures.append(f"{catalogue.stem}: {where}: {value!r}")
    if failures:
        print(f"iRiS Settings strings missing from catalogues ({len(failures)}):")
        for failure in failures[:60]:
            print("  " + failure)
        return 1
    print(f"iRiS Settings strings: {len(wanted)} in every complete catalogue")
    return 0


if __name__ == "__main__":
    sys.exit(main())
