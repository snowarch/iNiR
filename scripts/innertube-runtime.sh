#!/usr/bin/env bash
# YouTube Music browsing runs in inir-accel; the browser cookie extraction it calls is still ytmusic_auth.py.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export INIR_YTMUSIC_AUTH="$SCRIPT_DIR/ytmusic_auth.py"
exec "$SCRIPT_DIR/lib/accel-run" innertube "$@"
