# Core functions for iNiR installer
# This is NOT a script for execution, but for loading functions

# shellcheck shell=bash

if [[ -n "${REPO_ROOT:-}" && -f "${REPO_ROOT}/scripts/lib/niri-session-env.sh" ]]; then
  source "${REPO_ROOT}/scripts/lib/niri-session-env.sh"
fi

function try { "$@" || sleep 0; }

function v(){
  if ! ${quiet:-false}; then
    echo -e "  ${STY_FAINT}▶${STY_RST} ${STY_GREEN}$*${STY_RST}"
  fi
  local execute=true
  if $ask;then
    while true;do
      echo -e "${STY_BLUE}Execute? ${STY_RST}"
      echo "  y = Yes (default)"
      echo "  e = Exit now"
      echo "  s = Skip this command"
      echo "  yesforall = Yes and don't ask again"
      
      # Read with timeout (60s), default to Yes if timeout
      local p
      if read -t 60 -p "====> " p; then
        :
      else
        echo ""
        echo -e "${STY_YELLOW}Timeout reached, assuming Yes...${STY_RST}"
        p="y"
      fi
      
      case $p in
        [yY] | "") break ;;
        [eE]) echo -e "${STY_BLUE}Exiting...${STY_RST}" ;exit ;break ;;
        [sS]) echo -e "${STY_BLUE}Alright, skipping...${STY_RST}" ;execute=false ;break ;;
        "yesforall") ask=false ;break ;;
        *) echo -e "${STY_RED}Please enter [y/e/s/yesforall].${STY_RST}";;
      esac
    done
  fi
  if $execute;then x "$@";else
    if ! ${quiet:-false}; then
      echo -e "${STY_YELLOW}[$0]: Skipped \"$*\"${STY_RST}"
    fi
  fi
}

function x(){
  if "$@";then local cmdstatus=0;else local cmdstatus=1;fi
  
  # In non-interactive mode, fail immediately on error
  if ! $ask && [ $cmdstatus == 1 ]; then
     echo -e "${STY_RED}[$0]: Command \"${STY_GREEN}$*${STY_RED}\" failed in non-interactive mode. Exiting...${STY_RST}"
     exit 1
  fi

  while [ $cmdstatus == 1 ] ;do
    echo -e "${STY_RED}[$0]: Command \"${STY_GREEN}$*${STY_RED}\" has failed."
    echo -e "You may need to resolve the problem manually.${STY_RST}"
    echo "  r = Repeat this command (DEFAULT)"
    echo "  e = Exit now"
    echo "  i = Ignore this error and continue"
    
    local p
    if read -t 60 -p " [R/e/i]: " p; then
        :
    else
        echo ""
        echo -e "${STY_YELLOW}Timeout reached, exiting to be safe...${STY_RST}"
        p="e"
    fi

    case $p in
      [iI]) echo -e "${STY_BLUE}Alright, ignoring...${STY_RST}";cmdstatus=2;;
      [eE]) echo -e "${STY_BLUE}Exiting...${STY_RST}";break;;
      [rR] | "") echo -e "${STY_BLUE}Repeating...${STY_RST}"
         if "$@";then cmdstatus=0;else cmdstatus=1;fi
         ;;
      *) echo -e "${STY_BLUE}Repeating...${STY_RST}"
         if "$@";then cmdstatus=0;else cmdstatus=1;fi
         ;;
    esac
  done
  case $cmdstatus in
    0) ;;
    1) echo -e "${STY_RED}[$0]: Command \"${STY_GREEN}$*${STY_RED}\" failed. Exiting...${STY_RST}";exit 1;;
    2) echo -e "${STY_RED}[$0]: Command \"${STY_GREEN}$*${STY_RED}\" failed but ignored.${STY_RST}";;
  esac
}

function showfun(){
  if ! ${quiet:-false}; then
    echo -e "\n  ${STY_PURPLE}${STY_BOLD}❯${STY_RST} ${STY_BOLD}$1${STY_RST}"
  fi
}

function pause(){
  if [ ! "$ask" == "false" ];then
    printf "${STY_FAINT}${STY_SLANT}"
    local p; read -p "(Ctrl-C to abort, Enter to proceed)" p
    printf "${STY_RST}"
  fi
}

function prevent_sudo_or_root(){
  case $(whoami) in
    root) echo -e "${STY_RED}[$0]: Do NOT run as root. Aborting...${STY_RST}";exit 1;;
  esac
}

function command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# The inir binary's install wizard runs setup quietly and follows it through the
# descriptor in INIR_EVENTS_FD: one "kind<TAB>text" line per thing worth showing.
function inir_event() {
  [[ -n "${INIR_EVENTS_FD:-}" ]] || return 0
  local text="${2//$'\n'/ }"
  printf '%s\t%s\n' "$1" "${text//$'\t'/ }" >&"${INIR_EVENTS_FD}" 2>/dev/null || true
}

function log_info() {
  inir_event info "$1"
  if ! ${quiet:-false}; then
    echo -e "  ${STY_BLUE}→${STY_RST} $1"
  fi
}

function log_success() {
  inir_event ok "$1"
  if ! ${quiet:-false}; then
    echo -e "  ${STY_GREEN}✓${STY_RST} $1"
  fi
}

function log_warning() {
  inir_event warn "$1"
  echo -e "  ${STY_YELLOW}⚠${STY_RST} $1"
}

function log_error() {
  inir_event error "$1"
  echo -e "  ${STY_RED}✗${STY_RST} $1" >&2
}

function log_header() {
  if ! ${quiet:-false}; then
    echo -e "\n  ${STY_PURPLE}${STY_BOLD}$1${STY_RST}"
  fi
}

# File operations for 3.files.sh
cp_file(){
  # $1 = source, $2 = target
  local src="$1"
  local dst="$2"

  x mkdir -p "$(dirname "$dst")"

  # Avoid failing when source and destination are the same file
  # (e.g. when ~/.config/quickshell/inir points into the repo).
  if [[ -e "$dst" ]]; then
    local src_real dst_real
    src_real="$(realpath -se "$src" 2>/dev/null || echo "$src")"
    dst_real="$(realpath -se "$dst" 2>/dev/null || echo "$dst")"

    if [[ "$src_real" == "$dst_real" ]]; then
      echo -e "${STY_BLUE}[$0]: cp_file: '$src' and '$dst' are the same file, skipping copy.${STY_RST}"
    else
      x cp -f "$src" "$dst"
    fi
  else
    x cp -f "$src" "$dst"
  fi

  x mkdir -p "$(dirname "${INSTALLED_LISTFILE}")"
  realpath -se "$dst" >> "${INSTALLED_LISTFILE}"
}

# Generate rsync exclusions from the same policy used by package delivery and manifests.
# Resolve relative paths against the source checkout, not the copied directory's basename.
source "$(dirname "${BASH_SOURCE[0]}")/runtime-payload.sh"
_runtime_rsync() {
  local source_path relative filters
  source_path="$(realpath -e -- "$1")" || return
  relative="${source_path#"$INIR_PAYLOAD_ROOT"/}"
  [[ "$relative" != "$source_path" ]] || { echo "Install source is outside repository" >&2; return 1; }
  filters="$(runtime_payload filters --root "$INIR_PAYLOAD_ROOT" --subdir "$relative")" || return
  local -a exclusions
  mapfile -t exclusions <<< "$filters"
  local target="$2"
  shift 2
  rsync -a "${exclusions[@]}" "$@" "$source_path/" "$target/"
}

rsync_dir() (
  set -o pipefail
  x mkdir -p "$2"
  local dest
  dest="$(realpath -se -- "$2")" || return
  x mkdir -p "$(dirname "${INSTALLED_LISTFILE}")"
  _runtime_rsync "$1" "$2" --out-format='%i %n' | awk -v d="$dest" '$1 ~ /^>/{ sub(/^[^ ]+ /,""); printf d "/" $0 "\n" }' >> "${INSTALLED_LISTFILE}"
)

rsync_dir__sync() (
  set -o pipefail
  x mkdir -p "$2"
  local dest
  dest="$(realpath -se -- "$2")" || return
  x mkdir -p "$(dirname "${INSTALLED_LISTFILE}")"
  _runtime_rsync "$1" "$2" --delete --out-format='%i %n' | awk -v d="$dest" '$1 ~ /^>/{ sub(/^[^ ]+ /,""); printf d "/" $0 "\n" }' >> "${INSTALLED_LISTFILE}"
)

function install_file(){
  local s="$1"
  local t="$2"
  if [ -f "$t" ] && ! ${quiet:-false}; then
    echo -e "${STY_YELLOW}[$0]: \"$t\" will be overwritten.${STY_RST}"
  fi
  v cp_file "$s" "$t"
}

function install_file__auto_backup(){
  local s="$1"
  local t="$2"
  if [ -f "$t" ];then
    if ! ${quiet:-false}; then
      echo -e "${STY_YELLOW}[$0]: \"$t\" exists.${STY_RST}"
    fi
    if ${INSTALL_FIRSTRUN};then
      if ! ${quiet:-false}; then
        echo -e "${STY_BLUE}[$0]: First run - backing up.${STY_RST}"
      fi
      v mv "$t" "$t.old"
      v cp_file "$s" "$t"
    else
      if ! ${quiet:-false}; then
        echo -e "${STY_BLUE}[$0]: Not first run - preserving existing file${STY_RST}"
      fi
    fi
  else
    if ! ${quiet:-false}; then
      echo -e "${STY_GREEN}[$0]: \"$t\" does not exist.${STY_RST}"
    fi
    v cp_file "$s" "$t"
  fi
}

function install_dir(){
  local s="$1"
  local t="$2"
  if [ -d "$t" ] && ! ${quiet:-false}; then
    echo -e "${STY_YELLOW}[$0]: \"$t\" will be merged.${STY_RST}"
  fi
  rsync_dir "$s" "$t"
}

function install_dir__sync(){
  local s="$1"
  local t="$2"
  if [ -d "$t" ] && ! ${quiet:-false}; then
    echo -e "${STY_YELLOW}[$0]: \"$t\" will be synced (--delete).${STY_RST}"
  fi
  rsync_dir__sync "$s" "$t"
}

function install_dir__skip_existed(){
  local s="$1"
  local t="$2"
  if [ -d "$t" ];then
    if ! ${quiet:-false}; then
      echo -e "${STY_BLUE}[$0]: \"$t\" exists, skipping.${STY_RST}"
    fi
  else
    if ! ${quiet:-false}; then
      echo -e "${STY_YELLOW}[$0]: \"$t\" does not exist.${STY_RST}"
    fi
    v rsync_dir "$s" "$t"
  fi
}

# Marked iNiR blocks in shell profiles (~/.bashrc, ~/.profile, ...): `path` or `env`, each its start marker, the
# body and its end marker after one blank line. Writing the same block again leaves the file byte-identical.
#   inir_rc_block set NAME FILE   write block NAME, body on stdin
#   inir_rc_block remove FILE     drop every iNiR block; FILE goes if nothing else is left
#   inir_rc_block prune FILE      FILE goes only if it holds nothing but iNiR blocks
# A profile that is a link (dotfile managers) is written where it points and stays a link, emptied, never removed.
_inir_rc_markers() {
  case "$1" in
    path) printf '%s\n%s\n' "# iNiR launcher PATH" "# end iNiR launcher PATH" ;;
    env) printf '%s\n%s\n' "# iNiR environment" "# end iNiR" ;;
    *) return 1 ;;
  esac
}

# _inir_rc_strip FILE OUT NAME...: FILE without those blocks and the blank lines right before each one. A start
# marker with no end marker after it stays, like everything around it.
_inir_rc_strip() {
  local file="$1" out="$2" name start end nonl
  shift 2
  cp -- "$file" "$out" || return
  for name; do
    { read -r start; read -r end; } < <(_inir_rc_markers "$name")
    nonl=0
    [[ -s "$out" && -n "$(tail -c1 -- "$out")" ]] && nonl=1
    START="$start" END="$end" LC_ALL=C awk -v nonl="$nonl" '
      function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
      { line[NR] = $0 }
      END {
        n = 0; held = 0; inblock = 0
        for (i = 1; i <= NR; i++) {
          t = trim(line[i])
          if (inblock) {
            if (t == ENVIRON["END"]) { inblock = 0; held = 0 } else hold[++held] = i
            continue
          }
          if (t == ENVIRON["START"] && i < NR) { inblock = 1; hold[++held] = i; continue }
          if (t == "") { hold[++held] = i; continue }
          for (j = 1; j <= held; j++) keep[++n] = hold[j]
          held = 0; keep[++n] = i
        }
        for (j = 1; j <= held; j++) keep[++n] = hold[j]
        for (j = 1; j <= n; j++) printf "%s%s", line[keep[j]], (keep[j] == NR && nonl ? "" : "\n")
      }' "$out" > "$out.next" && mv -f -- "$out.next" "$out" || return
  done
}

# _inir_rc_write FILE TEXT_FILE: put TEXT_FILE in FILE atomically, keeping FILE's mode; nothing when equal.
_inir_rc_write() {
  local real tmp
  real="$(realpath -m -- "$1")" || return
  if [[ -f "$real" ]] && cmp -s -- "$2" "$real"; then return 0; fi
  tmp="${real}.inir.$$"
  cp -- "$2" "$tmp" || return
  [[ ! -e "$real" ]] || chmod "$(stat -c %a -- "$real")" "$tmp" || { rm -f -- "$tmp"; return 1; }
  mv -f -- "$tmp" "$real"
}

_inir_rc_drop() {
  if [[ -L "$1" ]]; then : > "$2/empty" && _inir_rc_write "$1" "$2/empty"; else rm -f -- "$1"; fi
}

inir_rc_block() {
  local cmd="${1:-}" name file scratch text rest body start end
  case "$cmd" in
    set) name="${2:-}" file="${3:-}"; _inir_rc_markers "$name" >/dev/null && [[ $# -eq 3 ]] || cmd="" ;;
    remove|prune) file="${2:-}"; [[ $# -eq 2 ]] || cmd="" ;;
    *) cmd="" ;;
  esac
  if [[ -z "$cmd" ]]; then
    echo "usage: inir_rc_block set path|env FILE (body on stdin) | remove FILE | prune FILE" >&2
    return 2
  fi
  scratch="$(mktemp -d)" || return
  local rc=0
  case "$cmd" in
    set)
      body="$(cat)"
      body="${body#"${body%%[!$'\n']*}"}"
      { read -r start; read -r end; } < <(_inir_rc_markers "$name")
      rest=""
      if [[ -f "$file" ]]; then
        _inir_rc_strip "$file" "$scratch/rest" "$name" && rest="$(<"$scratch/rest")" || rc=1
        rest="${rest%"${rest##*[![:space:]]}"}"
      fi
      if ((rc == 0)); then
        if [[ -n "$rest" ]]; then
          printf '%s\n\n%s\n%s\n%s\n' "$rest" "$start" "$body" "$end" > "$scratch/new"
        else
          printf '%s\n%s\n%s\n' "$start" "$body" "$end" > "$scratch/new"
        fi
        _inir_rc_write "$file" "$scratch/new" || rc=1
      fi
      ;;
    remove)
      if [[ -f "$file" ]]; then
        if ! _inir_rc_strip "$file" "$scratch/rest" path env; then
          rc=1
        elif ! cmp -s -- "$file" "$scratch/rest"; then
          text="$(<"$scratch/rest")"
          if [[ -z "${text//[[:space:]]/}" ]]; then
            _inir_rc_drop "$file" "$scratch" || rc=1
          else
            printf '%s\n' "${text%"${text##*[![:space:]]}"}" > "$scratch/new" && _inir_rc_write "$file" "$scratch/new" || rc=1
          fi
        fi
      fi
      ;;
    prune)
      if [[ -f "$file" ]]; then
        text="$(<"$file")"
        if [[ -n "${text//[[:space:]]/}" ]] && _inir_rc_strip "$file" "$scratch/rest" path env; then
          text="$(<"$scratch/rest")"
          [[ -n "${text//[[:space:]]/}" ]] || _inir_rc_drop "$file" "$scratch" || rc=1
        fi
      fi
      ;;
  esac
  rm -rf -- "$scratch"
  return "$rc"
}

# v2 ran its helpers in a Python venv; inir-accel runs them now. It goes once the installed shell never reads it
# (a rollback to v2 still does): an update calls this before touching anything and once the new shell loaded. The
# fish file and the rc lines only ever carried its path.
retire_python_venv() {
  local runtime="${II_TARGET:-${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/inir}"
  local fish="${XDG_CONFIG_HOME:-$HOME/.config}/fish/conf.d/inir-env.fish" rc
  [[ -e "$runtime/sdata/uv/requirements.txt" ]] && return 0
  rm -rf -- "${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/.venv"
  if [[ -f "$fish" ]] && ! grep -qv -e '^#' -e '^$' -e '^set -gx INIR_VENV ' -e '^set -gx ILLOGICAL_IMPULSE_VIRTUAL_ENV ' "$fish"; then
    rm -f -- "$fish"
  fi
  for rc in bash zsh; do
    [[ -f "$HOME/.${rc}rc" ]] && grep -q '^export INIR_VENV=' "$HOME/.${rc}rc" && grep -qxF '# iNiR environment' "$HOME/.${rc}rc" \
      && write_inir_shell_env "$HOME/.${rc}rc" "$rc"
  done
  return 0
}

# Writes the iNiR environment block into a bash or zsh rc file.
write_inir_shell_env() {
  local rc_file="$1" shell_name="$2"
  sed -i '/iNiR-env.sh/d' "$rc_file" 2>/dev/null || true
  inir_rc_block set env "$rc_file" <<EOF
# Terminal colors (Material You from the wallpaper) and the prompt only where someone types: ssh commands, scp and
# scripts that read this file get clean output
case \$- in *i*)
  if [ -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt ]; then
    cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
  fi
  # Starship prompt (fish is wired via config.fish; ${shell_name} needs its own init)
  if command -v starship >/dev/null 2>&1; then
    eval "\$(starship init ${shell_name})"
  fi
  ;;
esac
EOF
}

function ensure_launcher_path_in_shells(){
  local launcher_dir="$1"
  [[ -n "$launcher_dir" ]] || return 0

  local body="case \":\$PATH:\" in
  *:\"${launcher_dir}\":*) ;;
  *) export PATH=\"${launcher_dir}:\$PATH\" ;;
esac"
  local shell_file=""

  # Older installers created every profile; a ~/.bash_profile holding only our
  # block hides ~/.profile from bash login shells, so those files go away.
  for shell_file in "$HOME/.bash_profile" "$HOME/.zprofile" "$HOME/.zshrc"; do
    inir_rc_block prune "$shell_file" || true
  done

  # Only profiles that exist get the block, plus one login profile per shell.
  if [[ ! -f "$HOME/.profile" && ! -f "$HOME/.bash_profile" && ! -f "$HOME/.bash_login" ]]; then
    : >"$HOME/.profile"
  fi
  if [[ "$(basename -- "${SHELL:-}")" == zsh && ! -f "$HOME/.zprofile" && ! -f "$HOME/.zshrc" ]]; then
    : >"$HOME/.zprofile"
  fi
  for shell_file in "$HOME/.profile" "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.bashrc" \
                    "$HOME/.zprofile" "$HOME/.zshrc"; do
    [[ -f "$shell_file" ]] || continue
    printf '%s\n' "$body" | inir_rc_block set path "$shell_file" || true
  done

  local fish_conf_dir="${XDG_CONFIG_HOME}/fish/conf.d"
  mkdir -p "$fish_conf_dir"
  cat > "${fish_conf_dir}/inir-path.fish" << EOF
if not contains -- "${launcher_dir}" \$PATH
    set -gx PATH "${launcher_dir}" \$PATH
end
EOF

  if has_usable_systemd_user_manager; then
    local manager_path
    manager_path="$(systemctl --user show-environment 2>/dev/null \
      | sed -n 's/^PATH=//p' | head -1)"
    if [[ -n "$manager_path" ]]; then
      case ":${manager_path}:" in
        *":${launcher_dir}:"*) ;;
        *) systemctl --user set-environment "PATH=${launcher_dir}:${manager_path}" 2>/dev/null || true ;;
      esac
    fi
  fi
}

repair_legacy_niri_shell_startup() {
  INIR_LEGACY_NIRI_STARTUP_REPAIRED=0
  local file tmp line changed

  for file in "${XDG_CONFIG_HOME}/niri/config.d/50-startup.kdl" "${XDG_CONFIG_HOME}/niri/config.kdl"; do
    [[ -f "$file" ]] || continue
    tmp="${file}.inir-repair.$$"
    changed=0
    : > "$tmp"
    while IFS= read -r line || [[ -n "$line" ]]; do
      if grep -Eq '^[[:space:]]*spawn-at-startup[[:space:]]+"([^"]*/)?inir"[[:space:]]+"start"([[:space:]]*//.*)?[[:space:]]*$|^[[:space:]]*spawn-at-startup[[:space:]]+"qs"[[:space:]]+"-c"[[:space:]]+"(ii|inir)"([[:space:]]*//.*)?[[:space:]]*$' <<< "$line"; then
        changed=1
        continue
      fi
      printf '%s\n' "$line" >> "$tmp"
    done < "$file"
    if [[ "$changed" -eq 1 ]]; then
      mv "$tmp" "$file"
      ((INIR_LEGACY_NIRI_STARTUP_REPAIRED++)) || true
    else
      rm -f "$tmp"
    fi
  done
}

# What v2 installs still carry, set right on every update and safe to repeat: the clipboard watcher on the
# deleted clipboard-store.py, borders that made self-drawn windows opaque, Waffle's own hide-city switch, and
# (only on the first update off v2, while its migrations.json is still there) the clock faded at Dimming 70.
repair_v2_leftovers() {
  INIR_V2_LEFTOVERS_REPAIRED=0
  local niri="${XDG_CONFIG_HOME:-$HOME/.config}/niri" conf state file rules line tmp accel dest shell
  # `inir completions install` linked into scripts/completions, which left the base: the binary writes its own.
  for dest in "${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions/inir" \
      "${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions/_inir" \
      "${XDG_CONFIG_HOME:-$HOME/.config}/fish/completions/inir.fish"; do
    [[ -L "$dest" && "$(readlink "$dest")" == */scripts/completions/inir.* ]] || continue
    case "$dest" in
      */bash-completion/*) shell=bash ;;
      */_inir) shell=zsh ;;
      *) shell=fish ;;
    esac
    rm -f "$dest"
    "${XDG_DATA_HOME:-$HOME/.local/share}/inir/cli/inir" completions install "$shell" >/dev/null 2>&1 || true
    ((INIR_V2_LEFTOVERS_REPAIRED++)) || true
  done
  declare -F inir_config_file >/dev/null || source "${REPO_ROOT}/scripts/lib/config-path.sh"
  conf="$(inir_config_file)"
  state="$(inir_config_dir)/migrations.json"

  file="$niri/config.d/50-startup.kdl"
  if [[ -f "$file" ]] && grep -q 'scripts/clipboard-store\.py' "$file"; then
    sed -i 's|scripts/clipboard-store\.py|scripts/lib/accel-run clipboard-store|g' "$file" || return 1
    ((INIR_V2_LEFTOVERS_REPAIRED++)) || true
  fi

  rules="$niri/config.d/30-window-rules.kdl"
  if [[ -f "$rules" ]] && ! grep -Eqs '^[[:space:]]*draw-border-with-background[[:space:]]' "$niri/config.kdl" "$niri"/config.d/*.kdl; then
    # the first window-rule with no match or exclude: the one every window takes
    line="$(awk '
      /^[[:space:]]*\/\// { next }
      /^[[:space:]]*window-rule[[:space:]]*\{[[:space:]]*$/ { start = NR; scoped = 0; next }
      start && /^[[:space:]]*(match|exclude)[[:space:]]/ { scoped = 1 }
      start && /^[[:space:]]*\}[[:space:]]*$/ { if (!scoped) { print start; exit } start = 0 }
    ' "$rules")"
    if [[ -n "$line" ]]; then
      sed -i "${line}a\\    draw-border-with-background false" "$rules" || return 1
      ((INIR_V2_LEFTOVERS_REPAIRED++)) || true
    fi
  fi

  # the opt-in Super-tap daemon ran a python file from ~/.local/bin; inir-accel runs it now
  # (until accel is in place the old python keeps working, and the next update gets here)
  accel="${XDG_DATA_HOME:-$HOME/.local/share}/inir/accel/current/inir-accel"
  for file in "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/inir-super-overview.service" \
      "${XDG_CONFIG_HOME:-$HOME/.config}/service/inir-super-overview/run"; do
    if [[ -x "$accel" && -f "$file" ]] && grep -q 'inir_super_overview_daemon\.py' "$file"; then
      line="$(printf '%s' "$accel" | sed 's/[&|\\]/\\&/g')"
      sed -i "s|/usr/bin/env python3 .*inir_super_overview_daemon\.py'\\?|'${line}' super-overview-daemon|" "$file" || return 1
      rm -f "$HOME/.local/bin/inir_super_overview_daemon.py"
      if [[ "$file" == *.service ]]; then
        systemctl --user daemon-reload >/dev/null 2>&1 && systemctl --user try-restart inir-super-overview.service >/dev/null 2>&1
      elif command -v sv >/dev/null 2>&1 && sv status "${file%/run}" 2>/dev/null | grep -q '^run:'; then
        sv restart "${file%/run}" >/dev/null 2>&1
      fi
      ((INIR_V2_LEFTOVERS_REPAIRED++)) || true
    fi
  done

  if [[ -f "$conf" ]]; then
    # the state file is the only sign of a v2 clock; keep it until jq can run
    command -v jq >/dev/null 2>&1 || return 0
    tmp="${conf}.inir-repair.$$"
    if jq -e '.waffles.widgetsPanel | has("weatherHideLocation")' "$conf" >/dev/null 2>&1; then
      jq '(.waffles.widgetsPanel.weatherHideLocation == true) as $hidden
          | .weather.hideLocation = ((.weather.hideLocation // .bar.weather.hideLocation // false) or $hidden)
          | del(.waffles.widgetsPanel.weatherHideLocation)' "$conf" >"$tmp" && mv "$tmp" "$conf" || { rm -f "$tmp"; return 1; }
      ((INIR_V2_LEFTOVERS_REPAIRED++)) || true
    fi
    if [[ -f "$state" ]] && ! grep -q '046-desktop-clock-full-strength' "$state" \
        && jq -e '.background.widgets.clock.dim == 70' "$conf" >/dev/null 2>&1; then
      jq '.background.widgets.clock.dim = 0' "$conf" >"$tmp" && mv "$tmp" "$conf" || { rm -f "$tmp"; return 1; }
      ((INIR_V2_LEFTOVERS_REPAIRED++)) || true
    fi
    repair_v2_shipped_wallpapers || return 1
  fi
  rm -f "$state"
  return 0
}

# v2's welcome wizard set the wallpaper to a picture inside the shell's own files (assets/wallpapers/qs-niri.jpg), and
# those pictures left the base: each one the config still names goes to the person's wallpaper folder (from their own
# copy there, else from the checkout's history) and the config and the wallpaper state follow it. The update runs it
# before the payload sync too, so the old shell moves to the copy before its picture goes.
repair_v2_shipped_wallpapers() {
  command -v jq >/dev/null 2>&1 || return 0
  declare -F inir_config_file >/dev/null || source "${REPO_ROOT}/scripts/lib/config-path.sh"
  local conf pictures dir path name dest rel commit tmp
  local state="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/wallpaper/path.txt"
  conf="$(inir_config_file)"
  [[ -f "$conf" ]] || return 0
  tmp="${conf}.inir-repair.$$"
  pictures="$(xdg-user-dir PICTURES 2>/dev/null || true)"
  [[ -n "$pictures" && "$pictures" == /* && "$pictures" != "$HOME" ]] || pictures="$HOME/Pictures"
  dir="$pictures/Wallpapers"
  while IFS= read -r path; do
    [[ -s "$path" ]] && continue
    name="${path##*/}" dest="$dir/$name" rel="assets/wallpapers/${path##*/}"
    if [[ ! -s "$dest" ]]; then
      commit="$(git -C "$REPO_ROOT" rev-list -1 HEAD -- "$rel" 2>/dev/null || true)"
      [[ -n "$commit" ]] && git -C "$REPO_ROOT" cat-file -e "${commit}^:$rel" 2>/dev/null || continue
      mkdir -p "$dir" || return 1
      git -C "$REPO_ROOT" show "${commit}^:$rel" >"$dest.tmp" && mv "$dest.tmp" "$dest" || { rm -f "$dest.tmp"; return 1; }
    fi
    jq --arg from "$path" --arg to "$dest" 'walk(if type == "string" then (split($from) | join($to)) else . end)' \
      "$conf" >"$tmp" && mv "$tmp" "$conf" || { rm -f "$tmp"; return 1; }
    [[ -f "$state" && "$(<"$state")" == *"$path"* ]] && printf '%s' "$dest" >"$state"
    ((INIR_V2_LEFTOVERS_REPAIRED++)) || true
  done < <(grep -oE '(file://)?/[^"]*/quickshell/(inir|ii)/assets/wallpapers/[^"/]+' "$conf" | sed 's|^file://||' | sort -u)
  return 0
}

sync_user_desktop_integration_from_repo() {
  INIR_DESKTOP_INTEGRATION_CHANGED=0

  local launcher_target="${XDG_BIN_HOME}/inir"
  local icon_source="${REPO_ROOT}/assets/icons/desktop-symbolic.svg"
  local icon_target="${XDG_DATA_HOME}/icons/hicolor/scalable/apps/inir.svg"
  local applications_dir="${XDG_DATA_HOME}/applications"
  local name source target tmp command

  if [[ -f "$icon_source" ]]; then
    mkdir -p "$(dirname "$icon_target")"
    if [[ ! -f "$icon_target" ]] || ! cmp -s "$icon_source" "$icon_target"; then
      cp -f "$icon_source" "$icon_target" || return 1
      ((INIR_DESKTOP_INTEGRATION_CHANGED++)) || true
    fi
  fi

  mkdir -p "$applications_dir" "${XDG_CACHE_HOME:-$HOME/.cache}"
  for name in inir inir-settings; do
    source="${REPO_ROOT}/assets/applications/${name}.desktop"
    [[ -f "$source" ]] || continue
    target="${applications_dir}/${name}.desktop"
    command="service restart"
    [[ "$name" == "inir-settings" ]] && command="settings"
    tmp="${XDG_CACHE_HOME:-$HOME/.cache}/${name}.desktop.$$"
    sed "s|^Exec=.*|Exec=${launcher_target//&/\\&} ${command}|" "$source" > "$tmp" || { rm -f "$tmp"; return 1; }
    if [[ ! -f "$target" ]] || ! cmp -s "$tmp" "$target"; then
      cp -f "$tmp" "$target" || { rm -f "$tmp"; return 1; }
      ((INIR_DESKTOP_INTEGRATION_CHANGED++)) || true
    fi
    rm -f "$tmp"
  done
}

function niri_can_resolve_launcher_dir(){
  local launcher_dir="$1"
  local niri_pid=""
  local niri_path=""

  command -v pgrep >/dev/null 2>&1 || return 1
  niri_pid="$(pgrep -xo niri 2>/dev/null || true)"
  [[ -n "$niri_pid" ]] || return 0
  [[ -r "/proc/${niri_pid}/environ" ]] || return 1

  niri_path="$(tr '\0' '\n' < "/proc/${niri_pid}/environ" \
    | sed -n 's/^PATH=//p' | head -1)"
  [[ -n "$niri_path" ]] || return 1

  case ":${niri_path}:" in
    *":${launcher_dir}:"*) return 0 ;;
    *) return 1 ;;
  esac
}

function backup_clashing_targets(){
  local source_dir="$1"
  local target_dir="$2"
  local backup_dir="$3"
  local -a ignored_list=("${@:4}")

  local clash_list=()
  local source_list=($(ls -A "$source_dir" 2>/dev/null))
  local target_list=($(ls -A "$target_dir" 2>/dev/null))
  local -A target_map
  for i in "${target_list[@]}"; do
    target_map["$i"]=1
  done
  for i in "${source_list[@]}"; do
    if [[ -n "${target_map[$i]}" ]]; then
      clash_list+=("$i")
    fi
  done

  local args_includes=()
  for i in "${clash_list[@]}"; do
    if [[ -d "$target_dir/$i" ]]; then
      args_includes+=(--include="/$i/")
      args_includes+=(--include="/$i/**")
    else
      args_includes+=(--include="/$i")
    fi
  done
  args_includes+=(--exclude='*')

  if [ ${#clash_list[@]} -gt 0 ]; then
    x mkdir -p $backup_dir
    x rsync -av --progress "${args_includes[@]}" "$target_dir/" "$backup_dir/"
  fi
}

function dedup_and_sort_listfile(){
  if ! test -f "$1"; then
    echo "File not found: $1" >&2; return 2
  else
    temp="$(mktemp)"
    sort -u -- "$1" > "$temp"
    mv -f -- "$temp" "$2"
  fi
}

# Intelligent privilege escalation: sudo for terminal, pkexec for graphical/IPC mode
# Usage: elevate command [args...]
# Returns: exit code of the elevated command
function elevate() {
  if [[ -t 0 ]] && [[ -t 1 ]]; then
    # Interactive terminal available — use sudo
    sudo "$@"
  elif sudo -n true 2>/dev/null; then
    # No terminal but passwordless sudo works (automation, VM checkers)
    sudo "$@"
  elif command -v pkexec &>/dev/null; then
    # No terminal but pkexec available — use graphical auth dialog
    pkexec "$@"
  else
    # Fallback to sudo (will likely fail without terminal, but try anyway)
    sudo "$@"
  fi
}

# Check if we can elevate privileges (either via terminal sudo or pkexec)
# Returns: 0 if elevation is possible, 1 otherwise
function can_elevate() {
  if [[ -t 0 ]] && [[ -t 1 ]]; then
    return 0  # Terminal available for sudo
  elif sudo -n true 2>/dev/null; then
    return 0  # Passwordless sudo available (automation)
  elif command -v pkexec &>/dev/null && [[ -n "$DISPLAY" || -n "$WAYLAND_DISPLAY" ]]; then
    return 0  # Graphical session with pkexec available
  else
    return 1  # No way to elevate
  fi
}

inir_user_service_is_masked() {
  local service_path="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/inir.service"
  local state

  if [[ -L "$service_path" ]] && [[ "$(readlink -f "$service_path" 2>/dev/null || true)" == "/dev/null" ]]; then
    return 0
  fi

  has_usable_systemd_user_manager || return 1
  state="$(systemctl --user is-enabled inir.service 2>/dev/null || true)"
  [[ "$state" == "masked" || "$state" == "masked-runtime" ]]
}

repair_legacy_quickshell_malloc_environment() {
  local conf="${XDG_CONFIG_HOME:-$HOME/.config}/environment.d/quickshell-mem.conf"
  local repaired=0

  INIR_LEGACY_MALLOC_ENV_REPAIRED=0
  INIR_LEGACY_MALLOC_ENV_CURRENT_PROCESS=0

  if [[ -f "$conf" ]] && grep -Eq \
      '^[[:space:]]*MALLOC_ARENA_MAX=2[[:space:]]*$|^[[:space:]]*MALLOC_MMAP_THRESHOLD_=131072[[:space:]]*$' \
      "$conf" 2>/dev/null; then
    local tmp="${conf}.inir-repair.$$"

    local filter_rc=0
    grep -Ev \
        '^[[:space:]]*MALLOC_ARENA_MAX=2[[:space:]]*$|^[[:space:]]*MALLOC_MMAP_THRESHOLD_=131072[[:space:]]*$|^# Quickshell/iNiR memory optimization[[:space:]]*$|^# Prevents glibc malloc arenas from retaining freed wallpaper textures\.[[:space:]]*$|^# See: scripts/quickshell-env\.sh for details\.[[:space:]]*$' \
        "$conf" > "$tmp" || filter_rc=$?
    # grep returns 1 when every line matched the removal filter. That is the
    # expected "delete the now-empty legacy file" case, not a read/filter error.
    if [[ "$filter_rc" -gt 1 ]]; then
      rm -f "$tmp"
      return 1
    fi

    if grep -q '[^[:space:]]' "$tmp" 2>/dev/null; then
      mv "$tmp" "$conf"
    else
      rm -f "$tmp" "$conf"
    fi
    ((repaired++)) || true
  fi

  # The environment.d file can already be gone while the user manager still
  # carries values imported earlier in the login session.  Cleanup must not be
  # gated on finding the file or Doctor reports success while future services
  # keep inheriting the retired allocator policy.
  if [[ "${MALLOC_ARENA_MAX:-}" == "2" ]]; then
    unset MALLOC_ARENA_MAX
    INIR_LEGACY_MALLOC_ENV_CURRENT_PROCESS=1
    ((repaired++)) || true
  fi
  if [[ "${MALLOC_MMAP_THRESHOLD_:-}" == "131072" ]]; then
    unset MALLOC_MMAP_THRESHOLD_
    INIR_LEGACY_MALLOC_ENV_CURRENT_PROCESS=1
    ((repaired++)) || true
  fi

  if has_usable_systemd_user_manager; then
    local manager_env=""
    manager_env="$(systemctl --user show-environment 2>/dev/null || true)"
    if grep -qx 'MALLOC_ARENA_MAX=2' <<< "$manager_env"; then
      if systemctl --user unset-environment MALLOC_ARENA_MAX >/dev/null 2>&1; then
        ((repaired++)) || true
      fi
    fi
    if grep -qx 'MALLOC_MMAP_THRESHOLD_=131072' <<< "$manager_env"; then
      if systemctl --user unset-environment MALLOC_MMAP_THRESHOLD_ >/dev/null 2>&1; then
        ((repaired++)) || true
      fi
    fi
  fi

  INIR_LEGACY_MALLOC_ENV_REPAIRED=$repaired
  return 0
}

# A systemctl binary alone does not prove the user manager is usable. The socket exists only while the manager
# runs: a probe that times out is a busy manager, still systemd. Reading it as runit would move a systemd host
# to runsvdir and strip its import-environment line.
function has_usable_systemd_user_manager() {
  [[ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/systemd/private" ]] || return 1
  timeout 3s systemctl --user show-environment >/dev/null 2>&1
  local rc=$?
  [[ $rc -eq 0 || $rc -eq 124 ]]
}

has_active_turnstile() {
  local service_path="${INIR_TURNSTILED_SERVICE_PATH:-/var/service/turnstiled}"
  [[ -e "$service_path" ]] || return 1
  if command -v sv >/dev/null 2>&1 && sv status "$service_path" 2>/dev/null | grep -q '^run:'; then
    return 0
  fi
  pgrep -x turnstiled >/dev/null 2>&1
}

configure_turnstile_user_services() {
  local service_root="${XDG_CONFIG_HOME:-$HOME/.config}/service"
  local examples="${INIR_TURNSTILE_EXAMPLES:-/usr/share/examples/turnstile}"
  local target

  [[ -f "$examples/dbus.run" && -f "$examples/dbus.check" ]] || {
    printf 'Turnstile D-Bus examples not found in %s\n' "$examples" >&2
    return 1
  }

  mkdir -p "$service_root/dbus" "$service_root/turnstile-ready"
  for target in run check; do
    install -m 755 "$examples/dbus.$target" "$service_root/dbus/$target"
  done

  local ready_conf="$service_root/turnstile-ready/conf"
  touch "$ready_conf"
  if ! grep -Eq '^core_services=.*dbus' "$ready_conf"; then
    if grep -q '^core_services=' "$ready_conf"; then
      sed -i -E 's/^core_services="([^"]*)"/core_services="\1 dbus"/' "$ready_conf"
    else
      printf 'core_services="dbus"\n' >> "$ready_conf"
    fi
  fi
}

inir_supervisor() {
  if has_usable_systemd_user_manager; then
    printf 'systemd\n'
  elif has_active_turnstile; then
    printf 'turnstile\n'
  else
    printf 'runsvdir\n'
  fi
}

# elogind's runit service mounts /run/user before starting it, but D-Bus can start elogind first: that later mount
# hides every /run/user/<uid> and logins hang on turnstile. Mounted at stage 1, the order stops mattering.
ensure_void_elogind_mounts() {
  [[ "${OS_GROUP_ID:-}" == void && -d /etc/runit/core-services && -e /etc/sv/elogind ]] || return 0
  local target=/etc/runit/core-services/90-inir-elogind.sh tmp rc
  tmp=$(mktemp) || return 1
  cat >"$tmp" <<'EOF'
# iNiR: the mounts elogind's runit service makes, done before any service can start elogind through D-Bus
mkdir -p /sys/fs/cgroup/elogind
mountpoint -q /sys/fs/cgroup/elogind || mount -t cgroup -o none,name=elogind cgroup /sys/fs/cgroup/elogind
for _inir_d in /run/systemd /run/user; do
  mountpoint -q "$_inir_d" || { mkdir -p "$_inir_d" && mount -t tmpfs -o nosuid,nodev,noexec,mode=0755 none "$_inir_d"; }
done
unset _inir_d
EOF
  if cmp -s "$tmp" "$target"; then rm -f "$tmp"; return 0; fi
  elevate install -Dm644 "$tmp" "$target"; rc=$?
  rm -f "$tmp"; return $rc
}

configure_void_ydotool_uinput() {
  [[ "${OS_GROUP_ID:-}" == void && "${INSTALL_TOOLKIT:-true}" == true ]] || return 0
  command -v ydotoold >/dev/null 2>&1 || return 0

  local module_conf=/etc/modules-load.d/inir-ydotool.conf
  local udev_rule=/etc/udev/rules.d/80-inir-ydotool.rules
  local rule='KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"'
  if [[ "$(cat "$module_conf" 2>/dev/null)" == uinput ]] \
      && grep -Fxq "$rule" "$udev_rule" 2>/dev/null \
      && [[ -c /dev/uinput ]] \
      && [[ "$(stat -c %G /dev/uinput 2>/dev/null)" == input ]] \
      && [[ "$(stat -c %a /dev/uinput 2>/dev/null)" == 660 ]]; then
    log_success "ydotool uinput permissions already configured"
    return 0
  fi

  if [[ "${ask:-true}" != true ]] \
      || tui_confirm "Configure uinput permissions for ydotool?" "yes"; then
    if elevate sh -c 'mkdir -p /etc/udev/rules.d && printf "%s\n" uinput > /etc/modules-load.d/inir-ydotool.conf && printf "%s\n" '\''KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"'\'' > /etc/udev/rules.d/80-inir-ydotool.rules && udevadm control --reload-rules && modprobe uinput && udevadm trigger --name-match=uinput && udevadm settle'; then
      if [[ -c /dev/uinput ]] \
          && [[ "$(stat -c %G /dev/uinput 2>/dev/null)" == input ]] \
          && [[ "$(stat -c %a /dev/uinput 2>/dev/null)" == 660 ]]; then
        log_success "ydotool uinput permissions configured"
        return 0
      fi
    fi
    log_warning "Could not configure ydotool uinput permissions"
    return 1
  fi

  log_info "Configure ydotool with: echo uinput | sudo tee /etc/modules-load.d/inir-ydotool.conf"
  log_info "Then add a udev rule granting group input mode 0660 on /dev/uinput and load the uinput module"
}

# Never replace another enabled display manager.
configure_void_sddm_service() {
  [[ "${OS_GROUP_ID:-}" == void ]] || return 0

  local service_dir="${INIR_SDDM_SERVICE_DIR:-/etc/sv/sddm}"
  local service_root="${INIR_RUNIT_SERVICE_ROOT:-/var/service}"
  local service_link="${service_root}/sddm"
  local niri_session_entry="${INIR_NIRI_SESSION_ENTRY:-/usr/share/wayland-sessions/niri.desktop}"
  local dbus_system_socket="${INIR_DBUS_SYSTEM_SOCKET:-/run/dbus/system_bus_socket}"
  local dm competitor attempt
  local dbus_ready=false

  if [[ ! -d "$service_dir" ]]; then
    log_warning "SDDM service directory missing (${service_dir}); reinstall the sddm package"
    return 1
  fi

  if [[ ! -f "$niri_session_entry" ]] \
      || ! grep -Eq '^Exec=.*/niri[[:space:]]+--session([[:space:]]|$)' "$niri_session_entry"; then
    log_warning "Niri display-manager session entry is missing or invalid (${niri_session_entry})"
    return 1
  fi

  if [[ ! -L "${service_root}/dbus" ]]; then
    log_warning "D-Bus runit service is not enabled; refusing to enable SDDM"
    log_info "Enable the Void session services first, then retry ./setup install"
    return 1
  fi

  if [[ -S "$dbus_system_socket" ]]; then
    dbus_ready=true
  elif command -v sv >/dev/null 2>&1; then
    for attempt in 1 2 3; do
      if sv status "${service_root}/dbus" 2>/dev/null | grep -q '^run:'; then
        dbus_ready=true
        break
      fi
      sleep 1
    done
  fi
  if [[ "$dbus_ready" != true ]]; then
    log_warning "D-Bus system bus is not reachable; refusing to enable SDDM"
    return 1
  fi

  if [[ -L "$service_link" ]] \
      && [[ "$(readlink -f "$service_link" 2>/dev/null)" == "$(readlink -f "$service_dir" 2>/dev/null)" ]]; then
    log_success "SDDM runit service already enabled"
    return 0
  fi

  if [[ -e "$service_link" || -L "$service_link" ]]; then
    log_warning "Existing ${service_link} is not the packaged SDDM service; leaving it unchanged"
    return 0
  fi

  for dm in gdm lightdm lxdm greetd xdm; do
    competitor="${service_root}/${dm}"
    if [[ -e "$competitor" || -L "$competitor" ]]; then
      log_warning "Competing display manager detected (${dm}); skipping SDDM activation"
      log_info "Disable ${competitor} first if you want SDDM to own graphical login"
      return 0
    fi
  done

  if [[ "${ask:-true}" == true ]]; then
    if ! tui_confirm "Enable SDDM display manager?" "yes"; then
      log_info "SDDM left disabled; start Niri manually with: niri --session"
      log_info "Enable later with: sudo ln -s ${service_dir} ${service_link}"
      return 0
    fi
  elif [[ "${assume_yes:-false}" != true ]]; then
    log_info "SDDM left disabled in non-interactive mode"
    log_info "Enable later with: sudo ln -s ${service_dir} ${service_link}"
    return 0
  fi

  if elevate ln -s "$service_dir" "$service_link"; then
    log_success "SDDM display manager enabled for this boot and future boots"
    return 0
  fi

  log_warning "Could not enable SDDM display manager"
  return 1
}

# Migrate network ownership atomically so failed activation can restore the previous services.
configure_void_networkmanager_service() {
  [[ "${OS_GROUP_ID:-}" == void ]] || return 0

  local service_dir="${INIR_NETWORKMANAGER_SERVICE_DIR:-/etc/sv/NetworkManager}"
  local service_root="${INIR_RUNIT_SERVICE_ROOT:-/var/service}"
  local service_link="${service_root}/NetworkManager"
  local competitor link index rollback_index
  local networkmanager_enabled=false
  local -a competitors=(dhcpcd wpa_supplicant wicd)
  local -a enabled_links=()
  local -a enabled_targets=()

  if [[ ! -d "$service_dir" ]]; then
    log_warning "NetworkManager service directory missing (${service_dir}); reinstall the NetworkManager package"
    return 1
  fi
  if [[ ! -d "$service_root" ]]; then
    log_warning "Void runit service root is missing (${service_root})"
    return 1
  fi

  if [[ -L "$service_link" ]] \
      && [[ "$(readlink -f "$service_link" 2>/dev/null)" == "$(readlink -f "$service_dir" 2>/dev/null)" ]]; then
    networkmanager_enabled=true
  elif [[ -e "$service_link" || -L "$service_link" ]]; then
    log_warning "Existing ${service_link} is not the packaged NetworkManager service; leaving it unchanged"
    return 1
  fi

  for competitor in "${competitors[@]}"; do
    link="${service_root}/${competitor}"
    if [[ -L "$link" ]]; then
      enabled_links+=("$link")
      enabled_targets+=("$(readlink "$link")")
    fi
  done

  if [[ "$networkmanager_enabled" == true && ${#enabled_links[@]} -eq 0 ]]; then
    log_success "NetworkManager runit service already enabled"
    return 0
  fi

  if [[ ${#enabled_links[@]} -gt 0 ]]; then
    if [[ "${ask:-true}" != true && "${assume_yes:-false}" != true ]]; then
      log_info "NetworkManager migration left unchanged in non-interactive mode"
      log_info "Disable dhcpcd/wpa_supplicant/wicd and enable NetworkManager when a brief network interruption is acceptable"
      return 0
    fi
    if [[ "${ask:-true}" == true ]]; then
      log_warning "Switching network managers may briefly interrupt connectivity"
      if ! tui_confirm "Replace enabled dhcpcd/wpa_supplicant/wicd services with NetworkManager?" "yes"; then
        log_info "Existing Void network services left unchanged"
        return 0
      fi
    fi

    for index in "${!enabled_links[@]}"; do
      if ! elevate rm -f -- "${enabled_links[$index]}"; then
        for ((rollback_index = 0; rollback_index < index; rollback_index++)); do
          elevate ln -s "${enabled_targets[$rollback_index]}" "${enabled_links[$rollback_index]}" >/dev/null 2>&1 || true
        done
        log_warning "Could not disable the existing Void network services; restored previous service links"
        return 1
      fi
    done
  elif [[ "$networkmanager_enabled" != true ]]; then
    if [[ "${ask:-true}" != true && "${assume_yes:-false}" != true ]]; then
      log_info "NetworkManager left disabled in non-interactive mode"
      log_info "Enable later with: sudo ln -s ${service_dir} ${service_link}"
      return 0
    fi
    if [[ "${ask:-true}" == true ]] && ! tui_confirm "Enable NetworkManager system service?" "yes"; then
      log_info "NetworkManager left disabled"
      return 0
    fi
  fi

  if [[ "$networkmanager_enabled" != true ]] && ! elevate ln -s "$service_dir" "$service_link"; then
    for rollback_index in "${!enabled_links[@]}"; do
      elevate ln -s "${enabled_targets[$rollback_index]}" "${enabled_links[$rollback_index]}" >/dev/null 2>&1 || true
    done
    log_warning "Could not enable NetworkManager; restored previous Void network service links"
    return 1
  fi

  if [[ ${#enabled_links[@]} -gt 0 ]]; then
    log_success "NetworkManager enabled; competing Void network services disabled"
    log_info "Reconnect through NetworkManager if the active connection does not transfer automatically"
  else
    log_success "NetworkManager runit service enabled"
  fi
  return 0
}

# Install only iNiR-owned service files; never replace a local WARP service.
configure_void_warp_service() {
  [[ "${OS_GROUP_ID:-}" == void ]] || return 0
  [[ -x /usr/local/bin/warp-svc ]] || return 0

  local run_file=/etc/sv/warp-svc/run
  local log_run_file=/etc/sv/warp-svc/log/run
  local service_link=/var/service/warp-svc
  local temp_dir run_tmp log_tmp
  if [[ -e /etc/sv/warp-svc && ! -f "$run_file" ]]; then
    log_warning "Existing WARP service directory is not managed by iNiR; leaving it unchanged"
    return 0
  fi
  if [[ -e "$run_file" ]] && ! grep -q '^# Managed by iNiR\.' "$run_file"; then
    log_warning "Existing WARP service is not managed by iNiR; leaving it unchanged"
    return 0
  fi
  if [[ -e "$service_link" || -L "$service_link" ]] \
      && [[ ! -L "$service_link" || "$(readlink "$service_link")" != /etc/sv/warp-svc ]]; then
    log_warning "Existing WARP service link is not managed by iNiR; leaving it unchanged"
    return 0
  fi
  if [[ -e "$log_run_file" ]] && ! grep -q '^# Managed by iNiR\.' "$log_run_file"; then
    if [[ ! -x "$log_run_file" ]]; then
      log_warning "Existing WARP logger is not managed by iNiR and is not executable; leaving it unchanged"
      return 0
    fi
    log_info "Keeping existing custom WARP runit logger"
  fi
  if [[ -f "$run_file" ]] && grep -q '^# Managed by iNiR\.' "$run_file" \
      && [[ -x "$log_run_file" ]] \
      && [[ -L "$service_link" ]] && [[ "$(readlink "$service_link")" == /etc/sv/warp-svc ]]; then
    log_success "Cloudflare WARP runit service already enabled"
    return 0
  fi

  if [[ "${ask:-true}" != true ]] || tui_confirm "Enable Cloudflare WARP system service?" "yes"; then
    temp_dir="$(mktemp -d)" || return 1
    run_tmp="$temp_dir/run"
    log_tmp="$temp_dir/log-run"
    printf '%s\n' '#!/bin/sh' '# Managed by iNiR.' \
      'mkdir -p /var/lib/cloudflare-warp /run/cloudflare-warp /var/log/cloudflare-warp' \
      'exec /usr/local/bin/warp-svc' > "$run_tmp"
    printf '%s\n' '#!/bin/sh' '# Managed by iNiR.' \
      'exec vlogger -t warp-svc -p daemon' > "$log_tmp"
    if elevate mkdir -p /etc/sv/warp-svc/log /var/lib/cloudflare-warp /run/cloudflare-warp /var/log/cloudflare-warp \
        && elevate install -m 0755 "$run_tmp" "$run_file" \
        && {
          if [[ ! -e "$log_run_file" ]] || grep -q '^# Managed by iNiR\.' "$log_run_file"; then
            elevate install -m 0755 "$log_tmp" "$log_run_file"
          else
            true
          fi
        } \
        && elevate ln -sfn /etc/sv/warp-svc "$service_link"; then
      rm -rf "$temp_dir"
      if command -v sv >/dev/null 2>&1 && [[ -L "$service_link" ]]; then
        elevate sv exit "$service_link" >/dev/null 2>&1 || true
      fi
      log_success "Cloudflare WARP runit service enabled"
    else
      rm -rf "$temp_dir"
      log_warning "Could not enable Cloudflare WARP runit service"
      return 1
    fi
  else
    log_info "Enable Cloudflare WARP with: sudo ln -s /etc/sv/warp-svc /var/service/"
  fi
}

# Void does not activate PipeWire user services; only replace files marked as iNiR-owned.
reconcile_audio_user_services() {
  local supervisor="$1"
  local service_root="${XDG_CONFIG_HOME:-$HOME/.config}/service"
  local svc svc_dir run_file bin bin_quoted
  local failed=0

  for svc in pipewire wireplumber pipewire-pulse; do
    svc_dir="$service_root/$svc"
    run_file="$svc_dir/run"
    if [[ "$supervisor" == systemd ]]; then
      if [[ -f "$run_file" ]] && grep -q '^# Managed by iNiR\.' "$run_file"; then
        command -v sv >/dev/null 2>&1 && sv down "$svc_dir" >/dev/null 2>&1 || true
        rm -rf "$svc_dir" || failed=1
      fi
      continue
    fi
    bin="$(command -v "$svc" 2>/dev/null || true)"
    if [[ -z "$bin" ]]; then
      if [[ -f "$run_file" ]] && grep -q '^# Managed by iNiR\.' "$run_file"; then
        rm -rf "$svc_dir" || failed=1
      fi
      continue
    fi
    if [[ -f "$run_file" ]] && ! grep -q '^# Managed by iNiR\.' "$run_file"; then
      continue
    fi
    mkdir -p "$svc_dir" || {
      failed=1
      continue
    }
    bin_quoted="$(printf '%s' "$bin" | sed "s/'/'\\\\''/g")"
    if [[ "$supervisor" == turnstile ]]; then
      printf '#!/bin/sh\n# Managed by iNiR.\nexec chpst -e "$TURNSTILE_ENV_DIR" '\''%s'\''\n' "$bin_quoted" > "$run_file" || failed=1
    else
      printf '#!/bin/sh\n# Managed by iNiR.\nexec '\''%s'\''\n' "$bin_quoted" > "$run_file" || failed=1
    fi
    chmod +x "$run_file" || failed=1
  done
  return "$failed"
}

reconcile_ydotool_user_service() {
  local supervisor="$1"
  local enabled="${2:-true}"
  local service_root="${XDG_CONFIG_HOME:-$HOME/.config}/service"
  local service_dir="$service_root/ydotool"
  local run_file="$service_dir/run"
  local unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
  local unit_file="$unit_dir/ydotool.service"
  local wants_link="$unit_dir/default.target.wants/ydotool.service"
  local bin version service_changed=false
  bin="$(command -v ydotoold 2>/dev/null || true)"
  version="$(ydotoold --version 2>/dev/null || true)"

  if [[ "$enabled" != true || -z "$bin" ]]; then
    if [[ -f "$run_file" ]] && grep -q '^# Managed by iNiR\.' "$run_file"; then
      command -v sv >/dev/null 2>&1 && sv down "$service_dir" >/dev/null 2>&1 || true
      rm -rf "$service_dir"
    fi
    if [[ -f "$unit_file" ]] && grep -q '^# Managed by iNiR\.' "$unit_file"; then
      has_usable_systemd_user_manager && systemctl --user disable --now ydotool.service >/dev/null 2>&1 || true
      rm -f "$unit_file" "$wants_link"
    fi
    return 0
  fi

  if [[ "$supervisor" == systemd ]]; then
    if [[ -f "$run_file" ]] && grep -q '^# Managed by iNiR\.' "$run_file"; then
      command -v sv >/dev/null 2>&1 && sv down "$service_dir" >/dev/null 2>&1 || true
      rm -rf "$service_dir"
    fi
    if [[ -f "$unit_file" ]] && grep -q '^# Managed by iNiR\.' "$unit_file" \
        && ! grep -Fxq "# Version: $version" "$unit_file"; then
      service_changed=true
    fi
    if [[ ! -f "$unit_file" ]] || grep -q '^# Managed by iNiR\.' "$unit_file"; then
      mkdir -p "$unit_dir"
      printf '# Managed by iNiR.\n# Version: %s\n[Unit]\nDescription=ydotool input daemon\n\n[Service]\nExecStart=%s\nRestart=always\n\n[Install]\nWantedBy=default.target\n' "$version" "$bin" > "$unit_file" || return 1
    fi
    if ! systemctl --user daemon-reload >/dev/null 2>&1 \
        || ! systemctl --user enable --now ydotool.service >/dev/null 2>&1; then
      return 1
    fi
    if $service_changed; then
      systemctl --user restart ydotool.service >/dev/null 2>&1 || return 1
    fi
    return
  fi

  if [[ -f "$unit_file" ]] && grep -q '^# Managed by iNiR\.' "$unit_file"; then
    rm -f "$unit_file" "$wants_link"
  fi
  if [[ -f "$run_file" ]] && ! grep -q '^# Managed by iNiR\.' "$run_file"; then
    return 0
  fi
  if [[ -f "$run_file" ]] && ! grep -Fxq "# Version: $version" "$run_file"; then
    service_changed=true
  fi
  mkdir -p "$service_dir" || return 1
  if [[ "$supervisor" == turnstile ]]; then
    printf '#!/bin/sh\n# Managed by iNiR.\n# Version: %s\nexec chpst -e "$TURNSTILE_ENV_DIR" %s\n' "$version" "$bin" > "$run_file" || return 1
  else
    printf '#!/bin/sh\n# Managed by iNiR.\n# Version: %s\nexec %s\n' "$version" "$bin" > "$run_file" || return 1
  fi
  chmod +x "$run_file" || return 1
  if $service_changed && command -v sv >/dev/null 2>&1 \
      && sv status "$service_dir" 2>/dev/null | grep -q '^run:'; then
    sv restart "$service_dir" >/dev/null 2>&1 || return 1
  fi
}

reconcile_inir_supervisor() {
  local launcher_path="${XDG_BIN_HOME:-$HOME/.local/bin}/inir"
  local runit_service_dir="${XDG_CONFIG_HOME:-$HOME/.config}/service/inir"
  local runit_run_file="${runit_service_dir}/run"
  local xembed_service_dir="${XDG_CONFIG_HOME:-$HOME/.config}/service/inir-xembedsniproxy"
  local xembed_run_file="${xembed_service_dir}/run"
  local startup_target="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.d/50-startup.kdl"
  [[ -f "$startup_target" ]] || startup_target="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"

  local supervisor
  supervisor="$(inir_supervisor)"

  if [[ -x "$launcher_path" ]]; then
    mkdir -p "$runit_service_dir"
    local launcher_quoted
    launcher_quoted="$(printf '%s' "$launcher_path" | sed "s/'/'\\\\''/g")"
    if [[ "$supervisor" == turnstile ]]; then
      # Turnstile is outside seat0; its shell polkit listener is rejected as the wrong session.
      printf "#!/bin/sh\nexec chpst -e \"\$TURNSTILE_ENV_DIR\" /usr/bin/env QS_DISABLE_POLKIT=1 '%s' run --session\n" "$launcher_quoted" > "$runit_run_file"
    else
      printf "#!/bin/sh\nexec '%s' run --session\n" "$launcher_quoted" > "$runit_run_file"
    fi
    chmod +x "$runit_run_file"
  fi
  if [[ "$supervisor" != systemd ]]; then
    if command -v xembedsniproxy >/dev/null 2>&1; then
      mkdir -p "$xembed_service_dir"
      if [[ "$supervisor" == turnstile ]]; then
        cat > "$xembed_run_file" <<'RUN_EOF'
#!/bin/sh
# Managed by iNiR.
exec chpst -e "$TURNSTILE_ENV_DIR" sh -c '
  [ -n "${DISPLAY:-}" ] || exec pause
  xembed_bin="$(command -v xembedsniproxy 2>/dev/null || true)"
  [ -n "$xembed_bin" ] || exec pause
  exec env QT_NO_XDG_DESKTOP_PORTAL=1 QT_QPA_PLATFORM=xcb "$xembed_bin"
'
RUN_EOF
      else
        cat > "$xembed_run_file" <<'RUN_EOF'
#!/bin/sh
# Managed by iNiR.
[ -n "${DISPLAY:-}" ] || exec pause
xembed_bin="$(command -v xembedsniproxy 2>/dev/null || true)"
[ -n "$xembed_bin" ] || exec pause
exec env QT_NO_XDG_DESKTOP_PORTAL=1 QT_QPA_PLATFORM=xcb "$xembed_bin"
RUN_EOF
      fi
      chmod +x "$xembed_run_file"
    fi
  elif [[ -f "$xembed_run_file" ]] && grep -q '^# Managed by iNiR\.' "$xembed_run_file"; then
    command -v sv >/dev/null 2>&1 && sv down "$xembed_service_dir" >/dev/null 2>&1 || true
    rm -rf "$xembed_service_dir"
  fi
  if [[ "$supervisor" == turnstile ]] && ! configure_turnstile_user_services; then
    return 1
  fi
  reconcile_audio_user_services "$supervisor" || return 1
  if [[ "${OS_GROUP_ID:-}" == void ]]; then
    reconcile_ydotool_user_service "$supervisor" "${INSTALL_TOOLKIT:-true}" || return 1
  fi

  update_inir_startup_supervisor() {
    local file="$1"
    local supervisor="$2"
    local comment block tmp text
    case "$supervisor" in
      systemd)
        comment="// iNiR is managed by the user systemd service (inir.service)."
        block='// BEGIN inir-systemd-environment
// Export XDG_MENU_PREFIX into the systemd user session and rebuild the
// sycoca database so KDE/Qt apps see the correct .desktop entries.
spawn-at-startup "bash" "-c" "systemctl --user import-environment XDG_MENU_PREFIX && kbuildsycoca6"
// END inir-systemd-environment' ;;
      runsvdir)
        comment="// iNiR is managed by the runit user service (service/inir)."
        block="// BEGIN inir-runsvdir-fallback
// iNiR shell supervisor (runsvdir fallback for non-systemd).
// Do not add a compositor startup entry here or you'll get two shells.
spawn-sh-at-startup \"exec runsvdir ~/.config/service\"
// END inir-runsvdir-fallback" ;;
      *)
        comment="// iNiR is managed by the turnstile user service (service/inir)."
        block=$(cat <<'KDL'
// BEGIN inir-turnstile-environment
// Publish Niri's session environment to Turnstile-managed user services.
spawn-sh-at-startup "export PATH=\"$HOME/.local/bin:$PATH\"; if command -v turnstile-update-runit-env >/dev/null 2>&1 && [ -n \"${WAYLAND_DISPLAY:-}\" ] && [ -n \"${XDG_RUNTIME_DIR:-}\" ] && [ -n \"${DBUS_SESSION_BUS_ADDRESS:-}\" ]; then turnstile-update-runit-env PATH WAYLAND_DISPLAY XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS NIRI_SOCKET; if command -v sv >/dev/null 2>&1 && [ -d \"$HOME/.config/service/inir\" ]; then sv restart \"$HOME/.config/service/inir\" >/dev/null 2>&1 || true; fi; fi"
// The shell runs outside this session on Turnstile (QS_DISABLE_POLKIT=1), so Niri starts the agent that answers password prompts.
spawn-sh-at-startup "for agent in /usr/libexec/polkit-gnome-authentication-agent-1 /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1; do if [ -x \"$agent\" ]; then exec \"$agent\"; fi; done"
// END inir-turnstile-environment
KDL
) ;;
    esac
    tmp="$(mktemp "$(dirname "$(realpath -m -- "$file")")/.inir-niri.XXXXXX")" || return 1
    # Whatever an earlier run wrote (any supervisor's block and comment, the old runsvdir and kbuildsycoca lines)
    # goes, then this supervisor's comment and block are appended.
    LC_ALL=C awk '
      { line[NR] = $0 }
      END {
        names = "(systemd-environment|runsvdir-fallback|turnstile-environment)"
        for (i = 1; i <= NR; i++) {
          if (line[i] ~ ("^[ \t]*// BEGIN inir-" names "$")) {
            for (j = i + 1; j <= NR && line[j] !~ ("^[ \t]*// END inir-" names); j++) ;
            if (j <= NR) { for (k = i; k <= j; k++) drop[k] = 1; i = j }
          }
        }
        for (i = 1; i <= NR; i++) {
          if (drop[i]) continue
          if (line[i] ~ /^[ \t]*spawn-sh-at-startup.*runsvdir/) drop[i] = 1
          else if (line[i] ~ /^[ \t]*spawn-at-startup "bash" "-c" "systemctl --user import-environment XDG_MENU_PREFIX && kbuildsycoca6"$/) drop[i] = 1
          else if (line[i] ~ /^[ \t]*\/\/ iNiR is managed by the (user systemd service \(inir\.service\)|runit user service \(service\/inir\)|turnstile user service \(service\/inir\))\.$/ \
                   && line[i + 1] ~ /^[ \t]*\/\/ Do not add a compositor startup entry here or you.ll get two shells\./) { drop[i] = 1; drop[i + 1] = 1; i++ }
        }
        for (i = 1; i <= NR; i++) if (!drop[i]) print line[i]
      }' "$file" > "$tmp" || { rm -f "$tmp"; return 1; }
    text="$(<"$tmp")"
    # the new text lands whole or not at all; a linked config stays a link
    local real
    real="$(realpath -m -- "$file")" || { rm -f "$tmp"; return 1; }
    printf '%s\n\n%s\n%s\n\n%s\n' "${text%"${text##*[![:space:]]}"}" "$comment" \
      "// Do not add a compositor startup entry here or you'll get two shells." "$block" > "$tmp" \
      && chmod "$(stat -c %a -- "$real")" "$tmp" && mv -f -- "$tmp" "$real" || { rm -f "$tmp"; return 1; }
  }

  [[ -f "$startup_target" ]] && update_inir_startup_supervisor "$startup_target" "$supervisor"
  printf '%s\n' "$supervisor"
  return 0
}
