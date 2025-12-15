# Migration: Add media playback keybinds
# Hardware media keys with MPRIS integration

MIGRATION_ID="008-media-keybinds"
MIGRATION_TITLE="Media Playback Keys"
MIGRATION_DESCRIPTION="Adds XF86AudioPlay/Pause/Next/Prev keybinds for media control.
  Works with any MPRIS-compatible player (Spotify, Firefox, etc.)."
MIGRATION_TARGET_FILE="~/.config/niri/config.kdl"
MIGRATION_REQUIRED=false

migration_check() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
  [[ -f "$config" ]] && ! grep -q 'XF86AudioPlay' "$config"
}

migration_preview() {
  echo -e "${STY_GREEN}+ XF86AudioPlay { spawn \"qs\" ... \"mpris\" \"playPause\"; }${STY_RST}"
  echo -e "${STY_GREEN}+ XF86AudioPause { spawn \"qs\" ... \"mpris\" \"playPause\"; }${STY_RST}"
  echo -e "${STY_GREEN}+ XF86AudioNext { spawn \"qs\" ... \"mpris\" \"next\"; }${STY_RST}"
  echo -e "${STY_GREEN}+ XF86AudioPrev { spawn \"qs\" ... \"mpris\" \"previous\"; }${STY_RST}"
}

migration_apply() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
  
  if ! migration_check; then
    return 0
  fi
  
  python3 << 'MIGRATE'
import os

config_path = os.path.expanduser("~/.config/niri/config.kdl")
with open(config_path, 'r') as f:
    lines = f.readlines()

# Find the last line in binds section that starts with XF86MonBrightness or XF86Audio
insert_idx = None
in_binds = False
for i, line in enumerate(lines):
    stripped = line.strip()
    if stripped.startswith('binds {'):
        in_binds = True
    if in_binds:
        if stripped.startswith(('XF86MonBrightness', 'XF86Audio')):
            insert_idx = i
        if stripped == '}' and in_binds:
            if insert_idx is None:
                insert_idx = i - 1
            break

if insert_idx is not None:
    media_block = '''
    // Media playback (hardware keys)
    XF86AudioPlay { spawn "qs" "-c" "ii" "ipc" "call" "mpris" "playPause"; }
    XF86AudioPause { spawn "qs" "-c" "ii" "ipc" "call" "mpris" "playPause"; }
    XF86AudioNext { spawn "qs" "-c" "ii" "ipc" "call" "mpris" "next"; }
    XF86AudioPrev { spawn "qs" "-c" "ii" "ipc" "call" "mpris" "previous"; }
'''
    lines.insert(insert_idx + 1, media_block)
    
    with open(config_path, 'w') as f:
        f.writelines(lines)
MIGRATE
}
