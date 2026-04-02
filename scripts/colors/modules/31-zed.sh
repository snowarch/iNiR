#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/module-runtime.sh"
COLOR_MODULE_ID="zed"

SCSS_FILE="$STATE_DIR/user/generated/material_colors.scss"
PALETTE_FILE="$STATE_DIR/user/generated/palette.json"
TERMINAL_FILE="$STATE_DIR/user/generated/terminal.json"
LEGACY_COLORS_FILE="$STATE_DIR/user/generated/colors.json"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ZED_THEMEGEN_BIN="$STATE_DIR/user/generated/bin/inir-zed-themegen"
ZED_THEMEGEN_SRC="$SCRIPT_DIR/zed_themegen/main.go"
ZED_OUTPUT_FILE="$HOME/.config/zed/themes/ii-theme.json"
ZED_TEMPLATE_FILE="$REPO_ROOT/dots/.config/matugen/templates/zed-colors.json"
ZED_THEMEGEN_LOG="$STATE_DIR/user/generated/code_editor_themes.log"
ZED_LOCK_FILE="$STATE_DIR/user/generated/.zed-themegen.lock"
ZED_INPUT_SIG_FILE="$STATE_DIR/user/generated/.zed-themegen-input.sig"

resolve_go_bin() {
  if command -v go &>/dev/null; then
    command -v go
    return 0
  fi
  if [[ -x /usr/bin/go ]]; then
    printf '%s\n' /usr/bin/go
    return 0
  fi
  return 1
}

ensure_zed_themegen() {
  local go_bin="$1"
  [[ -f "$ZED_THEMEGEN_SRC" ]] || return 1
  mkdir -p "$STATE_DIR/user/generated/bin"
  if [[ -x "$ZED_THEMEGEN_BIN" && "$ZED_THEMEGEN_SRC" -ot "$ZED_THEMEGEN_BIN" ]]; then
    return 0
  fi

  local tmp_bin="$STATE_DIR/user/generated/bin/.inir-zed-themegen.$$"
  if "$go_bin" build -o "$tmp_bin" "$ZED_THEMEGEN_SRC" >> "$ZED_THEMEGEN_LOG" 2>&1; then
    mv -f "$tmp_bin" "$ZED_THEMEGEN_BIN" >> "$ZED_THEMEGEN_LOG" 2>&1 || {
      rm -f "$tmp_bin"
      return 1
    }
    chmod +x "$ZED_THEMEGEN_BIN" >> "$ZED_THEMEGEN_LOG" 2>&1 || true
    return 0
  fi

  rm -f "$tmp_bin"
  return 1
}

with_zed_lock() {
  if ! command -v flock >/dev/null 2>&1; then
    "$@"
    return $?
  fi
  mkdir -p "$STATE_DIR/user/generated"
  exec 9>"$ZED_LOCK_FILE" || return 1
  if ! flock -w 15 9; then
    return 1
  fi
  "$@"
  local rc=$?
  flock -u 9 || true
  return "$rc"
}

run_zed_themegen() {
  local colors_file="$1"
  local args=(
    --scss "$SCSS_FILE"
    --colors "$colors_file"
    --terminal-json "$TERMINAL_FILE"
    --output "$ZED_OUTPUT_FILE"
    --template "$ZED_TEMPLATE_FILE"
  )

  if [[ -x "$ZED_THEMEGEN_BIN" ]]; then
    "$ZED_THEMEGEN_BIN" "${args[@]}" >> "$ZED_THEMEGEN_LOG" 2>&1 && return 0
  fi

  local go_bin
  go_bin="$(resolve_go_bin || true)"
  if [[ -z "$go_bin" ]]; then
    return 1
  fi

  if ensure_zed_themegen "$go_bin"; then
    "$ZED_THEMEGEN_BIN" "${args[@]}" >> "$ZED_THEMEGEN_LOG" 2>&1 && return 0
  fi

  # Build failed (e.g. output path issue). Run directly so theme updates still apply.
  "$go_bin" run "$ZED_THEMEGEN_SRC" "${args[@]}" >> "$ZED_THEMEGEN_LOG" 2>&1
}

build_input_signature() {
  local colors_file="$1"
  {
    for file in "$SCSS_FILE" "$colors_file" "$TERMINAL_FILE" "$ZED_TEMPLATE_FILE" "$ZED_THEMEGEN_SRC"; do
      if [[ -f "$file" ]]; then
        cksum "$file"
      else
        printf 'missing:%s\n' "$file"
      fi
    done
  } | cksum | awk '{print $1 ":" $2}'
}

apply_zed_theme() {
  [[ -f "$SCSS_FILE" ]] || return 0

  local enable_zed
  enable_zed=$(config_json 'if .appearance.wallpaperTheming | has("enableZed") then .appearance.wallpaperTheming.enableZed else true end' true)
  [[ "$enable_zed" == 'true' ]] || return 0

  command -v zed &>/dev/null || command -v zeditor &>/dev/null || return 0

  local colors_file="$PALETTE_FILE"
  [[ -f "$colors_file" ]] || colors_file="$LEGACY_COLORS_FILE"

  local input_sig
  input_sig="$(build_input_signature "$colors_file")"
  if [[ -f "$ZED_OUTPUT_FILE" && -f "$ZED_INPUT_SIG_FILE" ]] && [[ "$(cat "$ZED_INPUT_SIG_FILE" 2>/dev/null || true)" == "$input_sig" ]]; then
    return 0
  fi

  if ! with_zed_lock run_zed_themegen "$colors_file"; then
    log_module "zed theme generation failed; see $ZED_THEMEGEN_LOG"
    return 0
  fi

  printf '%s\n' "$input_sig" > "$ZED_INPUT_SIG_FILE" 2>/dev/null || true
}

main() {
  apply_zed_theme
}

main "$@"
