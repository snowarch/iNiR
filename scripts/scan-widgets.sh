#!/usr/bin/env bash
# Scan custom widgets directory and output JSON manifest list
dir="${1:?Usage: scan-widgets.sh <widgets-dir>}"
[ -d "$dir" ] || { echo "[]"; exit 0; }

result="["
first=true
for manifest in "$dir"/*/widget.json; do
    [ -f "$manifest" ] || continue
    wdir="$(dirname "$manifest")"
    wid="$(basename "$wdir")"
    content="$(cat "$manifest" 2>/dev/null)" || continue
    $first || result="$result,"
    first=false
    result="$result{\"id\":\"$wid\",\"dir\":\"$wdir\",\"manifest\":$content}"
done
echo "$result]"
