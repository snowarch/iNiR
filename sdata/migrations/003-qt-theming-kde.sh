# Migration: Update Qt theming from gtk3 to kde
# Enables proper Qt app theming via kdeglobals

MIGRATION_ID="003-qt-theming-kde"
MIGRATION_TITLE="Qt Theming via KDE"
MIGRATION_DESCRIPTION="Changes QT_QPA_PLATFORMTHEME from 'gtk3' to 'kde'.
  This enables ii-niri to theme Qt applications (Dolphin, Kate, etc.)
  using kdeglobals color schemes for consistent Material You theming."
MIGRATION_TARGET_FILE="~/.config/niri/config.kdl"
MIGRATION_REQUIRED=false

migration_check() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
  [[ -f "$config" ]] && grep -q 'QT_QPA_PLATFORMTHEME "gtk3"' "$config"
}

migration_preview() {
  echo -e "${STY_RED}- QT_QPA_PLATFORMTHEME \"gtk3\"${STY_RST}"
  echo -e "${STY_GREEN}+ QT_QPA_PLATFORMTHEME \"kde\"${STY_RST}"
  echo -e "${STY_GREEN}+ QT_STYLE_OVERRIDE \"Breeze\"${STY_RST}"
}

migration_diff() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
  echo "Current:"
  grep "QT_QPA_PLATFORMTHEME" "$config" 2>/dev/null || echo "  (not set)"
  echo ""
  echo "After migration:"
  echo "  QT_QPA_PLATFORMTHEME \"kde\""
  echo "  QT_STYLE_OVERRIDE \"Breeze\""
}

migration_apply() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
  
  if ! migration_check; then
    return 0
  fi
  
  # Change gtk3 to kde
  sed -i 's/QT_QPA_PLATFORMTHEME "gtk3"/QT_QPA_PLATFORMTHEME "kde"/' "$config"
  
  # Remove QT_QPA_PLATFORMTHEME_QT6 if present (not needed with kde)
  sed -i '/QT_QPA_PLATFORMTHEME_QT6/d' "$config"
  
  # Add QT_STYLE_OVERRIDE if not present
  if ! grep -q 'QT_STYLE_OVERRIDE' "$config"; then
    sed -i '/QT_QPA_PLATFORMTHEME/a\    QT_STYLE_OVERRIDE "Breeze"' "$config"
  fi
}
