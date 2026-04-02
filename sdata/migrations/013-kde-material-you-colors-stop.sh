# Migration: Fix kde-material-you-colors daemon leak
# The wrapper script launches kde-material-you-colors without --stop,
# causing each wallpaper switch to leave an orphan daemon process (~43MB each).
# This migration patches the wrapper to kill the previous instance first.

MIGRATION_ID="013-kde-material-you-colors-stop"
MIGRATION_TITLE="Fix kde-material-you-colors daemon accumulation"
MIGRATION_DESCRIPTION="Patches kde-material-you-colors-wrapper.sh to kill previous daemon before launching a new one.
  Without this fix, every wallpaper switch leaves an orphan process (~43MB RAM each)."
MIGRATION_TARGET_FILE="~/.config/matugen/templates/kde/kde-material-you-colors-wrapper.sh"
MIGRATION_REQUIRED=true

migration_check() {
  local wrapper="${XDG_CONFIG_HOME:-$HOME/.config}/matugen/templates/kde/kde-material-you-colors-wrapper.sh"
  [[ -f "$wrapper" ]] || return 1

  # Needs migration if wrapper does NOT already have --stop
  ! grep -q 'kde-material-you-colors --stop' "$wrapper"
}

migration_preview() {
  echo "Will patch kde-material-you-colors-wrapper.sh to kill previous daemon:"
  echo ""
  echo -e "${STY_GREEN}+ kde-material-you-colors --stop 2>/dev/null${STY_RST}"
  echo "  (added before launching new instance)"
  echo ""
  echo "Also kills any currently orphaned instances to reclaim memory."
}

migration_diff() {
  local wrapper="${XDG_CONFIG_HOME:-$HOME/.config}/matugen/templates/kde/kde-material-you-colors-wrapper.sh"
  echo "Current wrapper (missing --stop):"
  grep 'kde-material-you-colors' "$wrapper" 2>/dev/null | head -5
  echo ""
  echo "After migration: --stop added before each launch to prevent daemon accumulation."
}

migration_apply() {
  local ii_dir
  ii_dir="$(get_runtime_shell_dir)"
  ii_dir="${ii_dir:-${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/inir}"
  local wrapper_src="${ii_dir}/dots/.config/matugen/templates/kde/kde-material-you-colors-wrapper.sh"
  local wrapper_dst="${XDG_CONFIG_HOME:-$HOME/.config}/matugen/templates/kde/kde-material-you-colors-wrapper.sh"

  # Copy the fixed wrapper from the repo
  if [[ -f "$wrapper_src" ]]; then
    mkdir -p "$(dirname "$wrapper_dst")"
    cp -f "$wrapper_src" "$wrapper_dst"
    chmod +x "$wrapper_dst"
  fi

  # Kill any currently accumulated orphan daemons to reclaim memory immediately
  local pids
  pids=$(ps -eo pid,args 2>/dev/null | grep 'kde-material-you-colors' | grep -v grep | grep -v '\-\-stop' | awk '{print $1}')
  if [[ -n "$pids" ]]; then
    local count
    count=$(echo "$pids" | wc -w)
    echo "$pids" | xargs -r kill 2>/dev/null
    echo "  Killed $count orphaned kde-material-you-colors daemon(s)"
  fi
}
