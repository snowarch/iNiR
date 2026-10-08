#!/usr/bin/env bash
# Usage: video-playback-copy.sh [--check] <source> <output> <height> [max-fps]
#
# Writes <output>: <source> scaled down to <height> (and to max-fps) for playback, or a
# symlink to <source> when it is already that small. --check only reports whether <output>
# is current (exit 0) or needs building (exit 1).
set -uo pipefail

check=0
if [[ "${1:-}" == "--check" ]]; then check=1; shift; fi
src="${1:-}" out="${2:-}" height="${3:-0}" max_fps="${4:-0}"
[[ -f "$src" && -n "$out" && "$height" -gt 0 ]] || exit 2

if [[ -L "$out" ]]; then
    [[ "$(readlink "$out")" == "$src" ]] && { touch -h "$out"; exit 0; }
elif [[ -s "$out" && "$out" -nt "$src" ]]; then
    touch "$out"; exit 0
fi
(( check )) && exit 1

command -v ffprobe >/dev/null && command -v ffmpeg >/dev/null || exit 3
dims="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height,avg_frame_rate -of csv=p=0 "$src")" || exit 4
IFS=, read -r src_w src_h rate <<< "$dims"
rate="${rate:-0/1}"
src_fps=$(( ${rate%%/*} / (${rate##*/} > 0 ? ${rate##*/} : 1) ))
[[ "$src_w" =~ ^[0-9]+$ && "$src_h" =~ ^[0-9]+$ && "$src_h" -gt 0 ]] || exit 4

dir="$(dirname "$out")"
mkdir -p "$dir"
fps_filter=""
(( max_fps > 0 && src_fps > max_fps )) && fps_filter="fps=$max_fps,"
if (( src_h <= height * 115 / 100 )) && [[ -z "$fps_filter" ]]; then
    ln -sfn "$src" "$out"
    exit 0
fi

width=$(( (src_w * height / src_h + 1) / 2 * 2 ))
qp=$(( height >= 720 ? 16 : 22 ))
tmp="$out.part.mp4"
trap 'rm -f "$tmp"' EXIT
run() { nice -n 19 ionice -c 3 ffmpeg -hide_banner -loglevel error -y "$@"; }
common=(-map 0:v:0 -an -sn -dn -fps_mode passthrough -g 60 -movflags +faststart)
render="$(ls /dev/dri/renderD* 2>/dev/null | head -1)"

built=0
if [[ -n "$render" ]]; then
    run -hwaccel vaapi -hwaccel_device "$render" -hwaccel_output_format vaapi -i "$src" \
        -vf "${fps_filter}scale_vaapi=w=$width:h=$height:format=nv12" -c:v h264_vaapi -qp "$qp" "${common[@]}" "$tmp" && built=1
    (( built )) || run -vaapi_device "$render" -i "$src" \
        -vf "${fps_filter}format=nv12,hwupload,scale_vaapi=w=$width:h=$height" -c:v h264_vaapi -qp "$qp" "${common[@]}" "$tmp" && built=1
fi
(( built )) || run -i "$src" -vf "${fps_filter}scale=$width:$height:flags=lanczos,format=yuv420p" \
    -c:v libx264 -preset veryfast -crf $(( qp + 1 )) "${common[@]}" "$tmp" && built=1
(( built )) || exit 5
mv -f "$tmp" "$out"

# Keep the newest copies only; each one is a few MB and gets rebuilt on demand.
ls -1t "$dir" 2>/dev/null | tail -n +13 | while read -r stale; do rm -f "$dir/$stale"; done
exit 0
