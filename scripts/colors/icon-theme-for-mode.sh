#!/usr/bin/env bash
# Print the installed variant of an icon theme that matches a colour mode.
#   icon-theme-for-mode.sh <theme> <light|dark>
# Icon themes ship their light and dark looks as sibling themes (WhiteSur / WhiteSur-dark,
# Papirus-Light / Papirus-Dark): a dark variant draws white symbolic icons, unreadable on a light
# scheme. The chosen theme names the family; the mode picks the sibling. A theme with no sibling
# for the mode is printed unchanged.
set -euo pipefail

theme="${1:-}"
mode="${2:-dark}"
[[ -z "$theme" ]] && exit 0

icon_dirs=("${XDG_DATA_HOME:-$HOME/.local/share}/icons" "$HOME/.icons")
IFS=':' read -r -a data_dirs <<< "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
for dir in "${data_dirs[@]}"; do icon_dirs+=("$dir/icons"); done

installed() {
    local dir
    for dir in "${icon_dirs[@]}"; do
        [[ -f "$dir/$1/index.theme" ]] && return 0
    done
    return 1
}

base="$theme"
suffix=""
for s in -dark -Dark -light -Light; do
    if [[ "$theme" == *"$s" ]]; then
        base="${theme%"$s"}"
        suffix="${s,,}"
        break
    fi
done

if [[ "$mode" == "dark" ]]; then
    [[ "$suffix" == "-dark" ]] && { echo "$theme"; exit 0; }
    candidates=("$base-dark" "$base-Dark")
    # A light-suffixed choice with no dark sibling falls back to the family's base.
    [[ "$suffix" == "-light" ]] && candidates+=("$base")
else
    [[ "$suffix" != "-dark" ]] && { echo "$theme"; exit 0; }
    candidates=("$base" "$base-light" "$base-Light")
fi

for candidate in "${candidates[@]}"; do
    if installed "$candidate"; then
        echo "$candidate"
        exit 0
    fi
done
echo "$theme"
