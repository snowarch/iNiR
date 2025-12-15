# Migration: Add brightness keybinds
# Hardware brightness keys with OSD

MIGRATION_ID="007-brightness-keybinds"
MIGRATION_TITLE="Brightness Hardware Keys"
MIGRATION_DESCRIPTION="Adds XF86MonBrightnessUp/Down keybinds that use ii-niri IPC.
  Shows on-screen display when changing brightness."
MIGRATION_TARGET_FILE="~/.config/niri/config.kdl"
MIGRATION_REQUIRED=false

migration_check() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
  [[ -f "$config" ]] && ! grep -q 'XF86MonBrightnessUp' "$config"
}

migration_preview() {
  echo -e "${STY_GREEN}+ XF86MonBrightnessUp { spawn \"qs\" ... \"brightness\" \"increment\"; }${STY_RST}"
  echo -e "${STY_GREEN}+ XF86MonBrightnessDown { spawn \"qs\" ... \"brightness\" \"decrement\"; }${STY_RST}"
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

# Find the last line in binds section that starts with XF86 or Print
insert_idx = None
in_binds = False
for i, line in enumerate(lines):
    stripped = line.strip()
    if stripped.startswith('binds {'):
        in_binds = True
    if in_binds:
        if stripped.startswith(('XF86Audio', 'Print', 'Ctrl+Print', 'Alt+Print')):
            insert_idx = i
        if stripped == '}' and in_binds:
            # End of binds block
            if insert_idx is None:
                insert_idx = i - 1
            break

if insert_idx is not None:
    brightness_block = '''
    // Brightness (hardware keys)
    XF86MonBrightnessUp { spawn "qs" "-c" "ii" "ipc" "call" "brightness" "increment"; }
    XF86MonBrightnessDown { spawn "qs" "-c" "ii" "ipc" "call" "brightness" "decrement"; }
'''
    lines.insert(insert_idx + 1, brightness_block)
    
    with open(config_path, 'w') as f:
        f.writelines(lines)
MIGRATE
}
