# Generic dependency installation guide for iNiR
# This script provides instructions for unsupported distributions
# It can also attempt to install what it can via common methods

# shellcheck shell=bash

#####################################################################################
# Introduction
#####################################################################################
echo ""
echo -e "${STY_CYAN}╔══════════════════════════════════════════════════════════════════╗${STY_RST}"
echo -e "${STY_CYAN}║           iNiR - Generic Installation Guide                      ║${STY_RST}"
echo -e "${STY_CYAN}╚══════════════════════════════════════════════════════════════════╝${STY_RST}"
echo ""
echo -e "${STY_YELLOW}Your distribution (${OS_PRETTY_NAME:-unknown}) is not directly supported.${STY_RST}"
echo -e "${STY_YELLOW}This guide will help you install dependencies manually.${STY_RST}"
echo ""

#####################################################################################
# Check what's already available
#####################################################################################
echo -e "${STY_CYAN}Checking available tools...${STY_RST}"
echo ""

check_cmd() {
  local cmd="$1"
  local name="$2"
  if command -v "$cmd" &>/dev/null; then
    echo -e "  ${STY_GREEN}✓${STY_RST} $name ($cmd)"
    return 0
  else
    echo -e "  ${STY_RED}✗${STY_RST} $name ($cmd)"
    return 1
  fi
}

echo -e "${STY_BLUE}Critical components:${STY_RST}"
check_cmd "qs" "Quickshell" && HAS_QUICKSHELL=true || HAS_QUICKSHELL=false
check_cmd "niri" "Niri compositor" && HAS_NIRI=true || HAS_NIRI=false

echo ""
echo -e "${STY_BLUE}Build tools:${STY_RST}"
check_cmd "cargo" "Rust/Cargo" && HAS_CARGO=true || HAS_CARGO=false
check_cmd "go" "Go" && HAS_GO=true || HAS_GO=false
check_cmd "cmake" "CMake" && HAS_CMAKE=true || HAS_CMAKE=false
check_cmd "ninja" "Ninja" && HAS_NINJA=true || HAS_NINJA=false
check_cmd "git" "Git" && HAS_GIT=true || HAS_GIT=false

echo ""
echo -e "${STY_BLUE}Runtime tools:${STY_RST}"
check_cmd "fish" "Fish shell"
check_cmd "jq" "jq"
check_cmd "curl" "curl"
check_cmd "wl-copy" "wl-clipboard"
check_cmd "grim" "grim"
check_cmd "slurp" "slurp"
check_cmd "matugen" "matugen"
check_cmd "cliphist" "cliphist"
check_cmd "pipewire" "PipeWire"
check_cmd "wpctl" "WirePlumber"

echo ""

#####################################################################################
# Critical dependencies that MUST be compiled
###############################################################################
COMPILE_NEEDED=()

if ! $HAS_QUICKSHELL; then
  COMPILE_NEEDED+=("quickshell")
fi

if ! $HAS_NIRI; then
  COMPILE_NEEDED+=("niri")
fi

if [[ ${#COMPILE_NEEDED[@]} -gt 0 ]]; then
  echo -e "${STY_RED}═══════════════════════════════════════════════════════════════════${STY_RST}"
  echo -e "${STY_RED}  CRITICAL: The following must be compiled from source:${STY_RST}"
  echo -e "${STY_RED}═══════════════════════════════════════════════════════════════════${STY_RST}"
  echo ""
  
  for pkg in "${COMPILE_NEEDED[@]}"; do
    case "$pkg" in
      quickshell)
        echo -e "${STY_YELLOW}QUICKSHELL${STY_RST} - The shell framework (required)"
        echo "  Repository: https://github.com/quickshell-mirror/quickshell"
        echo "  Build requirements: Qt6, CMake, Ninja, PipeWire, PAM"
        echo ""
        echo "  Build commands:"
        echo "    git clone --recursive https://github.com/quickshell-mirror/quickshell.git"
        echo "    cd quickshell"
        echo "    cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \\"
        echo "      -DSERVICE_PIPEWIRE=ON -DSERVICE_PAM=ON"
        echo "    cmake --build build"
        echo "    sudo cmake --install build"
        echo ""
        ;;
      niri)
        echo -e "${STY_YELLOW}NIRI${STY_RST} - The Wayland compositor (required)"
        echo "  Repository: https://github.com/YaLTeR/niri"
        echo "  Build requirements: Rust, libinput, libgbm, libseat, Pango"
        echo ""
        echo "  Build commands:"
        echo "    git clone https://github.com/YaLTeR/niri.git"
        echo "    cd niri"
        echo "    cargo build --release"
        echo "    sudo cp target/release/niri /usr/local/bin/"
        echo "    sudo cp resources/niri.desktop /usr/share/wayland-sessions/"
        echo ""
        ;;
    esac
  done
fi

#####################################################################################
# Cargo-installable packages
#####################################################################################
echo -e "${STY_CYAN}═══════════════════════════════════════════════════════════════════${STY_RST}"
echo -e "${STY_CYAN}  Packages installable via Cargo (Rust)${STY_RST}"
echo -e "${STY_CYAN}═══════════════════════════════════════════════════════════════════${STY_RST}"
echo ""

CARGO_PACKAGES=(
  "matugen:Color scheme generator"
  "xwayland-satellite:X11 compatibility layer"
  "uv:Fast Python package manager"
)

if $HAS_CARGO; then
  echo "Cargo is available. You can install these with:"
  echo ""
  for pkg_info in "${CARGO_PACKAGES[@]}"; do
    pkg="${pkg_info%%:*}"
    desc="${pkg_info#*:}"
    if ! command -v "$pkg" &>/dev/null; then
      echo "  cargo install $pkg  # $desc"
    fi
  done
else
  echo -e "${STY_YELLOW}Cargo not found. Install Rust first:${STY_RST}"
  echo "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
  echo ""
  echo "Then install these packages:"
  for pkg_info in "${CARGO_PACKAGES[@]}"; do
    pkg="${pkg_info%%:*}"
    desc="${pkg_info#*:}"
    echo "  cargo install $pkg  # $desc"
  done
fi
echo ""

#####################################################################################
# Go-installable packages
#####################################################################################
echo -e "${STY_CYAN}═══════════════════════════════════════════════════════════════════${STY_RST}"
echo -e "${STY_CYAN}  Packages installable via Go${STY_RST}"
echo -e "${STY_CYAN}═══════════════════════════════════════════════════════════════════${STY_RST}"
echo ""

GO_PACKAGES=(
  "go.senan.xyz/cliphist@latest:Clipboard history manager"
)

if $HAS_GO; then
  echo "Go is available. You can install these with:"
  echo ""
  for pkg_info in "${GO_PACKAGES[@]}"; do
    pkg="${pkg_info%%:*}"
    desc="${pkg_info#*:}"
    echo "  go install $pkg  # $desc"
  done
else
  echo -e "${STY_YELLOW}Go not found. Install Go from your package manager or:${STY_RST}"
  echo "  https://go.dev/dl/"
  echo ""
  echo "Then install these packages:"
  for pkg_info in "${GO_PACKAGES[@]}"; do
    pkg="${pkg_info%%:*}"
    desc="${pkg_info#*:}"
    echo "  go install $pkg  # $desc"
  done
fi
echo ""

#####################################################################################
# System packages by category
#####################################################################################
echo -e "${STY_CYAN}═══════════════════════════════════════════════════════════════════${STY_RST}"
echo -e "${STY_CYAN}  System packages to install via your package manager${STY_RST}"
echo -e "${STY_CYAN}═══════════════════════════════════════════════════════════════════${STY_RST}"
echo ""

echo -e "${STY_BLUE}Qt6 (required):${STY_RST}"
echo "  qt6-base, qt6-declarative, qt6-svg, qt6-wayland, qt6-5compat"
echo "  qt6-multimedia, qt6-imageformats, qt6-virtualkeyboard"
echo ""

echo -e "${STY_BLUE}Wayland tools (required):${STY_RST}"
echo "  wl-clipboard, grim, slurp, swaylock, swayidle, wlsunset"
echo ""

echo -e "${STY_BLUE}Audio (required):${STY_RST}"
echo "  pipewire, pipewire-pulse, wireplumber, playerctl, pavucontrol"
echo ""

echo -e "${STY_BLUE}Utilities (required):${STY_RST}"
echo "  fish, jq, curl, wget, git, rsync, ripgrep, bc"
echo "  dunst, libnotify, imagemagick, brightnessctl"
echo ""

echo -e "${STY_BLUE}Desktop integration:${STY_RST}"
echo "  xdg-desktop-portal, xdg-desktop-portal-gtk, xdg-desktop-portal-gnome"
echo "  polkit, networkmanager, gnome-keyring, blueman"
echo ""

echo -e "${STY_BLUE}Optional but recommended:${STY_RST}"
echo "  foot (terminal), dolphin (file manager), fuzzel (launcher)"
echo "  easyeffects, mpv, yt-dlp, tesseract-ocr"
echo ""

#####################################################################################
# Fonts
#####################################################################################
echo -e "${STY_CYAN}═══════════════════════════════════════════════════════════════════${STY_RST}"
echo -e "${STY_CYAN}  Required Fonts${STY_RST}"
echo -e "${STY_CYAN}═══════════════════════════════════════════════════════════════════${STY_RST}"
echo ""

echo -e "${STY_RED}CRITICAL: These fonts are required for UI icons to display:${STY_RST}"
echo ""
echo "  1. Material Symbols (icons)"
echo "     Download: https://fonts.google.com/icons"
echo "     Or: https://github.com/ArtifexSoftware/mupdf/raw/master/resources/fonts/noto/"
echo ""
echo "  2. JetBrains Mono Nerd Font (terminal/code)"
echo "     Download: https://github.com/ryanoasis/nerd-fonts/releases"
echo "     Direct: https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
echo ""
echo "  Install fonts to: ~/.local/share/fonts/"
echo "  Then run: fc-cache -fv"
echo ""

#####################################################################################
# Attempt automatic installation of what we can
#####################################################################################
if $ask; then
  echo -e "${STY_CYAN}═══════════════════════════════════════════════════════════════════${STY_RST}"
  echo ""
  echo -e "${STY_YELLOW}Would you like to attempt automatic installation of:${STY_RST}"
  echo "  - Cargo packages (if Rust is available)"
  echo "  - Go packages (if Go is available)"
  echo "  - Fonts (downloaded to ~/.local/share/fonts)"
  echo ""
  
  local choice
  read -p "Attempt automatic installation? [y/N]: " choice
  
  if [[ "$choice" =~ ^[yY]$ ]]; then
    echo ""
    
    # Install Cargo packages
    if $HAS_CARGO; then
      echo -e "${STY_BLUE}Installing Cargo packages...${STY_RST}"
      for pkg_info in "${CARGO_PACKAGES[@]}"; do
        pkg="${pkg_info%%:*}"
        if ! command -v "$pkg" &>/dev/null; then
          echo "  Installing $pkg..."
          cargo install "$pkg" 2>/dev/null || echo "  Failed to install $pkg"
        fi
      done
    fi
    
    # Install Go packages
    if $HAS_GO; then
      echo -e "${STY_BLUE}Installing Go packages...${STY_RST}"
      for pkg_info in "${GO_PACKAGES[@]}"; do
        pkg="${pkg_info%%:*}"
        cmd="${pkg##*/}"
        cmd="${cmd%%@*}"
        if ! command -v "$cmd" &>/dev/null; then
          echo "  Installing $pkg..."
          go install "$pkg" 2>/dev/null || echo "  Failed to install $pkg"
        fi
      done
    fi
    
    # Install fonts
    echo -e "${STY_BLUE}Installing fonts...${STY_RST}"
    FONT_DIR="$HOME/.local/share/fonts"
    mkdir -p "$FONT_DIR"
    
    # JetBrains Mono Nerd Font
    if ! fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd"; then
      echo "  Downloading JetBrains Mono Nerd Font..."
      TEMP_DIR="/tmp/fonts-$$"
      mkdir -p "$TEMP_DIR"
      
      if curl -fsSL -o "$TEMP_DIR/JetBrainsMono.zip" \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" 2>/dev/null; then
        unzip -o "$TEMP_DIR/JetBrainsMono.zip" -d "$FONT_DIR" 2>/dev/null
        echo "  JetBrains Mono Nerd Font installed."
      else
        echo "  Failed to download JetBrains Mono Nerd Font."
      fi
      rm -rf "$TEMP_DIR"
    fi
    
    fc-cache -f "$FONT_DIR" 2>/dev/null
    
    echo ""
    echo -e "${STY_GREEN}Automatic installation complete.${STY_RST}"
  fi
fi

#####################################################################################
# Final checklist
#####################################################################################
echo ""
echo -e "${STY_CYAN}═══════════════════════════════════════════════════════════════════${STY_RST}"
echo -e "${STY_CYAN}  Pre-flight Checklist${STY_RST}"
echo -e "${STY_CYAN}═══════════════════════════════════════════════════════════════════${STY_RST}"
echo ""

READY=true

echo -e "${STY_BLUE}Critical components:${STY_RST}"
if command -v qs &>/dev/null; then
  echo -e "  ${STY_GREEN}✓${STY_RST} Quickshell installed"
else
  echo -e "  ${STY_RED}✗${STY_RST} Quickshell NOT installed - REQUIRED"
  READY=false
fi

if command -v niri &>/dev/null; then
  echo -e "  ${STY_GREEN}✓${STY_RST} Niri installed"
else
  echo -e "  ${STY_RED}✗${STY_RST} Niri NOT installed - REQUIRED"
  READY=false
fi

if command -v fish &>/dev/null; then
  echo -e "  ${STY_GREEN}✓${STY_RST} Fish shell installed"
else
  echo -e "  ${STY_RED}✗${STY_RST} Fish shell NOT installed - REQUIRED"
  READY=false
fi

echo ""

if $READY; then
  echo -e "${STY_GREEN}All critical components are installed!${STY_RST}"
  echo "You can proceed with: ./setup install --skip-deps"
else
  echo -e "${STY_RED}Some critical components are missing.${STY_RST}"
  echo "Please install them before continuing."
  echo ""
  echo "After installing dependencies, run:"
  echo "  ./setup install --skip-deps"
fi

echo ""
echo -e "${STY_CYAN}For more help, see:${STY_RST}"
echo "  - https://github.com/anomalyco/inir/wiki/Manual-Installation"
echo "  - https://quickshell.outfoxxed.me/docs"
echo "  - https://github.com/YaLTeR/niri/wiki"
echo ""
