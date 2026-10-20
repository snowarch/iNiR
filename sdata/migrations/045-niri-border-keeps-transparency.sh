#!/usr/bin/env bash
# Migration 045: borders and focus rings no longer fill in behind see-through windows.
#
# Niri draws a window's border and focus ring as a solid rectangle behind it unless a rule says otherwise, so with
# borders on, an app with its own decorations (Firefox, Steam, GTK4 apps) lost the opacity set for it. The global
# rule already rounds and clips every window, so the border can follow the window's own shape instead. Anyone who set
# draw-border-with-background anywhere keeps their choice.

MIGRATION_ID="045-niri-border-keeps-transparency"
MIGRATION_TITLE="Borders keep windows see-through"
MIGRATION_DESCRIPTION="With window borders on, apps that draw their own title bar (Firefox, Steam, GTK apps) turned opaque. Borders now go around the window instead of filling in behind it."
MIGRATION_TARGET_FILE="~/.config/niri/config.d/30-window-rules.kdl"
MIGRATION_REQUIRED=true

_border_bg_niri_dir() {
  printf '%s/niri' "${XDG_CONFIG_HOME:-$HOME/.config}"
}

_border_bg_rules_file() {
  printf '%s/config.d/30-window-rules.kdl' "$(_border_bg_niri_dir)"
}

# Any uncommented draw-border-with-background in the user's niri config is a choice already made.
_border_bg_set_anywhere() {
  local dir file
  dir="$(_border_bg_niri_dir)"
  for file in "$dir/config.kdl" "$dir"/config.d/*.kdl; do
    [[ -f "$file" ]] || continue
    grep -Eq '^[[:space:]]*draw-border-with-background[[:space:]]' "$file" && return 0
  done
  return 1
}

# Line number of the first `window-rule {` whose block has no match or exclude: the rule every window takes.
_border_bg_global_rule_line() {
  awk '
    /^[[:space:]]*\/\// { next }
    /^[[:space:]]*window-rule[[:space:]]*\{[[:space:]]*$/ { start = NR; scoped = 0; next }
    start && /^[[:space:]]*(match|exclude)[[:space:]]/ { scoped = 1 }
    start && /^[[:space:]]*\}[[:space:]]*$/ { if (!scoped) { print start; exit } start = 0 }
  ' "$1"
}

migration_check() {
  local file
  file="$(_border_bg_rules_file)"
  [[ -f "$file" ]] || return 1
  _border_bg_set_anywhere && return 1
  [[ -n "$(_border_bg_global_rule_line "$file")" ]]
}

migration_preview() {
  echo -e "${STY_GREEN}+ draw-border-with-background false${STY_RST}  (30-window-rules.kdl, the rule every window takes)"
  echo ""
  echo "Borders and the focus ring go around each window instead of filling in behind it."
}

migration_apply() {
  local file line
  file="$(_border_bg_rules_file)"
  line="$(_border_bg_global_rule_line "$file")"
  [[ -n "$line" ]] || return 1
  sed -i "${line}a\\    draw-border-with-background false" "$file" || return 1
  ! migration_check
}
