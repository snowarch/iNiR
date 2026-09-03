#!/usr/bin/env bash
# Store normal clipboard images in cliphist while ignoring iNiR's internal
# Niri window-preview screenshots. wl-paste --watch streams the image on stdin.

set -euo pipefail

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
marker="$runtime_dir/inir-window-preview-capture-${UID:-$(id -u)}"

if [[ -r "$marker" ]]; then
  preview_pid="$(cat "$marker" 2>/dev/null || true)"
  if [[ "$preview_pid" =~ ^[0-9]+$ ]] && kill -0 "$preview_pid" 2>/dev/null; then
    # Consume stdin so wl-paste's watched child exits cleanly, but deliberately
    # do not forward this compositor-internal frame into clipboard history.
    cat >/dev/null
    exit 0
  fi
  # A SIGKILL/power loss can leave a marker behind; never let that disable
  # image history permanently.
  rm -f -- "$marker" 2>/dev/null || true
fi

exec cliphist store
