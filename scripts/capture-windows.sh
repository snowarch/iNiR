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
sha256_bin="/usr/bin/sha256sum"

capture_all=false
ids_to_capture=()

for arg in "$@"; do
  if [[ "$arg" == "--all" ]]; then
    capture_all=true
  elif [[ "$arg" =~ ^[0-9]+$ ]]; then
    ids_to_capture+=("$arg")
  fi
done

for bin in "$niri_bin" "$jq_bin" "$cliphist_bin" "$head_bin" \
  "$wl_paste_bin" "$wl_copy_bin" "$sha256_bin"; do
  if [[ ! -x "$bin" ]]; then
    echo "[capture-windows] missing binary: $bin" >&2
    exit 127
  fi
done

state_dir="$(mktemp -d -t inir-window-previews.XXXXXX)"
trap 'rm -rf -- "$state_dir"' EXIT

select_clipboard_mime() {
  local mime_list preferred
  mime_list="$("$wl_paste_bin" -l 2>/dev/null || true)"
  for preferred in \
    "text/plain;charset=utf-8" \
    "text/plain" \
    "UTF8_STRING" \
    "image/png"; do
    if printf '%s\n' "$mime_list" | /usr/bin/grep -Fqx "$preferred"; then
      printf '%s\n' "$preferred"
      return
    fi
  done
  printf '%s\n' "$mime_list" | /usr/bin/head -1
}

hash_matches_preview() {
  local candidate="$1" preview_hash
  for preview_hash in "${preview_hashes[@]}"; do
    [[ "$candidate" == "$preview_hash" ]] && return 0
  done
  return 1
}

# Niri always puts screenshot-window output in the clipboard even when --path
# is supplied. Save one pasteable representation synchronously before starting
# any capture. Arbitrary MIME fallback covers browser/custom selections too.
saved_clip_mime="$(select_clipboard_mime)"
saved_clip_file="$state_dir/clipboard.bin"
if [[ -n "$saved_clip_mime" ]]; then
  if ! "$wl_paste_bin" --type "$saved_clip_mime" >"$saved_clip_file" 2>/dev/null; then
    saved_clip_mime=""
    : >"$saved_clip_file"
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

# Publish each preview by rename. The shell polls this directory with a plain
# Image source, so a reader must never open a half-written PNG, and a capture
# that fails must leave the previous good preview instead of truncating it.
rm -f "$preview_dir"/.window-*.part.png 2>/dev/null || true

for id in "${windows_to_capture[@]}"; do
  path="$preview_dir/window-$id.png"
  tmp="$preview_dir/.window-$id.part.png"
  {
    if "$niri_bin" msg action screenshot-window --id "$id" --path "$tmp" >/dev/null; then
      # The action and clipboard ownership can settle after the IPC reply.
      for _ready_try in {1..40}; do
        [[ -s "$tmp" ]] && break
        sleep 0.05
      done
      if [[ -s "$tmp" ]]; then
        mv -f "$tmp" "$path"
        exit 0
      fi
    fi
    rm -f "$tmp"
    exit 1
  } &
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

preview_hashes=()
for id in "${windows_to_capture[@]}"; do
  path="$preview_dir/window-$id.png"
  if [[ -s "$path" ]]; then
    preview_hashes+=("$("$sha256_bin" "$path" | cut -d' ' -f1)")
  fi
done

sleep 0.5

max_cleanup=100

# Delete only cliphist entries whose decoded bytes match a generated preview.
# A user copy made during capture may have a newer ID too and must survive.
for _pass in 1 2; do
  cleanup_count=0
  while IFS= read -r entry && [[ $cleanup_count -lt $max_cleanup ]]; do
    entry_id="${entry%%$'\t'*}"
    [[ "$entry_id" =~ ^[0-9]+$ ]] || continue
    [[ "$entry_id" -gt "$before_id" ]] || break
    decoded_entry="$state_dir/cliphist-$entry_id.bin"
    if printf '%s\n' "$entry" | "$cliphist_bin" decode >"$decoded_entry" 2>/dev/null; then
      entry_hash="$("$sha256_bin" "$decoded_entry" | cut -d' ' -f1)"
      if hash_matches_preview "$entry_hash"; then
        printf '%s\n' "$entry" | "$cliphist_bin" delete 2>/dev/null || true
      fi
      cleanup_count=$((cleanup_count + 1))
    fi
  done < <("$cliphist_bin" list 2>/dev/null)
  [[ $_pass -eq 1 ]] && sleep 0.3
done

# Restore only when Niri still owns the clipboard with one of our screenshots.
# If the user copied something else while capture ran, that newer intent wins.
current_clip_file="$state_dir/current-clipboard.png"
current_clip_hash=""
if "$wl_paste_bin" -l 2>/dev/null | /usr/bin/grep -Fqx "image/png"; then
  if "$wl_paste_bin" --type "image/png" >"$current_clip_file" 2>/dev/null; then
    current_clip_hash="$("$sha256_bin" "$current_clip_file" | cut -d' ' -f1)"
  fi
fi
if [[ -n "$current_clip_hash" ]] && hash_matches_preview "$current_clip_hash"; then
  if [[ -n "$saved_clip_mime" && -s "$saved_clip_file" ]]; then
    "$wl_copy_bin" --type "$saved_clip_mime" <"$saved_clip_file" 2>/dev/null || true
  else
    "$wl_copy_bin" --clear 2>/dev/null || true
  fi
fi

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
