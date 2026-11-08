# Environment variables for iNiR installer
# This is NOT a script for execution, but for loading variables

# Every setup, old or new, cds into the checkout and sources this file first. A setup that is not the checkout's own
# (v2.33's copy in the runtime, which its `inir update` runs when an earlier update pulled this tree and then stopped
# before the sync) would go on with code that calls files this tree no longer has; it hands over to the checkout's
# setup instead, with the same arguments and environment.
if [[ -z "${INIR_SETUP_HANDOFF:-}" && -n "${SCRIPT_DIR:-}" && -f "${SCRIPT_DIR}/setup" \
      && -f "${PWD}/setup" && -f "${PWD}/shell.qml" \
      && "$(basename -- "${BASH_SOURCE[${#BASH_SOURCE[@]}-1]}")" == setup ]] \
    && ! cmp -s -- "${SCRIPT_DIR}/setup" "${PWD}/setup"; then
  export INIR_SETUP_HANDOFF=1
  exec bash "${PWD}/setup" "$@"
fi
unset INIR_SETUP_HANDOFF

XDG_BIN_HOME=${XDG_BIN_HOME:-$HOME/.local/bin}
XDG_CACHE_HOME=${XDG_CACHE_HOME:-$HOME/.cache}
XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
XDG_STATE_HOME=${XDG_STATE_HOME:-$HOME/.local/state}

# Setup installs the launcher, Deno, starship and eza into XDG_BIN_HOME. The rest of
# the same run has to find them there, before a new login puts it on PATH. Last on
# PATH, so nothing there shadows a system binary.
case ":${PATH}:" in
  *":${XDG_BIN_HOME}:"*) ;;
  *) export PATH="${PATH}:${XDG_BIN_HOME}" ;;
esac

# Setup downloads fonts, themes, binaries and installers from many hosts; one dropped connection used to
# leave a piece missing until the next run (Deno, in a CI run). Every curl it or its scripts call retries.
curl() { command curl --retry 3 --retry-all-errors --connect-timeout 15 "$@"; }
export -f curl

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
  if [[ -L "$INIR_CONFIG_DIR_LEGACY" && "$INIR_CONFIG_DIR_LEGACY" -ef "$INIR_CONFIG_DIR_NEW" ]]; then
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

# The shell reads ~/.config/illogical-impulse/config.json and setup writes ~/.config/inir: the old name is a link to
# the new one. Set right on every run, never at the cost of a file: two real folders stay as they are (setup then
# writes the old one, which is what the shell reads).
ensure_config_dir_link() {
  if [[ -L "$INIR_CONFIG_DIR_LEGACY" ]]; then
    return 0
  elif [[ -d "$INIR_CONFIG_DIR_LEGACY" ]]; then
    [[ -e "$INIR_CONFIG_DIR_NEW" ]] && return 0
    mv -- "$INIR_CONFIG_DIR_LEGACY" "$INIR_CONFIG_DIR_NEW" || return 1
  elif [[ -e "$INIR_CONFIG_DIR_LEGACY" ]]; then
    return 1
  fi
  mkdir -p -- "$INIR_CONFIG_DIR_NEW" && ln -s -- "$INIR_CONFIG_DIR_NEW" "$INIR_CONFIG_DIR_LEGACY"
}

DOTS_CORE_CONFDIR="${DOTS_CORE_CONFDIR:-$(resolve_inir_config_dir)}"
INSTALLED_LISTFILE="${DOTS_CORE_CONFDIR}/installed_listfile"
FIRSTRUN_FILE="${DOTS_CORE_CONFDIR}/installed_true"
