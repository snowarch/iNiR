#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/module-runtime.sh"
COLOR_MODULE_ID="chrome"

main() {
  local enable_chrome
  enable_chrome=$(config_bool '.appearance.wallpaperTheming.enableChrome' true)
  [[ "$enable_chrome" == 'true' ]] || exit 0
  "$SCRIPT_DIR/apply-chrome-theme.sh"
}

main "$@"
