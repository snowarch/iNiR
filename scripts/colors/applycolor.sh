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

  # Only write OSC sequences to PTYs that have an interactive shell (fish, bash, zsh, etc.)
  # Writing to non-shell PTYs (quickshell, IDE, cat, etc.) can crash those processes
  local seq_file="$STATE_DIR/user/generated/terminal/sequences.txt"
  local shell_pids
  shell_pids=$(pgrep -x "fish|bash|zsh|nu|elvish|xonsh" 2>/dev/null || true)

  if [[ -z "$shell_pids" ]]; then
    return
  fi

  # Build a set of safe PTY numbers from interactive shells
  local safe_pts=()
  for pid in $shell_pids; do
    # Get the controlling terminal of the shell process
    local tty_nr
    tty_nr=$(readlink /proc/"$pid"/fd/0 2>/dev/null || true)
    if [[ "$tty_nr" =~ ^/dev/pts/([0-9]+)$ ]]; then
      local pts_num="${BASH_REMATCH[1]}"
      # Avoid duplicates
      local already=false
      for existing in "${safe_pts[@]}"; do
        [[ "$existing" == "$pts_num" ]] && already=true && break
      done
      $already || safe_pts+=("$pts_num")
    fi
  done

  # Write sequences only to PTYs with interactive shells
  for pts_num in "${safe_pts[@]}"; do
    local pts_file="/dev/pts/$pts_num"
    if [[ -w "$pts_file" ]]; then
      {
        cat "$seq_file" > "$pts_file"
      } & disown || true
    fi
  done
}

apply_terminal_configs() {
  # Generate terminal-specific config files (Kitty, Alacritty, Foot, WezTerm, Ghostty, Konsole)
  local log_file="$STATE_DIR/user/generated/terminal_colors.log"
  
  if [ ! -f "$STATE_DIR/user/generated/material_colors.scss" ]; then
    echo "[terminal-colors] material_colors.scss not found. Skipping." | tee -a "$log_file" 2>/dev/null
    return
  fi

  # Get enabled terminals from config, but only if actually installed
  local enabled_terminals=()
  if [ -f "$CONFIG_FILE" ]; then
    local enable_kitty=$(jq -r '.appearance.wallpaperTheming.terminals.kitty // true' "$CONFIG_FILE")
    local enable_alacritty=$(jq -r '.appearance.wallpaperTheming.terminals.alacritty // true' "$CONFIG_FILE")
    local enable_foot=$(jq -r '.appearance.wallpaperTheming.terminals.foot // true' "$CONFIG_FILE")
    local enable_wezterm=$(jq -r '.appearance.wallpaperTheming.terminals.wezterm // true' "$CONFIG_FILE")
    local enable_ghostty=$(jq -r '.appearance.wallpaperTheming.terminals.ghostty // true' "$CONFIG_FILE")
    local enable_konsole=$(jq -r '.appearance.wallpaperTheming.terminals.konsole // true' "$CONFIG_FILE")
    local enable_starship=$(jq -r '.appearance.wallpaperTheming.terminals.starship // true' "$CONFIG_FILE")

    # Only add terminals that are both enabled AND installed
    [[ "$enable_kitty" == "true" ]] && command -v kitty &>/dev/null && enabled_terminals+=(kitty)
    [[ "$enable_alacritty" == "true" ]] && command -v alacritty &>/dev/null && enabled_terminals+=(alacritty)
    [[ "$enable_foot" == "true" ]] && command -v foot &>/dev/null && enabled_terminals+=(foot)
    [[ "$enable_wezterm" == "true" ]] && command -v wezterm &>/dev/null && enabled_terminals+=(wezterm)
    [[ "$enable_ghostty" == "true" ]] && command -v ghostty &>/dev/null && enabled_terminals+=(ghostty)
    [[ "$enable_konsole" == "true" ]] && command -v konsole &>/dev/null && enabled_terminals+=(konsole)
    [[ "$enable_starship" == "true" ]] && command -v starship &>/dev/null && enabled_terminals+=(starship)
  else
    # Default: only generate for installed terminals + starship
    for term in kitty alacritty foot wezterm ghostty konsole starship; do
      command -v "$term" &>/dev/null && enabled_terminals+=("$term")
    done
  fi

  if [ ${#enabled_terminals[@]} -eq 0 ]; then
    echo "[terminal-colors] No enabled terminals found installed. Skipping." >> "$log_file" 2>/dev/null
    return
  fi

  # Run the Python script to generate configs
  local python_cmd="python3"
  local venv_python="${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-$HOME/.local/state/quickshell/.venv}/bin/python"
  if [[ -x "$venv_python" ]]; then
    python_cmd="$venv_python"
  fi

  if command -v "$python_cmd" &>/dev/null || [[ -x "$python_cmd" ]]; then
    echo "[terminal-colors] Generating configs for: ${enabled_terminals[*]}" >> "$log_file" 2>/dev/null
    "$python_cmd" "$SCRIPT_DIR/generate_terminal_configs.py" \
      --scss "$STATE_DIR/user/generated/material_colors.scss" \
      --terminals "${enabled_terminals[@]}" >> "$log_file" 2>&1

    # Reload running terminals so colors update in real-time
    reload_terminal_colors "${enabled_terminals[@]}" >> "$log_file" 2>&1 &
  else
    echo "[terminal-colors] ERROR: Python not found ($python_cmd). Cannot generate terminal configs." >> "$log_file" 2>/dev/null
  fi
}

reload_terminal_colors() {
  local terminals=("$@")
  local home="$HOME"

  for term in "${terminals[@]}"; do
    case "$term" in
      kitty)
        # Kitty: reload colors via remote control (works if allow_remote_control is enabled)
        if pgrep -x kitty &>/dev/null; then
          kitty @ set-colors --all "$home/.config/kitty/current-theme.conf" 2>/dev/null && \
            echo "[terminal-colors] Kitty: reloaded via remote control" || \
            echo "[terminal-colors] Kitty: remote control not available (enable allow_remote_control in kitty.conf for live reload)"
        fi
        ;;
      foot)
        # Foot: SIGUSR1 triggers config reload
        if pgrep -x foot &>/dev/null; then
          pkill -USR1 foot 2>/dev/null && \
            echo "[terminal-colors] Foot: sent SIGUSR1 reload signal"
        fi
        ;;
      alacritty)
        # Alacritty: auto-reloads on config file change (built-in file watcher)
        # Just touch the main config to trigger the watcher if import didn't trigger it
        if pgrep -x alacritty &>/dev/null && [ -f "$home/.config/alacritty/alacritty.toml" ]; then
          touch "$home/.config/alacritty/alacritty.toml" 2>/dev/null
          echo "[terminal-colors] Alacritty: touched config to trigger auto-reload"
        fi
        ;;
      wezterm)
        # WezTerm: auto-reloads on config change (built-in file watcher)
        # Touch config to ensure watcher triggers
        if pgrep -x wezterm &>/dev/null && [ -f "$home/.config/wezterm/wezterm.lua" ]; then
          touch "$home/.config/wezterm/wezterm.lua" 2>/dev/null
          echo "[terminal-colors] WezTerm: touched config to trigger auto-reload"
        fi
        ;;
      ghostty)
        # Ghostty: does NOT support SIGUSR1 reload (as of v1.x)
        # Config reload is only via Ctrl+Shift+, keyboard shortcut
        # Colors will apply on next new window/tab or manual reload
        if pgrep -x ghostty &>/dev/null; then
          echo "[terminal-colors] Ghostty: config updated (press Ctrl+Shift+, to reload, or open new window)"
        fi
        ;;
      konsole)
        # Konsole: Use qdbus to reload profile if available
        if pgrep -x konsole &>/dev/null; then
          # Try to reload via DBus (works in some versions)
          if command -v qdbus6 &>/dev/null; then
            for session in $(qdbus6 org.kde.konsole 2>/dev/null | grep -E '/Sessions/[0-9]+$'); do
              qdbus6 org.kde.konsole "$session" org.kde.konsole.Session.setProfile "ii-auto" 2>/dev/null
            done
            echo "[terminal-colors] Konsole: attempted profile reload via DBus"
          else
            echo "[terminal-colors] Konsole: colors will apply on next new tab/session"
          fi
        fi
        ;;
    esac
  done
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
  enable_terminal=$(jq -r '.appearance.wallpaperTheming.enableTerminal // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
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
