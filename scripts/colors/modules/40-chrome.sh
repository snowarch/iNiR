#!/usr/bin/env bash
# Chromium browsers take one colour, the BrowserThemeColor policy, and build their whole palette from it. Its tone
# decides light or dark, so they get the header bar colour, never the accent. A running browser watches its policy
# folder and repaints about 5 s after the file changes, so nothing is launched. Folders under /etc need root once:
# one prompt for all of them, remembered when declined. Flatpak Chromium reads a folder in the user's data dir.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/module-runtime.sh"
COLOR_MODULE_ID="chrome"

POLICY_FILE="ii-theme.json"
POLICY_DECLINED_FILE="$STATE_DIR/user/generated/chrome-policy.declined"

notify_user() {
  command -v notify-send >/dev/null 2>&1 || return 0
  notify-send "Chrome Theme" "$1" -a "Chrome Theme" || true
}

elevate() {
  # 1. Interactive terminal — use sudo directly
  if [[ -t 0 ]] && [[ -t 1 ]]; then
    sudo "$@"
    return $?
  fi

  # 2. Non-interactive but cached sudo credentials available
  if sudo -n true 2>/dev/null; then
    sudo "$@"
    return $?
  fi

  # 3. Graphical session: pkexec asks through whichever polkit agent runs (iNiR's lives inside the shell, so no
  # process name gives it away). Without an agent it exits 127 at once; a dismissed dialog exits 126.
  if command -v pkexec >/dev/null 2>&1 && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    pkexec "$@"
    return $?
  fi

  log_module "no elevation method available (need sudo or pkexec)"
  return 1
}

# One password prompt for every browser's policy dir, once. A dismissed or failed prompt is remembered, so a wallpaper
# change never asks again; the notification carries the command to do it by hand.
prepare_policy_dirs() {
  local missing=() dir
  for dir in "$@"; do
    [[ -d "$dir" && -w "$dir" ]] || missing+=("$dir")
  done
  (( ${#missing[@]} )) || return 0

  if [[ -f "$POLICY_DECLINED_FILE" && "$(cat "$POLICY_DECLINED_FILE")" == "${missing[*]}" ]]; then
    log_module "policy dirs not writable, prompt declined earlier: ${missing[*]}"
    return 1
  fi

  log_module "requesting writable policy dirs: ${missing[*]}"
  # shellcheck disable=SC2016 # expanded by the elevated shell, paths passed as arguments
  if elevate sh -c 'for d; do mkdir -p "$d" && chmod a+rw "$d" || exit 1; done' sh "${missing[@]}"; then
    rm -f "$POLICY_DECLINED_FILE"
    log_module "policy dirs ready: ${missing[*]}"
    return 0
  fi

  printf '%s\n' "${missing[*]}" > "$POLICY_DECLINED_FILE"
  local manual=""
  for dir in "${missing[@]}"; do
    manual+="sudo mkdir -p $dir && sudo chmod a+rw $dir"$'\n'
  done
  log_module "policy dirs not prepared; by hand: ${manual//$'\n'/; }"
  notify_user "Browser colours need writable policy folders. Run once:"$'\n'"${manual%$'\n'}"
  return 1
}

# The header bar colour: the browser's frame is built from it (a tinted accent would turn a dark shell's browser light).
header_colour() {
  local palette
  for palette in app-palette.json palette.json; do
    palette="$STATE_DIR/user/generated/$palette"
    [[ -s "$palette" ]] || continue
    jq -r '.app_headerbar_bg // .app_surface // .surface_container_low // .surface // .background // empty' "$palette" \
      2>/dev/null | grep -xiE '#[0-9a-f]{6}' && return 0
  done
  return 1
}

write_policy() {
  local dir="$1" colour="$2"
  if [[ ! -d "$dir" && "$dir" != /etc/* ]]; then
    mkdir -p "$dir"
  fi
  if [[ ! -d "$dir" || ! -w "$dir" ]]; then
    log_module "$dir not writable - colour skipped"
    return 0
  fi
  # BackgroundModeEnabled false: a closed browser never stays resident.
  if printf '{"BrowserThemeColor": "%s", "BackgroundModeEnabled": false}\n' "$colour" | write_if_changed "$dir/$POLICY_FILE"; then
    log_module "wrote $dir/$POLICY_FILE ($colour)"
  fi
}

remove_policy() {
  local file="$1/$POLICY_FILE"
  [[ -e "$file" ]] || return 0
  if rm -f "$file" 2>/dev/null; then
    log_module "removed $file: the browser's own colours are back"
  else
    log_module "cannot remove $file (folder not writable)"
  fi
}

# Web pages read light or dark from the profile's colour scheme (2 dark, 1 light). The browser keeps its prefs in memory
# and writes them back when it closes, so the file is only edited while the browser is closed.
set_colour_scheme() {
  local data="$1" scheme="$2" prefs="$1/Default/Preferences" tmp
  [[ -f "$prefs" ]] || return 0
  if [[ -L "$data/SingletonLock" ]]; then
    return 0
  fi
  if jq -e --argjson cs "$scheme" '.browser.theme.color_scheme2 == $cs and .browser.theme.color_scheme == $cs' \
    "$prefs" >/dev/null 2>&1; then
    return 0
  fi
  tmp="$(mktemp "$prefs.XXXXXX")"
  if jq -c --argjson cs "$scheme" '.browser.theme.color_scheme = $cs | .browser.theme.color_scheme2 = $cs' \
    "$prefs" > "$tmp" 2>/dev/null && [[ -s "$tmp" ]]; then
    chmod --reference="$prefs" "$tmp"
    mv -f "$tmp" "$prefs"
    log_module "wrote $prefs (colour scheme $scheme)"
  else
    rm -f "$tmp"
    log_module "$prefs unreadable - left alone"
  fi
}

main() {
  command -v jq >/dev/null 2>&1 || { log_module "jq not installed - skipping"; exit 0; }
  local browsers=() entry dir data colour scheme=1 root_dirs=() seen=" "
  mapfile -t browsers < <(installed_chromium_browsers)
  (( ${#browsers[@]} )) || exit 0

  if [[ "$(config_bool '.appearance.wallpaperTheming.enableChrome' true)" != "true" ]]; then
    for entry in "${browsers[@]}"; do
      remove_policy "${entry%%|*}"
    done
    exit 0
  fi

  colour="$(header_colour)" || { log_module "no app palette yet - skipping"; exit 0; }
  if [[ "$(theme_mode)" == "dark" ]]; then
    scheme=2
  fi

  for entry in "${browsers[@]}"; do
    dir="${entry%%|*}"
    if [[ "$dir" == /etc/* && "$seen" != *" $dir "* ]]; then
      root_dirs+=("$dir")
      seen+="$dir "
    fi
  done
  if (( ${#root_dirs[@]} )); then
    prepare_policy_dirs "${root_dirs[@]}" || true
  fi

  seen=" "
  for entry in "${browsers[@]}"; do
    dir="${entry%%|*}"
    data="${entry#*|}"
    data="${data%%|*}"
    if [[ "$seen" != *" $dir "* ]]; then
      write_policy "$dir" "$colour"
      seen+="$dir "
    fi
    set_colour_scheme "$data" "$scheme"
  done
}

main "$@"
