#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/module-runtime.sh"
COLOR_MODULE_ID="sddm"

main() {
  local sync_script="$SCRIPT_DIR/../sddm/sync-pixel-sddm.py"
  [[ -d '/usr/share/sddm/themes/ii-pixel' ]] || exit 0
  [[ -f "$sync_script" ]] || exit 0
  python3 "$sync_script"
}

main "$@"
