#!/usr/bin/env bash
# Umbriel in the theme's colours: borders, the overview, tab and title bars, its own panels. Written only for a person
# whose ~/.config/umbriel is iNiR's (it includes this file as optional); Umbriel reloads it by itself.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/module-runtime.sh"
COLOR_MODULE_ID="umbriel"

UMBRIEL_CONFIG="$XDG_CONFIG_HOME/umbriel/config.toml"
COLORS_FILE="$STATE_DIR/user/generated/colors.json"
OUT="$STATE_DIR/user/generated/umbriel-colors.toml"

grep -qs '^# iNiR — Umbriel configuration' "$UMBRIEL_CONFIG" || exit 0
[[ -f "$COLORS_FILE" ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

glass="$(config_json '.iris.appearance.glass.mode // "wallpaper"' wallpaper)"
family="$(config_json '.panelFamily // "ii"' ii)"

tmp="$(mktemp "$OUT.XXXXXX")"
jq -r --arg glass "$glass" --arg family "$family" '
  def c($k; $a): ((.[$k] // "#808080") | ascii_upcase) + $a;
  [
    "# Written by iNiR from the theme on every colour change; edits here are lost. Your own: config.d/90-user-extra.toml.",
    "",
    "[colors]",
    "background = \"\(c("surface_container"; "FF"))\"",
    "text_primary = \"\(c("on_surface"; "FF"))\"",
    "text_muted = \"\(c("on_surface_variant"; "FF"))\"",
    "accent_primary = \"\(c("primary"; "FF"))\"",
    "accent_secondary = \"\(c("tertiary"; "FF"))\"",
    "warning = \"\(c("tertiary"; "FF"))\"",
    "error = \"\(c("error"; "FF"))\"",
    "insert_hint = \"\(c("primary"; "55"))\"",
    "shadow = \"#00000070\"",
    "",
    "[colors.border]",
    "focused = \"\(c("primary"; "FF"))\"",
    "unfocused = \"\(c("outline_variant"; "FF"))\"",
    "outer = \"\(c("surface"; "FF"))\"",
    "",
    "[colors.overview]",
    "background_tint = \"\(c("surface"; "66"))\"",
    "workspace_background = \"\(c("surface_container_low"; "88"))\"",
    "badge = \"\(c("primary"; "FF"))\"",
    "",
    "[colors.tab_bar]",
    "background = \"\(c("surface_container"; "FF"))\"",
    "text = \"\(c("on_surface_variant"; "FF"))\"",
    "active = \"\(c("primary"; "FF"))\"",
    "active_text = \"\(c("on_primary"; "FF"))\"",
    "active_unfocused = \"\(c("surface_container_highest"; "FF"))\"",
    "active_unfocused_text = \"\(c("on_surface"; "FF"))\"",
    "urgent = \"\(c("error"; "FF"))\"",
    "urgent_text = \"\(c("on_error"; "FF"))\"",
    "",
    "[colors.title_bar]",
    "background = \"\(c("surface_container_high"; "FF"))\"",
    "background_unfocused = \"\(c("surface_container"; "FF"))\"",
    "text = \"\(c("on_surface"; "FF"))\"",
    "text_unfocused = \"\(c("on_surface_variant"; "FF"))\"",
    "close = \"\(c("error"; "FF"))\"",
    "close_glyph = \"\(c("on_error"; "FF"))\"",
    "close_glyph_hover = \"\(c("on_error"; "FF"))\"",
    "maximize = \"\(c("primary"; "FF"))\"",
    "maximize_glyph = \"\(c("on_primary"; "FF"))\"",
    "maximize_glyph_hover = \"\(c("on_primary"; "FF"))\"",
    "minimize = \"\(c("tertiary"; "FF"))\"",
    "minimize_glyph = \"\(c("on_tertiary"; "FF"))\"",
    "minimize_glyph_hover = \"\(c("on_tertiary"; "FF"))\""
  ]
  + (if $family == "iris" and $glass == "compositor" then [
    "",
    "# iRiS asked for compositor glass. Umbriel has no blur region: it blurs every pixel of a matched surface above",
    "# the alpha threshold. So only the surfaces that publish a region under Niri are matched (not Prism, whose",
    "# scrim covers the screen), and the threshold sits over the iRiS shadows (kept under 0.1) and under its glass (0.12+).",
    "[[layer_rule]]",
    "match.namespace = \"^quickshell:iris-(chassis|sidebar-|notifications|osd|osk|menu|edit|settings)\"",
    "blur = true",
    "blur_ignore_alpha = 0.1",
    "blur_optimized = false",
    "",
    "# The Umbriel blur dims and flattens what it blurs (0.9); the Niri one does neither. These are the Niri values",
    "# (3 passes of 3, saturation 1.5), so the glass reads the same on both.",
    "# Settings writes after this file: what a person picks there wins.",
    "[appearance.blur]",
    "passes = 3",
    "radius = 3",
    "brightness = 1.0",
    "contrast = 1.0",
    "saturation = 1.5"
  ] else [] end)
  | .[]' "$COLORS_FILE" > "$tmp"
if cmp -s "$tmp" "$OUT"; then rm -f "$tmp"; else mv -f "$tmp" "$OUT"; fi
