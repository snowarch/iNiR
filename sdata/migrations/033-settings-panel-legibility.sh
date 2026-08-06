#!/usr/bin/env bash
# Migration: Repair the Settings overlay background contract.
#
# Two orphans in settingsUi.overlayAppearance:
#
#   enableBlur — shipped as "Enhanced blur (aurora/angel only)" but never had
#   a consumer anywhere in the shell. The toggle did nothing in any style.
#
#   backgroundOpacity — the control bottomed out at 20%. The panel is a single
#   surface and the cards on it carry the reading contrast, so below 60% the
#   solid styles put a sharp wallpaper straight behind the text and aurora thins
#   to a bare 64 px blur. Both settings hosts clamp on read, so this only
#   realigns the stored value with what the panel actually renders.

MIGRATION_ID="033-settings-panel-legibility"
MIGRATION_TITLE="Repair Settings panel background options"
MIGRATION_DESCRIPTION="Drops the orphan settingsUi.overlayAppearance.enableBlur key, which never
  had a consumer, and lifts a stored panel opacity below 60% to the new floor.
  Below that the Settings panel stopped being readable over a wallpaper."
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

  # Needs migration while either the orphan key is present or a stored
  # opacity still sits below the floor.
  jq -e '
    (.settingsUi.overlayAppearance // {}) as $a
    | ($a | has("enableBlur"))
      or (($a.backgroundOpacity // 1) < 0.6)
  ' "$conf" >/dev/null 2>&1
}

migration_preview() {
  local conf current
  conf="$(_config_path)"
  echo "Will repair settingsUi.overlayAppearance in $conf:"
  echo ""

  if jq -e '.settingsUi.overlayAppearance | has("enableBlur")' "$conf" >/dev/null 2>&1; then
    echo -e "  ${STY_RED}- enableBlur${STY_RST} (never read by the shell)"
  fi

  if jq -e '(.settingsUi.overlayAppearance.backgroundOpacity // 1) < 0.6' "$conf" >/dev/null 2>&1; then
    current="$(jq -r '.settingsUi.overlayAppearance.backgroundOpacity // 1' "$conf" 2>/dev/null)"
    echo -e "  ${STY_YLW}~ backgroundOpacity${STY_RST} ${current} -> 0.6 (legibility floor)"
  fi

  echo ""
  echo "The Settings panel keeps a readable background over any wallpaper."
}

migration_diff() {
  local conf
  conf="$(_config_path)"
  echo "Current settingsUi.overlayAppearance:"
  jq -r '.settingsUi.overlayAppearance // "(absent)"' "$conf" 2>/dev/null \
    || echo "  (unreadable)"
}

migration_apply() {
  local conf
  conf="$(_config_path)"
  [[ -f "$conf" ]] || { echo "  Config file not found, skipping."; return 0; }

  local tmp="${conf}.migration-tmp"

  jq '
    if .settingsUi.overlayAppearance then
      .settingsUi.overlayAppearance |= (
        del(.enableBlur)
        | if (.backgroundOpacity // 1) < 0.6 then .backgroundOpacity = 0.6 else . end
      )
    else . end
  ' "$conf" > "$tmp" && mv "$tmp" "$conf"

  echo "  Repaired settingsUi.overlayAppearance"
}
