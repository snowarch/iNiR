#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/module-runtime.sh"
COLOR_MODULE_ID="steam"

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

GENERATED_MILLENNIUM_CSS="$STATE_DIR/user/generated/steam-millennium-material.css"
MILLENNIUM_TEMPLATE="$SCRIPT_DIR/../../defaults/matugen/templates/steam/millennium-material.css"
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
  local mode
  if [[ -f "$STATE_DIR/user/generated/theme-meta.json" ]] && command -v jq >/dev/null 2>&1; then
    mode="$(jq -r '.mode // "dark"' "$STATE_DIR/user/generated/theme-meta.json" 2>/dev/null || printf dark)"
  else
    mode="dark"
  fi
  if [[ "$mode" == "light" ]]; then
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
        data = json.load(f)
except Exception:
    data = {}

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

os.makedirs(os.path.dirname(path), exist_ok=True)
with open(tmp, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
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

  if [[ ! -f "$css_file" ||
        ( -f "$COLORS_JSON" && "$COLORS_JSON" -nt "$css_file" ) ||
        ( -f "$MILLENNIUM_TEMPLATE" && "$MILLENNIUM_TEMPLATE" -nt "$css_file" ) ]]; then
    generate_millennium_css_from_colors_json > "$css_file"
  fi

  for theme_dir in "${theme_dirs[@]}"; do
    [[ -n "$theme_dir" ]] || continue
    mkdir -p "$theme_dir/css/main/colors"
    cp "$css_file" "$theme_dir/css/main/colors/matugen.css"
    deployed=$((deployed + 1))
  done

  while IFS= read -r loopback_dir; do
    [[ -n "$loopback_dir" ]] || continue
    mkdir -p "$loopback_dir/css/main/colors"
    cp "$css_file" "$loopback_dir/css/main/colors/matugen.css"
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
  enabled=$(config_bool '.appearance.wallpaperTheming.enableSteam' false)

  [[ "$enabled" == 'true' || "${INIR_STEAM_THEME_FORCE:-0}" == "1" ]] || exit 0

  if ! millennium_runtime_available; then
    log_module "Millennium is required for Steam theming — install millennium-bin"
    exit 0
  fi

  deploy_millennium_material || exit 0
  log_module "done"
}

main "$@"
