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

function log_info() {
  if ! ${quiet:-false}; then
    echo -e "  ${STY_BLUE}→${STY_RST} $1"
  fi
}

function log_success() {
  if ! ${quiet:-false}; then
    echo -e "  ${STY_GREEN}✓${STY_RST} $1"
  fi
}

function log_warning() {
  echo -e "  ${STY_YELLOW}⚠${STY_RST} $1"
}

function log_error() {
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
INIR_PAYLOAD_TOOL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/runtime-payload.py"
_runtime_rsync() {
  local source_path payload_root relative filters
  source_path="$(realpath -e -- "$1")" || return
  payload_root="$(cd "$(dirname "$INIR_PAYLOAD_TOOL")/../.." && pwd)" || return
  relative="${source_path#"$payload_root"/}"
  [[ "$relative" != "$source_path" ]] || { echo "Install source is outside repository" >&2; return 1; }
  filters="$(python3 "$INIR_PAYLOAD_TOOL" filters --root "$payload_root" --subdir "$relative")" || return
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

function ensure_launcher_path_in_shells(){
  local launcher_dir="$1"
  [[ -n "$launcher_dir" ]] || return 0

  local marker="# iNiR launcher PATH"
  local end_marker="# end iNiR launcher PATH"
  local sh_block="
${marker}
case \":\$PATH:\" in
  *:\"${launcher_dir}\":*) ;;
  *) export PATH=\"${launcher_dir}:\$PATH\" ;;
esac
${end_marker}
"
  local shell_file=""

  for shell_file in "$HOME/.profile" "$HOME/.bash_profile" "$HOME/.bashrc" \
                    "$HOME/.zprofile" "$HOME/.zshrc"; do
    touch "$shell_file"
    sed -i "/${marker}/,/${end_marker}/d" "$shell_file" 2>/dev/null || true
    printf '%s\n' "$sh_block" >> "$shell_file"
  done

  local fish_conf_dir="${XDG_CONFIG_HOME}/fish/conf.d"
  mkdir -p "$fish_conf_dir"
  cat > "${fish_conf_dir}/inir-path.fish" << EOF
if not contains -- "${launcher_dir}" \$PATH
    set -gx PATH "${launcher_dir}" \$PATH
end
EOF

  if command -v systemctl >/dev/null 2>&1; then
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

  command -v systemctl >/dev/null 2>&1 || return 1
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

  if command -v systemctl >/dev/null 2>&1; then
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
