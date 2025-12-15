# Migration: Replace native close-window with closeConfirm
# Shows confirmation dialog before closing windows

MIGRATION_ID="006-close-confirm"
MIGRATION_TITLE="Close Window Confirmation"
MIGRATION_DESCRIPTION="Replaces Mod+Q close-window with ii-niri's closeConfirm script.
  This shows a confirmation dialog before closing windows,
  preventing accidental data loss."
MIGRATION_TARGET_FILE="~/.config/niri/config.kdl"
MIGRATION_REQUIRED=false

migration_check() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
  # Check if there's an uncommented Mod+Q with close-window (not the script version)
  [[ -f "$config" ]] && grep -v '^\s*//' "$config" | grep -q 'Mod+Q.*close-window;'
}

migration_preview() {
  echo -e "${STY_RED}- Mod+Q { close-window; }${STY_RST}"
  echo -e "${STY_GREEN}+ Mod+Q { spawn \"bash\" \"-c\" \"\$HOME/.config/quickshell/ii/scripts/close-window.sh\"; }${STY_RST}"
}

migration_apply() {
  local config="${XDG_CONFIG_HOME}/niri/config.kdl"
  
  if ! migration_check; then
    return 0
  fi
  
  python3 << 'MIGRATE'
import re
import os

config_path = os.path.expanduser("~/.config/niri/config.kdl")
with open(config_path, 'r') as f:
    content = f.read()

pattern = r'Mod\+Q[^}]*close-window[^}]*\}'
replacement = 'Mod+Q repeat=false { spawn "bash" "-c" "$HOME/.config/quickshell/ii/scripts/close-window.sh"; }'
content = re.sub(pattern, replacement, content)

with open(config_path, 'w') as f:
    f.write(content)
MIGRATE
}
