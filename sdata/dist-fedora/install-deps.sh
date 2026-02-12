# Install dependencies for iNiR on Fedora-based systems
# This script is meant to be sourced, not run directly.

# shellcheck shell=bash

#####################################################################################
# Verify we're on Fedora
#####################################################################################
if ! command -v dnf >/dev/null 2>&1; then
  printf "${STY_RED}[$0]: dnf not found. This script is for Fedora-based systems only.${STY_RST}\n"
  exit 1
fi

# Check for immutable variants
if is_immutable_distro 2>/dev/null; then
  printf "${STY_YELLOW}[$0]: Detected immutable Fedora variant (${OS_SPECIFIC_ID}).${STY_RST}\n"
  printf "${STY_YELLOW}[$0]: You may need to use rpm-ostree or toolbox for some packages.${STY_RST}\n"
  printf "${STY_YELLOW}[$0]: Consider using Flatpak for applications where available.${STY_RST}\n"
  echo ""
fi

# Detect Fedora version
FEDORA_VERSION=$(rpm -E %fedora)
echo -e "${STY_CYAN}[$0]: Detected Fedora ${FEDORA_VERSION}${STY_RST}"

#####################################################################################
# System update (optional)
#####################################################################################
case ${SKIP_SYSUPDATE:-false} in
  true) 
    echo -e "${STY_CYAN}[$0]: Skipping system update${STY_RST}"
    ;;
  *) 
    echo -e "${STY_CYAN}[$0]: Updating system...${STY_RST}"
    v sudo dnf upgrade -y --refresh
    ;;
esac

#####################################################################################
# Enable required COPR repositories
#####################################################################################
echo -e "${STY_CYAN}[$0]: Enabling COPR repositories...${STY_RST}"

# Quickshell (CRITICAL) - PRECOMPILED from errornointernet COPR (no compilation needed!)
if ! dnf copr list --enabled 2>/dev/null | grep -q "errornointernet/quickshell"; then
  echo -e "${STY_BLUE}[$0]: Enabling Quickshell COPR (precompiled packages)...${STY_RST}"
  v sudo dnf copr enable -y errornointernet/quickshell || {
    echo -e "${STY_RED}[$0]: Failed to enable Quickshell COPR. You may need to install manually.${STY_RST}"
    echo -e "${STY_YELLOW}See: https://copr.fedorainfracloud.org/coprs/errornointernet/quickshell/${STY_RST}"
  }
fi

# Niri compositor
if ! dnf copr list --enabled 2>/dev/null | grep -q "yalter/niri"; then
  echo -e "${STY_BLUE}[$0]: Enabling Niri COPR...${STY_RST}"
  v sudo dnf copr enable -y yalter/niri
fi

#####################################################################################
# Enable RPM Fusion (for ffmpeg, etc.)
#####################################################################################
echo -e "${STY_CYAN}[$0]: Enabling RPM Fusion repositories...${STY_RST}"

if ! rpm -q rpmfusion-free-release &>/dev/null; then
  v sudo dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm"
fi

if ! rpm -q rpmfusion-nonfree-release &>/dev/null; then
  v sudo dnf install -y \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm"
fi

#####################################################################################
# Install official repository packages
#####################################################################################
echo -e "${STY_CYAN}[$0]: Installing packages from repositories...${STY_RST}"

  # Core system packages (including Quickshell and Niri from COPR)
FEDORA_CORE_PKGS=(
  # Quickshell (from COPR - no compilation needed!)
  quickshell

  # Niri compositor (from COPR)
  niri

  # zoxide - smart cd replacement
  zoxide
  
  # Build tools (needed for Python packages like dbus-python, pycairo, pygobject)
  gcc
  gcc-c++
  make
  meson
  ninja-build
  cmake
  pkg-config
  python3-devel
  dbus-devel
  cairo-devel
  cairo-gobject-devel
  gobject-introspection-devel
  gtk3-devel
  glib2-devel
  
  # Basic utilities
  bc
  coreutils
  curl
  wget
  ripgrep
  jq
  xdg-user-dirs
  rsync
  git
  wl-clipboard
  libnotify
  wlsunset
  dunst
  
  # XDG Portals
  xdg-desktop-portal
  xdg-desktop-portal-gtk
  xdg-desktop-portal-gnome
  
  # Polkit
  polkit
  
  # Network
  NetworkManager
  gnome-keyring
  
  # File manager
  dolphin
  kio-extras
  
  # Terminal - kitty is default, configurable in Settings
  kitty
  foot
  
  # Shell (required for scripts)
  fish
  
  # System monitor (not available in all Fedora versions)
  # mission-center
  
  # Thumbnails
  ffmpegthumbnailer
  tumbler
  
  # Translation
  translate-shell
)

# Qt6 packages
FEDORA_QT6_PKGS=(
  qt6-qtbase
  qt6-qtdeclarative
  qt6-qtsvg
  qt6-qtwayland
  qt6-qt5compat
  qt6-qtmultimedia
  qt6-qtimageformats
  qt6-qtvirtualkeyboard
  qt6-qtpositioning
  qt6-qtsensors
  qt6-qttools
  
  # System libs
  jemalloc
  libxcb
  libdrm
  mesa-dri-drivers
  
  # KDE integration
  kf6-kirigami
  kdialog
  kf6-syntax-highlighting
  
  # Qt theming
  qt6ct
  kde-gtk-config
  breeze-gtk
)

# Audio packages
FEDORA_AUDIO_PKGS=(
  pipewire
  pipewire-pulseaudio
  pipewire-alsa
  wireplumber
  playerctl
  libdbusmenu-gtk3
  pavucontrol
  cava
  easyeffects
  mpv
  yt-dlp
)

# Toolkit packages
FEDORA_TOOLKIT_PKGS=(
  upower
  wtype
  ydotool
  python3-evdev
  python3-pillow
  brightnessctl
  ddcutil
  geoclue2
  swayidle
  swaylock
  grim
  slurp
  ImageMagick
  libqalculate
  blueman
  kf6-kconfig
  tesseract
  tesseract-langpack-eng
  tesseract-langpack-spa
)

# Screen capture packages
# Note: ffmpeg from rpmfusion conflicts with ffmpeg-free, use --allowerasing
FEDORA_SCREENCAPTURE_PKGS=(
  grim
  slurp
  swappy
  wf-recorder
  ImageMagick
)

# Font packages
FEDORA_FONT_PKGS=(
  fontconfig
  dejavu-fonts-all
  liberation-fonts
  google-noto-emoji-fonts
  jetbrains-mono-fonts-all
  
  # Launcher
  fuzzel
  glib2
  
  # Qt theming
  kvantum

  # Icon themes - fallbacks (always available from repos)
  hicolor-icon-theme
  adwaita-icon-theme
  papirus-icon-theme
)

installflags=""
$ask || installflags="-y --skip-unavailable"

# Install core packages
echo -e "${STY_BLUE}[$0]: Installing core packages (including Quickshell & Niri)...${STY_RST}"
v sudo dnf install $installflags "${FEDORA_CORE_PKGS[@]}"

# Install Qt6 packages
echo -e "${STY_BLUE}[$0]: Installing Qt6 packages...${STY_RST}"
v sudo dnf install $installflags "${FEDORA_QT6_PKGS[@]}"

# Install based on flags
if ${INSTALL_AUDIO:-true}; then
  echo -e "${STY_BLUE}[$0]: Installing audio packages...${STY_RST}"
  v sudo dnf install $installflags "${FEDORA_AUDIO_PKGS[@]}"
fi

if ${INSTALL_TOOLKIT:-true}; then
  echo -e "${STY_BLUE}[$0]: Installing toolkit packages...${STY_RST}"
  v sudo dnf install $installflags "${FEDORA_TOOLKIT_PKGS[@]}"
fi

if ${INSTALL_SCREENCAPTURE:-true}; then
  echo -e "${STY_BLUE}[$0]: Installing screen capture packages...${STY_RST}"
  v sudo dnf install $installflags "${FEDORA_SCREENCAPTURE_PKGS[@]}"
fi

if ${INSTALL_FONTS:-true}; then
  echo -e "${STY_BLUE}[$0]: Installing font packages...${STY_RST}"
  v sudo dnf install $installflags "${FEDORA_FONT_PKGS[@]}"
fi

#####################################################################################
# Install packages from GitHub releases (precompiled binaries)
#####################################################################################
echo -e "${STY_CYAN}[$0]: Installing packages from GitHub releases...${STY_RST}"

ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH_SUFFIX="amd64" ;;
  aarch64) ARCH_SUFFIX="arm64" ;;
  *) ARCH_SUFFIX="$ARCH" ;;
esac

# Helper function to download and install from GitHub
install_github_binary() {
  local name="$1"
  local repo="$2"
  local asset_pattern="$3"
  local install_path="${4:-/usr/local/bin}"
  
  if command -v "$name" &>/dev/null; then
    echo -e "${STY_GREEN}[$0]: $name already installed${STY_RST}"
    return 0
  fi
  
  echo -e "${STY_BLUE}[$0]: Installing $name from GitHub...${STY_RST}"
  
  local download_url
  download_url=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" | \
    jq -r ".assets[] | select(.name | test(\"${asset_pattern}\")) | .browser_download_url" | head -1)
  
  if [[ -z "$download_url" || "$download_url" == "null" ]]; then
    echo -e "${STY_YELLOW}[$0]: Could not find $name binary, skipping...${STY_RST}"
    return 1
  fi
  
  local temp_dir="/tmp/${name}-install-$$"
  mkdir -p "$temp_dir"
  
  local filename=$(basename "$download_url")
  if curl -fsSL -o "$temp_dir/$filename" "$download_url"; then
    case "$filename" in
      *.tar.gz|*.tgz)
        tar -xzf "$temp_dir/$filename" -C "$temp_dir"
        local binary=$(find "$temp_dir" -type f -name "$name" -o -type f -executable | grep -v "\.tar" | head -1)
        [[ -n "$binary" ]] && sudo cp "$binary" "$install_path/$name"
        ;;
      *.zip)
        unzip -o "$temp_dir/$filename" -d "$temp_dir" >/dev/null
        local binary=$(find "$temp_dir" -type f -name "$name" | head -1)
        [[ -n "$binary" ]] && sudo cp "$binary" "$install_path/$name"
        ;;
      *.rpm)
        sudo dnf install -y "$temp_dir/$filename"
        ;;
      *)
        # Direct binary
        sudo cp "$temp_dir/$filename" "$install_path/$name"
        ;;
    esac
    sudo chmod +x "$install_path/$name" 2>/dev/null
    echo -e "${STY_GREEN}[$0]: $name installed successfully${STY_RST}"
  else
    echo -e "${STY_YELLOW}[$0]: Failed to download $name${STY_RST}"
  fi
  
  rm -rf "$temp_dir"
}

# gum - TUI tool (download .rpm from GitHub)
if ! command -v gum &>/dev/null; then
  echo -e "${STY_BLUE}[$0]: Installing gum from GitHub...${STY_RST}"
  GUM_RPM_URL=$(curl -s "https://api.github.com/repos/charmbracelet/gum/releases/latest" | \
    jq -r '.assets[] | select(.name | test("linux.*x86_64.*rpm$")) | .browser_download_url' | head -1)
  if [[ -n "$GUM_RPM_URL" && "$GUM_RPM_URL" != "null" ]]; then
    v sudo dnf install -y "$GUM_RPM_URL"
  fi
fi

# cliphist - clipboard manager
install_github_binary "cliphist" "sentriz/cliphist" "linux-amd64$"

# matugen - color generator
install_github_binary "matugen" "InioX/matugen" "x86_64.*tar.gz"

# xwayland-satellite - X11 compatibility (try cargo-binstall first)
if ! command -v xwayland-satellite &>/dev/null; then
  echo -e "${STY_BLUE}[$0]: Installing xwayland-satellite...${STY_RST}"
  if command -v cargo-binstall &>/dev/null; then
    cargo-binstall -y xwayland-satellite
  elif command -v cargo &>/dev/null; then
    cargo install xwayland-satellite
  else
    echo -e "${STY_YELLOW}[$0]: xwayland-satellite requires Rust. Install with: cargo install xwayland-satellite${STY_RST}"
  fi
fi

# darkly - Qt theme (download .rpm from GitHub)
if ${INSTALL_FONTS:-true}; then
  if ! rpm -q darkly &>/dev/null; then
    echo -e "${STY_BLUE}[$0]: Installing darkly theme from GitHub...${STY_RST}"
    DARKLY_RPM_URL=$(curl -s "https://api.github.com/repos/Bali10050/darkly/releases/latest" | \
      jq -r ".assets[] | select(.name | test(\"fc${FEDORA_VERSION}.*x86_64.rpm$\")) | .browser_download_url" | head -1)
    
    # Fallback to any Fedora RPM if exact version not found
    if [[ -z "$DARKLY_RPM_URL" || "$DARKLY_RPM_URL" == "null" ]]; then
      DARKLY_RPM_URL=$(curl -s "https://api.github.com/repos/Bali10050/darkly/releases/latest" | \
        jq -r '.assets[] | select(.name | test("fc[0-9]+.*x86_64.rpm$")) | .browser_download_url' | head -1)
    fi
    
    if [[ -n "$DARKLY_RPM_URL" && "$DARKLY_RPM_URL" != "null" ]]; then
      v sudo dnf install -y "$DARKLY_RPM_URL"
    else
      echo -e "${STY_YELLOW}[$0]: darkly RPM not found for Fedora ${FEDORA_VERSION}${STY_RST}"
    fi
  fi
fi

#####################################################################################
# Install uv (Python package manager)
#####################################################################################
echo -e "${STY_CYAN}[$0]: Installing uv...${STY_RST}"
if ! command -v uv &>/dev/null; then
  # Try the official installer first (fastest)
  curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null || {
    # Fallback to cargo
    if command -v cargo &>/dev/null; then
      cargo install uv
    else
      echo -e "${STY_YELLOW}[$0]: Could not install uv. Install manually: https://github.com/astral-sh/uv${STY_RST}"
    fi
  }
fi

#####################################################################################
# Install critical fonts
#####################################################################################
echo -e "${STY_CYAN}[$0]: Installing critical fonts...${STY_RST}"

FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"

# Material Symbols Rounded (icons) - this is the font iNiR actually uses
if ! fc-list | grep -qi "Material Symbols Rounded"; then
  echo -e "${STY_BLUE}[$0]: Downloading Material Symbols Rounded font...${STY_RST}"
  
  # Direct download from raw.githubusercontent
  MATERIAL_URL="https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
  
  if curl -fsSL -o "$FONT_DIR/MaterialSymbolsRounded.ttf" "$MATERIAL_URL"; then
    fc-cache -fv "$FONT_DIR" 2>/dev/null
    echo -e "${STY_GREEN}[$0]: Material Symbols Rounded font installed.${STY_RST}"
  else
    echo -e "${STY_YELLOW}[$0]: Could not download Material Symbols Rounded.${STY_RST}"
    echo -e "${STY_YELLOW}Please download from: https://fonts.google.com/icons${STY_RST}"
  fi
fi

# Also install Outlined variant (used by nts)
if ! fc-list | grep -qi "Material Symbols Outlined"; then
  echo -e "${STY_BLUE}[$0]: Downloading Material Symbols Outlined font...${STY_RST}"
  
  MATERIAL_URL="https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsOutlined%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
  
  if curl -fsSL -o "$FONT_DIR/MaterialSymbolsOutlined.ttf" "$MATERIAL_URL"; then
    fc-cache -fv "$FONT_DIR" 2>/dev/null
    echo -e "${STY_GREEN}[$0]: Material Symbols Outlined font installed.${STY_RST}"
  else
    echo -e "${STYLLOW}[$0]: Could not download Material Symbols Outlined.${STY_RST}"
  fi
fi

# JetBrains Mono Nerd Font (if not installed via dnf)
if ! fc-list | grep -qi "JetBrainsMono Nerd"; then
  echo -e "${STY_BLUE}[$0]: Downloading JetBrains Mono Nerd Font...${STY_RST}"
  
  NERD_FONTS_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
  TEMP_DIR="/tmp/nerdfonts-$$"
  mkdir -p "$TEMP_DIR"
  
  if curl -fsSL -o "$TEMP_DIR/JetBrainsMono.zip" "$NERD_FONTS_URL"; then
    unzip -o "$TEMP_DIR/JetBrainsMono.zip" -d "$FONT_DIR" >/dev/null 2>&1
    fc-cache -f "$FONT_DIR"
    echo -e "${STY_GREEN}[$0]: JetBrains Mono Nerd Font installed.${STY_RST}"
  else
    echo -e "${STY_YELLOW}[$0]: Could not download JetBrains Mono Nerd Font.${STY_RST}"
  fi
  
  rm -rf "$TEMP_DIR"
fi

#####################################################################################
# Icon themes (WhiteSur, MacTahoe)
#####################################################################################
echo -e "${STY_CYAN}[$0]: Installing icon themes...${STY_RST}"

ICON_DIR="$HOME/.local/share/icons"
mkdir -p "$ICON_DIR"

# WhiteSur icon theme
if [[ ! -d "$ICON_DIR/WhiteSur-dark" ]]; then
  echo -e "${STY_BLUE}[$0]: Installing WhiteSur icon theme...${STY_RST}"
  
  TEMP_DIR="/tmp/whitesur-icons-$$"
  mkdir -p "$TEMP_DIR"
  
  if curl -fsSL -o "$TEMP_DIR/whitesur.tar.gz" \
    "https://github.com/vinceliuice/WhiteSur-icon-theme/archive/refs/heads/master.tar.gz"; then
    tar -xzf "$TEMP_DIR/whitesur.tar.gz" -C "$TEMP_DIR"
    cd "$TEMP_DIR/WhiteSur-icon-theme-master"
    ./install.sh -d "$ICON_DIR" -t default >/dev/null 2>&1 || {
      # Fallback: manual copy
      cp -r src/WhiteSur "$ICON_DIR/WhiteSur-dark" 2>/dev/null || true
    }
    cd - >/dev/null
    echo -e "${STY_GREEN}[$0]: WhiteSur icon theme installed.${STY_RST}"
  else
    echo -e "${STY_YELLOW}[$0]: Could not download WhiteSur icon theme.${STY_RST}"
  fi
  
  rm -rf "$TEMP_DIR"
fi

# MacTahoe icon theme (for dock)
if [[ ! -d "$ICON_DIR/MacTahoe" ]]; then
  echo -e "${STY_BLUE}[$0]: Installing MacTahoe icon theme...${STY_RST}"
  
  TEMP_DIR="/tmp/mactahoe-icons-$$"
  mkdir -p "$TEMP_DIR"
  
  if curl -fsSL -o "$TEMP_DIR/mactahoe.tar.gz" \
    "https://github.com/vinceliuice/MacTahoe-icon-theme/archive/refs/heads/master.tar.gz"; then
    tar -xzf "$TEMP_DIR/mactahoe.tar.gz" -C "$TEMP_DIR"
    cd "$TEMP_DIR/MacTahoe-icon-theme-master" 2>/dev/null || cd "$TEMP_DIR/MacTahoe-icon-theme-main"
    ./install.sh -d "$ICON_DIR" >/dev/null 2>&1
    cd - >/dev/null
    echo -e "${STY_GREEN}[$0]: MacTahoe icon theme installed.${STY_RST}"
  else
    echo -e "${STY_YELLOW}[$0]: Could not download MacTahoe icon theme.${STY_RST}"
  fi
  
  rm -rf "$TEMP_DIR"
fi

#####################################################################################
# Cursor themes
#####################################################################################
echo -e "${STY_CYAN}[$0]: Installing cursor themes...${STY_RST}"

# Bibata Modern cursors (popular, well-maintained)
if [[ ! -d "$ICON_DIR/Bibata-Modern-Classic" ]]; then
  echo -e "${STY_BLUE}[$0]: Installing Bibata cursor theme...${STY_RST}"
  
  TEMP_DIR="/tmp/bibata-cursors-$$"
  mkdir -p "$TEMP_DIR"
  
  # Download Bibata Modern Classic (dark)
  if curl -fsSL -o "$TEMP_DIR/bibata-classic.tar.xz" \
    "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Classic.tar.xz"; then
    tar -xf "$TEMP_DIR/bibata-classic.tar.xz" -C "$ICON_DIR"
    echo -e "${STY_GREEN}[$0]: Bibata Modern Classic cursor installed.${STY_RST}"
  fi
  
  # Download Bibata Modern Ice (light)
  if curl -fsSL -o "$TEMP_DIR/bibata-ice.tar.xz" \
    "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Ice.tar.xz"; then
    tar -xf "$TEMP_DIR/bibata-ice.tar.xz" -C "$ICON_DIR"
    echo -e "${STY_GREEN}[$0]: Bibata Modern Ice cursor installed.${STY_RST}"
  fi
  
  rm -rf "$TEMP_DIR"
fi

#####################################################################################
# Optional fonts (nice to have)
#####################################################################################
echo -e "${STY_CYAN}[$0]: Installing optional fonts...${STY_RST}"

# Space Grotesk
if ! fc-list | grep -qi "Space Grotesk"; then
  echo -e "${STY_BLUE}[$0]: Downloading Space Grotesk font...${STY_RST}"
  curl -fsSL -o "$FONT_DIR/SpaceGrotesk.ttf" \
    "https://github.com/floriankarsten/space-grotesk/raw/master/fonts/ttf/SpaceGrotesk%5Bwght%5D.ttf" 2>/dev/null && \
    echo -e "${STY_GREEN}[$0]: Space Grotesk installed.${STY_RST}"
fi

# Rubik
if ! fc-list | grep -qi "Rubik"; then
  echo -e "${STY_BLUE}[$0]: Downloading Rubik font...${STY_RST}"
  curl -fsSL -o "$FONT_DIR/Rubik.ttf" \
    "https://github.com/googlefonts/rubik/raw/main/fonts/variable/Rubik%5Bwght%5D.ttf" 2>/dev/null && \
    echo -e "${STY_GREEN}[$0]: Rubik installed.${STY_RST}"
fi

# Geist (used by default in iNiR)
if ! fc-list | grep -qi "Geist"; then
  echo -e "${STY_BLUE}[$0]: Downloading Geist font...${STY_RST}"
  TEMP_DIR="/tmp/geist-font-$$"
  mkdir -p "$TEMP_DIR"
  if curl -fsSL -o "$TEMP_DIR/geist.zip" \
    "https://github.com/vercel/geist-font/releases/latest/download/Geist.zip"; then
    unzip -o "$TEMP_DIR/geist.zip" -d "$TEMP_DIR" >/dev/null 2>&1
    find "$TEMP_DIR" -name "*.ttf" -exec cp {} "$FONT_DIR/" \;
    echo -e "${STY_GREEN}[$0]: Geist font installed.${STY_RST}"
  fi
  rm -rf "$TEMP_DIR"
fi

# Refresh font cache
fc-cache -f "$FONT_DIR" 2>/dev/null

#####################################################################################
# Install CLI tools (starship, eza)
#####################################################################################
echo -e "${STY_CYAN}[$0]: Installing CLI tools...${STY_RST}"

# Starship prompt
if ! command -v starship &>/dev/null; then
  echo -e "${STY_BLUE}[$0]: Installing Starship prompt...${STY_RST}"
  mkdir -p ~/.local/bin
  curl -sS https://starship.rs/install.sh | sh -s -- -y -b ~/.local/bin 2>/dev/null || \
    echo -e "${STY_YELLOW}[$0]: Could not install Starship.${STY_RST}"
fi

# Eza (modern ls replacement)
if ! command -v eza &>/dev/null; then
  echo -e "${STY_BLUE}[$0]: Installing Eza...${STY_RST}"
  mkdir -p ~/.local/bin
  if curl -fsSL -o /tmp/eza.tar.gz \
    'https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-musl.tar.gz'; then
    tar -xzf /tmp/eza.tar.gz -C ~/.local/bin
    chmod +x ~/.local/bin/eza
    echo -e "${STY_GREEN}[$0]: Eza installed.${STY_RST}"
  fi
  rm -f /tmp/eza.tar.gz
fi

#####################################################################################
# Install adw-gtk3 theme
#####################################################################################
echo -e "${STY_CYAN}[$0]: Installing GTK themes...${STY_RST}"

if ! rpm -q adw-gtk3-theme &>/dev/null; then
  v sudo dnf install -y adw-gtk3-theme
fi

#####################################################################################
# Install polkit-e (for authentication dialogs)
#####################################################################################
echo -e "${STY_CYAN}[$0]: Installing polkit agent...${STY_RST}"

if ! rpm -q polkit-kde &>/dev/null; then
  v sudo dnf install -y polkit-kde
fi

#####################################################################################
# Setup configuration files
#####################################################################################
echo -e "${STY_CYAN}[$0]: Setting up configuration files...${STY_RST}"

# GTK configuration
setup-gtk-config "Bibata-Modern-Classic" "WhiteSur-dark" "adw-gtk3-dark" "Geist"

# Kvantum configuration
setup-kvantum-config "MaterialAdw"

# Environment variables
setup-environment-config "Bibata-Modern-Classic"

# Terminal configuration
setup-kitty-config
setup-foot-config

# Fish shell configuration
setup-fish-config

#####################################################################################
# Python environment setup
#####################################################################################
showfun install-python-packages
v install-python-packages

#####################################################################################
# Post-install summary
#####################################################################################
echo ""
echo -e "${STY_GREEN}════════════════════════════════════════════════════════════════${STY_RST}"
echo -e "${STY_GREEN}  Fedora dependencies installed successfully!${STY_RST}"
echo -e "${STY_GREEN}════════════════════════════════════════════════════════════════${STY_RST}"
echo ""
echo -e "${STY_CYAN}Installed from COPR (no compilation):${STY_RST}"
echo "  - quickshell (errornointernet/quickshell)"
echo "  - niri (yalter/niri)"
echo ""
echo -e "${STY_CYAN}Installed from GitHub releases:${STY_RST}"
echo "  - gum, cliphist, matugen, darkly, starship, eza"
echo ""
echo -e "${STY_CYAN}Themes configured:${STY_RST}"
echo "  - GTK: adw-gtk3-dark"
echo "  - Icons: WhiteSur-dark, MacTahoe"
echo "  - Cursor: Bibata-Modern-Classic"
echo "  - Qt/Kvantum: MaterialAdw + Darkly"
echo ""

# Verify critical commands
echo -e "${STY_CYAN}Verifying installation:${STY_RST}"
for cmd in qs niri fish gum matugen cliphist starship eza zoxide; do
  if command -v "$cmd" &>/dev/null || command -v ~/.local/bin/$cmd &>/dev/null; then
    echo -e "  ${STY_GREEN}✓${STY_RST} $cmd"
  else
    echo -e "  ${STY_RED}✗${STY_RST} $cmd (not found)"
  fi
done
echo ""

# Detect and show polkit agent path
POLKIT_AGENT=$(get-polkit-agent 2>/dev/null)
if [[ -n "$POLKIT_AGENT" ]]; then
  echo -e "${STY_CYAN}Polkit agent:${STY_RST} $POLKIT_AGENT"
  echo -e "${STY_YELLOW}Note: Update your niri config spawn-at-startup if different.${STY_RST}"
fi
echo ""
