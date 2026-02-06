# Determine distribution for iNiR installer
# This is NOT a script for execution, but for loading functions

# shellcheck shell=bash

# Global variables set by detection
OS_GROUP_ID=""
OS_SPECIFIC_ID=""
OS_VERSION=""
OS_PRETTY_NAME=""

###############################################################################
# Arch-based detection
###############################################################################
function print_arch_info(){
  if [[ -f /etc/arch-release ]] || command -v pacman &>/dev/null; then
    OS_GROUP_ID="arch"
    
    # Detect specific distro
    if [[ -f /etc/cachyos-release ]]; then
      OS_SPECIFIC_ID="cachyos"
      OS_PRETTY_NAME="CachyOS"
    elif [[ -f /etc/endeavouros-release ]]; then
      OS_SPECIFIC_ID="endeavouros"
      OS_PRETTY_NAME="EndeavourOS"
    elif grep -qi "manjaro" /etc/os-release 2>/dev/null; then
      OS_SPECIFIC_ID="manjaro"
      OS_PRETTY_NAME="Manjaro"
    elif grep -qi "garuda" /etc/os-release 2>/dev/null; then
      OS_SPECIFIC_ID="garuda"
      OS_PRETTY_NAME="Garuda Linux"
    elif grep -qi "artix" /etc/os-release 2>/dev/null; then
      OS_SPECIFIC_ID="artix"
      OS_PRETTY_NAME="Artix Linux"
    else
      OS_SPECIFIC_ID="arch"
      OS_PRETTY_NAME="Arch Linux"
    fi
    
    if ! ${quiet:-false}; then
      echo -e "${STY_GREEN}Detected: Arch-based system${STY_RST}"
      echo -e "${STY_CYAN}  Distribution: ${OS_PRETTY_NAME}${STY_RST}"
    fi
  fi
}

###############################################################################
# Fedora-based detection
###############################################################################
function print_fedora_info(){
  if [[ -f /etc/fedora-release ]] || (grep -qi "fedora" /etc/os-release 2>/dev/null); then
    OS_GROUP_ID="fedora"
    
    # Get version
    if [[ -f /etc/os-release ]]; then
      OS_VERSION=$(grep "^VERSION_ID=" /etc/os-release | cut -d= -f2 | tr -d '"')
    fi
    
    # Detect specific variant
    if grep -qi "nobara" /etc/os-release 2>/dev/null; then
      OS_SPECIFIC_ID="nobara"
      OS_PRETTY_NAME="Nobara Linux"
    elif grep -qi "ultramarine" /etc/os-release 2>/dev/null; then
      OS_SPECIFIC_ID="ultramarine"
      OS_PRETTY_NAME="Ultramarine Linux"
    elif [[ -f /etc/fedora-release ]] && grep -qi "silverblue" /etc/os-release 2>/dev/null; then
      OS_SPECIFIC_ID="silverblue"
      OS_PRETTY_NAME="Fedora Silverblue"
    elif [[ -f /etc/fedora-release ]] && grep -qi "kinoite" /etc/os-release 2>/dev/null; then
      OS_SPECIFIC_ID="kinoite"
      OS_PRETTY_NAME="Fedora Kinoite"
    else
      OS_SPECIFIC_ID="fedora"
      OS_PRETTY_NAME="Fedora ${OS_VERSION}"
    fi
    
    if ! ${quiet:-false}; then
      echo -e "${STY_GREEN}Detected: Fedora-based system${STY_RST}"
      echo -e "${STY_CYAN}  Distribution: ${OS_PRETTY_NAME}${STY_RST}"
    fi
  fi
}

###############################################################################
# Debian/Ubuntu-based detection
###############################################################################
function print_debian_info(){
  # Check for Debian/Ubuntu family
  if [[ -f /etc/debian_version ]]; then
    # Determine if Ubuntu or Debian
    if grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
      OS_GROUP_ID="ubuntu"
      OS_VERSION=$(grep "^VERSION_ID=" /etc/os-release | cut -d= -f2 | tr -d '"')
      
      # Detect Ubuntu variants
      if grep -qi "pop" /etc/os-release 2>/dev/null; then
        OS_SPECIFIC_ID="pop"
        OS_PRETTY_NAME="Pop!_OS"
      elif grep -qi "mint" /etc/os-release 2>/dev/null; then
        OS_SPECIFIC_ID="mint"
        OS_PRETTY_NAME="Linux Mint"
      elif grep -qi "elementary" /etc/os-release 2>/dev/null; then
        OS_SPECIFIC_ID="elementary"
        OS_PRETTY_NAME="elementary OS"
      elif grep -qi "zorin" /etc/os-release 2>/dev/null; then
        OS_SPECIFIC_ID="zorin"
        OS_PRETTY_NAME="Zorin OS"
      elif grep -qi "kubuntu" /etc/os-release 2>/dev/null; then
        OS_SPECIFIC_ID="kubuntu"
        OS_PRETTY_NAME="Kubuntu"
      else
        OS_SPECIFIC_ID="ubuntu"
        OS_PRETTY_NAME="Ubuntu ${OS_VERSION}"
      fi
    else
      OS_GROUP_ID="debian"
      OS_VERSION=$(cat /etc/debian_version 2>/dev/null || echo "unknown")
      
      # Detect Debian variants
      if grep -qi "mx" /etc/os-release 2>/dev/null; then
        OS_SPECIFIC_ID="mx"
        OS_PRETTY_NAME="MX Linux"
      elif grep -qi "devuan" /etc/os-release 2>/dev/null; then
        OS_SPECIFIC_ID="devuan"
        OS_PRETTY_NAME="Devuan"
      elif grep -qi "kali" /etc/os-release 2>/dev/null; then
        OS_SPECIFIC_ID="kali"
        OS_PRETTY_NAME="Kali Linux"
      else
        OS_SPECIFIC_ID="debian"
        OS_PRETTY_NAME="Debian ${OS_VERSION}"
      fi
    fi
    
    if ! ${quiet:-false}; then
      echo -e "${STY_GREEN}Detected: Debian-based system${STY_RST}"
      echo -e "${STY_CYAN}  Distribution: ${OS_PRETTY_NAME}${STY_RST}"
    fi
  fi
}

###############################################################################
# openSUSE detection
###############################################################################
function print_opensuse_info(){
  if grep -qi "opensuse" /etc/os-release 2>/dev/null || [[ -f /etc/SuSE-release ]]; then
    OS_GROUP_ID="opensuse"
    
    if grep -qi "tumbleweed" /etc/os-release 2>/dev/null; then
      OS_SPECIFIC_ID="tumbleweed"
      OS_PRETTY_NAME="openSUSE Tumbleweed"
    elif grep -qi "leap" /etc/os-release 2>/dev/null; then
      OS_SPECIFIC_ID="leap"
      OS_VERSION=$(grep "^VERSION_ID=" /etc/os-release | cut -d= -f2 | tr -d '"')
      OS_PRETTY_NAME="openSUSE Leap ${OS_VERSION}"
    elif grep -qi "microos" /etc/os-release 2>/dev/null; then
      OS_SPECIFIC_ID="microos"
      OS_PRETTY_NAME="openSUSE MicroOS"
    else
      OS_SPECIFIC_ID="opensuse"
      OS_PRETTY_NAME="openSUSE"
    fi
    
    if ! ${quiet:-false}; then
      echo -e "${STY_GREEN}Detected: openSUSE-based system${STY_RST}"
      echo -e "${STY_CYAN}  Distribution: ${OS_PRETTY_NAME}${STY_RST}"
    fi
  fi
}

###############################################################################
# Void Linux detection
###############################################################################
function print_void_info(){
  if [[ -f /etc/void-release ]] || (grep -qi "void" /etc/os-release 2>/dev/null); then
    OS_GROUP_ID="void"
    OS_SPECIFIC_ID="void"
    OS_PRETTY_NAME="Void Linux"
    
    if ! ${quiet:-false}; then
      echo -e "${STY_GREEN}Detected: Void Linux${STY_RST}"
    fi
  fi
}

###############################################################################
# Gentoo detection
###############################################################################
function print_gentoo_info(){
  if [[ -f /etc/gentoo-release ]]; then
    OS_GROUP_ID="gentoo"
    OS_SPECIFIC_ID="gentoo"
    OS_PRETTY_NAME="Gentoo Linux"
    
    if ! ${quiet:-false}; then
      echo -e "${STY_GREEN}Detected: Gentoo-based system${STY_RST}"
    fi
  fi
}

###############################################################################
# NixOS detection
###############################################################################
function print_nixos_info(){
  if [[ -f /etc/NIXOS ]] || (grep -qi "nixos" /etc/os-release 2>/dev/null); then
    OS_GROUP_ID="nixos"
    OS_SPECIFIC_ID="nixos"
    OS_PRETTY_NAME="NixOS"
    
    if ! ${quiet:-false}; then
      echo -e "${STY_GREEN}Detected: NixOS${STY_RST}"
      echo -e "${STY_YELLOW}  Note: NixOS requires declarative configuration.${STY_RST}"
      echo -e "${STY_YELLOW}  See docs for NixOS-specific setup.${STY_RST}"
    fi
  fi
}

###############################################################################
# Alpine detection
###############################################################################
function print_alpine_info(){
  if [[ -f /etc/alpine-release ]]; then
    OS_GROUP_ID="alpine"
    OS_SPECIFIC_ID="alpine"
    OS_VERSION=$(cat /etc/alpine-release 2>/dev/null || echo "unknown")
    OS_PRETTY_NAME="Alpine Linux ${OS_VERSION}"
    
    if ! ${quiet:-false}; then
      echo -e "${STY_GREEN}Detected: Alpine Linux${STY_RST}"
    fi
  fi
}

# Array of detection functions (order matters - more specific first)
print_os_group_id_functions=(
  print_arch_info
  print_fedora_info
  print_debian_info
  print_opensuse_info
  print_void_info
  print_gentoo_info
  print_nixos_info
  print_alpine_info
)

###############################################################################
# Main detection function
###############################################################################
detect_distro(){
  # Reset globals
  OS_GROUP_ID=""
  OS_SPECIFIC_ID=""
  OS_VERSION=""
  OS_PRETTY_NAME=""
  
  for fn in "${print_os_group_id_functions[@]}"; do
    $fn
    # Stop at first match
    [[ -n "$OS_GROUP_ID" ]] && break
  done
  
  if [[ -z "$OS_GROUP_ID" ]]; then
    echo -e "${STY_RED}Could not detect distribution.${STY_RST}"
    echo ""
    echo -e "${STY_YELLOW}This installer supports:${STY_RST}"
    echo "  - Arch Linux and derivatives (CachyOS, EndeavourOS, Manjaro, Garuda, Artix)"
    echo "  - Fedora and derivatives (Nobara, Ultramarine, Silverblue, Kinoite)"
    echo "  - Debian and derivatives (Ubuntu, Pop!_OS, Mint, elementary, Zorin, MX)"
    echo "  - openSUSE (Tumbleweed, Leap, MicroOS)"
    echo "  - Void Linux"
    echo "  - Gentoo"
    echo "  - NixOS (requires manual configuration)"
    echo "  - Alpine Linux"
    echo ""
    echo -e "${STY_CYAN}For unsupported distributions:${STY_RST}"
    echo "  1. Run: ./setup install --skip-deps"
    echo "  2. Install dependencies manually (see docs/MANUAL_INSTALL.md)"
    echo ""
    
    # Allow continuing with generic installer
    if ${ask:-true}; then
      echo -e "${STY_YELLOW}Would you like to continue with manual dependency installation?${STY_RST}"
      local choice
      read -p "[y/N]: " choice
      if [[ "$choice" =~ ^[yY]$ ]]; then
        OS_GROUP_ID="generic"
        OS_SPECIFIC_ID="unknown"
        OS_PRETTY_NAME="Unknown Distribution"
        return 0
      fi
    fi
    
    exit 1
  fi
}

###############################################################################
# Helper functions
###############################################################################

# Check if running on immutable/atomic distro
is_immutable_distro() {
  case "$OS_SPECIFIC_ID" in
    silverblue|kinoite|microos) return 0 ;;
    *) return 1 ;;
  esac
}

# Check if distro uses systemd
uses_systemd() {
  [[ -d /run/systemd/system ]]
}

# Get package manager for current distro
get_package_manager() {
  case "$OS_GROUP_ID" in
    arch) echo "pacman" ;;
    fedora) 
      if is_immutable_distro; then
        echo "rpm-ostree"
      else
        echo "dnf"
      fi
      ;;
    debian|ubuntu) echo "apt" ;;
    opensuse) echo "zypper" ;;
    void) echo "xbps" ;;
    gentoo) echo "emerge" ;;
    nixos) echo "nix" ;;
    alpine) echo "apk" ;;
    *) echo "unknown" ;;
  esac
}

# Check if AUR is available
has_aur() {
  [[ "$OS_GROUP_ID" == "arch" ]]
}

# Check if COPR is available
has_copr() {
  [[ "$OS_GROUP_ID" == "fedora" ]] && ! is_immutable_distro
}

# Print distro info summary
print_distro_summary() {
  echo ""
  echo -e "${STY_CYAN}System Information:${STY_RST}"
  echo "  Distribution: ${OS_PRETTY_NAME}"
  echo "  Family: ${OS_GROUP_ID}"
  echo "  Package Manager: $(get_package_manager)"
  [[ -n "$OS_VERSION" ]] && echo "  Version: ${OS_VERSION}"
  is_immutable_distro && echo "  Type: Immutable/Atomic"
  uses_systemd && echo "  Init: systemd" || echo "  Init: other"
  echo ""
}
