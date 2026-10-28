#!/usr/bin/env bash
# The path the families call: inir-accel answers it with least_busy_region.py's arguments and output.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/accel.sh"
[[ -x "$INIR_ACCEL" ]] || { echo "inir-accel is missing. Run: inir update" >&2; exit 1; }
exec "$INIR_ACCEL" region "$@"
