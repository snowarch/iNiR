# Migration: Install plasma-integration and switch QT_QPA_PLATFORMTHEME to kde
# Fixes black text on dark backgrounds in Dolphin and other Qt/KDE apps.
# Root cause: qt6ct platform theme doesn't properly pass kdeglobals colors to Darkly style.
# plasma-integration provides the kde QPA plugin that reads kdeglobals directly.

MIGRATION_ID="011-plasma-integration-qt-theming"
MIGRATION_TITLE="Qt theming: plasma-integration"
MIGRATION_DESCRIPTION="Installs plasma-integration and switches QT_QPA_PLATFORMTHEME from qt6ct to kde.
  This fixes black/unreadable text in Dolphin and other Qt apps by enabling direct
  kdeglobals color reading for the Darkly style."
MIGRATION_TARGET_FILE="~/.config/niri/config.kdl"
MIGRATION_REQUIRED=true

migration_check() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
  [[ -f "$config" ]] || return 1

  # Needs migration if niri config still has qt6ct
  grep -q 'QT_QPA_PLATFORMTHEME "qt6ct"' "$config"
}

migration_preview() {
  echo -e "${STY_YELLOW}  Package: plasma-integration (provides kde QPA platform theme plugin)${STY_RST}"
  echo ""
  echo -e "${STY_RED}- QT_QPA_PLATFORMTHEME \"qt6ct\"${STY_RST}"
  echo -e "${STY_GREEN}+ QT_QPA_PLATFORMTHEME \"kde\"${STY_RST}"
  echo ""
  echo "  This enables Qt apps to read Material You colors from kdeglobals"
  echo "  via the Darkly style, fixing black text on dark backgrounds."
}

migration_diff() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
  echo "Current Qt platform theme:"
  grep 'QT_QPA_PLATFORMTHEME' "$config" 2>/dev/null | head -2
  echo ""
  echo "After migration: QT_QPA_PLATFORMTHEME \"kde\" + plasma-integration installed"
}

migration_apply() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"

  if ! migration_check; then
    return 0
  fi

  # Install plasma-integration if on Arch and not already installed
  if command -v pacman &>/dev/null; then
    if ! pacman -Q plasma-integration &>/dev/null 2>&1; then
      echo "Installing plasma-integration..."
      sudo pacman -S --needed --noconfirm plasma-integration 2>/dev/null || {
        echo -e "${STY_YELLOW}Could not auto-install plasma-integration.${STY_RST}"
        echo -e "${STY_YELLOW}Install manually: sudo pacman -S plasma-integration${STY_RST}"
        # Don't patch niri config if package install failed
        return 1
      }
    fi
  elif command -v apt &>/dev/null; then
    if ! dpkg -l plasma-integration 2>/dev/null | grep -q '^inir'; then
      echo "Installing plasma-integration..."
      sudo apt install -y plasma-integration 2>/dev/null || {
        echo -e "${STY_YELLOW}Could not auto-install plasma-integration.${STY_RST}"
        echo -e "${STY_YELLOW}Install manually: sudo apt install plasma-integration${STY_RST}"
        return 1
      }
    fi
  elif command -v dnf &>/dev/null; then
    if ! rpm -q plasma-integration &>/dev/null 2>&1; then
      echo "Installing plasma-integration..."
      sudo dnf install -y plasma-integration 2>/dev/null || {
        echo -e "${STY_YELLOW}Could not auto-install plasma-integration.${STY_RST}"
        echo -e "${STY_YELLOW}Install manually: sudo dnf install plasma-integration${STY_RST}"
        return 1
      }
    fi
  fi

  # Verify the kde platform plugin actually exists before switching
  local plugin_found=false
  for plugindir in /usr/lib/qt6/plugins/platformthemes /usr/lib64/qt6/plugins/platformthemes \
                   /usr/lib/x86_64-linux-gnu/qt6/plugins/platformthemes; do
    if [[ -f "${plugindir}/KDEPlasmaPlatformTheme6.so" ]]; then
      plugin_found=true
      break
    fi
  done

  if ! $plugin_found; then
    echo -e "${STY_YELLOW}Warning: KDEPlasmaPlatformTheme6.so not found after install.${STY_RST}"
    echo -e "${STY_YELLOW}Keeping qt6ct as fallback. Install plasma-integration manually.${STY_RST}"
    return 1
  fi

  # Patch niri config: qt6ct -> kde
  sed -i 's/QT_QPA_PLATFORMTHEME "qt6ct"/QT_QPA_PLATFORMTHEME "kde"/' "$config"
}
