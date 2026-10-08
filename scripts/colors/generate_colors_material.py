#!/usr/bin/env -S\_/bin/sh\_-c\_"source\_\$(eval\_echo\_\${INIR_VENV:-\$ILLOGICAL_IMPULSE_VIRTUAL_ENV})/bin/activate&&exec\_python\_-E\_"\$0"\_"\$@""
import argparse
import math
import json
import os
import re
import sys

import numpy as np

try:
    import tomllib
except ModuleNotFoundError:
    tomllib = None
from PIL import Image
from materialyoucolor.quantize import QuantizeCelebi
from materialyoucolor.score.score import Score
from materialyoucolor.hct import Hct
from materialyoucolor.dynamiccolor.material_dynamic_colors import MaterialDynamicColors
from materialyoucolor.utils.color_utils import (
    rgba_from_argb,
    argb_from_rgb,
    argb_from_rgba,
)
from materialyoucolor.utils.math_utils import (
    sanitize_degrees_double,
    difference_degrees,
    rotation_direction,
)

parser = argparse.ArgumentParser(description="Color generation script")
parser.add_argument(
    "--path", type=str, default=None, help="generate colorscheme from image"
)
parser.add_argument("--size", type=int, default=128, help="bitmap image size")
parser.add_argument(
    "--color", type=str, default=None, help="generate colorscheme from color"
)
parser.add_argument(
    "--mode",
    type=str,
    choices=["dark", "light"],
    default="dark",
    help="dark or light mode",
)
parser.add_argument(
    "--scheme", type=str, default="vibrant", help="material scheme to use"
)
parser.add_argument(
    "--smart",
    action="store_true",
    default=False,
    help="decide scheme type based on image color",
)
parser.add_argument(
    "--transparency",
    type=str,
    choices=["opaque", "transparent"],
    default="opaque",
    help="enable transparency",
)
parser.add_argument(
    "--termscheme",
    type=str,
    default=None,
    help="JSON file containg the terminal scheme for generating term colors",
)
parser.add_argument(
    "--harmony", type=float, default=0.4, help="(0-1) Color hue shift towards accent"
)
parser.add_argument(
    "--harmonize_threshold",
    type=float,
    default=100,
    help="(0-180) Max threshold angle to limit color hue shift",
)
parser.add_argument(
    "--term_fg_boost",
    type=float,
    default=0.35,
    help="Make terminal foreground more different from the background",
)
parser.add_argument(
    "--term_saturation",
    type=float,
    default=0.65,
    help="Terminal color saturation (0.0-1.0)",
)
parser.add_argument(
    "--term_brightness",
    type=float,
    default=0.60,
    help="Terminal color brightness/lightness (0.0-1.0)",
)
parser.add_argument(
    "--term_bg_brightness",
    type=float,
    default=0.50,
    help="Terminal background brightness (0.0-1.0, 0=darkest, 1=lightest)",
)
parser.add_argument(
    "--blend_bg_fg",
    action="store_true",
    default=False,
    help="Shift terminal background or foreground towards accent",
)
parser.add_argument(
    "--cache", type=str, default=None, help="file path to store the generated color"
)
parser.add_argument(
    "--soften", action="store_true", default=False, help="soften generated colors"
)
parser.add_argument(
    "--debug", action="store_true", default=False, help="enable debug output"
)
parser.add_argument(
    "--json-output", type=str, default=None, help="file path to write colors.json"
)
parser.add_argument(
    "--palette-output", type=str, default=None, help="file path to write palette.json"
)
parser.add_argument(
    "--app-palette-output",
    type=str,
    default=None,
    help="file path to write app-palette.json",
)
parser.add_argument(
    "--terminal-output", type=str, default=None, help="file path to write terminal.json"
)
parser.add_argument(
    "--meta-output", type=str, default=None, help="file path to write theme-meta.json"
)
parser.add_argument(
    "--scss-output",
    type=str,
    default=None,
    help="file path to write material_colors.scss",
)
parser.add_argument(
    "--surface-seed",
    type=str,
    default=None,
    help="hex colour the neutral surfaces are anchored to (the shell's own material); accents stay from the source",
)
parser.add_argument(
    "--accent-seed",
    type=str,
    default=None,
    help="hex colour the accents are drawn from instead of the source (the shell's own accent)",
)
parser.add_argument(
    "--washi-roles",
    type=str,
    default=None,
    help="iris-surface.json whose 'roles' are iRiS's solved palette in Material role names: the apps wear them as they are",
)
parser.add_argument(
    "--render-templates",
    type=str,
    default=None,
    help="directory containing templates/ and templates.json (renders GTK/fuzzel/etc.)",
)
parser.add_argument(
    "--color-strength",
    type=float,
    default=1.0,
    help="multiplier for wallpaper-derived accent chroma (1.0 = default)",
)
parser.add_argument(
    "--invert-hue",
    action="store_true",
    default=False,
    help="Rotate seed color hue 180° before scheme generation (complementary palette)",
)
args = parser.parse_args()

rgba_to_hex = lambda rgba: "#{:02X}{:02X}{:02X}".format(rgba[0], rgba[1], rgba[2])
argb_to_hex = lambda argb: "#{:02X}{:02X}{:02X}".format(
    *map(round, rgba_from_argb(argb))
)
hex_to_argb = lambda hex_code: argb_from_rgb(
    int(hex_code[1:3], 16), int(hex_code[3:5], 16), int(hex_code[5:], 16)
)
display_color = lambda rgba: "\x1b[38;2;{};{};{}m{}\x1b[0m".format(
    rgba[0], rgba[1], rgba[2], "\x1b[7m   \x1b[7m"
)


def _auto_detect_scheme(pil_image):
    """Detect optimal material scheme from image statistics.
    Uses the same decision tree as scheme_for_image.py but operates on an
    already-loaded PIL image, avoiding a separate Python process + cv2 import."""
    arr = np.array(pil_image, dtype=np.float64)
    if arr.ndim != 3 or arr.shape[2] < 3:
        return "scheme-tonal-spot"

    R, G, B = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]

    # Colorfulness (Hasler-Süsstrunk metric)
    rg = np.absolute(R - G)
    yb = np.absolute(0.5 * (R + G) - B)
    colorfulness = float(
        np.sqrt(np.std(rg) ** 2 + np.std(yb) ** 2)
        + 0.3 * np.sqrt(np.mean(rg) ** 2 + np.mean(yb) ** 2)
    )

    # HSV via numpy (H scaled to 0-180 to match cv2 convention)
    r, g, b = R / 255.0, G / 255.0, B / 255.0
    maxc = np.maximum(np.maximum(r, g), b)
    minc = np.minimum(np.minimum(r, g), b)
    s = np.where(maxc > 0, (maxc - minc) / maxc, 0.0) * 255
    delta = maxc - minc
    h = np.zeros_like(r)
    with np.errstate(invalid="ignore", divide="ignore"):
        mask = delta > 0
        idx = (maxc == r) & mask
        h[idx] = 30.0 * (((g[idx] - b[idx]) / delta[idx]) % 6)
        idx = (maxc == g) & mask
        h[idx] = 30.0 * ((b[idx] - r[idx]) / delta[idx] + 2)
        idx = (maxc == b) & mask
        h[idx] = 30.0 * ((r[idx] - g[idx]) / delta[idx] + 4)

    saturation = float(np.mean(s))
    hue_spread = float(np.std(h))

    if saturation < 20:
        return "scheme-monochrome"
    if colorfulness < 30:
        if saturation < 55:
            return "scheme-neutral"
        if hue_spread < 22:
            return "scheme-content"
        return "scheme-tonal-spot"
    if colorfulness < 55:
        if hue_spread < 22 and saturation < 100:
            return "scheme-content"
        return "scheme-tonal-spot"
    if colorfulness < 90:
        if saturation > 140 and hue_spread < 35:
            return "scheme-fidelity"
        if hue_spread < 30:
            return "scheme-content"
        return "scheme-tonal-spot"
    if hue_spread > 55 and saturation > 150:
        return "scheme-rainbow"
    if saturation > 160:
        return "scheme-fidelity"
    if hue_spread > 45:
        return "scheme-expressive"
    return "scheme-tonal-spot"


def calculate_optimal_size(width: int, height: int, bitmap_size: int) -> (int, int):
    image_area = width * height
    bitmap_area = bitmap_size**2
    scale = math.sqrt(bitmap_area / image_area) if image_area > bitmap_area else 1
    new_width = round(width * scale)
    new_height = round(height * scale)
    if new_width == 0:
        new_width = 1
    if new_height == 0:
        new_height = 1
    return new_width, new_height


def harmonize(
    design_color: int, source_color: int, threshold: float = 35, harmony: float = 0.5
) -> int:
    from_hct = Hct.from_int(design_color)
    to_hct = Hct.from_int(source_color)
    difference_degrees_ = difference_degrees(from_hct.hue, to_hct.hue)
    rotation_degrees = min(difference_degrees_ * harmony, threshold)
    output_hue = sanitize_degrees_double(
        from_hct.hue + rotation_degrees * rotation_direction(from_hct.hue, to_hct.hue)
    )
    return Hct.from_hct(output_hue, from_hct.chroma, from_hct.tone).to_int()


def boost_chroma_tone(
    argb: int, chroma: float = 1, tone: float = 1, tone_cap: float = 95.0
) -> int:
    """Scale chroma and tone of a color.

    Args:
        argb: Input color in ARGB format
        chroma: Chroma multiplier (1 = no change)
        tone: Tone multiplier (1 = no change)
        tone_cap: Maximum tone value to prevent white-washing bright colors

    Returns:
        Adjusted color in ARGB format
    """
    hct = Hct.from_int(argb)
    new_tone = min(tone_cap, hct.tone * tone)
    return Hct.from_hct(hct.hue, hct.chroma * chroma, new_tone).to_int()


def ensure_min_chroma(argb: int, min_chroma: float = 40) -> int:
    """Ensure a color has minimum chroma for visual distinctiveness."""
    hct = Hct.from_int(argb)
    if hct.chroma < min_chroma:
        return Hct.from_hct(hct.hue, min_chroma, hct.tone).to_int()
    return argb


def scale_chroma(argb: int, factor: float, maximum: float | None = None) -> int:
    """Scale chroma while preserving hue/tone for stronger or calmer accent colors."""
    if abs(factor - 1.0) < 1e-6:
        return argb
    hct = Hct.from_int(argb)
    new_chroma = max(0.0, hct.chroma * factor)
    if maximum is not None:
        new_chroma = min(maximum, new_chroma)
    return Hct.from_hct(hct.hue, new_chroma, hct.tone).to_int()


def relative_luminance(argb: int) -> float:
    """Calculate relative luminance per WCAG 2.1 spec."""
    r = ((argb >> 16) & 0xFF) / 255.0
    g = ((argb >> 8) & 0xFF) / 255.0
    b = (argb & 0xFF) / 255.0

    def linearize(c):
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4

    return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)


def contrast_ratio(fg_argb: int, bg_argb: int) -> float:
    """Calculate WCAG contrast ratio between two colors."""
    l1 = relative_luminance(fg_argb)
    l2 = relative_luminance(bg_argb)
    lighter = max(l1, l2)
    darker = min(l1, l2)
    return (lighter + 0.05) / (darker + 0.05)


def find_tone_for_contrast(
    hue: float,
    chroma: float,
    start_tone: float,
    limit_tone: float,
    bg_argb: int,
    min_ratio: float,
    is_dark: bool,
    step: float = 0.25,
) -> tuple[int, float, bool, float]:
    """Search tone values for contrast.

    Returns:
        (color_argb, tone, met_min_ratio, achieved_ratio)
    """
    direction = 1.0 if is_dark else -1.0
    tone = start_tone
    max_steps = max(1, int(math.ceil(abs(limit_tone - start_tone) / step)) + 2)

    initial = Hct.from_hct(hue, chroma, max(0.0, min(100.0, start_tone))).to_int()
    best_color = initial
    best_tone = start_tone
    best_ratio = contrast_ratio(initial, bg_argb)

    for _ in range(max_steps):
        clamped_tone = max(0.0, min(100.0, tone))
        candidate = Hct.from_hct(hue, chroma, clamped_tone).to_int()
        ratio = contrast_ratio(candidate, bg_argb)

        if ratio > best_ratio:
            best_color = candidate
            best_tone = clamped_tone
            best_ratio = ratio

        if ratio >= min_ratio:
            return candidate, clamped_tone, True, ratio

        if is_dark and clamped_tone >= limit_tone:
            break
        if not is_dark and clamped_tone <= limit_tone:
            break

        tone += direction * step
        if is_dark and tone > limit_tone:
            tone = limit_tone
        if not is_dark and tone < limit_tone:
            tone = limit_tone

    return best_color, best_tone, False, best_ratio


def apca_lc(text_argb: int, bg_argb: int) -> float:
    """|Lc| of APCA-W3 0.0.98G: perceived contrast of text on a background, polarity-aware."""
    def ys(argb: int) -> float:
        r, g, b = ((argb >> 16) & 0xFF) / 255.0, ((argb >> 8) & 0xFF) / 255.0, (argb & 0xFF) / 255.0
        y = 0.2126729 * r ** 2.4 + 0.7151522 * g ** 2.4 + 0.0721750 * b ** 2.4
        return y + (0.022 - y) ** 1.414 if y < 0.022 else y
    yt, yb = ys(text_argb), ys(bg_argb)
    if yb > yt:
        s = (yb ** 0.56 - yt ** 0.57) * 1.14
        return 0.0 if s < 0.1 else (s - 0.027) * 100
    s = (yb ** 0.65 - yt ** 0.62) * 1.14
    return 0.0 if s > -0.1 else -(s + 0.027) * 100


def tone_for_lc(hue: float, chroma: float, bg_argb: int, lc: float) -> float:
    """The darkest tone, lighter than a dark background, whose text reaches `lc` on it."""
    lo, hi = Hct.from_int(bg_argb).tone, 100.0
    for _ in range(24):
        mid = (lo + hi) / 2
        if apca_lc(Hct.from_hct(hue, chroma, mid).to_int(), bg_argb) >= lc:
            hi = mid
        else:
            lo = mid
    return hi


TERM_READING_LC = {"term15": 70.0, "term7": 56.0, "term8": 42.0}
TERM_BG_TONE = (6.0, 16.0)
TERM_BG_CHROMA = 8.0


def solve_dark_terminal_reading(term_colors: dict, fg_boost: float) -> None:
    """Background in the reading band; foreground, term7 and term8 solved for their Lc in the background's hue;
    no colour slot lighter than the foreground (brights level with it, normals a step under)."""
    bg = Hct.from_int(hex_to_argb(term_colors["term0"]))
    bg_tone = max(TERM_BG_TONE[0], min(TERM_BG_TONE[1], bg.tone))
    bg_argb = Hct.from_hct(bg.hue, min(bg.chroma, TERM_BG_CHROMA), bg_tone).to_int()
    term_colors["term0"] = argb_to_hex(bg_argb)
    ink_chroma = min(Hct.from_int(bg_argb).chroma, 6.0)
    boost = max(-7.0, min(13.0, (fg_boost - 0.35) * 20.0))
    tones = {}
    for key, lc in TERM_READING_LC.items():
        tones[key] = tone_for_lc(bg.hue, ink_chroma, bg_argb, lc + boost * (1.0 if key == "term15" else 0.5))
        ink = Hct.from_hct(bg.hue, ink_chroma, tones[key]).to_int()
        floor = {"term15": 7.0, "term7": 4.5, "term8": 3.5}[key]
        term_colors[key] = argb_to_hex(ensure_contrast(ink, bg_argb, floor, True))
    fg_tone = Hct.from_int(hex_to_argb(term_colors["term15"])).tone
    # Every hue of a level carries the same colourfulness, or a highlight in blue reads grey beside a neon green.
    # Normals and brights each take one chroma, the gamut permitting.
    chromas = {}
    for i in list(range(1, 7)) + list(range(9, 15)):
        key = f"term{i}"
        if key in term_colors:
            chromas[key] = Hct.from_int(hex_to_argb(term_colors[key])).chroma
    level_chroma = {
        "normal": max(34.0, min(44.0, sorted(chromas.get(f"term{i}", 40.0) for i in range(1, 7))[3])),
        "bright": max(30.0, min(38.0, sorted(chromas.get(f"term{i}", 34.0) for i in range(9, 15))[3])),
    }
    for i in list(range(1, 7)) + list(range(9, 15)):
        key = f"term{i}"
        if key not in term_colors:
            continue
        c = Hct.from_int(hex_to_argb(term_colors[key]))
        cap = fg_tone if i >= 9 else fg_tone - 5.0
        chroma = level_chroma["bright" if i >= 9 else "normal"]
        evened = Hct.from_hct(c.hue, chroma, min(c.tone, cap)).to_int()
        term_colors[key] = argb_to_hex(ensure_contrast(evened, bg_argb, 3.5 if i >= 9 else 4.5, True))


def ensure_contrast(
    fg_argb: int,
    bg_argb: int,
    min_ratio: float = 4.5,
    is_dark: bool = True,
    tone_limit: float | None = None,
) -> int:
    """Adjust foreground tone to ensure minimum contrast ratio against background.

    For dark mode, increases tone (lighter). For light mode, decreases tone (darker).
    Preserves hue and boosts chroma when tone approaches extremes to prevent washed-out colors.
    """
    current_ratio = contrast_ratio(fg_argb, bg_argb)
    if current_ratio >= min_ratio:
        return fg_argb

    hct = Hct.from_int(fg_argb)
    original_tone = hct.tone
    original_chroma = hct.chroma

    # Tone limits to prevent colors from washing out to pure white/black.
    # If min ratio is unreachable inside limits, return highest-contrast option.
    if tone_limit is None:
        tone_limit = 88.0 if is_dark else 20.0

    best, best_tone, met_min, best_ratio = find_tone_for_contrast(
        hct.hue,
        hct.chroma,
        original_tone,
        tone_limit,
        bg_argb,
        min_ratio,
        is_dark,
    )

    # Compensate for tone shift by boosting chroma
    # When tone moves far from original, colors lose perceptual saturation
    # Boost chroma proportionally to maintain color identity
    tone_shift = abs(best_tone - original_tone)
    if tone_shift > 10:
        # Boost chroma by up to 40% for large tone shifts
        # The further we shift, the more we compensate
        boost_factor = 1.0 + min(0.4, (tone_shift - 10) / 50)
        boosted_chroma = min(original_chroma * boost_factor, 80.0)
        boosted_same_tone = Hct.from_hct(hct.hue, boosted_chroma, best_tone).to_int()
        boosted_ratio = contrast_ratio(boosted_same_tone, bg_argb)

        if met_min and boosted_ratio >= min_ratio:
            return boosted_same_tone

        boosted_best, _, boosted_met, boosted_best_ratio = find_tone_for_contrast(
            hct.hue,
            boosted_chroma,
            best_tone,
            tone_limit,
            bg_argb,
            min_ratio,
            is_dark,
        )

        if met_min:
            # Keep strict contrast if we already had a valid candidate.
            if boosted_met:
                return boosted_best
            return best

        # If target contrast is unreachable, keep the best achievable ratio.
        if boosted_best_ratio > best_ratio:
            return boosted_best

    return best


def mix_hex(color_a: str, color_b: str, keep_a: float = 0.5) -> str:
    a = color_a.lstrip("#")
    b = color_b.lstrip("#")
    ar, ag, ab = int(a[0:2], 16), int(a[2:4], 16), int(a[4:6], 16)
    br, bg, bb = int(b[0:2], 16), int(b[2:4], 16), int(b[4:6], 16)
    return "#{:02X}{:02X}{:02X}".format(
        round(ar * keep_a + br * (1 - keep_a)),
        round(ag * keep_a + bg * (1 - keep_a)),
        round(ab * keep_a + bb * (1 - keep_a)),
    )


def readable_hex(fg_hex: str, bg_hex: str, min_ratio: float = 4.5) -> str:
    bg_argb = hex_to_argb(bg_hex)
    is_bg_dark = Hct.from_int(bg_argb).tone < 50
    return argb_to_hex(ensure_contrast(hex_to_argb(fg_hex), bg_argb, min_ratio, is_bg_dark))


def build_app_palette(base_palette: dict[str, str]) -> dict[str, str]:
    layer0 = base_palette.get("background") or base_palette.get("surface") or "#000000"
    layer1 = base_palette.get("surface_container_low") or base_palette.get("surface") or layer0
    layer2 = base_palette.get("surface_container") or layer1
    layer3 = base_palette.get("surface_container_high") or layer2
    layer4 = base_palette.get("surface_container_highest") or layer3
    on_surface = base_palette.get("on_surface") or base_palette.get("on_background") or "#FFFFFF"
    on_surface_variant = base_palette.get("on_surface_variant") or on_surface
    primary = base_palette.get("primary") or "#6750A4"
    primary_container = base_palette.get("primary_container") or primary
    on_primary = base_palette.get("on_primary") or readable_hex(on_surface, primary, 4.5)
    outline = base_palette.get("outline") or on_surface_variant
    outline_variant = base_palette.get("outline_variant") or mix_hex(layer1, outline, 0.72)

    on_layer0 = readable_hex(on_surface, layer0, 4.5)
    # Body text is onSurface on every layer; the variant is for secondary text (app_subtext), never the main ink.
    on_layer1 = readable_hex(on_surface, layer1, 4.5)
    on_layer2 = readable_hex(on_surface, layer2, 4.5)
    on_layer3 = readable_hex(on_surface, layer3, 4.5)
    on_layer4 = readable_hex(on_surface, layer4, 4.5)
    layer1_hover = mix_hex(layer1, on_layer1, 0.92)
    layer1_active = mix_hex(layer1, on_layer1, 0.85)
    # Muted text on a light theme drops under 3:1 on hover and press fills, so
    # it is solved against the pressed fill; dark themes keep the 3:1 floor.
    if Hct.from_int(hex_to_argb(layer0)).tone >= 50:
        subtext = readable_hex(mix_hex(on_layer1, layer1, 0.75), layer1_active, 4.5)
    else:
        subtext = readable_hex(mix_hex(on_layer1, layer1, 0.75), layer1, 3.0)
    layer2_hover = mix_hex(layer2, on_layer2, 0.90)
    layer2_active = mix_hex(layer2, on_layer2, 0.80)
    layer3_hover = mix_hex(layer3, on_layer3, 0.90)
    layer3_active = mix_hex(layer3, on_layer3, 0.80)
    # Where you are is the accent's quiet sibling, the same in every app: the container's hue and tone at the strength
    # Material gives its secondary container. 18 % of the accent on grey read as no colour at all; 75 % of the container
    # (chroma 36-43) made every selected row, tab and menu item as loud as a button.
    # Its tone keeps a step from the window (12 dark, 10 light): over a frost-tinted paper the container's tone 90 was
    # the background's own, and the row stood out by colour alone (1.1:1).
    container_hct = Hct.from_int(hex_to_argb(primary_container))
    layer0_tone = Hct.from_int(hex_to_argb(layer0)).tone
    selection_tone = (max(container_hct.tone, layer0_tone + 12.0) if layer0_tone < 50
                      else min(container_hct.tone, layer0_tone - 10.0))
    selection = argb_to_hex(Hct.from_hct(container_hct.hue, min(container_hct.chroma, 20.0), selection_tone).to_int())
    selection_hover = argb_to_hex(Hct.from_hct(container_hct.hue, min(container_hct.chroma, 26.0), selection_tone).to_int())
    on_selection = readable_hex(on_layer3, selection, 4.5)

    is_dark = Hct.from_int(hex_to_argb(layer0)).tone < 50
    accent_hue = Hct.from_int(hex_to_argb(primary)).hue

    def status(hue: float, chroma: float) -> str:
        delta = ((accent_hue - hue + 180.0) % 360.0) - 180.0
        hue = (hue + max(-15.0, min(15.0, delta * 0.25))) % 360.0
        seed = Hct.from_hct(hue, chroma, 80.0 if is_dark else 40.0).to_int()
        return argb_to_hex(ensure_contrast(seed, hex_to_argb(layer0), 4.5, is_dark))

    success = status(145.0, 48.0)
    warning = status(75.0, 56.0)
    error = readable_hex(base_palette.get("error") or status(25.0, 60.0), layer0, 4.5)
    on_status = layer0

    app = dict(base_palette)
    app.update(
        {
            "background": layer0,
            "on_background": on_layer0,
            "surface": layer0,
            "on_surface": on_layer1,
            "surface_dim": layer0,
            "surface_bright": layer3,
            "surface_container_lowest": layer0,
            "surface_container_low": layer1,
            "surface_container": layer2,
            "surface_container_high": layer3,
            "surface_container_highest": layer4,
            "outline": outline,
            "outline_variant": outline_variant,
            "app_background": layer0,
            "app_foreground": on_layer0,
            "app_subtext": subtext,
            "app_surface": layer1,
            "app_surface_hover": layer1_hover,
            "app_surface_active": layer1_active,
            "app_surface_elevated": layer2,
            "app_surface_elevated_hover": layer2_hover,
            "app_surface_elevated_active": layer2_active,
            "app_surface_popup": layer3,
            "app_surface_popup_hover": layer3_hover,
            "app_surface_popup_active": layer3_active,
            "app_on_surface": on_layer1,
            "app_on_surface_elevated": on_layer2,
            "app_on_surface_popup": on_layer3,
            "app_on_surface_highest": on_layer4,
            "app_border": outline,
            "app_border_subtle": outline_variant,
            "app_accent": primary,
            "app_on_accent": on_primary,
            "app_accent_container": primary_container,
            "app_selection": selection,
            "app_selection_hover": selection_hover,
            "app_on_selection": on_selection,
            "app_success": success,
            "app_warning": warning,
            "app_error": error,
            "app_on_status": on_status,
            "app_window_bg": layer0,
            "app_view_bg": layer0,
            "app_headerbar_bg": layer0,
            "app_sidebar_bg": layer0,
            "app_card_bg": layer1,
            "app_popover_bg": layer2,
            "app_dialog_bg": layer3,
            "app_thumbnail_bg": layer4,
        }
    )
    return app


darkmode = args.mode == "dark"
transparent = args.transparency == "transparent"

if args.path is not None:
    image = Image.open(args.path)

    if image.format == "GIF":
        image.seek(1)

    if image.mode in ["L", "P"]:
        image = image.convert("RGB")
    wsize, hsize = image.size
    wsize_new, hsize_new = calculate_optimal_size(wsize, hsize, args.size)
    if wsize_new < wsize or hsize_new < hsize:
        image = image.resize((wsize_new, hsize_new), Image.Resampling.BICUBIC)
    # Auto-detect scheme from the already-resized image (avoids separate Python process)
    if args.scheme == "auto":
        args.scheme = _auto_detect_scheme(image)
    colors = QuantizeCelebi(list(image.getdata()), 128)
    argb = Score.score(colors)[0]

    if args.cache is not None:
        with open(args.cache, "w") as file:
            file.write(argb_to_hex(argb))
    hct = Hct.from_int(argb)
    if args.smart:
        if hct.chroma < 20:
            args.scheme = "scheme-neutral"
elif args.color is not None:
    argb = hex_to_argb(args.color)
    hct = Hct.from_int(argb)

if args.accent_seed and re.fullmatch(r"#?[0-9A-Fa-f]{6}", args.accent_seed.strip()):
    argb = hex_to_argb("#" + args.accent_seed.strip().lstrip("#"))
    hct = Hct.from_int(argb)

# Complementary palette: rotate seed hue 180° before scheme generation.
# The motor recalculates optimal tones for the complementary hue, producing
# a natural palette rather than a flat hue-shift of the generated colors.
if args.invert_hue and hct is not None:
    hct = Hct.from_hct((hct.hue + 180.0) % 360.0, hct.chroma, hct.tone)

if args.scheme == "scheme-fruit-salad":
    from materialyoucolor.scheme.scheme_fruit_salad import SchemeFruitSalad as Scheme
elif args.scheme == "scheme-expressive":
    from materialyoucolor.scheme.scheme_expressive import SchemeExpressive as Scheme
elif args.scheme == "scheme-monochrome":
    from materialyoucolor.scheme.scheme_monochrome import SchemeMonochrome as Scheme
elif args.scheme == "scheme-rainbow":
    from materialyoucolor.scheme.scheme_rainbow import SchemeRainbow as Scheme
elif args.scheme == "scheme-tonal-spot":
    from materialyoucolor.scheme.scheme_tonal_spot import SchemeTonalSpot as Scheme
elif args.scheme == "scheme-neutral":
    from materialyoucolor.scheme.scheme_neutral import SchemeNeutral as Scheme
elif args.scheme == "scheme-fidelity":
    from materialyoucolor.scheme.scheme_fidelity import SchemeFidelity as Scheme
elif args.scheme == "scheme-content":
    from materialyoucolor.scheme.scheme_content import SchemeContent as Scheme
elif args.scheme == "scheme-vibrant":
    from materialyoucolor.scheme.scheme_vibrant import SchemeVibrant as Scheme
else:
    from materialyoucolor.scheme.scheme_tonal_spot import SchemeTonalSpot as Scheme
# Generate
scheme = Scheme(hct, darkmode, 0.0)

material_colors = {}
term_colors = {}

for color in vars(MaterialDynamicColors).keys():
    color_name = getattr(MaterialDynamicColors, color)
    if hasattr(color_name, "get_hct"):
        generated_hct = color_name.get_hct(scheme)

        # Apply softening if requested and scheme allows it
        if args.soften and args.scheme not in [
            "scheme-tonal-spot",
            "scheme-neutral",
            "scheme-monochrome",
        ]:
            generated_hct = Hct.from_hct(
                generated_hct.hue, generated_hct.chroma * 0.60, generated_hct.tone
            )

        # Scale output chroma for color strength — skip near-achromatic tokens
        # (chroma < 2 means effectively gray/black/white, leave untouched)
        if abs(args.color_strength - 1.0) > 1e-6 and generated_hct.chroma > 2.0:
            generated_hct = Hct.from_hct(
                generated_hct.hue,
                generated_hct.chroma * args.color_strength,
                generated_hct.tone,
            )

        rgba = generated_hct.to_rgba()
        material_colors[color] = rgba_to_hex(rgba)

# Accents live in Material's band (tone 80 on dark, 40 on light). Fidelity and content schemes copy the seed's
# tone, so a pale wallpaper gave a dark theme a primary at tone 97 (#E9FAFF): white, and every app and the shell
# lost their colour. Out of band, an accent is read from its own palette at the standard tone, keeping its chroma.
if args.scheme != "scheme-monochrome":
    for key, palette_name in (("primary", "primary_palette"), ("secondary", "secondary_palette"), ("tertiary", "tertiary_palette")):
        palette = getattr(scheme, palette_name, None)
        if palette is None or key not in material_colors:
            continue
        tone = Hct.from_int(hex_to_argb(material_colors[key])).tone
        if darkmode and not 70.0 <= tone <= 85.0:
            material_colors[key] = argb_to_hex(palette.tone(80))
        elif not darkmode and not 25.0 <= tone <= 50.0:
            material_colors[key] = argb_to_hex(palette.tone(40))
        container, on_container = key + "Container", "on" + key[0].upper() + key[1:] + "Container"
        if container in material_colors:
            ctone = Hct.from_int(hex_to_argb(material_colors[container])).tone
            if darkmode and not 20.0 <= ctone <= 40.0:
                material_colors[container] = argb_to_hex(palette.tone(30))
                material_colors[on_container] = argb_to_hex(palette.tone(90))
            elif not darkmode and not 80.0 <= ctone <= 95.0:
                material_colors[container] = argb_to_hex(palette.tone(90))
                material_colors[on_container] = argb_to_hex(palette.tone(10))
        # A near-grey wallpaper still has a hue: the accent carries it at a chroma people read as colour, so no
        # wallpaper leaves the shell and its apps without one (a night wallpaper gave a grey #C2C7CE).
        # And a ceiling: a vivid green wallpaper gave #05E600 (chroma 102), a neon no text or fill sits well on.
        hct = Hct.from_int(hex_to_argb(material_colors[key]))
        if hct.chroma > 60.0:
            material_colors[key] = argb_to_hex(Hct.from_hct(hct.hue, 60.0, hct.tone).to_int())
        if key == "primary":
            for role, floor in ((key, 36.0), (container, 24.0)):
                if role in material_colors:
                    hct = Hct.from_int(hex_to_argb(material_colors[role]))
                    if 4.0 <= hct.chroma < floor:
                        material_colors[role] = argb_to_hex(Hct.from_hct(hct.hue, floor, hct.tone).to_int())

# Extended material
if darkmode == True:
    material_colors["success"] = "#B5CCBA"
    material_colors["onSuccess"] = "#213528"
    material_colors["successContainer"] = "#374B3E"
    material_colors["onSuccessContainer"] = "#D1E9D6"
else:
    material_colors["success"] = "#4F6354"
    material_colors["onSuccess"] = "#FFFFFF"
    material_colors["successContainer"] = "#D1E8D5"
    material_colors["onSuccessContainer"] = "#0C1F13"

# The shell's own material as the surface base: the ramp between surfaces keeps
# its steps, the hue and chroma come from the seed, so apps read as the shell.
SURFACE_RAMP = [
    "background", "surface", "surfaceDim", "surfaceBright", "surfaceVariant",
    "surfaceContainerLowest", "surfaceContainerLow", "surfaceContainer",
    "surfaceContainerHigh", "surfaceContainerHighest",
]
# The scheme's own background before the shell's surface moves it: iRiS's "Theme" material is read from this, never
# from the paper it handed over (each pass would carry the person's tone again).
seed_background = material_colors.get("background", "")
if args.surface_seed and re.fullmatch(r"#?[0-9A-Fa-f]{6}", args.surface_seed.strip()):
    seed_hct = Hct.from_int(hex_to_argb("#" + args.surface_seed.strip().lstrip("#")))
    # A seed of the other polarity is a scheme change still on its way: ignore it.
    if (seed_hct.tone < 50) == bool(darkmode) and "background" in material_colors:
        base_tone = Hct.from_int(hex_to_argb(material_colors["background"])).tone
        # A paper stays a paper and a night a night: past these tones no role can be solved against the ramp.
        seed_tone = max(64.0, seed_hct.tone) if not darkmode else min(30.0, seed_hct.tone)
        # The body's hue at a neutral's strength. The seed is iRiS's frost over the wallpaper's average, and copying its
        # chroma (26 on a red wallpaper) painted every app's window, sidebar and dialog the wallpaper's colour; Material
        # keeps neutrals under ~10 (Vibrant 10, TonalSpot 6), dark and light alike.
        seed_chroma = min(seed_hct.chroma, 10.0 if darkmode else 8.0)
        for key in SURFACE_RAMP:
            if key not in material_colors:
                continue
            tone = Hct.from_int(hex_to_argb(material_colors[key])).tone
            shifted = max(0.0, min(100.0, seed_tone + (tone - base_tone)))
            material_colors[key] = argb_to_hex(
                Hct.from_hct(seed_hct.hue, seed_chroma, shifted).to_int()
            )
        # The ramp moved, and the text and accent roles were solved for the stock paper (or night). Solve them again against
        # the surface they now sit farthest from (the darkest in light, the lightest in dark), keeping hue and chroma, so a
        # seed that follows the shell's frost never costs legibility.
        ramp = [hex_to_argb(material_colors[key]) for key in SURFACE_RAMP if key in material_colors]
        worst = (min if not darkmode else max)(ramp, key=lambda argb: Hct.from_int(argb).tone)
        for key, ratio in (
            ("onSurface", 7.0), ("onBackground", 7.0), ("onSurfaceVariant", 4.5), ("error", 4.5), ("outline", 3.0),
        ):
            if key in material_colors:
                material_colors[key] = argb_to_hex(
                    ensure_contrast(
                        hex_to_argb(material_colors[key]), worst, ratio, bool(darkmode), 94.0 if darkmode else 8.0
                    )
                )
        # Accents are fills and marks first (buttons, progress, selection): 3:1 against the farthest surface, as
        # WCAG asks of non-text, and 4.5:1 against the background, where they also set text. Solving them for text
        # on the farthest surface pushed a dark theme's cyan to tone 94 (#E9FAFF) and every app lost its colour.
        background = hex_to_argb(material_colors.get("background", material_colors.get("surface")))
        for key in ("primary", "secondary", "tertiary"):
            if key in material_colors:
                argb = ensure_contrast(hex_to_argb(material_colors[key]), worst, 3.0, bool(darkmode), 94.0 if darkmode else 8.0)
                argb = ensure_contrast(argb, background, 4.5, bool(darkmode), 94.0 if darkmode else 8.0)
                material_colors[key] = argb_to_hex(argb)

# iRiS: the shell's palette (scripts/colors/washi) already solved every role against every surface of its ramp. The apps
# wear it as it is, so window, sidebar, text and accent are the shell's own colours, not a second reading of the seed.
if args.washi_roles:
    # The shell's "theme" and "wallpaper" colours are read from these, never from the roles it handed over (a loop
    # that kept whatever accent once passed through).
    try:
        seeds_path = os.path.join(os.path.dirname(args.washi_roles), "iris-seeds.json")
        seeds = {k: material_colors.get(k, "") for k in ("primary", "secondary", "tertiary")}
        seeds["background"] = seed_background
        seeds_text = json.dumps(seeds)
        try:
            with open(seeds_path) as f:
                unchanged = f.read() == seeds_text
        except OSError:
            unchanged = False
        if not unchanged:
            with open(seeds_path + ".tmp", "w") as f:
                f.write(seeds_text)
            os.replace(seeds_path + ".tmp", seeds_path)
    except OSError:
        pass
    try:
        with open(args.washi_roles) as f:
            washi_roles = json.load(f).get("roles") or {}
        background = washi_roles.get("background", "")
        if re.fullmatch(r"#[0-9A-Fa-f]{6}", background) and (Hct.from_int(hex_to_argb(background)).tone < 50) == bool(darkmode):
            for key, value in washi_roles.items():
                if re.fullmatch(r"#[0-9A-Fa-f]{6}", str(value)):
                    material_colors[key] = value
    except (OSError, ValueError):
        pass

# Terminal Colors
if args.termscheme is not None:
    with open(args.termscheme, "r") as f:
        json_termscheme = f.read()
    term_source_colors = json.loads(json_termscheme)["dark" if darkmode else "light"]

    # Handle both snake_case and camelCase key naming across library versions
    primary_key = material_colors.get(
        "primary_paletteKeyColor",
        material_colors.get(
            "primaryPaletteKeyColor", material_colors.get("primary", "#6750A4")
        ),
    )
    primary_color_argb = hex_to_argb(primary_key)

    # User-configurable parameters
    user_saturation = args.term_saturation  # 0.0-1.0
    user_brightness = args.term_brightness  # 0.0-1.0
    user_harmony = args.harmony  # 0.0-1.0
    user_bg_brightness = args.term_bg_brightness  # 0.0-1.0

    # Define surface colors for interpolation based on bg_brightness
    # 0.0 = background (darkest), 0.5 = surfaceContainerLow (matches shell), 1.0 = surfaceContainerHighest (lightest)
    surface_levels = [
        ("background", 0.0),
        ("surfaceContainerLowest", 0.2),
        ("surfaceContainerLow", 0.4),
        ("surfaceContainer", 0.6),
        ("surfaceContainerHigh", 0.8),
        ("surfaceContainerHighest", 1.0),
    ]

    def get_interpolated_surface(brightness):
        """Get a surface color based on brightness (0-1)"""
        # Find the two surface levels to interpolate between
        for i, (name, level) in enumerate(surface_levels):
            if brightness <= level or i == len(surface_levels) - 1:
                if i == 0:
                    return material_colors.get(name, "#1a1a1a")
                # Interpolate between previous and current
                prev_name, prev_level = surface_levels[i - 1]
                t = (
                    (brightness - prev_level) / (level - prev_level)
                    if level != prev_level
                    else 0
                )
                c1 = hex_to_argb(material_colors.get(prev_name, "#1a1a1a"))
                c2 = hex_to_argb(material_colors.get(name, "#2a2a2a"))
                # Simple RGB interpolation
                r1, g1, b1 = (c1 >> 16) & 0xFF, (c1 >> 8) & 0xFF, c1 & 0xFF
                r2, g2, b2 = (c2 >> 16) & 0xFF, (c2 >> 8) & 0xFF, c2 & 0xFF
                r = int(r1 + (r2 - r1) * t)
                g = int(g1 + (g2 - g1) * t)
                b = int(b1 + (b2 - b1) * t)
                return f"#{r:02X}{g:02X}{b:02X}"
        return material_colors.get("surfaceContainerLow", "#1a1a1a")

    for color, val in term_source_colors.items():
        # Terminal background: Interpolate based on user_bg_brightness
        # 0.5 = surfaceContainerLow (matches shell surfaces perfectly)
        if color == "term0":
            term_colors[color] = get_interpolated_surface(user_bg_brightness)
            continue

        if color == "term15":
            term_colors[color] = material_colors.get("onSurface", "#e0e0e0")
            continue

        # term8: autosuggestion color — needs contrast against term0
        if color == "term8":
            if darkmode:
                term_colors[color] = material_colors.get(
                    "outline",
                    get_interpolated_surface(min(1.0, user_bg_brightness + 0.45)),
                )
            else:
                term_colors[color] = material_colors.get(
                    "outline",
                    get_interpolated_surface(max(0.0, user_bg_brightness - 0.45)),
                )
            continue

        if color == "term7":
            # Neutral colors (gray tones) - minimal harmonization
            harmonized = harmonize(
                hex_to_argb(val),
                primary_color_argb,
                args.harmonize_threshold * 0.3,
                user_harmony * 0.4,
            )
            # Apply user saturation (reduced for grays)
            harmonized = boost_chroma_tone(harmonized, user_saturation * 1.2, 1)
        else:
            # Regular semantic colors — gentle harmonization preserves hue identity
            harmonized = harmonize(
                hex_to_argb(val),
                primary_color_argb,
                args.harmonize_threshold * 0.12,
                user_harmony,
            )
            # Apply user saturation and brightness
            # Brightness affects tone: higher = lighter in dark mode, darker in light mode
            tone_mult = 1 + ((user_brightness - 0.5) * 0.8 * (1 if darkmode else -1))
            # Foreground boost gently pushes ANSI colors away from background tone.
            # Keep this bounded so high values don't collapse colors to white/black.
            fg_boost_delta = args.term_fg_boost * 0.25 * (1 if darkmode else -1)
            tone_mult = max(0.60, min(1.45, tone_mult + fg_boost_delta))
            # In dark the multiplier took every bright slot to tone 91-95 on all wallpapers (C10-33, the text's own tone) and the
            # warm yellow to cream (C12): the syntax of Claude Code, git and every editor built on slots 10-14 read as plain
            # text. Hold the normals at 76 and the brights at 84 so they keep their chroma and stay apart from the foreground.
            tone_cap = 95.0
            if darkmode:
                tone_cap = 84.0 if color in ("term9", "term10", "term11", "term12", "term13", "term14") else 76.0
            harmonized = boost_chroma_tone(harmonized, user_saturation * 2.0, tone_mult, tone_cap)
            # Ensure minimum chroma for visual distinctiveness
            harmonized = ensure_min_chroma(harmonized, 40)
            # And a ceiling, so no hue shouts over the others: greens and cyans reach chroma 77 and 54 at a tone
            # where reds and blues hold 40, and read as neon in the terminal and in every editor theme built on it.
            ceiling = 24 + 36 * user_saturation
            hct = Hct.from_int(harmonized)
            if hct.chroma > ceiling:
                harmonized = Hct.from_hct(hct.hue, ceiling, hct.tone).to_int()

        # Apply additional softening if requested
        if args.soften and args.scheme not in [
            "scheme-tonal-spot",
            "scheme-neutral",
            "scheme-monochrome",
        ]:
            harmonized = boost_chroma_tone(harmonized, 0.55, 1)

        term_colors[color] = argb_to_hex(harmonized)

    # Second pass: ensure all foreground colors have sufficient contrast against background
    # WCAG AA requires 4.5:1 for normal text, 3:1 for large text
    # Normal colors (term1-6) use 4.5:1, bright colors (term9-14) use 3.5:1 since they're
    # already intended to be lighter and we don't want to wash them out to white
    if "term0" in term_colors:
        bg_argb = hex_to_argb(term_colors["term0"])

        # Normal semantic colors: stricter contrast (4.5:1)
        normal_colors = ["term1", "term2", "term3", "term4", "term5", "term6"]
        for color in normal_colors:
            if color in term_colors:
                fg_argb = hex_to_argb(term_colors[color])
                adjusted = ensure_contrast(fg_argb, bg_argb, 4.5, darkmode)
                term_colors[color] = argb_to_hex(adjusted)

        bg_hct = Hct.from_int(bg_argb)
        grey_chroma = min(bg_hct.chroma, 10.0)
        for color, start_tone, ratio in (("term7", 75.0 if darkmode else 35.0, 4.5), ("term8", 60.0 if darkmode else 50.0, 3.5)):
            if color in term_colors:
                grey = Hct.from_hct(bg_hct.hue, grey_chroma, start_tone).to_int()
                term_colors[color] = argb_to_hex(ensure_contrast(grey, bg_argb, ratio, darkmode))

        # Brights: 3.5:1 in dark; on paper they are text (strings, types, ls) and need 4.5:1.
        bright_colors = ["term9", "term10", "term11", "term12", "term13", "term14"]
        for color in bright_colors:
            if color in term_colors:
                fg_argb = hex_to_argb(term_colors[color])
                adjusted = ensure_contrast(fg_argb, bg_argb, 3.5 if darkmode else 4.5, darkmode)
                term_colors[color] = argb_to_hex(adjusted)

    if darkmode and "term0" in term_colors and "term15" in term_colors:
        solve_dark_terminal_reading(term_colors, args.term_fg_boost)

# Fallback: derive term colors from material colors when no termscheme provided
if not term_colors and material_colors:
    term_colors = {
        "term0": material_colors.get("surfaceVariant", "#282828"),
        "term1": material_colors.get("error", "#CC241D"),
        "term2": material_colors.get("secondary", "#98971A"),
        "term3": material_colors.get("tertiary", "#D79921"),
        "term4": material_colors.get("primary", "#458588"),
        "term5": material_colors.get("tertiary", "#B16286"),
        "term6": material_colors.get("secondary", "#689D6A"),
        "term7": material_colors.get("onSurfaceVariant", "#A89984"),
        "term8": material_colors.get("outline", "#928374"),
        "term9": material_colors.get("error", "#FB4934"),
        "term10": material_colors.get("secondary", "#B8BB26"),
        "term11": material_colors.get("tertiary", "#FABD2F"),
        "term12": material_colors.get("primary", "#83A598"),
        "term13": material_colors.get("tertiary", "#D3869B"),
        "term14": material_colors.get("secondary", "#8EC07C"),
        "term15": material_colors.get("onSurface", "#EBDBB2"),
    }

def build_scss_output() -> str:
    lines = [f"$darkmode: {darkmode};", f"$transparent: {transparent};"]
    for color, code in material_colors.items():
        lines.append(f"${color}: {code};")
    for color, code in term_colors.items():
        lines.append(f"${color}: {code};")
    return "\n".join(lines) + "\n"


scss_output = build_scss_output()

if args.scss_output:
    with open(args.scss_output, "w") as f:
        f.write(scss_output)

if args.debug == False:
    print(scss_output, end="")
else:
    if args.path is not None:
        print("\n--------------Image properties-----------------")
        print(f"Image size: {wsize} x {hsize}")
        print(f"Resized image: {wsize_new} x {hsize_new}")
    print("\n---------------Selected color------------------")
    print(f"Dark mode: {darkmode}")
    print(f"Scheme: {args.scheme}")
    print(f"Accent color: {display_color(rgba_from_argb(argb))} {argb_to_hex(argb)}")
    print(f"HCT: {hct.hue:.2f}  {hct.chroma:.2f}  {hct.tone:.2f}")
    print("\n---------------Material colors-----------------")
    for color, code in material_colors.items():
        rgba = rgba_from_argb(hex_to_argb(code))
        print(f"{color.ljust(32)} : {display_color(rgba)}  {code}")
    print("\n----------Harmonize terminal colors------------")
    for color, code in term_colors.items():
        rgba = rgba_from_argb(hex_to_argb(code))
        code_source = term_source_colors[color]
        rgba_source = rgba_from_argb(hex_to_argb(code_source))
        print(
            f"{color.ljust(6)} : {display_color(rgba_source)} {code_source} --> {display_color(rgba)} {code}"
        )
    print("-----------------------------------------------")


def build_palette_json():
    palette = {
        "primary": material_colors.get("primary", ""),
        "on_primary": material_colors.get("onPrimary", ""),
        "primary_container": material_colors.get("primaryContainer", ""),
        "on_primary_container": material_colors.get("onPrimaryContainer", ""),
        "primary_fixed": material_colors.get("primaryFixed", ""),
        "primary_fixed_dim": material_colors.get("primaryFixedDim", ""),
        "on_primary_fixed": material_colors.get("onPrimaryFixed", ""),
        "on_primary_fixed_variant": material_colors.get("onPrimaryFixedVariant", ""),
        "secondary": material_colors.get("secondary", ""),
        "on_secondary": material_colors.get("onSecondary", ""),
        "secondary_container": material_colors.get("secondaryContainer", ""),
        "on_secondary_container": material_colors.get("onSecondaryContainer", ""),
        "secondary_fixed": material_colors.get("secondaryFixed", ""),
        "secondary_fixed_dim": material_colors.get("secondaryFixedDim", ""),
        "on_secondary_fixed": material_colors.get("onSecondaryFixed", ""),
        "on_secondary_fixed_variant": material_colors.get(
            "onSecondaryFixedVariant", ""
        ),
        "tertiary": material_colors.get("tertiary", ""),
        "on_tertiary": material_colors.get("onTertiary", ""),
        "tertiary_container": material_colors.get("tertiaryContainer", ""),
        "on_tertiary_container": material_colors.get("onTertiaryContainer", ""),
        "tertiary_fixed": material_colors.get("tertiaryFixed", ""),
        "tertiary_fixed_dim": material_colors.get("tertiaryFixedDim", ""),
        "on_tertiary_fixed": material_colors.get("onTertiaryFixed", ""),
        "on_tertiary_fixed_variant": material_colors.get("onTertiaryFixedVariant", ""),
        "error": material_colors.get("error", ""),
        "on_error": material_colors.get("onError", ""),
        "error_container": material_colors.get("errorContainer", ""),
        "on_error_container": material_colors.get("onErrorContainer", ""),
        "background": material_colors.get("background", ""),
        "on_background": material_colors.get("onBackground", ""),
        "surface": material_colors.get("surface", ""),
        "on_surface": material_colors.get("onSurface", ""),
        "surface_dim": material_colors.get("surfaceDim", ""),
        "surface_bright": material_colors.get("surfaceBright", ""),
        "surface_variant": material_colors.get("surfaceVariant", ""),
        "on_surface_variant": material_colors.get("onSurfaceVariant", ""),
        "surface_container_lowest": material_colors.get("surfaceContainerLowest", ""),
        "surface_container_low": material_colors.get("surfaceContainerLow", ""),
        "surface_container": material_colors.get("surfaceContainer", ""),
        "surface_container_high": material_colors.get("surfaceContainerHigh", ""),
        "surface_container_highest": material_colors.get("surfaceContainerHighest", ""),
        "outline": material_colors.get("outline", ""),
        "outline_variant": material_colors.get("outlineVariant", ""),
        "inverse_surface": material_colors.get("inverseSurface", ""),
        "inverse_on_surface": material_colors.get("inverseOnSurface", ""),
        "inverse_primary": material_colors.get("inversePrimary", ""),
        "shadow": material_colors.get("shadow", ""),
        "scrim": material_colors.get("scrim", ""),
        "surface_tint": material_colors.get("surfaceTint", ""),
        "success": material_colors.get("success", ""),
        "on_success": material_colors.get("onSuccess", ""),
        "success_container": material_colors.get("successContainer", ""),
        "on_success_container": material_colors.get("onSuccessContainer", ""),
    }
    # iRiS's filled alert (badges): a pigment that is a shape, not text. Absent outside iRiS; readers fall back to error.
    if material_colors.get("errorFill"):
        palette["error_fill"] = material_colors["errorFill"]
        palette["on_error_fill"] = material_colors.get("onErrorFill", "")
    return palette


palette_json = build_palette_json()
app_palette_json = build_app_palette(palette_json)
colors_json = dict(palette_json)
for tkey, tval in term_colors.items():
    colors_json[tkey] = tval

theme_meta = {
    "source": "image"
    if args.path is not None
    else "color"
    if args.color is not None
    else "unknown",
    "source_path": args.path,
    "seed_color": argb_to_hex(argb),
    "mode": "dark" if darkmode else "light",
    "scheme": args.scheme,
    "transparent": transparent,
    "soften": args.soften,
    "term_harmony": args.harmony,
    "term_saturation": args.term_saturation,
    "term_brightness": args.term_brightness,
    "term_bg_brightness": args.term_bg_brightness,
    "term_fg_boost": args.term_fg_boost,
    "harmonize_threshold": args.harmonize_threshold,
    "color_strength": args.color_strength,
    "blend_bg_fg": args.blend_bg_fg,
    "surface_seed": ("#" + args.surface_seed.strip().lstrip("#").lower())
    if args.surface_seed and re.fullmatch(r"#?[0-9A-Fa-f]{6}", args.surface_seed.strip())
    else "",
    "accent_seed": ("#" + args.accent_seed.strip().lstrip("#").lower())
    if args.accent_seed and re.fullmatch(r"#?[0-9A-Fa-f]{6}", args.accent_seed.strip())
    else "",
    "generated_by": "generate_colors_material.py",
}

if args.json_output:
    with open(args.json_output, "w") as f:
        json.dump(colors_json, f, indent=2)

if args.palette_output:
    with open(args.palette_output, "w") as f:
        json.dump(palette_json, f, indent=2)

if args.app_palette_output:
    with open(args.app_palette_output, "w") as f:
        json.dump(app_palette_json, f, indent=2)

if args.terminal_output:
    with open(args.terminal_output, "w") as f:
        json.dump(term_colors, f, indent=2)

if args.meta_output:
    with open(args.meta_output, "w") as f:
        json.dump(theme_meta, f, indent=2)

# ---------------------------------------------------------------------------
# Template rendering for iNiR's unified theming pipeline
# ---------------------------------------------------------------------------
if args.render_templates:
    template_dir = args.render_templates
    manifest_path = os.path.join(template_dir, "templates.json")
    legacy_config_path = os.path.join(template_dir, "config.toml")

    template_entries = []
    managed_outputs = set()
    for managed_path in [
        args.json_output,
        args.palette_output,
        args.app_palette_output,
        args.terminal_output,
        args.meta_output,
        args.scss_output,
    ]:
        if not managed_path:
            continue
        resolved = os.path.abspath(os.path.expanduser(managed_path))
        if resolved.endswith(".tmp"):
            resolved = resolved[:-4]
        managed_outputs.add(resolved)

    if os.path.isfile(manifest_path):
        with open(manifest_path, "r") as f:
            manifest = json.load(f)

        templates_base = os.path.join(template_dir, "templates")
        for entry in manifest.get("templates", []):
            output_path = os.path.abspath(os.path.expanduser(entry["output"]))
            if output_path in managed_outputs:
                continue
            template_entries.append(
                {
                    "name": entry.get("name", "template"),
                    "template_path": os.path.join(templates_base, entry["input"]),
                    "output_path": output_path,
                }
            )
    elif os.path.isfile(legacy_config_path):
        if tomllib is None:
            print(
                "[render-templates] Legacy config.toml found but tomllib is unavailable, skipping",
                file=sys.stderr,
            )
        else:
            with open(legacy_config_path, "rb") as f:
                legacy_config = tomllib.load(f)

            for name, entry in (legacy_config.get("templates") or {}).items():
                if not isinstance(entry, dict):
                    continue

                input_path = entry.get("input_path")
                output_path = entry.get("output_path")
                if not input_path or not output_path:
                    continue
                if input_path == "/dev/null" or output_path == "/dev/null":
                    continue

                resolved_input = os.path.expanduser(input_path)
                resolved_output = os.path.abspath(os.path.expanduser(output_path))
                if resolved_output in managed_outputs:
                    continue
                if not os.path.isfile(resolved_input) and "/templates/" in input_path:
                    rel_input = input_path.split("/templates/", 1)[1].lstrip("/")
                    candidate = os.path.join(template_dir, "templates", rel_input)
                    if os.path.isfile(candidate):
                        resolved_input = candidate

                template_entries.append(
                    {
                        "name": name,
                        "template_path": resolved_input,
                        "output_path": resolved_output,
                    }
                )
    else:
        print(
            f"[render-templates] Missing {manifest_path} and {legacy_config_path}, skipping template rendering",
            file=sys.stderr,
        )

    if not template_entries:
        # Nothing to render — either no manifest found or all entries were
        # invalid.  Color generation already succeeded, so exit cleanly.
        sys.exit(0)

    # Build both dark and light palettes so templates can use either variant.
    # The main `material_colors` dict was generated for the *current* mode;
    # we also need the opposite mode for templates like GTK4 that embed both.
    def _generate_palette(is_dark):
        s = Scheme(hct, is_dark, 0.0)
        palette = {}
        for c in vars(MaterialDynamicColors).keys():
            cn = getattr(MaterialDynamicColors, c)
            if hasattr(cn, "get_hct"):
                g = cn.get_hct(s)
                if args.soften and args.scheme not in [
                    "scheme-tonal-spot",
                    "scheme-neutral",
                    "scheme-monochrome",
                ]:
                    g = Hct.from_hct(g.hue, g.chroma * 0.60, g.tone)
                palette[c] = rgba_to_hex(g.to_rgba())
        # source_color is the seed itself
        palette["source_color"] = argb_to_hex(argb)
        # Extended Material tokens (not in MaterialDynamicColors)
        if is_dark:
            palette["success"] = "#B5CCBA"
            palette["onSuccess"] = "#213528"
            palette["successContainer"] = "#374B3E"
            palette["onSuccessContainer"] = "#D1E9D6"
        else:
            palette["success"] = "#4F6354"
            palette["onSuccess"] = "#FFFFFF"
            palette["successContainer"] = "#D1E8D5"
            palette["onSuccessContainer"] = "#0C1F13"
        raw_contract = {
            "primary": palette.get("primary", ""),
            "on_primary": palette.get("onPrimary", ""),
            "primary_container": palette.get("primaryContainer", ""),
            "on_primary_container": palette.get("onPrimaryContainer", ""),
            "background": palette.get("background", ""),
            "on_background": palette.get("onBackground", ""),
            "surface": palette.get("surface", ""),
            "on_surface": palette.get("onSurface", ""),
            "surface_dim": palette.get("surfaceDim", ""),
            "surface_bright": palette.get("surfaceBright", ""),
            "surface_container_lowest": palette.get("surfaceContainerLowest", ""),
            "surface_container_low": palette.get("surfaceContainerLow", ""),
            "surface_container": palette.get("surfaceContainer", ""),
            "surface_container_high": palette.get("surfaceContainerHigh", ""),
            "surface_container_highest": palette.get("surfaceContainerHighest", ""),
            "on_surface_variant": palette.get("onSurfaceVariant", ""),
            "outline": palette.get("outline", ""),
            "outline_variant": palette.get("outlineVariant", ""),
        }
        palette.update(build_app_palette(raw_contract))
        return palette

    dark_palette = _generate_palette(True)
    light_palette = _generate_palette(False)
    # The current mode is the palette the shell and every app module already use (accent band, chroma caps, surface seed, contrast);
    # the raw templates drew colours nobody else showed. The opposite mode stays the raw scheme.
    current = dict(_generate_palette(darkmode))
    current.update(material_colors)
    current["source_color"] = argb_to_hex(argb)
    current.update(app_palette_json)
    if darkmode:
        dark_palette = current
    else:
        light_palette = current
    default_palette = current

    # Build the nested `colors` namespace expected by the compatibility templates:
    #   colors.<token>.dark.hex          → "#rrggbb"
    #   colors.<token>.dark.hex_stripped  → "rrggbb"
    #   colors.<token>.dark.rgb          → "R, G, B" (decimal triplet)
    #   colors.<token>.light.hex
    #   colors.<token>.default.hex       → follows current mode
    class _Hex:
        """Tiny wrapper so `hex` / `hex_stripped` / `rgb` resolve as attributes."""

        __slots__ = ("hex", "hex_stripped", "rgb")

        def __init__(self, hexval):
            self.hex = hexval
            self.hex_stripped = hexval.lstrip("#")
            h = self.hex_stripped
            self.rgb = f"{int(h[0:2], 16)}, {int(h[2:4], 16)}, {int(h[4:6], 16)}"

    class _Token:
        __slots__ = ("dark", "light", "default")

        def __init__(self, dk, lt, df):
            self.dark = _Hex(dk)
            self.light = _Hex(lt)
            self.default = _Hex(df)

    # Collect every token name that appears in either palette
    all_tokens = set(dark_palette.keys()) | set(light_palette.keys())
    colors_ns = {}

    def _camel_to_snake(name):
        """Convert camelCase to snake_case for compatibility template aliases."""
        return re.sub(r"(?<=[a-z0-9])([A-Z])", r"_\1", name).lower()

    for tok in all_tokens:
        dk = dark_palette.get(tok, "#000000")
        lt = light_palette.get(tok, "#000000")
        df = default_palette.get(tok, "#000000")
        token_obj = _Token(dk, lt, df)
        # Register under both camelCase and snake_case keys
        colors_ns[tok] = token_obj
        snake = _camel_to_snake(tok)
        if snake != tok:
            colors_ns[snake] = token_obj

    # Regex to resolve {{colors.TOKEN.MODE.PROP}} and {{image}}
    _VAR_RE = re.compile(r"\{\{\s*(.*?)\s*\}\}")

    def _resolve(match):
        expr = match.group(1)
        if expr == "image":
            return args.path or ""
        parts = expr.split(".")
        # Expected: colors.<token>.<mode>.<prop>
        if len(parts) == 4 and parts[0] == "colors":
            _, token, mode, prop = parts
            tok_obj = colors_ns.get(token)
            if tok_obj is None:
                # Try camelCase → snake_case and vice-versa
                # Compatibility templates use snake_case token names.
                print(
                    f"[render-templates] WARNING: unresolved token '{token}' in {{{{colors.{token}.{mode}.{prop}}}}}",
                    file=sys.stderr,
                )
                return match.group(0)  # leave unresolved
            mode_obj = getattr(tok_obj, mode, None)
            if mode_obj is None:
                print(
                    f"[render-templates] WARNING: unresolved mode '{mode}' for token '{token}' in {{{{colors.{token}.{mode}.{prop}}}}}",
                    file=sys.stderr,
                )
                return match.group(0)
            val = getattr(mode_obj, prop, None)
            if val is None:
                print(
                    f"[render-templates] WARNING: unresolved prop '{prop}' for token '{token}.{mode}' in {{{{colors.{token}.{mode}.{prop}}}}}",
                    file=sys.stderr,
                )
                return match.group(0)
            return val
        return match.group(0)  # leave unknown expressions untouched

    rendered_count = 0

    for entry in template_entries:
        tpl_path = entry["template_path"]
        out_path = entry["output_path"]

        if not os.path.isfile(tpl_path):
            print(
                f"[render-templates] Skipping missing template: {tpl_path}",
                file=sys.stderr,
            )
            continue

        with open(tpl_path, "r") as f:
            content = f.read()

        rendered = _VAR_RE.sub(_resolve, content)

        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        # Break symlinks before writing so we don't corrupt external themes
        if os.path.islink(out_path):
            print(
                f"[render-templates] Replacing symlink with regular file: {out_path}",
                file=sys.stderr,
            )
            os.remove(out_path)
        with open(out_path, "w") as f:
            f.write(rendered)
        rendered_count += 1

    if rendered_count > 0:
        print(
            f"[render-templates] Rendered {rendered_count} template(s)", file=sys.stderr
        )
