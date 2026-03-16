# Migration: Remove duplicated hardware keybind blocks
# Cleans up accidental duplicate brightness/media keybinds if both old absolute-launcher
# bindings and later shorthand duplicates coexist in the same config.

MIGRATION_ID="017-dedupe-hardware-keybinds"
MIGRATION_TITLE="Deduplicate hardware keybinds"
MIGRATION_DESCRIPTION="Removes duplicate brightness/media keybind blocks if the config contains repeated hardware bindings."
MIGRATION_TARGET_FILE="~/.config/niri/config.kdl"
MIGRATION_REQUIRED=true

migration_check() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
  [[ -f "$config" ]] || return 1

  local brightness_count media_count
  brightness_count="$(grep -c 'XF86MonBrightnessUp' "$config" || true)"
  media_count="$(grep -c 'XF86AudioPlay' "$config" || true)"
  [[ "${brightness_count:-0}" -gt 1 || "${media_count:-0}" -gt 1 ]]
}

migration_preview() {
  echo -e "${STY_RED}- duplicate XF86MonBrightness*/XF86Audio* keybind blocks${STY_RST}"
  echo -e "${STY_GREEN}+ keep only the first hardware-key binding for each duplicated key${STY_RST}"
}

migration_apply() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"

  if ! migration_check; then
    return 0
  fi

  python3 << 'MIGRATE'
import os

config_path = os.path.expanduser(os.environ.get("XDG_CONFIG_HOME", "~/.config")) + "/niri/config.kdl"

seen = set()
output = []

duplicate_keys = (
    "XF86MonBrightnessUp",
    "XF86MonBrightnessDown",
    "XF86AudioPlay",
    "XF86AudioPause",
    "XF86AudioNext",
    "XF86AudioPrev",
)

with open(config_path, "r", encoding="utf-8") as f:
    for line in f:
        stripped = line.strip()

        key = None
        for candidate in duplicate_keys:
            if stripped.startswith(candidate):
                key = candidate
                break

        if key is not None:
            if key in seen:
                continue
            seen.add(key)

        output.append(line)

with open(config_path, "w", encoding="utf-8") as f:
    f.writelines(output)
MIGRATE
}
