#!/usr/bin/env bash
#
# apply-spicetify-theme.sh - Generate and apply a Spicetify color scheme
# from iNiR Material colors.
#
# Reads:  ~/.local/state/quickshell/user/generated/colors.json
# Writes: ~/.config/spicetify/Themes/ii-material/color.ini
#

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$XDG_STATE_HOME/quickshell"
COLORS_JSON="$STATE_DIR/user/generated/colors.json"
LOG_FILE="$STATE_DIR/user/generated/spicetify_theme.log"

THEME_NAME="ii-material"
SCHEME_NAME="iNiR"

mkdir -p "$STATE_DIR/user/generated" 2>/dev/null || true
if ! touch "$LOG_FILE" 2>/dev/null; then
  LOG_FILE="/tmp/ii_spicetify_theme.log"
  touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/dev/null"
fi

log() {
  [[ -n "$LOG_FILE" ]] || return 0
  printf "[spicetify] %s\n" "$*" | tee -a "$LOG_FILE" >/dev/null 2>&1 || true
}

strip_hash() {
  local color="$1"
  color="${color#\#}"
  echo "${color,,}"
}

if ! command -v spicetify &>/dev/null; then
  log "spicetify not installed. Skipping."
  exit 0
fi

if [[ ! -f "$COLORS_JSON" ]] || ! command -v jq &>/dev/null; then
  log "colors.json missing or jq unavailable. Skipping."
  exit 0
fi

primary=$(jq -r '.primary // "#8caaee"' "$COLORS_JSON")
on_surface=$(jq -r '.on_surface // "#dce0e8"' "$COLORS_JSON")
on_surface_variant=$(jq -r '.on_surface_variant // "#a6adc8"' "$COLORS_JSON")
surface=$(jq -r '.surface // "#1e1e2e"' "$COLORS_JSON")
surface_container_low=$(jq -r '.surface_container_low // "#181825"' "$COLORS_JSON")
surface_container=$(jq -r '.surface_container // "#313244"' "$COLORS_JSON")
surface_container_high=$(jq -r '.surface_container_high // "#45475a"' "$COLORS_JSON")
primary_container=$(jq -r '.primary_container // "#313244"' "$COLORS_JSON")
secondary=$(jq -r '.secondary // "#89b4fa"' "$COLORS_JSON")
tertiary=$(jq -r '.tertiary // "#94e2d5"' "$COLORS_JSON")
outline=$(jq -r '.outline // "#585b70"' "$COLORS_JSON")
outline_variant=$(jq -r '.outline_variant // "#45475a"' "$COLORS_JSON")
error=$(jq -r '.error // "#f38ba8"' "$COLORS_JSON")
shadow=$(jq -r '.shadow // "#000000"' "$COLORS_JSON")

spicetify_config="${SPICETIFY_CONFIG_PATH:-$XDG_CONFIG_HOME/spicetify/config-xpui.ini}"
if cmd_config=$(spicetify -c 2>/dev/null); then
  [[ -n "$cmd_config" ]] && spicetify_config="$cmd_config"
fi
spicetify_root="$(dirname "$spicetify_config")"
theme_dir="$spicetify_root/Themes/$THEME_NAME"
color_file="$theme_dir/color.ini"

if ! mkdir -p "$theme_dir" 2>/dev/null; then
  log "Cannot create theme directory: $theme_dir"
  exit 1
fi

if ! cat > "$color_file" <<EOF
[${SCHEME_NAME}]
text               = $(strip_hash "$on_surface")
subtext            = $(strip_hash "$on_surface_variant")
main               = $(strip_hash "$surface")
sidebar            = $(strip_hash "$surface_container_low")
player             = $(strip_hash "$surface_container")
card               = $(strip_hash "$surface_container_high")
shadow             = $(strip_hash "$shadow")
selected-row       = $(strip_hash "$primary_container")
button             = $(strip_hash "$primary")
button-active      = $(strip_hash "$secondary")
button-disabled    = $(strip_hash "$outline")
tab-active         = $(strip_hash "$primary_container")
notification       = $(strip_hash "$tertiary")
notification-error = $(strip_hash "$error")
misc               = $(strip_hash "$outline_variant")
EOF
then
  log "Cannot write color scheme file: $color_file"
  exit 1
fi

if ! spicetify config current_theme "$THEME_NAME" color_scheme "$SCHEME_NAME" >> "$LOG_FILE" 2>&1; then
  log "Failed to update Spicetify config."
  exit 1
fi

if spicetify apply >> "$LOG_FILE" 2>&1; then
  log "Applied theme '$THEME_NAME' (scheme '$SCHEME_NAME')."
else
  log "spicetify apply failed. Check Spicetify setup and backups."
  exit 1
fi
