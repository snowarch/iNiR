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
# The base's faces and every installed plugin's own (a family that ships its type in assets/fonts) are linked where
# fontconfig looks, so apps, GTK and doctor have what the shell draws with; a removed plugin's link goes with it.
shell_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fonts_root="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
declare -A font_dirs=()
[[ -d "$shell_root/assets/fonts" ]] && font_dirs[inir]="$shell_root/assets/fonts"
for dir in "$shell_root"/modules/*/assets/fonts; do
    [[ -d "$dir" ]] || continue
    id="${dir%/assets/fonts}"
    font_dirs["inir-${id##*/}"]="$dir"
done
# Each folder of faces gets a folder of our own under fonts/ with a link per face: fontconfig marks every folder it scans
# with a .uuid, and a link to the shell's or a plugin's folder put that mark inside their files (a hub checkout then
# refused to build). Ours carry .inir-fonts; a folder without it is the person's and is never touched.
fonts_stamp="$state_home/quickshell/user/generated/bundled-fonts.stamp"
fonts_list="$(for name in "${!font_dirs[@]}"; do (cd "${font_dirs[$name]}" && find . -type f \( -name '*.ttf' -o -name '*.otf' -o -name '*.ttc' \) | sed "s|^\.|$name|"); done | sort | tr '\n' ' ')"
ours() { [[ -L "$1" || -e "$1/.inir-fonts" ]]; }
rebuild=0
[[ "$(cat "$fonts_stamp" 2>/dev/null)" == "$fonts_list" ]] || rebuild=1
for name in "${!font_dirs[@]}"; do
    [[ -e "$fonts_root/$name/.inir-fonts" && ! -L "$fonts_root/$name" ]] || rebuild=1
done
for old in "$fonts_root"/inir "$fonts_root"/inir-*; do
    [[ -n "${font_dirs[${old##*/}]+_}" ]] && continue
    ours "$old" || continue
    rm -rf "$old" && rebuild=1
done
if [[ $rebuild == 1 ]]; then
    mkdir -p "$fonts_root"
    for name in "${!font_dirs[@]}"; do
        dest="$fonts_root/$name" src="${font_dirs[$name]}"
        [[ -e "$dest" || -L "$dest" ]] && ! ours "$dest" && continue
        rm -rf "$dest.new" && mkdir -p "$dest.new" && : >"$dest.new/.inir-fonts" || continue
        while IFS= read -r -d '' face; do
            face="${face#./}"
            mkdir -p "$dest.new/$(dirname "$face")" && ln -s "$src/$face" "$dest.new/$face"
        done < <(cd "$src" && find . -type f \( -name '*.ttf' -o -name '*.otf' -o -name '*.ttc' \) -print0)
        rm -rf "$dest" && mv "$dest.new" "$dest"
        find "$src" -name .uuid -type f -delete 2>/dev/null || true  # the marks the old links let fontconfig leave
    done
    command -v fc-cache >/dev/null 2>&1 && fc-cache -f "$fonts_root" >/dev/null 2>&1 || true
    printf '%s' "$fonts_list" > "$fonts_stamp" || true
fi

if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface font-name "$main_font $font_size" || status=1
    gsettings set org.gnome.desktop.interface monospace-font-name "$mono_font $font_size" || status=1
fi

gtk_font_before="$(grep -s '^gtk-font-name=' "$config_home/gtk-3.0/settings.ini" || true)"
# Every line that sets the key gets the new font; a file without one gets it at its end.
set_font_line() {
    local file="$1" tmp
    [[ -f "$file" ]] || return 0
    tmp="$(mktemp "$(dirname "$file")/.$(basename "$file").XXXXXX")" || return 1
    if PREFIX="$2" LINE="$3" awk '
        index($0, ENVIRON["PREFIX"]) == 1 { $0 = ENVIRON["LINE"]; found = 1 }
        { lines[NR] = $0 }
        END {
            n = NR
            if (!found) {
                while (n > 0 && lines[n] ~ /^[ \t\r]*$/) n--
                if (n) sub(/[ \t\r]+$/, "", lines[n])
            }
            for (i = 1; i <= n; i++) print lines[i]
            if (!found) print ENVIRON["LINE"]
        }' "$file" > "$tmp" && chmod --reference="$file" "$tmp" && mv -f "$tmp" "$file"; then
        return 0
    fi
    rm -f "$tmp"
    return 1
}

set_font_line "$config_home/gtk-3.0/settings.ini" "gtk-font-name=" "gtk-font-name=$main_font $font_size" || status=1
set_font_line "$config_home/gtk-4.0/settings.ini" "gtk-font-name=" "gtk-font-name=$main_font $font_size" || status=1
set_font_line "$config_home/xsettingsd/xsettingsd.conf" "Gtk/FontName " "Gtk/FontName \"$main_font,  $font_size\"" || status=1

if command -v kwriteconfig6 >/dev/null 2>&1; then
    main_kde="${main_font},${font_size},-1,5,50,0,0,0,0,0"
    mono_kde="${mono_font},${font_size},-1,5,50,0,0,0,0,0"
    for key in font menuFont toolBarFont; do
        kwriteconfig6 --file kdeglobals --group General --key "$key" "$main_kde" || status=1
    done
    kwriteconfig6 --file kdeglobals --group General --key fixed "$mono_kde" || status=1
fi

# Steam, Pear and Spotify carry the face in their generated themes: a new face reaches them only by running them again.
if [[ "$(grep -s '^gtk-font-name=' "$config_home/gtk-3.0/settings.ini")" != "$gtk_font_before" ]]; then
    colors_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    for module in 70-steam.sh 80-pear-desktop.sh 50-spicetify.sh; do
        bash "$colors_dir/modules/$module" >/dev/null 2>&1 || true
    done
fi

exit "$status"
