# Migration: Add XDG_MENU_PREFIX for Dolphin file associations
# Fixes "Open With" menu in Dolphin

MIGRATION_ID="005-dolphin-xdg-menu"
MIGRATION_TITLE="Dolphin File Associations"
MIGRATION_DESCRIPTION="Adds XDG_MENU_PREFIX environment variable for Dolphin.
  This fixes the 'Open With' menu showing applications correctly."
MIGRATION_TARGET_FILE="~/.config/niri/config.kdl"
MIGRATION_REQUIRED=false

migration_check() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
  [[ -f "$config" ]] && ! grep -q 'XDG_MENU_PREFIX "plasma-"' "$config"
}

migration_preview() {
  echo -e "${STY_GREEN}+ XDG_MENU_PREFIX \"plasma-\"${STY_RST} (in environment block)"
  echo -e "${STY_GREEN}+ spawn-at-startup for systemctl import-environment${STY_RST}"
}

migration_diff() {
  cat << 'DIFF'
Will add to environment block:
  XDG_MENU_PREFIX "plasma-"

Will add spawn-at-startup:
  spawn-at-startup "bash" "-c" "systemctl --user import-environment XDG_MENU_PREFIX && kbuildsycoca6"
DIFF
}

migration_apply() {
  local config="${XDG_CONFIG_HOME}/niri/config.kdl"
  
  if ! migration_check; then
    return 0
  fi
  
  # Add XDG_MENU_PREFIX after XDG_CURRENT_DESKTOP
  if grep -q 'XDG_CURRENT_DESKTOP' "$config"; then
    sed -i '/XDG_CURRENT_DESKTOP/a\    XDG_MENU_PREFIX "plasma-"  // Required for Dolphin file associations' "$config"
  fi
  
  # Add spawn-at-startup for systemctl import-environment
  if ! grep -q 'import-environment XDG_MENU_PREFIX' "$config"; then
    if grep -q 'spawn-at-startup' "$config"; then
      sed -i '0,/spawn-at-startup/s//spawn-at-startup "bash" "-c" "systemctl --user import-environment XDG_MENU_PREFIX \&\& kbuildsycoca6"\n\nspawn-at-startup/' "$config"
    fi
  fi
}
