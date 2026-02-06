MIGRATION_ID="012-terminal-theming-omarchy-fix"
MIGRATION_TITLE="Fix Terminal Theming (Omarchy Conflicts)"
MIGRATION_DESCRIPTION="Removes conflicting omarchy theme imports from terminal configs so iNiR wallpaper theming works correctly for Foot, Ghostty, and Alacritty."
MIGRATION_TARGET_FILE="~/.config/{foot,ghostty,alacritty}/*"
MIGRATION_REQUIRED=false

migration_check() {
  local found=false
  
  if [[ -f ~/.config/ghostty/config ]] && grep -qi "omarchy" ~/.config/ghostty/config 2>/dev/null; then
    found=true
  fi
  
  if [[ -f ~/.config/alacritty/alacritty.toml ]] && grep -qi "omarchy" ~/.config/alacritty/alacritty.toml 2>/dev/null; then
    found=true
  fi
  
  if [[ -f ~/.config/foot/foot.ini ]] && grep -qi "omarchy" ~/.config/foot/foot.ini 2>/dev/null; then
    found=true
  fi
  
  [[ "$found" == "true" ]]
}

migration_preview() {
  echo -e "${STY_CYAN}This migration will:${STY_RST}"
  echo ""
  
  if [[ -f ~/.config/ghostty/config ]] && grep -qi "omarchy" ~/.config/ghostty/config 2>/dev/null; then
    echo -e "${STY_RED}- config-file = ~/.config/omarchy/current/theme/ghostty.conf${STY_RST}"
    echo -e "${STY_GREEN}+ (removed - using theme = ii-auto instead)${STY_RST}"
    echo ""
  fi
  
  if [[ -f ~/.config/alacritty/alacritty.toml ]] && grep -qi "omarchy" ~/.config/alacritty/alacritty.toml 2>/dev/null; then
    echo -e "${STY_RED}- import = [\"~/.config/omarchy/current/theme/alacritty.toml\"]${STY_RST}"
    echo -e "${STY_GREEN}+ import = [\"~/.config/alacritty/colors.toml\"]${STY_RST}"
    echo ""
  fi
  
  if [[ -f ~/.config/foot/foot.ini ]] && grep -qi "omarchy" ~/.config/foot/foot.ini 2>/dev/null; then
    echo -e "${STY_RED}- (omarchy references in foot.ini)${STY_RST}"
    echo -e "${STY_GREEN}+ (removed - using include=~/.config/foot/colors.ini)${STY_RST}"
  fi
}

migration_diff() {
  echo "Current omarchy references found:"
  echo ""
  
  [[ -f ~/.config/ghostty/config ]] && grep -i "omarchy" ~/.config/ghostty/config 2>/dev/null && echo ""
  [[ -f ~/.config/alacritty/alacritty.toml ]] && grep -i "omarchy" ~/.config/alacritty/alacritty.toml 2>/dev/null && echo ""
  [[ -f ~/.config/foot/foot.ini ]] && grep -i "omarchy" ~/.config/foot/foot.ini 2>/dev/null
  
  echo ""
  echo "After migration, terminal colors will be controlled by iNiR wallpaper theming."
}

migration_apply() {
  if ! migration_check; then
    return 0
  fi
  
  if [[ -f ~/.config/ghostty/config ]]; then
    sed -i '/omarchy/Id' ~/.config/ghostty/config
    if ! grep -q "theme = ii-auto" ~/.config/ghostty/config; then
      echo "theme = ii-auto" >> ~/.config/ghostty/config
    fi
  fi
  
  if [[ -f ~/.config/alacritty/alacritty.toml ]]; then
    sed -i 's|import\s*=\s*\[.*omarchy.*\]|general.import = [ "~/.config/alacritty/colors.toml" ]|Ig' ~/.config/alacritty/alacritty.toml
  fi
  
  if [[ -f ~/.config/foot/foot.ini ]]; then
    sed -i '/omarchy/Id' ~/.config/foot/foot.ini
    if ! grep -q "include=.*colors.ini" ~/.config/foot/foot.ini; then
      sed -i '1i include=~/.config/foot/colors.ini' ~/.config/foot/foot.ini
    fi
  fi
  
  ~/.config/quickshell/ii/scripts/colors/applycolor.sh &>/dev/null &
  
  echo "✓ Removed omarchy theme references, iNiR theming now active"
}
