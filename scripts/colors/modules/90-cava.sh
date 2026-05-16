#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/module-runtime.sh"
COLOR_MODULE_ID="cava"

PALETTE_FILE="$STATE_DIR/user/generated/palette.json"
COVER_COLORS_FILE="$STATE_DIR/user/generated/cover-colors.json"
CAVA_CONFIG_DIR="$XDG_CONFIG_HOME/cava"
CAVA_CONFIG="$CAVA_CONFIG_DIR/config"

MARKER_BEGIN="# BEGIN inir-managed"
MARKER_END="# END inir-managed"

# Read a cava config value from appearance.cava
cava_cfg() {
  local key="$1" fallback="$2"
  config_json ".appearance.cava.${key} // \"${fallback}\"" "$fallback"
}

palette_color() {
  local key="$1"
  jq -r ".$key // empty" "$PALETTE_FILE" 2>/dev/null
}

cover_color() {
  local idx="$1"
  [[ -f "$COVER_COLORS_FILE" ]] || return 1
  jq -r ".[$idx] // empty" "$COVER_COLORS_FILE" 2>/dev/null
}

# Boost saturation of a hex color by mixing toward its hue at full saturation
saturate_hex() {
  local hex="$1" factor="${2:-1.4}"
  python3 -c "
import colorsys, sys
h = '${hex}'.lstrip('#')
r, g, b = int(h[0:2],16)/255, int(h[2:4],16)/255, int(h[4:6],16)/255
hue, sat, val = colorsys.rgb_to_hsv(r, g, b)
sat = min(1.0, sat * ${factor})
val = min(1.0, val * 1.1)
r2, g2, b2 = colorsys.hsv_to_rgb(hue, sat, val)
print('#%02x%02x%02x' % (int(r2*255), int(g2*255), int(b2*255)))
" 2>/dev/null || printf '%s\n' "$hex"
}

# Build gradient from palette - uses bright, visible colors first
build_gradient_theme() {
  local count="$1"
  local -a keys=(primary tertiary secondary error success primary_fixed tertiary_fixed primary_container)
  local -a colors=()
  local c
  for key in "${keys[@]}"; do
    c=$(palette_color "$key")
    [[ -n "$c" ]] && colors+=("$c")
    (( ${#colors[@]} >= count )) && break
  done
  (( ${#colors[@]} >= 2 )) || return 1
  printf '%s\n' "${colors[@]}"
}

# Build gradient with saturated variants of palette colors
build_gradient_vibrant() {
  local count="$1"
  local -a keys=(primary tertiary secondary error success primary_fixed tertiary_fixed inverse_primary)
  local -a colors=()
  local c sat
  for key in "${keys[@]}"; do
    c=$(palette_color "$key")
    if [[ -n "$c" ]]; then
      sat=$(saturate_hex "$c" 1.6)
      colors+=("$sat")
    fi
    (( ${#colors[@]} >= count )) && break
  done
  (( ${#colors[@]} >= 2 )) || return 1
  printf '%s\n' "${colors[@]}"
}

# Build gradient from album art cover colors
build_gradient_cover() {
  local count="$1"
  [[ -f "$COVER_COLORS_FILE" ]] || { log_module "No cover colors file, falling back to theme"; build_gradient_theme "$count"; return; }
  local -a colors=()
  local c
  for i in $(seq 0 $((count - 1))); do
    c=$(cover_color "$i")
    [[ -n "$c" ]] && colors+=("$c")
  done
  if (( ${#colors[@]} < 2 )); then
    log_module "Not enough cover colors (${#colors[@]}), falling back to theme"
    build_gradient_theme "$count"
    return
  fi
  printf '%s\n' "${colors[@]}"
}

generate_managed_block() {
  local color_source gradient_count fg_override bg_override
  local sensitivity bars framerate bar_width bar_spacing stereo

  color_source=$(cava_cfg colorSource "theme")
  gradient_count=$(cava_cfg gradientCount "8")
  fg_override=$(cava_cfg foreground "")
  bg_override=$(cava_cfg background "")
  sensitivity=$(cava_cfg sensitivity "100")
  bars=$(cava_cfg bars "0")
  framerate=$(cava_cfg framerate "60")
  bar_width=$(cava_cfg barWidth "2")
  bar_spacing=$(cava_cfg barSpacing "1")
  stereo=$(cava_cfg stereo "true")

  # Clamp gradient count
  (( gradient_count < 2 )) && gradient_count=2
  (( gradient_count > 8 )) && gradient_count=8

  # Build gradient based on source
  local -a gradient=()
  case "$color_source" in
    vibrant) while IFS= read -r c; do gradient+=("$c"); done < <(build_gradient_vibrant "$gradient_count") ;;
    cover)   while IFS= read -r c; do gradient+=("$c"); done < <(build_gradient_cover "$gradient_count") ;;
    *)       while IFS= read -r c; do gradient+=("$c"); done < <(build_gradient_theme "$gradient_count") ;;
  esac

  (( ${#gradient[@]} >= 2 )) || return 1

  # Resolve background
  local bg="${bg_override}"
  if [[ -z "$bg" ]]; then
    bg=$(palette_color "background")
    [[ -n "$bg" ]] || bg=$(palette_color "surface")
  fi

  # Channels
  local channels="stereo"
  [[ "$stereo" == "false" ]] && channels="mono"

  printf '%s\n' "$MARKER_BEGIN"

  # General section
  printf '[general]\n'
  printf 'framerate = %d\n' "$framerate"
  printf 'sensitivity = %d\n' "$sensitivity"
  (( bars > 0 )) && printf 'bars = %d\n' "$bars"
  printf 'bar_width = %d\n' "$bar_width"
  printf 'bar_spacing = %d\n' "$bar_spacing"
  printf '\n'

  # Output section
  printf '[output]\n'
  printf 'channels = %s\n' "$channels"
  printf '\n'

  # Color section
  printf '[color]\n'
  [[ -n "${bg:-}" ]] && printf "background = '%s'\n" "$bg"

  if [[ -n "$fg_override" ]]; then
    printf "foreground = '%s'\n" "$fg_override"
  else
    printf 'gradient = 1\n'
    local i=1
    for c in "${gradient[@]}"; do
      printf "gradient_color_%d = '%s'\n" "$i" "$c"
      ((i++))
    done
  fi

  printf '%s\n' "$MARKER_END"
}

# Inject or replace managed block in cava config
apply_cava_config() {
  [[ -f "$PALETTE_FILE" ]] || { log_module "palette.json not found, skipping"; return 0; }
  command -v cava &>/dev/null || { log_module "cava not installed, skipping"; return 0; }

  local block
  block=$(generate_managed_block) || { log_module "Failed to generate config"; return 0; }

  mkdir -p "$CAVA_CONFIG_DIR"

  if [[ ! -f "$CAVA_CONFIG" ]]; then
    printf '%s\n' "$block" > "$CAVA_CONFIG"
    log_module "Created cava config with theme"
    return 0
  fi

  if grep -qF "$MARKER_BEGIN" "$CAVA_CONFIG"; then
    local tmp; tmp=$(mktemp)
    awk -v begin="$MARKER_BEGIN" -v end="$MARKER_END" -v block="$block" '
      $0 == begin { skip=1; printed=0 }
      skip && $0 == end { skip=0; print block; printed=1; next }
      !skip { print }
    ' "$CAVA_CONFIG" > "$tmp"
    mv "$tmp" "$CAVA_CONFIG"
  else
    # Also handle legacy markers
    local legacy_begin="# BEGIN inir-generated-colors"
    if grep -qF "$legacy_begin" "$CAVA_CONFIG"; then
      local tmp; tmp=$(mktemp)
      awk -v begin="$legacy_begin" -v end="# END inir-generated-colors" -v block="$block" '
        $0 == begin { skip=1; printed=0 }
        skip && $0 == end { skip=0; print block; printed=1; next }
        !skip { print }
      ' "$CAVA_CONFIG" > "$tmp"
      mv "$tmp" "$CAVA_CONFIG"
    elif grep -q '^\[color\]' "$CAVA_CONFIG"; then
      local tmp; tmp=$(mktemp)
      awk -v block="$block" '
        /^\[color\]/ { in_color=1; print block; next }
        in_color && /^\[/ { in_color=0 }
        !in_color { print }
      ' "$CAVA_CONFIG" > "$tmp"
      mv "$tmp" "$CAVA_CONFIG"
    else
      printf '\n%s\n' "$block" >> "$CAVA_CONFIG"
    fi
  fi

  log_module "Applied cava config (source=$( cava_cfg colorSource theme ))"
}

strip_cava_config() {
  [[ -f "$CAVA_CONFIG" ]] || return 0

  local stripped=false
  for marker in "$MARKER_BEGIN" "# BEGIN inir-generated-colors"; do
    if grep -qF "$marker" "$CAVA_CONFIG"; then
      local end_marker="${marker/BEGIN/END}"
      local tmp; tmp=$(mktemp)
      awk -v begin="$marker" -v end="$end_marker" '
        $0 == begin { skip=1; next }
        skip && $0 == end { skip=0; next }
        !skip { print }
      ' "$CAVA_CONFIG" > "$tmp"
      mv "$tmp" "$CAVA_CONFIG"
      stripped=true
    fi
  done
  $stripped && log_module "Stripped iNiR config from cava"
}

main() {
  local enabled
  enabled=$(config_bool '.appearance.wallpaperTheming.enableCava' false)

  if [[ "$enabled" == 'true' ]]; then
    apply_cava_config
  else
    strip_cava_config
  fi
}

main "$@"
