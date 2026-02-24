#!/usr/bin/env python3
"""
Generate Zed editor theme from Material You colors and SCSS terminal colors.
Creates both dark and light theme variants with auto-detected palette scheme.
"""

import json
import os
import re
import sys
from pathlib import Path


def generate_zed_config(colors, scss_path, output_path):
    """Generate Zed editor theme from Material You colors and SCSS terminal colors."""
    colors_json_path = os.path.expanduser(
        "~/.local/state/quickshell/user/generated/colors.json"
    )

    try:
        with open(colors_json_path, "r") as f:
            my_colors = json.load(f)
    except FileNotFoundError:
        print(
            f"Warning: Could not find colors.json. Using defaults for Zed theme.",
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

    my_colors = {k: v.lower() for k, v in my_colors.items()}

    def parse_scss_colors(scss_path):
        """Parse material_colors.scss and extract color variables"""
        term_colors = {}
        try:
            with open(scss_path, "r") as f:
                for line in f:
                    match = re.match(r"\$(\w+):\s*(#[A-Fa-f0-9]{6});", line.strip())
                    if match:
                        name, value = match.groups()
                        term_colors[name] = value
        except FileNotFoundError:
            pass
        return term_colors

    term_colors = parse_scss_colors(scss_path)

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
        on_surface = _dk_on_surface
        on_surface_variant = _dk_on_surface_variant

        theme = {
            "border": hex_with_alpha(outline, "ff"),
            "border.variant": hex_with_alpha(adjust_lightness(surface_low, 0.8), "ff"),
            "border.focused": hex_with_alpha(primary, "ff"),
            "border.selected": hex_with_alpha(adjust_lightness(primary, 0.7), "ff"),
            "border.transparent": "#00000000",
            "border.disabled": hex_with_alpha(adjust_lightness(outline, 0.5), "ff"),
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

        for i in range(16):
            term_color = term_colors.get(
                f"term{i}", f"#{282828 if i == 0 else 'ffffff'}"
            )
            theme[f"terminal.ansi.black"] = (
                hex_with_alpha(term_colors.get("term0", "#000000"), "ff")
                if i == 0
                else theme.get("terminal.ansi.black")
            )
            theme[f"terminal.ansi.bright_black"] = (
                hex_with_alpha(term_colors.get("term8", "#555555"), "ff")
                if i == 8
                else theme.get("terminal.ansi.bright_black")
            )
            theme[f"terminal.ansi.dim_black"] = (
                hex_with_alpha(
                    adjust_lightness(term_colors.get("term0", "#000000"), 0.6), "ff"
                )
                if i == 0
                else theme.get("terminal.ansi.dim_black")
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
            base_color = term_colors.get(f"term{idx}", "#ffffff")
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

        theme["syntax"] = {
            "attribute": {
                "color": hex_with_alpha(primary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "boolean": {
                "color": hex_with_alpha(tertiary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "comment": {
                "color": hex_with_alpha(
                    adjust_lightness(on_surface_variant, 0.7), "ff"
                ),
                "font_style": None,
                "font_weight": None,
            },
            "comment.doc": {
                "color": hex_with_alpha(
                    adjust_lightness(on_surface_variant, 0.8), "ff"
                ),
                "font_style": None,
                "font_weight": None,
            },
            "constant": {
                "color": hex_with_alpha(adjust_lightness(tertiary, 0.9), "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "constructor": {
                "color": hex_with_alpha(primary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "embedded": {
                "color": hex_with_alpha(on_surface, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "emphasis": {
                "color": hex_with_alpha(primary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "emphasis.strong": {
                "color": hex_with_alpha(adjust_lightness(tertiary, 0.8), "ff"),
                "font_style": None,
                "font_weight": 700,
            },
            "enum": {
                "color": hex_with_alpha(secondary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "function": {
                "color": hex_with_alpha(primary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "hint": {
                "color": hex_with_alpha(adjust_lightness(primary, 0.7), "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "keyword": {
                "color": hex_with_alpha(secondary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "label": {
                "color": hex_with_alpha(primary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "link_text": {
                "color": hex_with_alpha(primary, "ff"),
                "font_style": "normal",
                "font_weight": None,
            },
            "link_uri": {
                "color": hex_with_alpha(secondary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "namespace": {
                "color": hex_with_alpha(on_surface, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "number": {
                "color": hex_with_alpha(adjust_lightness(tertiary, 0.8), "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "operator": {
                "color": hex_with_alpha(secondary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "predictive": {
                "color": hex_with_alpha(adjust_lightness(secondary, 0.8), "ff"),
                "font_style": "italic",
                "font_weight": None,
            },
            "preproc": {
                "color": hex_with_alpha(on_surface, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "primary": {
                "color": hex_with_alpha(on_surface, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "property": {
                "color": hex_with_alpha(adjust_lightness(primary, 0.85), "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "punctuation": {
                "color": hex_with_alpha(on_surface, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "punctuation.bracket": {
                "color": hex_with_alpha(adjust_lightness(on_surface, 0.9), "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "punctuation.delimiter": {
                "color": hex_with_alpha(adjust_lightness(on_surface, 0.9), "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "punctuation.list_marker": {
                "color": hex_with_alpha(adjust_lightness(primary, 0.85), "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "punctuation.markup": {
                "color": hex_with_alpha(adjust_lightness(primary, 0.85), "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "punctuation.special": {
                "color": hex_with_alpha(adjust_lightness(error, 0.8), "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "selector": {
                "color": hex_with_alpha(adjust_lightness(tertiary, 0.9), "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "selector.pseudo": {
                "color": hex_with_alpha(primary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "string": {
                "color": hex_with_alpha(tertiary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "string.escape": {
                "color": hex_with_alpha(on_surface_variant, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "string.regex": {
                "color": hex_with_alpha(tertiary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "string.special": {
                "color": hex_with_alpha(tertiary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "string.special.symbol": {
                "color": hex_with_alpha(tertiary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "text.literal": {
                "color": hex_with_alpha(tertiary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "title": {
                "color": hex_with_alpha(primary, "ff"),
                "font_style": None,
                "font_weight": 400,
            },
            "variable.special": {
                "color": hex_with_alpha(tertiary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "variable": {
                "color": hex_with_alpha(on_surface, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "variable.special": {
                "color": hex_with_alpha(adjust_lightness(tertiary, 0.8), "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "variant": {
                "color": hex_with_alpha(primary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
        }

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
        on_primary = my_colors.get("on_primary", "#ffffff")

        def lighten(color, factor=1.15):
            return adjust_lightness(color, factor)

        def darken(color, factor=0.85):
            return adjust_lightness(color, factor)

        light_theme = {
            "border": hex_with_alpha(outline_variant, "ff"),
            "border.variant": hex_with_alpha(lighten(outline_variant, 1.1), "ff"),
            "border.focused": hex_with_alpha(primary, "ff"),
            "border.selected": hex_with_alpha(darken(primary, 0.9), "ff"),
            "border.transparent": "#00000000",
            "border.disabled": hex_with_alpha(lighten(outline_variant, 1.2), "ff"),
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
            "version_control.added": hex_with_alpha(darken(tertiary, 0.8), "ff"),
            "version_control.modified": hex_with_alpha(darken(primary, 0.85), "ff"),
            "version_control.word_added": hex_with_alpha(tertiary, "40"),
            "version_control.word_deleted": hex_with_alpha(error, "40"),
            "version_control.deleted": hex_with_alpha(darken(error, 0.85), "ff"),
            "version_control.conflict_marker.ours": hex_with_alpha(tertiary, "25"),
            "version_control.conflict_marker.theirs": hex_with_alpha(primary, "25"),
            "conflict": hex_with_alpha(darken(tertiary, 0.8), "ff"),
            "conflict.background": hex_with_alpha(tertiary, "18"),
            "conflict.border": hex_with_alpha(darken(tertiary, 0.7), "ff"),
            "created": hex_with_alpha(darken(tertiary, 0.8), "ff"),
            "created.background": hex_with_alpha(tertiary, "18"),
            "created.border": hex_with_alpha(darken(tertiary, 0.7), "ff"),
            "deleted": hex_with_alpha(darken(error, 0.85), "ff"),
            "deleted.background": hex_with_alpha(error, "18"),
            "deleted.border": hex_with_alpha(darken(error, 0.7), "ff"),
            "error": hex_with_alpha(darken(error, 0.85), "ff"),
            "error.background": hex_with_alpha(error, "18"),
            "error.border": hex_with_alpha(darken(error, 0.7), "ff"),
            "hidden": hex_with_alpha(on_surface_variant, "ff"),
            "hidden.background": hex_with_alpha(on_surface_variant, "18"),
            "hidden.border": hex_with_alpha(outline_variant, "ff"),
            "hint": hex_with_alpha(darken(primary, 0.8), "ff"),
            "hint.background": hex_with_alpha(primary, "18"),
            "hint.border": hex_with_alpha(darken(primary, 0.7), "ff"),
            "ignored": hex_with_alpha(on_surface_variant, "ff"),
            "ignored.background": hex_with_alpha(on_surface_variant, "18"),
            "ignored.border": hex_with_alpha(outline_variant, "ff"),
            "info": hex_with_alpha(darken(primary, 0.85), "ff"),
            "info.background": hex_with_alpha(primary, "18"),
            "info.border": hex_with_alpha(darken(primary, 0.7), "ff"),
            "modified": hex_with_alpha(darken(primary, 0.85), "ff"),
            "modified.background": hex_with_alpha(primary, "18"),
            "modified.border": hex_with_alpha(darken(primary, 0.7), "ff"),
            "predictive": hex_with_alpha(darken(secondary, 0.8), "ff"),
            "predictive.background": hex_with_alpha(secondary, "18"),
            "predictive.border": hex_with_alpha(darken(secondary, 0.7), "ff"),
            "renamed": hex_with_alpha(darken(primary, 0.85), "ff"),
            "renamed.background": hex_with_alpha(primary, "18"),
            "renamed.border": hex_with_alpha(darken(primary, 0.7), "ff"),
            "success": hex_with_alpha(darken(tertiary, 0.8), "ff"),
            "success.background": hex_with_alpha(tertiary, "18"),
            "success.border": hex_with_alpha(darken(tertiary, 0.7), "ff"),
            "unreachable": hex_with_alpha(on_surface_variant, "ff"),
            "unreachable.background": hex_with_alpha(on_surface_variant, "18"),
            "unreachable.border": hex_with_alpha(outline_variant, "ff"),
            "warning": hex_with_alpha(darken(tertiary, 0.85), "ff"),
            "warning.background": hex_with_alpha(tertiary, "18"),
            "warning.border": hex_with_alpha(darken(tertiary, 0.7), "ff"),
        }

        for i in range(16):
            term_color = term_colors.get(f"term{i}", "#000000")
            if i == 0:
                light_theme[f"terminal.ansi.black"] = hex_with_alpha(term_color, "ff")
            elif i == 7:
                light_theme[f"terminal.ansi.white"] = hex_with_alpha(
                    darken(term_color, 0.5), "ff"
                )
            elif i == 8:
                light_theme[f"terminal.ansi.bright_black"] = hex_with_alpha(
                    darken(term_color, 0.6), "ff"
                )
            elif i == 15:
                light_theme[f"terminal.ansi.bright_white"] = hex_with_alpha(
                    darken(term_color, 0.3), "ff"
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
            base_color = term_colors.get(f"term{idx}", "#000000")
            if "bright" in name:
                color = darken(base_color, 0.75)
            elif "dim" in name:
                color = darken(base_color, 0.5)
            else:
                color = darken(base_color, 0.85)
            light_theme[f"terminal.ansi.{name}"] = hex_with_alpha(color, "ff")

        player_colors = [
            darken(primary, 0.8),
            darken(error, 0.85),
            darken(tertiary, 0.8),
            darken(secondary, 0.8),
        ]
        light_theme["players"] = [
            {
                "cursor": hex_with_alpha(color, "ff"),
                "background": hex_with_alpha(color, "ff"),
                "selection": hex_with_alpha(lighten(color, 1.2), "3d"),
            }
            for color in player_colors
        ]

        light_theme["syntax"] = {
            "attribute": {
                "color": hex_with_alpha(primary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "boolean": {
                "color": hex_with_alpha(tertiary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "comment": {
                "color": hex_with_alpha(on_surface_variant, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "comment.doc": {
                "color": hex_with_alpha(on_surface_variant, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "constant": {
                "color": hex_with_alpha(tertiary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "constructor": {
                "color": hex_with_alpha(primary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "embedded": {
                "color": hex_with_alpha(on_surface, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "emphasis": {
                "color": hex_with_alpha(primary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "emphasis.strong": {
                "color": hex_with_alpha(tertiary, "ff"),
                "font_style": None,
                "font_weight": 700,
            },
            "enum": {
                "color": hex_with_alpha(secondary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "function": {
                "color": hex_with_alpha(primary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "hint": {
                "color": hex_with_alpha(primary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "keyword": {
                "color": hex_with_alpha(secondary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "label": {
                "color": hex_with_alpha(primary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "link_text": {
                "color": hex_with_alpha(primary, "ff"),
                "font_style": "normal",
                "font_weight": None,
            },
            "link_uri": {
                "color": hex_with_alpha(secondary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "namespace": {
                "color": hex_with_alpha(on_surface, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "number": {
                "color": hex_with_alpha(tertiary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "operator": {
                "color": hex_with_alpha(secondary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "predictive": {
                "color": hex_with_alpha(secondary, "ff"),
                "font_style": "italic",
                "font_weight": None,
            },
            "preproc": {
                "color": hex_with_alpha(on_surface, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "primary": {
                "color": hex_with_alpha(on_surface, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "property": {
                "color": hex_with_alpha(primary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "punctuation": {
                "color": hex_with_alpha(on_surface, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "punctuation.bracket": {
                "color": hex_with_alpha(on_surface_variant, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "punctuation.delimiter": {
                "color": hex_with_alpha(on_surface_variant, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "punctuation.list_marker": {
                "color": hex_with_alpha(primary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "punctuation.markup": {
                "color": hex_with_alpha(primary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "punctuation.special": {
                "color": hex_with_alpha(error, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "selector": {
                "color": hex_with_alpha(tertiary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "selector.pseudo": {
                "color": hex_with_alpha(primary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "string": {
                "color": hex_with_alpha(tertiary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "string.escape": {
                "color": hex_with_alpha(on_surface_variant, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "string.regex": {
                "color": hex_with_alpha(tertiary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "string.special": {
                "color": hex_with_alpha(tertiary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "string.special.symbol": {
                "color": hex_with_alpha(tertiary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "tag": {
                "color": hex_with_alpha(primary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "text.literal": {
                "color": hex_with_alpha(tertiary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "title": {
                "color": hex_with_alpha(primary, "ff"),
                "font_style": None,
                "font_weight": 400,
            },
            "type": {
                "color": hex_with_alpha(secondary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "variable": {
                "color": hex_with_alpha(on_surface, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "variable.special": {
                "color": hex_with_alpha(tertiary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
            "variant": {
                "color": hex_with_alpha(primary, "ff"),
                "font_style": None,
                "font_weight": None,
            },
        }

        return light_theme

    dark_style = build_zed_dark_theme()
    light_style = build_zed_light_theme()

    theme_data = {
        "$schema": "https://zed.dev/schema/themes/v0.2.0.json",
        "name": "iNiR Material",
        "author": "iNiR Theme System",
        "themes": [
            {"name": "iNiR Dark", "appearance": "dark", "style": dark_style},
            {"name": "iNiR Light", "appearance": "light", "style": light_style},
        ],
    }

    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(theme_data, f, indent=2, ensure_ascii=False)

    print(f"\u2713 Generated Zed theme")
