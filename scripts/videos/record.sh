#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/config-path.sh
source "$SCRIPT_DIR/../lib/config-path.sh"

getdate() {
    date '+%Y-%m-%d_%H.%M.%S'
}

is_truthy() {
    case "$1" in
        1|true|TRUE|yes|YES|on|ON) return 0 ;;
        *) return 1 ;;
    esac
}

is_vaapi_codec() {
    [[ "$1" == "h264_vaapi" || "$1" == "hevc_vaapi" || "$1" == "vp9_vaapi" || "$1" == "av1_vaapi" ]]
}

is_nvenc_codec() {
    [[ "$1" == "h264_nvenc" || "$1" == "hevc_nvenc" || "$1" == "av1_nvenc" ]]
}

is_hw_codec() {
    is_vaapi_codec "$1" || is_nvenc_codec "$1"
}

is_nvidia_gpu() {
    command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null
}

json_escape() {
    local value="$1"
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/\\r}
    value=${value//$'\t'/\\t}
    printf '%s' "$value"
}

json_array() {
    local first=1
    printf '['
    for item in "$@"; do
        [[ $first -eq 0 ]] && printf ','
        printf '"%s"' "$(json_escape "$item")"
        first=0
    done
    printf ']'
}

resolve_hardware_device() {
    local requested="$1"
    if [[ -n "$requested" && "$requested" != "null" && -c "$requested" ]]; then
        printf '%s\n' "$requested"
        return
    fi

    local device
    for device in /dev/dri/renderD*; do
        if [[ -c "$device" ]]; then
            printf '%s\n' "$device"
            return
        fi
    done
}

collect_video_codecs() {
    local -a codecs=()
    local resolved_device="$1"

    if [[ -n "$resolved_device" && -c "$resolved_device" ]]; then
        has_ffmpeg_encoder h264_vaapi && codecs+=("h264_vaapi")
        has_ffmpeg_encoder hevc_vaapi && codecs+=("hevc_vaapi")
        has_ffmpeg_encoder vp9_vaapi && codecs+=("vp9_vaapi")
        has_ffmpeg_encoder av1_vaapi && codecs+=("av1_vaapi")
    fi

    if is_nvidia_gpu || has_ffmpeg_encoder h264_nvenc || has_ffmpeg_encoder hevc_nvenc || has_ffmpeg_encoder av1_nvenc; then
        has_ffmpeg_encoder h264_nvenc && codecs+=("h264_nvenc")
        has_ffmpeg_encoder hevc_nvenc && codecs+=("hevc_nvenc")
        has_ffmpeg_encoder av1_nvenc && codecs+=("av1_nvenc")
    fi

    has_ffmpeg_encoder libx264 && codecs+=("libx264")
    has_ffmpeg_encoder libx265 && codecs+=("libx265")

    printf '%s\n' "${codecs[@]}"
}

collect_audio_codecs() {
    local -a codecs=()
    has_ffmpeg_encoder aac && codecs+=("aac")
    has_ffmpeg_encoder libopus && codecs+=("libopus")
    has_ffmpeg_encoder opus && codecs+=("opus")
    printf '%s\n' "${codecs[@]}"
}

collect_audio_sources() {
    pactl list sources short 2>/dev/null | awk 'NF >= 2 { print $2 }'
}

collect_hardware_devices() {
    local device
    for device in /dev/dri/renderD*; do
        [[ -c "$device" ]] && printf '%s\n' "$device"
    done
}

probe_capabilities() {
    local resolved_device="$1"
    local default_sink
    default_sink="$(pactl get-default-sink 2>/dev/null)"
    local preferred_codec
    preferred_codec="$(detect_hw_video_codec)"

    local -a video_codecs=()
    local -a audio_codecs=()
    local -a audio_sources=()
    local -a hardware_devices=()

    mapfile -t video_codecs < <(collect_video_codecs "$resolved_device")
    mapfile -t audio_codecs < <(collect_audio_codecs)
    mapfile -t audio_sources < <(collect_audio_sources)
    mapfile -t hardware_devices < <(collect_hardware_devices)

    printf '{'
    printf '"videoCodecs":%s,' "$(json_array "${video_codecs[@]}")"
    printf '"audioCodecs":%s,' "$(json_array "${audio_codecs[@]}")"
    printf '"audioSources":%s,' "$(json_array "${audio_sources[@]}")"
    printf '"hardwareDevices":%s,' "$(json_array "${hardware_devices[@]}")"
    printf '"defaultSink":"%s",' "$(json_escape "$default_sink")"
    printf '"preferredCodec":"%s",' "$(json_escape "$preferred_codec")"
    printf '"nvidia":%s,' "$(is_nvidia_gpu && printf true || printf false)"
    printf '"vaapiAvailable":%s,' "$(printf '%s\n' "${video_codecs[@]}" | grep -q '_vaapi$' && printf true || printf false)"
    printf '"nvencAvailable":%s' "$(printf '%s\n' "${video_codecs[@]}" | grep -q '_nvenc$' && printf true || printf false)"
    printf '}\n'
}

getaudiooutput() {
    local default_sink
    default_sink="$(pactl get-default-sink 2>/dev/null)"
    if [[ -n "$default_sink" && "$default_sink" != "null" ]]; then
        printf '%s.monitor\n' "$default_sink"
        return
    fi

    pactl info 2>/dev/null | sed -n 's/^Default Sink: //p' | head -n 1 | awk 'NF { print $0 ".monitor"; found=1; exit } END { if (!found) exit 1 }'
    if [[ $? -eq 0 ]]; then
        return
    fi

    pactl list sources short 2>/dev/null | awk '/monitor/ { print $2; exit }'
}

resolve_audio_device() {
    if [[ -n "$AUDIO_SOURCE" && "$AUDIO_SOURCE" != "null" ]]; then
        printf '%s\n' "$AUDIO_SOURCE"
        return
    fi
    getaudiooutput
}

getactivemonitor() {
    if command -v niri >/dev/null 2>&1 && niri msg focused-output >/dev/null 2>&1; then
        niri msg focused-output | head -n 1 | sed -n 's/.*(\(.*\))/\1/p'
    elif command -v hyprctl >/dev/null 2>&1; then
        hyprctl monitors -j | jq -r '.[] | select(.focused) | .name'
    fi
}

has_ffmpeg_encoder() {
    local encoder="$1"
    ffmpeg -hide_banner -encoders 2>/dev/null | awk '{print $2}' | grep -Fxq "$encoder"
}

detect_hw_video_codec() {
    # Nvidia: skip VAAPI (unreliable even if ffmpeg lists it), go straight to NVENC
    if is_nvidia_gpu; then
        if has_ffmpeg_encoder h264_nvenc; then
            printf '%s\n' 'h264_nvenc'
            return
        fi
        if has_ffmpeg_encoder hevc_nvenc; then
            printf '%s\n' 'hevc_nvenc'
            return
        fi
    fi
    # AMD/Intel: try VAAPI (needs render device)
    if [[ -n "$HARDWARE_DEVICE" && -c "$HARDWARE_DEVICE" ]]; then
        if has_ffmpeg_encoder h264_vaapi; then
            printf '%s\n' 'h264_vaapi'
            return
        fi
        if has_ffmpeg_encoder hevc_vaapi; then
            printf '%s\n' 'hevc_vaapi'
            return
        fi
    fi
    # Fallback: try NVENC anyway (hybrid GPU setups)
    if has_ffmpeg_encoder h264_nvenc; then
        printf '%s\n' 'h264_nvenc'
        return
    fi
    printf '%s\n' 'libx264'
}

is_default_recorder_value() {
    local value="$1"
    local default_value="$2"
    [[ -z "$value" || "$value" == "null" || "$value" == "$default_value" ]]
}

build_common_args() {
    common_args=(
        -f "$output_file"
        -t
        -r "$FPS"
    )

    if is_vaapi_codec "$VIDEO_CODEC"; then
        common_args+=(
            -c "$VIDEO_CODEC"
        )
        [[ -n "$HARDWARE_DEVICE" ]] && common_args+=( -d "$HARDWARE_DEVICE" )
        [[ -n "$VAAPI_FILTER" ]] && common_args+=( -F "$VAAPI_FILTER" )
        if [[ -n "$VIDEO_BITRATE_KBPS" ]]; then
            common_args+=( -p "b=${VIDEO_BITRATE_KBPS}k" )
        fi
    elif is_nvenc_codec "$VIDEO_CODEC"; then
        common_args+=( -c "$VIDEO_CODEC" )
        if [[ -n "$VIDEO_BITRATE_KBPS" ]]; then
            common_args+=( -p "b=${VIDEO_BITRATE_KBPS}k" )
        fi
    else
        common_args+=( --pixel-format "$PIXEL_FORMAT" )
        common_args+=( -c "$VIDEO_CODEC" )
        if [[ -n "$VIDEO_BITRATE_KBPS" ]]; then
            common_args+=( -p "b=${VIDEO_BITRATE_KBPS}k" )
        fi
        if [[ "$VIDEO_CODEC" == libx264* || "$VIDEO_CODEC" == libx265* ]]; then
            [[ -n "$VIDEO_PRESET" ]] && common_args+=( -p "preset=${VIDEO_PRESET}" )
            [[ -n "$VIDEO_CRF" ]] && common_args+=( -p "crf=${VIDEO_CRF}" )
        fi
    fi
}

build_audio_args() {
    audio_args=()
    if [[ $SOUND_FLAG -ne 1 ]]; then
        return
    fi

    local audio_device
    audio_device="$(resolve_audio_device)"
    if [[ -n "$audio_device" ]]; then
        audio_args+=( --audio="$audio_device" )
    else
        audio_args+=( --audio )
    fi

    [[ -n "$AUDIO_BACKEND" ]] && audio_args+=( --audio-backend="$AUDIO_BACKEND" )
    [[ -n "$AUDIO_CODEC" ]] && audio_args+=( -C "$AUDIO_CODEC" )
    [[ -n "$AUDIO_BITRATE_KBPS" ]] && audio_args+=( -P "b=${AUDIO_BITRATE_KBPS}k" )
    audio_args+=( -R "$AUDIO_SAMPLE_RATE" )
}

build_safe_fallback_common_args() {
    fallback_common_args=(
        --pixel-format yuv420p
        -f "$output_file"
        -t
        -r "$FPS"
    )
}

start_recording_command() {
    local geometry="$1"
    local output_name="$2"
    local -a preferred_cmd=(wf-recorder)
    local -a fallback_cmd=(wf-recorder)

    if [[ -n "$geometry" ]]; then
        preferred_cmd+=(--geometry "$geometry")
        fallback_cmd+=(--geometry "$geometry")
    else
        preferred_cmd+=(-o "$(getactivemonitor)")
        fallback_cmd+=(-o "$(getactivemonitor)")
    fi

    preferred_cmd+=("${common_args[@]}" "${audio_args[@]}")
    fallback_cmd+=("${fallback_common_args[@]}")
    if [[ $SOUND_FLAG -eq 1 ]]; then
        local fallback_audio_device
        fallback_audio_device="$(resolve_audio_device)"
        if [[ -n "$fallback_audio_device" ]]; then
            fallback_cmd+=(--audio="$fallback_audio_device")
        else
            fallback_cmd+=(--audio)
        fi
        [[ -n "$AUDIO_BACKEND" ]] && fallback_cmd+=(--audio-backend="$AUDIO_BACKEND")
        [[ -n "$AUDIO_CODEC" ]] && fallback_cmd+=(-C "$AUDIO_CODEC")
        [[ -n "$AUDIO_BITRATE_KBPS" ]] && fallback_cmd+=(-P "b=${AUDIO_BITRATE_KBPS}k")
        fallback_cmd+=(-R "$AUDIO_SAMPLE_RATE")
    fi

    notify-send "Starting recording" "$output_name" -a 'Recorder' & disown
    if ! "${preferred_cmd[@]}"; then
        if is_truthy "$ENABLE_FALLBACK"; then
            notify-send "Recording fallback" "Preferred encoder failed, retrying with safe mode" -a 'Recorder' & disown
            "${fallback_cmd[@]}"
        else
            return 1
        fi
    fi
}

# Try to get save path from config, fallback to XDG Videos
CONFIG_FILE="$(inir_config_file)"
SAVE_PATH=""
QUALITY_PRESET="balanced"
VIDEO_CODEC=""
AUDIO_CODEC="aac"
ACCELERATION_MODE="auto"
HARDWARE_DEVICE="/dev/dri/renderD128"
FPS="60"
VIDEO_BITRATE_KBPS="12000"
AUDIO_BITRATE_KBPS="192"
AUDIO_SOURCE=""
AUDIO_BACKEND=""
AUDIO_SAMPLE_RATE="48000"
PIXEL_FORMAT="yuv420p"
VIDEO_PRESET="veryfast"
VIDEO_CRF="21"
VAAPI_FILTER="scale_vaapi=format=nv12:out_range=full"
ENABLE_FALLBACK="true"
if [[ -f "$CONFIG_FILE" ]] && command -v jq >/dev/null 2>&1; then
    SAVE_PATH=$(jq -r '.screenRecord.savePath // empty' "$CONFIG_FILE" 2>/dev/null)
    QUALITY_PRESET=$(jq -r '.screenRecord.qualityPreset // "balanced"' "$CONFIG_FILE" 2>/dev/null)
    VIDEO_CODEC=$(jq -r '.screenRecord.videoCodec // empty' "$CONFIG_FILE" 2>/dev/null)
    AUDIO_CODEC=$(jq -r '.screenRecord.audioCodec // "aac"' "$CONFIG_FILE" 2>/dev/null)
    ACCELERATION_MODE=$(jq -r '.screenRecord.accelerationMode // "auto"' "$CONFIG_FILE" 2>/dev/null)
    HARDWARE_DEVICE=$(jq -r '.screenRecord.hardwareDevice // "/dev/dri/renderD128"' "$CONFIG_FILE" 2>/dev/null)
    FPS=$(jq -r '.screenRecord.fps // 60' "$CONFIG_FILE" 2>/dev/null)
    VIDEO_BITRATE_KBPS=$(jq -r '.screenRecord.videoBitrateKbps // 12000' "$CONFIG_FILE" 2>/dev/null)
    AUDIO_BITRATE_KBPS=$(jq -r '.screenRecord.audioBitrateKbps // 192' "$CONFIG_FILE" 2>/dev/null)
    AUDIO_SOURCE=$(jq -r '.screenRecord.audioSource // empty' "$CONFIG_FILE" 2>/dev/null)
    AUDIO_BACKEND=$(jq -r '.screenRecord.audioBackend // empty' "$CONFIG_FILE" 2>/dev/null)
    AUDIO_SAMPLE_RATE=$(jq -r '.screenRecord.audioSampleRate // 48000' "$CONFIG_FILE" 2>/dev/null)
    PIXEL_FORMAT=$(jq -r '.screenRecord.pixelFormat // "yuv420p"' "$CONFIG_FILE" 2>/dev/null)
    VIDEO_PRESET=$(jq -r '.screenRecord.preset // "veryfast"' "$CONFIG_FILE" 2>/dev/null)
    VIDEO_CRF=$(jq -r '.screenRecord.crf // 21' "$CONFIG_FILE" 2>/dev/null)
    VAAPI_FILTER=$(jq -r '.screenRecord.vaapiFilter // "scale_vaapi=format=nv12:out_range=full"' "$CONFIG_FILE" 2>/dev/null)
    ENABLE_FALLBACK=$(jq -r '.screenRecord.enableFallback // true' "$CONFIG_FILE" 2>/dev/null)
fi

HARDWARE_DEVICE="$(resolve_hardware_device "$HARDWARE_DEVICE")"

if printf '%s\n' "$*" | grep -q -- '--probe-capabilities'; then
    probe_capabilities "$HARDWARE_DEVICE"
    exit 0
fi

if [[ "$ACCELERATION_MODE" == "gpu" ]]; then
    if is_default_recorder_value "$VIDEO_CODEC" "libx264"; then
        VIDEO_CODEC="$(detect_hw_video_codec)"
    fi
elif [[ "$ACCELERATION_MODE" == "software" ]]; then
    if is_default_recorder_value "$VIDEO_CODEC" "libx264" || is_hw_codec "$VIDEO_CODEC"; then
        VIDEO_CODEC="libx264"
    fi
elif is_default_recorder_value "$VIDEO_CODEC" "libx264"; then
    VIDEO_CODEC="$(detect_hw_video_codec)"
fi

if is_vaapi_codec "$VIDEO_CODEC"; then
    PIXEL_FORMAT="yuv420p"
    if is_default_recorder_value "$VIDEO_BITRATE_KBPS" "12000"; then
        VIDEO_BITRATE_KBPS="18000"
    fi
fi

if is_nvenc_codec "$VIDEO_CODEC"; then
    if is_default_recorder_value "$VIDEO_BITRATE_KBPS" "12000"; then
        VIDEO_BITRATE_KBPS="18000"
    fi
fi

# Fallback to XDG Videos if config path is empty
if [[ -z "$SAVE_PATH" ]]; then
    xdgvideo="$(xdg-user-dir VIDEOS)"
    if [[ $xdgvideo = "$HOME" ]]; then
        SAVE_PATH="$HOME/Videos"
    else
        SAVE_PATH="$xdgvideo"
    fi
fi

mkdir -p "$SAVE_PATH"
cd "$SAVE_PATH" || exit

# parse --region <value> without modifying $@ so other flags like --fullscreen still work
ARGS=("$@")
MANUAL_REGION=""
SOUND_FLAG=0
FULLSCREEN_FLAG=0
for ((i=0;i<${#ARGS[@]};i++)); do
    if [[ "${ARGS[i]}" == "--region" ]]; then
        if (( i+1 < ${#ARGS[@]} )); then
            MANUAL_REGION="${ARGS[i+1]}"
        else
            notify-send "Recording cancelled" "No region specified for --region" -a 'Recorder' & disown
            exit 1
        fi
    elif [[ "${ARGS[i]}" == "--sound" ]]; then
        SOUND_FLAG=1
    elif [[ "${ARGS[i]}" == "--fullscreen" ]]; then
        FULLSCREEN_FLAG=1
    fi
done

if pgrep wf-recorder > /dev/null; then
    notify-send "Recording Stopped" "Stopped" -a 'Recorder' &
    pkill wf-recorder &
else
    timestamp="$(getdate)"
    output_file="./recording_${timestamp}.mp4"
    output_name="recording_${timestamp}.mp4"
    build_common_args
    build_audio_args
    build_safe_fallback_common_args
    if [[ $FULLSCREEN_FLAG -eq 1 ]]; then
        start_recording_command "" "$output_name"
    else
        # If a manual region was provided via --region, use it; otherwise run slurp as before.
        if [[ -n "$MANUAL_REGION" ]]; then
            region="$MANUAL_REGION"
        else
            if ! region="$(slurp 2>&1)"; then
                notify-send "Recording cancelled" "Selection was cancelled" -a 'Recorder' & disown
                exit 1
            fi
        fi

        start_recording_command "$region" "$output_name"
    fi
fi
