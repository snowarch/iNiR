# Migration: Merge new default config keys into illogical-impulse config.json
# Adds missing keys only (never overwrites user values)

MIGRATION_ID="009-config-json-merge-defaults"
MIGRATION_TITLE="Merge new config.json defaults"
MIGRATION_DESCRIPTION="Adds missing keys from ii-niri defaults/config.json into your existing config.json.
  This never overwrites existing values; it only fills in new options required by newer versions."
MIGRATION_TARGET_FILE="~/.config/illogical-impulse/config.json"
MIGRATION_REQUIRED=true

migration_check() {
  local target="${XDG_CONFIG_HOME}/illogical-impulse/config.json"
  local defaults="${REPO_ROOT}/defaults/config.json"

  [[ -f "$target" ]] || return 1
  [[ -f "$defaults" ]] || return 1

  DEFAULTS_PATH="$defaults" TARGET_PATH="$target" python3 - << 'PY'
import json
import os
import sys

def has_missing_keys(defaults, user):
    if not isinstance(defaults, dict) or not isinstance(user, dict):
        return False
    for k, v in defaults.items():
        if k not in user:
            return True
        if isinstance(v, dict) and isinstance(user.get(k), dict):
            if has_missing_keys(v, user[k]):
                return True
    return False

def main():
    defaults_path = os.environ["DEFAULTS_PATH"]
    target_path = os.environ["TARGET_PATH"]

    with open(defaults_path, "r", encoding="utf-8") as f:
        defaults = json.load(f)

    with open(target_path, "r", encoding="utf-8") as f:
        user = json.load(f)

    sys.exit(0 if has_missing_keys(defaults, user) else 1)

if __name__ == "__main__":
    main()
PY
}

migration_preview() {
  echo -e "${STY_GREEN}+ Add missing keys from defaults/config.json (non-destructive merge)${STY_RST}"
}

migration_apply() {
  local target="${XDG_CONFIG_HOME}/illogical-impulse/config.json"
  local defaults="${REPO_ROOT}/defaults/config.json"

  [[ -f "$target" ]] || return 0
  [[ -f "$defaults" ]] || return 0

  DEFAULTS_PATH="$defaults" TARGET_PATH="$target" python3 - << 'PY'
import json
import os

def merge_add_missing(defaults, user):
    if not isinstance(defaults, dict) or not isinstance(user, dict):
        return user
    for k, v in defaults.items():
        if k not in user:
            user[k] = v
            continue
        if isinstance(v, dict) and isinstance(user.get(k), dict):
            merge_add_missing(v, user[k])
    return user

def main():
    defaults_path = os.environ["DEFAULTS_PATH"]
    target_path = os.environ["TARGET_PATH"]

    with open(defaults_path, "r", encoding="utf-8") as f:
        defaults = json.load(f)

    with open(target_path, "r", encoding="utf-8") as f:
        user = json.load(f)

    merged = merge_add_missing(defaults, user)

    with open(target_path, "w", encoding="utf-8") as f:
        json.dump(merged, f, indent=2)
        f.write("\n")

if __name__ == "__main__":
    main()
PY
}
