# Config file installation for ii-niri
# This script is meant to be sourced.

# shellcheck shell=bash

if ! ${quiet:-false}; then
  printf "${STY_CYAN}[$0]: 3. Copying config files${STY_RST}\n"
fi

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

# Notifications persistence setup
OLD_NOTIF_PATH="${XDG_CACHE_HOME}/quickshell/notifications/notifications.json"
NEW_NOTIF_PATH="${XDG_STATE_HOME}/quickshell/user/notifications.json"

# Migrate from old cache location if exists
if [[ -f "$OLD_NOTIF_PATH" && ! -f "$NEW_NOTIF_PATH" ]]; then
  if ! ${quiet:-false}; then
    echo -e "${STY_CYAN}Migrating notifications to persistent storage...${STY_RST}"
  fi
  mv "$OLD_NOTIF_PATH" "$NEW_NOTIF_PATH"
  rmdir "${XDG_CACHE_HOME}/quickshell/notifications" 2>/dev/null || true
  log_success "Notifications migrated to state directory"
fi

# Create empty notifications file if it doesn't exist (fresh install)
if [[ ! -f "$NEW_NOTIF_PATH" ]]; then
  echo "[]" > "$NEW_NOTIF_PATH"
fi

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
    # Only show message if backup dir was actually created
    if [[ -d "${BACKUP_DIR}" ]]; then
      printf "${STY_BLUE}Backup finished: ${BACKUP_DIR}${STY_RST}\n"
    fi
  fi
}

if [[ ! "${SKIP_BACKUP}" == true ]]; then auto_backup_configs; fi

#####################################################################################
# Install Quickshell config (ii)
#####################################################################################
case "${SKIP_QUICKSHELL}" in
  true) sleep 0;;
  *)
    if ! ${quiet:-false}; then
      echo -e "${STY_CYAN}Installing Quickshell ii config...${STY_RST}"
    fi
    
    # The ii QML code is in the root of this repo, not in dots/
    # We copy it to ~/.config/quickshell/ii/
    II_SOURCE="${REPO_ROOT}"
    II_TARGET="${XDG_CONFIG_HOME}/quickshell/ii"
    
    v mkdir -p "$II_TARGET"
    
    # Create backup before update (if this is an update)
    if [[ "${IS_UPDATE}" == "true" ]]; then
      log_info "Creating backup before update..."
      create_update_backup "$II_TARGET" >/dev/null
    fi
    
    # Generate manifest BEFORE syncing (to know what should exist)
    log_info "Generating file manifest..."
    generate_manifest "$II_SOURCE" "${II_TARGET}/.ii-manifest.new"
    
    # Copy all .qml files from root (auto-detect, no manual list needed)
    for qml_file in "${II_SOURCE}"/*.qml; do
      if [[ -f "$qml_file" ]]; then
        install_file "$qml_file" "${II_TARGET}/$(basename "$qml_file")"
      fi
    done
    
    # Copy required directories
    QML_DIRS=(modules services scripts assets translations)
    for dir in "${QML_DIRS[@]}"; do
      if [[ -d "${II_SOURCE}/${dir}" ]]; then
        install_dir__sync "${II_SOURCE}/${dir}" "${II_TARGET}/${dir}"
      fi
    done
    
    # Copy requirements.txt
    if [[ -f "${II_SOURCE}/requirements.txt" ]]; then
      install_file "${II_SOURCE}/requirements.txt" "${II_TARGET}/requirements.txt"
    fi
    
    # Finalize manifest
    mv "${II_TARGET}/.ii-manifest.new" "${II_TARGET}/.ii-manifest"
    
    # Cleanup orphan files (files that no longer exist in repo)
    if [[ "${IS_UPDATE}" == "true" ]]; then
      log_info "Cleaning up orphan files..."
      cleanup_orphans "$II_TARGET" "${II_TARGET}/.ii-manifest"
    fi
    
    # Fix script permissions
    log_info "Setting script permissions..."
    find "$II_TARGET/scripts" \( -name "*.sh" -o -name "*.fish" -o -name "*.py" \) -exec chmod +x {} \; 2>/dev/null || true
    
    log_success "Quickshell ii config installed"
    
    # Install Python packages now that requirements.txt is in place
    showfun install-python-packages
    v install-python-packages
    
    # Verify installation (only on updates, not fresh install)
    if [[ "${IS_UPDATE}" == "true" && "${SKIP_VERIFICATION}" != "true" ]]; then
      log_info "Verifying installation..."
      if ! verify_qs_loads 8; then
        log_error "Verification failed!"
        echo ""
        echo -e "${STY_YELLOW}The update may have issues. Options:${STY_RST}"
        echo "  1. Run ${STY_CYAN}./setup doctor${STY_RST} to diagnose"
        echo "  2. Run ${STY_CYAN}./setup restore${STY_RST} to rollback"
        echo ""
      else
        log_success "Verification passed"
      fi
    fi
    ;;
esac

#####################################################################################
# Install config files from dots/
#####################################################################################
if ! ${quiet:-false}; then
  echo -e "${STY_CYAN}Installing config files from dots/...${STY_RST}"
fi

# Niri config
case "${SKIP_NIRI}" in
  true) sleep 0;;
  *)
    NIRI_CONFIG="${XDG_CONFIG_HOME}/niri/config.kdl"
    
    # First install: copy our default config
    # Update: preserve user's config; new options are handled via migrations
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
# These are controlled by ii-niri for theming - always overwrite
if [[ -f "defaults/kde/kdeglobals" ]]; then
  install_file "defaults/kde/kdeglobals" "${XDG_CONFIG_HOME}/kdeglobals"
elif [[ -f "dots/.config/kdeglobals" ]]; then
  install_file "dots/.config/kdeglobals" "${XDG_CONFIG_HOME}/kdeglobals"
fi
if [[ -f "defaults/kde/dolphinrc" ]]; then
  install_file "defaults/kde/dolphinrc" "${XDG_CONFIG_HOME}/dolphinrc"
elif [[ -f "dots/.config/dolphinrc" ]]; then
  install_file "dots/.config/dolphinrc" "${XDG_CONFIG_HOME}/dolphinrc"
fi

# Dolphin panel layout state
# Dolphin stores panel visibility in dolphinstaterc which overrides dolphinrc.
# Policy:
# - Fresh install: apply our clean layout so users don't get all panels enabled.
# - Update: preserve user's custom layout by default.
# - User can force reset via --reset-dolphin-layout.
DOLPHIN_STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/dolphinstaterc"
if [[ "${INSTALL_FIRSTRUN}" == true || "${RESET_DOLPHIN_LAYOUT}" == true ]]; then
  if [[ -f "defaults/kde/dolphinstaterc" ]]; then
    mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}"
    install_file "defaults/kde/dolphinstaterc" "${DOLPHIN_STATE_FILE}"
    log_success "Dolphin panel layout state reset"
  elif [[ -f "${DOLPHIN_STATE_FILE}" ]]; then
    rm -f "${DOLPHIN_STATE_FILE}"
    log_success "Dolphin panel layout state cleaned"
  fi
fi

# Clean up obsolete .new files from previous installs
# These files are no longer created - kdeglobals and dolphinrc are always overwritten
for obsolete_new in "${XDG_CONFIG_HOME}/kdeglobals.new" \
                    "${XDG_CONFIG_HOME}/dolphinrc.new"; do
  if [[ -f "$obsolete_new" ]]; then
    rm -f "$obsolete_new"
    log_success "Cleaned obsolete ${obsolete_new##*/}"
  fi
done

# Kvantum (Qt theming)
if [[ -d "dots/.config/Kvantum" ]]; then
  install_dir "dots/.config/Kvantum" "${XDG_CONFIG_HOME}/Kvantum"
fi

# Copy Colloid theme to user Kvantum folder if installed
if [[ -d "/usr/share/Kvantum/Colloid" ]]; then
  if ! ${quiet:-false}; then
    echo -e "${STY_CYAN}Setting up Kvantum Colloid theme...${STY_RST}"
  fi
  mkdir -p "${XDG_CONFIG_HOME}/Kvantum/Colloid"
  cp -r /usr/share/Kvantum/Colloid/* "${XDG_CONFIG_HOME}/Kvantum/Colloid/"
  log_success "Kvantum Colloid theme configured"
fi

# Setup MaterialAdw folder for dynamic theming
mkdir -p "${XDG_CONFIG_HOME}/Kvantum/MaterialAdw"
if [[ -f "${XDG_CONFIG_HOME}/Kvantum/Colloid/ColloidDark.kvconfig" ]]; then
  cp "${XDG_CONFIG_HOME}/Kvantum/Colloid/ColloidDark.kvconfig" "${XDG_CONFIG_HOME}/Kvantum/MaterialAdw/MaterialAdw.kvconfig"
fi

# Vesktop themes (Discord theming with Material You colors)
if [[ -d "dots/.config/vesktop/themes" ]]; then
  mkdir -p "${XDG_CONFIG_HOME}/vesktop/themes"
  mkdir -p "${XDG_CONFIG_HOME}/Vesktop/themes"
  
  # Migrate: Remove old theme files from previous versions
  OLD_VESKTOP_THEMES=(
    "midnight-ii.theme.css"
    "dms-midnight.theme.css"
    "system24-ii.theme.css"
    "system24-palette.css"
    "ii-palette.css"
    "ii-system24.theme.css"
  )
  for old_theme in "${OLD_VESKTOP_THEMES[@]}"; do
    if [[ -f "${XDG_CONFIG_HOME}/vesktop/themes/${old_theme}" ]]; then
      rm -f "${XDG_CONFIG_HOME}/vesktop/themes/${old_theme}"
      log_success "Removed old Vesktop theme: ${old_theme}"
    fi
    if [[ -f "${XDG_CONFIG_HOME}/Vesktop/themes/${old_theme}" ]]; then
      rm -f "${XDG_CONFIG_HOME}/Vesktop/themes/${old_theme}"
      log_success "Removed old Vesktop theme: ${old_theme} (Vesktop/)"
    fi
  done
  
  install_dir "dots/.config/vesktop/themes" "${XDG_CONFIG_HOME}/vesktop/themes"
  install_dir "dots/.config/vesktop/themes" "${XDG_CONFIG_HOME}/Vesktop/themes"
  log_success "Vesktop Material You theme installed"

  # Best-effort verification (helps diagnose "update didn't apply" reports)
  VESKTOP_THEME_A="${XDG_CONFIG_HOME}/vesktop/themes/system24.theme.css"
  VESKTOP_THEME_B="${XDG_CONFIG_HOME}/Vesktop/themes/system24.theme.css"
  if [[ ! -f "$VESKTOP_THEME_A" && ! -f "$VESKTOP_THEME_B" ]]; then
    log_warning "Vesktop theme file was not found after install"
    echo -e "${STY_YELLOW}Expected one of:${STY_RST}"
    echo -e "  ${STY_YELLOW}$VESKTOP_THEME_A${STY_RST}"
    echo -e "  ${STY_YELLOW}$VESKTOP_THEME_B${STY_RST}"
    echo -e "${STY_YELLOW}If Vesktop uses a different config dir, install manually or set SYSTEM24_PALETTE_CSS to your path.${STY_RST}"
  fi
fi

# Fontconfig
if [[ -d "dots/.config/fontconfig" ]]; then
  install_dir__sync "dots/.config/fontconfig" "${XDG_CONFIG_HOME}/fontconfig"
fi

# illogical-impulse config.json (use defaults for distribution)
if [[ -f "defaults/config.json" ]]; then
  v mkdir -p "${XDG_CONFIG_HOME}/illogical-impulse"
  install_file__auto_backup "defaults/config.json" "${XDG_CONFIG_HOME}/illogical-impulse/config.json"
elif [[ -f "dots/.config/illogical-impulse/config.json" ]]; then
  # Fallback to dots (legacy)
  install_file__auto_backup "dots/.config/illogical-impulse/config.json" "${XDG_CONFIG_HOME}/illogical-impulse/config.json"
fi

#####################################################################################
# Apply required migrations automatically
#####################################################################################
if [[ "${SKIP_MIGRATIONS}" != "true" ]]; then
  run_migrations_auto
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
# Environment variables are configured in Niri
#####################################################################################
if ! ${quiet:-false}; then
  echo -e "${STY_CYAN}Configuring environment variables...${STY_RST}"
fi

# Note: ILLOGICAL_IMPULSE_VIRTUAL_ENV is set in ~/.config/niri/config.kdl
# in the environment {} block. This is the proper way for Niri/Wayland compositors.
# The Niri config has been installed with this variable already set.

# Verify the variable will be available after Niri restart
if grep -q "ILLOGICAL_IMPULSE_VIRTUAL_ENV" "${XDG_CONFIG_HOME}/niri/config.kdl" 2>/dev/null; then
    log_success "Environment variable configured in Niri config"
else
    echo -e "${STY_YELLOW}Warning: ILLOGICAL_IMPULSE_VIRTUAL_ENV not found in Niri config${STY_RST}"
    echo -e "${STY_YELLOW}Quickshell may not work correctly until you add it to ~/.config/niri/config.kdl${STY_RST}"
fi

# Clean up legacy shell-specific files from previous versions
for legacy_file in \
    "${XDG_CONFIG_HOME}/fish/conf.d/ii-niri-env.fish" \
    "${XDG_CONFIG_HOME}/ii-niri-env.sh" \
    "${XDG_CONFIG_HOME}/environment.d/60-ii-niri.conf"
do
    if [[ -f "$legacy_file" ]]; then
        rm -f "$legacy_file"
        log_success "Removed legacy config: $(basename $legacy_file)"
    fi
done

# Clean up legacy lines in shell rc files
if [[ -f "$HOME/.bashrc" ]]; then
    if grep -q "ii-niri-env.sh" "$HOME/.bashrc"; then
        sed -i '/ii-niri-env.sh/d' "$HOME/.bashrc"
        log_success "Cleaned up .bashrc"
    fi
fi
if [[ -f "$HOME/.zshrc" ]]; then
    if grep -q "ii-niri-env.sh" "$HOME/.zshrc"; then
        sed -i '/ii-niri-env.sh/d' "$HOME/.zshrc"
        log_success "Cleaned up .zshrc"
    fi
fi

# Fix Qt Icons (Apply GTK icon theme to KDE/Qt globals)
# This ensures Qt apps use the same icons as GTK apps
GTK_SETTINGS="${XDG_CONFIG_HOME}/gtk-3.0/settings.ini"
KDE_GLOBALS="${XDG_CONFIG_HOME}/kdeglobals"

if [[ -f "$GTK_SETTINGS" ]]; then
    ICON_THEME=$(grep "gtk-icon-theme-name" "$GTK_SETTINGS" | cut -d= -f2 | xargs)
    if [[ -n "$ICON_THEME" ]]; then
        if ! ${quiet:-false}; then
          echo -e "${STY_CYAN}Applying icon theme '$ICON_THEME' to Qt/KDE...${STY_RST}"
        fi
        
        # Ensure [Icons] section exists
        if ! grep -q "\[Icons\]" "$KDE_GLOBALS" 2>/dev/null; then
            mkdir -p "$(dirname "$KDE_GLOBALS")"
            echo -e "\n[Icons]" >> "$KDE_GLOBALS"
        fi
        
        # Update or add Theme key
        if grep -q "Theme=" "$KDE_GLOBALS"; then
            sed -i "s/^Theme=.*/Theme=$ICON_THEME/" "$KDE_GLOBALS"
        else
            # Insert after [Icons]
            sed -i "/\[Icons\]/a Theme=$ICON_THEME" "$KDE_GLOBALS"
        fi
        log_success "Qt icon theme configured"
    fi
fi

#####################################################################################
# Set default MIME associations (only if not already set)
#####################################################################################
if ! ${quiet:-false}; then
  echo -e "${STY_CYAN}Configuring default applications...${STY_RST}"
fi

# Function to set MIME default only if not already configured or set to something broken
# Note: xdg-mime may fail without a graphical session, so we handle errors gracefully
set_mime_default_if_missing() {
    local mime_type="$1"
    local desktop_file="$2"
    
    # Check if the desktop file exists
    if [[ ! -f "/usr/share/applications/${desktop_file}" ]] && [[ ! -f "${XDG_DATA_HOME}/applications/${desktop_file}" ]]; then
        return 1  # Desktop file not available
    fi
    
    # xdg-mime requires a graphical session, skip if not available
    if ! command -v xdg-mime &>/dev/null; then
        return 1
    fi
    
    # Get current default (may fail without D-Bus session)
    local current_default
    current_default=$(xdg-mime query default "$mime_type" 2>/dev/null) || return 1
    
    # If no default set, or default is a non-editor for text files, set our default
    if [[ -z "$current_default" ]]; then
        xdg-mime default "$desktop_file" "$mime_type" 2>/dev/null || return 1
        return 0
    fi
    
    # For text files, check if current default is actually a text editor
    # (avoid cases where okular or other non-editors are set)
    if [[ "$mime_type" == text/* ]]; then
        case "$current_default" in
            *kate*|*gedit*|*code*|*vim*|*nvim*|*emacs*|*nano*|*sublime*|*atom*|*notepad*|*helix*|*zed*)
                # Already set to a proper editor, don't change
                return 1
                ;;
            *)
                # Not a known editor, set our default
                xdg-mime default "$desktop_file" "$mime_type" 2>/dev/null || return 1
                return 0
                ;;
        esac
    fi
    
    return 1  # Already has a valid default
}

# Detect available text editor (in order of preference)
TEXT_EDITOR=""
for editor in org.kde.kate.desktop org.gnome.gedit.desktop code.desktop vim.desktop; do
    if [[ -f "/usr/share/applications/${editor}" ]] || [[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/applications/${editor}" ]]; then
        TEXT_EDITOR="$editor"
        break
    fi
done

# Set text editor defaults if we found one
if [[ -n "$TEXT_EDITOR" ]]; then
    set_mime_default_if_missing "text/plain" "$TEXT_EDITOR" && log_success "Set default text editor: $TEXT_EDITOR" || true
    # Also set for common config file types
    for mime in text/x-shellscript application/x-shellscript text/x-python text/x-script.python; do
        set_mime_default_if_missing "$mime" "$TEXT_EDITOR" 2>/dev/null || true
    done
fi

# Detect and set file manager (prefer Dolphin for KDE consistency)
FILE_MANAGER=""
for fm in org.kde.dolphin.desktop thunar.desktop pcmanfm.desktop org.gnome.Nautilus.desktop; do
    if [[ -f "/usr/share/applications/${fm}" ]] || [[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/applications/${fm}" ]]; then
        FILE_MANAGER="$fm"
        break
    fi
done

if [[ -n "$FILE_MANAGER" ]]; then
    set_mime_default_if_missing "inode/directory" "$FILE_MANAGER" && log_success "Set default file manager: $FILE_MANAGER" || true
fi

# Detect and set image viewer
IMAGE_VIEWER=""
for viewer in org.kde.gwenview.desktop org.gnome.eog.desktop org.gnome.Loupe.desktop feh.desktop; do
    if [[ -f "/usr/share/applications/${viewer}" ]] || [[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/applications/${viewer}" ]]; then
        IMAGE_VIEWER="$viewer"
        break
    fi
done

if [[ -n "$IMAGE_VIEWER" ]]; then
    for mime in image/png image/jpeg image/gif image/webp image/bmp; do
        set_mime_default_if_missing "$mime" "$IMAGE_VIEWER" 2>/dev/null || true
    done
    log_success "Set default image viewer: $IMAGE_VIEWER"
fi

# Detect and set PDF viewer
PDF_VIEWER=""
for viewer in org.kde.okular.desktop org.gnome.Evince.desktop zathura.desktop; do
    if [[ -f "/usr/share/applications/${viewer}" ]] || [[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/applications/${viewer}" ]]; then
        PDF_VIEWER="$viewer"
        break
    fi
done

if [[ -n "$PDF_VIEWER" ]]; then
    set_mime_default_if_missing "application/pdf" "$PDF_VIEWER" && log_success "Set default PDF viewer: $PDF_VIEWER" || true
fi

# Detect and set web browser
WEB_BROWSER=""
for browser in firefox.desktop chromium.desktop google-chrome.desktop brave-browser.desktop; do
    if [[ -f "/usr/share/applications/${browser}" ]] || [[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/applications/${browser}" ]]; then
        WEB_BROWSER="$browser"
        break
    fi
done

if [[ -n "$WEB_BROWSER" ]]; then
    for mime in x-scheme-handler/http x-scheme-handler/https text/html; do
        set_mime_default_if_missing "$mime" "$WEB_BROWSER" 2>/dev/null || true
    done
    log_success "Set default web browser: $WEB_BROWSER"
fi

if ! ${quiet:-false}; then
  echo -e "${STY_CYAN}Copying wallpapers...${STY_RST}"
fi

#####################################################################################
# Copy bundled wallpapers to user's Pictures/Wallpapers (always, don't overwrite)
#####################################################################################
# Ensure II_TARGET is defined (in case SKIP_QUICKSHELL was set)
II_TARGET="${II_TARGET:-${XDG_CONFIG_HOME}/quickshell/ii}"
USER_WALLPAPERS_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Wallpapers"
if [[ -d "${II_TARGET}/assets/wallpapers" ]]; then
  mkdir -p "${USER_WALLPAPERS_DIR}"
  COPIED_COUNT=0
  for wallpaper in "${II_TARGET}/assets/wallpapers"/*; do
    if [[ -f "$wallpaper" ]]; then
      dest="${USER_WALLPAPERS_DIR}/$(basename "$wallpaper")"
      if [[ ! -f "$dest" ]]; then
        cp "$wallpaper" "$dest"
        COPIED_COUNT=$((COPIED_COUNT + 1))
      fi
    fi
  done
  if [[ $COPIED_COUNT -gt 0 ]]; then
    log_success "Copied $COPIED_COUNT new wallpapers to ${USER_WALLPAPERS_DIR}"
  fi
fi

#####################################################################################
# Set default wallpaper and generate initial theme (first run only)
#####################################################################################
DEFAULT_WALLPAPER="${USER_WALLPAPERS_DIR}/Angel1.png"
if [[ "${INSTALL_FIRSTRUN}" == true && -f "${DEFAULT_WALLPAPER}" ]]; then
  if ! ${quiet:-false}; then
    echo -e "${STY_CYAN}Setting default wallpaper...${STY_RST}"
  fi
  
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
    if ! ${quiet:-false}; then
      echo -e "${STY_CYAN}Generating theme colors from wallpaper...${STY_RST}"
    fi
    # Use --config to ensure correct config file is used
    if matugen image "${DEFAULT_WALLPAPER}" --mode dark --config "${XDG_CONFIG_HOME}/matugen/config.toml" 2>&1; then
      log_success "Theme colors generated"
      
      # Generate Darkly.colors for Qt file dialogs (Darkly style needs this)
      if [[ -f "${II_TARGET}/scripts/colors/apply-gtk-theme.sh" ]]; then
        bash "${II_TARGET}/scripts/colors/apply-gtk-theme.sh" 2>/dev/null || true
        log_success "Qt Darkly theme colors generated"
      fi
    else
      log_warning "Matugen failed to generate colors. Theme may not work correctly."
    fi
  else
    log_warning "Matugen not installed. GTK/Qt theming will not be applied."
  fi
fi

#####################################################################################
# Migrate: Generate Darkly.colors for existing users (Qt file dialogs fix)
#####################################################################################
DARKLY_COLORS_FILE="${HOME}/.local/share/color-schemes/Darkly.colors"
if [[ ! -f "${DARKLY_COLORS_FILE}" ]]; then
  if ! ${quiet:-false}; then
    echo -e "${STY_CYAN}Generating Darkly color scheme for Qt file dialogs...${STY_RST}"
  fi
  
  # Ensure directory exists
  mkdir -p "$(dirname "${DARKLY_COLORS_FILE}")"
  
  # Try to regenerate from existing material colors
  MATERIAL_COLORS="${XDG_STATE_HOME}/quickshell/user/generated/material_colors.scss"
  if [[ -f "${MATERIAL_COLORS}" && -f "${II_TARGET}/scripts/colors/apply-gtk-theme.sh" ]]; then
    # Run the apply script which will generate Darkly.colors
    bash "${II_TARGET}/scripts/colors/apply-gtk-theme.sh" 2>/dev/null || true
    if [[ -f "${DARKLY_COLORS_FILE}" ]]; then
      log_success "Darkly color scheme generated for Qt apps"
    fi
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

# In quiet mode, just print a simple status line
if ${quiet:-false}; then
  if [[ "${IS_UPDATE}" == "true" ]]; then
    echo "ii-niri: update complete"
  else
    echo "ii-niri: install complete"
  fi
else
  echo ""
  echo ""

  if [[ "${IS_UPDATE}" == "true" ]]; then
    # Update-specific output
    printf "${STY_GREEN}${STY_BOLD}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║                    ✓ Update Complete                         ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    printf "${STY_RST}"
    echo ""

    echo -e "${STY_BLUE}${STY_BOLD}┌─ What was updated${STY_RST}"
    echo -e "${STY_BLUE}│${STY_RST}"
    echo -e "${STY_BLUE}│${STY_RST}  ${STY_GREEN}✓${STY_RST} Quickshell ii synced to ~/.config/quickshell/ii/"
    echo -e "${STY_BLUE}│${STY_RST}  ${STY_GREEN}✓${STY_RST} Missing keybinds added to Niri config (if any)"
    echo -e "${STY_BLUE}│${STY_RST}  ${STY_GREEN}✓${STY_RST} Config migrations applied"
    echo -e "${STY_BLUE}│${STY_RST}"
    echo -e "${STY_BLUE}└──────────────────────────────${STY_RST}"
    echo ""
  else
    # Install output
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
  fi
fi

# Skip the rest of the summary in quiet mode
if ! ${quiet:-false}; then

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

  # REBOOT WARNING (first install only)
  if [[ "${IS_UPDATE}" != "true" ]]; then
    echo ""
    printf "${STY_RED}${STY_BOLD}"
    cat << 'REBOOT'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║     ██████╗ ███████╗██████╗  ██████╗  ██████╗ ████████╗      ║
║     ██╔══██╗██╔════╝██╔══██╗██╔═══██╗██╔═══██╗╚══██╔══╝      ║
║     ██████╔╝█████╗  ██████╔╝██║   ██║██║   ██║   ██║         ║
║     ██╔══██╗██╔══╝  ██╔══██╗██║   ██║██║   ██║   ██║         ║
║     ██║  ██║███████╗██████╔╝╚██████╔╝╚██████╔╝   ██║         ║
║     ╚═╝  ╚═╝╚══════╝╚═════╝  ╚═════╝  ╚═════╝    ╚═╝         ║
║                                                              ║
║          REBOOT YOUR SYSTEM. SERIOUSLY. DO IT NOW.           ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
REBOOT
    printf "${STY_RST}"
    echo ""
    echo -e "${STY_YELLOW}Environment variables, user groups, and systemd services${STY_RST}"
    echo -e "${STY_YELLOW}won't take effect until you reboot. Don't skip this.${STY_RST}"
    echo ""
  fi

  # Next steps
  echo -e "${STY_CYAN}${STY_BOLD}┌─ Next Steps${STY_RST}"
  echo -e "${STY_CYAN}│${STY_RST}"
  if [[ "${IS_UPDATE}" != "true" ]]; then
    echo -e "${STY_CYAN}│${STY_RST}  ${STY_BOLD}1.${STY_RST} ${STY_RED}${STY_BOLD}REBOOT${STY_RST} your system"
    echo -e "${STY_CYAN}│${STY_RST}  ${STY_BOLD}2.${STY_RST} Select ${STY_BOLD}Niri${STY_RST} at your display manager"
    echo -e "${STY_CYAN}│${STY_RST}  ${STY_BOLD}3.${STY_RST} ii will start automatically with your session"
  else
    echo -e "${STY_CYAN}│${STY_RST}  ${STY_BOLD}1.${STY_RST} Log out and log back in, or reload Niri:"
    echo -e "${STY_CYAN}│${STY_RST}  ${STY_FAINT}$ niri msg action load-config-file${STY_RST}"
  fi
  echo -e "${STY_CYAN}│${STY_RST}"
  echo -e "${STY_CYAN}└──────────────────────────────${STY_RST}"
  echo ""

  # Key shortcuts (only show on install, not update)
  if [[ "${IS_UPDATE}" != "true" ]]; then
    echo -e "${STY_PURPLE}${STY_BOLD}┌─ Key Shortcuts${STY_RST}"
    echo -e "${STY_PURPLE}│${STY_RST}"
    echo -e "${STY_PURPLE}│${STY_RST}  ${STY_INVERT} Super+Space ${STY_RST}     Search / Overview"
    echo -e "${STY_PURPLE}│${STY_RST}  ${STY_INVERT} Super+G ${STY_RST}         Overlay (widgets, tools)"
    echo -e "${STY_PURPLE}│${STY_RST}  ${STY_INVERT} Alt+Tab ${STY_RST}         Window switcher"
    echo -e "${STY_PURPLE}│${STY_RST}  ${STY_INVERT} Super+V ${STY_RST}         Clipboard history"
    echo -e "${STY_PURPLE}│${STY_RST}  ${STY_INVERT} Ctrl+Alt+T ${STY_RST}      Wallpaper picker"
    echo -e "${STY_PURPLE}│${STY_RST}  ${STY_INVERT} Super+/ ${STY_RST}         Show all shortcuts"
    echo -e "${STY_PURPLE}│${STY_RST}"
    echo -e "${STY_PURPLE}└──────────────────────────────${STY_RST}"
    echo ""
  fi

  echo -e "${STY_FAINT}Backups saved to: ${BACKUP_DIR}${STY_RST}"
  echo -e "${STY_FAINT}Logs: qs log -c ii${STY_RST}"
  echo ""

  if [[ "${IS_UPDATE}" == "true" ]]; then
    echo -e "${STY_GREEN}Done. Hot reload should kick in any second now.${STY_RST}"
  else
    echo -e "${STY_GREEN}Now reboot and enjoy your new desktop!${STY_RST}"
  fi
  echo ""

fi  # end quiet check
