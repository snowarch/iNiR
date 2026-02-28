#!/usr/bin/env bash
#
# apply-chrome-theme.sh — Apply GM3 BrowserThemeColor to Chromium-based browsers
#
# Usage:
#   apply-chrome-theme.sh                  # auto-detect color from material pipeline
#   apply-chrome-theme.sh "#ff6b35"        # explicit hex color
#
# Supports: Google Chrome, Chromium, Brave
# Requires: jq, writable policy dir (one-time sudo setup)
#
# One-time setup per browser:
#   sudo mkdir -p /etc/chromium/policies/managed && sudo chown a+rw- /etc/chromium/policies/managed
#   sudo mkdir -p /etc/opt/chrome/policies/managed && sudo chown a+rw- /etc/opt/chrome/policies/managed
#   sudo mkdir -p /etc/brave/policies/managed && sudo chown a+rw- /etc/brave/policies/managed

XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$XDG_STATE_HOME/quickshell"
LOG_FILE="$STATE_DIR/user/generated/chrome_theme.log"
mkdir -p "$STATE_DIR/user/generated" 2>/dev/null
: > "$LOG_FILE" 2>/dev/null

log() { echo "[chrome] $*" >> "$LOG_FILE"; }

# ── Helpers ──────────────────────────────────────────────────────────────────

hex_to_rgb() {
  local hex=$1
  hex="${hex#\#}"
  printf "%d,%d,%d" "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
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

# ── Resolve theme color ─────────────────────────────────────────────────────

resolve_color() {
  # 1. Explicit argument
  if [[ -n "$1" && "$1" =~ ^#[A-Fa-f0-9]{6}$ ]]; then
    echo "$1"
    return
  fi

  # 2. Raw seed color from image (best for GM3, as Chrome generates its own palette from this)
  local seed_file="$STATE_DIR/user/generated/color.txt"
  if [[ -f "$seed_file" ]]; then
    local c
    c=$(cat "$seed_file" | tr -d '\n')
    if [[ -n "$c" && "$c" =~ ^#[A-Fa-f0-9]{6}$ ]]; then
      echo "$c"
      return
    fi
  fi

  # 3. colors.json fallback (this is the already-generated primary, which might cause double-theming)
  local colors_json="$STATE_DIR/user/generated/colors.json"
  if [[ -f "$colors_json" ]] && command -v jq &>/dev/null; then
    local c
    c=$(jq -r '.primary // empty' "$colors_json" 2>/dev/null)
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
  local name="$bin"

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
  if [[ -d "$policy_dir" && -w "$policy_dir" ]]; then
    echo "{\"BrowserThemeColor\": \"$theme_color\"}" | tee "$policy_dir/ii-theme.json" >/dev/null
  else
    log "$name: policy dir not writable → sudo mkdir -p $policy_dir && sudo chown \$USER $policy_dir"
  fi

  # 3. Apply live
  if is_omarchy "$bin"; then
    local rgb_color
    rgb_color=$(hex_to_rgb "$theme_color")
    
    log "$name: Omarchy fork detected. Using CLI flags + policy."
    # We use both: policy for persistence, CLI for instant flicker-free update
    "$bin" --no-startup-window \
           --refresh-platform-policy \
           --set-user-color="$rgb_color" \
           --set-color-scheme="$mode" \
           --set-color-variant="tonal_spot" >/dev/null 2>&1 & disown
  else
    log "$name: Standard browser detected. Using policy refresh."
    "$bin" --refresh-platform-policy --no-startup-window >/dev/null 2>&1 & disown
  fi

  log "$name: applied theme $theme_color (mode=$mode, pref_cs2=$pref_cs2)"
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
  local theme_color
  theme_color=$(resolve_color "$1")

  if [[ -z "$theme_color" ]]; then
    log "Could not determine primary color. Skipping."
    return 1
  fi

  local mode
  mode=$(resolve_color_scheme)

  log "GM3 seed color: $theme_color, mode: $mode"

  _dedup_browsers

  if [[ ${#BROWSERS[@]} -eq 0 ]]; then
    log "No Chromium-based browsers found. Skipping."
    return 0
  fi

  for entry in "${BROWSERS[@]}"; do
    IFS='|' read -r bin policy_dir prefs_dir <<< "$entry"
    apply_to_browser "$bin" "$policy_dir" "$prefs_dir" "$theme_color" "$mode"
  done
}

main "$@"
