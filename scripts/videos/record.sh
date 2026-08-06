#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/config-path.sh
source "$SCRIPT_DIR/../lib/config-path.sh"
if ! command -v wf-recorder >/dev/null 2>&1 || ! command -v ffmpeg >/dev/null 2>&1; then
    notify-send "Recording failed" "Missing dependencies: wf-recorder or ffmpeg is not installed." -a 'Recorder' & disown
    exit 1
fi
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

normalize_acceleration_mode() {
    case "$1" in
        cpu|software) printf '%s\n' "software" ;;
        gpu|hardware) printf '%s\n' "gpu" ;;
        *) printf '%s\n' "auto" ;;
    esac
}

normalize_audio_mode() {
    case "$1" in
        none|off|silent) printf '%s\n' "none" ;;
        microphone|mic|input) printf '%s\n' "microphone" ;;
        both|mix|mixed) printf '%s\n' "both" ;;
        *) printf '%s\n' "system" ;;
    esac
}

audio_mode_description() {
    case "$1" in
        none) printf '%s\n' "No audio" ;;
        microphone) printf '%s\n' "Microphone" ;;
        both) printf '%s\n' "System + microphone" ;;
        *) printf '%s\n' "System audio" ;;
    esac
}

determine_active_audio_mode() {
    if [[ ${SOUND_FLAG:-0} -ne 1 || -z "${AUDIO_CAPTURE_DEVICE:-}" ]]; then
        printf '%s\n' "none"
    elif [[ "$AUDIO_CAPTURE_DEVICE" == "${MIX_SINK_PREFIX:-inir_recorder_mix_}"*.monitor ]]; then
        printf '%s\n' "both"
    elif [[ "$AUDIO_CAPTURE_DEVICE" == *.monitor ]]; then
        printf '%s\n' "system"
    else
        printf '%s\n' "microphone"
    fi
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

write_recorder_status() {
    local recorder_pid="$1"
    local fallback=false
    local tmp_file="${RECORDER_STATUS_FILE}.tmp.$$"

    [[ "$ACTIVE_AUDIO_MODE" != "$AUDIO_MODE" ]] && fallback=true
    if printf '{"recorderPid":%s,"requestedAudioMode":"%s","activeAudioMode":"%s","audioFallback":%s,"audioSource":"%s"}\n' \
        "$recorder_pid" \
        "$(json_escape "$AUDIO_MODE")" \
        "$(json_escape "$ACTIVE_AUDIO_MODE")" \
        "$fallback" \
        "$(json_escape "$AUDIO_CAPTURE_DEVICE")" > "$tmp_file" \
        && mv "$tmp_file" "$RECORDER_STATUS_FILE"; then
        OWNS_RECORDER_STATUS=1
    else
        rm -f "$tmp_file" 2>/dev/null || true
    fi
    return 0
}

cleanup_recorder_status() {
    if [[ ${OWNS_RECORDER_STATUS:-0} -eq 1 ]]; then
        rm -f "$RECORDER_STATUS_FILE" "${RECORDER_STATUS_FILE}.tmp.$$" 2>/dev/null || true
        OWNS_RECORDER_STATUS=0
    fi
}

cleanup_recorder_session() {
    cleanup_audio_mix
    cleanup_recorder_status
}

config_value() {
    local expr="$1"
    local fallback="${2:-}"
    local value
    value="$(jq -r "$expr" "$CONFIG_FILE" 2>/dev/null || true)"
    if [[ -z "$value" || "$value" == "null" ]]; then
        printf '%s\n' "$fallback"
    else
        printf '%s\n' "$value"
    fi
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
    return 0
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
    pactl list sources short 2>/dev/null | awk 'NF >= 2 { print $2 }' || true
}

collect_hardware_devices() {
    local device
    for device in /dev/dri/renderD*; do
        [[ -c "$device" ]] && printf '%s\n' "$device"
    done
    return 0
}

# Preconditions for a system+microphone mix, checked without touching the live
# audio graph. Loading a probe sink and loopbacks to answer a yes/no question
# mutates the user's PipeWire session on every Settings open, and it cannot
# prevent a failure that create_audio_mix() already handles: the real load
# falls back to a single source and notifies.
probe_audio_mix_support() {
    local system_source="$1"
    local microphone_source="$2"

    command -v pactl >/dev/null 2>&1 || return 1
    pactl info >/dev/null 2>&1 || return 1
    audio_source_exists "$system_source" || return 1
    audio_source_exists "$microphone_source" || return 1
    return 0
}

probe_capabilities() {
    local resolved_device="$1"
    local default_sink default_source system_source microphone_source mix_available
    default_sink="$(pactl get-default-sink 2>/dev/null || true)"
    default_source="$(pactl get-default-source 2>/dev/null || true)"
    system_source="$(resolve_system_audio_device)"
    microphone_source="$(resolve_microphone_device)"
    mix_available=false
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

    if probe_audio_mix_support "$system_source" "$microphone_source"; then
        mix_available=true
    fi

    printf '{'
    printf '"videoCodecs":%s,' "$(json_array "${video_codecs[@]}")"
    printf '"audioCodecs":%s,' "$(json_array "${audio_codecs[@]}")"
    printf '"audioSources":%s,' "$(json_array "${audio_sources[@]}")"
    printf '"hardwareDevices":%s,' "$(json_array "${hardware_devices[@]}")"
    printf '"defaultSink":"%s",' "$(json_escape "$default_sink")"
    printf '"defaultSource":"%s",' "$(json_escape "$default_source")"
    printf '"audioMixAvailable":%s,' "$mix_available"
    printf '"preferredCodec":"%s",' "$(json_escape "$preferred_codec")"
    printf '"nvidia":%s,' "$(is_nvidia_gpu && printf true || printf false)"
    printf '"vaapiAvailable":%s,' "$(printf '%s\n' "${video_codecs[@]}" | grep -q '_vaapi$' && printf true || printf false)"
    printf '"nvencAvailable":%s' "$(printf '%s\n' "${video_codecs[@]}" | grep -q '_nvenc$' && printf true || printf false)"
    printf '}\n'
}

getaudiooutput() {
    local default_sink
    default_sink="$(pactl get-default-sink 2>/dev/null || true)"
    if [[ -n "$default_sink" && "$default_sink" != "null" ]]; then
        printf '%s.monitor\n' "$default_sink"
        return
    fi

    if pactl info 2>/dev/null | sed -n 's/^Default Sink: //p' | head -n 1 | awk 'NF { print $0 ".monitor"; found=1; exit } END { if (!found) exit 1 }'; then
        return
    fi

    pactl list sources short 2>/dev/null | awk '/monitor/ { print $2; exit }' || true
}

getmicrophoneinput() {
    local default_source
    default_source="$(pactl get-default-source 2>/dev/null || true)"
    if [[ -n "$default_source" && "$default_source" != "null" && "$default_source" != *.monitor ]]; then
        printf '%s\n' "$default_source"
        return
    fi

    pactl list sources short 2>/dev/null | awk '$2 !~ /\.monitor$/ { print $2; exit }' || true
}

resolve_system_audio_device() {
    if [[ "$SYSTEM_AUDIO_SOURCE_CONFIGURED" == true ]]; then
        if [[ -n "$SYSTEM_AUDIO_SOURCE" && "$SYSTEM_AUDIO_SOURCE" != "null" ]]; then
            printf '%s\n' "$SYSTEM_AUDIO_SOURCE"
        else
            getaudiooutput
        fi
        return
    fi
    if [[ -n "$AUDIO_SOURCE" && "$AUDIO_SOURCE" == *.monitor ]]; then
        printf '%s\n' "$AUDIO_SOURCE"
        return
    fi
    getaudiooutput
}

resolve_microphone_device() {
    if [[ "$MICROPHONE_SOURCE_CONFIGURED" == true ]]; then
        if [[ -n "$MICROPHONE_SOURCE" && "$MICROPHONE_SOURCE" != "null" ]]; then
            printf '%s\n' "$MICROPHONE_SOURCE"
        else
            getmicrophoneinput
        fi
        return
    fi
    if [[ -n "$AUDIO_SOURCE" && "$AUDIO_SOURCE" != *.monitor ]]; then
        printf '%s\n' "$AUDIO_SOURCE"
        return
    fi
    getmicrophoneinput
}

audio_source_exists() {
    local source_name="$1"
    [[ -n "$source_name" ]] || return 1
    pactl list sources short 2>/dev/null | awk -v source_name="$source_name" '$2 == source_name { found=1 } END { exit(found ? 0 : 1) }'
}

notify_audio_fallback() {
    local message="$1"
    if is_truthy "$SHOW_NOTIFICATIONS"; then
        notify-send "Recorder audio fallback" "$message" -a 'Recorder' & disown
    fi
}

cleanup_audio_mix() {
    local module_id
    for module_id in "$MIX_MIC_MODULE" "$MIX_SYSTEM_MODULE" "$MIX_SINK_MODULE"; do
        if [[ -n "$module_id" ]]; then
            pactl unload-module "$module_id" >/dev/null 2>&1 || true
        fi
    done
    MIX_MIC_MODULE=""
    MIX_SYSTEM_MODULE=""
    MIX_SINK_MODULE=""
    MIX_SINK_NAME=""
}

cleanup_stale_audio_mix() {
    local module_id
    while read -r module_id; do
        [[ -n "$module_id" ]] && pactl unload-module "$module_id" >/dev/null 2>&1 || true
    done < <(pactl list modules short 2>/dev/null | awk -v prefix="$MIX_SINK_PREFIX" 'index($0, prefix) { print $1 }' | sort -rn)
}

# A null sink fed by two loopbacks. wf-recorder takes a single --audio device,
# so mixing has to happen in the audio graph, and this is the only shape that
# actually carries signal here: libpipewire-module-combine-stream builds the
# node with one module and no phantom sink, but its combined source records as
# digital silence on PipeWire 1.6.8 (combine.mode=source segfaults outright).
# The sink is visible to other apps while recording; that is the cost.
create_audio_mix() {
    local system_source microphone_source
    system_source="$(resolve_system_audio_device)"
    microphone_source="$(resolve_microphone_device)"

    if ! audio_source_exists "$system_source" || ! audio_source_exists "$microphone_source"; then
        return 1
    fi

    cleanup_stale_audio_mix
    MIX_SINK_NAME="${MIX_SINK_PREFIX}${UID}_$$"
    MIX_SINK_MODULE="$(pactl load-module module-null-sink \
        "sink_name=$MIX_SINK_NAME" \
        "rate=$AUDIO_SAMPLE_RATE" \
        "channels=2" \
        "channel_map=front-left,front-right" \
        "sink_properties=device.description=iNiR_Recorder_Mix" 2>/dev/null || true)"
    if [[ -z "$MIX_SINK_MODULE" ]]; then
        cleanup_audio_mix
        return 1
    fi

    MIX_SYSTEM_MODULE="$(pactl load-module module-loopback \
        "source=$system_source" \
        "sink=$MIX_SINK_NAME" \
        "latency_msec=20" \
        "remix=yes" 2>/dev/null || true)"
    if [[ -z "$MIX_SYSTEM_MODULE" ]]; then
        cleanup_audio_mix
        return 1
    fi

    MIX_MIC_MODULE="$(pactl load-module module-loopback \
        "source=$microphone_source" \
        "sink=$MIX_SINK_NAME" \
        "latency_msec=20" \
        "remix=yes" 2>/dev/null || true)"
    if [[ -z "$MIX_MIC_MODULE" ]]; then
        cleanup_audio_mix
        return 1
    fi

    local mixed_source="${MIX_SINK_NAME}.monitor"
    local attempt
    for attempt in {1..20}; do
        if audio_source_exists "$mixed_source"; then
            AUDIO_CAPTURE_DEVICE="$mixed_source"
            return 0
        fi
        sleep 0.05
    done

    cleanup_audio_mix
    return 1
}

prepare_audio_capture() {
    AUDIO_CAPTURE_DEVICE=""
    if [[ $SOUND_FLAG -ne 1 || "$AUDIO_MODE" == "none" ]]; then
        SOUND_FLAG=0
        return 0
    fi

    case "$AUDIO_MODE" in
        system)
            AUDIO_CAPTURE_DEVICE="$(resolve_system_audio_device)"
            ;;
        microphone)
            AUDIO_CAPTURE_DEVICE="$(resolve_microphone_device)"
            ;;
        both)
            if create_audio_mix; then
                return 0
            fi
            AUDIO_CAPTURE_DEVICE="$(resolve_system_audio_device)"
            if audio_source_exists "$AUDIO_CAPTURE_DEVICE"; then
                notify_audio_fallback "Could not mix microphone and desktop audio. Recording desktop audio only."
                return 0
            fi
            AUDIO_CAPTURE_DEVICE="$(resolve_microphone_device)"
            if audio_source_exists "$AUDIO_CAPTURE_DEVICE"; then
                notify_audio_fallback "Could not mix microphone and desktop audio. Recording microphone only."
                return 0
            fi
            ;;
    esac

    if ! audio_source_exists "$AUDIO_CAPTURE_DEVICE"; then
        notify_audio_fallback "The selected audio source is unavailable. Recording video without audio."
        AUDIO_CAPTURE_DEVICE=""
        SOUND_FLAG=0
    fi
}

getactivemonitor() {
    if command -v niri >/dev/null 2>&1 && niri msg focused-output >/dev/null 2>&1; then
        niri msg focused-output 2>/dev/null | head -n 1 | sed -n 's/.*(\(.*\))/\1/p' || true
    elif command -v hyprctl >/dev/null 2>&1; then
        hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name' || true
    fi
}

maybe_compress_recording() {
    local input_file="$1"
    if ! is_truthy "$DISCORD_COMPRESS_ENABLED"; then
        return 0
    fi
    if [[ ! -s "$input_file" ]]; then
        return 0
    fi

    local compressor="$SCRIPT_DIR/compress-discord.py"
    local python_cmd=""
    if command -v python3 >/dev/null 2>&1; then
        python_cmd="$(command -v python3)"
    fi
    if [[ -z "$python_cmd" || ! -f "$compressor" ]] || ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ffprobe >/dev/null 2>&1; then
        if is_truthy "$SHOW_NOTIFICATIONS"; then notify-send "Discord compression skipped" "Missing python3, ffmpeg, or ffprobe" -a 'Recorder' & disown; fi
        return 0
    fi

    local input_dir input_base input_stem output_file
    input_dir="$(dirname "$input_file")"
    input_base="$(basename "$input_file")"
    input_stem="${input_base%.*}"
    output_file="$input_dir/${input_stem}.discord.mp4"
    local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/inir"
    local lock_file="$cache_dir/discord-compress.lock"
    mkdir -p "$cache_dir"

    (
        if command -v flock >/dev/null 2>&1; then
            exec 9>"$lock_file"
            if ! flock -n 9; then
                if is_truthy "$SHOW_NOTIFICATIONS"; then notify-send "Discord compression queued" "Another recording is already compressing" -a 'Recorder' & disown; fi
                flock 9
            fi
        fi

        if is_truthy "$SHOW_NOTIFICATIONS"; then notify-send "Compressing recording" "Creating Discord-ready copy under ${DISCORD_COMPRESS_TARGET_MB} MB" -a 'Recorder' & disown; fi

        local -a compress_cmd=(
            "$python_cmd" "$compressor"
            --input "$input_file"
            --output "$output_file"
            --target-mb "$DISCORD_COMPRESS_TARGET_MB"
            --safety-margin-mb "$DISCORD_COMPRESS_SAFETY_MARGIN_MB"
            --audio-kbps "$DISCORD_COMPRESS_AUDIO_BITRATE_KBPS"
            --preset "$DISCORD_COMPRESS_PRESET"
            --max-dimension "$DISCORD_COMPRESS_MAX_DIMENSION"
            --quiet
            --json
        )
        if ! is_truthy "$DISCORD_COMPRESS_ONLY_IF_NEEDED"; then
            compress_cmd+=(--force)
        fi

        local result=""
        if result="$("${compress_cmd[@]}" 2>&1)"; then
            local status=""
            local result_output="$output_file"
            if command -v jq >/dev/null 2>&1; then
                status="$(printf '%s' "$result" | jq -r '.status // empty' 2>/dev/null || true)"
                result_output="$(printf '%s' "$result" | jq -r '.output // empty' 2>/dev/null || printf '%s' "$output_file")"
            fi
            if [[ "$status" == "skipped" ]]; then
                if is_truthy "$SHOW_NOTIFICATIONS"; then notify-send "Recording already Discord-ready" "$(basename "$input_file") is under ${DISCORD_COMPRESS_TARGET_MB} MB" -a 'Recorder' & disown; fi
            elif [[ -s "$result_output" ]]; then
                if is_truthy "$SHOW_NOTIFICATIONS"; then notify-send "Discord-ready recording" "$(basename "$result_output")" -a 'Recorder' & disown; fi
            elif is_truthy "$SHOW_NOTIFICATIONS"; then
                notify-send "Discord compression finished" "$(basename "$input_file")" -a 'Recorder' & disown
            fi
        else
            if is_truthy "$SHOW_NOTIFICATIONS"; then notify-send "Discord compression failed" "Original recording was kept. Obviously." -a 'Recorder' & disown; fi
        fi
    )
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

    if [[ -n "$AUDIO_CAPTURE_DEVICE" ]]; then
        audio_args+=( --audio="$AUDIO_CAPTURE_DEVICE" )
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
    if has_ffmpeg_encoder libx264; then
        fallback_common_args+=(
            -c libx264
            -p preset=veryfast
            -p crf=23
        )
    fi
}

run_recorder_process() {
    local -a recorder_cmd=("$@")
    local recorder_pid status

    rm -f "$RECORDER_STOP_FILE"
    "${recorder_cmd[@]}" &
    recorder_pid=$!
    printf '%s\n' "$recorder_pid" > "$RECORDER_PID_FILE"
    write_recorder_status "$recorder_pid"

    set +e
    wait "$recorder_pid"
    status=$?
    set -e

    if [[ "$(cat "$RECORDER_PID_FILE" 2>/dev/null || true)" == "$recorder_pid" ]]; then
        rm -f "$RECORDER_PID_FILE"
    fi
    if [[ -f "$RECORDER_STOP_FILE" ]]; then
        rm -f "$RECORDER_STOP_FILE"
        return 0
    fi
    if [[ $status -eq 130 || $status -eq 143 ]]; then
        return 0
    fi
    return "$status"
}

stop_running_recorder() {
    local recorder_pid=""
    recorder_pid="$(cat "$RECORDER_PID_FILE" 2>/dev/null || true)"
    if [[ "$recorder_pid" =~ ^[0-9]+$ ]] && kill -0 "$recorder_pid" 2>/dev/null; then
        if [[ "$(cat "/proc/$recorder_pid/comm" 2>/dev/null || true)" == "wf-recorder" ]]; then
            : > "$RECORDER_STOP_FILE"
            kill -SIGINT "$recorder_pid" 2>/dev/null || true
            return 0
        fi
    fi

    rm -f "$RECORDER_PID_FILE" "$RECORDER_STOP_FILE"
    if pgrep -x wf-recorder >/dev/null 2>&1; then
        pkill -SIGINT -x wf-recorder 2>/dev/null || true
        return 0
    fi
    return 1
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
        if [[ -n "$AUDIO_CAPTURE_DEVICE" ]]; then
            fallback_cmd+=(--audio="$AUDIO_CAPTURE_DEVICE")
        else
            fallback_cmd+=(--audio)
        fi
        [[ -n "$AUDIO_BACKEND" ]] && fallback_cmd+=(--audio-backend="$AUDIO_BACKEND")
        [[ -n "$AUDIO_CODEC" ]] && fallback_cmd+=(-C "$AUDIO_CODEC")
        [[ -n "$AUDIO_BITRATE_KBPS" ]] && fallback_cmd+=(-P "b=${AUDIO_BITRATE_KBPS}k")
        fallback_cmd+=(-R "$AUDIO_SAMPLE_RATE")
    fi

    if is_truthy "$SHOW_NOTIFICATIONS"; then
        notify-send "Starting recording" "$output_name — $(audio_mode_description "$AUDIO_MODE")" -a 'Recorder' & disown
    fi
    if ! run_recorder_process "${preferred_cmd[@]}"; then
        if is_truthy "$ENABLE_FALLBACK"; then
            if is_truthy "$SHOW_NOTIFICATIONS"; then notify-send "Recording fallback" "Preferred encoder failed, retrying with safe mode" -a 'Recorder' & disown; fi
            run_recorder_process "${fallback_cmd[@]}"
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
AUDIO_MODE="system"
AUDIO_MODE_CONFIGURED=false
AUDIO_SOURCE=""
SYSTEM_AUDIO_SOURCE=""
SYSTEM_AUDIO_SOURCE_CONFIGURED=false
MICROPHONE_SOURCE=""
MICROPHONE_SOURCE_CONFIGURED=false
AUDIO_CAPTURE_DEVICE=""
ACTIVE_AUDIO_MODE="none"
AUDIO_BACKEND=""
AUDIO_SAMPLE_RATE="48000"
MIX_SINK_PREFIX="inir_recorder_mix_"
MIX_SINK_NAME=""
MIX_SINK_MODULE=""
MIX_SYSTEM_MODULE=""
MIX_MIC_MODULE=""
PIXEL_FORMAT="yuv420p"
VIDEO_PRESET="veryfast"
VIDEO_CRF="21"
VAAPI_FILTER="scale_vaapi=format=nv12:out_range=full"
ENABLE_FALLBACK="true"
SHOW_NOTIFICATIONS="true"
RECORDING_NAME_FORMAT="recording_%Y-%m-%d_%H.%M.%S"
DISCORD_COMPRESS_ENABLED="false"
DISCORD_COMPRESS_TARGET_MB="10"
DISCORD_COMPRESS_SAFETY_MARGIN_MB="0.5"
DISCORD_COMPRESS_ONLY_IF_NEEDED="true"
DISCORD_COMPRESS_AUDIO_BITRATE_KBPS="96"
DISCORD_COMPRESS_PRESET="slow"
DISCORD_COMPRESS_MAX_DIMENSION="1280"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/inir"
RECORDER_PID_FILE="$STATE_DIR/recorder.pid"
RECORDER_STOP_FILE="$STATE_DIR/recorder.stop"
RECORDER_STATUS_FILE="$STATE_DIR/recorder-status.json"
OWNS_RECORDER_STATUS=0
mkdir -p "$STATE_DIR"
trap cleanup_recorder_session EXIT
if [[ -f "$CONFIG_FILE" ]] && command -v jq >/dev/null 2>&1; then
    SAVE_PATH=$(config_value '.screenRecord.savePath // empty')
    QUALITY_PRESET=$(config_value '.screenRecord.qualityPreset // "balanced"' "balanced")
    VIDEO_CODEC=$(config_value '.screenRecord.videoCodec // empty')
    AUDIO_CODEC=$(config_value '.screenRecord.audioCodec // "aac"' "aac")
    ACCELERATION_MODE=$(config_value '.screenRecord.accelerationMode // "auto"' "auto")
    HARDWARE_DEVICE=$(config_value '.screenRecord.hardwareDevice // "/dev/dri/renderD128"' "/dev/dri/renderD128")
    FPS=$(config_value '.screenRecord.fps // 60' "60")
    VIDEO_BITRATE_KBPS=$(config_value '.screenRecord.videoBitrateKbps // 12000' "12000")
    AUDIO_BITRATE_KBPS=$(config_value '.screenRecord.audioBitrateKbps // 192' "192")
    if jq -e '.screenRecord | has("audioMode")' "$CONFIG_FILE" >/dev/null 2>&1; then
        AUDIO_MODE=$(config_value '.screenRecord.audioMode // "system"' "system")
        AUDIO_MODE_CONFIGURED=true
    fi
    AUDIO_SOURCE=$(config_value '.screenRecord.audioSource // empty')
    if jq -e '.screenRecord | has("systemAudioSource")' "$CONFIG_FILE" >/dev/null 2>&1; then
        SYSTEM_AUDIO_SOURCE=$(config_value '.screenRecord.systemAudioSource // empty')
        SYSTEM_AUDIO_SOURCE_CONFIGURED=true
    fi
    if jq -e '.screenRecord | has("microphoneSource")' "$CONFIG_FILE" >/dev/null 2>&1; then
        MICROPHONE_SOURCE=$(config_value '.screenRecord.microphoneSource // empty')
        MICROPHONE_SOURCE_CONFIGURED=true
    fi
    AUDIO_BACKEND=$(config_value '.screenRecord.audioBackend // empty')
    AUDIO_SAMPLE_RATE=$(config_value '.screenRecord.audioSampleRate // 48000' "48000")
    PIXEL_FORMAT=$(config_value '.screenRecord.pixelFormat // "yuv420p"' "yuv420p")
    VIDEO_PRESET=$(config_value '.screenRecord.preset // "veryfast"' "veryfast")
    VIDEO_CRF=$(config_value '.screenRecord.crf // 21' "21")
    VAAPI_FILTER=$(config_value '.screenRecord.vaapiFilter // "scale_vaapi=format=nv12:out_range=full"' "scale_vaapi=format=nv12:out_range=full")
    ENABLE_FALLBACK=$(config_value 'if .screenRecord.enableFallback == null then "true" else .screenRecord.enableFallback end' "true")
    SHOW_NOTIFICATIONS=$(config_value 'if .screenRecord.showNotifications == null then "true" else .screenRecord.showNotifications end' "true")
    RECORDING_NAME_FORMAT=$(config_value '.screenRecord.recordingNameFormat // "recording_%Y-%m-%d_%H.%M.%S"' "recording_%Y-%m-%d_%H.%M.%S")
    DISCORD_COMPRESS_ENABLED=$(config_value 'if .screenRecord.discordCompress.enabled == null then "false" else .screenRecord.discordCompress.enabled end' "false")
    DISCORD_COMPRESS_TARGET_MB=$(config_value '.screenRecord.discordCompress.targetSizeMb // 10' "10")
    DISCORD_COMPRESS_SAFETY_MARGIN_MB=$(config_value '.screenRecord.discordCompress.safetyMarginMb // 0.5' "0.5")
    DISCORD_COMPRESS_ONLY_IF_NEEDED=$(config_value 'if .screenRecord.discordCompress.onlyIfNeeded == null then "true" else .screenRecord.discordCompress.onlyIfNeeded end' "true")
    DISCORD_COMPRESS_AUDIO_BITRATE_KBPS=$(config_value '.screenRecord.discordCompress.audioBitrateKbps // 96' "96")
    DISCORD_COMPRESS_PRESET=$(config_value '.screenRecord.discordCompress.preset // "slow"' "slow")
    DISCORD_COMPRESS_MAX_DIMENSION=$(config_value '.screenRecord.discordCompress.maxDimension // 1280' "1280")
fi

HARDWARE_DEVICE="$(resolve_hardware_device "$HARDWARE_DEVICE")"
ACCELERATION_MODE="$(normalize_acceleration_mode "$ACCELERATION_MODE")"
if [[ "$AUDIO_MODE_CONFIGURED" != true && -n "$AUDIO_SOURCE" && "$AUDIO_SOURCE" != *.monitor ]]; then
    AUDIO_MODE="microphone"
fi
AUDIO_MODE="$(normalize_audio_mode "$AUDIO_MODE")"

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
    xdgvideo="$(xdg-user-dir VIDEOS 2>/dev/null || true)"
    if [[ $xdgvideo = "$HOME" ]]; then
        SAVE_PATH="$HOME/Videos"
    else
        SAVE_PATH="$xdgvideo"
    fi
fi

mkdir -p "$SAVE_PATH"
cd "$SAVE_PATH" || exit

# Parse arguments without modifying $@ so --region geometry and the other flags
# can coexist. The audio mode comes from screenRecord.audioMode in config.json.
ARGS=("$@")
MANUAL_REGION=""
SOUND_FLAG=0
FULLSCREEN_FLAG=0
STOP_ONLY=0
for ((i=0;i<${#ARGS[@]};i++)); do
    case "${ARGS[i]}" in
        --region)
            if (( i+1 < ${#ARGS[@]} )); then
                MANUAL_REGION="${ARGS[i+1]}"
                ((i+=1))
            else
                if is_truthy "$SHOW_NOTIFICATIONS"; then notify-send "Recording cancelled" "No region specified for --region" -a 'Recorder' & disown; fi
                exit 1
            fi
            ;;
        --sound)
            SOUND_FLAG=1
            ;;
        --fullscreen)
            FULLSCREEN_FLAG=1
            ;;
        --stop)
            STOP_ONLY=1
            ;;
    esac
done

# Stopping stays silent: the recording process itself notifies once the file is
# written, and two toasts a second apart for one action is noise.
if [[ $STOP_ONLY -eq 1 ]]; then
    if pgrep -x wf-recorder >/dev/null 2>&1; then
        stop_running_recorder || true
    elif is_truthy "$SHOW_NOTIFICATIONS"; then
        notify-send "Recorder" "No active recording" -a 'Recorder' & disown
    fi
    exit 0
fi

if pgrep -x wf-recorder >/dev/null 2>&1; then
    stop_running_recorder || true
    exit 0
fi

rm -f "$RECORDER_PID_FILE" "$RECORDER_STOP_FILE" "$RECORDER_STATUS_FILE"
cleanup_stale_audio_mix

output_base="$(date +"$RECORDING_NAME_FORMAT")"
output_file="./${output_base}.mp4"
output_name="${output_base}.mp4"
recording_geometry=""

if [[ $FULLSCREEN_FLAG -ne 1 ]]; then
    if [[ -n "$MANUAL_REGION" ]]; then
        recording_geometry="$MANUAL_REGION"
    else
        if ! recording_geometry="$(slurp 2>&1)"; then
            if is_truthy "$SHOW_NOTIFICATIONS"; then notify-send "Recording cancelled" "Selection was cancelled" -a 'Recorder' & disown; fi
            exit 1
        fi
    fi
fi

prepare_audio_capture
ACTIVE_AUDIO_MODE="$(determine_active_audio_mode)"
build_common_args
build_audio_args
build_safe_fallback_common_args

if start_recording_command "$recording_geometry" "$output_name"; then
    cleanup_audio_mix
    cleanup_recorder_status
    if [[ -s "$output_file" ]] && is_truthy "$SHOW_NOTIFICATIONS"; then
        notify-send "Recording saved" "${SAVE_PATH%/}/$output_name" -a 'Recorder' & disown
    fi
    maybe_compress_recording "$output_file"
    quickshell -c inir ipc call launchVideoEditor handle "${SAVE_PATH%/}/$output_name"
else
    exit $?
fi
