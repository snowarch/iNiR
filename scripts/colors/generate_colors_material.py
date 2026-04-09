#!/usr/bin/env -S\_/bin/sh\_-c\_"source\_\$(eval\_echo\_\${INIR_VENV:-\$ILLOGICAL_IMPULSE_VIRTUAL_ENV})/bin/activate&&exec\_python\_-E\_"\$0"\_"\$@""
import argparse
import math
import json
import os
import re
import sys

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
    "--terminal-output", type=str, default=None, help="file path to write terminal.json"
)
parser.add_argument(
    "--meta-output", type=str, default=None, help="file path to write theme-meta.json"
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


def ensure_contrast(
    fg_argb: int, bg_argb: int, min_ratio: float = 4.5, is_dark: bool = True
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
    colors = QuantizeCelebi(list(image.getdata()), 128)
    argb = Score.score(colors)[0]

    if args.cache is not None:
        with open(args.cache, "w") as file:
            file.write(argb_to_hex(argb))
    hct = Hct.from_int(argb)
    if args.smart:
        if hct.chroma < 20:
            args.scheme = "neutral"
elif args.color is not None:
    argb = hex_to_argb(args.color)
    hct = Hct.from_int(argb)

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
        if args.scheme == "monochrome":
            term_colors[color] = val
            continue

        # Terminal background: Interpolate based on user_bg_brightness
        # 0.5 = surfaceContainerLow (matches shell surfaces perfectly)
        if color == "term0":
            term_colors[color] = get_interpolated_surface(user_bg_brightness)
            continue

        # Terminal foreground: Use EXACT Material onSurface color
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
                    "outline_variant",
                    material_colors.get(
                        "outlineVariant",
                        get_interpolated_surface(max(0.0, user_bg_brightness - 0.45)),
                    ),
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
            harmonized = boost_chroma_tone(harmonized, user_saturation * 2.0, tone_mult)
            # Ensure minimum chroma for visual distinctiveness
            harmonized = ensure_min_chroma(harmonized, 40)

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

        # Bright semantic colors: lighter contrast requirement (3.5:1) to preserve vibrancy
        bright_colors = ["term9", "term10", "term11", "term12", "term13", "term14"]
        for color in bright_colors:
            if color in term_colors:
                fg_argb = hex_to_argb(term_colors[color])
                adjusted = ensure_contrast(fg_argb, bg_argb, 3.5, darkmode)
                term_colors[color] = argb_to_hex(adjusted)

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

if args.debug == False:
    print(f"$darkmode: {darkmode};")
    print(f"$transparent: {transparent};")
    for color, code in material_colors.items():
        print(f"${color}: {code};")
    for color, code in term_colors.items():
        print(f"${color}: {code};")
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
    return palette


palette_json = build_palette_json()
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
    "generated_by": "generate_colors_material.py",
}

if args.json_output:
    with open(args.json_output, "w") as f:
        json.dump(colors_json, f, indent=2)

if args.palette_output:
    with open(args.palette_output, "w") as f:
        json.dump(palette_json, f, indent=2)

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

    if os.path.isfile(manifest_path):
        with open(manifest_path, "r") as f:
            manifest = json.load(f)

        templates_base = os.path.join(template_dir, "templates")
        for entry in manifest.get("templates", []):
            template_entries.append(
                {
                    "name": entry.get("name", "template"),
                    "template_path": os.path.join(templates_base, entry["input"]),
                    "output_path": os.path.expanduser(entry["output"]),
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
                if not os.path.isfile(resolved_input) and "/templates/" in input_path:
                    rel_input = input_path.split("/templates/", 1)[1].lstrip("/")
                    candidate = os.path.join(template_dir, "templates", rel_input)
                    if os.path.isfile(candidate):
                        resolved_input = candidate

                template_entries.append(
                    {
                        "name": name,
                        "template_path": resolved_input,
                        "output_path": os.path.expanduser(output_path),
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
        return palette

    dark_palette = _generate_palette(True)
    light_palette = _generate_palette(False)
    default_palette = dark_palette if darkmode else light_palette

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

    # SDDM sync post-hook: run only if script and theme exist
    sddm_sync = os.path.expanduser("~/.local/bin/sync-pixel-sddm.py")
    sddm_theme = "/usr/share/sddm/themes/ii-pixel"
    if os.path.isfile(sddm_sync) and os.path.isdir(sddm_theme):
        import subprocess

        subprocess.Popen(
            ["python3", sddm_sync],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
