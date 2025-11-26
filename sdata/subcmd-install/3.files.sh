# Config file installation for ii-niri
# This script is meant to be sourced.

# shellcheck shell=bash

printf "${STY_CYAN}[$0]: 3. Copying config files${STY_RST}\n"

#####################################################################################
# Ensure directories exist
#####################################################################################
for dir in "$XDG_BIN_HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"; do
  if ! test -e "$dir"; then
    v mkdir -p "$dir"
  fi
done

# Create quickshell state directories
v mkdir -p "${XDG_STATE_HOME}/quickshell/user/generated/wallpaper"
v mkdir -p "${XDG_CACHE_HOME}/quickshell"

#####################################################################################
# Determine first run
#####################################################################################
case "${INSTALL_FIRSTRUN}" in
  true) sleep 0 ;;
  *)
    if test -f "${FIRSTRUN_FILE}"; then
      INSTALL_FIRSTRUN=false
    else
      INSTALL_FIRSTRUN=true
    fi
    ;;
esac

#####################################################################################
# Backup existing configs
#####################################################################################
function auto_backup_configs(){
  local backup=false
  case $ask in
    false) if [[ ! -d "$BACKUP_DIR" ]]; then local backup=true;fi;;
    *)
      printf "${STY_YELLOW}"
      printf "Would you like to backup existing configs to \"$BACKUP_DIR\"?\n"
      printf "${STY_RST}"
      while true;do
        echo "  y = Yes, backup"
        echo "  n = No, skip"
        local p; read -p "====> " p
        case $p in
          [yY]) local backup=true;break ;;
          [nN]) local backup=false;break ;;
          *) echo -e "${STY_RED}Please enter [y/n].${STY_RST}";;
        esac
      done
      ;;
  esac
  if $backup;then
    backup_clashing_targets dots/.config $XDG_CONFIG_HOME "${BACKUP_DIR}/.config"
    printf "${STY_BLUE}Backup finished: ${BACKUP_DIR}${STY_RST}\n"
  fi
}

if [[ ! "${SKIP_BACKUP}" == true ]]; then auto_backup_configs; fi

#####################################################################################
# Install Quickshell config (ii)
#####################################################################################
case "${SKIP_QUICKSHELL}" in
  true) sleep 0;;
  *)
    echo -e "${STY_CYAN}Installing Quickshell ii config...${STY_RST}"
    
    # The ii QML code is in the root of this repo, not in dots/
    # We copy it to ~/.config/quickshell/ii/
    II_SOURCE="${REPO_ROOT}"
    II_TARGET="${XDG_CONFIG_HOME}/quickshell/ii"
    
    # Files/dirs to copy (QML code and assets)
    QML_ITEMS=(
      shell.qml
      GlobalStates.qml
      ReloadPopup.qml
      NiriConfigPopup.qml
      killDialog.qml
      settings.qml
      welcome.qml
      modules
      services
      scripts
      assets
      translations
      requirements.txt
    )
    
    v mkdir -p "$II_TARGET"
    
    for item in "${QML_ITEMS[@]}"; do
      if [[ -d "${II_SOURCE}/${item}" ]]; then
        install_dir__sync "${II_SOURCE}/${item}" "${II_TARGET}/${item}"
      elif [[ -f "${II_SOURCE}/${item}" ]]; then
        install_file "${II_SOURCE}/${item}" "${II_TARGET}/${item}"
      fi
    done
    
    log_success "Quickshell ii config installed"
    ;;
esac

#####################################################################################
# Install config files from dots/
#####################################################################################
echo -e "${STY_CYAN}Installing config files from dots/...${STY_RST}"

# Niri config
case "${SKIP_NIRI}" in
  true) sleep 0;;
  *)
    if [[ -f "defaults/niri/config.kdl" ]]; then
      install_file__auto_backup "defaults/niri/config.kdl" "${XDG_CONFIG_HOME}/niri/config.kdl"
      log_success "Niri config installed (defaults)"
    elif [[ -d "dots/.config/niri" ]]; then
      install_file__auto_backup "dots/.config/niri/config.kdl" "${XDG_CONFIG_HOME}/niri/config.kdl"
      log_success "Niri config installed (dots)"
    fi
    ;;
esac

# Matugen (theming)
if [[ -d "dots/.config/matugen" ]]; then
  install_dir__sync "dots/.config/matugen" "${XDG_CONFIG_HOME}/matugen"
  log_success "Matugen config installed"
fi

# Fuzzel (launcher)
if [[ -d "dots/.config/fuzzel" ]]; then
  install_dir__sync "dots/.config/fuzzel" "${XDG_CONFIG_HOME}/fuzzel"
  log_success "Fuzzel config installed"
fi

# GTK settings
for gtkver in gtk-3.0 gtk-4.0; do
  if [[ -d "dots/.config/${gtkver}" ]]; then
    install_dir "dots/.config/${gtkver}" "${XDG_CONFIG_HOME}/${gtkver}"
  fi
done

# KDE settings (for Dolphin and Qt apps)
if [[ -f "defaults/kde/kdeglobals" ]]; then
  install_file__auto_backup "defaults/kde/kdeglobals" "${XDG_CONFIG_HOME}/kdeglobals"
elif [[ -f "dots/.config/kdeglobals" ]]; then
  install_file__auto_backup "dots/.config/kdeglobals" "${XDG_CONFIG_HOME}/kdeglobals"
fi
if [[ -f "defaults/kde/dolphinrc" ]]; then
  install_file__auto_backup "defaults/kde/dolphinrc" "${XDG_CONFIG_HOME}/dolphinrc"
elif [[ -f "dots/.config/dolphinrc" ]]; then
  install_file__auto_backup "dots/.config/dolphinrc" "${XDG_CONFIG_HOME}/dolphinrc"
fi

# Kvantum (Qt theming)
if [[ -d "dots/.config/Kvantum" ]]; then
  install_dir "dots/.config/Kvantum" "${XDG_CONFIG_HOME}/Kvantum"
fi

# Copy Colloid theme to user Kvantum folder if installed
if [[ -d "/usr/share/Kvantum/Colloid" ]]; then
  echo -e "${STY_CYAN}Setting up Kvantum Colloid theme...${STY_RST}"
  mkdir -p "${XDG_CONFIG_HOME}/Kvantum/Colloid"
  cp -r /usr/share/Kvantum/Colloid/* "${XDG_CONFIG_HOME}/Kvantum/Colloid/"
  log_success "Kvantum Colloid theme configured"
fi

# Setup MaterialAdw folder for dynamic theming
mkdir -p "${XDG_CONFIG_HOME}/Kvantum/MaterialAdw"
if [[ -f "${XDG_CONFIG_HOME}/Kvantum/Colloid/ColloidDark.kvconfig" ]]; then
  cp "${XDG_CONFIG_HOME}/Kvantum/Colloid/ColloidDark.kvconfig" "${XDG_CONFIG_HOME}/Kvantum/MaterialAdw/MaterialAdw.kvconfig"
fi

# Fontconfig
if [[ -d "dots/.config/fontconfig" ]]; then
  install_dir__sync "dots/.config/fontconfig" "${XDG_CONFIG_HOME}/fontconfig"
fi

# illogical-impulse config.json
if [[ -f "dots/.config/illogical-impulse/config.json" ]]; then
  install_file__auto_backup "dots/.config/illogical-impulse/config.json" "${XDG_CONFIG_HOME}/illogical-impulse/config.json"
elif [[ -f "defaults/config.json" ]]; then
  # Fallback to defaults
  v mkdir -p "${XDG_CONFIG_HOME}/illogical-impulse"
  install_file__auto_backup "defaults/config.json" "${XDG_CONFIG_HOME}/illogical-impulse/config.json"
fi

#####################################################################################
# Mark first run complete
#####################################################################################
function gen_firstrun(){
  x mkdir -p "$(dirname ${FIRSTRUN_FILE})"
  x touch "${FIRSTRUN_FILE}"
  x mkdir -p "$(dirname ${INSTALLED_LISTFILE})"
  realpath -se "${FIRSTRUN_FILE}" >> "${INSTALLED_LISTFILE}"
}

v gen_firstrun
v dedup_and_sort_listfile "${INSTALLED_LISTFILE}" "${INSTALLED_LISTFILE}"

#####################################################################################
# Setup environment variables for all shells
#####################################################################################
echo -e "${STY_CYAN}Setting up environment variables...${STY_RST}"

# Create POSIX shell profile snippet (bash, zsh, sh)
II_ENV_FILE="${XDG_CONFIG_HOME}/ii-niri-env.sh"
cat > "${II_ENV_FILE}" << 'ENVEOF'
# ii-niri environment variables
export ILLOGICAL_IMPULSE_VIRTUAL_ENV="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/.venv"

# Qt theming (optional)
# export QT_STYLE_OVERRIDE=kvantum
# export QT_QPA_PLATFORMTHEME=kde
ENVEOF

# Auto-add to bash
if [[ -f "$HOME/.bashrc" ]]; then
  if ! grep -q "ii-niri-env.sh" "$HOME/.bashrc" 2>/dev/null; then
    echo "" >> "$HOME/.bashrc"
    echo "# ii-niri environment" >> "$HOME/.bashrc"
    echo "[ -f \"\${XDG_CONFIG_HOME:-\$HOME/.config}/ii-niri-env.sh\" ] && source \"\${XDG_CONFIG_HOME:-\$HOME/.config}/ii-niri-env.sh\"" >> "$HOME/.bashrc"
    log_success "Bash environment configured"
  fi
fi

# Auto-add to zsh
if [[ -f "$HOME/.zshrc" ]]; then
  if ! grep -q "ii-niri-env.sh" "$HOME/.zshrc" 2>/dev/null; then
    echo "" >> "$HOME/.zshrc"
    echo "# ii-niri environment" >> "$HOME/.zshrc"
    echo "[ -f \"\${XDG_CONFIG_HOME:-\$HOME/.config}/ii-niri-env.sh\" ] && source \"\${XDG_CONFIG_HOME:-\$HOME/.config}/ii-niri-env.sh\"" >> "$HOME/.zshrc"
    log_success "Zsh environment configured"
  fi
fi

# Fish config (different syntax)
if [[ -d "${XDG_CONFIG_HOME}/fish" ]] || command -v fish &>/dev/null; then
  FISH_CONF="${XDG_CONFIG_HOME}/fish/conf.d/ii-niri-env.fish"
  mkdir -p "$(dirname "$FISH_CONF")"
  cat > "${FISH_CONF}" << 'FISHEOF'
# ii-niri environment variables
set -gx ILLOGICAL_IMPULSE_VIRTUAL_ENV "$HOME/.local/state/quickshell/.venv"

# Qt theming (optional)
# set -gx QT_STYLE_OVERRIDE kvantum
# set -gx QT_QPA_PLATFORMTHEME kde
FISHEOF
  log_success "Fish environment configured"
fi

# Clean up old global environment (prevent compositor crashes)
ENVD_FILE="${XDG_CONFIG_HOME}/environment.d/ii-niri.conf"
if [[ -f "$ENVD_FILE" ]]; then
  echo -e "${STY_YELLOW}Removing legacy environment file: $ENVD_FILE${STY_RST}"
  rm -f "$ENVD_FILE"
fi

log_success "Environment variables configured"

#####################################################################################
# Set default wallpaper and generate initial theme
#####################################################################################
DEFAULT_WALLPAPER="${II_TARGET}/assets/wallpapers/qs-niri.jpg"
if [[ "${INSTALL_FIRSTRUN}" == true && -f "${DEFAULT_WALLPAPER}" ]]; then
  echo -e "${STY_CYAN}Setting default wallpaper...${STY_RST}"
  
  # Ensure output directories exist for matugen
  mkdir -p "${XDG_STATE_HOME}/quickshell/user/generated"
  mkdir -p "${XDG_STATE_HOME}/quickshell/user/generated/wallpaper"
  mkdir -p "${XDG_CONFIG_HOME}/gtk-3.0"
  mkdir -p "${XDG_CONFIG_HOME}/gtk-4.0"
  mkdir -p "${XDG_CONFIG_HOME}/fuzzel"
  
  # Update config.json with default wallpaper path
  if [[ -f "${XDG_CONFIG_HOME}/illogical-impulse/config.json" ]]; then
    if command -v jq >/dev/null 2>&1; then
      jq --arg path "${DEFAULT_WALLPAPER}" '.background.wallpaperPath = $path' \
        "${XDG_CONFIG_HOME}/illogical-impulse/config.json" > "${XDG_CONFIG_HOME}/illogical-impulse/config.json.tmp" \
        && mv "${XDG_CONFIG_HOME}/illogical-impulse/config.json.tmp" "${XDG_CONFIG_HOME}/illogical-impulse/config.json"
      log_success "Default wallpaper configured"
    fi
  fi
  
  # Generate initial theme colors with matugen
  export ILLOGICAL_IMPULSE_VIRTUAL_ENV="${XDG_STATE_HOME}/quickshell/.venv"
  if command -v matugen >/dev/null 2>&1; then
    echo -e "${STY_CYAN}Generating theme colors from wallpaper...${STY_RST}"
    # Use --config to ensure correct config file is used
    if matugen image "${DEFAULT_WALLPAPER}" --mode dark --config "${XDG_CONFIG_HOME}/matugen/config.toml" 2>&1; then
      log_success "Theme colors generated"
    else
      log_warning "Matugen failed to generate colors. Theme may not work correctly."
    fi
  else
    log_warning "Matugen not installed. GTK/Qt theming will not be applied."
  fi
fi

#####################################################################################
# Reset first run marker
#####################################################################################
QUICKSHELL_FIRST_RUN_FILE="${XDG_STATE_HOME}/quickshell/user/first_run.txt"
if [[ "${INSTALL_FIRSTRUN}" == true ]]; then
  if [[ -f "${QUICKSHELL_FIRST_RUN_FILE}" ]]; then
    x rm -f "${QUICKSHELL_FIRST_RUN_FILE}"
  fi
fi

#####################################################################################
# Final status checks
#####################################################################################
WARNINGS=()

if ! command -v niri >/dev/null; then
  WARNINGS+=("Niri compositor not found in PATH")
fi

if [[ ! -f "${XDG_CONFIG_HOME}/niri/config.kdl" ]]; then
  WARNINGS+=("Niri config not found at ~/.config/niri/config.kdl")
fi

if ! command -v qs >/dev/null; then
  WARNINGS+=("Quickshell (qs) not found in PATH")
fi

if ! command -v matugen >/dev/null; then
  WARNINGS+=("Matugen not found - theming may not work")
fi

#####################################################################################
# Final Summary
#####################################################################################
echo ""
echo ""
printf "${STY_GREEN}${STY_BOLD}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║                  ✓ Installation Complete                     ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
printf "${STY_RST}"
echo ""

# Show what was configured
echo -e "${STY_BLUE}${STY_BOLD}┌─ What was installed${STY_RST}"
echo -e "${STY_BLUE}│${STY_RST}"
echo -e "${STY_BLUE}│${STY_RST}  ${STY_GREEN}✓${STY_RST} Quickshell ii copied to ~/.config/quickshell/ii/"
echo -e "${STY_BLUE}│${STY_RST}  ${STY_GREEN}✓${STY_RST} Niri config with ii keybindings"
echo -e "${STY_BLUE}│${STY_RST}  ${STY_GREEN}✓${STY_RST} GTK/Qt theming (Matugen + Kvantum + Darkly)"
echo -e "${STY_BLUE}│${STY_RST}  ${STY_GREEN}✓${STY_RST} Environment variables for ${DETECTED_SHELL:-your shell}"
echo -e "${STY_BLUE}│${STY_RST}  ${STY_GREEN}✓${STY_RST} Default wallpaper and color scheme"
echo -e "${STY_BLUE}│${STY_RST}"
echo -e "${STY_BLUE}└──────────────────────────────${STY_RST}"
echo ""

# Show warnings if any
if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  echo -e "${STY_YELLOW}${STY_BOLD}┌─ Warnings${STY_RST}"
  echo -e "${STY_YELLOW}│${STY_RST}"
  for warn in "${WARNINGS[@]}"; do
    echo -e "${STY_YELLOW}│${STY_RST}  ${STY_RED}⚠${STY_RST} ${warn}"
  done
  echo -e "${STY_YELLOW}│${STY_RST}"
  echo -e "${STY_YELLOW}└──────────────────────────────${STY_RST}"
  echo ""
fi

# Next steps
echo -e "${STY_CYAN}${STY_BOLD}┌─ Next Steps${STY_RST}"
echo -e "${STY_CYAN}│${STY_RST}"
echo -e "${STY_CYAN}│${STY_RST}  ${STY_BOLD}1.${STY_RST} Log out and select ${STY_BOLD}Niri${STY_RST} at your display manager"
echo -e "${STY_CYAN}│${STY_RST}  ${STY_BOLD}2.${STY_RST} ii will start automatically with your session"
echo -e "${STY_CYAN}│${STY_RST}"
echo -e "${STY_CYAN}│${STY_RST}  Or reload now if already in Niri:"
echo -e "${STY_CYAN}│${STY_RST}  ${STY_FAINT}$ niri msg action reload-config${STY_RST}"
echo -e "${STY_CYAN}│${STY_RST}"
echo -e "${STY_CYAN}└──────────────────────────────${STY_RST}"
echo ""

# Key shortcuts
echo -e "${STY_PURPLE}${STY_BOLD}┌─ Key Shortcuts${STY_RST}"
echo -e "${STY_PURPLE}│${STY_RST}"
echo -e "${STY_PURPLE}│${STY_RST}  ${STY_INVERT} Super+G ${STY_RST}         Overlay (search, widgets)"
echo -e "${STY_PURPLE}│${STY_RST}  ${STY_INVERT} Alt+Tab ${STY_RST}         Window switcher"
echo -e "${STY_PURPLE}│${STY_RST}  ${STY_INVERT} Super+V ${STY_RST}         Clipboard history"
echo -e "${STY_PURPLE}│${STY_RST}  ${STY_INVERT} Ctrl+Alt+T ${STY_RST}      Wallpaper picker"
echo -e "${STY_PURPLE}│${STY_RST}  ${STY_INVERT} Super+/ ${STY_RST}         Show all shortcuts"
echo -e "${STY_PURPLE}│${STY_RST}"
echo -e "${STY_PURPLE}└──────────────────────────────${STY_RST}"
echo ""

echo -e "${STY_FAINT}Backups saved to: ${BACKUP_DIR}${STY_RST}"
echo -e "${STY_FAINT}Logs: qs log -c ii${STY_RST}"
echo ""
echo -e "${STY_GREEN}Enjoy your new desktop!${STY_RST}"
echo ""
