#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/module-runtime.sh"
COLOR_MODULE_ID="sddm"

main() {
  [[ -d '/usr/share/sddm/themes/ii-pixel' ]] || exit 0
  "$SCRIPT_DIR/../lib/accel-run" sddm-sync
}

main "$@"
