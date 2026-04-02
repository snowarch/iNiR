#!/usr/bin/env bash

MIGRATION_ID="019-config-dir-rename-compat"
MIGRATION_TITLE="Config directory compatibility for ~/.config/inir"
MIGRATION_DESCRIPTION="Ensures config directory compatibility by linking legacy ~/.config/illogical-impulse to ~/.config/inir while preserving user data."
MIGRATION_TARGET_FILE="~/.config/inir"
MIGRATION_REQUIRED=true

migration_check() {
  local xdg_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local config_new="${xdg_config_home}/inir"
  local config_legacy="${xdg_config_home}/illogical-impulse"

  if [[ -L "$config_legacy" ]] && [[ "$(readlink "$config_legacy" 2>/dev/null || true)" == "$config_new" ]]; then
    return 1
  fi

  return 0
}

migration_preview() {
  local xdg_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  echo -e "${STY_YELLOW}~ create compatibility layout:${STY_RST}"
  echo "  - canonical: ${xdg_config_home}/inir"
  echo "  - legacy link: ${xdg_config_home}/illogical-impulse -> ${xdg_config_home}/inir"
}

migration_apply() {
  local xdg_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local config_new="${xdg_config_home}/inir"
  local config_legacy="${xdg_config_home}/illogical-impulse"

  mkdir -p "$xdg_config_home"

  if [[ -L "$config_legacy" ]]; then
    local target
    target="$(readlink "$config_legacy" 2>/dev/null || true)"
    if [[ "$target" == "$config_new" ]]; then
      mkdir -p "$config_new"
      return 0
    fi
    rm -f "$config_legacy"
  fi

  if [[ -d "$config_legacy" && ! -d "$config_new" ]]; then
    mv "$config_legacy" "$config_new"
    ln -s "$config_new" "$config_legacy"
    return 0
  fi

  if [[ -d "$config_legacy" && -d "$config_new" ]]; then
    cp -an "$config_legacy/." "$config_new/" 2>/dev/null || true
    rm -rf "$config_legacy"
    ln -s "$config_new" "$config_legacy"
    return 0
  fi

  mkdir -p "$config_new"
  if [[ ! -e "$config_legacy" ]]; then
    ln -s "$config_new" "$config_legacy"
  fi
}
