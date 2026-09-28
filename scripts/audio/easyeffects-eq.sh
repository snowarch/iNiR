#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
socket="${EASYEFFECTS_SERVER_SOCKET:-$runtime_dir/EasyEffectsServer}"
target_frequencies=(32 64 125 250 500 1000 2000 4000 8000 16000)
equalizer_instance=""

json_unavailable() {
    local server_available="$1"
    local plugin_available="$2"
    local supported="$3"
    local error_code="$4"
    printf '{"serverAvailable":%s,"pluginAvailable":%s,"supported":%s,"numBands":0,"splitChannels":false,"bypassed":null,"bands":[],"error":"%s"}\n' \
        "$server_available" "$plugin_available" "$supported" "$error_code"
}

if ! command -v socat >/dev/null 2>&1; then
    json_unavailable false false false "socat_missing"
    exit 0
fi

if [[ ! -S "$socket" ]]; then
    json_unavailable false false true "server_unavailable"
    exit 0
fi

send_command() {
    local command="$1"
    printf '%s\n' "$command" \
        | socat -T 1 - "UNIX-CONNECT:$socket" 2>/dev/null \
        | tr -d '\r' \
        | tail -n 1
}

easyeffects_process_is_flatpak() {
    local pid
    pid="$(pgrep -n -x easyeffects 2>/dev/null || true)"
    [[ -n "$pid" ]] || return 1
    tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null \
        | grep -Fxq 'FLATPAK_ID=com.github.wwmm.easyeffects'
}

easyeffects_config_file() {
    if easyeffects_process_is_flatpak; then
        printf '%s\n' "$HOME/.var/app/com.github.wwmm.easyeffects/config/easyeffects/db/easyeffectsrc"
        return
    fi
    printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/easyeffects/db/easyeffectsrc"
}

easyeffects_preset_dir() {
    if easyeffects_process_is_flatpak; then
        printf '%s\n' "$HOME/.var/app/com.github.wwmm.easyeffects/data/easyeffects/output"
        return
    fi
    printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/easyeffects/output"
}

output_pipeline_plugins() {
    local cfg
    cfg="$(easyeffects_config_file)"
    [[ -f "$cfg" ]] || return 1
    awk '
        /^\[StreamOutputs\]$/ { in_output=1; next }
        /^\[/ { in_output=0 }
        in_output && /^plugins=/ { sub(/^plugins=/, ""); print; found=1; exit }
        END { if (!found) print "" }
    ' "$cfg" 2>/dev/null
}

output_pipeline_is_empty() {
    local plugins
    plugins="$(output_pipeline_plugins)" || return 1
    [[ -z "${plugins//[[:space:]]/}" ]]
}

write_inir_equalizer_preset() {
    local preset_dir preset_path tmp_path
    preset_dir="$(easyeffects_preset_dir)"
    mkdir -p "$preset_dir"
    preset_path="$preset_dir/iNiR Equalizer.json"
    tmp_path="$(mktemp "$preset_dir/.inir-equalizer.XXXXXX")"
    python3 - "$tmp_path" <<'PY_PRESET'
import json, sys
frequencies = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
def side():
    return {
        f"band{i}": {
            "frequency": float(freq), "gain": 0.0, "mode": "RLC (BT)",
            "mute": False, "q": 4.36, "slope": "x1", "solo": False,
            "type": "Bell", "width": 4.0
        }
        for i, freq in enumerate(frequencies)
    }
eq = {
    "balance": 0.0, "bypass": False, "input-gain": 0.0,
    "left": side(), "mode": "IIR", "num-bands": 10,
    "output-gain": 0.0, "pitch-left": 0.0, "pitch-right": 0.0,
    "right": side(), "split-channels": False
}
preset = {"output": {"blocklist": [], "plugins_order": ["equalizer#0"], "equalizer#0": eq}}
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    json.dump(preset, fh, indent=2)
    fh.write("\n")
PY_PRESET
    chmod 600 "$tmp_path"
    mv -f "$tmp_path" "$preset_path"
}

config_equalizer_instances() {
    local -a candidates=(
        "${XDG_CONFIG_HOME:-$HOME/.config}/easyeffects/db/easyeffectsrc"
        "$HOME/.var/app/com.github.wwmm.easyeffects/config/easyeffects/db/easyeffectsrc"
    )
    local cfg plugins token
    for cfg in "${candidates[@]}"; do
        [[ -f "$cfg" ]] || continue
        plugins="$(awk '
            /^\[StreamOutputs\]$/ { in_output=1; next }
            /^\[/ { in_output=0 }
            in_output && /^plugins=/ { sub(/^plugins=/, ""); print; exit }
        ' "$cfg" 2>/dev/null || true)"
        [[ -n "$plugins" ]] || continue
        local IFS=,
        read -r -a plugin_tokens <<< "$plugins"
        for token in "${plugin_tokens[@]}"; do
            token="${token//[[:space:]]/}"
            if [[ "$token" =~ ^equalizer#([0-9]+)$ ]]; then
                printf '%s\n' "${BASH_REMATCH[1]}"
            fi
        done
    done
}

find_equalizer_instance() {
    [[ -n "$equalizer_instance" ]] && return 0

    local forced="${EASYEFFECTS_EQUALIZER_INSTANCE:-}"
    local instance response
    if [[ "$forced" =~ ^[0-9]+$ ]]; then
        response="$(send_command "get_property:output:equalizer:${forced}:numBands" || true)"
        if [[ "$response" =~ ^[0-9]+$ ]]; then
            equalizer_instance="$forced"
            return 0
        fi
    fi

    while IFS= read -r instance; do
        [[ "$instance" =~ ^[0-9]+$ ]] || continue
        response="$(send_command "get_property:output:equalizer:${instance}:numBands" || true)"
        if [[ "$response" =~ ^[0-9]+$ ]]; then
            equalizer_instance="$instance"
            return 0
        fi
    done < <(config_equalizer_instances | awk '!seen[$0]++')

    # Fallback for custom config locations or builds where the KConfig file is
    # not host-visible. EasyEffects instance ids are small monotonic integers.
    for instance in $(seq 0 31); do
        response="$(send_command "get_property:output:equalizer:${instance}:numBands" || true)"
        if [[ "$response" =~ ^[0-9]+$ ]]; then
            equalizer_instance="$instance"
            return 0
        fi
    done
    return 1
}

ensure_equalizer_active() {
    local response bypass
    find_equalizer_instance || return 1
    response="$(send_command "set_property:output:equalizer:${equalizer_instance}:bypass:false" || true)"
    if is_error_response "$response"; then
        return 1
    fi
    bypass="$(send_command "get_property:output:equalizer:${equalizer_instance}:bypass" || true)"
    [[ "$bypass" == "false" || "$bypass" == "0" ]]
}

is_error_response() {
    [[ "$1" == error_* ]]
}

is_number() {
    [[ "$1" =~ ^-?[0-9]+([.][0-9]+)?$ ]]
}

lsp_lv2_available() {
    local pid exe proc_root lv2_path base
    pid="$(pgrep -n -x easyeffects 2>/dev/null || true)"

    # A synthetic/local-server fixture has no EasyEffects process. In that case
    # let the server contract itself decide availability so the helper remains
    # testable without manufacturing host package state.
    [[ -n "$pid" ]] || return 0

    exe="$(readlink -f "/proc/$pid/exe" 2>/dev/null || true)"
    [[ -n "$exe" ]] || return 0
    proc_root="/proc/$pid/root"

    lv2_path="$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null \
        | sed -n 's/^LV2_PATH=//p' | head -n 1)"

    local -a search_paths=(
        "/usr/lib/lv2"
        "/usr/lib64/lv2"
        "/usr/local/lib/lv2"
        "/usr/local/lib64/lv2"
        "/app/lib/lv2"
        "/app/lib64/lv2"
    )

    if [[ -n "$lv2_path" ]]; then
        local IFS=:
        read -r -a runtime_paths <<< "$lv2_path"
        search_paths+=("${runtime_paths[@]}")
    fi

    for base in "${search_paths[@]}"; do
        [[ -n "$base" ]] || continue
        if compgen -G "$proc_root$base/lsp-plugins*.lv2" >/dev/null \
                || compgen -G "$proc_root$base/lsp*.lv2" >/dev/null; then
            return 0
        fi
    done

    return 1
}

read_state() {
    local num_bands split_channels bypass

    if ! lsp_lv2_available; then
        json_unavailable true false true "lsp_plugins_missing"
        return 0
    fi

    if ! find_equalizer_instance; then
        json_unavailable true false true "plugin_not_found"
        return 0
    fi
    num_bands="$(send_command "get_property:output:equalizer:${equalizer_instance}:numBands" || true)"

    if is_error_response "$num_bands" || [[ ! "$num_bands" =~ ^[0-9]+$ ]]; then
        json_unavailable true false false "server_api_unsupported"
        return 0
    fi

    split_channels="$(send_command "get_property:output:equalizer:${equalizer_instance}:splitChannels" || true)"
    [[ "$split_channels" == "true" || "$split_channels" == "1" ]] && split_channels=true || split_channels=false
    bypass="$(send_command "get_property:output:equalizer:${equalizer_instance}:bypass" || true)"
    [[ "$bypass" == "true" || "$bypass" == "1" ]] && bypass=true || bypass=false

    local count="$num_bands"
    (( count > 10 )) && count=10
    local i frequency gain
    local -a band_json=()
    for ((i = 0; i < count; i++)); do
        frequency="$(send_command "get_property:output:equalizer:${equalizer_instance}:left:band${i}Frequency" || true)"
        gain="$(send_command "get_property:output:equalizer:${equalizer_instance}:left:band${i}Gain" || true)"

        if is_error_response "$frequency" || is_error_response "$gain"; then
            json_unavailable true true false "band_api_unsupported"
            return 0
        fi

        is_number "$frequency" || frequency="${target_frequencies[$i]}"
        is_number "$gain" || gain=0
        band_json+=("{\"index\":${i},\"frequency\":${frequency},\"gain\":${gain}}")
    done

    printf '{"serverAvailable":true,"pluginAvailable":true,"supported":true,"instanceId":%s,"numBands":%s,"splitChannels":%s,"bypassed":%s,"bands":[' \
        "$equalizer_instance" "$num_bands" "$split_channels" "$bypass"
    local IFS=,
    printf '%s' "${band_json[*]}"
    printf '],"error":""}\n'
}

bootstrap_equalizer() {
    local response attempt
    if find_equalizer_instance; then
        read_state
        return 0
    fi

    # Fresh EasyEffects installs have an empty output chain. In that one safe
    # case, create a neutral iNiR-owned preset and ask EasyEffects itself to
    # load it. Never replace a non-empty user pipeline just to add Equalizer.
    if ! output_pipeline_is_empty; then
        read_state
        return 0
    fi
    if ! lsp_lv2_available || ! command -v python3 >/dev/null 2>&1; then
        read_state
        return 0
    fi

    write_inir_equalizer_preset || { read_state; return 0; }
    response="$(send_command 'load_preset:output:iNiR Equalizer' || true)"
    if is_error_response "$response"; then
        read_state
        return 0
    fi

    for attempt in $(seq 1 20); do
        equalizer_instance=""
        if find_equalizer_instance; then
            read_state
            return 0
        fi
        sleep 0.1
    done
    read_state
}

require_ten_band_plugin() {
    local num_bands
    lsp_lv2_available || return 1
    find_equalizer_instance || return 1
    num_bands="$(send_command "get_property:output:equalizer:${equalizer_instance}:numBands" || true)"
    [[ "$num_bands" == "10" ]]
}

set_band_unchecked() {
    local index="$1"
    local gain="$2"
    [[ "$index" =~ ^[0-9]+$ ]] || return 2
    (( index >= 0 && index < 10 )) || return 2
    is_number "$gain" || return 2

    ensure_equalizer_active || return 4

    local left_response right_response readback
    left_response="$(send_command "set_property:output:equalizer:${equalizer_instance}:left:band${index}Gain:${gain}" || true)"
    right_response="$(send_command "set_property:output:equalizer:${equalizer_instance}:right:band${index}Gain:${gain}" || true)"
    if is_error_response "$left_response" || is_error_response "$right_response"; then
        return 4
    fi

    readback="$(send_command "get_property:output:equalizer:${equalizer_instance}:left:band${index}Gain" || true)"
    is_number "$readback" || return 4
    awk -v actual="$readback" -v expected="$gain" 'BEGIN { d = actual - expected; if (d < 0) d = -d; exit !(d <= 0.051) }' || return 4
}

set_band() {
    require_ten_band_plugin || return 3
    set_band_unchecked "$1" "$2"
}

configure_ten_band() {
    local response
    ensure_equalizer_active || return 4
    find_equalizer_instance || return 3
    response="$(send_command "set_property:output:equalizer:${equalizer_instance}:numBands:10" || true)"
    is_error_response "$response" && return 4

    response="$(send_command "set_property:output:equalizer:${equalizer_instance}:splitChannels:0" || true)"
    is_error_response "$response" && return 4

    local i frequency left_response right_response readback
    for ((i = 0; i < 10; i++)); do
        frequency="${target_frequencies[$i]}"
        left_response="$(send_command "set_property:output:equalizer:${equalizer_instance}:left:band${i}Frequency:${frequency}" || true)"
        right_response="$(send_command "set_property:output:equalizer:${equalizer_instance}:right:band${i}Frequency:${frequency}" || true)"
        if is_error_response "$left_response" || is_error_response "$right_response"; then
            return 4
        fi
        readback="$(send_command "get_property:output:equalizer:${equalizer_instance}:left:band${i}Frequency" || true)"
        is_number "$readback" || return 4
        awk -v actual="$readback" -v expected="$frequency" 'BEGIN { d = actual - expected; if (d < 0) d = -d; exit !(d <= 0.51) }' || return 4
        set_band_unchecked "$i" 0 || return 4
    done
}

preset_values() {
    case "$1" in
        Flat)    printf '%s\n' '0 0 0 0 0 0 0 0 0 0' ;;
        Bass)    printf '%s\n' '5 7 5 2 1 0 0 0 1 2' ;;
        Treble)  printf '%s\n' '-2 -1 0 1 2 3 4 5 6 6' ;;
        Vocal)   printf '%s\n' '-2 -1 1 3 5 5 4 2 1 0' ;;
        Pop)     printf '%s\n' '2 4 2 0 1 2 4 2 1 2' ;;
        Rock)    printf '%s\n' '5 4 2 -1 -2 -1 2 4 5 6' ;;
        Jazz)    printf '%s\n' '3 3 1 1 1 1 2 1 2 3' ;;
        Classic) printf '%s\n' '0 1 2 2 2 2 1 2 3 4' ;;
        *) return 2 ;;
    esac
}

apply_preset() {
    local name="$1"
    local values
    values="$(preset_values "$name")" || return 2
    require_ten_band_plugin || return 3

    local -a gains
    read -r -a gains <<< "$values"
    local i
    for ((i = 0; i < 10; i++)); do
        set_band_unchecked "$i" "${gains[$i]}"
    done
}

case "${1:-get}" in
    get)
        read_state
        ;;
    bootstrap)
        bootstrap_equalizer
        ;;
    set-band)
        if ! set_band "${2:-}" "${3:-}"; then
            read_state
            exit 0
        fi
        read_state
        ;;
    configure)
        if ! configure_ten_band; then
            read_state
            exit 0
        fi
        read_state
        ;;
    preset)
        if ! apply_preset "${2:-}"; then
            read_state
            exit 0
        fi
        read_state
        ;;
    *)
        printf 'Usage: %s <get|bootstrap|set-band INDEX GAIN|configure|preset NAME>\n' "$0" >&2
        exit 2
        ;;
esac
