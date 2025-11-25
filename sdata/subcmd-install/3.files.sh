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

# Qt theming - use Kvantum for consistent look with KDE apps
export QT_STYLE_OVERRIDE=kvantum
export QT_QPA_PLATFORMTHEME=kde
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

# Qt theming
set -gx QT_STYLE_OVERRIDE kvantum
set -gx QT_QPA_PLATFORMTHEME kde
FISHEOF
  log_success "Fish environment configured"
fi

# Also add to environment.d for systemd user sessions (affects all apps)
ENVD_DIR="${XDG_CONFIG_HOME}/environment.d"
mkdir -p "$ENVD_DIR"
cat > "${ENVD_DIR}/ii-niri.conf" << 'ENVDEOF'
ILLOGICAL_IMPULSE_VIRTUAL_ENV=${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/.venv
QT_STYLE_OVERRIDE=kvantum
QT_QPA_PLATFORMTHEME=kde
ENVDEOF
log_success "Systemd environment.d configured"

log_success "Environment variables configured for all shells"

#####################################################################################
# Set default wallpaper and generate initial theme
#####################################################################################
DEFAULT_WALLPAPER="${II_TARGET}/assets/wallpapers/qs-niri.jpg"
if [[ -f "${DEFAULT_WALLPAPER}" ]]; then
  echo -e "${STY_CYAN}Setting default wallpaper...${STY_RST}"
  
  # Update config.json with default wallpaper path
  if [[ -f "${XDG_CONFIG_HOME}/illogical-impulse/config.json" ]]; then
    if command -v jq >/dev/null 2>&1; then
      jq --arg path "${DEFAULT_WALLPAPER}" '.background.wallpaperPath = $path' \
        "${XDG_CONFIG_HOME}/illogical-impulse/config.json" > "${XDG_CONFIG_HOME}/illogical-impulse/config.json.tmp" \
        && mv "${XDG_CONFIG_HOME}/illogical-impulse/config.json.tmp" "${XDG_CONFIG_HOME}/illogical-impulse/config.json"
      log_success "Default wallpaper configured"
    fi
  fi
  
  # Generate initial theme colors with matugen (needs the venv variable)
  export ILLOGICAL_IMPULSE_VIRTUAL_ENV="${XDG_STATE_HOME}/quickshell/.venv"
  if command -v matugen >/dev/null 2>&1; then
    echo -e "${STY_CYAN}Generating theme colors from wallpaper...${STY_RST}"
    matugen image "${DEFAULT_WALLPAPER}" --mode dark 2>/dev/null && log_success "Theme colors generated"
  fi
fi

#####################################################################################
# Finished
#####################################################################################
printf "\n"
printf "${STY_GREEN}${STY_BOLD}Installation complete!${STY_RST}\n"
printf "\n"
printf "${STY_CYAN}To start using ii on Niri:${STY_RST}\n"
printf "  1. Log out and select 'Niri' at your display manager\n"
printf "  2. ii should start automatically\n"
printf "\n"
printf "${STY_CYAN}Useful commands:${STY_RST}\n"
printf "  niri msg action reload-config  # Reload Niri config\n"
printf "  qs -c ii                        # Start ii manually\n"
printf "\n"
printf "${STY_CYAN}First steps:${STY_RST}\n"
printf "  Press ${STY_INVERT} Ctrl+Alt+T ${STY_RST} to select a wallpaper\n"
printf "  Press ${STY_INVERT} Super+G ${STY_RST} to toggle the overlay\n"
printf "\n"

# Reset ii "first run" marker so the welcome window appears after installation.
# FirstRunExperience.qml looks for this file under XDG_STATE_HOME/quickshell/user.
QUICKSHELL_FIRST_RUN_FILE="${XDG_STATE_HOME}/quickshell/user/first_run.txt"
if [[ -f "${QUICKSHELL_FIRST_RUN_FILE}" ]]; then
  x rm -f "${QUICKSHELL_FIRST_RUN_FILE}"
fi

# Final sanity check
if ! command -v niri >/dev/null; then
  printf "${STY_RED}[WARNING]: Niri compositor not found in PATH!${STY_RST}\n"
  printf "Please ensure it is installed properly.\n\n"
fi

if [[ ! -f "${XDG_CONFIG_HOME}/niri/config.kdl" ]]; then
  printf "${STY_RED}[WARNING]: Niri config not found at ~/.config/niri/config.kdl${STY_RST}\n"
  printf "You may need to copy it manually from dots/.config/niri/config.kdl\n\n"
fi
