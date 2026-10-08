#!/usr/bin/env bash
# Runs inir-washi (scripts/colors/washi), building it first when its sources are newer than the binary.
# Usage: washi.sh --request '<json>' --out <file>  |  washi.sh --default
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
bin_dir="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/bin"
bin="$bin_dir/inir-washi"

stale() {
  [[ -x "$bin" ]] || return 0
  local src
  for src in "$here"/washi/*.go "$root/go.mod"; do
    [[ "$src" == *_test.go ]] && continue
    [[ "$src" -nt "$bin" ]] && return 0
  done
  return 1
}

if stale; then
  go_bin="$(command -v go || true)"
  if [[ -z "$go_bin" ]]; then
    [[ -x "$bin" ]] || { echo "washi: Go is not installed; iRiS keeps its default palette" >&2; exit 3; }
  else
    mkdir -p "$bin_dir"
    tmp="$bin_dir/.inir-washi.$$"
    if (cd "$root" && "$go_bin" build -trimpath -o "$tmp" ./scripts/colors/washi) >&2; then
      mv -f "$tmp" "$bin"
    else
      rm -f "$tmp"
      [[ -x "$bin" ]] || exit 4
    fi
  fi
fi

exec "$bin" "$@"
