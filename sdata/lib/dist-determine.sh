# Determine distribution for ii-niri installer
# This is NOT a script for execution, but for loading functions

# shellcheck shell=bash

function print_arch_info(){
  if [[ -f /etc/arch-release ]] || command -v pacman &>/dev/null; then
    OS_GROUP_ID="arch"
    if ! ${quiet:-false}; then
      echo -e "${STY_GREEN}Detected: Arch-based system${STY_RST}"
      
      # Detect specific distro
      if [[ -f /etc/cachyos-release ]]; then
        echo -e "${STY_CYAN}  Distribution: CachyOS${STY_RST}"
      elif [[ -f /etc/endeavouros-release ]]; then
        echo -e "${STY_CYAN}  Distribution: EndeavourOS${STY_RST}"
      elif grep -qi "manjaro" /etc/os-release 2>/dev/null; then
        echo -e "${STY_CYAN}  Distribution: Manjaro${STY_RST}"
      else
        echo -e "${STY_CYAN}  Distribution: Arch Linux${STY_RST}"
      fi
    fi
  fi
}

function print_fedora_info(){
  if [[ -f /etc/fedora-release ]]; then
    OS_GROUP_ID="fedora"
    if ! ${quiet:-false}; then
      echo -e "${STY_GREEN}Detected: Fedora-based system${STY_RST}"
    fi
  fi
}

function print_gentoo_info(){
  if [[ -f /etc/gentoo-release ]]; then
    OS_GROUP_ID="gentoo"
    if ! ${quiet:-false}; then
      echo -e "${STY_GREEN}Detected: Gentoo-based system${STY_RST}"
    fi
  fi
}

# Array of detection functions
print_os_group_id_functions=(
  print_arch_info
  print_fedora_info
  print_gentoo_info
)

# Run all detection
detect_distro(){
  for fn in "${print_os_group_id_functions[@]}"; do
    $fn
  done
  
  if [[ -z "$OS_GROUP_ID" ]]; then
    echo -e "${STY_RED}Could not detect distribution.${STY_RST}"
    echo -e "${STY_YELLOW}This installer currently supports:${STY_RST}"
    echo "  - Arch Linux and derivatives (CachyOS, EndeavourOS, Manjaro)"
    echo ""
    echo "For other distributions, please install dependencies manually."
    exit 1
  fi
}
