#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$XDG_STATE_HOME/quickshell"
LOG_FILE="$STATE_DIR/user/generated/system24_themegen.log"

mkdir -p "$STATE_DIR/user/generated"

# Append-only log with no cap of its own. Trimmed here rather than in
# module-runtime.sh's rotate_log because this wrapper runs outside applycolor.sh
# and does not source the module runtime.
if [[ -f "$LOG_FILE" ]]; then
  _log_size="$(stat -c %s "$LOG_FILE" 2>/dev/null || printf '0')"
  if [[ "$_log_size" =~ ^[0-9]+$ ]] && (( _log_size > 1048576 )); then
    if tail -c 262144 "$LOG_FILE" > "$LOG_FILE.rotated" 2>/dev/null; then
      mv -f "$LOG_FILE.rotated" "$LOG_FILE"
    else
      rm -f "$LOG_FILE.rotated"
    fi
  fi
  unset _log_size
fi

log() {
  printf '[system24-wrapper] %s\n' "$*" >> "$LOG_FILE"
}

main() {
  source "$SCRIPT_DIR/../lib/accel.sh"
  if [[ ! -x "$INIR_ACCEL" ]]; then
    log "inir-accel is missing. Run: inir update"
    exit 0
  fi
  exec "$INIR_ACCEL" system24-themegen "$@" >> "$LOG_FILE" 2>&1
}

main "$@"
