# Environment variables for iNiR installer
# This is NOT a script for execution, but for loading variables

XDG_BIN_HOME=${XDG_BIN_HOME:-$HOME/.local/bin}
XDG_CACHE_HOME=${XDG_CACHE_HOME:-$HOME/.cache}
XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
XDG_STATE_HOME=${XDG_STATE_HOME:-$HOME/.local/state}

# Setup installs the launcher, uv, starship and eza into XDG_BIN_HOME. The rest of
# the same run has to find them there, before a new login puts it on PATH. Last on
# PATH, so nothing there shadows a system binary.
case ":${PATH}:" in
  *":${XDG_BIN_HOME}:"*) ;;
  *) export PATH="${PATH}:${XDG_BIN_HOME}" ;;
esac

# Colors (ANSI escape codes)
STY_RED='\e[31m'
STY_GREEN='\e[32m'
STY_YELLOW='\e[33m'
STY_BLUE='\e[34m'
STY_PURPLE='\e[35m'
STY_MAGENTA='\e[35m'
STY_CYAN='\e[36m'
STY_WHITE='\e[37m'

# Text styles
STY_BOLD='\e[1m'
STY_FAINT='\e[2m'
STY_SLANT='\e[3m'
STY_ITALIC='\e[3m'
STY_UNDERLINE='\e[4m'
STY_INVERT='\e[7m'
STY_RST='\e[0m'

# Used by register_temp_file()
declare -a TEMP_FILES_TO_CLEANUP=()

# Used by install script
BACKUP_DIR="${BACKUP_DIR:-$HOME/inir-backup}"
INIR_CONFIG_DIR_NEW="${XDG_CONFIG_HOME}/inir"
INIR_CONFIG_DIR_LEGACY="${XDG_CONFIG_HOME}/illogical-impulse"

resolve_inir_config_dir() {
  if [[ -L "$INIR_CONFIG_DIR_LEGACY" && -d "$INIR_CONFIG_DIR_NEW" ]]; then
    printf '%s' "$INIR_CONFIG_DIR_NEW"
    return
  fi

  if [[ -d "$INIR_CONFIG_DIR_LEGACY" ]]; then
    printf '%s' "$INIR_CONFIG_DIR_LEGACY"
    return
  fi

  if [[ -d "$INIR_CONFIG_DIR_NEW" ]]; then
    printf '%s' "$INIR_CONFIG_DIR_NEW"
    return
  fi

  printf '%s' "$INIR_CONFIG_DIR_NEW"
}

DOTS_CORE_CONFDIR="${DOTS_CORE_CONFDIR:-$(resolve_inir_config_dir)}"
INSTALLED_LISTFILE="${DOTS_CORE_CONFDIR}/installed_listfile"
FIRSTRUN_FILE="${DOTS_CORE_CONFDIR}/installed_true"
