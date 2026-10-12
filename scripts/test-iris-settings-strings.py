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
LITERAL = re.compile(FIELDS + r':\s*"((?:[^"\\]|\\.)*)"')
TR = re.compile(r'Translation\.tr\("((?:[^"\\]|\\.)*)"\)')
SURFACES = sorted((ROOT / "modules" / "iris" / "settings").glob("*.qml")) + [
    ROOT / "modules" / "iris" / "wallpaper" / "IrisWallpaperPicker.qml",
]
# Literals that are names, not words (a font family shown in its own face).
NAMES = {"Alacritty", "btop", "foot", "Ghostty", "kitty", "Konsole", "lazygit", "Oh My Posh", "Starship", "WezTerm", "yazi", "Montserrat", "Space Grotesk", "PACIFIC DRIVE-IN", "iRiS", "PNG", "JPG", "WEBP", "AVIF", "BMP", "TIFF", "PDF", "GIF", "CPU", "GPU", "Kaishi 1.5k", "Manabi 2.7k", "Niponismo",
         "1080p", "720p", "480p", "2.4 GHz", "5 GHz", "5/5/26", "80%", "90%", "Bing", "Brave", "DuckDuckGo", "Startpage", "yande.re",
         "Gabarito", "Inter", "Inter Display", "Archivo", "Archivo SemiExpanded", "AIRISU", "Noto Sans", "Oxanium", "Rubik", "PipeWire", "PulseAudio", "Windows 11"}


def strings() -> dict[str, str]:
    found: dict[str, str] = {}
    for path in SOURCES:
        text = path.read_text(encoding="utf-8")
        for match in LITERAL.finditer(text):
            value = json.loads('"' + match.group(1) + '"')
            if value and value not in NAMES and not re.fullmatch(r"\d\d:\d\d", value) and not value.startswith("iris."):
                line = text.count("\n", 0, match.start()) + 1
                found.setdefault(value, f"{path.relative_to(ROOT)}:{line}")
    for path in SURFACES:
        text = path.read_text(encoding="utf-8")
        for match in TR.finditer(text):
            value = json.loads('"' + match.group(1) + '"')
            if value and value not in NAMES and not re.fullmatch(r"\d\d:\d\d", value):
                line = text.count("\n", 0, match.start()) + 1
                found.setdefault(value, f"{path.relative_to(ROOT)}:{line}")
    found.update({value: where for value, where in widget_rows().items() if value not in found})
    return found


# Settings › Widgets builds its rows from arguments, not `label:` fields: row(widget, key, "Label", …),
# edge(key, "Label", …), preset(widget, "Label", …), [value, "Label", …] choice and entry lists, and
# `name: "Words"` maps (groups, size names, captions).
WIDGET_ROWS = ROOT / "modules" / "iris" / "settings" / "IrisWidgetRows.qml"
WIDGET_PATTERNS = [
    re.compile(r'root\.row\("\w+", "[^"]*", "((?:[^"\\]|\\.)*)"'),
    re.compile(r'root\.(?:edge|preset)\("[^"]*", "((?:[^"\\]|\\.)*)"'),
    re.compile(r'\[(?:"[^"]*"|-?\d+|true|false), "((?:[^"\\]|\\.)*)"'),
    re.compile(r'\b\w+: "([A-Z](?:[^"\\]|\\.)*)"'),
]
IDENTIFIER = re.compile(r"^[a-z][A-Za-z0-9._]*$")
TIMEZONE = re.compile(r"^(?:Africa|America|Asia|Australia|Europe|Pacific)/")


def widget_rows() -> dict[str, str]:
    found: dict[str, str] = {}
    text = WIDGET_ROWS.read_text(encoding="utf-8")
    for pattern in WIDGET_PATTERNS:
        for match in pattern.finditer(text):
            value = json.loads('"' + match.group(1) + '"')
            if not value or value in NAMES or IDENTIFIER.match(value) or TIMEZONE.match(value) or value.startswith("#"):
                continue
            if not re.search(r"[A-Za-z]", value):
                continue
            line = text.count("\n", 0, match.start()) + 1
            found.setdefault(value, f"{WIDGET_ROWS.relative_to(ROOT)}:{line}")
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
