#!/usr/bin/env bash
#
# apply-chrome-theme.sh — Apply GM3 BrowserThemeColor to Chromium-based browsers
#
# Usage:
#   apply-chrome-theme.sh                  # auto-detect color from material pipeline
#   apply-chrome-theme.sh "#ff6b35"        # explicit hex color
#
# Supports: Google Chrome, Chromium, Brave
# Requires: jq, writable policy dir (one-time sudo/pkexec setup)
#
# One-time setup per browser:
#   sudo mkdir -p /etc/chromium/policies/managed && sudo chmod a+rw /etc/chromium/policies/managed
#   sudo mkdir -p /etc/opt/chrome/policies/managed && sudo chmod a+rw /etc/opt/chrome/policies/managed
#   sudo mkdir -p /etc/brave/policies/managed && sudo chmod a+rw /etc/brave/policies/managed

XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$XDG_STATE_HOME/quickshell"
CHROMIUM_THEME_FILE="$STATE_DIR/user/generated/chromium.theme"
LOG_FILE="$STATE_DIR/user/generated/chrome_theme.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/config-path.sh
source "$SCRIPT_DIR/../lib/config-path.sh"
mkdir -p "$STATE_DIR/user/generated" 2>/dev/null
: > "$LOG_FILE" 2>/dev/null

log() { echo "[chrome] $*" >> "$LOG_FILE"; }

notify_user() {
  command -v notify-send >/dev/null 2>&1 || return 0
  notify-send "Chrome Theme" "$1" -a "Chrome Theme"
}

# ── Helpers ──────────────────────────────────────────────────────────────────

hex_to_rgb() {
  local hex=$1
  hex="${hex#\#}"
  printf "%d,%d,%d" "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
}

rgb_to_hex() {
  local rgb="$1"
  local r g b
  IFS=',' read -r r g b <<< "$rgb"
  [[ "$r" =~ ^[0-9]+$ && "$g" =~ ^[0-9]+$ && "$b" =~ ^[0-9]+$ ]] || return 1
  (( r >= 0 && r <= 255 && g >= 0 && g <= 255 && b >= 0 && b <= 255 )) || return 1
  printf '#%02X%02X%02X\n' "$r" "$g" "$b"
}

is_omarchy() {
  local bin_path
  bin_path=$(command -v "$1" 2>/dev/null)
  if [[ -n "$bin_path" ]]; then
    if command -v pacman &>/dev/null; then
      pacman -Qo "$bin_path" 2>/dev/null | grep -qi "omarchy" && return 0
    fi
  fi
  return 1
}

elevate() {
  # 1. Interactive terminal — use sudo directly (user sees password prompt)
  if [[ -t 0 ]] && [[ -t 1 ]]; then
    sudo "$@"
    return $?
  fi

  # 2. Non-interactive but cached sudo credentials available
  if sudo -n true 2>/dev/null; then
    sudo "$@"
    return $?
  fi

  # 3. Graphical session with polkit — try pkexec, but warn if no agent
  if command -v pkexec >/dev/null 2>&1 && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    # Check for a running polkit agent; without one pkexec hangs or fails silently
    if pgrep -xf 'polkit-.+-authentication-agent' >/dev/null 2>&1 \
       || pgrep -xf 'polkitd' >/dev/null 2>&1 \
       || pgrep -xf 'gnome-shell' >/dev/null 2>&1 \
       || pgrep -xf 'kwin_wayland' >/dev/null 2>&1; then
      pkexec "$@"
      return $?
    else
      log "elevate: pkexec available but no polkit agent detected — skipping elevation"
      return 1
    fi
  fi

  log "elevate: no elevation method available (need sudo/pkexec with agent)"
  return 1
}

policy_fix_commands() {
  local policy_dir="$1"
  printf 'sudo mkdir -p %s\nsudo chmod a+rw %s' "$policy_dir" "$policy_dir"
}

ensure_policy_dir_writable() {
  local policy_dir="$1"
  local name="$2"

  if [[ -d "$policy_dir" && -w "$policy_dir" ]]; then
    return 0
  fi

  log "$name: requesting writable policy dir: $policy_dir"
  if elevate mkdir -p "$policy_dir" && elevate chmod a+rw "$policy_dir"; then
    log "$name: policy dir ready: $policy_dir"
    notify_user "$name can now write browser policy files."
    return 0
  fi

  local instructions
  instructions=$(policy_fix_commands "$policy_dir")
  log "$name: ERROR — failed to prepare $policy_dir"
  log "$name: run manually:
$instructions"
  notify_user "$name needs writable policy files.\n$instructions"
  return 1
}

# ── Resolve theme color ─────────────────────────────────────────────────────

resolve_color() {
  # 1. Explicit argument
  if [[ -n "$1" && "$1" =~ ^#[A-Fa-f0-9]{6}$ ]]; then
    echo "$1"
    return
  fi

  # 2. Generated browser theme contract
  if [[ -f "$CHROMIUM_THEME_FILE" ]]; then
    local rgb_color
    rgb_color=$(tr -d '[:space:]' < "$CHROMIUM_THEME_FILE")
    if [[ "$rgb_color" =~ ^[0-9]{1,3},[0-9]{1,3},[0-9]{1,3}$ ]]; then
      local hex_color
      hex_color=$(rgb_to_hex "$rgb_color" 2>/dev/null || true)
      if [[ -n "$hex_color" ]]; then
        echo "$hex_color"
        return
      fi
    fi
  fi

  # 3. Raw seed color from image
  local seed_file="$STATE_DIR/user/generated/color.txt"
  if [[ -f "$seed_file" ]]; then
    local c
    c=$(cat "$seed_file" | tr -d '\n')
    if [[ -n "$c" && "$c" =~ ^#[A-Fa-f0-9]{6}$ ]]; then
      echo "$c"
      return
    fi
  fi

  # 4. explicit palette contract, then colors.json fallback
  local colors_json="$STATE_DIR/user/generated/palette.json"
  [[ -f "$colors_json" ]] || colors_json="$STATE_DIR/user/generated/colors.json"
  if [[ -f "$colors_json" ]] && command -v jq &>/dev/null; then
    local c
    c=$(jq -r '.surface_container_low // .surface // .background // .primary // empty' "$colors_json" 2>/dev/null)
    if [[ -n "$c" ]]; then
      echo "$c"
      return
    fi
  fi
}

# ── Resolve dark/light mode ─────────────────────────────────────────────────
# Returns Chrome's color_scheme2 value:
#   In Chrome internals: 0 = system, 1 = light, 2 = dark
# But since Niri does not have a reliable XDG portal for standard Chrome,
# we map them directly. However, we'll invert them if needed to match what actually works.

resolve_color_scheme() {
  local meta_file="$STATE_DIR/user/generated/theme-meta.json"
  if [[ -f "$meta_file" ]] && command -v jq &>/dev/null; then
    local mode
    mode=$(jq -r '.mode // empty' "$meta_file" 2>/dev/null)
    if [[ "$mode" == "dark" || "$mode" == "light" ]]; then
      echo "$mode"
      return
    fi
  fi

  local scss_file="$STATE_DIR/user/generated/material_colors.scss"
  if [[ -f "$scss_file" ]]; then
    local val
    val=$(grep '^\$darkmode:' "$scss_file" | sed 's/.*: *\(.*\);/\1/' | tr -d ' ')
    if [[ "$val" == "True" || "$val" == "true" ]]; then
      # If Dark mode is currently returning light, we swap to 1.
      # If it's standard, it's 2. But we need to use 2 for dark in CLI and 2 for light in Prefs?
      # Let's pass 'dark' or 'light' string, and translate internally per method.
      echo "dark"
      return
    fi
  fi
  echo "light"
}

# ── Browser registry ─────────────────────────────────────────────────────────
# Each entry: bin_name|policy_dir|prefs_dir

BROWSERS=()

_register() {
  local bin="$1" policy_dir="$2" prefs_dir="$3"
  if command -v "$bin" &>/dev/null; then
    BROWSERS+=("$bin|$policy_dir|$prefs_dir")
  fi
}

# Google Chrome
_register google-chrome-stable "/etc/opt/chrome/policies/managed" "$HOME/.config/google-chrome"
_register google-chrome        "/etc/opt/chrome/policies/managed" "$HOME/.config/google-chrome"
# Chromium
_register chromium             "/etc/chromium/policies/managed"   "$HOME/.config/chromium"
_register chromium-browser     "/etc/chromium/policies/managed"   "$HOME/.config/chromium"
# Brave
_register brave                "/etc/brave/policies/managed"      "$HOME/.config/BraveSoftware/Brave-Browser"
_register brave-browser        "/etc/brave/policies/managed"      "$HOME/.config/BraveSoftware/Brave-Browser"

# Deduplicate by policy_dir (e.g. google-chrome-stable vs google-chrome)
_dedup_browsers() {
  local -A seen
  local deduped=()
  for entry in "${BROWSERS[@]}"; do
    local policy_dir="${entry#*|}"
    policy_dir="${policy_dir%%|*}"
    if [[ -z "${seen[$policy_dir]:-}" ]]; then
      seen[$policy_dir]=1
      deduped+=("$entry")
    fi
  done
  BROWSERS=("${deduped[@]}")
}

# ── Preferences fixer ────────────────────────────────────────────────────────
# Ensures browser Preferences are set so managed policy theme takes effect.
# Clears user themes, sets both color_scheme and color_scheme2 to explicitly
# follow the required mode.

fix_preferences() {
  local prefs_dir="$1"
  local name="$2"
  local cs2="$3"  # color_scheme: 2=dark, 1=light, 0=system
  local prefs_file="$prefs_dir/Default/Preferences"

  # Create Default dir and minimal Preferences if missing
  if [[ ! -f "$prefs_file" ]]; then
    mkdir -p "$prefs_dir/Default" 2>/dev/null
    echo '{}' > "$prefs_file"
    log "$name: created empty Preferences file"
  fi

  # Apply all required defaults via jq — every run, not cached
  # extensions.theme.id = ""           → clear any installed/autogenerated theme
  # extensions.theme.use_system = false → don't use system theme
  # extensions.theme.use_custom = false → don't use custom theme
  # browser.theme.color_scheme         → 2=dark, 1=light, 0=system
  # browser.theme.color_scheme2        → 2=dark, 1=light, 0=system
  local tmp_file="${prefs_file}.ii-tmp"

  if jq --argjson cs "$cs2" '
    .extensions.theme.id = "" |
    .extensions.theme.use_system = false |
    .extensions.theme.use_custom = false |
    .browser.theme.color_scheme = $cs |
    .browser.theme.color_scheme2 = $cs |
    del(.browser.theme.user_color) |
    del(.browser.theme.user_color2)
  ' "$prefs_file" > "$tmp_file" 2>/dev/null && [[ -s "$tmp_file" ]]; then
    mv "$tmp_file" "$prefs_file"
    log "$name: preferences set (color_scheme=$cs2, color_scheme2=$cs2)"
  else
    rm -f "$tmp_file"
    log "$name: ERROR — failed to update preferences"
  fi
}

# ── Write policy and refresh ─────────────────────────────────────────────────

apply_to_browser() {
  local bin="$1"
  local policy_dir="$2"
  local prefs_dir="$3"
  local theme_color="$4"
  local mode="$5"  # "dark" or "light"
  local variant="$6"  # "tonal_spot", "content", "rainbow", etc.
  local name="$bin"
  local policy_written='false'
  local omarchy_browser='false'

  # We must explicitly set Chrome's internal theme engine to Dark (2) or Light (1).
  # While xdg-desktop-portal successfully tells Chrome's GTK window borders to switch,
  # it often fails to trigger the GM3 Theme Engine to recalculate its palette.
  # 2 = Dark, 1 = Light
  local pref_cs2=1
  if [[ "$mode" == "dark" ]]; then
    pref_cs2=2
  fi

  # 1. Fix preferences first — ensures GM3 theme engine generates correct dark/light palette
  fix_preferences "$prefs_dir" "$name" "$pref_cs2"

  # 2. Write policy — only BrowserThemeColor (persists across restarts)
  if ensure_policy_dir_writable "$policy_dir" "$name"; then
    printf '{"BrowserThemeColor": "%s", "BrowserColorScheme": "device"}\n' "$theme_color" > "$policy_dir/ii-theme.json"
    policy_written='true'
    log "$name: policy written to $policy_dir/ii-theme.json"
  else
    log "$name: BrowserThemeColor policy unavailable; standard Chrome/Brave will only get dark/light frame prefs"
  fi

  # 3. Apply live
  if is_omarchy "$bin"; then
    omarchy_browser='true'
    local rgb_color
    rgb_color=$(hex_to_rgb "$theme_color")

    log "$name: Omarchy fork detected. Using CLI flags + policy."
    # We use both: policy for persistence, CLI for instant flicker-free update
    "$bin" --no-startup-window \
           --refresh-platform-policy \
           --set-user-color="$rgb_color" \
           --set-color-scheme="$mode" \
           --set-color-variant="$variant" >/dev/null 2>&1 & disown
  else
    log "$name: Standard browser detected. Using policy refresh."
    "$bin" --refresh-platform-policy --no-startup-window >/dev/null 2>&1 & disown
  fi

  if [[ "$policy_written" == 'true' || "$omarchy_browser" == 'true' ]]; then
    log "$name: applied theme $theme_color (mode=$mode, variant=$variant)"
  else
    log "$name: applied mode only (mode=$mode); theme color requires writable policy dir"
  fi
}

# ── Resolve variant (scheme type) ──────────────────────────────────────────────

resolve_variant() {
  # Read variant from config
  local config_file
  config_file="$(inir_config_file)"
  if [[ -f "$config_file" ]]; then
    local variant
    variant=$(jq -r '.appearance.palette.type // "auto"' "$config_file" 2>/dev/null)
    if [[ -n "$variant" && "$variant" != "null" && "$variant" != "auto" ]]; then
      # Convert scheme-xxx to xxx for Chrome (e.g., scheme-tonal-spot -> tonal_spot)
      local chrome_variant
      chrome_variant=$(echo "$variant" | sed 's/scheme-//' | tr '-' '_')

      # Chrome only supports: tonal_spot, neutral, vibrant, expressive
      # Map unsupported variants to neutral
      case "$chrome_variant" in
        tonal_spot|neutral|vibrant|expressive)
          echo "$chrome_variant"
          ;;
        *)
          echo "neutral"
          ;;
      esac
      return
    fi
  fi
  echo "tonal_spot"  # Default fallback
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
  local theme_color
  theme_color=$(resolve_color "$1")

  if [[ -z "$theme_color" ]]; then
    log "Could not determine browser theme color. Skipping."
    return 1
  fi

  local mode
  mode=$(resolve_color_scheme)

  local variant
  variant=$(resolve_variant)

  log "Browser theme color: $theme_color, mode: $mode, variant: $variant"

  _dedup_browsers

  if [[ ${#BROWSERS[@]} -eq 0 ]]; then
    log "No Chromium-based browsers found. Skipping."
    return 0
  fi

  for entry in "${BROWSERS[@]}"; do
    IFS='|' read -r bin policy_dir prefs_dir <<< "$entry"
    apply_to_browser "$bin" "$policy_dir" "$prefs_dir" "$theme_color" "$mode" "$variant"
  done
}

main "$@"
