MIGRATION_ID="018-modularize-niri-config"
MIGRATION_TITLE="Modularize Niri config"
MIGRATION_DESCRIPTION="Splits a legacy monolithic Niri config.kdl into config.d fragments while preserving the current user configuration."
MIGRATION_TARGET_FILE="~/.config/niri/config.kdl"
MIGRATION_REQUIRED=true

migration_check() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
  [[ -f "$config" ]] || return 1
  grep -q 'include "config\.d/' "$config" && return 1
  grep -qE '^[[:space:]]*include[[:space:]]+"[^"]+"' "$config" && return 1
  return 0
}

migration_preview() {
  echo -e "${STY_RED}- ~/.config/niri/config.kdl as one monolithic file${STY_RST}"
  echo -e "${STY_GREEN}+ ~/.config/niri/config.kdl with config.d/10..90 fragments${STY_RST}"
}

migration_apply() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"

  if ! migration_check; then
    return 0
  fi

  export INIR_MIGRATION_NIRI_CONFIG="$config"
  export INIR_MIGRATION_LAUNCHER_PATH="${XDG_BIN_HOME:-$HOME/.local/bin}/inir"
  python3 << 'MIGRATE'
import os
import shutil
import time
from pathlib import Path

config_path = Path(os.environ["INIR_MIGRATION_NIRI_CONFIG"]).expanduser()
launcher_path = os.environ["INIR_MIGRATION_LAUNCHER_PATH"]
niri_dir = config_path.parent
modular_dir = niri_dir / "config.d"

content = config_path.read_text(encoding="utf-8")
if 'include "config.d/' in content:
    raise SystemExit(0)

lines = content.splitlines(keepends=True)

bucket_files = {
    "10": "10-input-and-cursor.kdl",
    "20": "20-layout-and-overview.kdl",
    "30": "30-window-rules.kdl",
    "40": "40-environment.kdl",
    "50": "50-startup.kdl",
    "60": "60-animations.kdl",
    "70": "70-binds.kdl",
    "80": "80-layer-rules.kdl",
    "90": "90-user-extra.kdl",
}

buckets = {key: [] for key in ["root", *bucket_files.keys()]}

root_tokens = {"prefer-no-csd", "hotkey-overlay", "screenshot-path"}
map_tokens = {
    "input": "10",
    "gestures": "10",
    "cursor": "10",
    "layout": "20",
    "overview": "20",
    "window-rule": "30",
    "environment": "40",
    "spawn-at-startup": "50",
    "animations": "60",
    "binds": "70",
    "layer-rule": "80",
}


def classify(stripped: str) -> str:
    token = stripped.split()[0] if stripped.split() else ""
    if token in root_tokens:
        return "root"
    return map_tokens.get(token, "90")


pending = []
i = 0
while i < len(lines):
    line = lines[i]
    stripped = line.strip()

    if not stripped or stripped.startswith("//"):
        pending.append(line)
        i += 1
        continue

    segment = pending + [line]
    pending = []
    depth = line.count("{") - line.count("}")
    i += 1

    while depth > 0 and i < len(lines):
        segment.append(lines[i])
        depth += lines[i].count("{") - lines[i].count("}")
        i += 1

    buckets[classify(stripped)].extend(segment)

if pending:
    buckets["root"].extend(pending)


def normalize_text(lines_or_text):
    if isinstance(lines_or_text, list):
        text = "".join(lines_or_text)
    else:
        text = lines_or_text
    text = text.strip("\n")
    return f"{text}\n" if text else ""


if modular_dir.exists():
    backup_dir = niri_dir / f"config.d.pre-modular-{time.strftime('%Y%m%d-%H%M%S')}"
    shutil.move(str(modular_dir), str(backup_dir))

modular_dir.mkdir(parents=True, exist_ok=True)

startup_text = normalize_text(buckets["50"]).replace(
    'spawn-at-startup "inir" "start"',
    f'spawn-at-startup "{launcher_path}" "start"',
)
binds_text = normalize_text(buckets["70"]).replace(
    'spawn "inir" "',
    f'spawn "{launcher_path}" "',
).replace(
    'spawn "bash" "-lc" "exec \\"$(inir path)/scripts/launch-terminal.sh\\""',
    f'spawn "{launcher_path}" "terminal"',
).replace(
    'spawn "bash" "-lc" "exec \\"$(inir path)/scripts/close-window.sh\\""',
    f'spawn "{launcher_path}" "close-window"',
)

USER_EXTRA_TEMPLATE = """\
// ─────────────────────────────────────────────────────────────────────────────
// 90 — Your personal overrides
// ─────────────────────────────────────────────────────────────────────────────
//
// This file is YOURS. iNiR updates will never overwrite it.
// Put any custom configuration here: extra binds, per-app window rules,
// output configuration, named workspaces, etc.
//
// Since Niri evaluates config top-to-bottom, settings here take effect
// after all other config.d files. For window-rule properties, all matching
// rules accumulate. For scalar values (like gaps), the last one wins.
//
// Examples:
//
//   // Named workspaces (sticky, always present)
//   workspace "browser"
//   workspace "code"
//   workspace "music"
//
//   // Per-app workspace assignment
//   window-rule {
//       match app-id="firefox"
//       open-on-workspace "browser"
//   }
//
//   // Extra keybind
//   binds {
//       Mod+P { spawn "rofi" "-show" "drun"; }
//   }
//
//   // Output config for your specific monitor
//   output "DP-1" {
//       mode "3440x1440@100.000"
//       scale 1
//       position x=0 y=0
//   }
// ─────────────────────────────────────────────────────────────────────────────
"""

write_map = {
    "10": normalize_text(buckets["10"]),
    "20": normalize_text(buckets["20"]),
    "30": normalize_text(buckets["30"]),
    "40": normalize_text(buckets["40"]),
    "50": startup_text,
    "60": normalize_text(buckets["60"]),
    "70": binds_text,
    "80": normalize_text(buckets["80"]),
    "90": normalize_text(buckets["90"]) or USER_EXTRA_TEMPLATE,
}

for key, filename in bucket_files.items():
    (modular_dir / filename).write_text(write_map[key], encoding="utf-8")

root_text = normalize_text(buckets["root"]).rstrip("\n")
include_lines = [
    'include "config.d/10-input-and-cursor.kdl"',
    'include "config.d/20-layout-and-overview.kdl"',
    'include "config.d/30-window-rules.kdl"',
    'include "config.d/40-environment.kdl"',
    'include "config.d/50-startup.kdl"',
    'include "config.d/60-animations.kdl"',
    'include "config.d/70-binds.kdl"',
    'include "config.d/80-layer-rules.kdl"',
    'include "config.d/90-user-extra.kdl"',
]
root_parts = []
if root_text:
    root_parts.append(root_text)
root_parts.extend(include_lines)
config_path.write_text("\n\n".join(root_parts).rstrip() + "\n", encoding="utf-8")
MIGRATE
}
