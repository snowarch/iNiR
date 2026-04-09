# Migration: Silence Quickshell DBus properties log spam
# Some StatusNotifierItem implementations intermittently fail Get(IconName) and spam logs.
# This migration adds QT_LOGGING_RULES to disable the noisy category.

MIGRATION_ID="009-quickshell-dbus-properties-logspam"
MIGRATION_TITLE="Silence tray DBus property spam"
MIGRATION_DESCRIPTION="Adds QT_LOGGING_RULES to Niri environment to silence quickshell.dbus.properties warnings (StatusNotifierItem IconName Get spam)."
MIGRATION_TARGET_FILE="~/.config/niri/config.kdl"
MIGRATION_REQUIRED=false

migration_check() {
  local niri_dir="${XDG_CONFIG_HOME:-$HOME/.config}/niri"
  local config="${niri_dir}/config.kdl"
  local env_file="${niri_dir}/config.d/40-environment.kdl"

  [[ -f "$config" ]] || return 1

  # Check both main config and modular environment file (after migration 018)
  grep -q 'QT_LOGGING_RULES' "$config" 2>/dev/null && return 1
  [[ -f "$env_file" ]] && grep -q 'QT_LOGGING_RULES' "$env_file" 2>/dev/null && return 1

  # Rule not found anywhere — migration needed
  return 0
}

migration_preview() {
  echo -e "${STY_GREEN}+ QT_LOGGING_RULES \"quickshell.dbus.properties=false\"${STY_RST}"
}

migration_diff() {
  local niri_dir="${XDG_CONFIG_HOME:-$HOME/.config}/niri"
  local config="${niri_dir}/config.kdl"
  local env_file="${niri_dir}/config.d/40-environment.kdl"
  echo "Current:"
  grep "QT_LOGGING_RULES" "$config" "$env_file" 2>/dev/null || echo "  (not set)"
  echo ""
  echo "After migration:"
  echo "  QT_LOGGING_RULES \"quickshell.dbus.properties=false\""
}

migration_apply() {
  if ! migration_check; then
    return 0
  fi

  /usr/bin/python3 - <<'PY'
import os
import sys
from pathlib import Path

xdg = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
niri_dir = Path(xdg) / "niri"
config_kdl = niri_dir / "config.kdl"
env_file = niri_dir / "config.d" / "40-environment.kdl"

# Prefer modular env file if it exists (post-migration-018)
target = env_file if env_file.is_file() else config_kdl

if not target.is_file():
    sys.stderr.write(f"Target not found: {target}\n")
    sys.exit(1)

lines = target.read_text(encoding="utf-8").splitlines(True)

if any("QT_LOGGING_RULES" in l for l in lines):
    sys.exit(0)

out = []
in_env = False
inserted = False

for line in lines:
    stripped = line.strip()

    if stripped.startswith("environment") and stripped.endswith("{"):
        in_env = True
        out.append(line)
        continue

    if in_env and stripped == "}" and not inserted:
        out.append('    QT_LOGGING_RULES "quickshell.dbus.properties=false"\n')
        inserted = True
        out.append(line)
        in_env = False
        continue

    out.append(line)

if not inserted:
    sys.stderr.write(f"Could not find environment block in {target}\n")
    sys.exit(1)

target.write_text("".join(out), encoding="utf-8")
PY
}
