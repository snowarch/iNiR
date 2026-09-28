#!/usr/bin/env bash
# Capture screenshots of windows for TaskView
# Handles cliphist cleanup to prevent screenshot spam

set -euo pipefail

preview_dir="$HOME/.cache/inir/window-previews"
mkdir -p "$preview_dir"

resolve_bin() {
  local name="$1" path
  path="$(command -v "$name" 2>/dev/null || true)"
  if [[ -z "$path" ]]; then
    echo "[capture-windows] missing binary: $name" >&2
    return 127
  fi
  printf '%s\n' "$path"
}

niri_bin="$(resolve_bin niri)" || exit $?
jq_bin="$(resolve_bin jq)" || exit $?
cliphist_bin="$(resolve_bin cliphist)" || exit $?
head_bin="$(resolve_bin head)" || exit $?
grep_bin="$(resolve_bin grep)" || exit $?
wl_paste_bin="$(resolve_bin wl-paste)" || exit $?
wl_copy_bin="$(resolve_bin wl-copy)" || exit $?
sha256_bin="$(resolve_bin sha256sum)" || exit $?

capture_all=false
ids_to_capture=()

for arg in "$@"; do
  if [[ "$arg" == "--all" ]]; then
    capture_all=true
  elif [[ "$arg" =~ ^[0-9]+$ ]]; then
    ids_to_capture+=("$arg")
  fi
done

state_dir="$(mktemp -d -t inir-window-previews.XXXXXX)"
preview_marker="${XDG_RUNTIME_DIR:-/tmp}/inir-window-preview-capture-${UID:-$(id -u)}"

cleanup_exit() {
  rm -f -- "$preview_marker" 2>/dev/null || true
  rm -rf -- "$state_dir"
}
trap cleanup_exit EXIT INT TERM

select_clipboard_mime() {
  local mime_list preferred
  mime_list="$("$wl_paste_bin" -l 2>/dev/null || true)"
  for preferred in \
    "text/plain;charset=utf-8" \
    "text/plain" \
    "UTF8_STRING" \
    "image/png"; do
    if printf '%s\n' "$mime_list" | "$grep_bin" -Fqx "$preferred"; then
      printf '%s\n' "$preferred"
      return
    fi
  done
  printf '%s\n' "$mime_list" | "$head_bin" -1
}

hash_matches_preview() {
  local candidate="$1" preview_hash
  for preview_hash in "${preview_hashes[@]}"; do
    [[ "$candidate" == "$preview_hash" ]] && return 0
  done
  return 1
}

restore_clipboard_file() {
  local mime="$1"
  local file="$2"

  # wl-copy normally forks and remains alive as the Wayland selection owner.
  # When this script runs from Quickshell that daemon would otherwise remain
  # inside inir.service after a shell restart.  Let the systemd user manager
  # own a foreground wl-copy in its own transient service instead: the
  # clipboard survives iNiR restarts, while the shell cgroup remains clean.
  # Use a per-capture unit name so an older selection owner can finish its
  # Wayland cancellation path without racing a unit-name reuse.
  local unit="inir-clipboard-owner-${BASHPID:-$$}"
  local systemd_run_bin
  if systemd_run_bin="$(command -v systemd-run 2>/dev/null)"; then
    if "$systemd_run_bin" \
      --user \
      --quiet \
      --unit="$unit" \
      --collect \
      --service-type=exec \
      --property="StandardInput=file:$file" \
      "$wl_copy_bin" --foreground --type "$mime"; then
      return 0
    fi
  fi

  # Keep clipboard restoration functional on non-systemd user sessions. The
  # fallback preserves the previous behavior, including wl-copy's daemon mode.
  "$wl_copy_bin" --type "$mime" <"$file"
}

restore_saved_clipboard() {
  if [[ -n "${saved_clip_mime:-}" && -s "${saved_clip_file:-/dev/null}" ]]; then
    restore_clipboard_file "$saved_clip_mime" "$saved_clip_file" 2>/dev/null || true
  else
    "$wl_copy_bin" --clear 2>/dev/null || true
  fi
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

# Mark the batch before Niri changes the clipboard. The image watcher routes
# through clipboard-image-store.sh, which consumes these internal frames instead
# of forwarding them to cliphist. The marker contains our PID so a stale file
# after an unclean shutdown cannot disable image history permanently.
printf '%s\n' "${BASHPID:-$$}" >"$preview_marker"

# niri screenshot-window always publishes to the global clipboard, even with
# --path. Serializing captures avoids multiple compositor actions racing that
# single selection and smooths the GPU/CPU burst. WindowPreviewService now
# keeps capture batches small through per-window freshness budgets.
max_concurrent=1
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
      # Niri publishes screenshot-window to the global clipboard even with
      # --path. Restore the user's pre-capture selection immediately, before
      # another preview capture or an app switch can expose the PNG to paste.
      # The final guarded restore below remains as a second safety net.
      restore_saved_clipboard
      # The output file can settle shortly after the IPC reply.
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
if "$wl_paste_bin" -l 2>/dev/null | "$grep_bin" -Fqx "image/png"; then
  if "$wl_paste_bin" --type "image/png" >"$current_clip_file" 2>/dev/null; then
    current_clip_hash="$("$sha256_bin" "$current_clip_file" | cut -d' ' -f1)"
  fi
fi
if [[ -n "$current_clip_hash" ]] && hash_matches_preview "$current_clip_hash"; then
  restore_saved_clipboard
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
