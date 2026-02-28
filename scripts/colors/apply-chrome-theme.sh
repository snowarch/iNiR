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
#   sudo mkdir -p /etc/chromium/policies/managed && sudo chown "$USER" /etc/chromium/policies/managed
#   sudo mkdir -p /etc/opt/chrome/policies/managed && sudo chown "$USER" /etc/opt/chrome/policies/managed
#   sudo mkdir -p /etc/brave/policies/managed && sudo chown "$USER" /etc/brave/policies/managed

XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$XDG_STATE_HOME/quickshell"
LOG_FILE="$STATE_DIR/user/generated/chrome_theme.log"
mkdir -p "$STATE_DIR/user/generated" 2>/dev/null
: > "$LOG_FILE" 2>/dev/null

log() { echo "[chrome] $*" >> "$LOG_FILE"; }

# ── Resolve theme color ─────────────────────────────────────────────────────

resolve_color() {
  # 1. Explicit argument
  if [[ -n "$1" && "$1" =~ ^#[A-Fa-f0-9]{6}$ ]]; then
    echo "$1"
    return
  fi

  # 2. colors.json (matugen output)
  local colors_json="$STATE_DIR/user/generated/colors.json"
  if [[ -f "$colors_json" ]] && command -v jq &>/dev/null; then
    local c
    c=$(jq -r '.primary // empty' "$colors_json" 2>/dev/null)
    if [[ -n "$c" ]]; then
      echo "$c"
      return
    fi
  fi

  # 3. material_colors.scss fallback
  local scss_file="$STATE_DIR/user/generated/material_colors.scss"
  if [[ -f "$scss_file" ]]; then
    local c
    c=$(grep '^\$primary:' "$scss_file" | sed 's/.*: *\(#[A-Fa-f0-9]\{6\}\).*/\1/')
    if [[ -n "$c" ]]; then
      echo "$c"
      return
    fi
  fi
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
# Clears user themes, sets color_scheme + color_scheme2 to follow-device (2).

fix_preferences() {
  local prefs_dir="$1"
  local name="$2"
  local prefs_file="$prefs_dir/Default/Preferences"

  # Create Default dir and minimal Preferences if missing
  if [[ ! -f "$prefs_file" ]]; then
    mkdir -p "$prefs_dir/Default" 2>/dev/null
    echo '{}' > "$prefs_file"
    log "$name: created empty Preferences file"
  fi

  # Apply all required defaults via jq
  # extensions.theme.id = ""           → clear any installed theme
  # extensions.theme.use_system = false → don't use system theme
  # extensions.theme.use_custom = false → don't use custom theme
  # browser.theme.color_scheme = 2     → follow device (legacy key)
  # browser.theme.user_color = 2       → follow device (legacy key)
  # browser.theme.color_scheme2 = 0    → system default (v2 key, used by newer Chrome/Chromium)
  local tmp_file="${prefs_file}.ii-tmp"

  local needs_update=false

  # Check each value — update only if something is wrong
  local cur_id cur_sys cur_cust cur_cs cur_uc cur_cs2
  cur_id=$(jq -r '.extensions.theme.id // "unset"' "$prefs_file" 2>/dev/null)
  cur_sys=$(jq -r '.extensions.theme.use_system // "unset"' "$prefs_file" 2>/dev/null)
  cur_cust=$(jq -r '.extensions.theme.use_custom // "unset"' "$prefs_file" 2>/dev/null)
  cur_cs=$(jq -r '.browser.theme.color_scheme // "unset"' "$prefs_file" 2>/dev/null)
  cur_uc=$(jq -r '.browser.theme.user_color // "unset"' "$prefs_file" 2>/dev/null)
  cur_cs2=$(jq -r '.browser.theme.color_scheme2 // "unset"' "$prefs_file" 2>/dev/null)

  if [[ "$cur_id" != "" || "$cur_sys" != "false" || "$cur_cust" != "false" \
     || "$cur_cs" != "2" || "$cur_uc" != "2" || "$cur_cs2" != "0" ]]; then
    needs_update=true
  fi

  if [[ "$needs_update" == "false" ]]; then
    log "$name: preferences already correct"
    return
  fi

  if jq '
    .extensions.theme.id = "" |
    .extensions.theme.use_system = false |
    .extensions.theme.use_custom = false |
    .browser.theme.color_scheme = 2 |
    .browser.theme.user_color = 2 |
    .browser.theme.color_scheme2 = 0
  ' "$prefs_file" > "$tmp_file" 2>/dev/null && [[ -s "$tmp_file" ]]; then
    mv "$tmp_file" "$prefs_file"
    log "$name: preferences updated (cleared user theme, set follow-device)"
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
  local name="$bin"

  # Fix preferences first
  fix_preferences "$prefs_dir" "$name"

  # Check policy dir
  if [[ ! -d "$policy_dir" || ! -w "$policy_dir" ]]; then
    log "$name: policy dir not writable → sudo mkdir -p $policy_dir && sudo chown \$USER $policy_dir"
    return
  fi

  # Write policy — only BrowserThemeColor, no BrowserColorScheme
  echo "{\"BrowserThemeColor\": \"$theme_color\"}" | tee "$policy_dir/ii-theme.json" >/dev/null

  # Refresh running instance
  "$bin" --refresh-platform-policy --no-startup-window >/dev/null 2>&1 & disown
  log "$name: applied theme $theme_color"
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
  local theme_color
  theme_color=$(resolve_color "$1")

  if [[ -z "$theme_color" ]]; then
    log "Could not determine primary color. Skipping."
    return 1
  fi

  log "GM3 seed color: $theme_color"

  _dedup_browsers

  if [[ ${#BROWSERS[@]} -eq 0 ]]; then
    log "No Chromium-based browsers found. Skipping."
    return 0
  fi

  for entry in "${BROWSERS[@]}"; do
    IFS='|' read -r bin policy_dir prefs_dir <<< "$entry"
    apply_to_browser "$bin" "$policy_dir" "$prefs_dir" "$theme_color"
  done
}

main "$@"
