#!/usr/bin/env bash
# Migration: Remove the Reddit sidebar panel config.
#
# Reddit blocks unauthenticated API access (HTTP 403), and the OAuth-based
# alternative required every user to register their own app — too much friction.
# The panel was removed; this drops its now-orphan config key.

MIGRATION_ID="031-remove-reddit-panel"
MIGRATION_TITLE="Remove Reddit panel config"
MIGRATION_DESCRIPTION="Removes the orphan sidebar.reddit config key. The Reddit panel was
  removed because Reddit blocks unauthenticated access and the OAuth workaround
  required per-user app registration."
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

  # Needs migration if the orphan reddit key still exists under sidebar.
  jq -e 'has("sidebar") and (.sidebar | has("reddit"))' "$conf" >/dev/null 2>&1
}

migration_preview() {
  local conf
  conf="$(_config_path)"
  echo "Will remove the orphan Reddit config key from $conf:"
  echo ""
  echo -e "  ${STY_RED}- sidebar.reddit${STY_RST} (panel removed; key no longer read by the shell)"
  echo ""
  echo "No visual or behavioral change — the Reddit panel is already gone."
}

migration_diff() {
  local conf
  conf="$(_config_path)"
  echo "Key to remove:"
  jq -e '.sidebar.reddit' "$conf" >/dev/null 2>&1 \
    && echo "  sidebar.reddit (present)" \
    || echo "  (none found)"
}

migration_apply() {
  local conf
  conf="$(_config_path)"
  [[ -f "$conf" ]] || { echo "  Config file not found, skipping."; return 0; }

  local tmp="${conf}.migration-tmp"

  jq 'if .sidebar then del(.sidebar.reddit) else . end' "$conf" > "$tmp" && mv "$tmp" "$conf"
  echo "  Removed sidebar.reddit from config"
}
