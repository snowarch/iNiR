# Install dependencies for iNiR on Arch-based systems
# This script is meant to be sourced, not run directly.

# shellcheck shell=bash

#####################################################################################
# Verify we're on Arch
#####################################################################################
if ! command -v pacman >/dev/null 2>&1; then
  printf "${STY_RED}[$0]: pacman not found. This script is for Arch-based systems only.${STY_RST}\n"
  exit 1
fi

#####################################################################################
# Optional: install only a specific list of missing deps
#####################################################################################
if [[ -n "${ONLY_MISSING_DEPS:-}" ]]; then
  tui_info "Installing missing dependencies only..."

  # doctor reports command IDs; map them to Arch package names.
  declare -A cmd_to_pkg=(
    [qs]="quickshell"
    [niri]="niri"
    [nmcli]="networkmanager"
    [wpctl]="wireplumber"
    [jq]="jq"
    [rsync]="rsync"
    [curl]="curl"
    [git]="git"
    [python3]="python"
    [matugen]="matugen"
    [wlsunset]="wlsunset"
    [dunstify]="dunst"
    [fish]="fish"
    [magick]="imagemagick"
    [swaylock]="swaylock"
    [swayidle]="swayidle"
    [grim]="grim"
    [mpv]="mpv"
    [cliphist]="cliphist"
    [wl-copy]="wl-clipboard"
    [wl-paste]="wl-clipboard"
    [fuzzel]="fuzzel"
    [hyprpicker]="hyprpicker"
    [songrec]="songrec"
    [trans]="translate-shell"
    # Package-level checks from doctor (no direct command binary)
    [syntax-highlighting]="syntax-highlighting"
    [kirigami]="kirigami"
    [kdialog]="kdialog"
  )

  _miss_installflags="--needed"
  $ask || _miss_installflags="$_miss_installflags --noconfirm"

  _miss_pkgs=()
  _miss_cmds=()
  read -r -a _miss_cmds <<<"$ONLY_MISSING_DEPS"
  for cmd in "${_miss_cmds[@]}"; do
    _miss_pkg="${cmd_to_pkg[$cmd]:-$cmd}"
    [[ " ${_miss_pkgs[*]} " == *" ${_miss_pkg} "* ]] || _miss_pkgs+=("$_miss_pkg")
  done

  if [[ ${#_miss_pkgs[@]} -gt 0 ]]; then
    case $SKIP_SYSUPDATE in
      true) sleep 0;;
      *) $ask && v pkg_sudo pacman -Syu || v pkg_sudo pacman -Syu --noconfirm;;
    esac

    if ! command -v yay >/dev/null 2>&1 && ! command -v paru >/dev/null 2>&1; then
      log_warning "No AUR helper found"
      showfun install-yay
      v install-yay
    fi

    if command -v yay >/dev/null 2>&1; then
      AUR_HELPER="yay"
    elif command -v paru >/dev/null 2>&1; then
      AUR_HELPER="paru"
    fi

    v $AUR_HELPER -S $_miss_installflags "${_miss_pkgs[@]}"
  fi

  unset ONLY_MISSING_DEPS
  return 0
fi

#####################################################################################
# System update
#####################################################################################
case $SKIP_SYSUPDATE in
  true) sleep 0;;
  *) $ask && v pkg_sudo pacman -Syu || v pkg_sudo pacman -Syu --noconfirm;;
esac

#####################################################################################
# Ensure AUR helper
#####################################################################################
if ! command -v yay >/dev/null 2>&1 && ! command -v paru >/dev/null 2>&1; then
  log_warning "No AUR helper found"
  showfun install-yay
  v install-yay
fi

# Set AUR helper
if command -v yay >/dev/null 2>&1; then
  AUR_HELPER="yay"
elif command -v paru >/dev/null 2>&1; then
  AUR_HELPER="paru"
fi

#####################################################################################
# Install packages from PKGBUILDs (read depends and install them)
#####################################################################################
tui_info "Installing packages from PKGBUILDs..."

# Function to install deps from a PKGBUILD
install_pkgbuild_deps() {
  local pkgbuild_dir="$1"
  local pkgbuild_file="${pkgbuild_dir}/PKGBUILD"
  
  if [[ ! -f "$pkgbuild_file" ]]; then
    log_warning "PKGBUILD not found: $pkgbuild_file"
    return 1
  fi
  
  log_info "Reading: $pkgbuild_file"
  
  # Source PKGBUILD to get depends array
  local depends=()
  source "$pkgbuild_file"
  
  if [[ ${#depends[@]} -eq 0 ]]; then
    log_warning "No dependencies in $(basename $pkgbuild_file)"
    return 0
  fi
  
  log_info "Installing: ${depends[*]}"
  
  local installflags="--needed"
  $ask || installflags="$installflags --noconfirm"
  
  # Install via pacman first (for official repos)
  pkg_sudo pacman -S $installflags "${depends[@]}" 2>/dev/null || {
    # Some packages may be AUR-only, try with AUR helper
    $AUR_HELPER -S $installflags "${depends[@]}"
  }
}

# Install from each PKGBUILD
for pkgdir in ./sdata/dist-arch/inir-*/; do
  # Check group flags
  pkgname=$(basename "$pkgdir")
  case "$pkgname" in
    inir-audio) $INSTALL_AUDIO || continue ;;
    inir-toolkit) $INSTALL_TOOLKIT || continue ;;
    inir-screencapture) $INSTALL_SCREENCAPTURE || continue ;;
    inir-fonts) $INSTALL_FONTS || continue ;;
  esac
  
  v install_pkgbuild_deps "$pkgdir"
done

#####################################################################################
# Pre-install: resolve quickshell package conflicts
# quickshell-git and quickshell-bin conflict with quickshell (official extra repo).
# pacman --noconfirm does NOT auto-remove conflicting packages — it aborts instead.
#####################################################################################
for qs_conflict in quickshell-git quickshell-bin; do
  if pacman -Qi "$qs_conflict" &>/dev/null 2>&1; then
    log_warning "$qs_conflict is installed and conflicts with quickshell (stable, extra repo)"
    if $ask; then
      if tui_confirm "Replace $qs_conflict with quickshell (stable)? (recommended)"; then
        log_info "Removing $qs_conflict..."
        v pkg_sudo pacman -Rdd --noconfirm "$qs_conflict" 2>/dev/null \
          || v pkg_sudo pacman -R --noconfirm "$qs_conflict" \
          || log_warning "Could not remove $qs_conflict — install may fail"
      else
        log_warning "Keeping $qs_conflict — removing quickshell from install list"
        OFFICIAL_PACKAGES=("${OFFICIAL_PACKAGES[@]/quickshell/}")
      fi
    else
      log_info "Non-interactive: replacing $qs_conflict with quickshell (stable)"
      pkg_sudo pacman -Rdd --noconfirm "$qs_conflict" 2>/dev/null \
        || pkg_sudo pacman -R --noconfirm "$qs_conflict" 2>/dev/null \
        || log_warning "Could not remove $qs_conflict — install may fail"
    fi
  fi
done

#####################################################################################
# Install official repo packages (NO COMPILATION NEEDED)
#####################################################################################
tui_info "Installing official repo packages..."

# These packages are now in official Arch repos (extra) - NO AUR, NO COMPILATION!
OFFICIAL_PACKAGES=(
  # Quickshell (CRITICAL) - NOW IN EXTRA REPO!
  quickshell

  # Critical QML/KDE runtime modules (required for shell startup)
  syntax-highlighting
  kirigami
  kdialog
  
  # Already in PKGBUILDs but ensure they're installed
  niri
  cliphist
  gum
  starship
  xwayland-satellite
  
  # Theming
  matugen
  
  # Emoji font (CRITICAL — overview search, notifications, etc.)
  noto-fonts-emoji
  
  # File manager
  nautilus
  
  # Polkit agent (needed for auth dialogs — gnome agent works universally)
  polkit-gnome
  
  # Icon themes - fallbacks from official repos (always available)
  hicolor-icon-theme
  adwaita-icon-theme
  papirus-icon-theme
  breeze-icons

  # Qt theming (works without Plasma desktop)
  qt6ct
  kvantum
  plasma-integration   # Provides QT_QPA_PLATFORMTHEME=kde plugin (reads kdeglobals colors)

  # KDE Frameworks needed by darkly-bin Qt style (lightweight, NOT Plasma)
  frameworkintegration
  kdecoration

  # SDDM login screen (users without another DE need this to log in)
  sddm
  qt6-svg
  qt6-virtualkeyboard
  qt6-multimedia-ffmpeg

  # Video wallpaper support (thumbnail + SDDM background extraction)
  ffmpeg
)

installflags="--needed"
$ask || installflags="$installflags --noconfirm"

log_info "Using precompiled packages from official repos (no compilation)"
v pkg_sudo pacman -S $installflags "${OFFICIAL_PACKAGES[@]}"

#####################################################################################
# Install AUR packages (only those not in official repos)
#####################################################################################
tui_info "Installing AUR packages..."

AUR_PACKAGES=(
  # Qt6 extras (not in official repos)
  qt6-avif-image-plugin
  
  # Note: Python deps are handled via uv + requirements.txt, not AUR packages
)

# Critical fonts (UI breaks without these)
CRITICAL_FONTS=(
  ttf-material-symbols-variable-git
  ttf-jetbrains-mono-nerd
  ttf-roboto-flex
  ttf-oxanium
)

# Optional fonts (have system fallbacks)
OPTIONAL_FONTS=(
  otf-space-grotesk
  ttf-readex-pro
  ttf-rubik-vf
  ttf-twemoji
)

# Direct download URLs for optional fonts (from official GitHub repos)
# These are used as fallback when AUR packages are unavailable
declare -A FONT_FALLBACK_URLS=(
  ["otf-space-grotesk"]="https://github.com/floriankarsten/space-grotesk/raw/master/fonts/ttf/SpaceGrotesk%5Bwght%5D.ttf"
  ["ttf-readex-pro"]="https://raw.githubusercontent.com/ThomasJockin/readexpro/master/fonts/variable/Readexpro%5BHEXP%2Cwght%5D.ttf"
  ["ttf-rubik-vf"]="https://github.com/googlefonts/rubik/raw/main/fonts/variable/Rubik%5Bwght%5D.ttf"
  ["ttf-oxanium"]="https://github.com/google/fonts/raw/main/ofl/oxanium/Oxanium%5Bwght%5D.ttf"
)

# Function to install font from direct URL
install_font_fallback() {
  local font_name="$1"
  local url="${FONT_FALLBACK_URLS[$font_name]}"
  
  if [[ -z "$url" ]]; then
    return 1
  fi
  
  local font_dir="$HOME/.local/share/fonts"
  mkdir -p "$font_dir"
  
  log_info "Downloading $font_name from fallback URL..."
  if curl -fsSL -o "$font_dir/${font_name}.ttf" "$url" 2>/dev/null; then
    fc-cache -f "$font_dir" 2>/dev/null
    log_success "Installed $font_name from fallback"
    return 0
  fi
  return 1
}

# Add other AUR packages based on flags
if $INSTALL_FONTS; then
  AUR_PACKAGES+=(
    adw-gtk-theme         # Official repo version if available, else AUR
    capitaine-cursors
    whitesur-icon-theme   # Try non-git version first
    darkly-bin
  )
fi

if $INSTALL_AUDIO; then
  : # cava moved to inir-audio PKGBUILD
fi

if $INSTALL_TOOLKIT; then
  AUR_PACKAGES+=(uv)
fi

# Reset installflags for AUR helper
installflags="--needed"
$ask || installflags="$installflags --noconfirm"

# Install main AUR packages (these are the only ones that need AUR)
if [[ ${#AUR_PACKAGES[@]} -gt 0 ]]; then
  log_info "Installing ${#AUR_PACKAGES[@]} AUR packages..."
  v $AUR_HELPER -S $installflags "${AUR_PACKAGES[@]}" || {
    log_warning "Some AUR packages failed — trying individually..."
    for pkg in "${AUR_PACKAGES[@]}"; do
      $AUR_HELPER -S $installflags "$pkg" 2>/dev/null || \
        log_warning "Could not install $pkg (non-critical)"
    done
  }
fi

# Install fonts separately with proper error handling
if $INSTALL_FONTS; then
  tui_info "Installing critical fonts..."
  
  # Critical fonts - must succeed
  for font in "${CRITICAL_FONTS[@]}"; do
    if ! $AUR_HELPER -S $installflags "$font" 2>/dev/null; then
      log_error "CRITICAL: Failed to install $font — UI icons may not work!"
      log_warning "Try: $AUR_HELPER -S $font"
    fi
  done
  
  tui_info "Installing optional fonts..."
  
  # Optional fonts - try AUR first, then fallback
  for font in "${OPTIONAL_FONTS[@]}"; do
    if ! $AUR_HELPER -S $installflags "$font" 2>/dev/null; then
      log_info "$font not in AUR, trying direct download..."
      if ! install_font_fallback "$font"; then
        log_warning "$font unavailable — system will use fallback fonts"
      fi
    fi
  done
fi

#####################################################################################
# Optional: Python environment setup
#####################################################################################
showfun install-python-packages
v install-python-packages

log_success "Dependencies installed"
