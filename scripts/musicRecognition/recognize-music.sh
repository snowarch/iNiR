#!/usr/bin/env bash

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

INTERVAL=2
TOTAL_DURATION=30
MIN_VALID_RESULT_LENGTH=300
SOURCE_TYPE="monitor"  # monitor | input
TMP_PATH="/tmp/quickshell/media/songrec"
TMP_RAW="$TMP_PATH/recording.raw"
TMP_MP3="$TMP_PATH/recording.mp3"

while getopts "i:t:s:" opt; do
  case $opt in
    i) INTERVAL=$OPTARG ;;
    t) TOTAL_DURATION=$OPTARG ;;
    s) SOURCE_TYPE=$OPTARG ;;
    *) exit 1 ;;
  esac
done
if [ "$SOURCE_TYPE" = "monitor" ]; then
    MONITOR_SOURCE=$(/usr/bin/pactl get-default-sink).monitor
elif [ "$SOURCE_TYPE" = "input" ]; then
    MONITOR_SOURCE=$(/usr/bin/pactl info | /usr/bin/grep "Default Source:" | /usr/bin/awk '{print $3}' || true)
else
    echo "Invalid source type"
    exit 1
fi

if [ ! -x /usr/bin/songrec ] || [ ! -x /usr/bin/parec ] || [ ! -x /usr/bin/ffmpeg ]; then
    exit 1
fi

if [ -z "$MONITOR_SOURCE" ] || ! /usr/bin/pactl list short sources | /usr/bin/grep -q "$MONITOR_SOURCE"; then
    exit 1
fi

cleanup() {
    /usr/bin/rm -f "$TMP_RAW" "$TMP_MP3"
    /usr/bin/pkill -P $$ parec >/dev/null 2>&1 || true
}
trap cleanup EXIT

/usr/bin/mkdir -p "$TMP_PATH"
/usr/bin/parec --device="$MONITOR_SOURCE" --format=s16le --rate=44100 --channels=2 > "$TMP_RAW" &
START_TIME=$(/usr/bin/date +%s)

while true; do
    /usr/bin/sleep "$INTERVAL"
    CURRENT_TIME=$(/usr/bin/date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))

    if (( ELAPSED >= TOTAL_DURATION )); then
        exit 0
    fi

    /usr/bin/ffmpeg -f s16le -ar 44100 -ac 2 -i "$TMP_RAW" -acodec libmp3lame -y -hide_banner -loglevel error "$TMP_MP3" 2>/dev/null
    RESULT=$(/usr/bin/songrec recognize -j "$TMP_MP3" 2>/dev/null || true)

    if echo "$RESULT" | /usr/bin/grep -q '"matches": \[' && [ ${#RESULT} -gt $MIN_VALID_RESULT_LENGTH ]; then
        echo "$RESULT"
        exit 0
    fi
done
