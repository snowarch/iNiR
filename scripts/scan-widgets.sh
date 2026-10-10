#!/usr/bin/env bash
# Scan custom widgets directory and output JSON manifest list.
# With a generation number, each widget is also linked under a folder for that generation and the
# JSON says where ("load"): the shell loads from there, so a widget updated in place compiles again,
# its .js and imports too (Qt keeps what it compiled per URL for the life of the process).
dir="${1:?Usage: scan-widgets.sh <widgets-dir> [generation]}"
gen="${2:-}"
[ -d "$dir" ] || { echo "[]"; exit 0; }

loads=""
if [ -n "$gen" ]; then
    root="${XDG_RUNTIME_DIR:-/tmp}/inir/widget-loads"
    loads="$root/g$gen"
    mkdir -p "$loads" 2>/dev/null || loads=""
    # The previous generation may still be finishing a load; anything older goes (links only).
    [ -n "$loads" ] && find "$root" -mindepth 1 -maxdepth 1 -name 'g*' ! -name "g$gen" ! -name "g$((gen - 1))" -exec rm -rf {} + 2>/dev/null
fi

result="["
first=true
for manifest in "$dir"/*/widget.json; do
    [ -f "$manifest" ] || continue
    wdir="$(dirname "$manifest")"
    wid="$(basename "$wdir")"
    content="$(cat "$manifest" 2>/dev/null)" || continue
    load="$wdir"
    if [ -n "$loads" ] && ln -sfn "$wdir" "$loads/$wid" 2>/dev/null; then
        load="$loads/$wid"
    fi
    $first || result="$result,"
    first=false
    result="$result{\"id\":\"$wid\",\"dir\":\"$wdir\",\"load\":\"$load\",\"manifest\":$content}"
done
echo "$result]"
