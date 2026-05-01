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
  INIR_SDDM_AUTO_APPLY="$auto_apply_mode" bash "$sddm_script" || log_warning "ii-pixel-sddm setup had issues (non-fatal)"
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
  local walls_estimated_count=117
  local walls_estimated_bytes=582018131
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
