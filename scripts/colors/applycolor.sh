#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/module-runtime.sh"

# Everything the modules read. Same inputs give the same files, so a run on them only makes
# every app reload what it already wears: Spotify reloaded (and raised itself), Steam and the
# terminals refreshed on each shell restart. App installs are part of it, so a Spotify update
# that drops its patch still gets themed again.
# Runs under `set -e -o pipefail`: a missing path is skipped with `if`, never `[[ -e ]] && …`, whose
# failure as a loop's last command ends the script before any app is themed (test-applycolor-fingerprint.py).
inputs_fingerprint() {
  local generated="$STATE_DIR/user/generated" name path
  {
    for name in colors.json palette.json app-palette.json terminal.json theme-meta.json material_colors.scss color.txt iris-surface.json; do
      if [[ -f "$generated/$name" ]]; then sha1sum "$generated/$name"; fi
    done
    if [[ -f "$CONFIG_FILE" ]]; then sha1sum "$CONFIG_FILE"; fi
    find "$SCRIPT_DIR" -type f -printf '%P %s %T@\n' 2>/dev/null | sort
    for path in /opt/spotify/Apps/xpui/index.html /usr/share/spotify/Apps/xpui/index.html \
      "$HOME/.local/share/spotify-launcher/install/usr/share/spotify/Apps/xpui/index.html" \
      "$HOME/.local/share/flatpak/app/com.spotify.Client/current/active/files/extra/share/spotify/Apps/xpui/index.html" \
      /var/lib/flatpak/app/com.spotify.Client/current/active/files/extra/share/spotify/Apps/xpui/index.html \
      "$HOME/.local/share/Steam/steamui/skins" "$HOME/.steam/steam/steamui/skins"; do
      if [[ -e "$path" ]]; then stat -c '%n %s %Y' "$path"; fi
    done
    # A new browser profile gets its colours; size only, since Firefox rewrites profiles.ini as it starts.
    while IFS= read -r path; do
      if [[ -f "$path/profiles.ini" ]]; then stat -c '%n %s' "$path/profiles.ini"; fi
    done < <(firefox_profile_roots)
    installed_chromium_browsers
  } 2>/dev/null | sha1sum | cut -d' ' -f1
}

main() {
  ensure_generated_dirs

  # One run at a time: a wallpaper change and iRiS handing over its new surface each start one, and two
  # runs side by side both restyled every app. The later one now waits and finds nothing left to do.
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$STATE_DIR/user/generated/applycolor.lock"
    flock -w 120 9 || true
  fi

  local force=0 arg
  for arg in "$@"; do
    [[ "$arg" == "--force" ]] && force=1
  done
  [[ "${INIR_THEME_FORCE:-0}" == "1" ]] && force=1
  local stamp_file="$STATE_DIR/user/generated/applycolor.inputs"
  local fingerprint
  fingerprint="$(inputs_fingerprint)"
  if (( ! force )) && [[ -n "$fingerprint" && "$(cat "$stamp_file" 2>/dev/null)" == "$fingerprint" ]]; then
    COLOR_MODULE_ID=applycolor log_module "inputs unchanged since the last run - apps left alone (--force to re-apply)"
    exit 0
  fi

  # Every pipeline log is append-only with no cap of its own; a long-lived
  # install accumulates tens of MB under XDG_STATE_HOME. Trim here, before the
  # modules that write them are spawned.
  local log_name
  for log_name in theming_modules terminal_colors code_editor_themes spicetify_theme; do
    rotate_log "$STATE_DIR/user/generated/$log_name.log"
  done

  local manifests=()
  while IFS= read -r manifest_path; do
    [[ -n "$manifest_path" ]] || continue
    manifests+=("$manifest_path")
  done < <(list_theming_target_manifests)

  local modules=()
  local enabled_targets=0
  local manifest_path target_id module_path
  for manifest_path in "${manifests[@]}"; do
    target_manifest_enabled "$manifest_path" || continue
    enabled_targets=$((enabled_targets + 1))
    target_id="$(basename "$manifest_path" .json)"
    module_path="$(resolve_target_module_path "$target_id" || true)"
    [[ -n "$module_path" ]] || continue
    modules+=("$module_path")
  done

  if [[ ${#modules[@]} -eq 0 && ${#manifests[@]} -eq 0 ]]; then
    while IFS= read -r module_path; do
      [[ -n "$module_path" ]] || continue
      modules+=("$module_path")
    done < <(list_theming_modules)
  fi

  if [[ ${#modules[@]} -eq 0 && ${#manifests[@]} -gt 0 && "$enabled_targets" -eq 0 ]]; then
    printf 'No enabled theming targets found in %s\n' "$SCRIPT_DIR/targets" >&2
    exit 0
  fi

  if [[ ${#modules[@]} -eq 0 ]]; then
    printf 'No theming modules found for enabled targets in %s\n' "$SCRIPT_DIR/modules" >&2
    exit 1
  fi

  local cpu_count max_jobs running failed
  cpu_count="$(nproc 2>/dev/null || printf '4')"
  max_jobs="${INIR_THEME_MAX_JOBS:-$((cpu_count / 2))}"
  [[ "$max_jobs" =~ ^[0-9]+$ ]] || max_jobs=2
  (( max_jobs < 2 )) && max_jobs=2
  (( max_jobs > 4 )) && max_jobs=4

  run_one_module() {
    local module_path="$1"
    if command -v ionice >/dev/null 2>&1; then
      ionice -c 3 nice -n 10 bash "$module_path"
    else
      nice -n 10 bash "$module_path"
    fi
  }

  running=0
  failed=0
  for module_path in "${modules[@]}"; do
    # The lock stays with this script: a module's detached helper must not hold it after we exit.
    run_one_module "$module_path" 9>&- &
    running=$((running + 1))
    if (( running >= max_jobs )); then
      if ! wait -n; then
        failed=1
      fi
      running=$((running - 1))
    fi
  done

  while (( running > 0 )); do
    if ! wait -n; then
      failed=1
    fi
    running=$((running - 1))
  done

  if (( ! failed )) && [[ -n "$fingerprint" ]]; then
    printf '%s\n' "$fingerprint" > "$stamp_file"
  fi
  exit "$failed"
}

main "$@"
