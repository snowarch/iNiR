#!/usr/bin/env python3
"""
Generate OpenCode TUI theme from Material You colors (material_colors.scss).
Outputs ~/.config/opencode/themes/inir.json

Part of iNiR wallpaper theming pipeline.
Called from applycolor.sh via generate_terminal_configs.py or directly.
"""

import json
import os
import re
import sys
from pathlib import Path


def parse_scss_colors(scss_path: str) -> dict[str, str]:
    """Parse material_colors.scss and extract color variables."""
    colors = {}
    with open(scss_path, "r") as f:
        for line in f:
            match = re.match(r"\$(\w+):\s*(#[A-Fa-f0-9]{6});", line.strip())
            if match:
                name, value = match.groups()
                colors[name] = value.lower()
    return colors


def hex_to_rgb(hex_color: str) -> tuple[int, int, int]:
    h = hex_color.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def rgb_to_hex(r: int, g: int, b: int) -> str:
    return f"#{r:02x}{g:02x}{b:02x}"


def blend(color1: str, color2: str, factor: float = 0.5) -> str:
    """Blend two hex colors. factor=0 → color1, factor=1 → color2."""
    r1, g1, b1 = hex_to_rgb(color1)
    r2, g2, b2 = hex_to_rgb(color2)
    r = int(r1 + (r2 - r1) * factor)
    g = int(g1 + (g2 - g1) * factor)
    b = int(b1 + (b2 - b1) * factor)
    return rgb_to_hex(r, g, b)


def adjust_lightness(hex_color: str, factor: float) -> str:
    """Adjust lightness. factor > 1 = lighter, < 1 = darker."""
    r, g, b = hex_to_rgb(hex_color)
    # Simple approach: scale towards white (factor>1) or black (factor<1)
    if factor > 1:
        r = min(255, int(r + (255 - r) * (factor - 1)))
        g = min(255, int(g + (255 - g) * (factor - 1)))
        b = min(255, int(b + (255 - b) * (factor - 1)))
    else:
        r = max(0, int(r * factor))
        g = max(0, int(g * factor))
        b = max(0, int(b * factor))
    return rgb_to_hex(r, g, b)


def with_alpha(hex_color: str, alpha: str) -> str:
    """Append alpha hex to color: #rrggbb + aa → #rrggbbaa."""
    return f"{hex_color}{alpha}"


def generate_opencode_theme(colors: dict[str, str]) -> dict:
    """Map Material You tokens → OpenCode theme JSON."""

    is_dark = colors.get("darkmode", "").lower() != "false"

    # ── Core Material tokens ───────────────────────────────
    primary = colors.get("primary", "#7aa2f7")
    on_primary = colors.get("onPrimary", "#1a1b26")
    primary_container = colors.get("primaryContainer", "#004c6b")
    on_primary_container = colors.get("onPrimaryContainer", "#c6e7ff")

    secondary = colors.get("secondary", "#bb9af7")
    on_secondary = colors.get("onSecondary", "#1a1b26")
    secondary_container = colors.get("secondaryContainer", "#394b58")

    tertiary = colors.get("tertiary", "#9ece6a")
    on_tertiary = colors.get("onTertiary", "#332c4c")
    tertiary_container = colors.get("tertiaryContainer", "#958bb1")

    surface = colors.get("surface", "#0f1417")
    surface_dim = colors.get("surfaceDim", "#0f1417")
    surface_bright = colors.get("surfaceBright", "#353a3d")
    surface_container = colors.get("surfaceContainer", "#1c2024")
    surface_container_low = colors.get("surfaceContainerLow", "#181c1f")
    surface_container_high = colors.get("surfaceContainerHigh", "#262b2e")
    surface_container_highest = colors.get("surfaceContainerHighest", "#313539")
    on_surface = colors.get("onSurface", "#dfe3e7")
    on_surface_variant = colors.get("onSurfaceVariant", "#c1c7ce")

    background = colors.get("background", "#0f1417")
    outline = colors.get("outline", "#8b9298")
    outline_variant = colors.get("outlineVariant", "#41484d")
    shadow = colors.get("shadow", "#000000")

    error = colors.get("error", "#ffb4ab")
    on_error = colors.get("onError", "#690005")
    error_container = colors.get("errorContainer", "#93000a")

    success = colors.get("success", "#b5ccba")
    on_success = colors.get("onSuccess", "#213528")
    success_container = colors.get("successContainer", "#374b3e")

    inverse_surface = colors.get("inverseSurface", "#dfe3e7")
    inverse_on_surface = colors.get("inverseOnSurface", "#2c3135")

    # ── Terminal ANSI colors (harmonized with palette) ─────
    term = {i: colors.get(f"term{i}", "#888888") for i in range(16)}

    # ── Build the OpenCode theme ───────────────────────────
    # Using defs for reusable Material tokens
    defs = {
        "m3Primary": primary,
        "m3OnPrimary": on_primary,
        "m3PrimaryContainer": primary_container,
        "m3OnPrimaryContainer": on_primary_container,
        "m3Secondary": secondary,
        "m3SecondaryContainer": secondary_container,
        "m3Tertiary": tertiary,
        "m3TertiaryContainer": tertiary_container,
        "m3Surface": surface,
        "m3SurfaceDim": surface_dim,
        "m3SurfaceBright": surface_bright,
        "m3SurfaceContainer": surface_container,
        "m3SurfaceContainerLow": surface_container_low,
        "m3SurfaceContainerHigh": surface_container_high,
        "m3SurfaceContainerHighest": surface_container_highest,
        "m3OnSurface": on_surface,
        "m3OnSurfaceVariant": on_surface_variant,
        "m3Outline": outline,
        "m3OutlineVariant": outline_variant,
        "m3Error": error,
        "m3ErrorContainer": error_container,
        "m3Success": success,
        "m3SuccessContainer": success_container,
        "m3Shadow": shadow,
        # Terminal ANSI
        "ansiRed": term[1],
        "ansiGreen": term[2],
        "ansiYellow": term[3],
        "ansiBlue": term[4],
        "ansiMagenta": term[5],
        "ansiCyan": term[6],
        "ansiBrightRed": term[9],
        "ansiBrightGreen": term[10],
        "ansiBrightYellow": term[11],
        "ansiBrightBlue": term[12],
        "ansiBrightMagenta": term[13],
        "ansiBrightCyan": term[14],
    }

    # Diff background colors — subtle tints
    diff_added_bg = blend(surface_container, success, 0.15)
    diff_removed_bg = blend(surface_container, error, 0.15)
    diff_added_line_bg = blend(surface_container, success, 0.1)
    diff_removed_line_bg = blend(surface_container, error, 0.1)

    # Warning color — blend tertiary towards yellow
    warning = colors.get("term3", term[3])  # ANSI yellow is harmonized

    theme = {
        # ── Core UI ─────────────────────────────────
        "primary": "m3Primary",
        "secondary": "m3Secondary",
        "accent": "m3Tertiary",
        # ── Semantic ────────────────────────────────
        "error": "m3Error",
        "warning": warning,
        "success": "m3Success",
        "info": "m3Primary",
        # ── Text ────────────────────────────────────
        "text": "m3OnSurface",
        "textMuted": "m3OnSurfaceVariant",
        # ── Backgrounds ─────────────────────────────
        "background": "m3Surface",
        "backgroundPanel": "m3SurfaceContainer",
        "backgroundElement": "m3SurfaceContainerHigh",
        # ── Borders ─────────────────────────────────
        "border": "m3OutlineVariant",
        "borderActive": "m3Primary",
        "borderSubtle": blend(outline_variant, surface, 0.3),
        # ── Diffs ───────────────────────────────────
        "diffAdded": "m3Success",
        "diffRemoved": "m3Error",
        "diffContext": "m3OnSurfaceVariant",
        "diffHunkHeader": "m3Outline",
        "diffHighlightAdded": "ansiBrightGreen",
        "diffHighlightRemoved": "ansiBrightRed",
        "diffAddedBg": diff_added_bg,
        "diffRemovedBg": diff_removed_bg,
        "diffContextBg": "m3SurfaceContainer",
        "diffLineNumber": "m3Outline",
        "diffAddedLineNumberBg": diff_added_line_bg,
        "diffRemovedLineNumberBg": diff_removed_line_bg,
        # ── Markdown ────────────────────────────────
        "markdownText": "m3OnSurface",
        "markdownHeading": "m3Primary",
        "markdownLink": "m3Tertiary",
        "markdownLinkText": "ansiCyan",
        "markdownCode": "ansiGreen",
        "markdownBlockQuote": "m3OnSurfaceVariant",
        "markdownEmph": "ansiYellow",
        "markdownStrong": "ansiBrightYellow",
        "markdownHorizontalRule": "m3OutlineVariant",
        "markdownListItem": "m3Primary",
        "markdownListEnumeration": "m3Secondary",
        "markdownImage": "ansiMagenta",
        "markdownImageText": "ansiBrightMagenta",
        "markdownCodeBlock": "m3OnSurface",
        # ── Syntax highlighting ─────────────────────
        "syntaxComment": "m3Outline",
        "syntaxKeyword": "ansiMagenta",
        "syntaxFunction": "ansiBlue",
        "syntaxVariable": "ansiCyan",
        "syntaxString": "ansiGreen",
        "syntaxNumber": "ansiBrightMagenta",
        "syntaxType": "ansiYellow",
        "syntaxOperator": "m3OnSurfaceVariant",
        "syntaxPunctuation": "m3OnSurfaceVariant",
    }

    return {
        "$schema": "https://opencode.ai/theme.json",
        "defs": defs,
        "theme": theme,
    }


def generate_opencode_config(scss_path: str, output_dir: str | None = None) -> str:
    """Main entry point. Parse SCSS, generate theme, write to disk."""
    colors = parse_scss_colors(scss_path)

    # Also read boolean values
    with open(scss_path, "r") as f:
        for line in f:
            match = re.match(r"\$(\w+):\s*(True|False);", line.strip())
            if match:
                colors[match.group(1)] = match.group(2)

    theme = generate_opencode_theme(colors)

    if output_dir is None:
        output_dir = os.path.expanduser("~/.config/opencode/themes")

    os.makedirs(output_dir, exist_ok=True)
    output_path = os.path.join(output_dir, "inir.json")

    with open(output_path, "w") as f:
        json.dump(theme, f, indent=2)

    return output_path


if __name__ == "__main__":
    if len(sys.argv) < 2:
        # Default path
        scss_path = os.path.expanduser(
            "~/.local/state/quickshell/user/generated/material_colors.scss"
        )
    else:
        scss_path = sys.argv[1]

    if not os.path.exists(scss_path):
        print(f"Error: {scss_path} not found", file=sys.stderr)
        sys.exit(1)

    output = generate_opencode_config(scss_path)
    print(f"[opencode] Theme generated: {output}")
