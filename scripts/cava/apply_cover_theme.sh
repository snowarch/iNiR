#!/usr/bin/env bash
# Write active cover art path (optional) and regenerate ~/.config/cava/config
set -euo pipefail

COVER_PATH="${1:-}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
STATE_FILE="$STATE_DIR/user/generated/cava-active-cover.path"

if [[ -n "$COVER_PATH" ]]; then
  mkdir -p "$(dirname "$STATE_FILE")"
  printf '%s\n' "$COVER_PATH" >"$STATE_FILE"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/../colors/modules/90-cava.sh"
