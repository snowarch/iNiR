#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
config_dir="$(cd -- "$script_dir/.." && pwd)"
qs_bin="/usr/bin/qs"
launcher_script="$config_dir/scripts/inir"
poll_delay="${QS_RESTART_POLL_DELAY:-0.1}"
max_polls="${QS_RESTART_MAX_POLLS:-50}"

if [[ ! -x "$qs_bin" ]]; then
    qs_bin="$(command -v qs)"
fi

if [[ -z "${qs_bin:-}" || ! -x "$qs_bin" ]]; then
    exit 1
fi

if [[ ! -f "$launcher_script" ]]; then
    launcher_script="$script_dir/inir"
fi

if [[ ! -f "$launcher_script" ]]; then
    exit 1
fi

"$qs_bin" -p "$config_dir" kill >/dev/null 2>&1 || true

for ((poll = 0; poll < max_polls; poll++)); do
    list_output="$("$qs_bin" -p "$config_dir" list 2>/dev/null || true)"
    if [[ "$list_output" == No\ running\ instances* ]]; then
        exec /usr/bin/env bash "$launcher_script" start -c "$config_dir"
    fi
    sleep "$poll_delay"
done

exit 1
