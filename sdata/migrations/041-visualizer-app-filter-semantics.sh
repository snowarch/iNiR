#!/usr/bin/env bash
# Migration 041: make Visualizer App Filters an exclusion list as originally
# advertised, instead of the accidentally-shipped allowlist semantics.

MIGRATION_ID="041-visualizer-app-filter-semantics"
MIGRATION_TITLE="Fix visualizer app filter semantics"
MIGRATION_DESCRIPTION="Visualizer App Filters now exclude selected applications, matching Notifications and the v2.30 changelog. Existing selected apps are preserved as blocked visualizer sources."
MIGRATION_TARGET_FILE="~/.config/inir/config.json"
MIGRATION_REQUIRED=true

_config_path() {
  local xdg_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local config_new="${xdg_config_home}/inir/config.json"
  local config_legacy="${xdg_config_home}/illogical-impulse/config.json"
  if [[ -f "$config_legacy" ]]; then
    printf '%s\n' "$config_legacy"
    return
  fi
  printf '%s\n' "$config_new"
}

migration_check() {
  local conf
  conf="$(_config_path)"
  [[ -f "$conf" ]] || return 1
  jq -e '.appearance.cava | has("allowedApps")' "$conf" >/dev/null 2>&1
}

migration_preview() {
  local conf
  conf="$(_config_path)"
  echo "Visualizer filters in $conf will switch to exclusion semantics:"
  echo ""
  echo "  appearance.cava.allowedApps -> appearance.cava.blockedApps"
  echo "  Existing selected apps stay selected, but are now excluded from Cava."
}

migration_apply() {
  local conf tmp
  conf="$(_config_path)"
  [[ -f "$conf" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 1

  tmp="${conf}.migration-tmp.$$"
  jq '
    (.appearance.cava.blockedApps // []) as $blocked
    | (.appearance.cava.allowedApps // []) as $legacy
    | .appearance.cava.blockedApps = (($blocked + $legacy) | unique)
    | del(.appearance.cava.allowedApps)
  ' "$conf" > "$tmp" && mv "$tmp" "$conf"
}
