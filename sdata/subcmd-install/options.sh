# Options parser for iNiR installer
# This script is meant to be sourced.

# shellcheck shell=bash

showhelp_install(){
printf "[$0]: Install iNiR — Quickshell config for Niri.

Syntax:
  $0 install [OPTIONS]...

Options:
  -y, --yes           Skip confirmation prompts (auto-yes)
  -q, --quiet         Minimal output (for scripts/CI)
  --firstrun          Force first-run behavior (backup existing configs)
  --reset-dolphin-layout  Reset Dolphin panel layout state (dolphinstaterc)
  --skip-deps         Skip dependency installation
  --skip-setups       Skip service/permission setup
  --skip-files        Skip config file installation
  --skip-quickshell   Skip Quickshell config sync
  --skip-niri         Skip Niri config installation
  --compositor NAME   niri, umbriel or both: which compositors iNiR is set up for (niri alone leaves Umbriel
                      as it is; without it, Umbriel gets iNiR when installed or first logged into)
  --skip-backup       Skip backup of existing configs
  --no-audio          Skip audio dependencies
  --no-toolkit        Skip toolkit dependencies (ydotool, backlight)
  --no-screencapture  Skip screenshot/recording tools
  --no-fonts          Skip fonts and theming tools
  --set-default-shell Set Fish as the default shell (uses chsh)
  -h, --help          Show this help

Examples:
  $0 install              Interactive installation
  $0 install -y           Non-interactive installation
  $0 install -y -q        Non-interactive, quiet (for CI/scripts)
  $0 install --skip-deps  Skip dependencies (if already installed)
  $0 install --no-audio   Skip audio stack (if you use something else)
"
}

# Default values (preserve globals already set by top-level parser)
ask=${ask:-true}
quiet=${quiet:-false}
assume_yes=${assume_yes:-false}
INSTALL_FIRSTRUN=""
RESET_DOLPHIN_LAYOUT=false
SKIP_ALLDEPS=${SKIP_ALLDEPS:-false}
SKIP_ALLSETUPS=${SKIP_ALLSETUPS:-false}
SKIP_ALLFILES=${SKIP_ALLFILES:-false}
SKIP_QUICKSHELL=false
SKIP_NIRI=false
INSTALL_COMPOSITOR="${INSTALL_COMPOSITOR:-}"
SKIP_BACKUP=false
SKIP_SYSUPDATE=false

# Dependency groups (enabled by default)
INSTALL_AUDIO=true
INSTALL_TOOLKIT=true
INSTALL_SCREENCAPTURE=true
INSTALL_FONTS=true
SET_DEFAULT_SHELL=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -y|--yes)
      ask=false
      assume_yes=true
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
    --reset-dolphin-layout)
      RESET_DOLPHIN_LAYOUT=true
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
    --compositor)
      case "${2:-}" in
        niri|umbriel|both) INSTALL_COMPOSITOR="$2" ;;
        *) echo "--compositor takes niri, umbriel or both" >&2; exit 2 ;;
      esac
      shift 2
      ;;
    --compositor=*)
      case "${1#*=}" in
        niri|umbriel|both) INSTALL_COMPOSITOR="${1#*=}" ;;
        *) echo "--compositor takes niri, umbriel or both" >&2; exit 2 ;;
      esac
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
    --set-default-shell)
      SET_DEFAULT_SHELL=true
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

# Recorded in version.json so `inir update` keeps the choice: with --skip-deps
# the user owns their packages and updates never install any.
if [[ "$SKIP_ALLDEPS" == true ]]; then
  INIR_DEPENDENCIES=user
else
  INIR_DEPENDENCIES=setup
fi
