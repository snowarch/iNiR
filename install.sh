#!/usr/bin/env bash
# =============================================================================
# illogical-impulse (ii) on Niri - Installer
# =============================================================================
# Modern installer with gum UI for Arch-based systems.
# Includes system checks, theming, and proper configuration.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/snowarch/quickshell-ii-niri/main/install.sh | bash
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# CONFIGURATION
# -----------------------------------------------------------------------------
REPO_URL="${REPO_URL:-https://github.com/snowarch/quickshell-ii-niri.git}"
CONFIG_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}"
DATA_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}"

# -----------------------------------------------------------------------------
# UI HELPERS (gum or fallback)
# -----------------------------------------------------------------------------
USE_GUM=false
if command -v gum >/dev/null 2>&1; then
  USE_GUM=true
fi

log() {
  local level="$1"; shift
  if $USE_GUM; then
    case "$level" in
      INFO)  gum style --foreground 10 "✓ $*" ;;
      WARN)  gum style --foreground 11 "⚠ $*" ;;
      ERR)   gum style --foreground 9 "✗ $*" ;;
      STEP)  echo; gum style --bold --foreground 14 "▶ $*" ;;
      *)     echo "[$level] $*" ;;
    esac
  else
    local bold="" reset="" green="" yellow="" red="" cyan=""
    if command -v tput >/dev/null 2>&1; then
      bold="$(tput bold 2>/dev/null || true)"
      reset="$(tput sgr0 2>/dev/null || true)"
      green="$(tput setaf 2 2>/dev/null || true)"
      yellow="$(tput setaf 3 2>/dev/null || true)"
      red="$(tput setaf 1 2>/dev/null || true)"
      cyan="$(tput setaf 6 2>/dev/null || true)"
    fi
    case "$level" in
      INFO)  printf '%s[INFO]%s %s\n' "$bold$green" "$reset" "$*" ;;
      WARN)  printf '%s[WARN]%s %s%s%s\n' "$bold$yellow" "$reset" "$yellow" "$*" "$reset" ;;
      ERR)   printf '%s[ERR]%s %s%s%s\n' "$bold$red" "$reset" "$red" "$*" "$reset" ;;
      STEP)  printf '\n%s==> %s%s\n' "$bold$cyan" "$*" "$reset" ;;
      *)     printf '[%s] %s\n' "$level" "$*" ;;
    esac
  fi
}

confirm() {
  local prompt="$1" default="${2:-y}"
  if [ "${II_INSTALLER_ASSUME_DEFAULTS:-}" = "1" ]; then
    [[ "$default" =~ ^[Yy] ]] && return 0 || return 1
  fi
  if $USE_GUM; then
    if [[ "$default" =~ ^[Yy] ]]; then
      gum confirm --default=yes "$prompt"
    else
      gum confirm --default=no "$prompt"
    fi
  else
    local reply suffix="[y/N]"
    [[ "$default" =~ ^[Yy] ]] && suffix="[Y/n]"
    while true; do
      printf '%s %s ' "$prompt" "$suffix"
      if [ -t 0 ]; then
        read -r reply || reply=""
      elif [ -r /dev/tty ]; then
        read -r reply </dev/tty || reply=""
      else
        reply="$default"
      fi
      reply="${reply:-$default}"
      case "$reply" in
        y|Y) return 0 ;;
        n|N) return 1 ;;
      esac
    done
  fi
}

choose() {
  local prompt="$1"; shift
  if $USE_GUM; then
    gum choose --header="$prompt" "$@"
  else
    echo "$prompt"
    select opt in "$@"; do
      [ -n "$opt" ] && echo "$opt" && break
    done </dev/tty
  fi
}

spin() {
  local title="$1"; shift
  if $USE_GUM; then
    gum spin --spinner dot --title "$title" -- "$@"
  else
    echo "$title..."
    "$@"
  fi
}

# -----------------------------------------------------------------------------
# SYSTEM HELPERS
# -----------------------------------------------------------------------------
require_cmd() {
  command -v "$1" >/dev/null 2>&1
}

pkg_installed() {
  pacman -Q "$1" >/dev/null 2>&1
}

pacman_has_pkg() {
  pacman -Si "$1" >/dev/null 2>&1
}

get_aur_helper() {
  for helper in yay paru; do
    if command -v "$helper" >/dev/null 2>&1; then
      echo "$helper"
      return 0
    fi
  done
  return 1
}

ensure_aur_helper() {
  if get_aur_helper >/dev/null; then
    return 0
  fi
  log INFO "Installing yay (AUR helper)..."
  sudo pacman -S --needed --noconfirm base-devel git
  local tmpdir="$(mktemp -d)"
  git clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay-bin"
  (cd "$tmpdir/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$tmpdir"
}

install_pkgs() {
  local pkgs=("$@")
  [ ${#pkgs[@]} -eq 0 ] && return 0
  
  local to_install=() pkg
  for pkg in "${pkgs[@]}"; do
    if ! pkg_installed "$pkg"; then
      to_install+=("$pkg")
    fi
  done
  
  [ ${#to_install[@]} -eq 0 ] && return 0
  
  log INFO "Installing: ${to_install[*]}"
  
  local helper
  if helper=$(get_aur_helper); then
    "$helper" -S --needed --noconfirm "${to_install[@]}" || log WARN "Some packages failed"
  else
    local pacman_pkgs=() aur_pkgs=()
    for pkg in "${to_install[@]}"; do
      if pacman_has_pkg "$pkg"; then
        pacman_pkgs+=("$pkg")
      else
        aur_pkgs+=("$pkg")
      fi
    done
    [ ${#pacman_pkgs[@]} -gt 0 ] && sudo pacman -S --needed --noconfirm "${pacman_pkgs[@]}"
    if [ ${#aur_pkgs[@]} -gt 0 ]; then
      ensure_aur_helper
      helper=$(get_aur_helper)
      "$helper" -S --needed --noconfirm "${aur_pkgs[@]}" || log WARN "Some AUR packages failed"
    fi
  fi
}

# -----------------------------------------------------------------------------
# SYSTEM CHECK
# -----------------------------------------------------------------------------
system_check() {
  log STEP "System Check"
  
  local issues=()
  
  # Check OS
  if ! require_cmd pacman; then
    log ERR "Arch-based distro required (pacman not found)"
    exit 1
  fi
  log INFO "Arch-based system detected"
  
  # Check sudo
  if ! require_cmd sudo; then
    log ERR "sudo required"
    exit 1
  fi
  
  # Check gum (install if missing for better UX)
  if ! $USE_GUM; then
    log WARN "gum not found - installing for better UI"
    sudo pacman -S --needed --noconfirm gum 2>/dev/null || true
    if command -v gum >/dev/null 2>&1; then
      USE_GUM=true
      log INFO "gum installed"
    fi
  fi
  
  # Check AUR helper
  if get_aur_helper >/dev/null; then
    log INFO "AUR helper: $(get_aur_helper)"
  else
    log WARN "No AUR helper - will install yay"
  fi
  
  # Check existing Niri
  if pkg_installed niri; then
    log INFO "Niri already installed"
  fi
  
  # Check existing Quickshell
  if pkg_installed quickshell-git || pkg_installed illogical-impulse-quickshell-git; then
    log INFO "Quickshell already installed"
  fi
  
  # Check existing ii config
  if [ -d "$CONFIG_ROOT/quickshell/ii" ]; then
    log INFO "Existing ii config found at $CONFIG_ROOT/quickshell/ii"
  fi
}

# -----------------------------------------------------------------------------
# SHOW BANNER
# -----------------------------------------------------------------------------
show_banner() {
  if $USE_GUM; then
    gum style \
      --border double \
      --border-foreground 212 \
      --padding "1 2" \
      --margin "1" \
      "  ii on Niri  " \
      "illogical-impulse shell for Niri compositor"
  else
    echo
    echo "======================================"
    echo "  ii on Niri - Installer"
    echo "======================================"
    echo
  fi
}

# =============================================================================
# PACKAGE DEFINITIONS
# =============================================================================
# Uses illogical-impulse metapackages from end-4's AUR when available.
# These bundle all dependencies and are conflict-free.
# =============================================================================

# -----------------------------------------------------------------------------
# NIRI: Compositor (not in original end-4, Niri-specific)
# -----------------------------------------------------------------------------
NIRI_PKGS=(
  niri
  xdg-desktop-portal-gnome
)

# -----------------------------------------------------------------------------
# METAPACKAGES: illogical-impulse bundles from AUR
# These are the PREFERRED way to install - they handle all deps correctly
# -----------------------------------------------------------------------------
II_METAPKGS=(
  illogical-impulse-quickshell-git  # Quickshell pinned + all Qt6 deps
  illogical-impulse-portal          # XDG portals
  illogical-impulse-fonts-themes    # Fonts, GTK themes, icons, cursors
  illogical-impulse-screencapture   # grim, slurp, wf-recorder, etc
  illogical-impulse-widgets         # fuzzel, hyprpicker, matugen, etc
  illogical-impulse-toolkit         # ydotool, wtype, python-evdev
  illogical-impulse-python          # Python deps for scripts
  illogical-impulse-kde             # KDE/Qt integration
)

# -----------------------------------------------------------------------------
# CORE: Polkit authentication agent
# -----------------------------------------------------------------------------
POLKIT_PKGS=(
  polkit
  mate-polkit  # authentication agent
)

# -----------------------------------------------------------------------------
# CORE: Basic utilities
# -----------------------------------------------------------------------------
BASIC_PKGS=(
  bc
  coreutils
  cliphist
  curl
  wget
  ripgrep
  jq
  xdg-user-dirs
  rsync
  git
  wl-clipboard
  libnotify
  gum  # for installer UI
)

# -----------------------------------------------------------------------------
# CORE: Audio
# -----------------------------------------------------------------------------
AUDIO_PKGS=(
  pipewire
  pipewire-pulse
  pipewire-alsa
  pipewire-jack
  wireplumber
  playerctl
  libdbusmenu-gtk3
)

# NOTE: The following are included via illogical-impulse metapackages:
# - illogical-impulse-toolkit: ydotool, wtype, python-evdev, upower
# - illogical-impulse-screencapture: grim, slurp, wf-recorder, tesseract, swappy
# - illogical-impulse-widgets: fuzzel, hyprpicker, songrec, translate-shell
# - illogical-impulse-fonts-themes: all fonts, icons, cursors, GTK themes

# =============================================================================
# THEMING CONFIGURATION
# =============================================================================
configure_gtk_theming() {
  log STEP "Configuring GTK theming"
  
  mkdir -p "$CONFIG_ROOT/gtk-3.0" "$CONFIG_ROOT/gtk-4.0"
  
  # GTK3 settings
  cat > "$CONFIG_ROOT/gtk-3.0/settings.ini" << 'EOF'
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=WhiteSur-dark
gtk-font-name=Rubik 11
gtk-cursor-theme-name=capitaine-cursors-light
gtk-cursor-theme-size=24
gtk-toolbar-style=3
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=0
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
gtk-application-prefer-dark-theme=1
gtk-decoration-layout=icon:minimize,maximize,close
gtk-enable-animations=true
gtk-modules=colorreload-gtk-module
gtk-primary-button-warps-slider=true
EOF
  log INFO "GTK3 settings configured"
  
  # GTK4 settings
  cat > "$CONFIG_ROOT/gtk-4.0/settings.ini" << 'EOF'
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=WhiteSur-dark
gtk-font-name=Rubik 11
gtk-cursor-theme-name=capitaine-cursors-light
gtk-cursor-theme-size=24
gtk-application-prefer-dark-theme=1
EOF
  log INFO "GTK4 settings configured"
  
  # Create cursor theme index for X11 compatibility
  mkdir -p "$HOME/.icons/default"
  cat > "$HOME/.icons/default/index.theme" << 'EOF'
[Icon Theme]
Name=Default
Comment=Default Cursor Theme
Inherits=capitaine-cursors-light
EOF
  
  # Apply via gsettings if available
  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme 'WhiteSur-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-theme 'capitaine-cursors-light' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-size 24 2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface font-name 'Rubik 11' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface enable-animations true 2>/dev/null || true
    log INFO "gsettings applied"
  fi
  
  # Start xsettingsd if available (for live theme updates)
  if command -v xsettingsd >/dev/null 2>&1; then
    pkill xsettingsd 2>/dev/null || true
    xsettingsd &
    log INFO "xsettingsd started"
  fi
}

setup_matugen() {
  log STEP "Setting up Matugen"
  
  local matugen_dir="$CONFIG_ROOT/matugen"
  local templates_dir="$matugen_dir/templates"
  local ii_dir="$CONFIG_ROOT/quickshell/ii"
  
  mkdir -p "$templates_dir"
  mkdir -p "$STATE_ROOT/quickshell/user/generated/wallpaper"
  
  # Copy templates from ii
  if [ -d "$ii_dir/matugen-templates" ]; then
    cp -r "$ii_dir/matugen-templates"/* "$templates_dir/" 2>/dev/null || true
    log INFO "Copied matugen templates"
  fi
  
  # Create matugen config
  cat > "$matugen_dir/config.toml" << EOF
[config]
version_check = false

[templates.m3colors]
input_path = '$templates_dir/colors.json'
output_path = '$STATE_ROOT/quickshell/user/generated/colors.json'

[templates.wallpaper]
input_path = '$templates_dir/wallpaper.txt'
output_path = '$STATE_ROOT/quickshell/user/generated/wallpaper/path.txt'
EOF
  
  log INFO "Matugen configured"
}

# =============================================================================
# MAIN INSTALLATION LOGIC
# =============================================================================
install_core() {
  log STEP "Installing core packages"
  
  log INFO "Niri compositor..."
  install_pkgs "${NIRI_PKGS[@]}"
  
  log INFO "illogical-impulse metapackages (Quickshell, fonts, tools, etc)..."
  install_pkgs "${II_METAPKGS[@]}"
  
  log INFO "Polkit authentication..."
  install_pkgs "${POLKIT_PKGS[@]}"
  
  log INFO "Basic utilities..."
  install_pkgs "${BASIC_PKGS[@]}"
  
  log INFO "Audio stack..."
  install_pkgs "${AUDIO_PKGS[@]}"
}

install_optional() {
  log STEP "Optional configuration"
  
  # Metapackages already include fonts/icons/themes, just need to configure
  if confirm "Configure GTK theming (icons, cursors, dark mode)?"; then
    configure_gtk_theming
  fi
}

setup_ii_config() {
  log STEP "Setting up ii configuration"
  
  local qs_dir="$CONFIG_ROOT/quickshell"
  local ii_dir="$qs_dir/ii"
  
  mkdir -p "$qs_dir"
  
  if [ -d "$ii_dir/.git" ]; then
    log INFO "Found existing ii config at $ii_dir"
    if confirm "Update from $REPO_URL?"; then
      git -C "$ii_dir" pull --ff-only || log WARN "Git pull failed"
    fi
  elif [ -d "$ii_dir" ]; then
    log WARN "$ii_dir exists but is not a git repo"
    if confirm "Backup and replace?"; then
      mv "$ii_dir" "$ii_dir.bak.$(date +%s)"
      git clone "$REPO_URL" "$ii_dir"
    fi
  else
    log INFO "Cloning ii config..."
    git clone "$REPO_URL" "$ii_dir"
  fi
  
  # Create required state directories
  mkdir -p "$STATE_ROOT/quickshell/user/generated/wallpaper"
  mkdir -p "$STATE_ROOT/quickshell/user"
  
  # DO NOT create first_run.txt - it triggers welcome screen on first launch
  # The file is created automatically when welcome.qml closes
  
  # Copy default config for illogical-impulse if not exists
  local ii_config_dir="$CONFIG_ROOT/illogical-impulse"
  if [ ! -f "$ii_config_dir/config.json" ]; then
    mkdir -p "$ii_config_dir"
    if [ -f "$ii_dir/defaults/config.json" ]; then
      cp "$ii_dir/defaults/config.json" "$ii_config_dir/config.json"
      log INFO "Copied default ii config"
    fi
  fi
  
  log INFO "ii config ready at $ii_dir"
}


configure_niri() {
  log STEP "Configuring Niri"
  
  local niri_dir="$CONFIG_ROOT/niri"
  local niri_config="$niri_dir/config.kdl"
  
  mkdir -p "$niri_dir"
  
  # Check if config exists
  if [ ! -f "$niri_config" ]; then
    log INFO "Creating Niri config with ii integration..."
    create_niri_config "$niri_config"
    return
  fi
  
  # Config exists - check if ii is already configured
  if grep -q 'spawn-at-startup "qs" "-c" "ii"' "$niri_config"; then
    log INFO "Niri already configured for ii"
    return
  fi
  
  # Ask to add ii binds
  if confirm "Add ii keybinds to existing Niri config?"; then
    append_ii_binds "$niri_config"
  fi
}

create_niri_config() {
  local config_file="$1"
  cat > "$config_file" << 'NIRI_EOF'
// =============================================================================
// NIRI CONFIGURATION for ii (illogical-impulse) shell
// =============================================================================
// Clean config with proper ii integration
// =============================================================================

prefer-no-csd

hotkey-overlay {
    skip-at-startup
}

screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

// =============================================================================
// INPUT
// =============================================================================

input {
    keyboard {
        xkb { }
        repeat-delay 250
        repeat-rate 50
    }
    
    touchpad {
        tap
        natural-scroll
    }
    
    mouse {
        accel-profile "flat"
    }
}

// =============================================================================
// LAYOUT - Clean, no borders (ii handles decorations)
// =============================================================================

layout {
    gaps 16
    background-color "transparent"
    center-focused-column "never"
    
    preset-column-widths {
        proportion 0.33333
        proportion 0.5
        proportion 0.66667
    }
    
    default-column-width { proportion 0.5 }
    
    border { off }
    focus-ring { off }
    shadow { off }
}

cursor {
    xcursor-theme "capitaine-cursors-light"
    xcursor-size 24
    hide-when-typing
}

// =============================================================================
// WINDOW RULES
// =============================================================================

window-rule {
    geometry-corner-radius 12
    clip-to-geometry true
}

window-rule { 
    match is-active=false
    opacity 0.95
}

// =============================================================================
// ANIMATIONS
// =============================================================================

animations {
    workspace-switch {
        spring damping-ratio=0.9 stiffness=800 epsilon=0.0001
    }
    window-open {
        spring damping-ratio=0.9 stiffness=900 epsilon=0.0001
    }
    window-close {
        spring damping-ratio=0.95 stiffness=1000 epsilon=0.0001
    }
}

// =============================================================================
// ENVIRONMENT
// =============================================================================

environment {
    XDG_CURRENT_DESKTOP "niri"
    QT_QPA_PLATFORM "wayland"
    QT_QPA_PLATFORMTHEME "gtk3"
    QT_QPA_PLATFORMTHEME_QT6 "gtk3"
    ELECTRON_OZONE_PLATFORM_HINT "auto"
}

// =============================================================================
// STARTUP
// =============================================================================

spawn-at-startup "bash" "-c" "wl-paste --watch cliphist store &"
spawn-at-startup "/usr/lib/mate-polkit/polkit-mate-authentication-agent-1"
spawn-at-startup "qs" "-c" "ii"

// =============================================================================
// KEYBINDINGS
// =============================================================================

binds {
    // ii window switcher (Alt+Tab)
    Alt+Tab {
        spawn "qs" "-c" "ii" "ipc" "call" "altSwitcher" "next"
    }
    Alt+Shift+Tab {
        spawn "qs" "-c" "ii" "ipc" "call" "altSwitcher" "previous"
    }
    
    // ii overlay
    Super+G {
        spawn "qs" "-c" "ii" "ipc" "call" "overlay" "toggle"
    }
    
    // Clipboard
    Mod+V {
        spawn "qs" "-c" "ii" "ipc" "call" "clipboard" "toggle"
    }
    
    // Lock screen
    Mod+Alt+L allow-when-locked=true {
        spawn "qs" "-c" "ii" "ipc" "call" "lock" "activate"
    }
    
    // Region tools
    Mod+Shift+S {
        spawn "qs" "-c" "ii" "ipc" "call" "region" "screenshot"
    }
    Mod+Shift+X {
        spawn "qs" "-c" "ii" "ipc" "call" "region" "ocr"
    }
    
    // Wallpaper selector
    Ctrl+Alt+T {
        spawn "qs" "-c" "ii" "ipc" "call" "wallpaperSelector" "toggle"
    }
    
    // System
    Mod+Tab repeat=false { toggle-overview; }
    Mod+Shift+E { quit; }
    Mod+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }
    
    // Window management
    Mod+Q repeat=false { close-window; }
    Mod+F { maximize-column; }
    Mod+Shift+F { fullscreen-window; }
    Mod+A { toggle-window-floating; }
    
    // Focus
    Mod+Left { focus-column-left; }
    Mod+Right { focus-column-right; }
    Mod+Up { focus-window-up; }
    Mod+Down { focus-window-down; }
    Mod+H { focus-column-left; }
    Mod+J { focus-window-down; }
    Mod+K { focus-window-up; }
    Mod+L { focus-column-right; }
    
    // Move windows
    Mod+Shift+Left { move-column-left; }
    Mod+Shift+Right { move-column-right; }
    Mod+Shift+Up { move-window-up; }
    Mod+Shift+Down { move-window-down; }
    Mod+Shift+H { move-column-left; }
    Mod+Shift+J { move-window-down; }
    Mod+Shift+K { move-window-up; }
    Mod+Shift+L { move-column-right; }
    
    // Workspaces
    Mod+1 { focus-workspace 1; }
    Mod+2 { focus-workspace 2; }
    Mod+3 { focus-workspace 3; }
    Mod+4 { focus-workspace 4; }
    Mod+5 { focus-workspace 5; }
    Mod+6 { focus-workspace 6; }
    Mod+7 { focus-workspace 7; }
    Mod+8 { focus-workspace 8; }
    Mod+9 { focus-workspace 9; }
    
    Mod+Shift+1 { move-column-to-workspace 1; }
    Mod+Shift+2 { move-column-to-workspace 2; }
    Mod+Shift+3 { move-column-to-workspace 3; }
    Mod+Shift+4 { move-column-to-workspace 4; }
    Mod+Shift+5 { move-column-to-workspace 5; }
    
    // Screenshots
    Print { screenshot; }
    Ctrl+Print { screenshot-screen; }
    Alt+Print { screenshot-window; }
    
    // Media keys
    XF86AudioRaiseVolume allow-when-locked=true {
        spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.05+"
    }
    XF86AudioLowerVolume allow-when-locked=true {
        spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.05-"
    }
    XF86AudioMute allow-when-locked=true {
        spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"
    }
}
NIRI_EOF
  log INFO "Created Niri config at $config_file"
}

append_ii_binds() {
  local config_file="$1"
  cat >> "$config_file" << 'II_BINDS'

// ii (illogical-impulse) shell integration
spawn-at-startup "qs" "-c" "ii"

binds {
    Alt+Tab { spawn "qs" "-c" "ii" "ipc" "call" "altSwitcher" "next"; }
    Alt+Shift+Tab { spawn "qs" "-c" "ii" "ipc" "call" "altSwitcher" "previous"; }
    Super+G { spawn "qs" "-c" "ii" "ipc" "call" "overlay" "toggle"; }
    Mod+V { spawn "qs" "-c" "ii" "ipc" "call" "clipboard" "toggle"; }
    Mod+Alt+L allow-when-locked=true { spawn "qs" "-c" "ii" "ipc" "call" "lock" "activate"; }
    Mod+Shift+S { spawn "qs" "-c" "ii" "ipc" "call" "region" "screenshot"; }
    Ctrl+Alt+T { spawn "qs" "-c" "ii" "ipc" "call" "wallpaperSelector" "toggle"; }
}
II_BINDS
  log INFO "Added ii binds to $config_file"
}

setup_super_daemon() {
  log STEP "Super-tap daemon"
  
  if ! confirm "Install Super-tap daemon (tap Super for overview)?"; then
    log INFO "Skipping Super-tap daemon"
    return
  fi
  
  local ii_dir="$CONFIG_ROOT/quickshell/ii"
  local systemd_dir="$CONFIG_ROOT/systemd/user"
  
  mkdir -p "$HOME/.local/bin" "$systemd_dir"
  
  if [ -f "$ii_dir/scripts/daemon/ii_super_overview_daemon.py" ]; then
    install -Dm755 "$ii_dir/scripts/daemon/ii_super_overview_daemon.py" \
      "$HOME/.local/bin/ii_super_overview_daemon.py"
  fi
  
  if [ -f "$ii_dir/scripts/systemd/ii-super-overview.service" ]; then
    install -Dm644 "$ii_dir/scripts/systemd/ii-super-overview.service" \
      "$systemd_dir/ii-super-overview.service"
  fi
  
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user daemon-reload 2>/dev/null || true
    if systemctl --user enable --now ii-super-overview.service 2>/dev/null; then
      log INFO "Super-tap daemon enabled"
    else
      log WARN "Enable manually: systemctl --user enable --now ii-super-overview.service"
    fi
  fi
}

show_completion() {
  log STEP "Installation complete!"
  
  if $USE_GUM; then
    gum style \
      --border rounded \
      --border-foreground 10 \
      --padding "1 2" \
      "Next steps:" \
      "" \
      "1. Log out of your current session" \
      "2. Select 'Niri' at the login screen" \
      "3. ii should start automatically" \
      "" \
      "Commands:" \
      "  niri msg action reload-config  # Reload Niri" \
      "  qs -c ii                        # Start ii manually"
  else
    echo
    log INFO "Next steps:"
    echo "  1. Log out of your current session"
    echo "  2. Select 'Niri' at the login screen"
    echo "  3. ii should start automatically"
    echo
    log INFO "Useful commands:"
    echo "  niri msg action reload-config  # Reload Niri config"
    echo "  qs -c ii                        # Start ii manually"
  fi
  echo
  log INFO "Issues: https://github.com/snowarch/quickshell-ii-niri"
}

# =============================================================================
# MAIN ENTRY POINT
# =============================================================================
main() {
  show_banner
  system_check
  
  # Choose installation mode
  local mode
  if $USE_GUM; then
    mode=$(choose "Select installation mode:" \
      "Full install (recommended)" \
      "Minimal (core only)" \
      "Update existing" \
      "Exit")
  else
    echo "Select installation mode:"
    echo "1) Full install (recommended)"
    echo "2) Minimal (core only)"
    echo "3) Update existing"
    echo "4) Exit"
    read -r -p "Choice [1-4]: " choice
    case "$choice" in
      1) mode="Full install (recommended)" ;;
      2) mode="Minimal (core only)" ;;
      3) mode="Update existing" ;;
      *) mode="Exit" ;;
    esac
  fi
  
  case "$mode" in
    "Full install"*)
      install_core
      install_optional
      setup_ii_config
      setup_matugen
      configure_niri
      setup_super_daemon
      ;;
    "Minimal"*)
      install_core
      setup_ii_config
      configure_niri
      ;;
    "Update"*)
      setup_ii_config
      if confirm "Update theming?"; then
        configure_gtk_theming
      fi
      if confirm "Update Niri config?"; then
        configure_niri
      fi
      ;;
    *)
      log INFO "Exiting"
      exit 0
      ;;
  esac
  
  show_completion
}

# Run main
main "$@"
