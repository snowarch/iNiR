#!/usr/bin/env bash
# Generate cava config for internal widget usage (CavaProcess.qml)
# Usage: generate_config.sh <output_file> [framerate] [sensitivity] [bars] [stereo]
#
# All parameters after output_file are optional and fall back to sane defaults.
# Supports both PipeWire and PulseAudio systems.

OUTPUT_FILE="${1:-/tmp/cava_config.txt}"
FRAMERATE="${2:-60}"
SENSITIVITY="${3:-100}"
BARS="${4:-50}"
STEREO="${5:-false}"
DESKTOP_ENTRY="${6:-}"

# Detect audio backend (pipewire or pulseaudio)
get_audio_method() {
    if pactl info 2>/dev/null | grep -qi "PipeWire"; then
        echo "pipewire"
    else
        echo "pulse"
    fi
}

# Get the default sink's monitor source
get_default_monitor() {
    local default_sink
    default_sink=$(pactl get-default-sink 2>/dev/null)
    if [[ -n "$default_sink" ]]; then
        echo "${default_sink}.monitor"
        return
    fi
    echo "auto"
}

METHOD=$(get_audio_method)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOLVER="$SCRIPT_DIR/resolve_audio_source.py"
RESOLVED=""
if [[ -f "$RESOLVER" ]]; then
  RESOLVED=$(python3 "$RESOLVER" --desktop-entry "$DESKTOP_ENTRY" 2>/dev/null || true)
fi
if [[ -n "$RESOLVED" ]]; then
  MONITOR="$RESOLVED"
else
  MONITOR=$(get_default_monitor)
fi
CHANNELS="mono"
[[ "$STEREO" == "true" ]] && CHANNELS="stereo"

cat > "$OUTPUT_FILE" << EOF
[general]
framerate = ${FRAMERATE}
sensitivity = ${SENSITIVITY}
autosens = 1
bars = ${BARS}

[input]
method = ${METHOD}
source = ${MONITOR}

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
channels = ${CHANNELS}
mono_option = average

[smoothing]
noise_reduction = 20
EOF

echo "$OUTPUT_FILE"
