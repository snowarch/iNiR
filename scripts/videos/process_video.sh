#!/usr/bin/env bash
INPUT="$1"
CROP_W_UI="$2"
CROP_H_UI="$3"
CROP_X_UI="$4"
CROP_Y_UI="$5"
START_MS="$6"
END_MS="$7"
UI_W="$8"
UI_H="$9"
REPLACE="${10}"

# Log for debugging
echo "Processing $INPUT" > /tmp/video_edit.log
echo "UI: ${UI_W}x${UI_H}, Crop: ${CROP_W_UI}x${CROP_H_UI} at ${CROP_X_UI},${CROP_Y_UI}" >> /tmp/video_edit.log
echo "Time: ${START_MS}ms to ${END_MS}ms" >> /tmp/video_edit.log
echo "Replace: $REPLACE" >> /tmp/video_edit.log

# Get original dimensions
DIM=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$INPUT")
ORIG_W=$(echo $DIM | cut -dx -f1)
ORIG_H=$(echo $DIM | cut -dx -f2)

echo "Original: ${ORIG_W}x${ORIG_H}" >> /tmp/video_edit.log

# Convert ms to seconds with leading zero
START_S=$(echo "scale=3; $START_MS / 1000" | bc -l | sed 's/^\./0./; s/^-\./-0./')
END_S=$(echo "scale=3; $END_MS / 1000" | bc -l | sed 's/^\./0./; s/^-\./-0./')

# Handle case where bc returns just 0
[[ "$START_S" == "0" ]] || [[ -z "$START_S" ]] && START_S="0.000"
[[ "$END_S" == "0" ]] || [[ -z "$END_S" ]] && END_S="0.000"

FILTER=""
# Only apply crop if it's not the full UI area (with some tolerance)
W_RATIO=$(echo "scale=4; $CROP_W_UI / $UI_W" | bc -l)
if [[ "$CROP_W_UI" != "-1" ]] && (( $(echo "$W_RATIO < 0.99" | bc -l) )); then
    # Scale UI coordinates to original dimensions
    W=$(echo "($CROP_W_UI * $ORIG_W) / $UI_W" | bc)
    H=$(echo "($CROP_H_UI * $ORIG_H) / $UI_H" | bc)
    X=$(echo "($CROP_X_UI * $ORIG_W) / $UI_W" | bc)
    Y=$(echo "($CROP_Y_UI * $ORIG_H) / $UI_H" | bc)
    
    # Ensure values are even
    W=$(( (W / 2) * 2 ))
    H=$(( (H / 2) * 2 ))
    X=$(( (X / 2) * 2 ))
    Y=$(( (Y / 2) * 2 ))
    
    FILTER="-vf crop=$W:$H:$X:$Y"
    echo "Applying filter: $FILTER" >> /tmp/video_edit.log
fi

DIR=$(dirname "$INPUT")
BASE=$(basename "$INPUT")
EXT="${BASE##*.}"
NAME="${BASE%.*}"

if [[ "$REPLACE" == "1" ]]; then
    OUTPUT="${INPUT}.edited.${EXT}"
else
    # Find a unique name
    i=1
    while [[ -f "${DIR}/${NAME}_edited_${i}.${EXT}" ]]; do
        i=$((i+1))
    done
    OUTPUT="${DIR}/${NAME}_edited_${i}.${EXT}"
fi

notify-send "Editing Video..." "Applying crop and cut..." -a 'Video Editor' -i video-x-generic &

# Run ffmpeg
ffmpeg -i "$INPUT" -ss "$START_S" -to "$END_S" $FILTER -preset fast -crf 18 -y "$OUTPUT" >> /tmp/video_edit.log 2>&1

if [[ -f "$OUTPUT" ]]; then
    if [[ "$REPLACE" == "1" ]]; then
        mv "$OUTPUT" "$INPUT"
        notify-send "Video Edited" "Saved to $INPUT" -a 'Video Editor' -i video-x-generic &
    else
        notify-send "Video Saved" "New copy at $OUTPUT" -a 'Video Editor' -i video-x-generic &
    fi
else
    notify-send "Video Edit Failed" "Check /tmp/video_edit.log" -a 'Video Editor' -u critical &
fi
