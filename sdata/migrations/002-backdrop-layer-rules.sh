# Migration: Add layer-rules for backdrop panels
# Required for Niri overview backdrop effect

MIGRATION_ID="002-backdrop-layer-rules"
MIGRATION_TITLE="Backdrop Layer Rules"
MIGRATION_DESCRIPTION="Adds layer-rules for quickshell backdrop panels.
  Required for the overview/task-view backdrop blur effect to work correctly."
MIGRATION_TARGET_FILE="~/.config/niri/config.kdl"
MIGRATION_REQUIRED=false

migration_check() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
  [[ -f "$config" ]] && ! grep -q "quickshell:iiBackdrop" "$config"
}

migration_preview() {
  echo -e "${STY_GREEN}+ layer-rule { match namespace=\"quickshell:iiBackdrop\" ... }${STY_RST}"
  echo -e "${STY_GREEN}+ layer-rule { match namespace=\"quickshell:wBackdrop\" ... }${STY_RST}"
}

migration_diff() {
  cat << 'DIFF'
Will append to end of config:

layer-rule {
    match namespace="quickshell:iiBackdrop"
    place-within-backdrop true
    opacity 1.0
}

layer-rule {
    match namespace="quickshell:wBackdrop"
    place-within-backdrop true
    opacity 1.0
}
DIFF
}

migration_apply() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
  
  if ! migration_check; then
    return 0
  fi
  
  cat >> "$config" << 'BACKDROP_RULES'

// ============================================================================
// Layer rules added by ii-niri (required for backdrop in overview)
// ============================================================================
layer-rule {
    match namespace="quickshell:iiBackdrop"
    place-within-backdrop true
    opacity 1.0
}

layer-rule {
    match namespace="quickshell:wBackdrop"
    place-within-backdrop true
    opacity 1.0
}
BACKDROP_RULES
}
