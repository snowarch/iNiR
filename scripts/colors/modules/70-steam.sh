#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/module-runtime.sh"
COLOR_MODULE_ID="steam"

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

GENERATED_MILLENNIUM_CSS="$STATE_DIR/user/generated/steam-millennium-material.css"
COLORS_JSON="$STATE_DIR/user/generated/app-palette.json"
[[ -f "$COLORS_JSON" ]] || COLORS_JSON="$STATE_DIR/user/generated/palette.json"
[[ -f "$COLORS_JSON" ]] || COLORS_JSON="$STATE_DIR/user/generated/colors.json"
MILLENNIUM_THEME_DIR_NAME="Material-Theme"
MILLENNIUM_THEME_CONDITION_NAME="Material-Theme"
MILLENNIUM_CONFIG="$XDG_CONFIG_HOME/millennium/config.json"
MILLENNIUM_MATERIAL_REPO="https://github.com/kuska1/Material-Theme.git"

STEAM_DIRS=(
  "$HOME/.steam/steam"
  "$HOME/.local/share/Steam"
  "$HOME/.var/app/com.valvesoftware.Steam/.steam/steam"
)

hex_to_rgb() {
  local hex="${1#\#}"
  printf '%d, %d, %d' "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
}

read_token() {
  local token="$1" fallback="${2:-0, 0, 0}" hex
  hex=$(jq -r ".${token} // empty" "$COLORS_JSON" 2>/dev/null) || true
  if [[ -n "$hex" ]]; then
    hex_to_rgb "$hex"
  else
    printf '%s' "$fallback"
  fi
}

generate_millennium_css_from_colors_json() {
  cat <<EOCSS
:root {
    --theme-color: "Matugen";
    --hue-rotate: 220deg;

    --md-sys-color-primary: rgb($(read_token app_accent "$(read_token primary)"));
    --md-sys-color-on-primary: rgb($(read_token app_on_accent "$(read_token on_primary)"));
    --md-sys-color-primary-container: rgb($(read_token app_accent_container "$(read_token primary_container)"));
    --md-sys-color-on-primary-container: rgb($(read_token on_primary_container));
    --md-sys-color-primary-fixed: rgb($(read_token primary_fixed "$(read_token primary_container)"));
    --md-sys-color-primary-fixed-dim: rgb($(read_token primary_fixed_dim "$(read_token primary)"));
    --md-sys-color-on-primary-fixed: rgb($(read_token on_primary_fixed "$(read_token on_primary_container)"));
    --md-sys-color-on-primary-fixed-variant: rgb($(read_token on_primary_fixed_variant "$(read_token on_primary_container)"));
    --md-sys-color-secondary: rgb($(read_token secondary));
    --md-sys-color-on-secondary: rgb($(read_token on_secondary));
    --md-sys-color-secondary-container: rgb($(read_token secondary_container));
    --md-sys-color-on-secondary-container: rgb($(read_token on_secondary_container));
    --md-sys-color-secondary-fixed: rgb($(read_token secondary_fixed "$(read_token secondary_container)"));
    --md-sys-color-secondary-fixed-dim: rgb($(read_token secondary_fixed_dim "$(read_token secondary)"));
    --md-sys-color-on-secondary-fixed: rgb($(read_token on_secondary_fixed "$(read_token on_secondary_container)"));
    --md-sys-color-on-secondary-fixed-variant: rgb($(read_token on_secondary_fixed_variant "$(read_token on_secondary_container)"));
    --md-sys-color-tertiary: rgb($(read_token tertiary));
    --md-sys-color-on-tertiary: rgb($(read_token on_tertiary));
    --md-sys-color-tertiary-container: rgb($(read_token tertiary_container));
    --md-sys-color-on-tertiary-container: rgb($(read_token on_tertiary_container));
    --md-sys-color-tertiary-fixed: rgb($(read_token tertiary_fixed "$(read_token tertiary_container)"));
    --md-sys-color-tertiary-fixed-dim: rgb($(read_token tertiary_fixed_dim "$(read_token tertiary)"));
    --md-sys-color-on-tertiary-fixed: rgb($(read_token on_tertiary_fixed "$(read_token on_tertiary_container)"));
    --md-sys-color-on-tertiary-fixed-variant: rgb($(read_token on_tertiary_fixed_variant "$(read_token on_tertiary_container)"));
    --md-sys-color-error: rgb($(read_token error));
    --md-sys-color-on-error: rgb($(read_token on_error));
    --md-sys-color-error-container: rgb($(read_token error_container));
    --md-sys-color-on-error-container: rgb($(read_token on_error_container));
    --md-sys-color-background: rgb($(read_token app_background "$(read_token background)"));
    --md-sys-color-on-background: rgb($(read_token app_foreground "$(read_token on_background)"));
    --md-sys-color-surface: rgb($(read_token app_background "$(read_token surface)"));
    --md-sys-color-on-surface: rgb($(read_token app_foreground "$(read_token on_surface)"));
    --md-sys-color-surface-variant: rgb($(read_token app_surface_elevated "$(read_token surface_variant)"));
    --md-sys-color-on-surface-variant: rgb($(read_token app_subtext "$(read_token on_surface_variant)"));
    --md-sys-color-surface-dim: rgb($(read_token app_background "$(read_token surface_dim)"));
    --md-sys-color-surface-bright: rgb($(read_token app_surface_popup "$(read_token surface_bright)"));
    --md-sys-color-surface-container-lowest: rgb($(read_token app_background "$(read_token surface_container_lowest)"));
    --md-sys-color-surface-container-low: rgb($(read_token app_surface "$(read_token surface_container_low)"));
    --md-sys-color-surface-container: rgb($(read_token app_surface "$(read_token surface_container)"));
    --md-sys-color-surface-container-high: rgb($(read_token app_surface_elevated "$(read_token surface_container_high)"));
    --md-sys-color-surface-container-highest: rgb($(read_token app_surface_popup "$(read_token surface_container_highest)"));
    --md-sys-color-outline: rgb($(read_token app_border "$(read_token outline)"));
    --md-sys-color-outline-variant: rgb($(read_token app_border_subtle "$(read_token outline_variant)"));
    --md-sys-color-inverse-surface: rgb($(read_token inverse_surface "$(read_token app_foreground)"));
    --md-sys-color-inverse-on-surface: rgb($(read_token inverse_on_surface "$(read_token app_background)"));
    --md-sys-color-inverse-primary: rgb($(read_token inverse_primary "$(read_token app_accent)"));
    --md-sys-color-shadow: rgb($(read_token shadow));
    --md-sys-color-scrim: rgb($(read_token scrim "$(read_token shadow)"));
    --md-sys-color-surface-tint: rgb($(read_token app_accent "$(read_token primary)"));
    --md-sys-color-source-color: rgb($(read_token source_color "$(read_token app_accent "$(read_token primary)")"));
}
EOCSS
  steam_refinements_css
}

# iNiR's finish on Material-Theme. It rides in this file because Material-Theme re-reads it every 1.5 s in
# every Steam window, so it follows the palette live without touching Millennium's options or reloading Steam.
# Selectors are Material-Theme's own (css/main/restyle/recolor.css), doubled to outrank them.
steam_refinements_css() {
  local font
  font="$(shell_font_family)"
  cat <<'EOCSS'

/* iNiR: a selection is the accent's container, as in every themed app; the accent itself is kept for actions */
._3pSPluBgf0NeR1kkCLWMhR._3pSPluBgf0NeR1kkCLWMhR.eNLOx4LVceeMwRvTVWh3 {
    background-color: var(--md-sys-color-primary-container) !important;
}
._3pSPluBgf0NeR1kkCLWMhR._3pSPluBgf0NeR1kkCLWMhR.eNLOx4LVceeMwRvTVWh3:hover {
    background-color: color-mix(in srgb, var(--md-sys-color-primary-container), var(--md-sys-color-on-primary-container) 8%) !important;
}
.eNLOx4LVceeMwRvTVWh3.eNLOx4LVceeMwRvTVWh3 ._3O48LaKWcabKx07xdrt1TH,
._3pSPluBgf0NeR1kkCLWMhR.eNLOx4LVceeMwRvTVWh3:hover ._3O48LaKWcabKx07xdrt1TH {
    color: var(--md-sys-color-on-primary-container) !important;
}
._3pSPluBgf0NeR1kkCLWMhR._3pSPluBgf0NeR1kkCLWMhR:not(.eNLOx4LVceeMwRvTVWh3):hover ._3O48LaKWcabKx07xdrt1TH {
    color: var(--md-sys-color-on-surface) !important;
}

/* Dropdowns read as fields, not buttons */
body .DialogDropDown.DialogDropDown, ._3few7361SOf4k_YuKCmM62 .DialogDropDown.DialogDropDown,
._2J170P0ckFcUIlsDU13MLS ._DialogInputContainer._DialogInputContainer,
._3_7wzN0kdchWheVyim6nmo .DialogDropDown.DialogDropDown, ._1UeO0R_NRSTMbWLI02pecg .DialogDropDown.DialogDropDown {
    color: var(--md-sys-color-on-surface) !important;
    background: var(--md-sys-color-surface-container-highest) !important;
}
body .DialogDropDown.DialogDropDown:hover, ._3few7361SOf4k_YuKCmM62 .DialogDropDown.DialogDropDown:hover,
._2J170P0ckFcUIlsDU13MLS ._DialogInputContainer._DialogInputContainer:hover,
._3_7wzN0kdchWheVyim6nmo .DialogDropDown.DialogDropDown:hover, ._1UeO0R_NRSTMbWLI02pecg .DialogDropDown.DialogDropDown:hover {
    color: var(--md-sys-color-on-surface) !important;
    background: color-mix(in srgb, var(--md-sys-color-surface-container-highest), var(--md-sys-color-on-surface) 8%) !important;
}
body .DialogDropDown_CurrentDisplay.DialogDropDown_CurrentDisplay { color: var(--md-sys-color-on-surface) !important; }
body .DialogDropDown_Arrow .SVGIcon_DownArrowContextMenu.SVGIcon_DownArrowContextMenu,
._2J170P0ckFcUIlsDU13MLS ._DialogInputContainer .DialogDropDown_Arrow svg {
    color: var(--md-sys-color-on-surface-variant) !important;
    fill: var(--md-sys-color-on-surface-variant) !important;
}

/* The library's type picker (Games, Software, ...) */
._1ZS_xta5HMXzR8JgxDH6n7._1ZS_xta5HMXzR8JgxDH6n7 ._2PF_m-I5yte3WnQhpcz8RC {
    background: var(--md-sys-color-surface-container-highest) !important;
}
._1ZS_xta5HMXzR8JgxDH6n7._1ZS_xta5HMXzR8JgxDH6n7 ._2PF_m-I5yte3WnQhpcz8RC:hover {
    background: color-mix(in srgb, var(--md-sys-color-surface-container-highest), var(--md-sys-color-on-surface) 8%) !important;
}
._1ZS_xta5HMXzR8JgxDH6n7._1ZS_xta5HMXzR8JgxDH6n7 ._2PF_m-I5yte3WnQhpcz8RC,
._1ZS_xta5HMXzR8JgxDH6n7._1ZS_xta5HMXzR8JgxDH6n7 ._2PF_m-I5yte3WnQhpcz8RC * {
    color: var(--md-sys-color-on-surface) !important;
}
._1ZS_xta5HMXzR8JgxDH6n7._1ZS_xta5HMXzR8JgxDH6n7 ._2PF_m-I5yte3WnQhpcz8RC svg,
._1ZS_xta5HMXzR8JgxDH6n7._1ZS_xta5HMXzR8JgxDH6n7 ._2PF_m-I5yte3WnQhpcz8RC svg polygon {
    color: var(--md-sys-color-on-surface-variant) !important;
    fill: var(--md-sys-color-on-surface-variant) !important;
}

/* Library section headers are labels, not bars */
._2sYIghGVXJr6tsQVvcryy8._2sYIghGVXJr6tsQVvcryy8 {
    background: transparent !important;
    color: var(--md-sys-color-on-surface-variant) !important;
}
._2sYIghGVXJr6tsQVvcryy8._2sYIghGVXJr6tsQVvcryy8:hover,
._2sYIghGVXJr6tsQVvcryy8._2sYIghGVXJr6tsQVvcryy8._1dcGFHhye9BeEOg7CkFNQG,
._2sYIghGVXJr6tsQVvcryy8._2sYIghGVXJr6tsQVvcryy8.sXMOsx8OIRalBMxO9yFY5 {
    background: color-mix(in srgb, transparent, var(--md-sys-color-on-surface) 6%) !important;
}
._2sYIghGVXJr6tsQVvcryy8._2sYIghGVXJr6tsQVvcryy8 ._3cV3O8FnPQqpJO5kIMUlLX { color: var(--md-sys-color-on-surface-variant) !important; }

/* A game without art is a tile of the palette, not Steam's olive placeholder with grey-gradient text */
._1R9r2OBCxAmtuUVrgBEUBw:has(._13fGPw2BaM5wWIahr2xNKt) { background: var(--md-sys-color-surface-container-high) !important; }
._1R9r2OBCxAmtuUVrgBEUBw:has(._13fGPw2BaM5wWIahr2xNKt) img { opacity: 0 !important; }
._13fGPw2BaM5wWIahr2xNKt._13fGPw2BaM5wWIahr2xNKt {
    background-image: none !important;
    -webkit-text-fill-color: var(--md-sys-color-on-surface-variant) !important;
    color: var(--md-sys-color-on-surface-variant) !important;
}

/* Shelf headers are labels, not rules */
._2W0O30CG0Q1UtW0Oq2-p6N._2W0O30CG0Q1UtW0Oq2-p6N { background: transparent !important; }

/* Menus are windows of their own with no alpha: a rounded plate showed black in its corners. The window is the
   plate, square and in the menu's colour; the items keep their rounded fill inside it. */
html.MillenniumWindow_ContextMenu, body.ContextMenuPopupBody.ContextMenuPopupBody {
    background: var(--md-sys-color-surface-container) !important;
    box-shadow: none !important;
}
body.ContextMenuPopupBody .PP7LM0Ow1K5qkR8WElLpt.PP7LM0Ow1K5qkR8WElLpt,
body.ContextMenuPopupBody ._2yAm5LY_eu-Vg_52l0HFlM._2yAm5LY_eu-Vg_52l0HFlM {
    border-radius: 0 !important;
    box-shadow: none !important;
}
body.ContextMenuPopupBody ._1n7Wloe5jZ6fSuvV18NNWI.contextMenuItem.contextMenuItem { border-radius: 8px !important; }

/* What's New titles clamp at two lines but clip at their padding, where the top of a third line showed */
.DVBcpUzJ0x6kaRMfug0OJ.DVBcpUzJ0x6kaRMfug0OJ { overflow: clip !important; overflow-clip-margin: content-box !important; }
EOCSS
  if [[ -n "$font" ]]; then
    cat <<EOCSS

/* The shell's interface font */
:root *:not(.SVGIcon_Button):not([class*="Icon"]):not(code):not(pre) {
    font-family: "${font}", "Open Sans", sans-serif !important;
}
EOCSS
  fi
}

millennium_runtime_available() {
  [[ -d /usr/lib/millennium ]] && return 0
  if command -v pacman >/dev/null 2>&1; then
    pacman -Q millennium-bin >/dev/null 2>&1 && return 0
    pacman -Q millennium >/dev/null 2>&1 && return 0
    pacman -Q millennium-git >/dev/null 2>&1 && return 0
  fi
  return 1
}

resolve_steam_root_for_theme() {
  local dir
  for dir in "${STEAM_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
      printf '%s\n' "$dir"
      return 0
    fi
  done
  printf '%s\n' "${STEAM_DIRS[0]}"
}

resolve_millennium_material_theme_dir() {
  local dir theme_dir resolved
  local seen=""
  for dir in "${STEAM_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    theme_dir="$dir/millennium/themes/$MILLENNIUM_THEME_DIR_NAME"
    [[ -f "$theme_dir/skin.json" ]] || continue
    resolved="$(readlink -f "$theme_dir" 2>/dev/null || printf '%s' "$theme_dir")"
    if [[ ":$seen:" == *":$resolved:"* ]]; then
      continue
    fi
    printf '%s\n' "$resolved"
    seen="${seen:+$seen:}$resolved"
  done
}

install_millennium_material_theme() {
  local existing theme_root target tmp
  existing="$(resolve_millennium_material_theme_dir | head -n 1 || true)"
  [[ -n "$existing" ]] && return 0

  command -v git >/dev/null 2>&1 || { log_module "git not installed — cannot install Millennium Material-Theme"; return 1; }
  theme_root="$(resolve_steam_root_for_theme)/millennium/themes"
  target="$theme_root/$MILLENNIUM_THEME_DIR_NAME"
  mkdir -p "$theme_root"

  if [[ -e "$target" && ! -f "$target/skin.json" ]]; then
    log_module "Millennium Material-Theme path exists but has no skin.json: $target"
    return 1
  fi

  tmp="$theme_root/.${MILLENNIUM_THEME_DIR_NAME}.tmp.$$"
  rm -rf "$tmp"
  if git clone --depth=1 "$MILLENNIUM_MATERIAL_REPO" "$tmp" >/dev/null 2>&1; then
    mv "$tmp" "$target"
    log_module "installed Millennium Material-Theme"
    return 0
  fi
  rm -rf "$tmp"
  log_module "failed to install Millennium Material-Theme"
  return 1
}

resolve_millennium_material_loopback_skin_dir() {
  local dir skin_dir resolved
  local seen=""
  for dir in "${STEAM_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    skin_dir="$dir/steamui/skins/$MILLENNIUM_THEME_DIR_NAME"
    resolved="$(readlink -m "$skin_dir" 2>/dev/null || printf '%s' "$skin_dir")"
    if [[ ":$seen:" == *":$resolved:"* ]]; then
      continue
    fi
    printf '%s\n' "$resolved"
    seen="${seen:+$seen:}$resolved"
  done
}

millennium_material_appearance() {
  if [[ "$(theme_mode)" == "light" ]]; then
    printf Light
  else
    printf Dark
  fi
}

millennium_material_matugen_selected() {
  [[ -f "$MILLENNIUM_CONFIG" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  [[ "$(jq -r '.themes.activeTheme // empty' "$MILLENNIUM_CONFIG" 2>/dev/null)" == "$MILLENNIUM_THEME_DIR_NAME" ]] || return 1
  [[ "$(jq -r --arg theme "$MILLENNIUM_THEME_CONDITION_NAME" '.themes.conditions[$theme].Color // empty' "$MILLENNIUM_CONFIG" 2>/dev/null)" == "Matugen" ]]
}

set_millennium_material_matugen() {
  local py tmp appearance
  py="$(venv_python)"
  tmp="${MILLENNIUM_CONFIG}.tmp"
  appearance="$(millennium_material_appearance)"
  mkdir -p "$(dirname "$MILLENNIUM_CONFIG")"
  "$py" - "$MILLENNIUM_CONFIG" "$tmp" "$MILLENNIUM_THEME_DIR_NAME" "$MILLENNIUM_THEME_CONDITION_NAME" "$appearance" <<'PYCFG'
import json
import os
import sys

path, tmp, active_theme, condition_theme, appearance = sys.argv[1:6]
try:
    with open(path) as f:
        before = f.read()
    data = json.loads(before)
except Exception:
    before, data = None, {}

general = data.setdefault("general", {})
general["injectCSS"] = True
general["injectJavascript"] = True

themes = data.setdefault("themes", {})
themes["activeTheme"] = active_theme
themes["allowedStyles"] = True
themes["allowedScripts"] = True
conditions = themes.setdefault("conditions", {})
theme_conditions = conditions.setdefault(condition_theme, {})
theme_conditions["Color"] = "Matugen"
theme_conditions["Appearance"] = appearance

after = json.dumps(data, indent=2) + "\n"
# Millennium owns this file too and reacts to writes: touch it only when a value changed.
if before is not None and json.loads(before) == data:
    sys.exit(0)
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(tmp, "w") as f:
    f.write(after)
os.replace(tmp, path)
PYCFG
}

deploy_millennium_material() {
  local theme_dir loopback_dir css_file deployed=0 loopback_deployed=0 already_matugen=0
  local -a theme_dirs=()

  install_millennium_material_theme || return 1
  mapfile -t theme_dirs < <(resolve_millennium_material_theme_dir)
  [[ "${#theme_dirs[@]}" -gt 0 ]] || return 1
  millennium_material_matugen_selected && already_matugen=1
  set_millennium_material_matugen

  css_file="$GENERATED_MILLENNIUM_CSS"
  if [[ ! -f "$COLORS_JSON" ]]; then
    log_module "configured Millennium Material-Theme Matugen; no generated palette yet"
    return 0
  fi
  command -v jq &>/dev/null || { log_module "jq not installed — cannot generate Steam Matugen CSS"; return 1; }

  generate_millennium_css_from_colors_json | write_if_changed "$css_file" || true

  for theme_dir in "${theme_dirs[@]}"; do
    [[ -n "$theme_dir" ]] || continue
    mkdir -p "$theme_dir/css/main/colors"
    # Millennium refreshes on every write: an identical copy would restyle a running Steam for nothing.
    cmp -s "$css_file" "$theme_dir/css/main/colors/matugen.css" || cp "$css_file" "$theme_dir/css/main/colors/matugen.css"
    deployed=$((deployed + 1))
  done

  while IFS= read -r loopback_dir; do
    [[ -n "$loopback_dir" ]] || continue
    mkdir -p "$loopback_dir/css/main/colors"
    cmp -s "$css_file" "$loopback_dir/css/main/colors/matugen.css" || cp "$css_file" "$loopback_dir/css/main/colors/matugen.css"
    loopback_deployed=$((loopback_deployed + 1))
  done < <(resolve_millennium_material_loopback_skin_dir)

  log_module "deployed Millennium Material-Theme Matugen CSS to $deployed theme installation(s) and $loopback_deployed Steam loopback path(s)"
  if ! pgrep -x steamwebhelper &>/dev/null; then
    log_module "Steam not running — Millennium theme will apply on next launch"
  elif [[ "$already_matugen" == "1" ]]; then
    log_module "Matugen CSS deployed — active Millennium Material-Theme sessions refresh automatically"
  else
    log_module "configured Millennium Material-Theme Matugen — reload or restart Steam once to activate Matugen live refresh"
  fi
}

main() {
  local enabled
  enabled=$(config_bool '.appearance.wallpaperTheming.enableSteam' true)

  [[ "$enabled" == 'true' || "${INIR_STEAM_THEME_FORCE:-0}" == "1" ]] || exit 0

  if ! millennium_runtime_available; then
    log_module "Millennium is required for Steam theming — install millennium-bin"
    exit 0
  fi

  deploy_millennium_material || exit 0
  log_module "done"
}

main "$@"
