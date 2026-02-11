#!/usr/bin/env -S\_/bin/sh\_-c\_"source\_\$(eval\_echo\_\$ILLOGICAL_IMPULSE_VIRTUAL_ENV)/bin/activate&&exec\_python\_-E\_"\$0"\_"\$@""
import argparse
import math
import json
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
    "--harmony", type=float, default=0.8, help="(0-1) Color hue shift towards accent"
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
    default=0.40,
    help="Terminal color saturation (0.0-1.0)",
)
parser.add_argument(
    "--term_brightness",
    type=float,
    default=0.55,
    help="Terminal color brightness/lightness (0.0-1.0)",
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


def boost_chroma_tone(argb: int, chroma: float = 1, tone: float = 1) -> int:
    hct = Hct.from_int(argb)
    return Hct.from_hct(hct.hue, hct.chroma * chroma, hct.tone * tone).to_int()


def enforce_terminal_palette_spread(
    term_colors: dict,
    term_source_colors: dict,
    darkmode: bool,
    primary_color_argb: int,
) -> None:
    """Nudge generated terminal colors so they are less bunched together.

    We keep Material You harmonization but ensure: (a) a minimum chroma floor so
    colors don't all become muted pastels, (b) a tone delta from the background so
    foreground colors remain legible, and (c) a small hue pull-back towards the
    original source color if harmonization collapses hues together.
    """

    if not term_colors:
        return

    bg_hex = term_colors.get("term0") or term_source_colors.get("term0")
    if not bg_hex:
        return

    bg_hct = Hct.from_int(hex_to_argb(bg_hex))
    anchor_tone = bg_hct.tone

    # Sets of keys to handle differently
    chroma_keys = {
        "term1",
        "term2",
        "term3",
        "term4",
        "term5",
        "term6",
        "term9",
        "term10",
        "term11",
        "term12",
        "term13",
        "term14",
    }
    bright_keys = {
        "term8",
        "term9",
        "term10",
        "term11",
        "term12",
        "term13",
        "term14",
        "term15",
    }

    for key, hex_val in list(term_colors.items()):
        source_hex = term_source_colors.get(key, hex_val)

        try:
            hct = Hct.from_int(hex_to_argb(hex_val))
            source_hct = Hct.from_int(hex_to_argb(source_hex))
        except Exception:
            continue

        # 1) Enforce a chroma floor so colors don't all sit near gray
        if key in chroma_keys:
            min_chroma = 34 if darkmode else 28
            # Slightly higher floor for warm slots to keep them lively
            if key in {"term1", "term3", "term5", "term9", "term11", "term13"}:
                min_chroma += 4
            if hct.chroma < min_chroma:
                hct = Hct.from_hct(hct.hue, min_chroma, hct.tone)

        # 2) Ensure a tone delta from the background so text is readable
        is_bright = key in bright_keys
        if key == "term8":
            delta = 12  # dim bright-black only a bit away from background
        else:
            delta = 30 if is_bright else 22

        if darkmode:
            target_tone = clamp(anchor_tone + delta, 0, 100)
            if hct.tone < target_tone:
                hct = Hct.from_hct(hct.hue, hct.chroma, target_tone)
        else:
            target_tone = clamp(anchor_tone - delta, 0, 100)
            if hct.tone > target_tone:
                hct = Hct.from_hct(hct.hue, hct.chroma, target_tone)

        # 3) If harmonization collapsed hues too close to the primary, pull a bit
        #    back towards the original slot hue to preserve variety
        hue_to_primary = difference_degrees(hct.hue, Hct.from_int(primary_color_argb).hue)
        if hue_to_primary < 10:
            restored_hue = sanitize_degrees_double(
                hct.hue + (source_hct.hue - hct.hue) * 0.35
            )
            hct = Hct.from_hct(restored_hue, hct.chroma, hct.tone)

        term_colors[key] = argb_to_hex(hct.to_int())


def build_material_term_source(material_colors: dict, darkmode: bool) -> dict:
    """Generate a default 16-color terminal palette from Material colors.

    This avoids the static JSON hue bias (blue-ish) and anchors the palette to
    the wallpaper-derived Material scheme. Falls back gracefully if keys are
    missing.
    """

    def pick(name: str, fallback: str) -> str:
        return material_colors.get(name, fallback)

    # Core anchors with safe defaults
    surface = pick("surfaceContainerLow" if darkmode else "surface", "#1E1E1E")
    surface_high = pick("surfaceContainerHigh" if darkmode else "surfaceBright", "#2A2A2A")
    on_surface = pick("onSurface", "#E6E1E5")
    on_surface_var = pick("onSurfaceVariant", "#CAC4D0")
    primary = pick("primary", "#9A82FF")
    secondary = pick("secondary", "#89D1C5")
    tertiary = pick("tertiary", "#F2B8C6")
    primary_c = pick("primaryContainer", "#4F378A")
    secondary_c = pick("secondaryContainer", "#4A635E")
    tertiary_c = pick("tertiaryContainer", "#633B48")
    on_primary = pick("onPrimary", "#0F0A1C")
    on_secondary = pick("onSecondary", "#0D1F1A")
    on_tertiary = pick("onTertiary", "#251420")
    inverse_primary = pick("inversePrimary", primary)
    outline = pick("outline", "#928F99")
    outline_var = pick("outlineVariant", "#49454F")

    return {
        # Base / bright base
        "term0": surface,
        "term8": surface_high,
        # Accents
        "term1": primary,
        "term2": secondary,
        "term3": tertiary,
        "term4": primary_c,
        "term5": secondary_c,
        "term6": tertiary_c,
        # Neutral fg/bg
        "term7": on_surface,
        "term15": on_surface_var,
        # Bright accents (on* give pop on dark bg)
        "term9": on_primary,
        "term10": on_secondary,
        "term11": on_tertiary,
        "term12": inverse_primary,
        "term13": outline,
        "term14": outline_var,
    }


def clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


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
    # Start from material-derived defaults to avoid static hue bias (e.g., always blue)
    term_source_colors = build_material_term_source(material_colors, darkmode)

    # If a term scheme file is provided, use it as a structure and blend with material
    # anchors so we keep slot intent (reds/greens) but hue-align to the wallpaper.
    with open(args.termscheme, "r") as f:
        json_termscheme = f.read()
    file_scheme = json.loads(json_termscheme)["dark" if darkmode else "light"]

    # Retint file scheme slots towards corresponding material anchors while keeping
    # their tone/chroma relationships to preserve semantic spread.
    for key, val in file_scheme.items():
        target_hex = term_source_colors.get(key, val)
        try:
            base_hct = Hct.from_int(hex_to_argb(val))
            target_hct = Hct.from_int(hex_to_argb(target_hex))
        except Exception:
            term_source_colors[key] = val
            continue

        # Keep the tone from the file (preserves bright/dim intent), use target hue,
        # and blend chroma between target and file to avoid washed-out results.
        blended_chroma = max(base_hct.chroma * 0.5 + target_hct.chroma * 0.5, 18)
        retinted = Hct.from_hct(target_hct.hue, blended_chroma, base_hct.tone)
        term_source_colors[key] = argb_to_hex(retinted.to_int())

    primary_color_argb = hex_to_argb(material_colors["primary_paletteKeyColor"])
    
    # User-configurable parameters
    user_saturation = args.term_saturation  # 0.0-1.0
    user_brightness = args.term_brightness  # 0.0-1.0
    user_harmony = args.harmony  # 0.0-1.0
    
    for color, val in term_source_colors.items():
        if args.scheme == "monochrome":
            term_colors[color] = val
            continue
        if args.blend_bg_fg and color == "term0":
            # Background: use surface color
            harmonized = boost_chroma_tone(
                hex_to_argb(material_colors["surfaceContainerLow"]), 0.7, 0.98
            )
        elif args.blend_bg_fg and color == "term15":
            # Foreground: use onSurface
            harmonized = boost_chroma_tone(
                hex_to_argb(material_colors["onSurface"]), 1.5, 1
            )
        elif color in ["term7", "term8"]:
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
            # Regular semantic colors
            harmonized = harmonize(
                hex_to_argb(val),
                primary_color_argb,
                args.harmonize_threshold * 0.7,
                user_harmony,
            )
            # Apply user saturation and brightness
            # Brightness affects tone: higher = lighter in dark mode, darker in light mode
            tone_mult = 1 + ((user_brightness - 0.5) * 0.4 * (1 if darkmode else -1))
            harmonized = boost_chroma_tone(harmonized, user_saturation * 1.5, tone_mult)

        # Apply additional softening if requested
        if args.soften and args.scheme not in [
            "scheme-tonal-spot",
            "scheme-neutral",
            "scheme-monochrome",
        ]:
            harmonized = boost_chroma_tone(harmonized, 0.55, 1)

        term_colors[color] = argb_to_hex(harmonized)

    enforce_terminal_palette_spread(
        term_colors, term_source_colors, darkmode, primary_color_argb
    )

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

# Generate colors.json if requested (for MaterialThemeLoader)
if args.json_output:
    # Convert snake_case keys to match expected format
    colors_json = {
        "primary": material_colors.get("primary", ""),
        "on_primary": material_colors.get("onPrimary", ""),
        "primary_container": material_colors.get("primaryContainer", ""),
        "on_primary_container": material_colors.get("onPrimaryContainer", ""),
        "secondary": material_colors.get("secondary", ""),
        "on_secondary": material_colors.get("onSecondary", ""),
        "secondary_container": material_colors.get("secondaryContainer", ""),
        "on_secondary_container": material_colors.get("onSecondaryContainer", ""),
        "tertiary": material_colors.get("tertiary", ""),
        "on_tertiary": material_colors.get("onTertiary", ""),
        "tertiary_container": material_colors.get("tertiaryContainer", ""),
        "on_tertiary_container": material_colors.get("onTertiaryContainer", ""),
        "error": material_colors.get("error", ""),
        "on_error": material_colors.get("onError", ""),
        "error_container": material_colors.get("errorContainer", ""),
        "on_error_container": material_colors.get("onErrorContainer", ""),
        "background": material_colors.get("background", ""),
        "on_background": material_colors.get("onBackground", ""),
        "surface": material_colors.get("surface", ""),
        "on_surface": material_colors.get("onSurface", ""),
        "surface_variant": material_colors.get("surfaceVariant", ""),
        "on_surface_variant": material_colors.get("onSurfaceVariant", ""),
        "surface_container": material_colors.get("surfaceContainer", ""),
        "surface_container_low": material_colors.get("surfaceContainerLow", ""),
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
    }
    with open(args.json_output, "w") as f:
        json.dump(colors_json, f, indent=2)
