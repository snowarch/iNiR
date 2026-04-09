#!/usr/bin/env bash
#
# apply-spicetify-theme.sh - Generate and apply Spicetify color scheme
# from iNiR Material colors using custom theme with live updates.
#
# Design:
# - If Spotify is not running: only regenerate theme files (never start/open Spotify)
# - If Spotify is running and watch mode is active: just update files, watch reloads live
# - If Spotify is running without watch mode: refresh once, then start watch mode
#
# Reads: palette.json first, then colors.json fallback
# Writes: ~/.config/spicetify/Themes/Inir/color.ini
#         ~/.config/spicetify/Themes/Inir/user.css  (bridge block only)

set -euo pipefail

# ─── Configuration ─────────────────────────────────────────────────────────────

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$XDG_STATE_HOME/quickshell"
PALETTE_JSON="$STATE_DIR/user/generated/palette.json"
COLORS_JSON="$STATE_DIR/user/generated/colors.json"
LOG_FILE="$STATE_DIR/user/generated/spicetify_theme.log"
WATCH_LOCK="$STATE_DIR/user/generated/spicetify_watch.lock"

THEME_NAME="Inir"
SCHEME_NAME="matugen"
SLEEK_CSS_URL="https://raw.githubusercontent.com/spicetify/spicetify-themes/master/Sleek/user.css"

# Global associative array for colors
declare -A COLORS

# ─── Setup directories and logging ─────────────────────────────────────────────

mkdir -p "$STATE_DIR/user/generated" 2>/dev/null || true

if ! touch "$LOG_FILE" 2>/dev/null; then
  LOG_FILE="/tmp/spicetify_theme_$$.log"
  touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/dev/null"
fi

log() {
  local timestamp
  timestamp=$(date '+%H:%M:%S')
  printf "[%s] [spicetify] %s\n" "$timestamp" "$*" >> "$LOG_FILE"
}

# ─── Helper functions ───────────────────────────────────────────────────────────

strip_hash() {
  local color="${1#\#}"
  echo "${color,,}"
}

# Convert a #rrggbb hex color to "r,g,b" decimal string for CSS rgba() calls
hex_to_rgb() {
  local hex="${1#\#}"
  hex="${hex,,}"
  local r g b
  r=$((16#${hex:0:2}))
  g=$((16#${hex:2:2}))
  b=$((16#${hex:4:2}))
  echo "$r,$g,$b"
}

get_spicetify_config_path() {
  local config_path="${SPICETIFY_CONFIG_PATH:-$XDG_CONFIG_HOME/spicetify/config-xpui.ini}"
  local cmd_config
  if cmd_config=$(spicetify -c 2>/dev/null) && [[ -n "$cmd_config" ]]; then
    config_path="$cmd_config"
  fi
  echo "$config_path"
}

is_process_running() {
  pgrep -x "$1" >/dev/null 2>&1
}

is_watch_active() {
  # First check if the process is genuinely running
  if pgrep -f "spicetify watch" >/dev/null 2>&1; then
    return 0
  fi
  # Process is not running — clean up any stale lock file
  if [[ -f "$WATCH_LOCK" ]]; then
    log "Stale watch lock detected (watch not running) — removing lock"
    release_watch_lock
  fi
  return 1
}

acquire_watch_lock() {
  echo $$ > "$WATCH_LOCK"
}

release_watch_lock() {
  rm -f "$WATCH_LOCK" 2>/dev/null || true
}

# ─── Color extraction ───────────────────────────────────────────────────────────

read_colors() {
  local color_source="$PALETTE_JSON"
  [[ -f "$color_source" ]] || color_source="$COLORS_JSON"

  if [[ ! -f "$color_source" ]]; then
    log "palette/colors JSON not found at $PALETTE_JSON or $COLORS_JSON"
    return 1
  fi

  if ! command -v jq &>/dev/null; then
    log "jq not available"
    return 1
  fi

  COLORS[primary]=$(jq -r '.primary // "#8caaee"' "$color_source")
  COLORS[on_primary]=$(jq -r '.on_primary // "#1e3a5f"' "$color_source")
  COLORS[on_primary_container]=$(jq -r '.on_primary_container // "#dce0e8"' "$color_source")
  COLORS[on_surface]=$(jq -r '.on_surface // "#dce0e8"' "$color_source")
  COLORS[on_surface_variant]=$(jq -r '.on_surface_variant // "#a6adc8"' "$color_source")
  COLORS[surface]=$(jq -r '.surface // "#1e1e2e"' "$color_source")
  COLORS[surface_variant]=$(jq -r '.surface_variant // "#45475a"' "$color_source")
  COLORS[surface_container_low]=$(jq -r '.surface_container_low // "#181825"' "$color_source")
  COLORS[surface_container]=$(jq -r '.surface_container // "#313244"' "$color_source")
  COLORS[surface_container_high]=$(jq -r '.surface_container_high // "#45475a"' "$color_source")
  COLORS[surface_container_highest]=$(jq -r '.surface_container_highest // "#494d64"' "$color_source")
  COLORS[primary_container]=$(jq -r '.primary_container // "#313244"' "$color_source")
  COLORS[secondary]=$(jq -r '.secondary // "#89b4fa"' "$color_source")
  COLORS[secondary_container]=$(jq -r '.secondary_container // "#3d4c6b"' "$color_source")
  COLORS[tertiary]=$(jq -r '.tertiary // "#94e2d5"' "$color_source")
  COLORS[outline]=$(jq -r '.outline // "#585b70"' "$color_source")
  COLORS[outline_variant]=$(jq -r '.outline_variant // "#45475a"' "$color_source")
  COLORS[error]=$(jq -r '.error // "#f38ba8"' "$color_source")
  COLORS[shadow]=$(jq -r '.shadow // "#000000"' "$color_source")
}

# ─── Theme generation ───────────────────────────────────────────────────────────

generate_color_ini() {
  local color_file="$1"
  
  # COLORS array is now populated by configure_spicetify before this is called

  cat > "$color_file" << EOF
[${SCHEME_NAME}]
text               = $(strip_hash "${COLORS[on_surface]}")
subtext            = $(strip_hash "${COLORS[on_surface_variant]}")
main               = $(strip_hash "${COLORS[surface]}")
sidebar            = $(strip_hash "${COLORS[surface_container_low]}")
player             = $(strip_hash "${COLORS[surface_container]}")
card               = $(strip_hash "${COLORS[surface_container_high]}")
shadow             = $(strip_hash "${COLORS[shadow]}")
selected-row       = $(strip_hash "${COLORS[on_surface_variant]}")
button             = $(strip_hash "${COLORS[primary]}")
button-active      = $(strip_hash "${COLORS[secondary_container]}")
button-disabled    = $(strip_hash "${COLORS[outline_variant]}")
tab-active         = $(strip_hash "${COLORS[surface_container_highest]}")
notification       = $(strip_hash "${COLORS[tertiary]}")
notification-error = $(strip_hash "${COLORS[error]}")
misc               = $(strip_hash "${COLORS[outline]}")
EOF
}

regenerate_user_css_bridge() {
  local css_file="$1"

  # user.css must already exist (downloaded by download_sleek_css)
  [[ -f "$css_file" ]] || return 0

  # ── Derive bridge values from matugen palette ─────────────────────────────
  # main-secondary / highlight: elevated surface layers for clear hierarchy
  local main_secondary="${COLORS[surface_container]}"
  local main_elevated="${COLORS[surface_container_high]}"
  local highlight="${COLORS[surface_container_high]}"
  local highlight_elevated="${COLORS[surface_container_highest]}"
  # nav-active uses an explicit container+on-container pair for readability
  local nav_active="${COLORS[primary_container]}"
  local nav_active_text="${COLORS[on_primary_container]}"
  local playback_bar="${COLORS[on_surface_variant]}"
  local play_button="${COLORS[primary]}"
  local play_button_active="${COLORS[secondary_container]}"
  local button_secondary="${COLORS[on_surface_variant]}"
  local spice_hover="rgba($(hex_to_rgb "${COLORS[primary]}"), 0.10)"
  local spice_active="rgba($(hex_to_rgb "${COLORS[primary]}"), 0.18)"
  local spice_border="${COLORS[outline_variant]}"

  # ── Build the bridge block ────────────────────────────────────────────────
  local bridge_block
  bridge_block="/* === iNiR CSS variable bridge - auto-generated, do not edit === */
:root {
  /* Aliases for variables used by Sleek CSS but not in color.ini */
  --spice-main-secondary:      #$(strip_hash "$main_secondary");
  --spice-main-elevated:       #$(strip_hash "$main_elevated");
  --spice-highlight:           #$(strip_hash "$highlight");
  --spice-highlight-elevated:  #$(strip_hash "$highlight_elevated");
  --spice-nav-active:          #$(strip_hash "$nav_active");
  --spice-nav-active-text:     #$(strip_hash "$nav_active_text");
  --spice-playback-bar:        #$(strip_hash "$playback_bar");
  --spice-play-button:         #$(strip_hash "$play_button");
  --spice-play-button-active:  #$(strip_hash "$play_button_active");
  --spice-button-secondary:    #$(strip_hash "$button_secondary");
  --spice-hover:               ${spice_hover};
  --spice-active:              ${spice_active};
  --spice-border:              #$(strip_hash "$spice_border");

  /* RGB variants used for rgba() calls */
  --spice-rgb-main:            $(hex_to_rgb "${COLORS[surface]}");
  --spice-rgb-main-secondary:  $(hex_to_rgb "$main_secondary");
  --spice-rgb-sidebar:         $(hex_to_rgb "${COLORS[surface_container_low]}");
  --spice-rgb-selected-row:    $(hex_to_rgb "${COLORS[on_surface_variant]}");
  --spice-rgb-button:          $(hex_to_rgb "${COLORS[primary]}");
  --spice-rgb-shadow:          $(hex_to_rgb "${COLORS[shadow]}");
  --spice-rgb-misc:            $(hex_to_rgb "${COLORS[outline]}");
}
/* === end iNiR CSS variable bridge ==="

  # ── Replace only the bridge block in user.css (keep everything else) ──────
  # Use python3 for reliable multi-line regex replace without temp file races.
  # The regex removes ALL occurrences (handles stale duplicate blocks from
  # previous buggy runs) and appends a single fresh block at the end so these
  # vars win over any later Sleek defaults/redefinitions.
  python3 - "$css_file" "$bridge_block" <<'PYEOF'
import sys, re, pathlib
css_path = pathlib.Path(sys.argv[1])
new_block = sys.argv[2] + ' */'
content = css_path.read_text()
pattern = re.compile(
    r'/\* === iNiR CSS variable bridge.*?end iNiR CSS variable bridge === \*/',
    re.DOTALL
)
# Strip ALL existing bridge blocks (including duplicates from prior bad runs)
content = pattern.sub('', content).lstrip('\n')
# Append the single fresh block so it has final cascade priority
if content and not content.endswith('\n'):
    content += '\n'
content = content + '\n' + new_block + '\n'
css_path.write_text(content)
PYEOF

  log "CSS variable bridge regenerated from current palette"
}

patch_existing_user_css() {
  local css_file="$1"

  [[ -f "$css_file" ]] || return 0

  sed -i 's/rgba(var(--spice-rgb-selected-row),.7)/var(--spice-subtext)/g' "$css_file"
}
download_sleek_css() {
  local css_file="$1"
  if [[ ! -f "$css_file" ]]; then
    log "Downloading base CSS from Sleek theme..."
    if curl -L --create-dirs -o "$css_file" "$SLEEK_CSS_URL" 2>/dev/null; then
      log "Downloaded base CSS"
      # Fix hard-to-read right-side playback controls (queue, connect, volume).
      # Sleek bases these on selected-row (which is a dark background in Matugen).
      # Change it to use the subtext color instead so they are visible.
      sed -i 's/rgba(var(--spice-rgb-selected-row),.7)/var(--spice-subtext)/g' "$css_file"
    else
      log "Warning: Failed to download base CSS"
    fi
  fi
}

# ─── Spicetify operations ──────────────────────────────────────────────────────

configure_spicetify() {
  local theme_dir="$1"
  local color_file="$theme_dir/color.ini"
  local user_css="$theme_dir/user.css"

  mkdir -p "$theme_dir" 2>/dev/null || return 1
  
  # Read the palette first so COLORS array is populated for both steps
  read_colors || return 1
  
  download_sleek_css "$user_css"
  patch_existing_user_css "$user_css"
  # Write user.css bridge FIRST so that when color.ini lands (last) and
  # triggers spicetify watch's file-change debounce, user.css is already
  # fully updated. Reversed order caused watch to reload Spotify from
  # color.ini before user.css was written — leaving bridge vars stale.
  regenerate_user_css_bridge "$user_css"
  generate_color_ini "$color_file" || return 1

  spicetify config inject_css 1 replace_colors 1 >> "$LOG_FILE" 2>&1 || true
  spicetify config current_theme "$THEME_NAME" color_scheme "$SCHEME_NAME" >> "$LOG_FILE" 2>&1 || true
}

apply_spicetify_theme() {
  local apply_out
  if apply_out=$(spicetify apply 2>&1); then
    printf "%s\n" "$apply_out" >> "$LOG_FILE" 2>&1
    return 0
  fi

  printf "%s\n" "$apply_out" >> "$LOG_FILE" 2>&1

  if printf "%s" "$apply_out" | grep -Eqi "backup|cannot find backup"; then
    log "Running spicetify backup apply..."
    local backup_out
    if backup_out=$(spicetify backup apply 2>&1); then
      printf "%s\n" "$backup_out" >> "$LOG_FILE" 2>&1
      return 0
    fi
    printf "%s\n" "$backup_out" >> "$LOG_FILE" 2>&1
    return 1
  fi

  return 1
}

start_watch_mode() {
  log "Starting spicetify watch mode..."
  nohup spicetify watch -s >> "$LOG_FILE" 2>&1 &
  local watch_pid=$!
  sleep 0.5

  if kill -0 "$watch_pid" 2>/dev/null; then
    acquire_watch_lock
    log "Watch mode started (PID: $watch_pid)"
    return 0
  else
    log "Failed to start watch mode"
    release_watch_lock
    return 1
  fi
}

# ─── Main logic ────────────────────────────────────────────────────────────────

main() {
  if ! command -v spicetify &>/dev/null; then
    log "spicetify not installed, skipping"
    exit 0
  fi

  local spicetify_config
  spicetify_config=$(get_spicetify_config_path)
  local spicetify_root
  spicetify_root="$(dirname "$spicetify_config")"
  local theme_dir="$spicetify_root/Themes/$THEME_NAME"

  configure_spicetify "$theme_dir" || {
    log "Failed to configure spicetify"
    exit 1
  }

  local spotify_running=false
  local watch_running=false

  is_process_running "spotify" && spotify_running=true
  is_watch_active && watch_running=true

  if $watch_running; then
    log "Watch mode active - colors updated (live reload)"
    exit 0
  fi

  if ! $spotify_running; then
    # Important UX rule: color generation must never open Spotify by itself.
    # Keep this path write-only (color.ini + user.css bridge already updated)
    # and return without apply/watch operations.
    log "Spotify not running - updated theme files only (no auto-open)"
    exit 0
  else
    log "Spotify running without watch - starting watch mode (no restart)"
    # If watch wasn't running, the file changes we just wrote won't be picked up.
    # We must explicitly refresh the running instance, then start watch for future changes.
    spicetify refresh -s >> "$LOG_FILE" 2>&1 || true
    start_watch_mode || {
      log "Watch start failed, colors will apply on next Spotify launch"
    }
  fi

  exit 0
}

main "$@"
