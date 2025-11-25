#!/usr/bin/env bash
# =============================================================================
# illogical-impulse (ii) on Niri - Installer
# =============================================================================
# This script installs ii and all its dependencies on Arch-based systems.
# Based on the dependency structure from end-4/dots-hyprland, adapted for Niri.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/snowarch/quickshell-ii-niri/main/install.sh | bash
# =============================================================================

set -euo pipefail

bold="" reset="" green="" yellow="" red="" cyan=""
if command -v tput >/dev/null 2>&1; then
  bold="$(tput bold || true)"
  reset="$(tput sgr0 || true)"
  green="$(tput setaf 2 || true)"
  yellow="$(tput setaf 3 || true)"
  red="$(tput setaf 1 || true)"
  cyan="$(tput setaf 6 || true)"
fi

log() {
  local level="$1"; shift
  case "$level" in
    INFO)  printf '%s[INFO]%s %s\n'  "$bold$green" "$reset" "$*" ;;
    WARN)  printf '%s[WARN]%s %s%s%s\n' "$bold$yellow" "$reset" "$yellow" "$*" "$reset" ;;
    ERR)   printf '%s[ERR]%s %s%s%s\n'  "$bold$red" "$reset" "$red" "$*" "$reset" ;;
    STEP)  printf '\n%s==> %s%s\n' "$bold$cyan" "$*" "$reset" ;;
    *)     printf '[%s] %s\n' "$level" "$*" ;;
  esac
}

ask_yes_no() {
  local prompt="$1" default="$2" reply
  local suffix="[y/N]"
  case "$default" in
    y|Y) suffix="[Y/n]" ;;
    n|N) suffix="[y/N]" ;;
  esac
  # Non-interactive / test mode: auto-pick the default answer.
  if [ "${II_INSTALLER_ASSUME_DEFAULTS:-}" = "1" ]; then
    printf '%s %s (auto-choosing %s)\n' "$prompt" "$suffix" "$default"
    case "$default" in
      y|Y) return 0 ;;
      n|N) return 1 ;;
    esac
  fi

  while true; do
    printf '%s %s ' "$prompt" "$suffix"
    if [ -t 0 ]; then
      # Normal interactive shell: read from stdin.
      read -r reply || reply=""
    elif [ -r /dev/tty ]; then
      # When run via a pipe (e.g. curl ... | bash), stdin is not a TTY.
      # Read answers from the controlling terminal instead.
      read -r reply < /dev/tty || reply=""
    else
      # Non-interactive environment with no TTY: fall back to default.
      echo
      reply="$default"
    fi
    reply="${reply:-$default}"
    case "$reply" in
      y|Y) return 0 ;;
      n|N) return 1 ;;
    esac
    echo "Please answer y or n."
  done
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1
}

pacman_has_pkg() {
  pacman -Si "$1" >/dev/null 2>&1
}

ensure_yay() {
  if command -v yay >/dev/null 2>&1; then
    return 0
  fi

  log INFO 'Installing "yay" (AUR helper) to handle repo + AUR packages.'
  sudo pacman -S --needed base-devel git

  local tmpdir
  tmpdir="$(mktemp -d)"
  (
    cd "$tmpdir"
    git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin
    makepkg -si --noconfirm
  )
  rm -rf "$tmpdir"
}

install_aur_pkgs() {
  local pkgs=("$@")
  [ ${#pkgs[@]} -eq 0 ] && return 0

  ensure_yay
  if ! yay -S --needed --noconfirm "${pkgs[@]}"; then
    log WARN "Some AUR packages failed to install."
  fi
}

log STEP "illogical-impulse (ii) on Niri - Installer"
log INFO "Based on end-4/dots-hyprland dependency structure"

if ! require_cmd pacman; then
  log ERR "This installer currently supports only Arch-based distros (pacman)."
  exit 1
fi

if ! require_cmd sudo; then
  log ERR "This script needs sudo for pacman. Install sudo first."
  exit 1
fi

# =============================================================================
# PACKAGE DEFINITIONS
# =============================================================================
# Based on illogical-impulse meta-packages from end-4/dots-hyprland
# Adapted for Niri (removed Hyprland-specific packages)
# =============================================================================

# -----------------------------------------------------------------------------
# CORE: Niri compositor
# -----------------------------------------------------------------------------
NIRI_PKGS=(
  niri
)

# -----------------------------------------------------------------------------
# CORE: Quickshell dependencies (from illogical-impulse-quickshell-git PKGBUILD)
# These are the Qt6 and system libs that Quickshell needs
# -----------------------------------------------------------------------------
QUICKSHELL_DEPS=(
  qt6-declarative
  qt6-base
  jemalloc
  qt6-svg
  libpipewire
  libxcb
  wayland
  libdrm
  mesa
  # Qt6 extras needed by ii
  qt6-5compat
  qt6-imageformats
  qt6-multimedia
  qt6-positioning
  qt6-quicktimeline
  qt6-sensors
  qt6-tools
  qt6-translations
  qt6-virtualkeyboard
  qt6-wayland
  # KDE/Qt integration
  kirigami
  kdialog
  syntax-highlighting
  # Build deps that become runtime deps
  polkit
)

# AUR packages for Quickshell (CRITICAL: quickshell-git, NOT quickshell)
QUICKSHELL_AUR=(
  google-breakpad
  qt6-avif-image-plugin
  quickshell-git
)

# -----------------------------------------------------------------------------
# CORE: Basic utilities (from illogical-impulse-basic)
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
)

# -----------------------------------------------------------------------------
# CORE: XDG portals for Niri
# -----------------------------------------------------------------------------
PORTAL_PKGS=(
  xdg-desktop-portal
  xdg-desktop-portal-gtk
  xdg-desktop-portal-gnome
)

# -----------------------------------------------------------------------------
# CORE: Audio dependencies (from illogical-impulse-audio)
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

# -----------------------------------------------------------------------------
# OPTIONAL: Toolkit for input simulation (from illogical-impulse-toolkit)
# -----------------------------------------------------------------------------
TOOLKIT_PKGS=(
  upower
  wtype
  ydotool
  python-evdev
)

# -----------------------------------------------------------------------------
# OPTIONAL: Screenshot and recording (from illogical-impulse-screencapture)
# -----------------------------------------------------------------------------
SCREENCAPTURE_PKGS=(
  grim
  slurp
  swappy
  tesseract
  tesseract-data-eng
  wf-recorder
  imagemagick
)

# -----------------------------------------------------------------------------
# OPTIONAL: Widget dependencies
# -----------------------------------------------------------------------------
WIDGET_PKGS=(
  fuzzel
  glib2
  hyprpicker
  songrec
  translate-shell
)

# -----------------------------------------------------------------------------
# OPTIONAL: Fonts and theming (from illogical-impulse-fonts-themes)
# -----------------------------------------------------------------------------
FONTS_PKGS=(
  fontconfig
)

FONTS_AUR=(
  matugen-bin
  otf-space-grotesk
  ttf-jetbrains-mono-nerd
  ttf-material-symbols-variable-git
  ttf-readex-pro
  ttf-rubik-vf
  ttf-gabarito
)

# -----------------------------------------------------------------------------
# OPTIONAL: Python dependencies
# -----------------------------------------------------------------------------
PYTHON_PKGS=(
  python-pillow
  python-opencv
)

# -----------------------------------------------------------------------------
# OPTIONAL: Icon themes
# -----------------------------------------------------------------------------
ICON_THEMES_AUR=(
  whitesur-icon-theme-git
  capitaine-cursors
)

# =============================================================================
# INSTALLATION HELPERS
# =============================================================================

install_pacman_pkgs() {
  local pkgs=("$@")
  [ ${#pkgs[@]} -eq 0 ] && return 0

  local available=() missing=() pkg
  for pkg in "${pkgs[@]}"; do
    if pacman_has_pkg "$pkg"; then
      available+=("$pkg")
    else
      missing+=("$pkg")
    fi
  done

  if [ ${#available[@]} -gt 0 ]; then
    if ! sudo pacman -S --needed --noconfirm "${available[@]}"; then
      log WARN "Some packages failed to install."
    fi
  fi

  if [ ${#missing[@]} -gt 0 ]; then
    log WARN "Packages not found in repos (skipped): ${missing[*]}"
  fi
}

# =============================================================================
# MAIN INSTALLATION LOGIC
# =============================================================================

log STEP "Installing core dependencies..."

log INFO "Installing Niri compositor..."
install_pacman_pkgs "${NIRI_PKGS[@]}"

log INFO "Installing Quickshell dependencies (Qt6, Wayland, etc.)..."
install_pacman_pkgs "${QUICKSHELL_DEPS[@]}"

log INFO "Installing basic utilities..."
install_pacman_pkgs "${BASIC_PKGS[@]}"

log INFO "Installing XDG portals..."
install_pacman_pkgs "${PORTAL_PKGS[@]}"

log INFO "Installing audio stack..."
install_pacman_pkgs "${AUDIO_PKGS[@]}"

log INFO "Installing Quickshell from AUR (this may take a while)..."
log INFO "NOTE: quickshell-git is required, NOT the official quickshell package."
install_aur_pkgs "${QUICKSHELL_AUR[@]}"

log STEP "Optional components..."

if ask_yes_no "Install toolkit (ydotool, wtype, evdev for input simulation)?" "y"; then
  log INFO "Installing toolkit..."
  install_pacman_pkgs "${TOOLKIT_PKGS[@]}"
fi

if ask_yes_no "Install screenshot/recording tools (grim, slurp, wf-recorder, OCR)?" "y"; then
  log INFO "Installing screenshot/recording tools..."
  install_pacman_pkgs "${SCREENCAPTURE_PKGS[@]}"
fi

if ask_yes_no "Install widget dependencies (fuzzel, hyprpicker, songrec)?" "y"; then
  log INFO "Installing widget dependencies..."
  install_pacman_pkgs "${WIDGET_PKGS[@]}"
fi

if ask_yes_no "Install fonts and theming (Matugen, JetBrains Mono, Material Symbols)?" "y"; then
  log INFO "Installing fonts and theming..."
  install_pacman_pkgs "${FONTS_PKGS[@]}"
  install_aur_pkgs "${FONTS_AUR[@]}"
fi

if ask_yes_no "Install Python dependencies (for evdev daemon)?" "y"; then
  log INFO "Installing Python dependencies..."
  install_pacman_pkgs "${PYTHON_PKGS[@]}"
fi

if ask_yes_no "Install icon themes (WhiteSur, Capitaine cursors)?" "n"; then
  log INFO "Installing icon themes..."
  install_aur_pkgs "${ICON_THEMES_AUR[@]}"
fi

log STEP "Setting up ii configuration..."

CONFIG_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}"
QS_DIR="$CONFIG_ROOT/quickshell"
II_DIR="$QS_DIR/ii"
REPO_URL="${REPO_URL:-https://github.com/snowarch/quickshell-ii-niri.git}"

mkdir -p "$QS_DIR"

if [ -d "$II_DIR/.git" ]; then
  log INFO "Found existing ii git repo at $II_DIR."
  if ask_yes_no "Update it from $REPO_URL?" "y"; then
    git -C "$II_DIR" pull --ff-only
  else
    log INFO "Leaving existing ii config as-is."
  fi
else
  if [ -d "$II_DIR" ] && [ ! -d "$II_DIR/.git" ]; then
    log WARN "$II_DIR exists but is not a git clone. Leaving it untouched."
  else
    log INFO "Cloning ii config into $II_DIR."
    git clone "$REPO_URL" "$II_DIR"
  fi
fi


log STEP "Configuring Niri..."

NIRI_CONFIG="$CONFIG_ROOT/niri/config.kdl"
if [ -f "$NIRI_CONFIG" ]; then
  # Add spawn-at-startup for ii
  if grep -q 'spawn-at-startup "qs" "-c" "ii"' "$NIRI_CONFIG"; then
    log INFO "Niri already starts ii at login."
  else
    if ask_yes_no "Add ii startup and keybinds to $NIRI_CONFIG?" "y"; then
      {
        echo
        echo "// ============================================================================"
        echo "// illogical-impulse (ii) shell configuration"
        echo "// ============================================================================"
        echo
        echo "spawn-at-startup \"qs\" \"-c\" \"ii\""
        echo
        echo "binds {"
        echo "    // Alt+Tab window switcher (ii AltSwitcher)"
        echo "    Alt+Tab {"
        echo "        spawn \"qs\" \"-c\" \"ii\" \"ipc\" \"call\" \"altSwitcher\" \"next\";"
        echo "    }"
        echo "    Alt+Shift+Tab {"
        echo "        spawn \"qs\" \"-c\" \"ii\" \"ipc\" \"call\" \"altSwitcher\" \"previous\";"
        echo "    }"
        echo
        echo "    // ii overlay toggle"
        echo "    Super+G hotkey-overlay-title=\"Toggle ii Overlay\" {"
        echo "        spawn \"qs\" \"-c\" \"ii\" \"ipc\" \"call\" \"overlay\" \"toggle\";"
        echo "    }"
        echo
        echo "    // Clipboard manager"
        echo "    Mod+V hotkey-overlay-title=\"Clipboard Manager\" {"
        echo "        spawn \"qs\" \"-c\" \"ii\" \"ipc\" \"call\" \"clipboard\" \"toggle\";"
        echo "    }"
        echo
        echo "    // Lock screen"
        echo "    Mod+Alt+L allow-when-locked=true hotkey-overlay-title=\"Lock Screen\" {"
        echo "        spawn \"qs\" \"-c\" \"ii\" \"ipc\" \"call\" \"lock\" \"activate\";"
        echo "    }"
        echo
        echo "    // Region tools"
        echo "    Mod+Shift+S hotkey-overlay-title=\"Region Screenshot\" {"
        echo "        spawn \"qs\" \"-c\" \"ii\" \"ipc\" \"call\" \"region\" \"screenshot\";"
        echo "    }"
        echo "    Mod+Shift+A hotkey-overlay-title=\"Region Search\" {"
        echo "        spawn \"qs\" \"-c\" \"ii\" \"ipc\" \"call\" \"region\" \"search\";"
        echo "    }"
        echo "    Mod+Shift+X hotkey-overlay-title=\"Region OCR\" {"
        echo "        spawn \"qs\" \"-c\" \"ii\" \"ipc\" \"call\" \"region\" \"ocr\";"
        echo "    }"
        echo
        echo "    // Wallpaper selector"
        echo "    Ctrl+Alt+T hotkey-overlay-title=\"Wallpaper Selector\" {"
        echo "        spawn \"qs\" \"-c\" \"ii\" \"ipc\" \"call\" \"wallpaperSelector\" \"toggle\";"
        echo "    }"
        echo "}"
      } >> "$NIRI_CONFIG"
      log INFO "Added ii configuration and keybinds to $NIRI_CONFIG."
    else
      log INFO "Skipped editing $NIRI_CONFIG. Add the spawn line and keybinds manually if needed."
    fi
  fi
else
  log WARN "Could not find $NIRI_CONFIG."
  log WARN "Create your Niri config and add these lines:"
  echo '  spawn-at-startup "qs" "-c" "ii"'
  echo
  echo "  binds {"
  echo '    Alt+Tab { spawn "qs" "-c" "ii" "ipc" "call" "altSwitcher" "next"; }'
  echo '    Alt+Shift+Tab { spawn "qs" "-c" "ii" "ipc" "call" "altSwitcher" "previous"; }'
  echo '    Super+G { spawn "qs" "-c" "ii" "ipc" "call" "overlay" "toggle"; }'
  echo '    Mod+V { spawn "qs" "-c" "ii" "ipc" "call" "clipboard" "toggle"; }'
  echo "  }"
fi

log STEP "Super-tap daemon..."

if ask_yes_no "Install Super-tap daemon (tap Super key to toggle overview)?" "y"; then
  log INFO "Installing Super-tap daemon files."
  CONFIG_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}"
  SYSTEMD_USER_DIR="$CONFIG_ROOT/systemd/user"

  mkdir -p "$HOME/.local/bin" "$SYSTEMD_USER_DIR"

  install -Dm755 "$II_DIR/scripts/daemon/ii_super_overview_daemon.py" \
    "$HOME/.local/bin/ii_super_overview_daemon.py"

  install -Dm644 "$II_DIR/scripts/systemd/ii-super-overview.service" \
    "$SYSTEMD_USER_DIR/ii-super-overview.service"

  if command -v systemctl >/dev/null 2>&1; then
    if systemctl --user daemon-reload 2>/dev/null; then
      if ! systemctl --user enable --now ii-super-overview.service 2>/dev/null; then
        log WARN "Could not enable ii-super-overview.service automatically. After logging into a graphical session, run:"
        echo "  systemctl --user enable --now ii-super-overview.service"
      else
        log INFO "Super-tap daemon enabled as a user service (ii-super-overview.service)."
      fi
    else
      log WARN "systemctl --user is not available in this shell. Once in a graphical session, enable the service with:"
      echo "  systemctl --user enable --now ii-super-overview.service"
    fi
  else
    log WARN "systemctl not found; install systemd user session support to manage ii-super-overview.service."
  fi
else
  log INFO "Skipping Super-tap daemon installation. You can still add it later from scripts/daemon and scripts/systemd."
fi

log STEP "Installation complete!"

echo
log INFO "Next steps:"
echo "  1. Log out of your current session"
echo "  2. Select 'Niri' at the login screen"
echo "  3. ii should start automatically"
echo
log INFO "If you need to reload Niri config:"
echo "  niri msg action reload-config"
echo
log INFO "To manually start ii:"
echo "  qs -c ii"
echo
log INFO "For issues, see: https://github.com/snowarch/quickshell-ii-niri"
