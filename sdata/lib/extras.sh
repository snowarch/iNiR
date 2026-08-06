# Optional extras helpers for setup/install flows
# shellcheck shell=bash

inir_get_user_wallpapers_dir() {
  local _xdg_pictures
  _xdg_pictures="$(xdg-user-dir PICTURES 2>/dev/null || true)"
  if [[ -z "$_xdg_pictures" || "$_xdg_pictures" != /* || "$_xdg_pictures" == "$HOME" ]]; then
    _xdg_pictures="$HOME/Pictures"
  fi
  printf '%s' "${_xdg_pictures}/Wallpapers"
}

# Install ii-pixel-sddm via the canonical installer script.
# Args:
#   $1 auto apply mode: ask|yes|no (default: ask)
extras_install_sddm_theme() {
  local auto_apply_mode="${1:-ask}"

  if ! command -v sddm &>/dev/null; then
    log_warning "SDDM not detected. Skipping ii-pixel-sddm setup."
    return 0
  fi

  local sddm_script="${REPO_ROOT}/scripts/sddm/install-pixel-sddm.sh"
  if [[ ! -f "$sddm_script" ]]; then
    log_warning "ii-pixel-sddm install script not found, skipping"
    return 0
  fi

  tui_info "Setting up ii-pixel-sddm login theme..."
  chmod +x "$sddm_script"
  if ! INIR_SDDM_AUTO_APPLY="$auto_apply_mode" bash "$sddm_script"; then
    log_warning "ii-pixel-sddm setup failed — SDDM config may need manual update"
    log_warning "Try: sudo bash ${sddm_script}"
    return 1
  fi
}

# Install iNiR-Walls image assets into user's wallpapers directory.
# Behavior:
# - clones repo to temp dir (not persisted)
# - copies only image files into destination
# - does not overwrite existing non-empty files
# Output contract:
# - sets global EXTRAS_INIR_WALLS_FIRST_IMAGE to first copied/available image path (or empty)
extras_install_inir_walls() {
  local walls_repo_url="https://github.com/snowarch/iNiR-Walls.git"
  local walls_estimated_count=148
  local walls_estimated_bytes=663709943
  local walls_estimated_mib
  walls_estimated_mib=$(awk "BEGIN { printf \"%.1f\", ${walls_estimated_bytes}/1024/1024 }")

  tui_info "Optional wallpapers: iNiR-Walls (~${walls_estimated_count} images, ~${walls_estimated_mib} MiB download)."
  tui_dim "Downloads to temp dir, copies image files only, then removes temp clone."

  if ! command -v git >/dev/null 2>&1; then
    log_warning "Git is required to install iNiR-Walls, skipping"
    return 0
  fi

  local user_wallpapers_dir
  user_wallpapers_dir="$(inir_get_user_wallpapers_dir)"
  mkdir -p "$user_wallpapers_dir"

  local walls_tmp
  walls_tmp="$(mktemp -d)"
  local walls_repo_dir="${walls_tmp}/iNiR-Walls"
  local first_image=""
  EXTRAS_INIR_WALLS_FIRST_IMAGE=""

  tui_info "Downloading iNiR-Walls repository (git progress below)..."
  if git clone --depth 1 --progress "$walls_repo_url" "$walls_repo_dir"; then
    local walls_scanned=0
    local walls_copied=0

    shopt -s nullglob globstar
    for wall in "${walls_repo_dir}"/**/*.{jpg,jpeg,png,webp,avif}; do
      [[ -f "$wall" ]] || continue
      # iNiR-Walls generates a 640px WebP per wallpaper under images/thumbs/ for
      # its gallery page. globstar swept those in as if they were wallpapers.
      # They also share the exact basename of the image they preview, so the
      # only thing keeping a thumbnail from landing on a real wallpaper here is
      # that "images/<name>" happens to sort before "images/thumbs/<name>".
      # Filtering by extension is not the fix: four wallpapers are genuinely
      # WebP, one of them 8000x4500.
      [[ "$wall" == */thumbs/* ]] && continue
      walls_scanned=$((walls_scanned + 1))
      local dest="${user_wallpapers_dir}/$(basename "$wall")"
      if [[ ! -f "$dest" ]] || [[ ! -s "$dest" ]]; then
        cp -f "$wall" "$dest"
        walls_copied=$((walls_copied + 1))
      fi
      if [[ -z "$first_image" && -f "$dest" && -s "$dest" ]]; then
        first_image="$dest"
      fi
    done
    shopt -u nullglob globstar

    if [[ "$walls_scanned" -gt 0 ]]; then
      log_success "iNiR-Walls synced (${walls_scanned} images scanned, ${walls_copied} new copied)"
    else
      log_warning "No wallpapers found in iNiR-Walls repository"
    fi
  else
    log_warning "Failed to download iNiR-Walls, continuing"
  fi

  rm -rf "$walls_tmp"
  EXTRAS_INIR_WALLS_FIRST_IMAGE="$first_image"
  return 0
}

# Install / update the "yet-another-monochrome-icon-set" (YAMIS) icon theme by
# dirn-typo. GPL-3, ~23 MiB. Lives in user-scope ($HOME/.local/share/icons) so
# it's available to GTK / Qt without root. Non-intrusive: only installs the
# theme files. The user's current icon theme is NOT touched — they can switch
# via iNiR Settings if they want.
#
# Idempotent: clones on first run, fast-forwards on subsequent runs.
extras_install_yamis_icons() {
  local repo_url="https://bitbucket.org/dirn-typo/yet-another-monochrome-icon-set.git"
  local theme_name="yet-another-monochrome-icon-set"
  local dest="${HOME}/.local/share/icons/${theme_name}"

  if ! command -v git >/dev/null 2>&1; then
    log_warning "Git is required to install YAMIS icons, skipping"
    return 0
  fi

  mkdir -p "${HOME}/.local/share/icons"

  if [[ -d "${dest}/.git" ]]; then
    tui_info "Updating YAMIS monochrome icon theme..."
    if git -C "$dest" pull --ff-only --quiet 2>/dev/null; then
      log_success "YAMIS icons updated"
    else
      log_warning "YAMIS update had issues (non-fatal). Existing files kept."
    fi
    return 0
  fi

  if [[ -d "$dest" && ! -d "${dest}/.git" ]]; then
    log_warning "YAMIS destination exists but is not a git checkout: ${dest}"
    log_warning "Skipping to avoid clobbering manual install"
    return 0
  fi

  tui_info "Installing YAMIS monochrome icon theme (~23 MiB, by dirn-typo)..."
  if git clone --depth 1 --quiet "$repo_url" "$dest"; then
    log_success "YAMIS icons installed at ${dest}"
    log_info  "Switch to it via iNiR Settings → Appearance → Icon theme"
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
      gtk-update-icon-cache -q "$dest" 2>/dev/null || true
    fi
  else
    log_warning "Failed to install YAMIS icons (network?), continuing"
    rm -rf "$dest"
  fi

  return 0
}

# Refresh YAMIS icons during `./setup update` — only acts if the user already
# has YAMIS installed. Never installs fresh on update; that's the install
# flow's or extras menu's responsibility.
extras_refresh_yamis_icons_on_update() {
  local dest="${HOME}/.local/share/icons/yet-another-monochrome-icon-set"
  if [[ -d "${dest}/.git" ]]; then
    extras_install_yamis_icons
  fi
}

# Resolve the latest inir-mascot release tag from the GitHub redirect
# (no API quota involved). Tests and local mirrors can provide an explicit tag.
extras_mascot_latest_tag() {
  if [[ -n "${INIR_MASCOT_RELEASE_TAG:-}" ]]; then
    printf '%s\n' "$INIR_MASCOT_RELEASE_TAG"
    return 0
  fi
  curl -fsI --max-time 10 "https://github.com/snowarch/inir-mascot/releases/latest" 2>/dev/null \
    | tr -d '\r' | awk -F/ 'tolower($0) ~ /^location:/ { print $NF; exit }'
}

extras_mascot_release_base_url() {
  printf '%s\n' "${INIR_MASCOT_RELEASE_BASE_URL:-https://github.com/snowarch/inir-mascot/releases/latest/download}"
}

extras_mascot_helper() {
  local shell_dir="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/inir"
  printf '%s\n' "${shell_dir}/scripts/lib/mascot-pack.py"
}

# Refresh an installed mascot pack during `./setup update`. Fresh installs
# remain opt-in: update only acts when art or a prior install marker exists.
# A matching tag is not enough; the installed count and aggregate tree hash
# must also match the recorded state, so deleted/corrupt files self-repair.
# Repo-link checkouts are maintained with inir-mascot/scripts/sync-shell.py.
extras_refresh_mascot_pack_on_update() {
  local shell_dir="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/inir"
  local dest="${shell_dir}/assets/images/mascot"
  local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/inir"
  local state_file="${state_dir}/mascot-pack-state.json"
  local legacy_marker="${state_dir}/mascot-pack-version"
  local helper
  helper="$(extras_mascot_helper)"

  [[ -d "${shell_dir}/.git" ]] && return 0
  [[ -x "$helper" || -f "$helper" ]] || return 0

  local count
  count=$(find "$dest" -maxdepth 1 -type f \( -name 'inir-mascot-*.png' -o -name 'inir-mascot-*.gif' \) 2>/dev/null | wc -l)
  if (( count <= 10 )) && [[ ! -f "$state_file" && ! -f "$legacy_marker" ]]; then
    return 0
  fi

  local latest
  latest="$(extras_mascot_latest_tag)"
  [[ -n "$latest" ]] || return 0

  if [[ -f "$state_file" ]]; then
    local state_json tree_json
    state_json="$(python3 "$helper" state "$state_file" 2>/dev/null || true)"
    tree_json="$(python3 "$helper" tree "$dest" 2>/dev/null || true)"
    if [[ -n "$state_json" && -n "$tree_json" ]] \
       && python3 - "$latest" "$state_json" "$tree_json" <<'PY'
import json, sys
latest, state_raw, tree_raw = sys.argv[1:]
state = json.loads(state_raw)
tree = json.loads(tree_raw)
raise SystemExit(0 if (
    state.get("tag") == latest
    and state.get("asset_count") == tree.get("asset_count")
    and state.get("asset_tree_sha256") == tree.get("asset_tree_sha256")
) else 1)
PY
    then
      return 0
    fi
  fi

  tui_info "Mascot pack: verifying release ${latest} and repairing the installed art"
  extras_install_mascot_pack "$latest"
}

# Optional mascot art pack: canonical art comes from snowarch/inir-mascot;
# manifest/dialogue/behavior stay in iNiR. Download and validation happen in a
# temporary staging directory. Only a complete verified tree is synchronized
# into the live runtime, preserving manifest.json and other shell-owned files.
extras_install_mascot_pack() {
  local requested_tag="${1:-}"
  local shell_dir="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/inir"
  local dest="${shell_dir}/assets/images/mascot"
  local helper
  helper="$(extras_mascot_helper)"
  local base_url
  base_url="$(extras_mascot_release_base_url)"
  local pack_url="${base_url}/inir-mascot-pack.tar.gz"
  local metadata_url="${base_url}/inir-mascot-pack.json"
  local checksum_url="${base_url}/inir-mascot-pack.sha256"

  tui_info "Optional mascot art pack: 354 poses/animations, ~32 MiB download."
  tui_dim "Downloads and verifies the complete pack before updating the live assets."

  if [[ ! -d "$shell_dir" ]]; then
    log_warning "iNiR shell dir not found at ${shell_dir}, skipping mascot pack"
    return 0
  fi
  if [[ ! -f "$helper" ]]; then
    log_warning "Mascot pack verifier missing at ${helper}, skipping"
    return 0
  fi
  mkdir -p "$dest"

  local tmp
  tmp="$(mktemp -d)"
  local archive="${tmp}/inir-mascot-pack.tar.gz"
  local metadata="${tmp}/inir-mascot-pack.json"
  local checksum="${tmp}/inir-mascot-pack.sha256"
  local stage="${tmp}/stage"
  local verified_json=""

  if ! curl -fsSL --retry 2 -o "$archive" "$pack_url"; then
    log_warning "Failed to download the mascot pack (network?), keeping current art"
    rm -rf "$tmp"
    return 0
  fi

  local metadata_arg=()
  if curl -fsSL --retry 1 -o "$metadata" "$metadata_url" 2>/dev/null; then
    metadata_arg=(--metadata "$metadata")
  elif curl -fsSL --retry 1 -o "$checksum" "$checksum_url" 2>/dev/null; then
    local expected actual
    expected="$(awk 'NR==1 {print $1}' "$checksum")"
    actual="$(sha256sum "$archive" | awk '{print $1}')"
    if [[ -z "$expected" || "$expected" != "$actual" ]]; then
      log_warning "Mascot pack checksum mismatch, keeping current art"
      rm -rf "$tmp"
      return 0
    fi
  fi

  verified_json="$(python3 "$helper" verify "$archive" "$stage" "${metadata_arg[@]}" 2>/dev/null || true)"
  if [[ -z "$verified_json" ]]; then
    log_warning "Mascot pack validation failed, keeping current art"
    rm -rf "$tmp"
    return 0
  fi

  if ! rsync -a --delay-updates --delete-delay \
      --include='inir-mascot-*.png' --include='inir-mascot-*.gif' --exclude='*' \
      "${stage}/" "${dest}/"; then
    log_warning "Failed to install the verified mascot pack, keeping the previous state marker"
    rm -rf "$tmp"
    return 0
  fi

  local installed_json
  installed_json="$(python3 "$helper" tree "$dest" 2>/dev/null || true)"
  if [[ -z "$installed_json" ]] \
     || ! python3 - "$verified_json" "$installed_json" <<'PY'
import json, sys
verified, installed = map(json.loads, sys.argv[1:])
raise SystemExit(0 if (
    verified.get("asset_count") == installed.get("asset_count")
    and verified.get("asset_tree_sha256") == installed.get("asset_tree_sha256")
) else 1)
PY
  then
    log_warning "Installed mascot tree did not match staging; it will be repaired on the next update"
    rm -rf "$tmp"
    return 0
  fi

  local tag
  tag="$requested_tag"
  [[ -n "$tag" ]] || tag="$(extras_mascot_latest_tag)"
  [[ -n "$tag" ]] || tag="unknown"

  local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/inir"
  local state_file="${state_dir}/mascot-pack-state.json"
  local legacy_marker="${state_dir}/mascot-pack-version"
  local count tree_hash archive_hash
  IFS=$'\t' read -r count tree_hash archive_hash < <(
    python3 - "$verified_json" <<'PY'
import json, sys
value = json.loads(sys.argv[1])
print(value["asset_count"], value["asset_tree_sha256"], value["archive_sha256"], sep="\t")
PY
  )
  python3 "$helper" write-state "$state_file" "$tag" "$count" "$tree_hash" "$archive_hash"
  rm -f "$legacy_marker"

  log_success "Mascot pack installed and verified (${count} assets in ${dest})"
  rm -rf "$tmp"
  return 0
}
