#!/usr/bin/env bash
# Migration: Point Mod+Shift+S at the annotation editor.
# The region screenshot bind now opens the capture in the annotation editor
# (crop + draw before saving) instead of copying immediately. Niri only, and
# only when the bind is still the unmodified iNiR default.

MIGRATION_ID="035-screenshot-edit-keybind"
MIGRATION_TITLE="Screenshot & annotate keybind"
MIGRATION_DESCRIPTION="Rebinds Mod+Shift+S from an instant region screenshot to the
  annotation editor (crop and draw before saving). Skipped if the bind was customized."
MIGRATION_TARGET_FILE="~/.config/niri/config.d/70-binds.kdl"
MIGRATION_REQUIRED=false

migration_check() {
  local binds_file="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.d/70-binds.kdl"
  [[ -f "$binds_file" ]] || return 1
  grep -qF 'Mod+Shift+S { spawn "inir" "region" "screenshot"; }' "$binds_file" 2>/dev/null
}

migration_preview() {
  echo -e "In 70-binds.kdl:"
  echo -e "${STY_RED}- Mod+Shift+S { spawn \"inir\" \"region\" \"screenshot\"; }${STY_RST}"
  echo -e "${STY_GREEN}+ Mod+Shift+S { spawn \"inir\" \"region\" \"screenshotEdit\"; }${STY_RST}"
}

migration_apply() {
  migration_check || return 0
  local binds_file="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.d/70-binds.kdl"
  sed -i 's|Mod+Shift+S { spawn "inir" "region" "screenshot"; }|Mod+Shift+S { spawn "inir" "region" "screenshotEdit"; }|' "$binds_file"
}
