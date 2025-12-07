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
    if ! ${quiet:-false}; then
      echo -e "${STY_CYAN}Installing Quickshell ii config...${STY_RST}"
    fi
    
    # The ii QML code is in the root of this repo, not in dots/
    # We copy it to ~/.config/quickshell/ii/
    II_SOURCE="${REPO_ROOT}"
    II_TARGET="${XDG_CONFIG_HOME}/quickshell/ii"
    
    v mkdir -p "$II_TARGET"
    
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
    
    log_success "Quickshell ii config installed"
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
    if [[ -f "defaults/niri/config.kdl" ]]; then
      install_file__auto_backup "defaults/niri/config.kdl" "${XDG_CONFIG_HOME}/niri/config.kdl"
      log_success "Niri config installed (defaults)"
    elif [[ -d "dots/.config/niri" ]]; then
      install_file__auto_backup "dots/.config/niri/config.kdl" "${XDG_CONFIG_HOME}/niri/config.kdl"
      log_success "Niri config installed (dots)"
    fi
    
    # Migrate: Add layer-rules for backdrop if missing (required for Niri overview)
    NIRI_CONFIG="${XDG_CONFIG_HOME}/niri/config.kdl"
    if [[ -f "$NIRI_CONFIG" ]]; then
      if ! grep -q "quickshell:iiBackdrop" "$NIRI_CONFIG" 2>/dev/null; then
        if ! ${quiet:-false}; then
          echo -e "${STY_CYAN}Adding backdrop layer-rules to Niri config...${STY_RST}"
        fi
        cat >> "$NIRI_CONFIG" << 'BACKDROP_RULES'

// ============================================================================
// Layer rules added by ii setup (required for backdrop in Niri overview)
// ============================================================================
layer-rule {
    match namespace="quickshell:iiBackdrop"
    place-within-backdrop true
    opacity 1.0
}

layer-rule {
    match namespace="quickshell:wBackdrop"
    place-within-backdrop true
    opacity 1.0
}
BACKDROP_RULES
        log_success "Backdrop layer-rules added to Niri config"
      fi
      
      # NOTE: Keybind migration removed - too fragile and causes duplicates
      # The defaults/niri/config.kdl already has all ii keybinds.
      # On first install: user gets the full config
      # On update: user keeps their config, new defaults go to .new
      # Users can manually merge keybinds from .new if needed
      
      # Only show a hint if this is an update and .new was created
      if [[ "${IS_UPDATE}" == "true" && -f "${NIRI_CONFIG}.new" ]] && ! ${quiet:-false}; then
        echo -e "${STY_YELLOW}Note: New keybinds may be available in ${NIRI_CONFIG}.new${STY_RST}"
        echo -e "${STY_YELLOW}Compare with: diff ~/.config/niri/config.kdl ~/.config/niri/config.kdl.new${STY_RST}"
      fi
      
      # Migrate: Add //off to animations block if missing (required for GameMode toggle)
      if ! grep -qE '^\s*(//)?off' "$NIRI_CONFIG" 2>/dev/null; then
        if ! ${quiet:-false}; then
          echo -e "${STY_CYAN}Adding //off to animations block for GameMode support...${STY_RST}"
        fi
        python3 << 'MIGRATE_ANIMATIONS'
import re
import os

config_path = os.path.expanduser("~/.config/niri/config.kdl")
with open(config_path, 'r') as f:
    content = f.read()

# Check if //off already exists in animations block
animations_match = re.search(r'^animations\s*\{([^}]*)\}', content, re.MULTILINE | re.DOTALL)
if animations_match:
    block_content = animations_match.group(1)
    if '//off' not in block_content and 'off' not in block_content:
        # Insert //off after animations {
        new_block = 'animations {\n    //off' + block_content + '}'
        content = content[:animations_match.start()] + new_block + content[animations_match.end():]
        with open(config_path, 'w') as f:
            f.write(content)
# Output suppressed - shell handles logging
MIGRATE_ANIMATIONS
        log_success "Added //off to animations block"
      fi
      
      # Migrate: Replace native close-window with closeConfirm script
      if grep -q 'Mod+Q.*close-window' "$NIRI_CONFIG" 2>/dev/null; then
        if ! ${quiet:-false}; then
          echo -e "${STY_CYAN}Migrating Mod+Q to use closeConfirm...${STY_RST}"
        fi
        python3 << 'MIGRATE_CLOSEWINDOW'
import re
import os

config_path = os.path.expanduser("~/.config/niri/config.kdl")
with open(config_path, 'r') as f:
    content = f.read()

# Replace Mod+Q close-window with our script
pattern = r'Mod\+Q[^}]*close-window[^}]*\}'
replacement = 'Mod+Q repeat=false { spawn "bash" "-c" "$HOME/.config/quickshell/ii/scripts/close-window.sh"; }'
content = re.sub(pattern, replacement, content)

with open(config_path, 'w') as f:
    f.write(content)
# Output suppressed in quiet mode (checked by shell)
MIGRATE_CLOSEWINDOW
        log_success "Mod+Q migrated to closeConfirm with fallback"
      fi
      
      # Migrate: Qt theming - use kde platform + Breeze style for proper Qt app theming
      if grep -q 'QT_QPA_PLATFORMTHEME "gtk3"' "$NIRI_CONFIG" 2>/dev/null; then
        if ! ${quiet:-false}; then
          echo -e "${STY_CYAN}Migrating Qt theming from gtk3 to kde...${STY_RST}"
        fi
        # Change gtk3 to kde for kdeglobals color support
        sed -i 's/QT_QPA_PLATFORMTHEME "gtk3"/QT_QPA_PLATFORMTHEME "kde"/' "$NIRI_CONFIG"
        # Remove QT_QPA_PLATFORMTHEME_QT6 if present (not needed with kde)
        sed -i '/QT_QPA_PLATFORMTHEME_QT6/d' "$NIRI_CONFIG"
        log_success "Qt theming migrated to kde"
      fi
      
      # Add QT_QPA_PLATFORMTHEME if missing entirely
      if ! grep -q 'QT_QPA_PLATFORMTHEME' "$NIRI_CONFIG" 2>/dev/null; then
        if ! ${quiet:-false}; then
          echo -e "${STY_CYAN}Adding QT_QPA_PLATFORMTHEME for Qt theming...${STY_RST}"
        fi
        sed -i '/QT_QPA_PLATFORM "wayland"/a\    QT_QPA_PLATFORMTHEME "kde"' "$NIRI_CONFIG"
        log_success "QT_QPA_PLATFORMTHEME added"
      fi
      
      # Add QT_STYLE_OVERRIDE if not present
      if ! grep -q 'QT_STYLE_OVERRIDE' "$NIRI_CONFIG" 2>/dev/null; then
        if ! ${quiet:-false}; then
          echo -e "${STY_CYAN}Adding QT_STYLE_OVERRIDE for Qt theming...${STY_RST}"
        fi
        sed -i '/QT_QPA_PLATFORMTHEME/a\    QT_STYLE_OVERRIDE "Breeze"' "$NIRI_CONFIG"
        log_success "QT_STYLE_OVERRIDE added"
      fi
      
      # Migrate: Add XDG_MENU_PREFIX for Dolphin file associations
      # Check specifically for XDG_MENU_PREFIX in environment block (not spawn-at-startup)
      if ! grep -q 'XDG_MENU_PREFIX "plasma-"' "$NIRI_CONFIG" 2>/dev/null; then
        if ! ${quiet:-false}; then
          echo -e "${STY_CYAN}Adding XDG_MENU_PREFIX for Dolphin file associations...${STY_RST}"
        fi
        # Add after XDG_CURRENT_DESKTOP
        sed -i '/XDG_CURRENT_DESKTOP "niri"/a\    XDG_MENU_PREFIX "plasma-"  // Required for Dolphin file associations' "$NIRI_CONFIG"
        log_success "XDG_MENU_PREFIX added for Dolphin"
      fi
      
      # Migrate: Add spawn-at-startup for systemctl import-environment (Dolphin fix)
      if ! grep -q 'import-environment XDG_MENU_PREFIX' "$NIRI_CONFIG" 2>/dev/null; then
        if ! ${quiet:-false}; then
          echo -e "${STY_CYAN}Adding systemctl import-environment for Dolphin...${STY_RST}"
        fi
        # Add before the first spawn-at-startup
        sed -i '0,/spawn-at-startup/s//spawn-at-startup "bash" "-c" "systemctl --user import-environment XDG_MENU_PREFIX \&\& kbuildsycoca6"\n\nspawn-at-startup/' "$NIRI_CONFIG"
        log_success "systemctl import-environment added for Dolphin"
      fi
      
      # Migrate: Update media/audio keybinds to use ii IPC (shows OSD)
      if grep -q 'XF86AudioRaiseVolume.*wpctl' "$NIRI_CONFIG" 2>/dev/null; then
        if ! ${quiet:-false}; then
          echo -e "${STY_CYAN}Migrating audio keybinds to use ii IPC (with OSD)...${STY_RST}"
        fi
        # Replace old wpctl keybinds with ii IPC
        sed -i 's|XF86AudioRaiseVolume.*{.*spawn.*wpctl.*}|XF86AudioRaiseVolume allow-when-locked=true { spawn "qs" "-c" "ii" "ipc" "call" "audio" "volumeUp"; }|' "$NIRI_CONFIG"
        sed -i 's|XF86AudioLowerVolume.*{.*spawn.*wpctl.*}|XF86AudioLowerVolume allow-when-locked=true { spawn "qs" "-c" "ii" "ipc" "call" "audio" "volumeDown"; }|' "$NIRI_CONFIG"
        sed -i 's|XF86AudioMute.*{.*spawn.*wpctl.*}|XF86AudioMute allow-when-locked=true { spawn "qs" "-c" "ii" "ipc" "call" "audio" "mute"; }|' "$NIRI_CONFIG"
        log_success "Audio keybinds migrated to ii IPC"
      fi
      
      # Add XF86AudioMicMute if missing
      if ! grep -q 'XF86AudioMicMute' "$NIRI_CONFIG" 2>/dev/null; then
        sed -i '/XF86AudioMute.*allow-when-locked/a\    XF86AudioMicMute allow-when-locked=true { spawn "qs" "-c" "ii" "ipc" "call" "audio" "micMute"; }' "$NIRI_CONFIG"
        log_success "XF86AudioMicMute keybind added"
      fi
      
      # Add brightness keybinds if missing
      if ! grep -q 'XF86MonBrightnessUp' "$NIRI_CONFIG" 2>/dev/null; then
        if ! ${quiet:-false}; then
          echo -e "${STY_CYAN}Adding brightness keybinds...${STY_RST}"
        fi
        # Add after XF86AudioMicMute or XF86AudioMute
        if grep -q 'XF86AudioMicMute' "$NIRI_CONFIG"; then
          sed -i '/XF86AudioMicMute/a\    \n    // Brightness (hardware keys)\n    XF86MonBrightnessUp { spawn "qs" "-c" "ii" "ipc" "call" "brightness" "increment"; }\n    XF86MonBrightnessDown { spawn "qs" "-c" "ii" "ipc" "call" "brightness" "decrement"; }' "$NIRI_CONFIG"
        else
          sed -i '/XF86AudioMute/a\    \n    // Brightness (hardware keys)\n    XF86MonBrightnessUp { spawn "qs" "-c" "ii" "ipc" "call" "brightness" "increment"; }\n    XF86MonBrightnessDown { spawn "qs" "-c" "ii" "ipc" "call" "brightness" "decrement"; }' "$NIRI_CONFIG"
        fi
        log_success "Brightness keybinds added"
      fi
      
      # Add media playback keybinds if missing
      if ! grep -q 'XF86AudioPlay' "$NIRI_CONFIG" 2>/dev/null; then
        if ! ${quiet:-false}; then
          echo -e "${STY_CYAN}Adding media playback keybinds...${STY_RST}"
        fi
        sed -i '/XF86MonBrightnessDown/a\    \n    // Media playback (hardware keys)\n    XF86AudioPlay { spawn "qs" "-c" "ii" "ipc" "call" "mpris" "playPause"; }\n    XF86AudioPause { spawn "qs" "-c" "ii" "ipc" "call" "mpris" "playPause"; }\n    XF86AudioNext { spawn "qs" "-c" "ii" "ipc" "call" "mpris" "next"; }\n    XF86AudioPrev { spawn "qs" "-c" "ii" "ipc" "call" "mpris" "previous"; }' "$NIRI_CONFIG"
        log_success "Media playback keybinds added"
      fi
      
      # Add keyboard alternatives for media (Mod+Shift+M/P/N/B) if missing
      if ! grep -q 'Mod+Shift+M.*audio.*mute' "$NIRI_CONFIG" 2>/dev/null; then
        if ! ${quiet:-false}; then
          echo -e "${STY_CYAN}Adding keyboard media shortcuts (Mod+Shift+M/P/N/B)...${STY_RST}"
        fi
        sed -i '/XF86AudioPrev/a\    \n    // Keyboard alternatives for media (for keyboards without media keys)\n    Mod+Shift+M { spawn "qs" "-c" "ii" "ipc" "call" "audio" "mute"; }\n    Mod+Shift+P { spawn "qs" "-c" "ii" "ipc" "call" "mpris" "playPause"; }\n    Mod+Shift+N { spawn "qs" "-c" "ii" "ipc" "call" "mpris" "next"; }\n    Mod+Shift+B { spawn "qs" "-c" "ii" "ipc" "call" "mpris" "previous"; }' "$NIRI_CONFIG"
        log_success "Keyboard media shortcuts added"
      fi
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

  # Check for .new files that need manual review
  NEW_FILES=()
  for f in "${XDG_CONFIG_HOME}/niri/config.kdl.new" \
           "${XDG_CONFIG_HOME}/illogical-impulse/config.json.new" \
           "${XDG_CONFIG_HOME}/kdeglobals.new"; do
    if [[ -f "$f" ]]; then
      NEW_FILES+=("$f")
    fi
  done

  if [[ ${#NEW_FILES[@]} -gt 0 ]]; then
    echo -e "${STY_YELLOW}${STY_BOLD}┌─ Files to Review${STY_RST}"
    echo -e "${STY_YELLOW}│${STY_RST}"
    echo -e "${STY_YELLOW}│${STY_RST}  New defaults saved as .new (your config preserved):"
    for f in "${NEW_FILES[@]}"; do
      echo -e "${STY_YELLOW}│${STY_RST}    ${STY_FAINT}${f}${STY_RST}"
    done
    echo -e "${STY_YELLOW}│${STY_RST}"
    echo -e "${STY_YELLOW}│${STY_RST}  Compare with: ${STY_FAINT}diff <file> <file>.new${STY_RST}"
    echo -e "${STY_YELLOW}└──────────────────────────${STY_RST}"
    echo ""
  fi

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
