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

# A /tmp mounted noexec (hardening guides advise it) can't run what a build makes there: cargo's build scripts,
# configure and cmake checks, a wrapper. Every temporary path in setup is ${TMPDIR:-/tmp}; this points it at a
# cache folder when the system's can't run a program.
_inir_exec_probe="$(mktemp "${TMPDIR:-/tmp}/inir-exec.XXXXXX" 2>/dev/null)" || _inir_exec_probe=""
if [[ -z "$_inir_exec_probe" ]] || ! { printf '#!/bin/sh\n' >"$_inir_exec_probe" && chmod +x "$_inir_exec_probe" \
    && "$_inir_exec_probe"; } 2>/dev/null; then
  mkdir -p "$XDG_CACHE_HOME/inir/tmp" && export TMPDIR="$XDG_CACHE_HOME/inir/tmp"
fi
if [[ -n "$_inir_exec_probe" ]]; then rm -f "$_inir_exec_probe"; fi
unset _inir_exec_probe

# Setup downloads fonts, themes, binaries and installers from many hosts; one dropped connection used to
# leave a piece missing until the next run (Deno, in a CI run). Every curl it or its scripts call retries.
curl() {
  command curl --retry 3 --retry-all-errors --connect-timeout 15 "$@" && return 0
  local rc=$? arg
  # 22 an HTTP error, the rest a server that hung up or never answered
  case $rc in 7|22|28|35|52|56|92) for arg; do [[ $arg == http*://* ]] && { net_down "$arg"; break; }; done ;; esac
  return "$rc"
}

# A server down (5xx, 429) makes setup print red lines people read as iNiR broken (GitHub's 504s, 11-09). net_down
# URL|HOST... asks each (an answer is kept five minutes), names the one that is down and whose problem it is, once a
# run, on setup's own stderr even where the caller hides curl's, sets NET_DOWN_CAUSE for a failure line and returns 0.
[[ -n "${INIR_NOTICE_FD:-}" ]] || { exec {INIR_NOTICE_FD}>&2; export INIR_NOTICE_FD INIR_RUN_ID=$$; }
net_down() {
  local target url host out code server who msg dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/inir-net-$UID"
  mkdir -p "$dir" 2>/dev/null || return 1
  for target; do
    url=$target
    [[ $url == *://* || $url != *@*:* ]] || { url=${url#*@}; url=${url%%:*}; }
    [[ $url == *://* ]] || url="https://$url/"
    host=${url#*://}; host=${host%%[/:?#]*}; [[ -n $host ]] || continue
    if [[ -z "$(find "$dir/$host" -mmin -5 2>/dev/null)" ]]; then
      out="$(command curl -s -o /dev/null -D - -r 0-0 -L --max-time 10 -w '\ncode %{http_code}\n' "$url" 2>/dev/null)"
      code=$(sed -n 's/^code //p' <<<"$out" | tail -n1); server=$(grep -i '^server:' <<<"$out" | tail -n1)
      who=$host
      [[ $host =~ (^|\.)(github\.com|githubusercontent\.com|github\.io)$ || ${server,,} == *github* ]] && who=GitHub
      printf '%s %s\n' "${code:-000}" "$who" > "$dir/$host"
    fi
    read -r code who < "$dir/$host" 2>/dev/null || continue
    [[ $code == 5[0-9][0-9] || $code == 429 ]] || continue
    local seen="HTTP $code"; [[ $who == GitHub ]] && seen+=" from $host"
    NET_DOWN_CAUSE="$who is having trouble right now ($seen), not iNiR"
    if [[ ! -e "$dir/$host.${INIR_RUN_ID:-0}" ]]; then
      : > "$dir/$host.${INIR_RUN_ID:-0}"
      if [[ $who == GitHub ]]; then
        msg="GitHub is having trouble right now ($seen). That's GitHub, not iNiR or your system: try again in a while (https://www.githubstatus.com)"
      else
        msg="$who is having trouble right now ($seen). That's that server, not iNiR or your system: try again in a while"
      fi
      { printf '  \e[33m⚠\e[0m %s\n' "$msg" >&"${INIR_NOTICE_FD:-2}"; } 2>/dev/null || printf '  \e[33m⚠\e[0m %s\n' "$msg" >&2
      [[ -n ${INIR_EVENTS_FD:-} ]] && printf 'warn\t%s\n' "$msg" >&"$INIR_EVENTS_FD" 2>/dev/null
    fi
    return 0
  done
  return 1
}
export -f curl net_down

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
