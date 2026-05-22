#!/usr/bin/env bash
# Capture screenshots of windows for TaskView
# Handles cliphist cleanup to prevent screenshot spam

set -euo pipefail

preview_dir="$HOME/.cache/inir/window-previews"
mkdir -p "$preview_dir"

niri_bin="/usr/bin/niri"
jq_bin="/usr/bin/jq"
cliphist_bin="/usr/bin/cliphist"
head_bin="/usr/bin/head"
wl_paste_bin="/usr/bin/wl-paste"
wl_copy_bin="/usr/bin/wl-copy"

capture_all=false
ids_to_capture=()

for arg in "$@"; do
  if [[ "$arg" == "--all" ]]; then
    capture_all=true
  elif [[ "$arg" =~ ^[0-9]+$ ]]; then
    ids_to_capture+=("$arg")
  fi
done

for bin in "$niri_bin" "$jq_bin" "$cliphist_bin" "$head_bin"; do
  if [[ ! -x "$bin" ]]; then
    echo "[capture-windows] missing binary: $bin" >&2
    exit 127
  fi
done

# Preserve clipboard (best-effort) so previews never replace user clipboard.
saved_clip_mime=""
saved_clip_file=""
if [[ -x "$wl_paste_bin" && -x "$wl_copy_bin" ]]; then
  mime_list="$($wl_paste_bin -l 2>/dev/null || true)"
  if printf '%s\n' "$mime_list" | grep -qx "text/plain;charset=utf-8"; then
    saved_clip_mime="text/plain;charset=utf-8"
  elif printf '%s\n' "$mime_list" | grep -qx "text/plain"; then
    saved_clip_mime="text/plain"
  elif printf '%s\n' "$mime_list" | grep -qx "UTF8_STRING"; then
    saved_clip_mime="UTF8_STRING"
  elif printf '%s\n' "$mime_list" | grep -qx "image/png"; then
    saved_clip_mime="image/png"
  fi

  if [[ -n "$saved_clip_mime" ]]; then
    saved_clip_file="$(mktemp -t inir-clipboard.XXXXXX 2>/dev/null || true)"
    if [[ -n "$saved_clip_file" ]]; then
      if ! "$wl_paste_bin" --type "$saved_clip_mime" >"$saved_clip_file" 2>/dev/null; then
        saved_clip_mime=""
        rm -f "$saved_clip_file" 2>/dev/null || true
        saved_clip_file=""
      fi
    else
      saved_clip_mime=""
    fi
  fi
fi

mapfile -t all_windows < <("$niri_bin" msg -j windows 2>/dev/null | "$jq_bin" -r '.[].id')
if [[ ${#all_windows[@]} -eq 0 ]]; then
  exit 0
fi

windows_to_capture=()

if $capture_all || [[ ${#ids_to_capture[@]} -eq 0 ]]; then
  windows_to_capture=("${all_windows[@]}")
else
  for id in "${ids_to_capture[@]}"; do
    for w in "${all_windows[@]}"; do
      if [[ "$id" == "$w" ]]; then
        windows_to_capture+=("$id")
        break
      fi
    done
  done
fi

if [[ ${#windows_to_capture[@]} -eq 0 ]]; then
  exit 0
fi

before_id=0
first_entry="$($cliphist_bin list 2>/dev/null | $head_bin -1 || true)"
if [[ -n "$first_entry" ]]; then
  before_id="${first_entry%%$'\t'*}"
  if [[ ! "$before_id" =~ ^[0-9]+$ ]]; then
    before_id=0
  fi
fi

max_concurrent=4
pids=()
count=0

for id in "${windows_to_capture[@]}"; do
  path="$preview_dir/window-$id.png"
  "$niri_bin" msg action screenshot-window --id "$id" --path "$path" 2>/dev/null &
  pids+=("$!")
  count=$((count + 1))

  if [[ $count -ge $max_concurrent ]]; then
    for pid in "${pids[@]}"; do
      wait "$pid" || true
    done
    pids=()
    count=0
  fi
done

for pid in "${pids[@]}"; do
  wait "$pid" || true
done

sleep 0.5

max_cleanup=100

# Two cleanup passes: first catches most entries, second catches late arrivals
for _pass in 1 2; do
  cleanup_count=0
  while [[ $cleanup_count -lt $max_cleanup ]]; do
    entry="$($cliphist_bin list 2>/dev/null | $head_bin -1 || true)"
    if [[ -z "$entry" ]]; then
      break
    fi

    entry_id="${entry%%$'\t'*}"
    if [[ "$entry_id" =~ ^[0-9]+$ ]] && [[ "$entry_id" -gt "$before_id" ]]; then
      printf '%s\n' "$entry" | "$cliphist_bin" delete 2>/dev/null || true
      cleanup_count=$((cleanup_count + 1))
    else
      break
    fi
  done
  [[ $_pass -eq 1 ]] && sleep 0.3
done

# Restore clipboard AFTER cleanup so screenshot-window side effects never persist.
if [[ -n "$saved_clip_mime" && -n "$saved_clip_file" && -x "$wl_copy_bin" ]]; then
  "$wl_copy_bin" --type "$saved_clip_mime" <"$saved_clip_file" 2>/dev/null || true
fi
rm -f "$saved_clip_file" 2>/dev/null || true

missing=0
for id in "${windows_to_capture[@]}"; do
  path="$preview_dir/window-$id.png"
  if [[ ! -s "$path" ]]; then
    echo "[capture-windows] missing output file: $path" >&2
    missing=1
  fi
done

if [[ $missing -ne 0 ]]; then
  exit 1
fi
