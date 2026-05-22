#!/usr/bin/env bash
#
# apply-spicetify-theme.sh - Generate and apply Spicetify color scheme
# from iNiR Material colors using custom theme with live updates.
#
# Design:
# - Always regenerate theme files (color.ini, user.css bridge) from the
#   current matugen palette.
# - Sync the generated user.css directly into the live xpui install so the
#   running client and the next launch use the same colors.
# - If Spotify is running with an existing remote-debugging port, trigger a
#   Page.reload over DevTools. No watch mode, no restart, no spawn.
# - If the live install is not patched yet, fall back to `spicetify -n apply`
#   so disk state is updated without opening Spotify.
# - This script never starts/opens Spotify itself.
#
# Reads: app-palette.json first, then palette.json/colors.json fallback
# Writes: ~/.config/spicetify/Themes/Inir/color.ini
#         ~/.config/spicetify/Themes/Inir/user.css  (bridge block only)

set -euo pipefail

# ─── Configuration ─────────────────────────────────────────────────────────────

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$XDG_STATE_HOME/quickshell"
PALETTE_JSON="$STATE_DIR/user/generated/palette.json"
APP_PALETTE_JSON="$STATE_DIR/user/generated/app-palette.json"
COLORS_JSON="$STATE_DIR/user/generated/colors.json"
LOG_FILE="$STATE_DIR/user/generated/spicetify_theme.log"

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

get_spotify_xpui_dir() {
  python3 - "$1" <<'PY'
import configparser, pathlib, sys

config_path = pathlib.Path(sys.argv[1])
config = configparser.RawConfigParser()
config.read(config_path)
spotify_root = config.get("Setting", "spotify_path", fallback="").strip()

candidates = []
if spotify_root:
    root = pathlib.Path(spotify_root).expanduser()
    candidates.extend([root / "Apps" / "xpui", root / "xpui"])

for path in candidates:
    if (path / "index.html").is_file():
        print(path)
        break
PY
}

is_live_install_patched() {
  local xpui_dir="$1"
  local index_html="$xpui_dir/index.html"
  [[ -f "$index_html" ]] || return 1
  grep -q "helper/spicetifyWrapper.js" "$index_html" && grep -q "class='userCSS' href='user.css'" "$index_html"
}

get_debugger_port() {
  pgrep -af 'spotify.*remote-debugging-port=' 2>/dev/null | sed -n 's/.*--remote-debugging-port=\([0-9]\+\).*/\1/p' | head -n1 || true
}

reload_running_spotify() {
  local port="$1"
  python3 - "$port" <<'PY'
import base64
import json
import os
import socket
import struct
import sys
import urllib.parse
import urllib.request

port = int(sys.argv[1])

with urllib.request.urlopen(f"http://127.0.0.1:{port}/json/list", timeout=2) as response:
    targets = json.load(response)

page = next((target for target in targets if target.get("type") == "page" and "spotify.com" in target.get("url", "")), None)
if page is None:
    raise SystemExit(1)

ws_url = urllib.parse.urlparse(page["webSocketDebuggerUrl"])
sock = socket.create_connection((ws_url.hostname, ws_url.port), timeout=2)

key = base64.b64encode(os.urandom(16)).decode()
request = (
    f"GET {ws_url.path} HTTP/1.1\r\n"
    f"Host: {ws_url.hostname}:{ws_url.port}\r\n"
    "Upgrade: websocket\r\n"
    "Connection: Upgrade\r\n"
    f"Sec-WebSocket-Key: {key}\r\n"
    "Sec-WebSocket-Version: 13\r\n"
    "\r\n"
)
sock.sendall(request.encode())
response = sock.recv(4096)
if b" 101 " not in response:
    raise SystemExit(1)

payload = json.dumps({"id": 1, "method": "Page.reload", "params": {"ignoreCache": True}}).encode()
mask = os.urandom(4)
header = bytearray([0x81])
length = len(payload)
if length < 126:
    header.append(0x80 | length)
elif length < 65536:
    header.extend((0x80 | 126, *struct.pack("!H", length)))
else:
    header.extend((0x80 | 127, *struct.pack("!Q", length)))

masked = bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
sock.sendall(bytes(header) + mask + masked)
sock.close()
PY
}

is_process_running() {
  pgrep -x "$1" >/dev/null 2>&1
}

# ─── Color extraction ───────────────────────────────────────────────────────────

read_colors() {
  local color_source="$APP_PALETTE_JSON"
  [[ -f "$color_source" ]] || color_source="$PALETTE_JSON"
  [[ -f "$color_source" ]] || color_source="$COLORS_JSON"

  if [[ ! -f "$color_source" ]]; then
    log "palette/colors JSON not found at $APP_PALETTE_JSON, $PALETTE_JSON, or $COLORS_JSON"
    return 1
  fi

  if ! command -v jq &>/dev/null; then
    log "jq not available"
    return 1
  fi

  COLORS[primary]=$(jq -r '.app_accent // .primary // "#8caaee"' "$color_source")
  COLORS[on_primary]=$(jq -r '.app_on_accent // .on_primary // "#1e3a5f"' "$color_source")
  COLORS[on_primary_container]=$(jq -r '.app_on_selection // .on_primary_container // "#dce0e8"' "$color_source")
  COLORS[on_surface]=$(jq -r '.app_foreground // .on_surface // "#dce0e8"' "$color_source")
  COLORS[on_surface_variant]=$(jq -r '.app_subtext // .on_surface_variant // "#a6adc8"' "$color_source")
  COLORS[surface]=$(jq -r '.app_background // .surface // "#1e1e2e"' "$color_source")
  COLORS[surface_variant]=$(jq -r '.app_surface_elevated // .surface_variant // "#45475a"' "$color_source")
  COLORS[surface_container_low]=$(jq -r '.app_sidebar_bg // .app_surface // .surface_container_low // "#181825"' "$color_source")
  COLORS[surface_container]=$(jq -r '.app_surface // .surface_container // "#313244"' "$color_source")
  COLORS[surface_container_high]=$(jq -r '.app_card_bg // .app_surface_elevated // .surface_container_high // "#45475a"' "$color_source")
  COLORS[surface_container_highest]=$(jq -r '.app_surface_popup // .app_thumbnail_bg // .surface_container_highest // "#494d64"' "$color_source")
  COLORS[primary_container]=$(jq -r '.app_selection // .primary_container // "#313244"' "$color_source")
  COLORS[secondary]=$(jq -r '.secondary // "#89b4fa"' "$color_source")
  COLORS[secondary_container]=$(jq -r '.app_selection_hover // .secondary_container // "#3d4c6b"' "$color_source")
  COLORS[tertiary]=$(jq -r '.tertiary // "#94e2d5"' "$color_source")
  COLORS[outline]=$(jq -r '.app_border // .outline // "#585b70"' "$color_source")
  COLORS[outline_variant]=$(jq -r '.app_border_subtle // .outline_variant // "#45475a"' "$color_source")
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
  --spice-text:                #$(strip_hash "${COLORS[on_surface]}");
  --spice-subtext:             #$(strip_hash "${COLORS[on_surface_variant]}");
  --spice-main:                #$(strip_hash "${COLORS[surface]}");
  --spice-sidebar:             #$(strip_hash "${COLORS[surface_container_low]}");
  --spice-player:              #$(strip_hash "${COLORS[surface_container]}");
  --spice-card:                #$(strip_hash "${COLORS[surface_container_high]}");
  --spice-shadow:              #$(strip_hash "${COLORS[shadow]}");
  --spice-selected-row:        #$(strip_hash "${COLORS[on_surface_variant]}");
  --spice-button:              #$(strip_hash "${COLORS[primary]}");
  --spice-button-active:       #$(strip_hash "${COLORS[secondary_container]}");
  --spice-button-disabled:     #$(strip_hash "${COLORS[outline_variant]}");
  --spice-tab-active:          #$(strip_hash "${COLORS[surface_container_highest]}");
  --spice-notification:        #$(strip_hash "${COLORS[tertiary]}");
  --spice-notification-error:  #$(strip_hash "${COLORS[error]}");
  --spice-misc:                #$(strip_hash "${COLORS[outline]}");

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
  --spice-rgb-text:            $(hex_to_rgb "${COLORS[on_surface]}");
  --spice-rgb-subtext:         $(hex_to_rgb "${COLORS[on_surface_variant]}");
  --spice-rgb-main:            $(hex_to_rgb "${COLORS[surface]}");
  --spice-rgb-sidebar:         $(hex_to_rgb "${COLORS[surface_container_low]}");
  --spice-rgb-player:          $(hex_to_rgb "${COLORS[surface_container]}");
  --spice-rgb-card:            $(hex_to_rgb "${COLORS[surface_container_high]}");
  --spice-rgb-shadow:          $(hex_to_rgb "${COLORS[shadow]}");
  --spice-rgb-selected-row:    $(hex_to_rgb "${COLORS[on_surface_variant]}");
  --spice-rgb-button:          $(hex_to_rgb "${COLORS[primary]}");
  --spice-rgb-button-active:   $(hex_to_rgb "${COLORS[secondary_container]}");
  --spice-rgb-button-disabled: $(hex_to_rgb "${COLORS[outline_variant]}");
  --spice-rgb-tab-active:      $(hex_to_rgb "${COLORS[surface_container_highest]}");
  --spice-rgb-notification:    $(hex_to_rgb "${COLORS[tertiary]}");
  --spice-rgb-notification-error: $(hex_to_rgb "${COLORS[error]}");
  --spice-rgb-misc:            $(hex_to_rgb "${COLORS[outline]}");
  --spice-rgb-main-secondary:  $(hex_to_rgb "$main_secondary");
}
/* === end iNiR CSS variable bridge === */"

  # ── Replace only the bridge block in user.css (keep everything else) ──────
  # Use python3 for reliable multi-line regex replace without temp file races.
  # The regex removes ALL occurrences (handles stale duplicate blocks from
  # previous buggy runs) and appends a single fresh block at the end so these
  # vars win over any later Sleek defaults/redefinitions.
  python3 - "$css_file" "$bridge_block" <<'PYEOF'
import sys, re, pathlib
css_path = pathlib.Path(sys.argv[1])
new_block = sys.argv[2]
content = css_path.read_text()
pattern = re.compile(
    r'/\* === iNiR CSS variable bridge - auto-generated, do not edit === \*/.*?/\* === end iNiR CSS variable bridge === \*/\n?',
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

regenerate_playback_controls_fix() {
  local css_file="$1"

  [[ -f "$css_file" ]] || return 0

  local playback_rgb
  playback_rgb="$(hex_to_rgb "${COLORS[on_surface_variant]}")"

  local playback_block
  playback_block="/* === iNiR playback controls fix - auto-generated === */
.main-playbackBar__slider,
.playback-bar__progress-time-elapsed,
.main-playbackBar__slider::before {
  --spice-rgb-selected-row: $playback_rgb;
}

.control-button,
.main-connectToDevice-button {
  color: var(--spice-subtext) !important;
}

.control-button:hover,
.main-connectToDevice-button:hover {
  color: var(--spice-text) !important;
}

.progress-bar {
  --spice-rgb-selected-row: $playback_rgb;
}

.progress-bar__bg {
  background-color: rgba($playback_rgb, 0.3) !important;
}
/* === end iNiR playback controls fix === */"

  python3 - "$css_file" "$playback_block" <<'PYEOF'
import sys, re, pathlib
css_path = pathlib.Path(sys.argv[1])
new_block = sys.argv[2]
content = css_path.read_text()
pattern = re.compile(
    r'/\* === iNiR playback controls fix - auto-generated === \*/.*?(?=(/\* === end iNiR playback controls fix === \*/|/\* === iNiR playback controls fix - auto-generated === \*/|\Z))',
    re.DOTALL
)
content = pattern.sub('', content)
content = re.sub(r'/\* === end iNiR playback controls fix === \*/\n?', '', content)
content = content.lstrip('\n')
content = new_block + '\n' + content
css_path.write_text(content)
PYEOF

  log "Playback controls fix regenerated from current palette"
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

CDP_PORT=8976

ensure_spotify_desktop_override() {
  # Create a .desktop override that launches Spotify with CDP enabled for live reload.
  local user_apps="$HOME/.local/share/applications"
  local override="$user_apps/spotify.desktop"
  local system_desktop="/usr/share/applications/spotify.desktop"

  # Already has the port? Skip.
  if [[ -f "$override" ]] && grep -q "remote-debugging-port=$CDP_PORT" "$override" 2>/dev/null; then
    return 0
  fi

  [[ -f "$system_desktop" ]] || return 0
  mkdir -p "$user_apps" 2>/dev/null || return 0

  sed "s|^Exec=spotify|Exec=spotify --remote-debugging-port=$CDP_PORT|" \
    "$system_desktop" > "$override"
  # TryExec must remain just the binary name
  sed -i 's|^TryExec=.*|TryExec=spotify|' "$override"
  log "Created Spotify desktop override with CDP port $CDP_PORT"
}

configure_spicetify() {
  local theme_dir="$1"
  local color_file="$theme_dir/color.ini"
  local user_css="$theme_dir/user.css"

  mkdir -p "$theme_dir" 2>/dev/null || return 1

  # Read the palette first so COLORS array is populated for both steps
  read_colors || return 1

  download_sleek_css "$user_css"
  patch_existing_user_css "$user_css"
  # Write user.css bridge FIRST so the live xpui sync always ships the full
  # variable set in a single file copy.
  regenerate_user_css_bridge "$user_css"
  regenerate_playback_controls_fix "$user_css"
  generate_color_ini "$color_file" || return 1

  spicetify config inject_css 1 replace_colors 1 >> "$LOG_FILE" 2>&1 || true
  spicetify config current_theme "$THEME_NAME" color_scheme "$SCHEME_NAME" >> "$LOG_FILE" 2>&1 || true
}

apply_spicetify_theme() {
  local apply_out
  if apply_out=$(spicetify -n apply 2>&1); then
    printf "%s\n" "$apply_out" >> "$LOG_FILE" 2>&1
    return 0
  fi

  printf "%s\n" "$apply_out" >> "$LOG_FILE" 2>&1

  if printf "%s" "$apply_out" | grep -Eqi "backup|cannot find backup"; then
    log "Running spicetify -n backup apply..."
    local backup_out
    if backup_out=$(spicetify -n backup apply 2>&1); then
      printf "%s\n" "$backup_out" >> "$LOG_FILE" 2>&1
      return 0
    fi
    printf "%s\n" "$backup_out" >> "$LOG_FILE" 2>&1
    return 1
  fi

  return 1
}
sync_live_user_css() {
  local user_css="$1"
  local xpui_dir="$2"
  local live_user_css="$xpui_dir/user.css"
  [[ -d "$xpui_dir" ]] || return 1
  cp "$user_css" "$live_user_css"
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
  local xpui_dir
  xpui_dir="$(get_spotify_xpui_dir "$spicetify_config")"

  configure_spicetify "$theme_dir" || {
    log "Failed to configure spicetify"
    exit 1
  }

  # Ensure Spotify launches with CDP for live reload on next start
  ensure_spotify_desktop_override

  local spotify_running=false
  is_process_running "spotify" && spotify_running=true

  if [[ -n "$xpui_dir" ]] && is_live_install_patched "$xpui_dir"; then
    if sync_live_user_css "$theme_dir/user.css" "$xpui_dir"; then
      log "Synced live Spotify user.css"
      if $spotify_running; then
        local debugger_port
        debugger_port="$(get_debugger_port)"
        if [[ -n "$debugger_port" ]] && reload_running_spotify "$debugger_port"; then
          log "Spotify live theme reloaded without restart"
          exit 0
        fi
        log "Live user.css synced; debugger reload unavailable"
        exit 0
      fi
      log "Spotify not running - live user.css synced for next launch"
      exit 0
    fi
  fi

  if ! apply_spicetify_theme; then
    log "spicetify -n apply failed; theme files written but install was not patched"
    exit 1
  fi

  # Some spicetify versions launch Spotify as a side effect despite -n.
  # Kill it if it wasn't running before we called apply.
  if ! $spotify_running && is_process_running "spotify"; then
    pkill -x spotify 2>/dev/null || true
    log "Killed Spotify spawned as side effect of spicetify apply"
  fi

  if ! $spotify_running; then
    log "Spotify not running - theme applied to bundle for next launch"
    exit 0
  fi

  if [[ -n "$xpui_dir" ]] && is_live_install_patched "$xpui_dir"; then
    sync_live_user_css "$theme_dir/user.css" "$xpui_dir" || true
    local debugger_port
    debugger_port="$(get_debugger_port)"
    if [[ -n "$debugger_port" ]] && reload_running_spotify "$debugger_port"; then
      log "Spotify live theme reloaded after no-restart apply"
      exit 0
    fi
  fi

  log "Spotify running - disk theme updated without restart"

  exit 0
}

main "$@"
