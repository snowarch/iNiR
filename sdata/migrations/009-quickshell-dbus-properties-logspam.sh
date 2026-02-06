# Migration: Silence Quickshell DBus properties log spam
# Some StatusNotifierItem implementations intermittently fail Get(IconName) and spam logs.
# This migration adds QT_LOGGING_RULES to disable the noisy category.

MIGRATION_ID="009-quickshell-dbus-properties-logspam"
MIGRATION_TITLE="Silence tray DBus property spam"
MIGRATION_DESCRIPTION="Adds QT_LOGGING_RULES to Niri environment to silence quickshell.dbus.properties warnings (StatusNotifierItem IconName Get spam)."
MIGRATION_TARGET_FILE="~/.config/niri/config.kdl"
MIGRATION_REQUIRED=false

migration_check() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
  [[ -f "$config" ]] || return 1

  # Apply only if QT_LOGGING_RULES is missing
  ! grep -q 'QT_LOGGING_RULES' "$config"
}

migration_preview() {
  echo -e "${STY_GREEN}+ QT_LOGGING_RULES \"quickshell.dbus.properties=false\"${STY_RST}"
}

migration_diff() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
  echo "Current:"
  grep "QT_LOGGING_RULES" "$config" 2>/dev/null || echo "  (not set)"
  echo ""
  echo "After migration:"
  echo "  QT_LOGGING_RULES \"quickshell.dbus.properties=false\""
}

migration_apply() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"

  if ! migration_check; then
    return 0
  fi

  /usr/bin/python3 - <<'PY'
import os
import sys

path = os.path.expanduser(os.environ.get("XDG_CONFIG_HOME", "~/.config")) + "/niri/config.kdl"

with open(path, "r", encoding="utf-8") as f:
    lines = f.read().splitlines(True)

if any("QT_LOGGING_RULES" in l for l in lines):
    sys.exit(0)

out = []
in_env = False
inserted = False

for i, line in enumerate(lines):
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
    sys.stderr.write("Could not find environment block in niri config.kdl\n")
    sys.exit(1)

with open(path, "w", encoding="utf-8") as f:
    f.write("".join(out))
PY
}
