# Migration: Remove duplicated hardware keybind blocks
# Cleans up accidental duplicate brightness/media keybinds if both old absolute-launcher
# bindings and later shorthand duplicates coexist in the same config.

MIGRATION_ID="017-dedupe-hardware-keybinds"
MIGRATION_TITLE="Deduplicate hardware keybinds"
MIGRATION_DESCRIPTION="Removes duplicate generated brightness/media shorthand blocks without touching custom hardware keybinds."
MIGRATION_TARGET_FILE="~/.config/niri/config.kdl"
MIGRATION_REQUIRED=true

migration_check() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
  [[ -f "$config" ]] || return 1

  local brightness_count media_count
  brightness_count="$(grep -Fc 'XF86MonBrightnessUp { spawn "inir" "brightness" "increment"; }' "$config" || true)"
  media_count="$(grep -Fc 'XF86AudioPlay { spawn "inir" "mpris" "playPause"; }' "$config" || true)"
  [[ "${brightness_count:-0}" -gt 1 || "${media_count:-0}" -gt 1 ]]
}

migration_preview() {
  echo -e "${STY_RED}- duplicate generated brightness/media shorthand blocks${STY_RST}"
  echo -e "${STY_GREEN}+ keep custom hardware keybinds and only drop repeated generated blocks${STY_RST}"
}

migration_apply() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"

  if ! migration_check; then
    return 0
  fi

  python3 << 'MIGRATE'
import os

config_path = os.path.expanduser(os.environ.get("XDG_CONFIG_HOME", "~/.config")) + "/niri/config.kdl"

BRIGHTNESS_BLOCK = [
    "// Brightness (hardware keys)",
    'XF86MonBrightnessUp { spawn "inir" "brightness" "increment"; }',
    'XF86MonBrightnessDown { spawn "inir" "brightness" "decrement"; }',
]

MEDIA_BLOCK = [
    "// Media playback (hardware keys)",
    'XF86AudioPlay { spawn "inir" "mpris" "playPause"; }',
    'XF86AudioPause { spawn "inir" "mpris" "playPause"; }',
    'XF86AudioNext { spawn "inir" "mpris" "next"; }',
    'XF86AudioPrev { spawn "inir" "mpris" "previous"; }',
]


def normalized_slice(lines, start, length):
    return [lines[start + idx].strip() for idx in range(length)]

with open(config_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

output = []
seen_brightness = False
seen_media = False
i = 0

while i < len(lines):
    if i + len(BRIGHTNESS_BLOCK) <= len(lines) and normalized_slice(lines, i, len(BRIGHTNESS_BLOCK)) == BRIGHTNESS_BLOCK:
        if seen_brightness:
            i += len(BRIGHTNESS_BLOCK)
            continue
        seen_brightness = True
        output.extend(lines[i:i + len(BRIGHTNESS_BLOCK)])
        i += len(BRIGHTNESS_BLOCK)
        continue

    if i + len(MEDIA_BLOCK) <= len(lines) and normalized_slice(lines, i, len(MEDIA_BLOCK)) == MEDIA_BLOCK:
        if seen_media:
            i += len(MEDIA_BLOCK)
            continue
        seen_media = True
        output.extend(lines[i:i + len(MEDIA_BLOCK)])
        i += len(MEDIA_BLOCK)
        continue

    output.append(lines[i])
    i += 1

with open(config_path, "w", encoding="utf-8") as f:
    f.writelines(output)
MIGRATE
}
