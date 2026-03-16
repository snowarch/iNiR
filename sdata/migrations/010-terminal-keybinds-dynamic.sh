# Migration: Dynamic terminal keybinds
# Updates Mod+T and Mod+Return to use the iNiR launcher so the Settings UI
# terminal selection controls which terminal opens.

MIGRATION_ID="010-terminal-keybinds-dynamic"
MIGRATION_TITLE="Dynamic terminal keybinds"
MIGRATION_DESCRIPTION="Updates Mod+T and Mod+Return to use the configured terminal from Settings instead of a hardcoded terminal."
MIGRATION_TARGET_FILE="~/.config/niri/config.kdl"
MIGRATION_REQUIRED=true

migration_check() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
  [[ -f "$config" ]] || return 1

  # Already migrated?
  if grep -qE 'Mod\+(T|Return).*spawn.*"inir"\s+"terminal"' "$config"; then
    return 1
  fi

  # Has hardcoded terminal keybinds?
  grep -qE 'Mod\+T.*spawn.*(foot|kitty|alacritty|ghostty|wezterm|konsole)' "$config"
}

migration_preview() {
  echo -e "${STY_RED}- Mod+T { spawn \"<terminal>\"; }${STY_RST}"
  echo -e "${STY_RED}- Mod+Return { spawn \"<terminal>\"; }${STY_RST}"
  echo ""
  echo -e "${STY_GREEN}+ Mod+T { spawn \"inir\" \"terminal\"; }${STY_RST}"
  echo -e "${STY_GREEN}+ Mod+Return { spawn \"inir\" \"terminal\"; }${STY_RST}"
}

migration_diff() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
  echo "Current terminal keybinds:"
  grep -E "Mod\+(T|Return).*spawn" "$config" 2>/dev/null | head -4
  echo ""
  echo "After migration, changing terminal in Settings will control these keybinds."
}

migration_apply() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"

  if ! migration_check; then
    return 0
  fi

  /usr/bin/python3 - <<'PY'
import re
import os

config_path = os.path.expanduser(os.environ.get("XDG_CONFIG_HOME", "~/.config")) + "/niri/config.kdl"

with open(config_path, "r", encoding="utf-8") as f:
    content = f.read()

# Replace Mod+T with any hardcoded terminal
content = re.sub(
    r'(Mod\+T\s*\{)\s*spawn\s+"(?:foot|kitty|alacritty|ghostty|wezterm|konsole)"[^}]*(\})',
    r'\1 spawn "inir" "terminal"; \2',
    content
)

# Replace Mod+Return with any hardcoded terminal
content = re.sub(
    r'(Mod\+Return\s*\{)\s*spawn\s+"(?:foot|kitty|alacritty|ghostty|wezterm|konsole)"[^}]*(\})',
    r'\1 spawn "inir" "terminal"; \2',
    content
)

with open(config_path, "w", encoding="utf-8") as f:
    f.write(content)
PY
}
