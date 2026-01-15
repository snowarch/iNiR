#!/usr/bin/env bash

QUICKSHELL_CONFIG_NAME="ii"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CONFIG_DIR="$XDG_CONFIG_HOME/quickshell/$QUICKSHELL_CONFIG_NAME"
CACHE_DIR="$XDG_CACHE_HOME/quickshell"
STATE_DIR="$XDG_STATE_HOME/quickshell"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

term_alpha=100 #Set this to < 100 make all your terminals transparent
# sleep 0 # idk i wanted some delay or colors dont get applied properly
if [ ! -d "$STATE_DIR"/user/generated ]; then
  mkdir -p "$STATE_DIR"/user/generated
fi
cd "$CONFIG_DIR" || exit

colornames=''
colorstrings=''
colorlist=()
colorvalues=()

colornames=$(cat $STATE_DIR/user/generated/material_colors.scss | cut -d: -f1)
colorstrings=$(cat $STATE_DIR/user/generated/material_colors.scss | cut -d: -f2 | cut -d ' ' -f2 | cut -d ";" -f1)
IFS=$'\n'
colorlist=($colornames)     # Array of color names
colorvalues=($colorstrings) # Array of color values

apply_term() {
  # Check if terminal escape sequence template exists
  if [ ! -f "$SCRIPT_DIR/terminal/sequences.txt" ]; then
    echo "Template file not found for Terminal. Skipping that."
    return
  fi
  # Copy template
  mkdir -p "$STATE_DIR"/user/generated/terminal
  cp "$SCRIPT_DIR/terminal/sequences.txt" "$STATE_DIR"/user/generated/terminal/sequences.txt
  # Apply colors
  for i in "${!colorlist[@]}"; do
    sed -i "s/${colorlist[$i]} #/${colorvalues[$i]#\#}/g" "$STATE_DIR"/user/generated/terminal/sequences.txt
  done

  sed -i "s/\$alpha/$term_alpha/g" "$STATE_DIR"/user/generated/terminal/sequences.txt

  for file in /dev/pts/*; do
    if [[ $file =~ ^/dev/pts/[0-9]+$ ]]; then
      {
      cat "$STATE_DIR"/user/generated/terminal/sequences.txt >"$file"
      } & disown || true
    fi
  done
}

apply_terminal_configs() {
  # Generate terminal-specific config files (Kitty, Alacritty, Foot, WezTerm, Ghostty, Konsole)
  if [ ! -f "$STATE_DIR/user/generated/material_colors.scss" ]; then
    echo "material_colors.scss not found. Skipping terminal config generation."
    return
  fi

  # Get enabled terminals from config
  local enabled_terminals=()
  if [ -f "$CONFIG_FILE" ]; then
    # Check which terminal config generators are enabled
    local enable_kitty=$(jq -r '.appearance.wallpaperTheming.terminals.kitty // true' "$CONFIG_FILE")
    local enable_alacritty=$(jq -r '.appearance.wallpaperTheming.terminals.alacritty // true' "$CONFIG_FILE")
    local enable_foot=$(jq -r '.appearance.wallpaperTheming.terminals.foot // true' "$CONFIG_FILE")
    local enable_wezterm=$(jq -r '.appearance.wallpaperTheming.terminals.wezterm // true' "$CONFIG_FILE")
    local enable_ghostty=$(jq -r '.appearance.wallpaperTheming.terminals.ghostty // true' "$CONFIG_FILE")
    local enable_konsole=$(jq -r '.appearance.wallpaperTheming.terminals.konsole // true' "$CONFIG_FILE")

    [[ "$enable_kitty" == "true" ]] && enabled_terminals+=(kitty)
    [[ "$enable_alacritty" == "true" ]] && enabled_terminals+=(alacritty)
    [[ "$enable_foot" == "true" ]] && enabled_terminals+=(foot)
    [[ "$enable_wezterm" == "true" ]] && enabled_terminals+=(wezterm)
    [[ "$enable_ghostty" == "true" ]] && enabled_terminals+=(ghostty)
    [[ "$enable_konsole" == "true" ]] && enabled_terminals+=(konsole)
  else
    # Default: enable all
    enabled_terminals=(kitty alacritty foot wezterm ghostty konsole)
  fi

  if [ ${#enabled_terminals[@]} -eq 0 ]; then
    return
  fi

  # Run the Python script to generate configs
  # Use venv python if available, otherwise system python
  local python_cmd="python3"
  local venv_python="${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-$HOME/.local/state/quickshell/.venv}/bin/python"
  if [[ -x "$venv_python" ]]; then
    python_cmd="$venv_python"
  fi

  if command -v "$python_cmd" &>/dev/null || [[ -x "$python_cmd" ]]; then
    "$python_cmd" "$SCRIPT_DIR/generate_terminal_configs.py" \
      --scss "$STATE_DIR/user/generated/material_colors.scss" \
      --terminals "${enabled_terminals[@]}" &>/dev/null &
  fi
}

apply_qt() {
  sh "$CONFIG_DIR/scripts/kvantum/materialQT.sh"          # generate kvantum theme
  python "$CONFIG_DIR/scripts/kvantum/changeAdwColors.py" # apply config colors
}

apply_gtk_kde() {
  local scss_file="$STATE_DIR/user/generated/material_colors.scss"
  if [ ! -f "$scss_file" ]; then
    return
  fi

  # Extract colors from scss (format: $colorname: #hex;)
  get_color() {
    grep "^\$$1:" "$scss_file" | cut -d: -f2 | tr -d ' ;'
  }

  local bg=$(get_color "background")
  local fg=$(get_color "onBackground")
  local primary=$(get_color "primary")
  local on_primary=$(get_color "onPrimary")
  local surface=$(get_color "surface")
  local surface_dim=$(get_color "surfaceDim")

  # Call apply-gtk-theme.sh with extracted colors
  "$SCRIPT_DIR/apply-gtk-theme.sh" "$bg" "$fg" "$primary" "$on_primary" "$surface" "$surface_dim"
}

# Check if terminal theming is enabled in config
CONFIG_FILE="$XDG_CONFIG_HOME/illogical-impulse/config.json"
if [ -f "$CONFIG_FILE" ]; then
  enable_terminal=$(jq -r '.appearance.wallpaperTheming.enableTerminal' "$CONFIG_FILE")
  if [ "$enable_terminal" = "true" ]; then
    apply_term &
    apply_terminal_configs &
  fi
else
  echo "Config file not found at $CONFIG_FILE. Applying terminal theming by default."
  apply_term &
  apply_terminal_configs &
fi

# apply_qt & # Qt theming is already handled by kde-material-colors

# Apply GTK/KDE theming if enabled
if [ -f "$CONFIG_FILE" ]; then
  enable_apps_shell=$(jq -r '.appearance.wallpaperTheming.enableAppsAndShell // true' "$CONFIG_FILE")
  enable_qt_apps=$(jq -r '.appearance.wallpaperTheming.enableQtApps // true' "$CONFIG_FILE")
  if [ "$enable_apps_shell" != "false" ] || [ "$enable_qt_apps" != "false" ]; then
    apply_gtk_kde &
  fi
else
  apply_gtk_kde &
fi

# Apply SDDM theming if enabled
apply_sddm() {
  if [ -f "$CONFIG_DIR/scripts/sddm/sync-sddm-theme.py" ]; then
    python3 "$CONFIG_DIR/scripts/sddm/sync-sddm-theme.py" &
  fi
}

if [ -f "$CONFIG_FILE" ]; then
  enable_sddm=$(jq -r '.appearance.wallpaperTheming.enableSddm // false' "$CONFIG_FILE")
  if [ "$enable_sddm" = "true" ]; then
    apply_sddm &
  fi
fi
