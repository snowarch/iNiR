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

# Quickshell (CRITICAL) - from errornointernet COPR
if ! dnf copr list --enabled 2>/dev/null | grep -q "errornointernet/quickshell"; then
  echo -e "${STY_BLUE}[$0]: Enabling Quickshell COPR...${STY_RST}"
  v sudo dnf copr enable -y errornointernet/quickshell
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
  
  # Terminal
  foot
  
  # Shell (required for scripts)
  fish
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
)

installflags=""
$ask || installflags="-y"

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

# Material Symbols (icons) - download from Google Fonts GitHub
if ! fc-list | grep -qi "Material Symbols"; then
  echo -e "${STY_BLUE}[$0]: Downloading Material Symbols font...${STY_RST}"
  
  # Direct download from Google Fonts GitHub repo
  MATERIAL_URL="https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsOutlined%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
  
  if curl -fsSL -o "$FONT_DIR/MaterialSymbolsOutlined[FILL,GRAD,opsz,wght].ttf" "$MATERIAL_URL"; then
    fc-cache -f "$FONT_DIR" 2>/dev/null
    echo -e "${STY_GREEN}[$0]: Material Symbols font installed.${STY_RST}"
  else
    echo -e "${STY_YELLOW}[$0]: Could not download Material Symbols automatically.${STY_RST}"
    echo -e "${STY_YELLOW}Please download from: https://fonts.google.com/icons${STY_RST}"
    echo -e "${STY_YELLOW}Or on Arch: yay -S ttf-material-symbols-variable-git${STY_RST}"
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
echo "  - gum, cliphist, matugen, darkly"
echo ""

# Verify critical commands
echo -e "${STY_CYAN}Verifying installation:${STY_RST}"
for cmd in qs niri fish gum; do
  if command -v "$cmd" &>/dev/null; then
    echo -e "  ${STY_GREEN}✓${STY_RST} $cmd"
  else
    echo -e "  ${STY_RED}✗${STY_RST} $cmd (not found)"
  fi
done
echo ""
