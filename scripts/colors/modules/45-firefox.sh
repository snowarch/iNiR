#!/usr/bin/env bash
# Firefox's "System theme" paints its chrome from system colours, and a `ui.<colour>` pref wins over what GTK
# reports (with adw-gtk3 Firefox ignores GTK and paints fixed libadwaita colours). The prefs go in a managed
# block of every Firefox-family profile's user.js, which the browser reads when it starts.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/module-runtime.sh"
COLOR_MODULE_ID="firefox"

APP_PALETTE="$STATE_DIR/user/generated/app-palette.json"
BLOCK_BEGIN='// iNiR colours: begin (rewritten by iNiR on every wallpaper change)'
BLOCK_END='// iNiR colours: end'

list_profiles() {
  local root ini path
  while IFS= read -r root; do
    ini="$root/profiles.ini"
    [[ -f "$ini" ]] || continue
    while IFS= read -r path; do
      [[ "$path" == /* ]] || path="$root/$path"
      [[ -d "$path" ]] && printf '%s\n' "$path"
    done < <(sed -n 's/^Path=//p' "$ini" | tr -d '\r')
  done < <(firefox_profile_roots)
}

# One user_pref line per system colour; with "off" every value is empty, which hands the colour back to Firefox.
render_block() {
  local mode="$1"
  printf '%s\n' "$BLOCK_BEGIN"
  jq -r --arg mode "$mode" '
    def chan: if . >= 97 then . - 87 elif . >= 65 then . - 55 else . - 48 end;
    def rgb: ltrimstr("#") | explode | map(chan) | [.[0] * 16 + .[1], .[2] * 16 + .[3], .[4] * 16 + .[5]];
    def hex2: ([., 0] | max | [., 255] | min | round) as $v
      | [($v / 16 | floor), ($v % 16)] | map(if . < 10 then . + 48 else . + 87 end) | implode;
    # Nova draws the toolbar and the selected tab as color-mix(-moz-dialog 85%, white): solve the dialog
    # colour that lands them on the target. A target darker than the white share is lifted evenly on every
    # channel first, so it keeps its tint.
    def under_white($p): if type == "string" then
        (255 * $p | ceil) as $floor
        | rgb | (min) as $low | map(. + ([$floor - $low, 0] | max))
        | "#" + (map(((. - 255 * $p) / (1 - $p)) | hex2) | join(""))
      else null end;
    def luma: if type == "string" then rgb | .[0] * 0.2126 + .[1] * 0.7152 + .[2] * 0.0722 else 0 end;
    . as $p
    # The toolbar and the selected tab sit on the page and take the lighter surface; the tab strip recedes.
    | [($p.app_headerbar_bg // $p.surface), ($p.app_surface_popup // $p.surface_container_high)]
    | sort_by(luma) as [$frame, $raised]
    | ($p.app_foreground // $p.on_surface) as $text
    | ($p.app_subtext // $p.on_surface_variant) as $subtext
    | ($p.app_on_surface_popup // $p.on_surface) as $on_raised
    | ($p.app_selection // $p.secondary_container) as $selection
    | ($p.app_on_selection // $p.on_secondary_container) as $on_selection
    | ($p.app_accent // $p.primary) as $accent
    | [
        ["-moz-headerbar", $frame], ["-moz-headerbartext", $text],
        ["-moz-headerbarinactive", $frame], ["-moz-headerbarinactivetext", $subtext],
        ["activecaption", $frame], ["captiontext", $text],
        ["inactivecaption", $frame], ["inactivecaptiontext", $subtext],
        ["-moz-dialog", ($raised | under_white(0.15))], ["-moz-dialogtext", $on_raised],
        ["window", ($p.app_window_bg // $frame)], ["windowtext", $text],
        ["-moz-field", $raised], ["-moz-fieldtext", $on_raised],
        ["menu", $raised], ["menutext", $on_raised],
        ["infobackground", $raised], ["infotext", $on_raised],
        ["-moz_menuhover", $selection], ["-moz_menuhovertext", $on_selection],
        ["-moz_menubarhovertext", $on_selection],
        ["selecteditem", $selection], ["selecteditemtext", $on_selection],
        ["-moz-cellhighlight", $selection], ["-moz_cellhighlighttext", $on_selection],
        ["highlight", $selection], ["highlighttext", $on_selection],
        ["accentcolor", $accent], ["accentcolortext", ($p.app_on_accent // $p.on_primary)],
        ["-moz-hyperlinktext", $accent], ["-moz-activehyperlinktext", $accent],
        ["-moz-visitedhyperlinktext", $accent],
        ["-moz-sidebar", $frame], ["-moz-sidebartext", $text],
        ["-moz-sidebarborder", ($p.app_border_subtle // $p.outline_variant)],
        ["buttonface", ($p.app_surface_elevated // $raised)], ["buttontext", $text],
        ["-moz-buttonhoverface", ($p.app_surface_elevated_hover // $raised)], ["-moz_buttonhovertext", $text],
        ["-moz-buttonactiveface", ($p.app_surface_elevated_active // $raised)], ["-moz-buttonactivetext", $text],
        ["buttonborder", ($p.app_border_subtle // $p.outline_variant)],
        ["graytext", $subtext]
      ]
    | .[]
    | if ($mode != "off" and ((.[1] // "") | test("^#[0-9A-Fa-f]{6}$") | not)) then error("bad colour for \(.[0])") else . end
    | "user_pref(\"ui.\(.[0])\", \"\(if $mode == "off" then "" else .[1] end)\");"
  ' < <(if [[ -s "$APP_PALETTE" ]]; then cat "$APP_PALETTE"; else printf '{}'; fi)
  printf '%s\n' "$BLOCK_END"
}

apply_profile() {
  local user_js="$1/user.js" block="$2" mode="$3"
  if [[ -L "$user_js" ]]; then
    log_module "left $user_js alone: it is a link"
    return 0
  fi
  # Giving the colours back only touches a profile iNiR coloured.
  [[ "$mode" == "off" ]] && ! grep -qsxF -- "$BLOCK_BEGIN" "$user_js" && return 0
  if {
    [[ -f "$user_js" ]] && awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" '
      $0 == b { skip = 1; next }
      $0 == e { skip = 0; next }
      !skip' "$user_js"
    printf '%s\n' "$block"
  } | write_if_changed "$user_js"; then
    log_module "wrote $user_js ($mode)"
  fi
}

main() {
  command -v jq >/dev/null 2>&1 || { log_module "jq not installed - skipping"; exit 0; }
  local mode="on" block profile
  [[ "$(config_bool '.appearance.wallpaperTheming.enableFirefox' true)" == "true" ]] || mode="off"
  if [[ "$mode" == "on" && ! -s "$APP_PALETTE" ]]; then
    log_module "no app palette yet - skipping"
    exit 0
  fi
  block="$(render_block "$mode")" || { log_module "app palette unreadable - skipping"; exit 0; }
  while IFS= read -r profile; do
    apply_profile "$profile" "$block" "$mode"
  done < <(list_profiles)
}

main "$@"
