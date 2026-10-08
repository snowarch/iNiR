#!/usr/bin/env bash
# Publish clipboard data without leaving wl-copy inside inir.service.
set -euo pipefail

selection_args=()
if [[ "${1:-}" == "--primary" ]]; then
  selection_args=(--primary)
  shift
fi

wl_copy_bin="$(command -v wl-copy 2>/dev/null || true)"
[[ -n "$wl_copy_bin" ]] || { echo "wl-copy is not installed" >&2; exit 127; }

state_dir="${XDG_RUNTIME_DIR:-/tmp}/inir-clipboard"
mkdir -p "$state_dir"
data_file="$(mktemp "$state_dir/copy.XXXXXX")"
trap 'rm -f -- "$data_file"' EXIT

if (($# > 0)); then
  printf '%s' "$*" > "$data_file"
else
  cat > "$data_file"
fi

# wl-copy is a long-lived Wayland selection owner. Let systemd own the
# foreground process so stopping/restarting iNiR never leaves it in the shell
# cgroup. StandardInput is opened by the manager before systemd-run returns.
if command -v systemd-run >/dev/null 2>&1; then
  unit="inir-clipboard-owner-${BASHPID:-$$}-$(date +%s%N)"
  if systemd-run --user --quiet --unit="$unit" --collect --service-type=exec \
      --property="StandardInput=file:$data_file" \
      "$wl_copy_bin" --foreground "${selection_args[@]}"; then
    exit 0
  fi
fi

# Non-systemd user sessions: wl-copy's normal daemon mode is the best fallback.
"$wl_copy_bin" "${selection_args[@]}" < "$data_file"
