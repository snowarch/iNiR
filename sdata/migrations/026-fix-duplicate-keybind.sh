#!/usr/bin/env bash
# Migration: Fix duplicate Mod+Shift+L keybind in niri config
# The lock focus workaround (Mod+Shift+L allow-when-locked) conflicts with
# move-column-right (Mod+Shift+L) — niri rejects duplicate keybinds.
# Fix: change lock focus to Mod+Ctrl+Shift+L.

MIGRATION_ID="026-fix-duplicate-keybind"
MIGRATION_TITLE="Fix duplicate Mod+Shift+L keybind"
MIGRATION_DESCRIPTION="Moves lock focus workaround from Mod+Shift+L to Mod+Ctrl+Shift+L to avoid conflict with move-column-right."
MIGRATION_REQUIRED=true

migration_check() {
  local binds_file="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.d/70-binds.kdl"
  [[ -f "$binds_file" ]] || return 1

  # Check if the file has the conflicting pattern:
  # Mod+Shift+L allow-when-locked (the lock focus line)
  if grep -q 'Mod+Shift+L.*allow-when-locked.*lock.*focus' "$binds_file" 2>/dev/null; then
    return 0
  fi
  return 1
}

migration_apply() {
  local binds_file="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.d/70-binds.kdl"
  [[ -f "$binds_file" ]] || return 0

  # Replace Mod+Shift+L allow-when-locked with Mod+Ctrl+Shift+L allow-when-locked
  sed -i 's/Mod+Shift+L\(\s\+allow-when-locked=true\s*{.*lock.*focus\)/Mod+Ctrl+Shift+L\1/' "$binds_file"
}

migration_preview() {
  echo "In 70-binds.kdl:"
  echo "  - Mod+Shift+L allow-when-locked=true { spawn \"inir\" \"lock\" \"focus\"; }"
  echo "  + Mod+Ctrl+Shift+L allow-when-locked=true { spawn \"inir\" \"lock\" \"focus\"; }"
}
