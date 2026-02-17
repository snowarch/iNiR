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
  echo -e "${STY_CYAN}[$0]: Installing missing dependencies only...${STY_RST}"

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
    # Package-level checks from doctor (no direct command binary)
    [syntax-highlighting]="syntax-highlighting"
    [kirigami]="kirigami"
    [kdialog]="kdialog"
  )

  local installflags="--needed"
  $ask || installflags="$installflags --noconfirm"

  local missing_pkgs=()
  local missing_cmds=()
  read -r -a missing_cmds <<<"$ONLY_MISSING_DEPS"
  for cmd in "${missing_cmds[@]}"; do
    local pkg="${cmd_to_pkg[$cmd]:-$cmd}"
    [[ " ${missing_pkgs[*]} " == *" ${pkg} "* ]] || missing_pkgs+=("$pkg")
  done

  if [[ ${#missing_pkgs[@]} -gt 0 ]]; then
    case $SKIP_SYSUPDATE in
      true) sleep 0;;
      *) $ask && v sudo pacman -Syu || v sudo pacman -Syu --noconfirm;;
    esac

    if ! command -v yay >/dev/null 2>&1 && ! command -v paru >/dev/null 2>&1; then
      echo -e "${STY_YELLOW}[$0]: No AUR helper found.${STY_RST}"
      showfun install-yay
      v install-yay
    fi

    if command -v yay >/dev/null 2>&1; then
      AUR_HELPER="yay"
    elif command -v paru >/dev/null 2>&1; then
      AUR_HELPER="paru"
    fi

    v $AUR_HELPER -S $installflags "${missing_pkgs[@]}"
  fi

  unset ONLY_MISSING_DEPS
  return 0
fi

#####################################################################################
# System update
#####################################################################################
case $SKIP_SYSUPDATE in
  true) sleep 0;;
  *) $ask && v sudo pacman -Syu || v sudo pacman -Syu --noconfirm;;
esac

#####################################################################################
# Ensure AUR helper
#####################################################################################
if ! command -v yay >/dev/null 2>&1 && ! command -v paru >/dev/null 2>&1; then
  echo -e "${STY_YELLOW}[$0]: No AUR helper found.${STY_RST}"
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
echo -e "${STY_CYAN}[$0]: Installing packages from local PKGBUILDs...${STY_RST}"

# Function to install deps from a PKGBUILD
install_pkgbuild_deps() {
  local pkgbuild_dir="$1"
  local pkgbuild_file="${pkgbuild_dir}/PKGBUILD"
  
  if [[ ! -f "$pkgbuild_file" ]]; then
    echo -e "${STY_YELLOW}PKGBUILD not found: $pkgbuild_file${STY_RST}"
    return 1
  fi
  
  echo -e "${STY_BLUE}Reading dependencies from: $pkgbuild_file${STY_RST}"
  
  # Source PKGBUILD to get depends array
  local depends=()
  source "$pkgbuild_file"
  
  if [[ ${#depends[@]} -eq 0 ]]; then
    echo -e "${STY_YELLOW}No dependencies in $pkgbuild_file${STY_RST}"
    return 0
  fi
  
  echo -e "${STY_GREEN}Installing: ${depends[*]}${STY_RST}"
  
  local installflags="--needed"
  $ask || installflags="$installflags --noconfirm"
  
  # Install via pacman first (for official repos)
  sudo pacman -S $installflags "${depends[@]}" 2>/dev/null || {
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
# Install official repo packages (NO COMPILATION NEEDED)
#####################################################################################
echo -e "${STY_CYAN}[$0]: Installing official repo packages...${STY_RST}"

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

  # Qt theming (works without Plasma)
  qt6ct
  kvantum

  # KDE Frameworks needed by darkly-bin Qt style (lightweight, NOT Plasma)
  frameworkintegration
  kdecoration
)

installflags="--needed"
$ask || installflags="$installflags --noconfirm"

echo -e "${STY_GREEN}[$0]: Using precompiled packages from official repos (no compilation!)${STY_RST}"
v sudo pacman -S $installflags "${OFFICIAL_PACKAGES[@]}"

#####################################################################################
# Install AUR packages (only those not in official repos)
#####################################################################################
echo -e "${STY_CYAN}[$0]: Installing AUR packages...${STY_RST}"

AUR_PACKAGES=(
  # Qt6 extras (not in official repos)
  google-breakpad
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
  
  echo -e "${STY_BLUE}Downloading $font_name from fallback URL...${STY_RST}"
  if curl -fsSL -o "$font_dir/${font_name}.ttf" "$url" 2>/dev/null; then
    fc-cache -f "$font_dir" 2>/dev/null
    echo -e "${STY_GREEN}Installed $font_name from fallback${STY_RST}"
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
  echo -e "${STY_BLUE}[$0]: Installing ${#AUR_PACKAGES[@]} AUR packages...${STY_RST}"
  v $AUR_HELPER -S $installflags "${AUR_PACKAGES[@]}" || {
    echo -e "${STY_YELLOW}[$0]: Some AUR packages failed. Trying individually...${STY_RST}"
    for pkg in "${AUR_PACKAGES[@]}"; do
      $AUR_HELPER -S $installflags "$pkg" 2>/dev/null || \
        echo -e "${STY_YELLOW}[$0]: Could not install $pkg (non-critical)${STY_RST}"
    done
  }
fi

# Install fonts separately with proper error handling
if $INSTALL_FONTS; then
  echo -e "${STY_CYAN}[$0]: Installing critical fonts...${STY_RST}"
  
  # Critical fonts - must succeed
  for font in "${CRITICAL_FONTS[@]}"; do
    if ! $AUR_HELPER -S $installflags "$font" 2>/dev/null; then
      echo -e "${STY_RED}CRITICAL: Failed to install $font. UI icons may not work.${STY_RST}"
      echo -e "${STY_YELLOW}Try installing manually: $AUR_HELPER -S $font${STY_RST}"
    fi
  done
  
  echo -e "${STY_CYAN}[$0]: Installing optional fonts...${STY_RST}"
  
  # Optional fonts - try AUR first, then fallback
  for font in "${OPTIONAL_FONTS[@]}"; do
    if ! $AUR_HELPER -S $installflags "$font" 2>/dev/null; then
      echo -e "${STY_YELLOW}AUR package $font not available, trying fallback...${STY_RST}"
      if ! install_font_fallback "$font"; then
        echo -e "${STY_YELLOW}Could not install $font. System will use fallback fonts.${STY_RST}"
      fi
    fi
  done
fi

#####################################################################################
# Optional: Python environment setup
#####################################################################################
showfun install-python-packages
v install-python-packages

echo -e "${STY_GREEN}[$0]: Dependencies installed successfully.${STY_RST}"
