# Options parser for ii-niri installer
# This script is meant to be sourced.

# shellcheck shell=bash

showhelp_install(){
printf "[$0]: Install illogical-impulse on Niri.

Syntax:
  $0 install [OPTIONS]...

Options:
  -y, --yes           Skip confirmation prompts (auto-yes)
  -q, --quiet         Minimal output (for scripts/CI)
  --firstrun          Force first-run behavior (backup existing configs)
  --skip-deps         Skip dependency installation
  --skip-setups       Skip service/permission setup
  --skip-files        Skip config file installation
  --skip-quickshell   Skip Quickshell config sync
  --skip-niri         Skip Niri config installation
  --skip-backup       Skip backup of existing configs
  --no-audio          Skip audio dependencies
  --no-toolkit        Skip toolkit dependencies (ydotool, backlight)
  --no-screencapture  Skip screenshot/recording tools
  --no-fonts          Skip fonts and theming tools
  -h, --help          Show this help

Examples:
  $0 install              Interactive installation
  $0 install -y           Non-interactive installation
  $0 install -y -q        Non-interactive, quiet (for CI/scripts)
  $0 install --skip-deps  Skip dependencies (if already installed)
  $0 install --no-audio   Skip audio stack (if you use something else)
"
}

# Default values
ask=true
quiet=false
INSTALL_FIRSTRUN=""
SKIP_ALLDEPS=${SKIP_ALLDEPS:-false}
SKIP_ALLSETUPS=${SKIP_ALLSETUPS:-false}
SKIP_ALLFILES=${SKIP_ALLFILES:-false}
SKIP_QUICKSHELL=false
SKIP_NIRI=false
SKIP_BACKUP=false
SKIP_SYSUPDATE=false

# Dependency groups (enabled by default)
INSTALL_AUDIO=true
INSTALL_TOOLKIT=true
INSTALL_SCREENCAPTURE=true
INSTALL_FONTS=true

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -y|--yes)
      ask=false
      shift
      ;;
    -q|--quiet)
      quiet=true
      shift
      ;;
    --firstrun)
      INSTALL_FIRSTRUN=true
      shift
      ;;
    --skip-deps)
      SKIP_ALLDEPS=true
      shift
      ;;
    --skip-setups)
      SKIP_ALLSETUPS=true
      shift
      ;;
    --skip-files)
      SKIP_ALLFILES=true
      shift
      ;;
    --skip-quickshell)
      SKIP_QUICKSHELL=true
      shift
      ;;
    --skip-niri)
      SKIP_NIRI=true
      shift
      ;;
    --skip-backup)
      SKIP_BACKUP=true
      shift
      ;;
    --skip-sysupdate)
      SKIP_SYSUPDATE=true
      shift
      ;;
    --no-audio)
      INSTALL_AUDIO=false
      shift
      ;;
    --no-toolkit)
      INSTALL_TOOLKIT=false
      shift
      ;;
    --no-screencapture)
      INSTALL_SCREENCAPTURE=false
      shift
      ;;
    --no-fonts)
      INSTALL_FONTS=false
      shift
      ;;
    -h|--help)
      showhelp_install
      exit 0
      ;;
    *)
      echo -e "${STY_RED}Unknown option: $1${STY_RST}"
      showhelp_install
      exit 1
      ;;
  esac
done
