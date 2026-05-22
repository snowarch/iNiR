#!/usr/bin/env bash

MIGRATION_ID="025-sddm-dropin-rename"
MIGRATION_TITLE="Rename SDDM drop-in so we stop fighting other configs"
MIGRATION_DESCRIPTION="Pre-2.26 versions of iNiR shipped /etc/sddm.conf.d/inir-theme.conf and worked around the alphabetical merge order by silently sed -i'ing InputMethod=qtvirtualkeyboard out of foreign drop-ins like kde_settings.conf. That stomped on user/KDE settings every install/update. The new install uses /etc/sddm.conf.d/99-inir-theme.conf which sorts last alphabetically and wins by drop-in order, so iNiR no longer needs to touch foreign files. This migration renames the legacy drop-in for existing users."
MIGRATION_TARGET_FILE="/etc/sddm.conf.d/inir-theme.conf"
MIGRATION_REQUIRED=true

_sddm_legacy_path="/etc/sddm.conf.d/inir-theme.conf"
_sddm_new_path="/etc/sddm.conf.d/99-inir-theme.conf"

migration_check() {
  # Only applicable if SDDM is even installed and the legacy file exists.
  command -v sddm >/dev/null 2>&1 || return 1
  [[ -f "$_sddm_legacy_path" ]] || return 1
  # Skip if both files exist already (user manually fixed) — we'd rather not touch.
  [[ -f "$_sddm_new_path" ]] && return 1
  return 0
}

migration_preview() {
  echo -e "${STY_GREEN}+ ${_sddm_new_path}${STY_RST} (rename of legacy drop-in)"
  echo -e "${STY_RED}- ${_sddm_legacy_path}${STY_RST}"
  echo -e "${STY_FAINT}  The new name sorts after kde_settings.conf etc. so iNiR's settings"
  echo -e "  win without us having to delete InputMethod= lines from foreign files.${STY_RST}"
}

migration_apply() {
  # We cannot mv across owners without elevation; pkg_sudo is the project helper.
  if [[ ! -f "$_sddm_legacy_path" ]]; then
    return 0
  fi
  if [[ -f "$_sddm_new_path" ]]; then
    # Both exist — leave the legacy in place for the user to reconcile, don't auto-delete.
    return 0
  fi

  if command -v pkg_sudo >/dev/null 2>&1; then
    pkg_sudo mv -f "$_sddm_legacy_path" "$_sddm_new_path" 2>/dev/null || {
      echo -e "${STY_YELLOW}Could not rename SDDM drop-in (need root). Run manually:${STY_RST}"
      echo -e "  sudo mv ${_sddm_legacy_path} ${_sddm_new_path}"
      return 1
    }
  else
    sudo mv -f "$_sddm_legacy_path" "$_sddm_new_path" 2>/dev/null || {
      echo -e "${STY_YELLOW}Could not rename SDDM drop-in (need root). Run manually:${STY_RST}"
      echo -e "  sudo mv ${_sddm_legacy_path} ${_sddm_new_path}"
      return 1
    }
  fi
  return 0
}
