#!/usr/bin/env bash
set -euo pipefail

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="$XDG_STATE_HOME/quickshell"

# shellcheck source=scripts/lib/config-path.sh
source "$SCRIPT_DIR/../lib/config-path.sh"
CONFIG_FILE="$(inir_config_file)"
MODULE_LOG="$STATE_DIR/user/generated/theming_modules.log"
TARGETS_DIR="$SCRIPT_DIR/targets"
MODULES_DIR="$SCRIPT_DIR/modules"

ensure_generated_dirs() {
  mkdir -p "$STATE_DIR/user/generated"
}

log_module() {
  ensure_generated_dirs
  printf '[%s] [%s] %s\n' "$(date '+%H:%M:%S')" "${COLOR_MODULE_ID:-module}" "$*" >> "$MODULE_LOG"
}

config_bool() {
  local query="$1"
  local fallback="$2"
  if [[ -f "$CONFIG_FILE" ]] && command -v jq >/dev/null 2>&1; then
    jq -r "$query // $fallback" "$CONFIG_FILE" 2>/dev/null || printf '%s\n' "$fallback"
  else
    printf '%s\n' "$fallback"
  fi
}

config_json() {
  local query="$1"
  local fallback="$2"
  if [[ -f "$CONFIG_FILE" ]] && command -v jq >/dev/null 2>&1; then
    jq -r "$query" "$CONFIG_FILE" 2>/dev/null || printf '%s\n' "$fallback"
  else
    printf '%s\n' "$fallback"
  fi
}

venv_python() {
  local venv_path
  if [[ -n "${INIR_VENV:-}" ]]; then
    venv_path="$(eval echo "$INIR_VENV")"
  elif [[ -n "${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-}" ]]; then
    venv_path="$(eval echo "$ILLOGICAL_IMPULSE_VIRTUAL_ENV")"
  else
    venv_path="$HOME/.local/state/quickshell/.venv"
  fi

  local candidate="$venv_path/bin/python3"
  if [[ -x "$candidate" ]]; then
    printf '%s\n' "$candidate"
  else
    printf '%s\n' python3
  fi
}

run_module_script() {
  local module_path="$1"
  if bash "$module_path"; then
    return 0
  fi
  log_module "module failed: $(basename "$module_path")"
  return 1
}

list_theming_modules() {
  find "$MODULES_DIR" -maxdepth 1 -type f -name '*.sh' | sort
}

list_theming_target_manifests() {
  if [[ -d "$TARGETS_DIR" ]]; then
    find "$TARGETS_DIR" -maxdepth 1 -type f -name '*.json' | sort
  fi
}

resolve_target_module_path() {
  local target_id="$1"
  local manifest_path="$TARGETS_DIR/${target_id}.json"
  [[ -f "$manifest_path" ]] || return 1

  local module_name=""
  if command -v jq >/dev/null 2>&1; then
    module_name=$(jq -r '.module // empty' "$manifest_path" 2>/dev/null || true)
  else
    module_name=$(sed -n 's/.*"module"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$manifest_path" | head -1)
  fi

  [[ -n "$module_name" ]] || return 1
  local module_path="$MODULES_DIR/$module_name"
  [[ -f "$module_path" ]] || return 1
  printf '%s\n' "$module_path"
}

list_declared_theming_modules() {
  local manifest
  while IFS= read -r manifest; do
    [[ -n "$manifest" ]] || continue
    local target_id
    target_id="$(basename "$manifest" .json)"
    resolve_target_module_path "$target_id" || true
  done < <(list_theming_target_manifests)
}
