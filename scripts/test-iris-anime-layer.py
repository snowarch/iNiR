#!/usr/bin/env python3
"""iRiS anime colour layer guard.

The anime layer is a pure transform in `IrisStyle.qml`: a base accent/highlight
resolver, the optional palette blend, and the on/off gates that decide whether
the layer touches the accent and the highlight. This guard extracts those exact
expressions from the owner and runs them in a Qt 6 QML test, so the gates and
the preview/live equivalence are executed, not inferred from strings.

Case coverage: layer off, strength 0, strength 60/100, highlight off and on,
accent-linked highlight, custom/theme/wallpaper bases, malformed palette names
(inherited object keys included) and malformed strength.

Skips only when no Qt 6 qmltestrunner can be found; once a runner is confirmed,
any harness failure is a failure.
"""

import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
STYLE = ROOT / "modules" / "iris" / "style" / "IrisStyle.qml"
COLOR_UTILS = ROOT / "modules" / "common" / "functions" / "ColorUtils.qml"
THEMES = ROOT / "modules" / "iris" / "settings" / "IrisThemes.qml"
OPTIONS = ROOT / "modules" / "iris" / "settings" / "IrisOptions.qml"
SETTINGS = ROOT / "modules" / "iris" / "settings" / "IrisSettings.qml"
EDIT_BAR = ROOT / "modules" / "iris" / "edit" / "IrisEditBar.qml"
PIECES = ROOT / "modules" / "iris" / "pieces" / "IrisPieces.qml"

PALETTE_KEYS = ["sakura", "neo-tokyo", "unit-01", "magical-girl", "spirit-forest"]
FUNCTIONS = ["animePaletteEntry", "animeBlend", "animeAccent", "animeHighlight", "wrapHue",
             "accentFrom", "highlightFrom", "readableAccent", "readableHighlight"]
SLICES = [
    ("readonly property var accents:", "// A choice as this scheme would solve it"),
    ("readonly property string animeDefaultPalette:", "function animePaletteEntry("),
    ("readonly property var animeLayer:", "readonly property bool animeEnabled:"),
    ("readonly property bool animeEnabled:", "readonly property string animePaletteName:"),
    ("readonly property string animePaletteName:", "readonly property real animeStrength:"),
    ("readonly property real animeStrength:", "readonly property bool animeHighlightOn:"),
    ("readonly property bool animeHighlightOn:", "readonly property color baseAccent:"),
    ("readonly property color baseAccent:", "readonly property color accent:"),
    ("readonly property color accent:", "readonly property color inkOnAccent:"),
    ("readonly property color baseSecondaryAccent:", "readonly property color secondaryAccent:"),
    ("readonly property color secondaryAccent:", "readonly property string auraName:"),
]


def extract_balanced(text, marker, open_ch, close_ch):
    start = text.index(marker)
    depth = 0
    cursor = text.index(open_ch, start)
    end = cursor
    while end < len(text):
        char = text[end]
        if char == open_ch:
            depth += 1
        elif char == close_ch:
            depth -= 1
            if depth == 0:
                return text[start:end + 1]
        end += 1
    raise ValueError(f"unbalanced block after {marker!r}")


def extract_between(text, start_marker, end_marker):
    start = text.index(start_marker)
    end = text.index(end_marker, start + len(start_marker))
    return text[start:end].rstrip()


def build_harness():
    style = STYLE.read_text(encoding="utf-8")
    colors = COLOR_UTILS.read_text(encoding="utf-8")
    parts = [extract_balanced(style, "readonly property var animePalettes", "(", ")")]
    parts += [extract_between(style, start, end) for start, end in SLICES]
    parts += [extract_balanced(style, f"function {name}(", "{", "}") for name in FUNCTIONS]
    mix = extract_balanced(colors, "function mix(", "{", "}")

    # Ids cannot start uppercase in QML; the owner's ColorUtils/Appearance are
    # singleton types. Only the dependency qualifier is rewritten, never the logic.
    body = "\n    ".join(parts).replace("ColorUtils.", "colorUtils.").replace("Appearance.", "appearanceStub.").replace("Lume.", "lumeStub.")

    return f"""import QtQuick
import QtTest

TestCase {{
    id: root
    name: "IrisAnimeLayer"

    property var appearance: ({{}})
    readonly property color base: Qt.color("#a8c7fa")
    // The scheme tuning is not under test: this is the dark scheme at full colour.
    readonly property bool light: false
    readonly property bool ink: false
    readonly property bool followsTheme: false
    readonly property real markLevel: 0.1
    // The solved palette (scripts/colors/washi) as the shell receives it: one swatch per choice, custom at the hue in use.
    readonly property var washi: ({{
        accents: {{ blue: "#8bb9ff", mint: "#6fdcb4", rose: "#ffa8b8", lilac: "#c9b3ff", theme: "#9ec2ff", wallpaper: "#8fb8e8",
            custom: Qt.hsla(root.wrapHue(root.appearance?.theme?.accentHue, 212), 0.7, 0.78, 1).toString() }},
        highlights: {{ orange: "#ff9f45", yellow: "#f0c64a", red: "#ff8a7a", pink: "#ff8fb0", green: "#6fd88a", theme: "#f5b860",
            wallpaper: "#e9a87a", custom: Qt.hsla(root.wrapHue(root.appearance?.theme?.highlightHue, 32), 0.92, 0.7, 1).toString() }}
    }})

    {body}

    QtObject {{
        id: colorUtils
        {mix}
    }}

    QtObject {{
        id: lumeStub
        function mark(c, level, spread, dark, contrast) {{ return c }}
    }}

    QtObject {{
        id: appearanceStub
        readonly property var colors: ({{ colPrimary: "#4285f4", colSecondary: "#ea4335", colTertiary: "#fbbc05" }})
        readonly property color wallpaperDominantColor: "#336699"
    }}

    function same(a, b) {{
        // QML colours round-trip through 16-bit channels; 0.003 is well below one
        // perceptible step and far below any palette difference.
        return Math.abs(a.r - b.r) < 0.003 && Math.abs(a.g - b.g) < 0.003
            && Math.abs(a.b - b.b) < 0.003 && Math.abs(a.a - b.a) < 0.003
    }}

    function inputs(accent, highlight, accentHue, highlightHue, anime) {{
        return {{ accent: accent, highlight: highlight,
            theme: {{ accentHue: accentHue, highlightHue: highlightHue }}, anime: anime }}
    }}

    function test_off_is_the_configured_colours() {{
        for (const pair of [["blue", "orange"], ["custom", "custom"], ["theme", "accent"], ["wallpaper", "wallpaper"], ["mint", "pink"]]) {{
            root.appearance = root.inputs(pair[0], pair[1], 200, 40, {{ enabled: false, palette: "spirit-forest", strength: 100, highlight: true }})
            verify(root.same(root.accent, root.baseAccent), pair + " accent off")
            verify(root.same(root.secondaryAccent, root.baseSecondaryAccent), pair + " highlight off")
            verify(root.same(root.secondaryAccent, root.highlightFrom(String(pair[1]), 40, root.baseAccent)), pair + " configured highlight")
        }}
    }}

    function test_strength_zero_is_the_base() {{
        root.appearance = root.inputs("custom", "accent", 200, 40, {{ enabled: true, palette: "spirit-forest", strength: 0, highlight: true }})
        verify(root.same(root.accent, root.baseAccent))
        verify(root.same(root.secondaryAccent, root.baseSecondaryAccent))
        verify(root.same(root.baseSecondaryAccent, root.baseAccent), "linked highlight keeps its base")
    }}

    function test_highlight_off_does_not_follow_the_accent() {{
        for (const palette of ["sakura", "neo-tokyo", "magical-girl"]) {{
            root.appearance = root.inputs("custom", "accent", 200, 40, {{ enabled: true, palette: palette, strength: 60, highlight: false }})
            verify(root.same(root.accent, root.animeAccent(root.baseAccent, palette, 0.6)), palette + " accent on")
            verify(root.same(root.secondaryAccent, root.baseSecondaryAccent), palette + " highlight unchanged")
            verify(!root.same(root.secondaryAccent, root.accent), palette + " linked highlight stays put")
        }}
    }}

    function test_highlight_on_follows_the_palette() {{
        for (const pair of [["blue", "orange"], ["custom", "accent"], ["theme", "custom"], ["wallpaper", "wallpaper"]]) {{
            root.appearance = root.inputs(pair[0], pair[1], 200, 40, {{ enabled: true, palette: "spirit-forest", strength: 60, highlight: true }})
            verify(root.same(root.accent, root.animeAccent(root.baseAccent, "spirit-forest", 0.6)), pair + " accent")
            verify(root.same(root.secondaryAccent, root.animeHighlight(root.baseSecondaryAccent, "spirit-forest", 0.6)), pair + " highlight")
        }}
    }}

    function test_preview_equals_live() {{
        const cases = [
            {{ accent: "custom", hueA: 300, highlight: "custom", hueH: 20, anime: {{ enabled: true, palette: "magical-girl", strength: 60, highlight: true }} }},
            {{ accent: "custom", hueA: 120, highlight: "accent", hueH: 0, anime: {{ enabled: true, palette: "spirit-forest", strength: 60, highlight: false }} }},
            {{ accent: "theme", hueA: 0, highlight: "theme", hueH: 0, anime: {{ enabled: true, palette: "sakura", strength: 100, highlight: true }} }},
            {{ accent: "wallpaper", hueA: 0, highlight: "wallpaper", hueH: 0, anime: {{ enabled: false, palette: "unit-01", strength: 60, highlight: false }} }}
        ]
        for (const item of cases) {{
            const v = {{ "iris.appearance.accent": item.accent, "iris.appearance.theme.accentHue": item.hueA,
                "iris.appearance.highlight": item.highlight, "iris.appearance.theme.highlightHue": item.hueH,
                "iris.appearance.anime.enabled": item.anime.enabled, "iris.appearance.anime.palette": item.anime.palette,
                "iris.appearance.anime.strength": item.anime.strength, "iris.appearance.anime.highlight": item.anime.highlight }}
            root.appearance = root.inputs(item.accent, item.highlight, item.hueA, item.hueH, item.anime)
            const previewBaseAccent = root.accentFrom(String(v["iris.appearance.accent"]), v["iris.appearance.theme.accentHue"])
            const on = Boolean(v["iris.appearance.anime.enabled"])
            const palette = String(v["iris.appearance.anime.palette"])
            const strength = Number(v["iris.appearance.anime.strength"]) / 100
            const previewAccent = on ? root.animeAccent(previewBaseAccent, palette, strength) : previewBaseAccent
            const previewBaseHighlight = root.highlightFrom(String(v["iris.appearance.highlight"]), v["iris.appearance.theme.highlightHue"], previewBaseAccent)
            const previewHighlight = on && Boolean(v["iris.appearance.anime.highlight"])
                ? root.animeHighlight(previewBaseHighlight, palette, strength) : previewBaseHighlight
            verify(root.same(previewBaseAccent, root.baseAccent), "preview base accent")
            verify(root.same(previewAccent, root.accent), "preview accent")
            verify(root.same(previewBaseHighlight, root.baseSecondaryAccent), "preview base highlight")
            verify(root.same(previewHighlight, root.secondaryAccent), "preview highlight")
        }}
    }}

    function test_malformed_palette_falls_back() {{
        const names = ["__proto__", "constructor", "toString", "hasOwnProperty", "valueOf", "not-a-palette", ""]
        for (const name of names) {{
            verify(root.animePaletteEntry(name).label === root.animePalettes.sakura.label, name + " entry")
            verify(root.same(root.animeAccent(root.base, name, 1), root.animeAccent(root.base, "sakura", 1)), name + " accent")
            verify(root.same(root.animeHighlight(root.base, name, 1), root.animeHighlight(root.base, "sakura", 1)), name + " highlight")
            verify(root.same(root.animeAccent(root.base, name, 0), root.base), name + " off")
        }}
        root.appearance = root.inputs("blue", "orange", 0, 0, {{ enabled: true, palette: "constructor", strength: 100, highlight: false }})
        verify(root.animePaletteName === "sakura", "name rejects constructor")
        root.appearance = root.inputs("blue", "orange", 0, 0, {{ enabled: true, palette: "__proto__", strength: 100, highlight: false }})
        verify(root.animePaletteName === "sakura", "name rejects __proto__")
    }}

    function test_strength_is_clamped() {{
        verify(root.same(root.animeAccent(root.base, "sakura", NaN), root.base))
        verify(root.same(root.animeAccent(root.base, "sakura", -4), root.base))
        verify(root.same(root.animeAccent(root.base, "sakura", 9), root.animeAccent(root.base, "sakura", 1)))
    }}

    function test_palettes_are_distinct() {{
        const seen = []
        for (const key in root.animePalettes) {{
            const swatch = root.animeAccent(root.base, key, 1)
            for (const other of seen)
                verify(Math.abs(swatch.r - other.color.r) + Math.abs(swatch.g - other.color.g) + Math.abs(swatch.b - other.color.b) > 0.08,
                    key + " differs from " + other.key)
            seen.push({{ key: key, color: swatch }})
        }}
    }}
}}
"""


PROBE = """import QtQuick
import QtTest

TestCase {
    name: "Probe"
    function test_ok() { verify(true) }
}
"""


def runner_candidates():
    return [path for path in [
        os.environ.get("QMLTESTRUNNER", ""),
        "/usr/lib/qt6/bin/qmltestrunner",
        "/usr/lib64/qt6/bin/qmltestrunner",
        "/usr/lib/x86_64-linux-gnu/qt6/bin/qmltestrunner",
        shutil.which("qmltestrunner") or "",
    ] if path and os.path.exists(path)]


def run_test(runner, source):
    with tempfile.TemporaryDirectory(prefix="inir-anime-") as folder:
        (pathlib.Path(folder) / "tst_iris.qml").write_text(source, encoding="utf-8")
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QML_DISABLE_DISK_CACHE="1")
        done = subprocess.run([runner, "-input", folder], capture_output=True, text=True, env=env)
        return done.returncode, done.stdout + done.stderr


def find_qt6_runner():
    for candidate in runner_candidates():
        try:
            _, output = run_test(candidate, PROBE)
        except OSError:
            continue
        if "Using QtTest library 6" in output:
            return candidate
    return None


def structural_failures():
    failures = []
    style = STYLE.read_text(encoding="utf-8")
    themes = THEMES.read_text(encoding="utf-8")
    options = OPTIONS.read_text(encoding="utf-8")
    settings = SETTINGS.read_text(encoding="utf-8")
    edit_bar = EDIT_BAR.read_text(encoding="utf-8")
    pieces = PIECES.read_text(encoding="utf-8")

    if "Config.setNestedValue" in style:
        failures.append("IrisStyle.qml writes Config; the anime layer must be a pure transform")
    for needle in ["Object.prototype.hasOwnProperty.call(root.animePalettes", "root.accentFrom(", "root.highlightFrom(",
                   "String(root.appearance?.accent", "String(root.appearance?.highlight"]:
        if needle not in style:
            failures.append(f"IrisStyle.qml no longer owns/validates the base colour path ({needle})")

    for path in ["iris.bubbles.extras.anime.enable", "iris.anime.shows"]:
        if path not in themes:
            failures.append(f"IrisThemes.qml does not exclude content path {path} from theme ownership")
    if "colourOf" in themes:
        failures.append("IrisThemes.qml still carries a second colour resolver")
    for needle in ["IrisStyle.accentFrom(", "IrisStyle.highlightFrom(", "IrisStyle.animeAccent(", "IrisStyle.animeHighlight("]:
        if needle not in themes:
            failures.append(f"IrisThemes.swatch no longer uses the shared resolver ({needle})")

    expected_rows = {
        "iris.appearance.anime.enabled": "false",
        "iris.appearance.anime.palette": '"sakura"',
        "iris.appearance.anime.strength": "60",
        "iris.appearance.anime.highlight": "false",
        "iris.bubbles.extras.anime.enable": "false",
        "iris.anime.shows": "5",
    }
    for path, fallback in expected_rows.items():
        row = re.search(r'path: "' + re.escape(path) + r'"[^\n]*?fallback: ?([^,}\n]+)', options)
        if not row:
            failures.append(f"IrisOptions.qml lacks the row {path}")
        elif row.group(1).strip() != fallback:
            failures.append(f"IrisOptions.qml {path} fallback {row.group(1).strip()!r}, expected {fallback!r}")

    for colour in ["pink", "rose", "cyan", "magenta", "violet", "purple", "green", "gold", "amber"]:
        if f'"{colour}"' not in options:
            failures.append(f"IrisOptions.qml palette row does not search the visible colour {colour}")

    if "spec.keywords" not in settings:
        failures.append("iRiS Settings search no longer indexes row keywords, so anime/weeb/otaku do not match")
    if 'includes("anime")' not in edit_bar:
        failures.append("Customize's themes sheet lost its anime filter")

    if "wallpaper" in re.search(r'id: "anime".*?card: true', pieces, re.S).group(0):
        failures.append("IrisPieces Airing description still claims a wallpaper launch")
    if "wallpaper picker opens" in options:
        failures.append("IrisOptions Airing description still claims the wallpaper picker opens")
    for key in PALETTE_KEYS:
        token = f'"{key}":' if "-" in key else f"{key}:"
        if token not in style:
            failures.append(f"IrisStyle.qml lacks the anime palette {key}")
    return failures


def main():
    failures = structural_failures()
    if failures:
        print("iRiS anime layer contract broken:", file=sys.stderr)
        for failure in failures:
            print("  " + failure, file=sys.stderr)
        return 1

    runner = find_qt6_runner()
    if runner is None:
        print("iRiS anime layer: no Qt 6 qmltestrunner found; colour logic not executed")
        return 0

    code, output = run_test(runner, build_harness())
    if code != 0 or "FAIL!" in output:
        print("iRiS anime layer colour logic failed:", file=sys.stderr)
        print(output, file=sys.stderr)
        return 1
    print("iRiS anime layer: colour logic and contracts ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
