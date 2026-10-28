# shellcheck shell=bash
# inir-accel runs what the shell spawns (colours, regions...); setup and update put it in accel/current.
# INIR_ACCEL points at another build.
INIR_ACCEL="${INIR_ACCEL:-${XDG_DATA_HOME:-$HOME/.local/share}/inir/accel/current/inir-accel}"
