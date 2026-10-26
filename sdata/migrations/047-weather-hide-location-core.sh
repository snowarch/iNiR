#!/usr/bin/env bash
# Migration 047: hiding the weather's city is one choice for every family.
#
# It lived under waffles.widgetsPanel even though Material and iRiS honour it too, and a family can now be
# uninstalled. It moves to bar.weather.hideLocation next to the rest of the weather settings.

MIGRATION_ID="047-weather-hide-location-core"
MIGRATION_TITLE="Hidden weather city, for every family"
MIGRATION_DESCRIPTION="If you hid your city on the weather, it stays hidden: the switch moved from Waffle's settings to the shared weather ones."
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
  jq -e '.waffles.widgetsPanel | has("weatherHideLocation")' "$conf" >/dev/null 2>&1
}

migration_preview() {
  echo -e "${STY_RED}- waffles.widgetsPanel.weatherHideLocation${STY_RST}"
  echo -e "${STY_GREEN}+ bar.weather.hideLocation${STY_RST}"
  echo ""
  echo "A hidden city stays hidden in every family."
}

migration_apply() {
  local conf tmp
  conf="$(_config_path)"
  [[ -f "$conf" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 1
  tmp="${conf}.migration-tmp.$$"
  jq '(.waffles.widgetsPanel.weatherHideLocation == true) as $hidden
      | .bar.weather.hideLocation = ((.bar.weather.hideLocation // false) or $hidden)
      | del(.waffles.widgetsPanel.weatherHideLocation)' "$conf" > "$tmp" && mv "$tmp" "$conf"
}
