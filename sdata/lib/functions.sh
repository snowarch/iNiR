# Core functions for ii-niri installer
# This is NOT a script for execution, but for loading functions

# shellcheck shell=bash

function try { "$@" || sleep 0; }

function v(){
  if ! ${quiet:-false}; then
    echo -e "####################################################"
    echo -e "${STY_BLUE}[$0]: Next command:${STY_RST}"
    echo -e "${STY_GREEN}$*${STY_RST}"
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
        [yY] | "") echo -e "${STY_BLUE}OK, executing...${STY_RST}" ;break ;;
        [eE]) echo -e "${STY_BLUE}Exiting...${STY_RST}" ;exit ;break ;;
        [sS]) echo -e "${STY_BLUE}Alright, skipping...${STY_RST}" ;execute=false ;break ;;
        "yesforall") echo -e "${STY_BLUE}Alright, won't ask again.${STY_RST}"; ask=false ;break ;;
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
    0) if ! ${quiet:-false}; then echo -e "${STY_BLUE}[$0]: Command \"${STY_GREEN}$*${STY_BLUE}\" finished.${STY_RST}"; fi;;
    1) echo -e "${STY_RED}[$0]: Command \"${STY_GREEN}$*${STY_RED}\" failed. Exiting...${STY_RST}";exit 1;;
    2) echo -e "${STY_RED}[$0]: Command \"${STY_GREEN}$*${STY_RED}\" failed but ignored.${STY_RST}";;
  esac
}

function showfun(){
  echo -e "${STY_BLUE}[$0]: Function \"$1\":${STY_RST}"
  printf "${STY_GREEN}"
  type -a "$1" 2>/dev/null || return 1
  printf "${STY_RST}"
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
    echo -e "${STY_BLUE}[INFO]${STY_RST} $1"
  fi
}

function log_success() {
  if ! ${quiet:-false}; then
    echo -e "${STY_GREEN}[OK]${STY_RST} $1"
  fi
}

function log_warning() {
  # Warnings always shown
  echo -e "${STY_YELLOW}[WARN]${STY_RST} $1"
}

function log_error() {
  # Errors always shown
  echo -e "${STY_RED}[ERROR]${STY_RST} $1" >&2
}

function log_header() {
  if ! ${quiet:-false}; then
    echo -e "\n${STY_PURPLE}=== $1 ===${STY_RST}"
  fi
}

# File operations for 3.files.sh
cp_file(){
  # $1 = source, $2 = target
  local src="$1"
  local dst="$2"

  x mkdir -p "$(dirname "$dst")"

  # Avoid failing when source and destination are the same file
  # (e.g. when ~/.config/quickshell/ii points into the repo).
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

rsync_dir(){
  x mkdir -p "$2"
  local dest="$(realpath -se $2)"
  x mkdir -p "$(dirname ${INSTALLED_LISTFILE})"
  rsync -a --out-format='%i %n' "$1"/ "$2"/ | awk -v d="$dest" '$1 ~ /^>/{ sub(/^[^ ]+ /,""); printf d "/" $0 "\n" }' >> "${INSTALLED_LISTFILE}"
}

rsync_dir__sync(){
  x mkdir -p "$2"
  local dest="$(realpath -se $2)"
  x mkdir -p "$(dirname ${INSTALLED_LISTFILE})"
  rsync -a --delete --out-format='%i %n' "$1"/ "$2"/ | awk -v d="$dest" '$1 ~ /^>/{ sub(/^[^ ]+ /,""); printf d "/" $0 "\n" }' >> "${INSTALLED_LISTFILE}"
}

function install_file(){
  local s=$1
  local t=$2
  if [ -f $t ] && ! ${quiet:-false}; then
    echo -e "${STY_YELLOW}[$0]: \"$t\" will be overwritten.${STY_RST}"
  fi
  v cp_file $s $t
}

function install_file__auto_backup(){
  local s=$1
  local t=$2
  if [ -f $t ];then
    if ! ${quiet:-false}; then
      echo -e "${STY_YELLOW}[$0]: \"$t\" exists.${STY_RST}"
    fi
    if ${INSTALL_FIRSTRUN};then
      if ! ${quiet:-false}; then
        echo -e "${STY_BLUE}[$0]: First run - backing up.${STY_RST}"
      fi
      v mv $t $t.old
      v cp_file $s $t
    else
      if ! ${quiet:-false}; then
        echo -e "${STY_BLUE}[$0]: Not first run - saving as .new${STY_RST}"
      fi
      v cp_file $s $t.new
    fi
  else
    if ! ${quiet:-false}; then
      echo -e "${STY_GREEN}[$0]: \"$t\" does not exist.${STY_RST}"
    fi
    v cp_file $s $t
  fi
}

function install_dir(){
  local s=$1
  local t=$2
  if [ -d $t ] && ! ${quiet:-false}; then
    echo -e "${STY_YELLOW}[$0]: \"$t\" will be merged.${STY_RST}"
  fi
  rsync_dir $s $t
}

function install_dir__sync(){
  local s=$1
  local t=$2
  if [ -d $t ] && ! ${quiet:-false}; then
    echo -e "${STY_YELLOW}[$0]: \"$t\" will be synced (--delete).${STY_RST}"
  fi
  rsync_dir__sync $s $t
}

function install_dir__skip_existed(){
  local s=$1
  local t=$2
  if [ -d $t ];then
    if ! ${quiet:-false}; then
      echo -e "${STY_BLUE}[$0]: \"$t\" exists, skipping.${STY_RST}"
    fi
  else
    if ! ${quiet:-false}; then
      echo -e "${STY_YELLOW}[$0]: \"$t\" does not exist.${STY_RST}"
    fi
    v rsync_dir $s $t
  fi
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
