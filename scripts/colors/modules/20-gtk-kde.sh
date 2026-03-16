#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/module-runtime.sh"
COLOR_MODULE_ID="gtk-kde"

main() {
  local enable_apps_shell enable_qt_apps
  enable_apps_shell=$(config_bool '.appearance.wallpaperTheming.enableAppsAndShell' true)
  enable_qt_apps=$(config_bool '.appearance.wallpaperTheming.enableQtApps' true)
  if [[ "$enable_apps_shell" == 'false' && "$enable_qt_apps" == 'false' ]]; then
    exit 0
  fi
  "$SCRIPT_DIR/apply-gtk-theme.sh"
}

main "$@"
