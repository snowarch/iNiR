#!/usr/bin/env bash
set -euo pipefail
# Steam theming module: deploys Material You CSS to Adwaita-for-Steam
# and restarts steamwebhelper for live reload.
#
# CSS source priority:
#   1. Pre-rendered by template engine → ~/.local/state/quickshell/user/generated/steam-colortheme.css
#   2. Generated on-the-fly from colors.json (fallback for existing installs)
#
# Called from: scripts/colors/applycolor.sh (color pipeline)

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/module-runtime.sh"
COLOR_MODULE_ID="steam"

XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

GENERATED_CSS="$STATE_DIR/user/generated/steam-colortheme.css"
COLORS_JSON="$STATE_DIR/user/generated/colors.json"
THEME_NAME="inir"

# AdwSteamGtk's extracted skin cache
ADWSTEAM_COLORTHEMES="$XDG_CACHE_HOME/AdwSteamInstaller/extracted/adwaita/colorthemes"

# All possible Steam installation paths (native + flatpak)
STEAM_DIRS=(
  "$HOME/.steam/steam"
  "$HOME/.local/share/Steam"
  "$HOME/.var/app/com.valvesoftware.Steam/.steam/steam"
)

# --- CSS fallback generation (when template engine hasn't rendered it) ---

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

generate_css_from_colors_json() {
  cat <<EOCSS
/**
 * iNiR Material You for Adwaita-for-Steam
 * Auto-generated from wallpaper colors. Do not edit.
 */
:root
{
	--adw-accent-bg-rgb: $(read_token primary) !important;
	--adw-accent-fg-rgb: $(read_token on_primary) !important;
	--adw-accent-rgb: $(read_token primary) !important;
	--adw-destructive-bg-rgb: $(read_token error) !important;
	--adw-destructive-fg-rgb: $(read_token on_error) !important;
	--adw-destructive-rgb: $(read_token error) !important;
	--adw-success-bg-rgb: $(read_token success) !important;
	--adw-success-fg-rgb: $(read_token on_success) !important;
	--adw-success-rgb: $(read_token success) !important;
	--adw-warning-bg-rgb: $(read_token tertiary) !important;
	--adw-warning-fg-rgb: $(read_token on_tertiary) !important;
	--adw-warning-fg-a: 0.8 !important;
	--adw-warning-rgb: $(read_token tertiary) !important;
	--adw-error-bg-rgb: $(read_token error) !important;
	--adw-error-fg-rgb: $(read_token on_error) !important;
	--adw-error-rgb: $(read_token error) !important;
	--adw-window-bg-rgb: $(read_token surface_container_low) !important;
	--adw-window-fg-rgb: $(read_token on_surface) !important;
	--adw-view-bg-rgb: $(read_token surface) !important;
	--adw-view-fg-rgb: $(read_token on_surface) !important;
	--adw-headerbar-bg-rgb: $(read_token surface_container) !important;
	--adw-headerbar-fg-rgb: $(read_token on_surface) !important;
	--adw-headerbar-border-rgb: $(read_token outline_variant) !important;
	--adw-headerbar-backdrop-rgb: $(read_token surface_container_low) !important;
	--adw-headerbar-shade-rgb: $(read_token shadow) !important;
	--adw-headerbar-shade-a: 0.36 !important;
	--adw-headerbar-darker-shade-rgb: $(read_token shadow) !important;
	--adw-headerbar-darker-shade-a: 0.9 !important;
	--adw-sidebar-bg-rgb: $(read_token surface_container) !important;
	--adw-sidebar-fg-rgb: $(read_token on_surface) !important;
	--adw-sidebar-backdrop-rgb: $(read_token surface_container_low) !important;
	--adw-sidebar-shade-rgb: $(read_token shadow) !important;
	--adw-sidebar-shade-a: 0.36 !important;
	--adw-secondary-sidebar-bg-rgb: $(read_token surface_container_low) !important;
	--adw-secondary-sidebar-fg-rgb: $(read_token on_surface_variant) !important;
	--adw-secondary-sidebar-backdrop-rgb: $(read_token surface) !important;
	--adw-secondary-sidebar-shade-rgb: $(read_token shadow) !important;
	--adw-secondary-sidebar-shade-a: 0.36 !important;
	--adw-card-bg-rgb: 255, 255, 255 !important;
	--adw-card-bg-a: 0.08 !important;
	--adw-card-fg-rgb: $(read_token on_surface) !important;
	--adw-card-shade-rgb: $(read_token shadow) !important;
	--adw-card-shade-a: 0.36 !important;
	--adw-dialog-bg-rgb: $(read_token surface_container_high) !important;
	--adw-dialog-fg-rgb: $(read_token on_surface) !important;
	--adw-popover-bg-rgb: $(read_token surface_container_high) !important;
	--adw-popover-fg-rgb: $(read_token on_surface) !important;
	--adw-popover-shade-rgb: $(read_token shadow) !important;
	--adw-popover-shade-a: 0.25 !important;
	--adw-thumbnail-bg-rgb: $(read_token surface_container_high) !important;
	--adw-thumbnail-fg-rgb: $(read_token on_surface) !important;
	--adw-shade-rgb: $(read_token shadow) !important;
	--adw-shade-a: 0.36 !important;
	--adw-user-offline-rgb: $(read_token outline) !important;
	--adw-user-online-rgb: $(read_token primary) !important;
	--adw-user-ingame-rgb: $(read_token success) !important;
}
EOCSS
}

# --- Steam skin management ---

resolve_adwsteam_cmd() {
  if command -v adwaita-steam-gtk &>/dev/null; then
    printf 'adwaita-steam-gtk'
    return 0
  fi
  if command -v flatpak &>/dev/null &&
     flatpak list --app 2>/dev/null | grep -q 'io.github.Foldex.AdwSteamGtk'; then
    printf 'flatpak run io.github.Foldex.AdwSteamGtk'
    return 0
  fi
  return 1
}

skin_installed() {
  local dir
  for dir in "${STEAM_DIRS[@]}"; do
    [[ -d "$dir/steamui/adwaita/colorthemes" ]] && return 0
  done
  return 1
}

bootstrap_skin() {
  local adwsteam_cmd
  if ! adwsteam_cmd="$(resolve_adwsteam_cmd)"; then
    log_module "adwaita-steam-gtk not found — install adwsteamgtk"
    return 1
  fi
  log_module "bootstrapping Adwaita-for-Steam skin (first-time setup)"
  # shellcheck disable=SC2086
  $adwsteam_cmd -i 2>/dev/null || {
    log_module "bootstrap failed — Steam may not be installed"
    return 1
  }
}

deploy_css() {
  local css_source="$1"
  local deployed=0

  # AdwSteamGtk's extracted cache (so future -i runs pick up our colors)
  if [[ -d "$ADWSTEAM_COLORTHEMES" ]]; then
    mkdir -p "$ADWSTEAM_COLORTHEMES/$THEME_NAME"
    cp "$css_source" "$ADWSTEAM_COLORTHEMES/$THEME_NAME/$THEME_NAME.css"
  fi

  # Also write to custom.css (applied on top of any color theme)
  mkdir -p "$XDG_CONFIG_HOME/AdwSteamGtk"
  cp "$css_source" "$XDG_CONFIG_HOME/AdwSteamGtk/custom.css"

  # Every Steam installation that has the skin
  local dir lcss
  for dir in "${STEAM_DIRS[@]}"; do
    [[ -d "$dir/steamui/adwaita" ]] || continue
    mkdir -p "$dir/steamui/adwaita/colorthemes/$THEME_NAME"
    cp "$css_source" "$dir/steamui/adwaita/colorthemes/$THEME_NAME/$THEME_NAME.css"

    # Also copy to custom/custom.css for immediate CSS override
    mkdir -p "$dir/steamui/adwaita/custom"
    cp "$css_source" "$dir/steamui/adwaita/custom/custom.css"

    # Ensure libraryroot.custom.css imports our colortheme
    lcss="$dir/steamui/libraryroot.custom.css"
    if [[ -f "$lcss" ]] && ! grep -q "colorthemes/$THEME_NAME/" "$lcss"; then
      sed -i "s|colorthemes/[^/]*/[^\"]*\.css|colorthemes/$THEME_NAME/$THEME_NAME.css|" "$lcss"
    fi

    deployed=$((deployed + 1))
  done

  log_module "deployed CSS to $deployed Steam installation(s)"
}

reload_steam() {
  if ! pgrep -x steamwebhelper &>/dev/null; then
    log_module "Steam not running — CSS will apply on next launch"
    return 0
  fi

  # Inject CSS via Chrome DevTools Protocol (instant, no flicker).
  # Steam runs steamwebhelper with --remote-debugging-port=8080 by default.
  local inject_script="$SCRIPT_DIR/steam-css-inject.py"
  local py
  py="$(venv_python)"
  if [[ -f "$inject_script" ]] && "$py" "$inject_script" "$1" 2>/dev/null; then
    log_module "injected CSS via CDP (live update)"
    return 0
  fi

  # CDP unavailable — CSS is already deployed to disk and will apply on next Steam restart.
  # Never kill steamwebhelper as fallback: the user perceives it as Steam closing/crashing.
  log_module "CDP unavailable — CSS deployed to disk, will apply on next Steam restart"
}

# --- Main ---

main() {
  local enabled
  enabled=$(config_bool '.appearance.wallpaperTheming.enableAdwSteam' false)
  [[ "$enabled" == 'true' ]] || exit 0

  if ! resolve_adwsteam_cmd &>/dev/null; then
    log_module "adwaita-steam-gtk not found — install adwsteamgtk to theme Steam"
    exit 0
  fi

  # Resolve CSS source: pre-rendered template or on-the-fly generation
  local css_file="$GENERATED_CSS"
  if [[ ! -f "$css_file" ]]; then
    # Template wasn't rendered (existing install without updated templates.json)
    if [[ ! -f "$COLORS_JSON" ]]; then
      log_module "no colors.json — skipping"
      exit 0
    fi
    command -v jq &>/dev/null || { log_module "jq not installed — skipping"; exit 0; }
    log_module "template CSS not found — generating from colors.json"
    css_file="$STATE_DIR/user/generated/steam-colortheme.css"
    generate_css_from_colors_json > "$css_file"
  fi

  # Bootstrap Adwaita-for-Steam skin on first run
  if ! skin_installed; then
    bootstrap_skin || exit 0
  fi

  deploy_css "$css_file"
  reload_steam "$css_file"
  log_module "done"
}

main "$@"
