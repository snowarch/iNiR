#!/usr/bin/env bash
# Rin in the theme's colours. Rin draws window edges, the focus outline, title bars and the window switcher from its own
# Material You scheme, so it gets the seed, scheme and mode iNiR's palette came from, through its settings service.
# Runs only on Rin, and writes only the keys that differ: each write re-themes the compositor.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/module-runtime.sh"
COLOR_MODULE_ID="rin"

META="$STATE_DIR/user/generated/theme-meta.json"

[[ -n "${RIN_SOCKET:-}" ]] || exit 0
[[ -f "$META" ]] || exit 0
command -v rin >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

seed="$(jq -r '.accent_seed // .seed_color // empty' "$META" 2>/dev/null | tr 'A-F' 'a-f')"
[[ "$seed" =~ ^#[0-9a-f]{6}$ ]] || exit 0
style="$(jq -r '.scheme // empty' "$META" 2>/dev/null)"
style="${style#scheme-}"
case "$style" in
  tonal-spot | vibrant | expressive | neutral | monochrome | fidelity | content | rainbow | fruit-salad) ;;
  *) style=tonal-spot ;;
esac
theme=material-you
[[ "$(theme_mode)" == light ]] && theme=material-you-light

# A Rin without the settings verb answers nothing here: leave it as it is.
current="$(rin msg settings read rin.appearance 2>/dev/null)" || exit 0
[[ "$current" == "{"* ]] || exit 0

set_key() {
  [[ "$(jq -r --arg key "$1" '.[$key] // empty' <<<"$current")" == "$2" ]] && return 0
  rin msg settings set rin.appearance "$1" "$2" >/dev/null && log_module "$1 = $2"
}
# The source and scheme first: the theme switch then draws the right colours at once.
set_key material-source "$seed"
set_key material-style "$style"
set_key theme "$theme"
