#!/usr/bin/env bash
# Migration 044: the shell is the only polkit agent.
#
# Setup used to spawn an external agent from Niri (polkit-gnome on most installs). Only one agent can register per
# session, so it took the place of the shell's own dialog. This comments out the exact spawn line setup wrote, in
# 50-startup.kdl or a monolithic config.kdl; a line anywhere else (90-user-extra.kdl) is the user's and stays.

MIGRATION_ID="044-polkit-shell-agent-only"
MIGRATION_TITLE="iNiR answers polkit itself"
MIGRATION_DESCRIPTION="Password prompts for installs, mounts and settings now come from iNiR's own dialog, in the look of the family you use. The external agent setup started from Niri is commented out; nothing else in the Niri config changes."
MIGRATION_TARGET_FILE="~/.config/niri/config.d/50-startup.kdl"
MIGRATION_REQUIRED=true

MIGRATION_SESSION_IMPACT=true
MIGRATION_SESSION_REFERENCE="Niri spawn-at-startup polkit agent"
MIGRATION_SESSION_REASON="The external agent that is already running keeps its registration until it exits."
MIGRATION_SESSION_EFFECT="Password prompts keep the old window until you log in again."
MIGRATION_SESSION_ACTION="Log out and back in."

_polkit_agents=(
  "/usr/libexec/kf6/polkit-kde-authentication-agent-1"
  "/usr/lib/polkit-kde-authentication-agent-1"
  "/usr/libexec/polkit-kde-authentication-agent-1"
  "/usr/lib/mate-polkit/polkit-mate-authentication-agent-1"
  "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
  "/usr/libexec/polkit-gnome-authentication-agent-1"
  "/usr/lib/lxpolkit/lxpolkit"
)

_polkit_niri_dir() {
  printf '%s/niri' "${XDG_CONFIG_HOME:-$HOME/.config}"
}

_polkit_files() {
  local dir
  dir="$(_polkit_niri_dir)"
  local file
  for file in "$dir/config.d/50-startup.kdl" "$dir/config.kdl"; do
    [[ -f "$file" ]] && printf '%s\n' "$file"
  done
}

# Whole-line match only: an agent the user wrapped in a script or gave arguments is theirs.
_polkit_line_re() {
  local alternatives="" agent
  for agent in "${_polkit_agents[@]}"; do
    alternatives+="${alternatives:+|}${agent//./\\.}"
  done
  printf '^[[:space:]]*spawn-at-startup[[:space:]]+"(%s)"[[:space:]]*$' "$alternatives"
}

# Someone who turned the shell's agent off relies on the external one.
_polkit_shell_agent_off() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/inir/config.json"
  [[ -f "$config" ]] && command -v jq >/dev/null 2>&1 \
    && [[ "$(jq -r '.modules.polkit == false' "$config" 2>/dev/null)" == "true" ]]
}

migration_check() {
  _polkit_shell_agent_off && return 1
  local re file
  re="$(_polkit_line_re)"
  while IFS= read -r file; do
    grep -Eq "$re" "$file" && return 0
  done < <(_polkit_files)
  return 1
}

migration_preview() {
  local re file
  re="$(_polkit_line_re)"
  while IFS= read -r file; do
    grep -E "$re" "$file" | while IFS= read -r line; do
      echo -e "${STY_RED}- ${line#"${line%%[![:space:]]*}"}${STY_RST}  ($(basename "$file"))"
    done
  done < <(_polkit_files)
  echo ""
  echo "iNiR's own dialog answers password prompts from now on."
}

migration_apply() {
  local re file changed=0
  re="$(_polkit_line_re)"
  while IFS= read -r file; do
    grep -Eq "$re" "$file" || continue
    # The framework backs up 50-startup.kdl; a monolithic config.kdl gets its own copy.
    [[ "$(basename "$file")" == "config.kdl" ]] && create_backup "$file" "config.kdl" >/dev/null
    sed -E -i "s#${re}#// & // iNiR is the polkit agent now#" "$file" || return 1
    changed=1
  done < <(_polkit_files)
  [[ "$changed" == 1 ]] || return 0
  ! migration_check
}
