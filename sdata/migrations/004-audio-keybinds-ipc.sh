# Migration: Update audio keybinds to use ii IPC
# Shows OSD when changing volume via hardware keys

MIGRATION_ID="004-audio-keybinds-ipc"
MIGRATION_TITLE="Audio Keybinds with OSD"
MIGRATION_DESCRIPTION="Updates audio keybinds to use ii-niri IPC instead of wpctl.
  This shows an on-screen display when changing volume with hardware keys."
MIGRATION_TARGET_FILE="~/.config/niri/config.kdl"
MIGRATION_REQUIRED=false

migration_check() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
  [[ -f "$config" ]] && grep -q 'XF86AudioRaiseVolume.*wpctl' "$config"
}

migration_preview() {
  echo -e "${STY_RED}- XF86AudioRaiseVolume { spawn \"wpctl\" \"set-volume\" ... }${STY_RST}"
  echo -e "${STY_GREEN}+ XF86AudioRaiseVolume { spawn \"qs\" \"-c\" \"ii\" \"ipc\" \"call\" \"audio\" \"volumeUp\" }${STY_RST}"
  echo ""
  echo "Same for: XF86AudioLowerVolume, XF86AudioMute"
}

migration_diff() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
  echo "Current audio keybinds:"
  grep -E "XF86Audio(Raise|Lower|Mute)" "$config" 2>/dev/null | head -5
  echo ""
  echo "After migration, will use ii IPC for OSD support"
}

migration_apply() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
  
  if ! migration_check; then
    return 0
  fi
  
  python3 << 'MIGRATE'
import re
import os

config_path = os.path.expanduser("~/.config/niri/config.kdl")
with open(config_path, 'r') as f:
    content = f.read()

# Replace wpctl volume keybinds with ii IPC (only if using wpctl)
content = re.sub(
    r'XF86AudioRaiseVolume[^}]*spawn[^}]*wpctl[^}]*\}',
    'XF86AudioRaiseVolume allow-when-locked=true { spawn "qs" "-c" "ii" "ipc" "call" "audio" "volumeUp"; }',
    content
)
content = re.sub(
    r'XF86AudioLowerVolume[^}]*spawn[^}]*wpctl[^}]*\}',
    'XF86AudioLowerVolume allow-when-locked=true { spawn "qs" "-c" "ii" "ipc" "call" "audio" "volumeDown"; }',
    content
)
content = re.sub(
    r'XF86AudioMute[^}]*spawn[^}]*wpctl[^}]*\}',
    'XF86AudioMute allow-when-locked=true { spawn "qs" "-c" "ii" "ipc" "call" "audio" "mute"; }',
    content
)

with open(config_path, 'w') as f:
    f.write(content)
MIGRATE
}
