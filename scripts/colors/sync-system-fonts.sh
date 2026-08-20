#!/usr/bin/env bash
set -euo pipefail

# Serialize all desktop font writers with the color/theme pipeline. Both paths
# update GTK settings files and kdeglobals, so interleaving them can lose the
# newest font or palette values.

if [[ $# -ne 3 || -z "$1" || -z "$2" || ! "$3" =~ ^[1-9][0-9]*$ ]]; then
    echo "usage: sync-system-fonts.sh MAIN_FONT MONO_FONT SIZE" >&2
    exit 2
fi

main_font="$1"
mono_font="$2"
font_size="$3"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
theme_lock="$state_home/quickshell/user/generated/app-theme.lock"

mkdir -p "$(dirname "$theme_lock")"
exec 9>"$theme_lock"
if ! flock -w 15 9; then
    echo "[sync-system-fonts] timed out waiting for the app-theme lock" >&2
    exit 1
fi

status=0
if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface font-name "$main_font $font_size" || status=1
    gsettings set org.gnome.desktop.interface monospace-font-name "$mono_font $font_size" || status=1
fi

python3 - "$config_home" "$main_font" "$font_size" <<'PY' || status=1
import os
import re
import sys
import tempfile

config_home, font_name, font_size = sys.argv[1:]


def replace_line(path: str, pattern: str, replacement: str, prefix: str) -> None:
    if not os.path.isfile(path):
        return
    with open(path, "r", encoding="utf-8") as handle:
        content = handle.read()
    if re.search(pattern, content, flags=re.MULTILINE):
        content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
    else:
        content = content.rstrip() + f"\n{replacement}\n"

    mode = os.stat(path).st_mode
    fd, temp_path = tempfile.mkstemp(prefix=prefix, dir=os.path.dirname(path))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(content)
        os.chmod(temp_path, mode)
        os.replace(temp_path, path)
    finally:
        if os.path.exists(temp_path):
            os.unlink(temp_path)


gtk_font = f"{font_name} {font_size}"
for gtk_version in ("gtk-3.0", "gtk-4.0"):
    replace_line(
        os.path.join(config_home, gtk_version, "settings.ini"),
        r"^gtk-font-name=.*$",
        f"gtk-font-name={gtk_font}",
        "settings.ini.",
    )

replace_line(
    os.path.join(config_home, "xsettingsd", "xsettingsd.conf"),
    r"^Gtk/FontName .*$",
    f'Gtk/FontName "{font_name},  {font_size}"',
    "xsettingsd.conf.",
)
PY

if command -v kwriteconfig6 >/dev/null 2>&1; then
    main_kde="${main_font},${font_size},-1,5,50,0,0,0,0,0,0,0,0,0,0,1"
    mono_kde="${mono_font},${font_size},-1,5,50,0,0,0,0,0,0,0,0,0,0,1"
    for key in font menuFont toolBarFont; do
        kwriteconfig6 --file kdeglobals --group General --key "$key" "$main_kde" || status=1
    done
    kwriteconfig6 --file kdeglobals --group General --key fixed "$mono_kde" || status=1
fi

exit "$status"
