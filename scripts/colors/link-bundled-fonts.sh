#!/usr/bin/env bash
set -euo pipefail
# The base's faces and every installed plugin's own (a family that ships its type in assets/fonts) linked where
# fontconfig looks, so apps, GTK and doctor have what the shell draws with; a removed plugin's link goes with it.
# sync-system-fonts.sh runs it from the shell; doctor's font check runs it first, so an update that has just installed
# a family sees that family's faces before the new shell starts (every update said "Geist unavailable", 11-04).

shell_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
mkdir -p "$state_home/quickshell/user/generated"
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
