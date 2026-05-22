#!/usr/bin/env bash

MIGRATION_ID="024-steam-millennium"
MIGRATION_TITLE="Move Steam theming to Millennium"
MIGRATION_DESCRIPTION="Renames the Steam wallpaper theming toggle and configures Millennium Material-Theme Matugen for users who had Steam theming enabled."
MIGRATION_TARGET_FILE="~/.config/illogical-impulse/config.json"
MIGRATION_REQUIRED=true

_steam_migration_config_file() {
  local xdg_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  if [[ -L "$xdg_config_home/illogical-impulse" && -f "$xdg_config_home/inir/config.json" ]]; then
    printf '%s\n' "$xdg_config_home/inir/config.json"
  elif [[ -d "$xdg_config_home/illogical-impulse" || -f "$xdg_config_home/illogical-impulse/config.json" ]]; then
    printf '%s\n' "$xdg_config_home/illogical-impulse/config.json"
  elif [[ -f "$xdg_config_home/inir/config.json" ]]; then
    printf '%s\n' "$xdg_config_home/inir/config.json"
  else
    printf '%s\n' "$xdg_config_home/inir/config.json"
  fi
}

_steam_migration_needs_config() {
  local config_file
  config_file="$(_steam_migration_config_file)"
  [[ -f "$config_file" ]] || return 1
  python3 - "$config_file" <<'PY'
import json
import sys

old_key = "enable" + "Adw" + "Steam"
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
except Exception:
    sys.exit(0)

node = data.get("appearance", {}).get("wallpaperTheming", {})
if old_key in node or "enableSteam" not in node:
    sys.exit(0)
sys.exit(1)
PY
}

_steam_migration_needs_millennium_config() {
  local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/millennium/config.json"
  [[ -f "$cfg" ]] || return 0
  python3 - "$cfg" <<'PY'
import json
import sys

try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
except Exception:
    sys.exit(0)

general = data.get("general", {})
themes = data.get("themes", {})
conditions = themes.get("conditions", {}).get("Material-Theme", {})
ok = (
    general.get("injectCSS") is True
    and general.get("injectJavascript") is True
    and themes.get("activeTheme") == "Material-Theme"
    and themes.get("allowedStyles") is True
    and themes.get("allowedScripts") is True
    and conditions.get("Color") == "Matugen"
)
sys.exit(1 if ok else 0)
PY
}

_steam_migration_enabled() {
  local config_file
  config_file="$(_steam_migration_config_file)"
  [[ -f "$config_file" ]] || return 1
  python3 - "$config_file" <<'PY'
import json
import sys

old_key = "enable" + "Adw" + "Steam"
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
except Exception:
    sys.exit(1)

node = data.get("appearance", {}).get("wallpaperTheming", {})
enabled = node.get("enableSteam", node.get(old_key, False))
sys.exit(0 if enabled is True else 1)
PY
}

_steam_migration_runtime_available() {
  [[ -d /usr/lib/millennium ]] && return 0
  if command -v pacman >/dev/null 2>&1; then
    pacman -Q millennium-bin >/dev/null 2>&1 && return 0
    pacman -Q millennium >/dev/null 2>&1 && return 0
    pacman -Q millennium-git >/dev/null 2>&1 && return 0
  fi
  return 1
}

_steam_migration_has_steam_dir() {
  local dir
  for dir in "$HOME/.steam/steam" "$HOME/.local/share/Steam" "$HOME/.var/app/com.valvesoftware.Steam/.steam/steam"; do
    [[ -d "$dir" ]] && return 0
  done
  return 1
}

_steam_migration_needs_theme() {
  local dir
  _steam_migration_runtime_available || return 1
  _steam_migration_has_steam_dir || return 1
  for dir in "$HOME/.steam/steam" "$HOME/.local/share/Steam" "$HOME/.var/app/com.valvesoftware.Steam/.steam/steam"; do
    [[ -d "$dir" ]] || continue
    [[ -f "$dir/millennium/themes/Material-Theme/skin.json" ]] && return 1
  done
  return 0
}

migration_check() {
  _steam_migration_needs_config && return 0
  if _steam_migration_enabled; then
    _steam_migration_needs_millennium_config && return 0
    _steam_migration_needs_theme && return 0
  fi
  return 1
}

migration_preview() {
  echo -e "${STY_GREEN}+ appearance.wallpaperTheming.enableSteam${STY_RST}"
  echo -e "${STY_GREEN}+ Millennium Material-Theme Color=Matugen when Steam theming is enabled${STY_RST}"
  echo -e "${STY_GREEN}+ Material-Theme installed under Steam's Millennium themes directory when needed${STY_RST}"
}

migration_apply() {
  local config_file
  local cfg_dir
  local millennium_cfg
  local repo_root
  config_file="$(_steam_migration_config_file)"
  cfg_dir="$(dirname "$config_file")"
  millennium_cfg="${XDG_CONFIG_HOME:-$HOME/.config}/millennium/config.json"
  repo_root="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)}"

  mkdir -p "$cfg_dir" "$(dirname "$millennium_cfg")"

  if [[ -f "$config_file" ]]; then
    python3 - "$config_file" <<'PY'
import json
import os
import sys

path = sys.argv[1]
old_key = "enable" + "Adw" + "Steam"
try:
    with open(path) as f:
        data = json.load(f)
except Exception:
    data = {}

node = data.setdefault("appearance", {}).setdefault("wallpaperTheming", {})
if "enableSteam" not in node:
    node["enableSteam"] = bool(node.get(old_key, False))
node.pop(old_key, None)

tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
os.replace(tmp, path)
PY
  fi

  if ! _steam_migration_enabled; then
    _steam_migration_needs_config && return 1
    return 0
  fi

  python3 - "$millennium_cfg" <<'PY'
import json
import os
import sys

path = sys.argv[1]
try:
    with open(path) as f:
        data = json.load(f)
except Exception:
    data = {}

general = data.setdefault("general", {})
general["injectCSS"] = True
general["injectJavascript"] = True
themes = data.setdefault("themes", {})
themes["activeTheme"] = "Material-Theme"
themes["allowedStyles"] = True
themes["allowedScripts"] = True
conditions = themes.setdefault("conditions", {})
theme_conditions = conditions.setdefault("Material-Theme", {})
theme_conditions["Color"] = "Matugen"
theme_conditions.setdefault("Appearance", "Dark")

tmp = path + ".tmp"
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(tmp, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
os.replace(tmp, path)
PY

  if _steam_migration_runtime_available && _steam_migration_has_steam_dir && [[ -x "$repo_root/scripts/colors/modules/70-steam.sh" ]]; then
    INIR_STEAM_THEME_FORCE=1 bash "$repo_root/scripts/colors/modules/70-steam.sh" >/dev/null 2>&1 || true
  fi

  _steam_migration_needs_config && return 1
  _steam_migration_needs_millennium_config && return 1
  return 0
}
