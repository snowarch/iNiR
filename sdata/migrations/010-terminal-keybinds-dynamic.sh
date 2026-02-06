MIGRATION_ID="010-terminal-keybinds-dynamic"
MIGRATION_TITLE="Dynamic Terminal Keybinds"
MIGRATION_DESCRIPTION="Updates Mod+T and Mod+Return to use the configured terminal from Settings.
  After this migration, changing terminal in Settings will affect these keybinds."
MIGRATION_TARGET_FILE="~/.config/niri/config.kdl"
MIGRATION_REQUIRED=true

migration_check() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
  if [[ ! -f "$config" ]]; then
    return 1
  fi
  
  if grep -q 'launch-terminal\.sh' "$config"; then
    return 1
  fi
  
  grep -qE 'Mod\+T.*spawn.*(foot|kitty|alacritty|ghostty|wezterm)' "$config"
}

migration_preview() {
  echo -e "${STY_RED}- Mod+T { spawn \"foot\"; }${STY_RST}"
  echo -e "${STY_RED}- Mod+Return { spawn \"foot\"; }${STY_RST}"
  echo ""
  echo -e "${STY_GREEN}+ Mod+T { spawn \"bash\" \"-c\" \"\$HOME/.config/quickshell/ii/scripts/launch-terminal.sh\"; }${STY_RST}"
  echo -e "${STY_GREEN}+ Mod+Return { spawn \"bash\" \"-c\" \"\$HOME/.config/quickshell/ii/scripts/launch-terminal.sh\"; }${STY_RST}"
}

migration_diff() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
  echo "Current terminal keybinds:"
  grep -E "Mod\+(T|Return).*spawn" "$config" 2>/dev/null | head -4
  echo ""
  echo "After migration, terminal selection in Settings will control these keybinds"
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

script_path = '$HOME/.config/quickshell/ii/scripts/launch-terminal.sh'

content = re.sub(
    r'(Mod\+T\s*\{)\s*spawn\s+"(?:foot|kitty|alacritty|ghostty|wezterm)"[^}]*(\})',
    rf'\1 spawn "bash" "-c" "{script_path}"; \2',
    content
)

content = re.sub(
    r'(Mod\+Return\s*\{)\s*spawn\s+"(?:foot|kitty|alacritty|ghostty|wezterm)"[^}]*(\})',
    rf'\1 spawn "bash" "-c" "{script_path}"; \2',
    content
)

with open(config_path, 'w') as f:
    f.write(content)
MIGRATE
}
