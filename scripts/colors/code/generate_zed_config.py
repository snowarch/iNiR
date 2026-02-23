#!/usr/bin/env python3
"""
Generate Zed editor theme from Material You colors
Creates both dark and light theme variants
"""

import argparse
import json
import os
from pathlib import Path
from typing import Dict, Optional

COLOR_SOURCE = Path(
    os.environ.get(
        "QUICKSHELL_COLORS_JSON",
        "~/.local/state/quickshell/user/generated/colors.json",
    )
).expanduser()

SCSS_SOURCE = Path(
    os.environ.get(
        "QUICKSHELL_SCSS_FILE",
        "~/.local/state/quickshell/user/generated/material_colors.scss",
    )
).expanduser()

OUTPUT_DIR = Path(
    os.environ.get(
        "ZED_THEMES_DIR",
        "~/.config/zed/themes",
    )
).expanduser()

OUTPUT_FILE = OUTPUT_DIR / "ii-theme.json"


def load_colors() -> Dict[str, str]:
    """Load colors from the generated colors.json file"""
    if not COLOR_SOURCE.exists():
        raise FileNotFoundError(
            f"Material colors file not found: {COLOR_SOURCE}. "
            "Ensure the color generation script has been executed successfully."
        )
    with COLOR_SOURCE.open("r", encoding="utf-8") as f:
        data = json.load(f)
    return {k: v.lower() for k, v in data.items()}


def parse_scss_colors(scss_path: Path) -> Dict[str, str]:
    """Parse material_colors.scss and extract terminal color variables"""
    colors = {}
    import re

    try:
        with scss_path.open("r") as f:
            for line in f:
                # Match lines like: $term0: #282828;
                match = re.match(r"\$(\w+):\s*(#[A-Fa-f0-9]{6});", line.strip())
                if match:
                    name, value = match.groups()
                    colors[name] = value.lower()
    except FileNotFoundError:
        print(
            f"Warning: Could not find {scss_path}. Terminal colors may be incomplete.",
            file=sys.stderr,
        )
    return colors


def hex_to_rgba(hex_color: str, alpha: float = 1.0) -> str:
    """Convert hex color to rgba format with alpha"""
    hex_color = hex_color.lstrip("#")
    if len(hex_color) == 6:
        r = int(hex_color[0:2], 16)
        g = int(hex_color[2:4], 16)
        b = int(hex_color[4:6], 16)
        return f"rgba({r}, {g}, {b}, {alpha:.2f})"
    return hex_color


def hex_with_alpha(hex_color: str, alpha_hex: str) -> str:
    """Add alpha hex value to color"""
    hex_color = hex_color.lstrip("#")
    return f"#{hex_color}{alpha_hex}"


def adjust_lightness(hex_color: str, factor: float) -> str:
    """Adjust lightness of hex color (factor > 1 = lighter, factor < 1 = darker)"""
    hex_color = hex_color.lstrip("#")
    r = int(hex_color[0:2], 16) / 255.0
    g = int(hex_color[2:4], 16) / 255.0
    b = int(hex_color[4:6], 16) / 255.0

    # Convert to HSL
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

    # Adjust lightness
    l = max(0.0, min(1.0, l * factor))

    # Convert back to RGB
    def hue_to_rgb(p: float, q: float, t: float) -> float:
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


def build_dark_theme(
    colors: Dict[str, str], term_colors: Dict[str, str] = None
) -> Dict:
    """Build dark theme color mapping"""
    primary = colors.get("primary", "#7aa2f7")
    secondary = colors.get("secondary", "#bb9af7")
    tertiary = colors.get("tertiary", "#9ece6a")
    error = colors.get("error", "#f7768e")
    surface = colors.get("surface", "#1a1b26")
    surface_low = colors.get("surface_container_low", "#24283b")
    surface_std = colors.get("surface_container", "#414868")
    surface_high = colors.get("surface_container_high", "#565f89")
    outline = colors.get("outline", "#565f89")
    on_surface = colors.get("on_surface", "#c0caf5")
    on_surface_variant = colors.get("on_surface_variant", "#9aa5ce")
    on_primary = colors.get("on_primary", "#1a1b26")

    # Get terminal colors if available
    if term_colors is None:
        term_colors = {}
    # Ensure we have term0-term15
    for i in range(16):
        if f"term{i}" not in term_colors:
            term_colors[f"term{i}"] = "#ffffff"

    # Build theme
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
        "tab.active_background": hex_with_alpha(adjust_lightness(surface, 0.9), "ff"),
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
        "editor.document_highlight.write_background": hex_with_alpha(surface_std, "66"),
    }

    # Terminal colors
    theme["terminal.background"] = hex_with_alpha(surface, "ff")
    theme["terminal.foreground"] = hex_with_alpha(on_surface, "ff")
    theme["terminal.bright_foreground"] = hex_with_alpha(on_surface, "ff")
    theme["terminal.dim_foreground"] = hex_with_alpha(
        adjust_lightness(on_surface, 0.6), "ff"
    )

    for i in range(16):
        theme[f"terminal.ansi.black"] = (
            hex_with_alpha(term_colors.get("term0", "#000000"), "ff")
            if i == 0
            else hex_with_alpha(term_colors.get(f"term{i}", "#000000"), "ff")
        )
        theme[f"terminal.ansi.bright_black"] = (
            hex_with_alpha(term_colors.get("term8", "#555555"), "ff")
            if i == 8
            else theme.get(f"terminal.ansi.bright_black", "#555555ff")
        )
        theme[f"terminal.ansi.dim_black"] = (
            hex_with_alpha(
                adjust_lightness(term_colors.get("term0", "#000000"), 0.6), "ff"
            )
            if i == 0
            else theme.get(f"terminal.ansi.dim_black", "#333333ff")
        )

    # Map remaining terminal colors
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

    # Status and diagnostic colors
    theme["link_text.hover"] = hex_with_alpha(primary, "ff")

    # Version control
    theme["version_control.added"] = hex_with_alpha(tertiary, "ff")
    theme["version_control.modified"] = hex_with_alpha(
        adjust_lightness(primary, 0.8), "ff"
    )
    theme["version_control.word_added"] = hex_with_alpha(tertiary, "59")
    theme["version_control.word_deleted"] = hex_with_alpha(error, "cc")
    theme["version_control.deleted"] = hex_with_alpha(error, "ff")
    theme["version_control.conflict_marker.ours"] = hex_with_alpha(tertiary, "1a")
    theme["version_control.conflict_marker.theirs"] = hex_with_alpha(primary, "1a")

    # Conflict
    theme["conflict"] = hex_with_alpha(adjust_lightness(tertiary, 0.8), "ff")
    theme["conflict.background"] = hex_with_alpha(adjust_lightness(tertiary, 0.8), "1a")
    theme["conflict.border"] = hex_with_alpha(adjust_lightness(tertiary, 0.6), "ff")

    # Created
    theme["created"] = hex_with_alpha(tertiary, "ff")
    theme["created.background"] = hex_with_alpha(tertiary, "1a")
    theme["created.border"] = hex_with_alpha(adjust_lightness(tertiary, 0.6), "ff")

    # Deleted
    theme["deleted"] = hex_with_alpha(error, "ff")
    theme["deleted.background"] = hex_with_alpha(error, "1a")
    theme["deleted.border"] = hex_with_alpha(adjust_lightness(error, 0.6), "ff")

    # Error
    theme["error"] = hex_with_alpha(error, "ff")
    theme["error.background"] = hex_with_alpha(error, "1a")
    theme["error.border"] = hex_with_alpha(adjust_lightness(error, 0.6), "ff")

    # Hidden
    theme["hidden"] = hex_with_alpha(on_surface_variant, "ff")
    theme["hidden.background"] = hex_with_alpha(
        adjust_lightness(on_surface_variant, 0.3), "1a"
    )
    theme["hidden.border"] = hex_with_alpha(outline, "ff")

    # Hint
    hint_color = adjust_lightness(primary, 0.7)
    theme["hint"] = hex_with_alpha(hint_color, "ff")
    theme["hint.background"] = hex_with_alpha(hint_color, "1a")
    theme["hint.border"] = hex_with_alpha(adjust_lightness(primary, 0.6), "ff")

    # Ignored
    theme["ignored"] = hex_with_alpha(on_surface_variant, "ff")
    theme["ignored.background"] = hex_with_alpha(
        adjust_lightness(on_surface_variant, 0.3), "1a"
    )
    theme["ignored.border"] = hex_with_alpha(outline, "ff")

    # Info
    theme["info"] = hex_with_alpha(primary, "ff")
    theme["info.background"] = hex_with_alpha(primary, "1a")
    theme["info.border"] = hex_with_alpha(adjust_lightness(primary, 0.6), "ff")

    # Modified
    modified_color = adjust_lightness(primary, 0.8)
    theme["modified"] = hex_with_alpha(modified_color, "ff")
    theme["modified.background"] = hex_with_alpha(modified_color, "1a")
    theme["modified.border"] = hex_with_alpha(
        adjust_lightness(modified_color, 0.6), "ff"
    )

    # Predictive
    predictive_color = adjust_lightness(secondary, 0.8)
    theme["predictive"] = hex_with_alpha(predictive_color, "ff")
    theme["predictive.background"] = hex_with_alpha(predictive_color, "1a")
    theme["predictive.border"] = hex_with_alpha(
        adjust_lightness(predictive_color, 0.6), "ff"
    )

    # Renamed
    theme["renamed"] = hex_with_alpha(primary, "ff")
    theme["renamed.background"] = hex_with_alpha(primary, "1a")
    theme["renamed.border"] = hex_with_alpha(adjust_lightness(primary, 0.6), "ff")

    # Success
    theme["success"] = hex_with_alpha(tertiary, "ff")
    theme["success.background"] = hex_with_alpha(tertiary, "1a")
    theme["success.border"] = hex_with_alpha(adjust_lightness(tertiary, 0.6), "ff")

    # Unreachable
    theme["unreachable"] = hex_with_alpha(on_surface_variant, "ff")
    theme["unreachable.background"] = hex_with_alpha(
        adjust_lightness(on_surface_variant, 0.3), "1a"
    )
    theme["unreachable.border"] = hex_with_alpha(outline, "ff")

    # Warning
    warning_color = adjust_lightness(tertiary, 0.9)
    theme["warning"] = hex_with_alpha(warning_color, "ff")
    theme["warning.background"] = hex_with_alpha(warning_color, "1a")
    theme["warning.border"] = hex_with_alpha(adjust_lightness(warning_color, 0.6), "ff")

    # Players (multiplayer cursors)
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

    # Syntax highlighting
    theme["syntax"] = {
        "attribute": {
            "color": hex_with_alpha(primary, "ff"),
            "font_style": None,
            "font_weight": None,
        },
        "boolean": {
            "color": hex_with_alpha(adjust_lightness(tertiary, 0.8), "ff"),
            "font_style": None,
            "font_weight": None,
        },
        "comment": {
            "color": hex_with_alpha(adjust_lightness(on_surface_variant, 0.7), "ff"),
            "font_style": None,
            "font_weight": None,
        },
        "comment.doc": {
            "color": hex_with_alpha(adjust_lightness(on_surface_variant, 0.8), "ff"),
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
            "color": hex_with_alpha(hint_color, "ff"),
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
            "color": hex_with_alpha(predictive_color, "ff"),
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
            "color": hex_with_alpha(adjust_lightness(on_surface_variant, 0.8), "ff"),
            "font_style": None,
            "font_weight": None,
        },
        "string.regex": {
            "color": hex_with_alpha(adjust_lightness(tertiary, 0.8), "ff"),
            "font_style": None,
            "font_weight": None,
        },
        "string.special": {
            "color": hex_with_alpha(adjust_lightness(tertiary, 0.8), "ff"),
            "font_style": None,
            "font_weight": None,
        },
        "string.special.symbol": {
            "color": hex_with_alpha(adjust_lightness(tertiary, 0.8), "ff"),
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
            "color": hex_with_alpha(adjust_lightness(primary, 0.85), "ff"),
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


def build_light_theme(
    colors: Dict[str, str], term_colors: Dict[str, str] = None
) -> Dict:
    """Build light theme color mapping"""
    # For light theme, we invert and adjust the dark theme colors
    dark_theme = build_dark_theme(colors, term_colors)

    # Invert backgrounds and foregrounds
    light_theme = {}
    for key, value in dark_theme.items():
        if isinstance(value, dict):
            # Handle nested dicts like syntax
            light_theme[key] = value.copy()
        elif value is None:
            light_theme[key] = None
        else:
            # Invert color for light theme
            if "background" in key.lower():
                light_theme[key] = adjust_lightness(value, 3.5)
            elif "foreground" in key.lower() or key in [
                "text",
                "icon",
                "editor.foreground",
                "terminal.foreground",
            ]:
                light_theme[key] = adjust_lightness(value, 0.3)
            else:
                light_theme[key] = value

    # Adjust specific colors for better light theme appearance
    light_theme["background"] = adjust_lightness(colors.get("surface", "#ffffff"), 2.5)
    light_theme["surface.background"] = adjust_lightness(
        colors.get("surface", "#ffffff"), 2.3
    )
    light_theme["elevated_surface.background"] = adjust_lightness(
        colors.get("surface_container_low", "#f0f0f0"), 2.0
    )
    light_theme["element.background"] = adjust_lightness(
        colors.get("surface_container_low", "#f0f0f0"), 2.0
    )
    light_theme["editor.background"] = adjust_lightness(
        colors.get("surface", "#ffffff"), 2.5
    )
    light_theme["editor.gutter.background"] = adjust_lightness(
        colors.get("surface", "#ffffff"), 2.5
    )
    light_theme["terminal.background"] = adjust_lightness(
        colors.get("surface", "#ffffff"), 2.5
    )

    # Ensure text is dark enough
    light_theme["text"] = adjust_lightness(light_theme["text"], 0.3)
    light_theme["editor.foreground"] = adjust_lightness(
        light_theme["editor.foreground"], 0.3
    )
    light_theme["terminal.foreground"] = adjust_lightness(
        light_theme["terminal.foreground"], 0.3
    )

    return light_theme


def generate_zed_theme(
    colors: Dict[str, str], output_path: Path, scss_path: Path = None
) -> None:
    """Generate complete Zed theme JSON file"""

    # Ensure output directory exists
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Load terminal colors from SCSS
    if scss_path and scss_path.exists():
        term_colors = parse_scss_colors(scss_path)
    else:
        term_colors = None

    # Build themes
    dark_style = build_dark_theme(colors, term_colors)
    light_style = build_light_theme(colors, term_colors)

    # Create theme structure
    theme_data = {
        "$schema": "https://zed.dev/schema/themes/v0.2.0.json",
        "name": "iNiR Material",
        "author": "iNiR Theme System",
        "themes": [
            {"name": "iNiR Dark", "appearance": "dark", "style": dark_style},
            {"name": "iNiR Light", "appearance": "light", "style": light_style},
        ],
    }

    # Write theme file
    with output_path.open("w", encoding="utf-8") as f:
        json.dump(theme_data, f, indent=2, ensure_ascii=False)

    print(f"Generated Zed theme: {output_path}")


def main():
    parser = argparse.ArgumentParser(
        description="Generate Zed editor theme from Material You colors"
    )
    parser.add_argument("--colors", type=str, help="Path to colors.json file")
    parser.add_argument("--scss", type=str, help="Path to material_colors.scss file")
    parser.add_argument("--output", type=str, help="Output path for theme file")
    args = parser.parse_args()

    # Override paths if provided
    color_source = COLOR_SOURCE
    scss_source = SCSS_SOURCE
    if args.colors:
        color_source = Path(args.colors).expanduser()
    if args.scss:
        scss_source = Path(args.scss).expanduser()

    if args.output:
        output_path = Path(args.output).expanduser()
    else:
        output_path = OUTPUT_FILE

    try:
        colors = load_colors()

        # If custom colors path, update the source
        if args.colors:
            global COLOR_SOURCE
            COLOR_SOURCE = color_source

        generate_zed_theme(colors, output_path, scss_source)
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    import sys

    main()
