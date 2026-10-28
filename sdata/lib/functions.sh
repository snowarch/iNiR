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

# Marked iNiR blocks in shell profiles: set, remove or prune (see rc-block.py).
inir_rc_block() {
  python3 "${REPO_ROOT}/sdata/lib/rc-block.py" "$@"
}

# Writes the iNiR environment block into a bash or zsh rc file.
write_inir_shell_env() {
  local rc_file="$1" shell_name="$2"
  local venv_path="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/.venv"
  sed -i '/iNiR-env.sh/d' "$rc_file" 2>/dev/null || true
  inir_rc_block set env "$rc_file" <<EOF
export INIR_VENV="${venv_path}"
export ILLOGICAL_IMPULSE_VIRTUAL_ENV="\$INIR_VENV"
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
    python3 - "$file" "$supervisor" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
supervisor = sys.argv[2]
text = path.read_text()

text = re.sub(
    r'(?ms)^[ \t]*// BEGIN inir-(?:systemd-environment|runsvdir-fallback|turnstile-environment)\n'
    r'.*?^[ \t]*// END inir-(?:systemd-environment|runsvdir-fallback|turnstile-environment)\n?',
    '',
    text,
)
text = re.sub(r'(?m)^[ \t]*spawn-sh-at-startup.*runsvdir.*\n?', '', text)
text = re.sub(
    r'(?m)^[ \t]*spawn-at-startup "bash" "-c" '
    r'"systemctl --user import-environment XDG_MENU_PREFIX && kbuildsycoca6"\n?',
    '',
    text,
)
# Remove all supervisor comment variants.
text = re.sub(
    r'(?m)^[ \t]*// iNiR is managed by the (?:user systemd service \(inir\.service\)|runit user service \(service/inir\)|turnstile user service \(service/inir\))\.\n'
    r'^[ \t]*// Do not add a compositor startup entry here or you\'ll get two shells\.\n?',
    '',
    text,
)

if supervisor == "systemd":
    supervisor_comment = '''// iNiR is managed by the user systemd service (inir.service).
// Do not add a compositor startup entry here or you'll get two shells.'''
    block = '''// BEGIN inir-systemd-environment
// Export XDG_MENU_PREFIX into the systemd user session and rebuild the
// sycoca database so KDE/Qt apps see the correct .desktop entries.
spawn-at-startup "bash" "-c" "systemctl --user import-environment XDG_MENU_PREFIX && kbuildsycoca6"
// END inir-systemd-environment'''
elif supervisor == "runsvdir":
    supervisor_comment = '''// iNiR is managed by the runit user service (service/inir).
// Do not add a compositor startup entry here or you'll get two shells.'''
    block = '''// BEGIN inir-runsvdir-fallback
// iNiR shell supervisor (runsvdir fallback for non-systemd).
// Do not add a compositor startup entry here or you'll get two shells.
spawn-sh-at-startup "exec runsvdir ~/.config/service"
// END inir-runsvdir-fallback'''
else:
    supervisor_comment = '''// iNiR is managed by the turnstile user service (service/inir).
// Do not add a compositor startup entry here or you'll get two shells.'''
    block = r'''// BEGIN inir-turnstile-environment
// Publish Niri's session environment to Turnstile-managed user services.
spawn-sh-at-startup "export PATH=\"$HOME/.local/bin:$PATH\"; export INIR_VENV=\"$HOME/.local/state/quickshell/.venv\"; export ILLOGICAL_IMPULSE_VIRTUAL_ENV=\"$INIR_VENV\"; if command -v turnstile-update-runit-env >/dev/null 2>&1 && [ -n \"${WAYLAND_DISPLAY:-}\" ] && [ -n \"${XDG_RUNTIME_DIR:-}\" ] && [ -n \"${DBUS_SESSION_BUS_ADDRESS:-}\" ]; then turnstile-update-runit-env PATH INIR_VENV ILLOGICAL_IMPULSE_VIRTUAL_ENV WAYLAND_DISPLAY XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS NIRI_SOCKET; if command -v sv >/dev/null 2>&1 && [ -d \"$HOME/.config/service/inir\" ]; then sv restart \"$HOME/.config/service/inir\" >/dev/null 2>&1 || true; fi; fi"
// The shell runs outside this session on Turnstile (QS_DISABLE_POLKIT=1), so Niri starts the agent that answers password prompts.
spawn-sh-at-startup "for agent in /usr/libexec/polkit-gnome-authentication-agent-1 /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1; do if [ -x \"$agent\" ]; then exec \"$agent\"; fi; done"
// END inir-turnstile-environment'''

suffix = f"\n\n{supervisor_comment}\n"
if block:
    suffix += f"\n{block}\n"
path.write_text(text.rstrip() + suffix)
PY
  }

  [[ -f "$startup_target" ]] && update_inir_startup_supervisor "$startup_target" "$supervisor"
  printf '%s\n' "$supervisor"
  return 0
}
