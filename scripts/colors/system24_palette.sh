#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$XDG_STATE_HOME/quickshell"
BIN_DIR="$STATE_DIR/user/generated/bin"
GO_BIN="$BIN_DIR/inir-system24-themegen"
LOG_FILE="$STATE_DIR/user/generated/system24_themegen.log"

mkdir -p "$STATE_DIR/user/generated" "$BIN_DIR"

log() {
  printf '[system24-wrapper] %s\n' "$*" >> "$LOG_FILE"
}

ensure_go_themegen() {
  command -v go &>/dev/null || return 1
  if [[ ! -x "$GO_BIN" || "$REPO_ROOT/go.mod" -nt "$GO_BIN" || "$SCRIPT_DIR/system24_themegen/main.go" -nt "$GO_BIN" ]]; then
    log "building Go system24 generator"
    (cd "$REPO_ROOT" && go build -o "$GO_BIN" ./scripts/colors/system24_themegen) >/dev/null 2>&1 || return 1
  fi
  [[ -x "$GO_BIN" ]]
}

main() {
  if ensure_go_themegen; then
    log "running Go generator"
    exec "$GO_BIN" "$@" >> "$LOG_FILE" 2>&1
  fi

  local python_cmd="python3"
  if [[ -x "$REPO_ROOT/.venv/bin/python3" ]]; then
    python_cmd="$REPO_ROOT/.venv/bin/python3"
  fi
  log "falling back to Python generator: $python_cmd"
  exec "$python_cmd" "$SCRIPT_DIR/system24_palette.py" "$@" >> "$LOG_FILE" 2>&1
}

main "$@"
