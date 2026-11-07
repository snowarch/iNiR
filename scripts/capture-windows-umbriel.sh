#!/usr/bin/env bash
# Window previews under Umbriel: each NUMBER=UMBRIEL_ID pair is captured through ext-image-copy-capture (Umbriel's
# window id is the foreign-toplevel identifier grim takes) into window-NUMBER.png. Unlike Niri's screenshot-window it
# never touches the clipboard. A failed capture leaves the previous preview in place.
set -uo pipefail

preview_dir="$HOME/.cache/inir/window-previews"
mkdir -p "$preview_dir"
command -v grim >/dev/null 2>&1 || { echo "[capture-windows] missing binary: grim" >&2; exit 127; }
rm -f "$preview_dir"/.window-*.part.png 2>/dev/null || true

pids=()
for pair in "$@"; do
  num="${pair%%=*}" id="${pair#*=}"
  [[ "$num" =~ ^[0-9]+$ && "$id" =~ ^[A-Za-z0-9_-]+$ ]] || continue
  {
    tmp="$preview_dir/.window-$num.part.png"
    if grim -l 1 -T "$id" "$tmp" 2>/dev/null && [[ -s "$tmp" ]]; then
      mv -f "$tmp" "$preview_dir/window-$num.png"
    else
      rm -f "$tmp"
      exit 1
    fi
  } &
  pids+=("$!")
  if (( ${#pids[@]} >= 4 )); then wait "${pids[0]}"; pids=("${pids[@]:1}"); fi
done
for pid in "${pids[@]}"; do wait "$pid" || true; done
exit 0
