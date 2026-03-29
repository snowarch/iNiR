#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/module-runtime.sh"
COLOR_MODULE_ID="spicetify"

main() {
  local enable_spicetify
  enable_spicetify=$(config_bool '.appearance.wallpaperTheming.enableSpicetify' false)
  [[ "$enable_spicetify" == 'true' ]] || exit 0
  command -v spicetify &>/dev/null || exit 0
  "$SCRIPT_DIR/apply-spicetify-theme.sh"
}

main "$@"
