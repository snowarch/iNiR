# Migration: GTK4 Nautilus sidebar CSS
# Adds Nautilus-specific CSS rules to the GTK4 matugen template for cleaner
# sidebar, headerbar, and view styling. Also updates GTK3 if needed.

MIGRATION_ID="011-gtk4-nautilus-css"
MIGRATION_TITLE="GTK4/GTK3 Nautilus sidebar styling"
MIGRATION_DESCRIPTION="Adds Nautilus-specific CSS rules to GTK4 matugen template for cleaner file manager appearance (sidebar, headerbar, view colors)."
MIGRATION_TARGET_FILE="~/.config/matugen/templates/gtk-4.0/gtk.css"
MIGRATION_REQUIRED=true

migration_check() {
  local gtk4_template="${XDG_CONFIG_HOME:-$HOME/.config}/matugen/templates/gtk-4.0/gtk.css"
  [[ -f "$gtk4_template" ]] || return 1

  # Already has Nautilus sidebar rules?
  if grep -q 'nautilus-window.*sidebar' "$gtk4_template" 2>/dev/null; then
    return 1
  fi

  # Template exists but lacks Nautilus rules
  return 0
}

migration_preview() {
  echo "Will add Nautilus-specific CSS rules to GTK4 template:"
  echo ""
  echo -e "${STY_GREEN}+ .nautilus-window .sidebar { ... }${STY_RST}"
  echo -e "${STY_GREEN}+ placessidebar row { ... }${STY_RST}"
  echo -e "${STY_GREEN}+ placessidebar row:hover { ... }${STY_RST}"
  echo -e "${STY_GREEN}+ placessidebar row:selected { ... }${STY_RST}"
  echo -e "${STY_GREEN}+ .nautilus-window headerbar { ... }${STY_RST}"
  echo -e "${STY_GREEN}+ .nautilus-window .view { ... }${STY_RST}"
  echo -e "${STY_GREEN}+ placessidebar image { ... }${STY_RST}"
}

migration_diff() {
  echo "Current GTK4 template lacks Nautilus-specific styling."
  echo "After migration, Nautilus sidebar/headerbar/view will use Material You colors."
}

migration_apply() {
  local inir_dir="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/inir"
  local gtk4_src="${inir_dir}/dots/.config/matugen/templates/gtk-4.0/gtk.css"
  local gtk4_dst="${XDG_CONFIG_HOME:-$HOME/.config}/matugen/templates/gtk-4.0/gtk.css"
  local gtk3_src="${inir_dir}/dots/.config/matugen/templates/gtk-3.0/gtk.css"
  local gtk3_dst="${XDG_CONFIG_HOME:-$HOME/.config}/matugen/templates/gtk-3.0/gtk.css"

  # Copy updated templates from the synced dots/ directory
  if [[ -f "$gtk4_src" ]]; then
    mkdir -p "$(dirname "$gtk4_dst")"
    cp -f "$gtk4_src" "$gtk4_dst"
  fi

  if [[ -f "$gtk3_src" ]]; then
    mkdir -p "$(dirname "$gtk3_dst")"
    cp -f "$gtk3_src" "$gtk3_dst"
  fi
}
