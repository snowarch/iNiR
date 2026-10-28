#!/usr/bin/env bash
# Runs inir-washi, iRiS's palette solver: inir-accel's, linked into user/generated/bin by sdata/lib/prebuilt.sh.
# Usage: washi.sh --request '<json>' --out <file>  |  washi.sh --default
set -uo pipefail

bin="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/bin/inir-washi"
[[ -x "$bin" ]] || { echo "washi: inir-accel is not installed; iRiS keeps its default palette" >&2; exit 3; }
exec "$bin" "$@"
