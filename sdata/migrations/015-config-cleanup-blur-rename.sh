#!/usr/bin/env bash
# Migration: Clean orphan config keys and rename videoBlurStrength
#
# Removes deprecated blurStatic keys (blur now only activates with windows)
# and renames videoBlurStrength → thumbnailBlurStrength preserving user value.

MIGRATION_ID="015-config-cleanup-blur-rename"
MIGRATION_TITLE="Clean deprecated blur config keys"
MIGRATION_DESCRIPTION="Removes blurStatic (replaced by windows-only blur) and renames
  videoBlurStrength → thumbnailBlurStrength in user config.
  Old values are preserved where applicable."
MIGRATION_TARGET_FILE="~/.config/inir/config.json"
MIGRATION_REQUIRED=true

_config_path() {
  local xdg_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local config_new="${xdg_config_home}/inir/config.json"
  local config_legacy="${xdg_config_home}/illogical-impulse/config.json"

  if [[ -f "$config_legacy" ]]; then
    echo "$config_legacy"
    return
  fi

  echo "$config_new"
}

migration_check() {
  local conf
  conf="$(_config_path)"
  [[ -f "$conf" ]] || return 1

  # Needs migration if any orphan key exists
  local needs=false
  grep -q '"blurStatic"' "$conf" 2>/dev/null && needs=true
  grep -q '"videoBlurStrength"' "$conf" 2>/dev/null && needs=true
  $needs
}

migration_preview() {
  local conf
  conf="$(_config_path)"
  echo "Will clean deprecated config keys from $conf:"
  echo ""
  if grep -q '"blurStatic"' "$conf" 2>/dev/null; then
    echo -e "  ${STY_RED}- background.effects.blurStatic${STY_RST} (removed: blur now only activates with windows)"
    echo -e "  ${STY_RED}- waffles.background.effects.blurStatic${STY_RST} (if present)"
  fi
  if grep -q '"videoBlurStrength"' "$conf" 2>/dev/null; then
    echo -e "  ${STY_YELLOW}~ background.effects.videoBlurStrength → thumbnailBlurStrength${STY_RST} (renamed, value preserved)"
  fi
  echo ""
  echo "No visual or behavioral change — these keys are already unused by the shell."
}

migration_diff() {
  local conf
  conf="$(_config_path)"
  echo "Keys to remove/rename:"
  grep -n '"blurStatic"\|"videoBlurStrength"' "$conf" 2>/dev/null || echo "  (none found)"
}

migration_apply() {
  local conf
  conf="$(_config_path)"
  [[ -f "$conf" ]] || { echo "  Config file not found, skipping."; return 0; }

  local tmp="${conf}.migration-tmp"

  # 1. Rename videoBlurStrength → thumbnailBlurStrength (preserve user value)
  if grep -q '"videoBlurStrength"' "$conf" 2>/dev/null; then
    # Only rename if thumbnailBlurStrength doesn't already exist
    if ! grep -q '"thumbnailBlurStrength"' "$conf" 2>/dev/null; then
      jq '
        if .background.effects.videoBlurStrength then
          .background.effects.thumbnailBlurStrength = .background.effects.videoBlurStrength
        else . end
      ' "$conf" > "$tmp" && mv "$tmp" "$conf"
      echo "  Renamed videoBlurStrength → thumbnailBlurStrength"
    fi
  fi

  # 2. Remove all blurStatic and videoBlurStrength orphan keys
  jq '
    del(.background.effects.blurStatic) |
    del(.background.effects.videoBlurStrength) |
    if .waffles.background.effects.blurStatic then
      del(.waffles.background.effects.blurStatic)
    else . end
  ' "$conf" > "$tmp" && mv "$tmp" "$conf"
  echo "  Removed deprecated blur keys from config"
}
