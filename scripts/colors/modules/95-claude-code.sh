#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/module-runtime.sh"
COLOR_MODULE_ID="claude-code"

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
THEMES_DIR="$CLAUDE_DIR/themes"
GENERATED_DIR="$STATE_DIR/user/generated"
TERMINAL_FILE="$GENERATED_DIR/terminal.json"
PALETTE_FILE="$GENERATED_DIR/palette.json"
WRITTEN_FILE="$GENERATED_DIR/claude-code-theme.files"
source "$SCRIPT_DIR/../lib/accel.sh"

take_back() {
  [[ -f "$WRITTEN_FILE" ]] || return 0
  local name
  while IFS= read -r name; do
    [[ "$name" =~ ^inir[a-z-]*\.json$ ]] && rm -f "$THEMES_DIR/$name"
  done < "$WRITTEN_FILE"
  rm -f "$WRITTEN_FILE"
  log_module "themes taken back"
}

if [[ "$(config_bool '.appearance.wallpaperTheming.enableClaudeCode' false)" != "true" ]]; then
  take_back
  exit 0
fi

if [[ ! -d "$CLAUDE_DIR" ]] && ! command -v claude >/dev/null 2>&1; then
  log_module "Claude Code not found, skipping"
  exit 0
fi
[[ -s "$TERMINAL_FILE" && -s "$PALETTE_FILE" ]] || { log_module "no terminal palette yet, skipping"; exit 0; }

[[ -x "$INIR_ACCEL" ]] || { log_module "inir-accel is missing. Run: inir update"; exit 0; }
result="$("$INIR_ACCEL" claude-code-theme --terminal "$TERMINAL_FILE" --palette "$PALETTE_FILE" --mode "$(theme_mode)" --out-dir "$THEMES_DIR")"
printf '%s\n' inir.json inir-soft.json inir-monokai.json inir-monokai-soft.json > "$WRITTEN_FILE"
[[ "$result" == changed:* ]] && log_module "$result"
exit 0
