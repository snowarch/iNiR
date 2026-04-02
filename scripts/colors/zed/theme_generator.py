#!/usr/bin/env python3
"""
Generate Zed editor theme from Material You colors and SCSS terminal colors.
Creates both dark and light theme variants with auto-detected palette scheme.
"""

import copy
import json
import os
import re
import sys
from pathlib import Path


def generate_zed_config(
    colors, scss_path, output_path, palette_json_path=None, terminal_json_path=None
):
    """Generate Zed editor theme from Material You colors and SCSS terminal colors."""
    input_colors = colors if isinstance(colors, dict) else {}
    colors_json_path = palette_json_path or os.path.expanduser(
        "~/.local/state/quickshell/user/generated/palette.json"
    )

    def _is_hex_color(value):
        return isinstance(value, str) and re.fullmatch(
            r"#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{8})", value.strip()
        )

    try:
        with open(colors_json_path, "r") as f:
            my_colors = json.load(f)
    except FileNotFoundError:
        print(
            f"Warning: Could not find palette/colors JSON. Using defaults for Zed theme.",
            file=sys.stderr,
        )
        my_colors = {
            "primary": "#7aa2f7",
            "secondary": "#bb9af7",
            "tertiary": "#9ece6a",
            "error": "#f7768e",
            "surface": "#1a1b26",
            "surface_container_low": "#24283b",
            "surface_container": "#414868",
            "surface_container_high": "#565f89",
            "outline": "#565f89",
            "on_surface": "#c0caf5",
            "on_surface_variant": "#9aa5ce",
            "on_primary": "#1a1b26",
        }

    my_colors = {k: v.lower() for k, v in my_colors.items() if _is_hex_color(v)}
    for key, value in input_colors.items():
        if _is_hex_color(value):
            my_colors[key] = value.lower()

    def parse_scss_colors(scss_path):
        """Parse material_colors.scss compatibility values."""
        term_colors = {}
        try:
            with open(scss_path, "r") as f:
                for line in f:
                    match = re.match(r"\$(\w+):\s*(#[A-Fa-f0-9]{6});", line.strip())
                    if match:
                        name, value = match.groups()
                        if re.fullmatch(r"term\d{1,2}", name):
                            term_colors[name] = value.lower()
        except FileNotFoundError:
            pass
        return term_colors

    def parse_terminal_json(json_path):
        parsed = {}
        if not json_path:
            return parsed
        try:
            with open(json_path, "r") as f:
                data = json.load(f)
                for key, value in data.items():
                    if re.fullmatch(r"term\d{1,2}", str(key)) and _is_hex_color(value):
                        parsed[str(key)] = value.lower()
        except (FileNotFoundError, json.JSONDecodeError):
            pass
        return parsed

    term_colors = {
        k: v.lower()
        for k, v in input_colors.items()
        if re.fullmatch(r"term\d{1,2}", str(k)) and _is_hex_color(v)
    }
    term_colors.update(parse_scss_colors(scss_path))
    term_colors.update(parse_terminal_json(terminal_json_path))

    default_term_colors = {
        "term0": "#1d1f21",
        "term1": "#cc6666",
        "term2": "#b5bd68",
        "term3": "#f0c674",
        "term4": "#81a2be",
        "term5": "#b294bb",
        "term6": "#8abeb7",
        "term7": "#c5c8c6",
        "term8": "#666666",
        "term9": "#d54e53",
        "term10": "#b9ca4a",
        "term11": "#e7c547",
        "term12": "#7aa6da",
        "term13": "#c397d8",
        "term14": "#70c0ba",
        "term15": "#ffffff",
    }

    def hex_with_alpha(hex_color, alpha_hex):
        """Add alpha hex value to color"""
        hex_color = hex_color.lstrip("#")
        return f"#{hex_color}{alpha_hex}"

    def adjust_lightness(hex_color, factor):
        """Adjust lightness of hex color (factor > 1 = lighter, factor < 1 = darker)"""
        hex_color = hex_color.lstrip("#")
        r = int(hex_color[0:2], 16) / 255.0
        g = int(hex_color[2:4], 16) / 255.0
        b = int(hex_color[4:6], 16) / 255.0

        max_c = max(r, g, b)
        min_c = min(r, g, b)
        l = (max_c + min_c) / 2.0

        if max_c == min_c:
            h = s = 0
        else:
            d = max_c - min_c
            s = d / (2.0 - max_c - min_c) if l > 0.5 else d / (max_c + min_c)
            if max_c == r:
                h = (g - b) / d + (6 if g < b else 0)
            elif max_c == g:
                h = (b - r) / d + 2
            else:
                h = (r - g) / d + 4
            h /= 6.0

        l = max(0.0, min(1.0, l * factor))

        def hue_to_rgb(p, q, t):
            if t < 0:
                t += 1
            if t > 1:
                t -= 1
            if t < 1 / 6:
                return p + (q - p) * 6 * t
            if t < 1 / 2:
                return q
            if t < 2 / 3:
                return p + (q - p) * (2 / 3 - t) * 6
            return p

        if s == 0:
            r = g = b = l
        else:
            q = l * (1 + s) if l < 0.5 else l + s - l * s
            p = 2 * l - q
            r = hue_to_rgb(p, q, h + 1 / 3)
            g = hue_to_rgb(p, q, h)
            b = hue_to_rgb(p, q, h - 1 / 3)

        return f"#{int(r * 255):02x}{int(g * 255):02x}{int(b * 255):02x}"

    def saturate(
        hex_color,
        factor,
        min_saturation=0.38,
        additive_floor=0.22,
        hue_hint=0.0,
    ):
        """Increase saturation with an additive floor for very muted colors."""
        hex_color = hex_color.lstrip("#")
        r = int(hex_color[0:2], 16) / 255.0
        g = int(hex_color[2:4], 16) / 255.0
        b = int(hex_color[4:6], 16) / 255.0

        max_c = max(r, g, b)
        min_c = min(r, g, b)
        l = (max_c + min_c) / 2.0

        if max_c == min_c:
            h = hue_hint % 1.0
            s = 0.0
        else:
            d = max_c - min_c
            s = d / (2.0 - max_c - min_c) if l > 0.5 else d / (max_c + min_c)
            if max_c == r:
                h = (g - b) / d + (6 if g < b else 0)
            elif max_c == g:
                h = (b - r) / d + 2
            else:
                h = (r - g) / d + 4
            h /= 6.0

        boosted = min(1.0, s * factor + additive_floor * (1.0 - s))
        if boosted < min_saturation:
            boosted = min(1.0, boosted + min_saturation)
        s = boosted

        def hue_to_rgb(p, q, t):
            if t < 0:
                t += 1
            if t > 1:
                t -= 1
            if t < 1 / 6:
                return p + (q - p) * 6 * t
            if t < 1 / 2:
                return q
            if t < 2 / 3:
                return p + (q - p) * (2 / 3 - t) * 6
            return p

        q = l * (1 + s) if l < 0.5 else l + s - l * s
        p = 2 * l - q
        r = hue_to_rgb(p, q, h + 1 / 3)
        g = hue_to_rgb(p, q, h)
        b = hue_to_rgb(p, q, h - 1 / 3)

        return f"#{int(r * 255):02x}{int(g * 255):02x}{int(b * 255):02x}"

    def blend_colors(base_hex, mix_hex, mix_ratio):
        """Blend mix_hex into base_hex by mix_ratio."""
        ratio = max(0.0, min(1.0, mix_ratio))
        base_hex = base_hex.lstrip("#")
        mix_hex = mix_hex.lstrip("#")
        br, bg, bb = (
            int(base_hex[0:2], 16),
            int(base_hex[2:4], 16),
            int(base_hex[4:6], 16),
        )
        mr, mg, mb = (
            int(mix_hex[0:2], 16),
            int(mix_hex[2:4], 16),
            int(mix_hex[4:6], 16),
        )
        r = int(round(br * (1.0 - ratio) + mr * ratio))
        g = int(round(bg * (1.0 - ratio) + mg * ratio))
        b = int(round(bb * (1.0 - ratio) + mb * ratio))
        return f"#{r:02x}{g:02x}{b:02x}"

    def get_term_color(index):
        key = f"term{index}"
        return term_colors.get(key, default_term_colors.get(key, "#ffffff"))

    # Blend 50% of theme primary into Zed default syntax colors.
    mix_ratio = 0.50

    def build_syntax_map(primary, appearance):
        # Keep external editor syntax aligned with shell code blocks defaults in
        # modules/common/Appearance.qml: Monokai (dark) and ayu Light (light).
        defaults = (
            {
                # Monokai
                "red": "#f92672",
                "green": "#a6e22e",
                "yellow": "#e6db74",
                "blue": "#66d9ef",
                "magenta": "#ae81ff",
                "cyan": "#a1efe4",
                "foreground": "#f8f8f2",
                "muted": "#b0ada0",
                "comment": "#75715e",
                "orange": "#fd971f",
            }
            if appearance == "dark"
            else {
                # ayu Light
                "red": "#f07178",
                "green": "#86b300",
                "yellow": "#f2ae49",
                "blue": "#399ee6",
                "magenta": "#a37acc",
                "cyan": "#4cbf99",
                "foreground": "#5c6166",
                "muted": "#8a9199",
                "comment": "#abb0b6",
                "orange": "#fa8d3e",
            }
        )

        def syntax_color(base_color):
            return blend_colors(base_color, primary, mix_ratio)

        accent_red = syntax_color(defaults["red"])
        accent_green = syntax_color(defaults["green"])
        accent_yellow = syntax_color(defaults["yellow"])
        accent_blue = syntax_color(defaults["blue"])
        accent_magenta = syntax_color(defaults["magenta"])
        accent_cyan = syntax_color(defaults["cyan"])
        foreground = syntax_color(defaults["foreground"])
        muted = syntax_color(defaults["muted"])
        comment = syntax_color(defaults["comment"])
        comment_doc = comment

        def sx(color, font_style=None, font_weight=None):
            return {
                "color": hex_with_alpha(color, "ff"),
                "font_style": font_style,
                "font_weight": font_weight,
            }

        return {
            "attribute": sx(accent_blue),
            "boolean": sx(accent_yellow),
            "comment": sx(comment),
            "comment.doc": sx(comment_doc),
            "constant": sx(accent_yellow),
            "constructor": sx(accent_magenta),
            "embedded": sx(foreground),
            "emphasis": sx(accent_blue),
            "emphasis.strong": sx(accent_blue, font_weight=700),
            "enum": sx(accent_cyan),
            "function": sx(accent_blue),
            "hint": sx(accent_cyan),
            "keyword": sx(accent_magenta),
            "label": sx(accent_blue),
            "link_text": sx(accent_blue, font_style="normal"),
            "link_uri": sx(accent_cyan),
            "namespace": sx(foreground),
            "number": sx(accent_yellow),
            "operator": sx(accent_cyan),
            "predictive": sx(accent_cyan, font_style="italic"),
            "preproc": sx(accent_magenta),
            "primary": sx(foreground),
            "property": sx(accent_blue),
            "punctuation": sx(muted),
            "punctuation.bracket": sx(accent_cyan),
            "punctuation.delimiter": sx(muted),
            "punctuation.list_marker": sx(accent_magenta),
            "punctuation.markup": sx(accent_magenta),
            "punctuation.special": sx(accent_red),
            "selector": sx(accent_magenta),
            "selector.pseudo": sx(accent_blue),
            "string": sx(accent_green),
            "string.escape": sx(syntax_color(defaults["orange"])),
            "string.regex": sx(accent_green),
            "string.special": sx(accent_green),
            "string.special.symbol": sx(accent_cyan),
            "tag": sx(accent_magenta),
            "text.literal": sx(accent_green),
            "title": sx(accent_blue, font_weight=400),
            "type": sx(accent_cyan),
            "variable": sx(foreground),
            "variable.special": sx(accent_red),
            "variant": sx(accent_blue),
        }

    def _luminance(hex_color):
        hex_color = hex_color.lstrip("#")
        r = int(hex_color[0:2], 16)
        g = int(hex_color[2:4], 16)
        b = int(hex_color[4:6], 16)
        return r * 0.299 + g * 0.587 + b * 0.114

    _surface_lum = _luminance(my_colors.get("surface", "#000000"))
    _is_dark_palette = _surface_lum < 128

    if _is_dark_palette:
        _dk_surface = my_colors.get("surface", "#1a1b26")
        _dk_surface_low = my_colors.get("surface_container_low", "#24283b")
        _dk_surface_std = my_colors.get("surface_container", "#414868")
        _dk_surface_high = my_colors.get("surface_container_high", "#565f89")
        _dk_surface_highest = my_colors.get("surface_container_highest", "#3d3231")
        _dk_on_surface = my_colors.get("on_surface", "#c0caf5")
        _dk_on_surface_variant = my_colors.get("on_surface_variant", "#9aa5ce")
        _dk_outline = my_colors.get("outline", "#565f89")
        _dk_outline_variant = my_colors.get("outline_variant", "#534341")
        _lt_surface = my_colors.get("inverse_surface", "#f1dedc")
        _lt_on_surface = my_colors.get("inverse_on_surface", "#392e2c")
        _lt_on_surface_variant = my_colors.get("outline_variant", "#534341")
        _lt_outline = my_colors.get("outline", "#565f89")
        _lt_outline_variant = my_colors.get("outline_variant", "#534341")
        _lt_surface_low = adjust_lightness(_lt_surface, 0.97)
        _lt_surface_std = adjust_lightness(_lt_surface, 0.94)
        _lt_surface_high = adjust_lightness(_lt_surface, 0.91)
        _lt_surface_highest = adjust_lightness(_lt_surface, 0.88)
    else:
        _lt_surface = my_colors.get("surface", "#fff8f7")
        _lt_surface_low = my_colors.get("surface_container_low", "#fff0f2")
        _lt_surface_std = my_colors.get("surface_container", "#fbeaec")
        _lt_surface_high = my_colors.get("surface_container_high", "#f5e4e6")
        _lt_surface_highest = my_colors.get("surface_container_highest", "#efdee0")
        _lt_on_surface = my_colors.get("on_surface", "#22191b")
        _lt_on_surface_variant = my_colors.get("on_surface_variant", "#514346")
        _lt_outline = my_colors.get("outline", "#847376")
        _lt_outline_variant = my_colors.get("outline_variant", "#d6c2c4")
        _dk_surface = my_colors.get("inverse_surface", "#382e30")
        _dk_on_surface = my_colors.get("inverse_on_surface", "#feedef")
        _dk_on_surface_variant = my_colors.get("outline_variant", "#d6c2c4")
        _dk_outline = my_colors.get("outline", "#847376")
        _dk_outline_variant = my_colors.get("outline_variant", "#d6c2c4")
        _dk_surface_low = adjust_lightness(_dk_surface, 1.15)
        _dk_surface_std = adjust_lightness(_dk_surface, 1.35)
        _dk_surface_high = adjust_lightness(_dk_surface, 1.55)
        _dk_surface_highest = adjust_lightness(_dk_surface, 1.75)

    def _hex6(hex_color):
        return f"#{hex_color.lstrip('#')[:6].lower()}"

    def build_mode_palette(appearance):
        palette = dict(my_colors)
        if appearance == "dark":
            palette.update(
                {
                    "surface": _dk_surface,
                    "surface_container_low": _dk_surface_low,
                    "surface_container": _dk_surface_std,
                    "surface_container_high": _dk_surface_high,
                    "surface_container_highest": _dk_surface_highest,
                    "on_surface": _dk_on_surface,
                    "on_surface_variant": _dk_on_surface_variant,
                    "outline": _dk_outline,
                    "outline_variant": _dk_outline_variant,
                }
            )
            palette.setdefault("surface_dim", adjust_lightness(_dk_surface, 0.92))
        else:
            palette.update(
                {
                    "surface": _lt_surface,
                    "surface_container_low": _lt_surface_low,
                    "surface_container": _lt_surface_std,
                    "surface_container_high": _lt_surface_high,
                    "surface_container_highest": _lt_surface_highest,
                    "on_surface": _lt_on_surface,
                    "on_surface_variant": _lt_on_surface_variant,
                    "outline": _lt_outline,
                    "outline_variant": _lt_outline_variant,
                }
            )
            palette.setdefault("surface_dim", adjust_lightness(_lt_surface, 0.95))
        palette.setdefault(
            "surface_variant", palette.get("surface_container", palette["surface"])
        )
        return palette

    mode_palettes = {
        "dark": build_mode_palette("dark"),
        "light": build_mode_palette("light"),
    }

    def resolve_material_color(token, mode):
        palette = mode_palettes.get(mode, mode_palettes["dark"])
        raw = palette.get(token)
        if _is_hex_color(raw):
            return _hex6(raw)

        fallback_map = {
            "primary": "#7aa2f7",
            "secondary": "#bb9af7",
            "tertiary": "#9ece6a",
            "error": "#f7768e",
            "surface": "#1a1b26" if mode == "dark" else "#faf4f2",
            "surface_container": "#24283b" if mode == "dark" else "#f0e8e6",
            "surface_container_low": "#1f2230" if mode == "dark" else "#f7efed",
            "surface_container_high": "#2d3246" if mode == "dark" else "#ece2df",
            "surface_container_highest": "#3a415b" if mode == "dark" else "#e5d9d6",
            "surface_dim": "#14161d" if mode == "dark" else "#ece2df",
            "on_surface": "#c0caf5" if mode == "dark" else "#2a2022",
            "on_surface_variant": "#9aa5ce" if mode == "dark" else "#5a4b4e",
            "outline": "#565f89" if mode == "dark" else "#7e6e72",
            "outline_variant": "#434a68" if mode == "dark" else "#ccb8bc",
            "primary_container": "#39426a" if mode == "dark" else "#dbe2ff",
            "on_primary_container": "#d7e2ff" if mode == "dark" else "#1f2a4d",
            "secondary_container": "#4a4064" if mode == "dark" else "#e8defc",
            "on_secondary_container": "#e8defd" if mode == "dark" else "#352d4b",
            "tertiary_container": "#334f2e" if mode == "dark" else "#d9f4bf",
            "on_tertiary_container": "#d2f0b8" if mode == "dark" else "#243a1e",
            "error_container": "#5d1f2d" if mode == "dark" else "#f9d8df",
            "on_error_container": "#ffd9df" if mode == "dark" else "#5b1b2a",
        }
        if token in fallback_map:
            return fallback_map[token]
        if token.startswith("on_"):
            return resolve_material_color("on_surface", mode)
        if token.endswith("_container"):
            return resolve_material_color("surface_container", mode)
        if token.startswith("surface"):
            return resolve_material_color("surface", mode)
        return resolve_material_color("primary", mode)

    _alt_template_path = (
        Path(__file__).resolve().parents[3]
        / "dots/.config/matugen/templates/zed-colors.json"
    )
    _alt_placeholder_re = re.compile(r"\{\{colors\.([a-z0-9_]+)\.(dark|light)\.hex\}\}")

    def render_alt_template(node):
        if isinstance(node, dict):
            return {k: render_alt_template(v) for k, v in node.items()}
        if isinstance(node, list):
            return [render_alt_template(item) for item in node]
        if isinstance(node, str):
            return _alt_placeholder_re.sub(
                lambda match: resolve_material_color(match.group(1), match.group(2)),
                node,
            )
        return node

    def load_alt_template_styles():
        try:
            with open(_alt_template_path, "r") as f:
                data = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            return {}

        styles = {}
        for theme in data.get("themes", []):
            appearance = theme.get("appearance")
            style = theme.get("style")
            if appearance in ("dark", "light") and isinstance(style, dict):
                styles[appearance] = style
        return styles

    alt_template_styles = load_alt_template_styles()

    def build_zed_dark_theme():
        primary = my_colors.get("primary", "#7aa2f7")
        secondary = my_colors.get("secondary", "#bb9af7")
        tertiary = my_colors.get("tertiary", "#9ece6a")
        error = my_colors.get("error", "#f7768e")
        surface = _dk_surface
        surface_low = _dk_surface_low
        surface_std = _dk_surface_std
        surface_high = _dk_surface_high
        outline = _dk_outline
        outline_variant = _dk_outline_variant
        on_surface = _dk_on_surface
        on_surface_variant = _dk_on_surface_variant

        theme = {
            "border": hex_with_alpha(on_surface, "20"),
            "border.variant": hex_with_alpha(surface, "20"),
            "border.focused": hex_with_alpha(surface, "40"),
            "border.selected": hex_with_alpha(surface, "ff"),
            "border.transparent": hex_with_alpha(surface, "20"),
            "border.disabled": hex_with_alpha(outline_variant, "60"),
            "elevated_surface.background": hex_with_alpha(surface_low, "ff"),
            "surface.background": hex_with_alpha(surface_low, "ff"),
            "background": hex_with_alpha(surface, "ff"),
            "element.background": hex_with_alpha(surface_low, "ff"),
            "element.hover": hex_with_alpha(surface_std, "ff"),
            "element.active": hex_with_alpha(surface_high, "ff"),
            "element.selected": hex_with_alpha(surface_high, "ff"),
            "element.disabled": hex_with_alpha(surface_low, "ff"),
            "drop_target.background": hex_with_alpha(primary, "80"),
            "ghost_element.background": "#00000000",
            "ghost_element.hover": hex_with_alpha(surface_std, "ff"),
            "ghost_element.active": hex_with_alpha(surface_high, "ff"),
            "ghost_element.selected": hex_with_alpha(surface_high, "ff"),
            "ghost_element.disabled": hex_with_alpha(surface_low, "ff"),
            "text": hex_with_alpha(on_surface, "ff"),
            "text.muted": hex_with_alpha(on_surface_variant, "ff"),
            "text.placeholder": hex_with_alpha(
                adjust_lightness(on_surface_variant, 0.7), "ff"
            ),
            "text.disabled": hex_with_alpha(
                adjust_lightness(on_surface_variant, 0.6), "ff"
            ),
            "text.accent": hex_with_alpha(primary, "ff"),
            "icon": hex_with_alpha(on_surface, "ff"),
            "icon.muted": hex_with_alpha(on_surface_variant, "ff"),
            "icon.disabled": hex_with_alpha(
                adjust_lightness(on_surface_variant, 0.6), "ff"
            ),
            "icon.placeholder": hex_with_alpha(on_surface_variant, "ff"),
            "icon.accent": hex_with_alpha(primary, "ff"),
            "status_bar.background": hex_with_alpha(surface, "ff"),
            "title_bar.background": hex_with_alpha(surface, "ff"),
            "title_bar.inactive_background": hex_with_alpha(surface_low, "ff"),
            "toolbar.background": hex_with_alpha(surface_low, "ff"),
            "tab_bar.background": hex_with_alpha(surface_low, "ff"),
            "tab.inactive_background": hex_with_alpha(surface_low, "ff"),
            "tab.active_background": hex_with_alpha(
                adjust_lightness(surface, 0.9), "ff"
            ),
            "search.match_background": hex_with_alpha(primary, "66"),
            "search.active_match_background": hex_with_alpha(tertiary, "66"),
            "panel.background": hex_with_alpha(surface_low, "ff"),
            "panel.focused_border": None,
            "pane.focused_border": None,
            "scrollbar.thumb.background": hex_with_alpha(on_surface_variant, "4c"),
            "scrollbar.thumb.hover_background": hex_with_alpha(surface_high, "ff"),
            "scrollbar.thumb.border": hex_with_alpha(surface_std, "ff"),
            "scrollbar.track.background": "#00000000",
            "scrollbar.track.border": hex_with_alpha(surface_std, "ff"),
            "editor.foreground": hex_with_alpha(on_surface, "ff"),
            "editor.background": hex_with_alpha(surface, "ff"),
            "editor.gutter.background": hex_with_alpha(surface, "ff"),
            "editor.subheader.background": hex_with_alpha(surface_low, "ff"),
            "editor.active_line.background": hex_with_alpha(surface_low, "bf"),
            "editor.highlighted_line.background": hex_with_alpha(surface_std, "ff"),
            "editor.line_number": hex_with_alpha(on_surface_variant, "ff"),
            "editor.active_line_number": hex_with_alpha(on_surface, "ff"),
            "editor.hover_line_number": hex_with_alpha(
                adjust_lightness(on_surface, 1.1), "ff"
            ),
            "editor.invisible": hex_with_alpha(on_surface_variant, "ff"),
            "editor.wrap_guide": hex_with_alpha(on_surface_variant, "0d"),
            "editor.active_wrap_guide": hex_with_alpha(on_surface_variant, "1a"),
            "editor.document_highlight.read_background": hex_with_alpha(primary, "1a"),
            "editor.document_highlight.write_background": hex_with_alpha(
                surface_std, "66"
            ),
            "terminal.background": hex_with_alpha(surface, "ff"),
            "terminal.foreground": hex_with_alpha(on_surface, "ff"),
            "terminal.bright_foreground": hex_with_alpha(on_surface, "ff"),
            "terminal.dim_foreground": hex_with_alpha(
                adjust_lightness(on_surface, 0.6), "ff"
            ),
            "link_text.hover": hex_with_alpha(primary, "ff"),
            "version_control.added": hex_with_alpha(tertiary, "ff"),
            "version_control.modified": hex_with_alpha(
                adjust_lightness(primary, 0.8), "ff"
            ),
            "version_control.word_added": hex_with_alpha(tertiary, "59"),
            "version_control.word_deleted": hex_with_alpha(error, "cc"),
            "version_control.deleted": hex_with_alpha(error, "ff"),
            "version_control.conflict_marker.ours": hex_with_alpha(tertiary, "1a"),
            "version_control.conflict_marker.theirs": hex_with_alpha(primary, "1a"),
            "conflict": hex_with_alpha(adjust_lightness(tertiary, 0.8), "ff"),
            "conflict.background": hex_with_alpha(
                adjust_lightness(tertiary, 0.8), "1a"
            ),
            "conflict.border": hex_with_alpha(adjust_lightness(tertiary, 0.6), "ff"),
            "created": hex_with_alpha(tertiary, "ff"),
            "created.background": hex_with_alpha(tertiary, "1a"),
            "created.border": hex_with_alpha(adjust_lightness(tertiary, 0.6), "ff"),
            "deleted": hex_with_alpha(error, "ff"),
            "deleted.background": hex_with_alpha(error, "1a"),
            "deleted.border": hex_with_alpha(adjust_lightness(error, 0.6), "ff"),
            "error": hex_with_alpha(error, "ff"),
            "error.background": hex_with_alpha(error, "1a"),
            "error.border": hex_with_alpha(adjust_lightness(error, 0.6), "ff"),
            "hidden": hex_with_alpha(on_surface_variant, "ff"),
            "hidden.background": hex_with_alpha(
                adjust_lightness(on_surface_variant, 0.3), "1a"
            ),
            "hidden.border": hex_with_alpha(outline, "ff"),
            "hint": hex_with_alpha(adjust_lightness(primary, 0.7), "ff"),
            "hint.background": hex_with_alpha(adjust_lightness(primary, 0.7), "1a"),
            "hint.border": hex_with_alpha(adjust_lightness(primary, 0.6), "ff"),
            "ignored": hex_with_alpha(on_surface_variant, "ff"),
            "ignored.background": hex_with_alpha(
                adjust_lightness(on_surface_variant, 0.3), "1a"
            ),
            "ignored.border": hex_with_alpha(outline, "ff"),
            "info": hex_with_alpha(primary, "ff"),
            "info.background": hex_with_alpha(primary, "1a"),
            "info.border": hex_with_alpha(adjust_lightness(primary, 0.6), "ff"),
            "color": hex_with_alpha(primary, "66"),
            "modified.background": hex_with_alpha(adjust_lightness(primary, 0.8), "1a"),
            "modified.border": hex_with_alpha(primary, "ff"),
            "predictive": hex_with_alpha(adjust_lightness(secondary, 0.8), "ff"),
            "predictive.background": hex_with_alpha(
                adjust_lightness(secondary, 0.8), "1a"
            ),
            "predictive.border": hex_with_alpha(secondary, "ff"),
            "renamed": hex_with_alpha(primary, "ff"),
            "renamed.background": hex_with_alpha(primary, "1a"),
            "renamed.border": hex_with_alpha(adjust_lightness(primary, 0.6), "ff"),
            "success": hex_with_alpha(tertiary, "ff"),
            "success.background": hex_with_alpha(tertiary, "1a"),
            "success.border": hex_with_alpha(adjust_lightness(tertiary, 0.6), "ff"),
            "unreachable": hex_with_alpha(on_surface_variant, "ff"),
            "unreachable.background": hex_with_alpha(
                adjust_lightness(on_surface_variant, 0.3), "1a"
            ),
            "unreachable.border": hex_with_alpha(outline, "ff"),
            "warning": hex_with_alpha(adjust_lightness(tertiary, 0.9), "ff"),
            "warning.background": hex_with_alpha(adjust_lightness(tertiary, 0.9), "1a"),
            "warning.border": hex_with_alpha(adjust_lightness(tertiary, 0.9), "ff"),
        }

        theme["terminal.ansi.black"] = hex_with_alpha(get_term_color(0), "ff")
        theme["terminal.ansi.bright_black"] = hex_with_alpha(get_term_color(8), "ff")
        theme["terminal.ansi.dim_black"] = hex_with_alpha(
            adjust_lightness(get_term_color(0), 0.6), "ff"
        )

        color_map = {
            "red": 1,
            "bright_red": 9,
            "dim_red": 1,
            "green": 2,
            "bright_green": 10,
            "dim_green": 2,
            "yellow": 3,
            "bright_yellow": 11,
            "dim_yellow": 3,
            "blue": 4,
            "bright_blue": 12,
            "dim_blue": 4,
            "magenta": 5,
            "bright_magenta": 13,
            "dim_magenta": 5,
            "cyan": 6,
            "bright_cyan": 14,
            "dim_cyan": 6,
            "white": 7,
            "bright_white": 15,
            "dim_white": 7,
        }

        for name, idx in color_map.items():
            base_color = get_term_color(idx)
            if "bright" in name:
                color = adjust_lightness(base_color, 1.2)
            elif "dim" in name:
                color = adjust_lightness(base_color, 0.7)
            else:
                color = base_color
            theme[f"terminal.ansi.{name}"] = hex_with_alpha(color, "ff")

        player_colors = [
            primary,
            error,
            adjust_lightness(tertiary, 0.8),
            secondary,
            adjust_lightness(secondary, 1.2),
            adjust_lightness(error, 0.8),
            adjust_lightness(tertiary, 0.9),
            adjust_lightness(primary, 0.8),
        ]
        theme["players"] = [
            {
                "cursor": hex_with_alpha(color, "ff"),
                "background": hex_with_alpha(color, "ff"),
                "selection": hex_with_alpha(color, "3d"),
            }
            for color in player_colors
        ]

        theme["syntax"] = build_syntax_map(
            primary=primary,
            appearance="dark",
        )

        return theme

    def build_zed_light_theme():
        primary = my_colors.get("primary", "#7aa2f7")
        secondary = my_colors.get("secondary", "#bb9af7")
        tertiary = my_colors.get("tertiary", "#9ece6a")
        error = my_colors.get("error", "#f7768e")
        surface = _lt_surface
        surface_low = _lt_surface_low
        surface_std = _lt_surface_std
        surface_high = _lt_surface_high
        surface_highest = _lt_surface_highest
        on_surface = _lt_on_surface
        on_surface_variant = _lt_on_surface_variant
        outline = _lt_outline
        outline_variant = _lt_outline_variant

        def lighten(color, factor=1.15):
            return adjust_lightness(color, factor)

        def darken(color, factor=0.85):
            return adjust_lightness(color, factor)

        light_theme = {
            "border": hex_with_alpha(on_surface, "20"),
            "border.variant": hex_with_alpha(surface, "20"),
            "border.focused": hex_with_alpha(surface, "40"),
            "border.selected": hex_with_alpha(surface, "ff"),
            "border.transparent": hex_with_alpha(surface, "20"),
            "border.disabled": hex_with_alpha(outline_variant, "60"),
            "elevated_surface.background": hex_with_alpha(surface_low, "ff"),
            "surface.background": hex_with_alpha(surface_low, "ff"),
            "background": hex_with_alpha(surface, "ff"),
            "element.background": hex_with_alpha(surface_std, "ff"),
            "element.hover": hex_with_alpha(surface_high, "ff"),
            "element.active": hex_with_alpha(surface_highest, "ff"),
            "element.selected": hex_with_alpha(surface_highest, "ff"),
            "element.disabled": hex_with_alpha(surface_low, "ff"),
            "drop_target.background": hex_with_alpha(primary, "30"),
            "ghost_element.background": "#00000000",
            "ghost_element.hover": hex_with_alpha(surface_high, "ff"),
            "ghost_element.active": hex_with_alpha(surface_highest, "ff"),
            "ghost_element.selected": hex_with_alpha(surface_highest, "ff"),
            "ghost_element.disabled": hex_with_alpha(surface_low, "ff"),
            "text": hex_with_alpha(on_surface, "ff"),
            "text.muted": hex_with_alpha(on_surface_variant, "ff"),
            "text.placeholder": hex_with_alpha(lighten(on_surface_variant, 1.3), "ff"),
            "text.disabled": hex_with_alpha(lighten(on_surface_variant, 1.5), "ff"),
            "text.accent": hex_with_alpha(primary, "ff"),
            "icon": hex_with_alpha(on_surface, "ff"),
            "icon.muted": hex_with_alpha(on_surface_variant, "ff"),
            "icon.disabled": hex_with_alpha(lighten(on_surface_variant, 1.5), "ff"),
            "icon.placeholder": hex_with_alpha(on_surface_variant, "ff"),
            "icon.accent": hex_with_alpha(primary, "ff"),
            "status_bar.background": hex_with_alpha(surface, "ff"),
            "title_bar.background": hex_with_alpha(surface, "ff"),
            "title_bar.inactive_background": hex_with_alpha(surface_low, "ff"),
            "toolbar.background": hex_with_alpha(surface_low, "ff"),
            "tab_bar.background": hex_with_alpha(surface_low, "ff"),
            "tab.inactive_background": hex_with_alpha(surface_low, "ff"),
            "tab.active_background": hex_with_alpha(surface, "ff"),
            "search.match_background": hex_with_alpha(primary, "40"),
            "search.active_match_background": hex_with_alpha(tertiary, "40"),
            "panel.background": hex_with_alpha(surface_low, "ff"),
            "panel.focused_border": None,
            "pane.focused_border": None,
            "scrollbar.thumb.background": hex_with_alpha(on_surface_variant, "4c"),
            "scrollbar.thumb.hover_background": hex_with_alpha(
                on_surface_variant, "80"
            ),
            "scrollbar.thumb.border": hex_with_alpha(on_surface_variant, "60"),
            "scrollbar.track.background": "#00000000",
            "scrollbar.track.border": hex_with_alpha(outline_variant, "ff"),
            "editor.foreground": hex_with_alpha(on_surface, "ff"),
            "editor.background": hex_with_alpha(surface, "ff"),
            "editor.gutter.background": hex_with_alpha(surface, "ff"),
            "editor.subheader.background": hex_with_alpha(surface_low, "ff"),
            "editor.active_line.background": hex_with_alpha(surface_std, "bf"),
            "editor.highlighted_line.background": hex_with_alpha(surface_high, "ff"),
            "editor.line_number": hex_with_alpha(on_surface_variant, "ff"),
            "editor.active_line_number": hex_with_alpha(on_surface, "ff"),
            "editor.hover_line_number": hex_with_alpha(darken(on_surface, 0.8), "ff"),
            "editor.invisible": hex_with_alpha(lighten(on_surface_variant, 1.3), "ff"),
            "editor.wrap_guide": hex_with_alpha(on_surface_variant, "0d"),
            "editor.active_wrap_guide": hex_with_alpha(on_surface_variant, "1a"),
            "editor.document_highlight.read_background": hex_with_alpha(primary, "20"),
            "editor.document_highlight.write_background": hex_with_alpha(
                on_surface_variant, "66"
            ),
            "terminal.background": hex_with_alpha(surface, "ff"),
            "terminal.foreground": hex_with_alpha(on_surface, "ff"),
            "terminal.bright_foreground": hex_with_alpha(on_surface, "ff"),
            "terminal.dim_foreground": hex_with_alpha(on_surface_variant, "ff"),
            "link_text.hover": hex_with_alpha(primary, "ff"),
            "version_control.added": hex_with_alpha(saturate(tertiary, 1.3), "ff"),
            "version_control.modified": hex_with_alpha(saturate(primary, 1.3), "ff"),
            "version_control.word_added": hex_with_alpha(tertiary, "40"),
            "version_control.word_deleted": hex_with_alpha(error, "40"),
            "version_control.deleted": hex_with_alpha(saturate(error, 1.3), "ff"),
            "version_control.conflict_marker.ours": hex_with_alpha(tertiary, "25"),
            "version_control.conflict_marker.theirs": hex_with_alpha(primary, "25"),
            "conflict": hex_with_alpha(saturate(tertiary, 1.3), "ff"),
            "conflict.background": hex_with_alpha(tertiary, "18"),
            "conflict.border": hex_with_alpha(saturate(tertiary, 1.5), "ff"),
            "created": hex_with_alpha(saturate(tertiary, 1.3), "ff"),
            "created.background": hex_with_alpha(tertiary, "18"),
            "created.border": hex_with_alpha(saturate(tertiary, 1.5), "ff"),
            "deleted": hex_with_alpha(saturate(error, 1.3), "ff"),
            "deleted.background": hex_with_alpha(error, "18"),
            "deleted.border": hex_with_alpha(saturate(error, 1.5), "ff"),
            "error": hex_with_alpha(saturate(error, 1.3), "ff"),
            "error.background": hex_with_alpha(error, "18"),
            "error.border": hex_with_alpha(saturate(error, 1.5), "ff"),
            "hidden": hex_with_alpha(on_surface_variant, "ff"),
            "hidden.background": hex_with_alpha(on_surface_variant, "18"),
            "hidden.border": hex_with_alpha(outline_variant, "ff"),
            "hint": hex_with_alpha(saturate(primary, 1.3), "ff"),
            "hint.background": hex_with_alpha(primary, "18"),
            "hint.border": hex_with_alpha(saturate(primary, 1.5), "ff"),
            "ignored": hex_with_alpha(on_surface_variant, "ff"),
            "ignored.background": hex_with_alpha(on_surface_variant, "18"),
            "ignored.border": hex_with_alpha(outline_variant, "ff"),
            "info": hex_with_alpha(saturate(primary, 1.3), "ff"),
            "info.background": hex_with_alpha(primary, "18"),
            "info.border": hex_with_alpha(saturate(primary, 1.5), "ff"),
            "modified": hex_with_alpha(saturate(primary, 1.3), "ff"),
            "modified.background": hex_with_alpha(primary, "18"),
            "modified.border": hex_with_alpha(saturate(primary, 1.5), "ff"),
            "predictive": hex_with_alpha(saturate(secondary, 1.3), "ff"),
            "predictive.background": hex_with_alpha(secondary, "18"),
            "predictive.border": hex_with_alpha(saturate(secondary, 1.5), "ff"),
            "renamed": hex_with_alpha(saturate(primary, 1.3), "ff"),
            "renamed.background": hex_with_alpha(primary, "18"),
            "renamed.border": hex_with_alpha(saturate(primary, 1.5), "ff"),
            "success": hex_with_alpha(saturate(tertiary, 1.3), "ff"),
            "success.background": hex_with_alpha(tertiary, "18"),
            "success.border": hex_with_alpha(saturate(tertiary, 1.5), "ff"),
            "unreachable": hex_with_alpha(on_surface_variant, "ff"),
            "unreachable.background": hex_with_alpha(on_surface_variant, "18"),
            "unreachable.border": hex_with_alpha(outline_variant, "ff"),
            "warning": hex_with_alpha(saturate(tertiary, 1.3), "ff"),
            "warning.background": hex_with_alpha(tertiary, "18"),
            "warning.border": hex_with_alpha(saturate(tertiary, 1.5), "ff"),
        }

        light_theme["terminal.ansi.black"] = hex_with_alpha(get_term_color(0), "ff")
        light_theme["terminal.ansi.white"] = hex_with_alpha(
            darken(get_term_color(7), 0.5), "ff"
        )
        light_theme["terminal.ansi.bright_black"] = hex_with_alpha(
            darken(get_term_color(8), 0.6), "ff"
        )
        light_theme["terminal.ansi.bright_white"] = hex_with_alpha(
            darken(get_term_color(15), 0.3), "ff"
        )

        color_map = {
            "red": 1,
            "bright_red": 9,
            "dim_red": 1,
            "green": 2,
            "bright_green": 10,
            "dim_green": 2,
            "yellow": 3,
            "bright_yellow": 11,
            "dim_yellow": 3,
            "blue": 4,
            "bright_blue": 12,
            "dim_blue": 4,
            "magenta": 5,
            "bright_magenta": 13,
            "dim_magenta": 5,
            "cyan": 6,
            "bright_cyan": 14,
            "dim_cyan": 6,
        }

        for name, idx in color_map.items():
            base_color = get_term_color(idx)
            if "bright" in name:
                color = darken(base_color, 0.75)
            elif "dim" in name:
                color = darken(base_color, 0.5)
            else:
                color = darken(base_color, 0.85)
            light_theme[f"terminal.ansi.{name}"] = hex_with_alpha(color, "ff")

        player_colors = [
            saturate(primary, 1.3),
            saturate(error, 1.3),
            saturate(tertiary, 1.3),
            saturate(secondary, 1.3),
        ]
        light_theme["players"] = [
            {
                "cursor": hex_with_alpha(color, "ff"),
                "background": hex_with_alpha(color, "ff"),
                "selection": hex_with_alpha(lighten(color, 1.2), "3d"),
            }
            for color in player_colors
        ]

        light_theme["syntax"] = build_syntax_map(
            primary=primary,
            appearance="light",
        )

        return light_theme

    def build_zed_alt_theme(appearance):
        template_style = alt_template_styles.get(appearance)

        if template_style:
            style = render_alt_template(template_style)
        else:
            style = (
                build_zed_dark_theme()
                if appearance == "dark"
                else build_zed_light_theme()
            )

        primary = resolve_material_color("primary", appearance)
        # Keep syntax vivid and cohesive even on desaturated wallpapers.
        style["syntax"] = build_syntax_map(
            primary=primary,
            appearance=appearance,
        )

        return style

    def make_borderless_style(style):
        borderless = copy.deepcopy(style)
        border_keys = [
            "border",
            "border.variant",
            "border.focused",
            "border.selected",
            "border.transparent",
            "border.disabled",
            "scrollbar.thumb.border",
            "scrollbar.track.border",
        ]
        for key in border_keys:
            if key in borderless:
                borderless[key] = "#00000000"
        borderless["panel.focused_border"] = None
        borderless["pane.focused_border"] = None
        return borderless

    dark_style = build_zed_dark_theme()
    light_style = build_zed_light_theme()
    alt_dark_style = build_zed_alt_theme("dark")
    alt_light_style = build_zed_alt_theme("light")
    borderless_dark_style = make_borderless_style(dark_style)
    borderless_light_style = make_borderless_style(light_style)

    theme_data = {
        "$schema": "https://zed.dev/schema/themes/v0.2.0.json",
        "name": "iNiR Material",
        "author": "iNiR Theme System",
        "themes": [
            {"name": "iNiR Dark", "appearance": "dark", "style": dark_style},
            {"name": "iNiR Light", "appearance": "light", "style": light_style},
            {
                "name": "iNiR Borderless Dark",
                "appearance": "dark",
                "style": borderless_dark_style,
            },
            {
                "name": "iNiR Borderless Light",
                "appearance": "light",
                "style": borderless_light_style,
            },
            {"name": "iNiR-alt Dark", "appearance": "dark", "style": alt_dark_style},
            {
                "name": "iNiR-alt Light",
                "appearance": "light",
                "style": alt_light_style,
            },
        ],
    }

    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(theme_data, f, indent=2, ensure_ascii=False)

    print(f"\u2713 Generated Zed theme")
