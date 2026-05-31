#!/usr/bin/env bash
# Migration: Translate the bar to the new 5-zone modular layout
#
# The bar used to be laid out by a fixed, hardcoded structure plus orphaned
# config keys (modulesLayout.order, edgeModulesLayout.leftOrder/rightOrder,
# modulesPlacement). The bar is now driven by Config.options.bar.layout with
# five zones (left, centerLeft, center, centerRight, right) that map 1:1 to the
# bar's real sections, keeping workspaces centered and pill surfaces intact.
#
# This migration seeds bar.layout from the user's current state so existing
# users are visually unchanged, preserving any custom order they may have set
# in the old orphaned arrays, then marks the layout as migrated and removes the
# dead keys. Module VISIBILITY is unchanged — it still lives in bar.modules.*.

MIGRATION_ID="028-bar-modular-layout"
MIGRATION_TITLE="Modular bar layout"
MIGRATION_DESCRIPTION="Disabled. The bar now falls back to the classic layout at runtime, so no config change is needed; this migration no longer runs."
MIGRATION_TARGET_FILE="~/.config/inir/config.json"
MIGRATION_REQUIRED=false

_config_path() {
  local xdg_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local config_new="${xdg_config_home}/inir/config.json"
  local config_legacy="${xdg_config_home}/illogical-impulse/config.json"
  if [[ -f "$config_legacy" ]]; then
    echo "$config_legacy"
    return
  fi
  echo "$config_new"
}

migration_check() {
  # Disabled: the bar reads bar.layout with a built-in classic fallback in
  # BarContent.qml (_zone(name, fallback)), so no config change is needed for
  # the modular layout to work. This migration is kept (append-only contract)
  # but never runs — it is not pending and never auto-applies.
  return 1
}

migration_preview() {
  local conf
  conf="$(_config_path)"
  echo "Will translate the bar to the new 5-zone modular layout in $conf:"
  echo ""
  echo -e "  ${STY_GREEN}+ bar.layout.left / centerLeft / center / centerRight / right${STY_RST} (built from your current modules)"
  echo -e "  ${STY_GREEN}+ bar.layout.migrated = true${STY_RST}"
  echo -e "  ${STY_YELLOW}~ preserves any custom order from the old modulesLayout / edgeModulesLayout${STY_RST}"
  echo -e "  ${STY_RED}- bar.modulesLayout / bar.edgeModulesLayout / bar.modulesPlacement${STY_RST} (dead keys, removed)"
  echo ""
  echo "Your bar will look exactly the same. Module visibility (bar.modules.*) is untouched."
}

migration_diff() {
  local conf
  conf="$(_config_path)"
  echo "Old orphaned layout keys present:"
  jq -r '.bar | {modulesLayout, edgeModulesLayout, modulesPlacement}' "$conf" 2>/dev/null || echo "  (none)"
}

migration_apply() {
  local conf
  conf="$(_config_path)"
  [[ -f "$conf" ]] || { echo "  Config file not found, skipping."; return 0; }
  command -v jq >/dev/null 2>&1 || { echo "  jq not found, skipping."; return 0; }

  local tmp="${conf}.migration-tmp"

  # Build the 5 zones, honoring old custom order where it exists, then seed
  # the new layout, mark migrated, and drop dead keys. sysTray → tray rename.
  jq '
    def dedup: reduce .[] as $x ([]; if (. | index($x)) == null then . + [$x] else . end);
    # Old center order (orphaned) or the canonical default
    (.bar.modulesLayout.order // ["resources","media","workspaces","clock","utilButtons","battery"]) as $center_old
    | ((.bar.edgeModulesLayout.leftOrder // ["leftSidebarButton","activeWindow"])) as $left_old
    | ((.bar.edgeModulesLayout.rightOrder // ["rightSidebarButton","sysTray","weather"])
        | map(if . == "sysTray" then "tray" else . end)) as $right_raw
    # Insert the fixed chrome ids (timer, shellUpdate, spacer) into the right
    # zone just before weather so the classic RTL order is reproduced exactly.
    | ($right_raw | map(select(. != "weather"))) as $right_head
    | ($right_head + ["timer","shellUpdate","spacer"] + ($right_raw | map(select(. == "weather")))) as $right_old
    # Split the old center flow at the workspaces pivot
    | ($center_old | index("workspaces")) as $piv
    | (if $piv == null then $center_old else $center_old[0:$piv] end) as $cl
    | (if $piv == null then [] else $center_old[($piv+1):] end) as $cr
    | .bar.layout = {
        "left": ($left_old | dedup),
        "centerLeft": ($cl | dedup),
        "center": ["workspaces"],
        "centerRight": ($cr | dedup),
        "right": ($right_old | dedup),
        "migrated": true
      }
  ' "$conf" > "$tmp" && mv "$tmp" "$conf"
  echo "  Bar translated to modular 5-zone layout (visuals preserved)."
}
