#!/usr/bin/env bash
set -euo pipefail

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="$XDG_STATE_HOME/quickshell"

# shellcheck source=scripts/lib/config-path.sh
source "$SCRIPT_DIR/../lib/config-path.sh"
CONFIG_FILE="$(inir_config_file)"
MODULE_LOG="$STATE_DIR/user/generated/theming_modules.log"
TARGETS_DIR="$SCRIPT_DIR/targets"
MODULES_DIR="$SCRIPT_DIR/modules"

ensure_generated_dirs() {
  mkdir -p "$STATE_DIR/user/generated"
}

# Cap an append-only pipeline log, keeping the newest lines.
# Call from an orchestrator before modules are spawned — never from inside a
# module, where up to four of them append concurrently and the swap would race.
rotate_log() {
  local log_path="$1"
  local max_bytes="${2:-1048576}"
  local keep_bytes=$((max_bytes / 4))
  [[ -f "$log_path" ]] || return 0

  local size
  size="$(stat -c %s "$log_path" 2>/dev/null || printf '0')"
  [[ "$size" =~ ^[0-9]+$ ]] || return 0
  (( size > max_bytes )) || return 0

  if tail -c "$keep_bytes" "$log_path" > "$log_path.rotated" 2>/dev/null; then
    mv -f "$log_path.rotated" "$log_path"
  else
    rm -f "$log_path.rotated"
  fi
}

log_module() {
  ensure_generated_dirs
  printf '[%s] [%s] %s\n' "$(date '+%H:%M:%S')" "${COLOR_MODULE_ID:-module}" "$*" >> "$MODULE_LOG"
}

config_bool() {
  local query="$1"
  local fallback="$2"
  if [[ -f "$CONFIG_FILE" ]] && command -v jq >/dev/null 2>&1; then
    # jq '//' treats false as null — use explicit null check so false is preserved
    jq -r "if ($query) == null then $fallback else ($query) end" "$CONFIG_FILE" 2>/dev/null || printf '%s\n' "$fallback"
  else
    printf '%s\n' "$fallback"
  fi
}

config_json() {
  local query="$1"
  local fallback="$2"
  if [[ -f "$CONFIG_FILE" ]] && command -v jq >/dev/null 2>&1; then
    jq -r "$query" "$CONFIG_FILE" 2>/dev/null || printf '%s\n' "$fallback"
  else
    printf '%s\n' "$fallback"
  fi
}

theme_mode() {
  local meta="$STATE_DIR/user/generated/theme-meta.json" mode=""
  if [[ -f "$meta" ]] && command -v jq >/dev/null 2>&1; then
    mode="$(jq -r '.mode // empty' "$meta" 2>/dev/null || true)"
  fi
  [[ "$mode" == "light" ]] && printf 'light\n' || printf 'dark\n'
}

# Add a whole line to a flags file once, on a line of its own even when the file ends without a newline.
# Returns 0 when it was added, 1 when it was already there.
append_line_once() {
  local path="$1" line="$2"
  grep -qsxF -- "$line" "$path" && return 1
  mkdir -p "$(dirname "$path")"
  [[ -s "$path" && -n "$(tail -c1 "$path")" ]] && printf '\n' >> "$path"
  printf '%s\n' "$line" >> "$path"
}

shell_font_family() {
  local line
  line="$(grep -s '^gtk-font-name=' "$XDG_CONFIG_HOME/gtk-3.0/settings.ini" | head -n1)"
  line="${line#gtk-font-name=}"
  line="$(sed -E 's/[[:space:]]+[0-9]+(\.[0-9]+)?$//' <<<"$line")"
  printf '%s' "${line//\"/}"
}

# Write stdin to a path only when the bytes differ (a running app reloads on any write).
# Returns 0 when the file changed, 1 when it was already identical.
write_if_changed() {
  local path="$1" tmp
  tmp="$(mktemp "${path}.XXXXXX")"
  cat > "$tmp"
  if [[ -f "$path" ]] && cmp -s "$tmp" "$path"; then
    rm -f "$tmp"
    return 1
  fi
  chmod 644 "$tmp"
  mv -f "$tmp" "$path"
  return 0
}

venv_python() {
  local venv_path
  if [[ -n "${INIR_VENV:-}" ]]; then
    venv_path="$(eval echo "$INIR_VENV")"
  elif [[ -n "${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-}" ]]; then
    venv_path="$(eval echo "$ILLOGICAL_IMPULSE_VIRTUAL_ENV")"
  else
    venv_path="$HOME/.local/state/quickshell/.venv"
  fi

  local candidate="$venv_path/bin/python3"
  if [[ -x "$candidate" ]]; then
    printf '%s\n' "$candidate"
  else
    printf '%s\n' python3
  fi
}

run_module_script() {
  local module_path="$1"
  if bash "$module_path"; then
    return 0
  fi
  log_module "module failed: $(basename "$module_path")"
  return 1
}

list_theming_modules() {
  find "$MODULES_DIR" -maxdepth 1 -type f -name '*.sh' | sort
}

# Profile roots of the Firefox family (Firefox, LibreWolf, Floorp, Waterfox, Zen), native and Flatpak.
firefox_profile_roots() {
  printf '%s\n' \
    "$XDG_CONFIG_HOME/mozilla/firefox" "$HOME/.mozilla/firefox" \
    "$HOME/.var/app/org.mozilla.firefox/config/mozilla/firefox" "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox" \
    "$HOME/.librewolf" "$XDG_CONFIG_HOME/librewolf/librewolf" "$HOME/.var/app/io.gitlab.librewolf-community/.librewolf" \
    "$HOME/.floorp" "$HOME/.var/app/one.ablaze.floorp/.floorp" \
    "$HOME/.waterfox" "$HOME/.var/app/net.waterfox.waterfox/.waterfox" \
    "$HOME/.zen" "$XDG_CONFIG_HOME/zen" "$HOME/.var/app/app.zen_browser.zen/.zen"
}

# Chromium-family browsers, one per line: "<managed policy dir>|<user data dir>|<how to tell it is installed>".
# Installed means a command on PATH or `flatpak:<id>` installed, never a data dir: one left behind by a removed browser
# (or an AppImage tried once) would ask for a password for nothing. Flatpak Chrome and Brave link the host's /etc policies at launch; Flatpak Chromium reads an extension point, which
# flatpak also looks for under the user's data dir, so that one needs no root.
chromium_browsers() {
  local ext="${FLATPAK_USER_DIR:-$XDG_DATA_HOME/flatpak}/extension" arch var="$HOME/.var/app"
  arch="$(uname -m)"
  printf '%s\n' \
    "/etc/opt/chrome/policies/managed|$XDG_CONFIG_HOME/google-chrome|google-chrome-stable google-chrome" \
    "/etc/opt/chrome/policies/managed|$XDG_CONFIG_HOME/google-chrome-beta|google-chrome-beta" \
    "/etc/opt/chrome/policies/managed|$XDG_CONFIG_HOME/google-chrome-unstable|google-chrome-unstable" \
    "/etc/chromium/policies/managed|$XDG_CONFIG_HOME/chromium|chromium chromium-browser" \
    "/etc/brave/policies/managed|$XDG_CONFIG_HOME/BraveSoftware/Brave-Browser|brave brave-browser" \
    "/etc/chromium/policies/managed|$XDG_CONFIG_HOME/net.imput.helium|helium helium-browser" \
    "/etc/chromium/policies/managed|$XDG_CONFIG_HOME/thorium|thorium-browser thorium" \
    "/etc/opt/chrome/policies/managed|$var/com.google.Chrome/config/google-chrome|flatpak:com.google.Chrome" \
    "/etc/brave/policies/managed|$var/com.brave.Browser/config/BraveSoftware/Brave-Browser|flatpak:com.brave.Browser" \
    "$ext/org.chromium.Chromium.Extension.inir/$arch/1/policies/managed|$var/org.chromium.Chromium/config/chromium|flatpak:org.chromium.Chromium" \
    "$ext/io.github.ungoogled_software.ungoogled_chromium.Extension.inir/$arch/1/policies/managed|$var/io.github.ungoogled_software.ungoogled_chromium/config/chromium|flatpak:io.github.ungoogled_software.ungoogled_chromium"
}

# The entries of chromium_browsers that are installed here. Always returns 0: it runs inside the applycolor
# fingerprint pipeline, under `set -e -o pipefail`.
installed_chromium_browsers() {
  local entry marker found
  while IFS= read -r entry; do
    for marker in ${entry##*|}; do
      case "$marker" in
        flatpak:*) found="$XDG_DATA_HOME/flatpak/app/${marker#flatpak:}"
          if [[ ! -d "$found" ]]; then found="/var/lib/flatpak/app/${marker#flatpak:}"; fi ;;
        *) found="$(command -v "$marker" 2>/dev/null || true)" ;;
      esac
      if [[ -n "$found" && -e "$found" ]]; then
        printf '%s\n' "$entry"
        break
      fi
    done
  done < <(chromium_browsers)
  return 0
}

list_theming_target_manifests() {
  if [[ -d "$TARGETS_DIR" ]]; then
    find "$TARGETS_DIR" -maxdepth 1 -type f -name '*.json' | sort
  fi
}

resolve_target_module_path() {
  local target_id="$1"
  local manifest_path="$TARGETS_DIR/${target_id}.json"
  [[ -f "$manifest_path" ]] || return 1

  local module_name=""
  if command -v jq >/dev/null 2>&1; then
    module_name=$(jq -r '.module // empty' "$manifest_path" 2>/dev/null || true)
  else
    module_name=$(sed -n 's/.*"module"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$manifest_path" | head -1)
  fi

  [[ -n "$module_name" ]] || return 1
  local module_path="$MODULES_DIR/$module_name"
  [[ -f "$module_path" ]] || return 1
  printf '%s\n' "$module_path"
}

target_manifest_enabled() {
  local manifest_path="$1"
  [[ -f "$manifest_path" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 0

  local config_key value
  config_key=$(jq -r '.configKey // empty' "$manifest_path" 2>/dev/null || true)
  [[ -n "$config_key" ]] || return 0
  [[ -f "$CONFIG_FILE" ]] || return 0

  value=$(jq -r --arg key "$config_key" 'getpath($key | split(".")) as $v | if $v == null then true else $v end' "$CONFIG_FILE" 2>/dev/null || printf 'true')
  [[ "$value" != "false" ]]
}

list_declared_theming_modules() {
  local manifest
  while IFS= read -r manifest; do
    [[ -n "$manifest" ]] || continue
    target_manifest_enabled "$manifest" || continue
    local target_id
    target_id="$(basename "$manifest" .json)"
    resolve_target_module_path "$target_id" || true
  done < <(list_theming_target_manifests)
}
