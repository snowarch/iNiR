#!/usr/bin/env bash
# The path the families call: inir-accel answers it with least_busy_region.py's arguments and output.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/accel.sh"
exec "$INIR_ACCEL" region "$@"
