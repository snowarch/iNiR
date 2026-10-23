#!/usr/bin/env bash
# Migration 046: the desktop clock stops shipping at 58% strength.
#
# The factory clock carried dim 70 from when dim was a slight colour mix (22% at most). Dim became one opacity
# contract for every widget, so that 70 faded the clock to a ghost. Only the factory value goes; any other is a choice.

MIGRATION_ID="046-desktop-clock-full-strength"
MIGRATION_TITLE="Desktop clock at full strength"
MIGRATION_DESCRIPTION="The desktop clock came faded out of the box (Dimming 70, left over from an older meaning of the slider). It goes back to 0; a Dimming you picked yourself stays."
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
  jq -e '.background.widgets.clock.dim == 70' "$conf" >/dev/null 2>&1
}

migration_preview() {
  echo -e "${STY_RED}- background.widgets.clock.dim 70${STY_RST}"
  echo -e "${STY_GREEN}+ background.widgets.clock.dim 0${STY_RST}"
  echo ""
  echo "The desktop clock is drawn at full strength again."
}

migration_apply() {
  local conf tmp
  conf="$(_config_path)"
  [[ -f "$conf" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 1
  tmp="${conf}.migration-tmp.$$"
  jq '.background.widgets.clock.dim = 0' "$conf" > "$tmp" && mv "$tmp" "$conf"
}
