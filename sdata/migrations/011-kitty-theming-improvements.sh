MIGRATION_ID="011-kitty-theming-improvements"
MIGRATION_TITLE="Kitty Terminal Theming Improvements"
MIGRATION_DESCRIPTION="Fixes kitty.conf for proper wallpaper theming:
  - Moves 'include current-theme.conf' to top of file for color priority
  - Adds transparency (background_opacity) and blur settings
  - Enables remote control socket for live color reload"
MIGRATION_TARGET_FILE="~/.config/kitty/kitty.conf"
MIGRATION_REQUIRED=false

migration_check() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/kitty/kitty.conf"
  
  # Only applies if kitty.conf exists
  if [[ ! -f "$config" ]]; then
    return 1
  fi
  
  # Check if migration is needed:
  # 1. include current-theme.conf exists but NOT at top of file
  # 2. No background_opacity setting
  # 3. No listen_on socket setting
  
  local needs_fix=false
  
  # Check if include exists but not at top
  if grep -q "include.*current-theme.conf" "$config"; then
    local first_non_comment
    first_non_comment=$(grep -n "^[^#]" "$config" | head -1 | cut -d: -f2)
    if [[ ! "$first_non_comment" =~ "include current-theme.conf" ]]; then
      needs_fix=true
    fi
  fi
  
  # Check for missing transparency
  if ! grep -q "background_opacity" "$config"; then
    needs_fix=true
  fi
  
  # Check for missing socket
  if ! grep -q "listen_on" "$config"; then
    needs_fix=true
  fi
  
  [[ "$needs_fix" == "true" ]]
}

migration_preview() {
  echo -e "${STY_CYAN}Changes to be made:${STY_RST}"
  echo ""
  echo -e "${STY_GREEN}+ include current-theme.conf  (moved to TOP of file)${STY_RST}"
  echo ""
  echo -e "${STY_GREEN}+ # iNiR live theming support${STY_RST}"
  echo -e "${STY_GREEN}+ listen_on unix:/tmp/kitty-socket${STY_RST}"
  echo -e "${STY_GREEN}+ allow_remote_control socket-only${STY_RST}"
  echo ""
  echo -e "${STY_GREEN}+ # Transparency and blur (Wayland)${STY_RST}"
  echo -e "${STY_GREEN}+ background_opacity 0.85${STY_RST}"
  echo -e "${STY_GREEN}+ background_blur 32${STY_RST}"
}

migration_diff() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/kitty/kitty.conf"
  
  echo "Current state:"
  echo "  Include line position: $(grep -n "include.*current-theme" "$config" 2>/dev/null | head -1 || echo "not found")"
  echo "  background_opacity: $(grep "background_opacity" "$config" 2>/dev/null || echo "not set")"
  echo "  listen_on: $(grep "listen_on" "$config" 2>/dev/null || echo "not set")"
  echo ""
  echo "After migration:"
  echo "  - Include will be at line 1 (highest priority)"
  echo "  - Transparency enabled for blur effect"
  echo "  - Socket enabled for live color reload on wallpaper change"
}

migration_apply() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/kitty/kitty.conf"
  
  if ! migration_check; then
    return 0
  fi
  
  # Create backup
  cp "$config" "${config}.bak.$(date +%Y%m%d%H%M%S)"
  
  python3 << 'MIGRATE'
import os
import re

config_path = os.path.expanduser("~/.config/kitty/kitty.conf")

with open(config_path, 'r') as f:
    content = f.read()
    lines = content.split('\n')

new_lines = []
include_found = False
has_opacity = 'background_opacity' in content
has_blur = 'background_blur' in content
has_socket = 'listen_on' in content
has_remote = 'allow_remote_control' in content

# Remove omarchy theme include if present (conflicts with iNiR theming)
lines = [l for l in lines if 'omarchy' not in l.lower() or 'include' not in l.lower()]

# Remove existing include current-theme.conf (we'll add at top)
lines = [l for l in lines if not re.match(r'^\s*include\s+current-theme\.conf', l)]

# Build new content with include at top
new_lines.append('# iNiR wallpaper theming - colors from quickshell')
new_lines.append('include current-theme.conf')
new_lines.append('')

# Add socket settings if missing
if not has_socket or not has_remote:
    new_lines.append('# iNiR live theming support')
    if not has_socket:
        new_lines.append('listen_on unix:/tmp/kitty-socket')
    if not has_remote:
        new_lines.append('allow_remote_control socket-only')
    new_lines.append('')

# Add rest of original content
new_lines.extend(lines)

# Add transparency at end if missing
additions = []
if not has_opacity or not has_blur:
    additions.append('')
    additions.append('# Transparency and blur (Wayland)')
    if not has_opacity:
        additions.append('background_opacity 0.85')
    if not has_blur:
        additions.append('background_blur 32')

new_lines.extend(additions)

# Write back
with open(config_path, 'w') as f:
    f.write('\n'.join(new_lines))

print("✓ Kitty config updated for iNiR theming")
MIGRATE
}
