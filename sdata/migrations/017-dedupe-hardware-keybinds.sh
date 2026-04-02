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

  # Match both bare "inir" and full-path "/home/user/.local/bin/inir" patterns,
  # since migration 016 rewrites all binds to the full launcher path.
  local brightness_count media_count
  brightness_count="$(grep -cE 'XF86MonBrightnessUp \{ spawn "[^"]*inir" "brightness" "increment"; \}' "$config" || true)"
  media_count="$(grep -cE 'XF86AudioPlay \{ spawn "[^"]*inir" "mpris" "playPause"; \}' "$config" || true)"
  [[ "${brightness_count:-0}" -gt 1 || "${media_count:-0}" -gt 1 ]]
}

migration_preview() {
  echo -e "${STY_RED}- duplicate generated brightness/media shorthand blocks${STY_RST}"
  echo -e "${STY_GREEN}+ keep custom hardware keybinds and only drop repeated generated blocks${STY_RST}"
}

migration_apply() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
  local launcher_path="${XDG_BIN_HOME:-$HOME/.local/bin}/inir"

  if ! migration_check; then
    return 0
  fi

  export INIR_MIGRATION_LAUNCHER_PATH="${launcher_path}"
  python3 << 'MIGRATE'
import os
import re

config_path = os.path.expanduser(os.environ.get("XDG_CONFIG_HOME", "~/.config")) + "/niri/config.kdl"
launcher_path = os.environ.get("INIR_MIGRATION_LAUNCHER_PATH", os.path.expanduser("~/.local/bin/inir"))

# Match blocks with any inir path variant (bare "inir" or full "/path/to/inir")
INIR_RE = re.escape(launcher_path) + r'|inir'

BRIGHTNESS_COMMENT = "// Brightness (hardware keys)"
BRIGHTNESS_KEYS = [
    ('XF86MonBrightnessUp', 'brightness', 'increment'),
    ('XF86MonBrightnessDown', 'brightness', 'decrement'),
]

MEDIA_COMMENT = "// Media playback (hardware keys)"
MEDIA_KEYS = [
    ('XF86AudioPlay', 'mpris', 'playPause'),
    ('XF86AudioPause', 'mpris', 'playPause'),
    ('XF86AudioNext', 'mpris', 'next'),
    ('XF86AudioPrev', 'mpris', 'previous'),
]


def matches_block(lines, start, comment, keys, inir_re):
    """Check if lines[start:] begins with a generated keybind block."""
    if start + 1 + len(keys) > len(lines):
        return False
    if lines[start].strip() != comment:
        return False
    for idx, (key, target, func) in enumerate(keys):
        pattern = rf'^{key}\s+\{{\s+spawn\s+"(?:{inir_re})"\s+"{target}"\s+"{func}";\s+\}}$'
        if not re.match(pattern, lines[start + 1 + idx].strip()):
            return False
    return True


with open(config_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

output = []
seen_brightness = False
seen_media = False
i = 0

while i < len(lines):
    block_len_bright = 1 + len(BRIGHTNESS_KEYS)
    if matches_block(lines, i, BRIGHTNESS_COMMENT, BRIGHTNESS_KEYS, INIR_RE):
        if seen_brightness:
            i += block_len_bright
            continue
        seen_brightness = True
        output.extend(lines[i:i + block_len_bright])
        i += block_len_bright
        continue

    block_len_media = 1 + len(MEDIA_KEYS)
    if matches_block(lines, i, MEDIA_COMMENT, MEDIA_KEYS, INIR_RE):
        if seen_media:
            i += block_len_media
            continue
        seen_media = True
        output.extend(lines[i:i + block_len_media])
        i += block_len_media
        continue

    output.append(lines[i])
    i += 1

with open(config_path, "w", encoding="utf-8") as f:
    f.writelines(output)
MIGRATE
}
