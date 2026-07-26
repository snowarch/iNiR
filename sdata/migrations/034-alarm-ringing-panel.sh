#!/usr/bin/env bash
# Migration: Enable the alarm ringing panel for existing users.
#
# The alarm feature ships iiAlarmRinging in the enabledPanels default, but a
# config that already stores its own enabledPanels array replaces that default
# wholesale — it does not merge. Upgrading users would get alarms that fire and
# play audio with no ringing surface on screen. This appends the identifier to
# an existing array only; a config without the key keeps inheriting the default.

MIGRATION_ID="034-alarm-ringing-panel"
MIGRATION_TITLE="Enable the alarm ringing panel"
MIGRATION_DESCRIPTION="Appends iiAlarmRinging to a stored enabledPanels array. A saved panel list
  overrides the shipped default instead of merging with it, so without this the
  alarm would ring with nothing shown on screen."
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

# True only when the key exists as an array and lacks the identifier. A config
# with no enabledPanels key inherits the new default and is left alone.
_needs_panel() {
  jq -e '(.enabledPanels | type) == "array"
    and ((.enabledPanels | index("iiAlarmRinging")) == null)' "$1" >/dev/null 2>&1
}

migration_check() {
  local conf
  conf="$(_config_path)"
  [[ -f "$conf" ]] || return 1

  _needs_panel "$conf"
}

migration_preview() {
  local conf
  conf="$(_config_path)"
  echo "Will add the alarm ringing panel to $conf:"
  echo ""
  echo -e "  ${STY_GREEN}+ enabledPanels: \"iiAlarmRinging\"${STY_RST} (ringing screen for a firing alarm)"
  echo ""
  echo "No other panel is touched and the existing order is kept."
}

migration_diff() {
  local conf
  conf="$(_config_path)"
  echo "Current enabledPanels:"
  jq -r '.enabledPanels // "(absent — inherits the default)"' "$conf" 2>/dev/null \
    || echo "  (unreadable)"
}

migration_apply() {
  local conf
  conf="$(_config_path)"
  [[ -f "$conf" ]] || { echo "  Config file not found, skipping."; return 0; }

  # Leave the file completely alone unless it stores its own panel list and is
  # missing the identifier — an absent key must keep inheriting the default,
  # and an unparseable config must not be rewritten.
  _needs_panel "$conf" || {
    echo "  enabledPanels absent or already lists iiAlarmRinging, nothing to do."
    return 0
  }

  local tmp="${conf}.migration-tmp"

  # Append-if-absent: re-running is a no-op once the identifier is present, and
  # a missing or non-array enabledPanels falls through untouched.
  # --indent 4 matches the shell's own writer (JSON.stringify(obj, null, 4)),
  # so the rewrite is a one-line diff instead of a whole-file reindent.
  if jq --indent 4 '
    if (.enabledPanels | type) == "array"
       and ((.enabledPanels | index("iiAlarmRinging")) == null)
    then .enabledPanels += ["iiAlarmRinging"]
    else . end
  ' "$conf" > "$tmp"; then
    mv "$tmp" "$conf"
    echo "  Added iiAlarmRinging to enabledPanels"
  else
    rm -f "$tmp"
    echo "  Config not readable as JSON, left unchanged."
  fi
}
