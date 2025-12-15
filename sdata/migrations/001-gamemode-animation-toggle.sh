# Migration: Add //off to Niri animations block for GameMode support
# This allows ii-niri to toggle animations on/off for gaming

MIGRATION_ID="001-gamemode-animation-toggle"
MIGRATION_TITLE="GameMode Animation Toggle"
MIGRATION_DESCRIPTION="Adds //off comment to Niri animations block, allowing ii-niri
  to toggle animations on/off when GameMode is activated.
  This improves gaming performance by disabling compositor animations."
MIGRATION_TARGET_FILE="~/.config/niri/config.kdl"
MIGRATION_REQUIRED=false

migration_check() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
  [[ -f "$config" ]] && ! grep -qE '^\s*(//)?off' "$config"
}

migration_preview() {
  echo -e "${STY_GREEN}+ //off${STY_RST}  (inside animations { } block)"
}

migration_diff() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
  echo "Will add '//off' after 'animations {' line"
  echo ""
  echo "Before:"
  grep -A2 "^animations" "$config" 2>/dev/null | head -5
  echo ""
  echo "After:"
  echo "animations {"
  echo "    //off"
  echo "    ..."
}

migration_apply() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
  
  if ! migration_check; then
    return 0  # Already has //off or file doesn't exist
  fi
  
  python3 << MIGRATE
import re
import os

config_path = os.path.expanduser("~/.config/niri/config.kdl")
with open(config_path, 'r') as f:
    content = f.read()

# Find animations block and add //off if not present
animations_match = re.search(r'^animations\s*\{([^}]*)\}', content, re.MULTILINE | re.DOTALL)
if animations_match:
    block_content = animations_match.group(1)
    if '//off' not in block_content and 'off' not in block_content:
        new_block = 'animations {\n    //off' + block_content + '}'
        content = content[:animations_match.start()] + new_block + content[animations_match.end():]
        with open(config_path, 'w') as f:
            f.write(content)
        exit(0)
exit(0)
MIGRATE
}
