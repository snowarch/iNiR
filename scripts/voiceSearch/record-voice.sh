#!/usr/bin/env bash
# Record audio from microphone for voice search

DURATION="${1:-8}"
TMP_PATH="/tmp/quickshell/media/voicesearch"
TMP_WAV="$TMP_PATH/recording.wav"

mkdir -p "$TMP_PATH"
rm -f "$TMP_WAV" 2>/dev/null

# Record with pw-record (PipeWire)
timeout "${DURATION}s" pw-record --format=s16 --rate=16000 --channels=1 "$TMP_WAV" 2>/dev/null

if [ -f "$TMP_WAV" ] && [ -s "$TMP_WAV" ]; then
    echo "$TMP_WAV"
    exit 0
fi

echo "error: recording failed" >&2
exit 1
