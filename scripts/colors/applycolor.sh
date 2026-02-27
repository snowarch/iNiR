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

  # Single source of truth for all supported targets.
  # Mirrors TERMINAL_REGISTRY in generate_terminal_configs.py.
  # To add a new target: add it here + add generate_X_config() and registry entry in the Python script.
  local all_supported=(kitty alacritty foot wezterm ghostty konsole starship btop lazygit yazi)

  # Build enabled list: config-enabled (default true) AND installed
  local enabled_terminals=()
  for term in "${all_supported[@]}"; do
    local term_enabled="true"
    if [ -f "$CONFIG_FILE" ]; then
      term_enabled=$(jq -r ".appearance.wallpaperTheming.terminals.${term} // true" "$CONFIG_FILE" 2>/dev/null || echo "true")
    fi

    [[ "$term_enabled" == "true" ]] && command -v "$term" &>/dev/null && enabled_terminals+=("$term")
  done

  if [ ${#enabled_terminals[@]} -eq 0 ]; then
    echo "[terminal-colors] No enabled terminals found installed. Skipping." >> "$log_file" 2>/dev/null
    return
  fi

  # Run the Python script to generate configs
  local python_cmd="python3"
  local _ac_venv
  if [[ -n "${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-}" ]]; then
    _ac_venv="$(eval echo "$ILLOGICAL_IMPULSE_VIRTUAL_ENV")"
  else
    _ac_venv="$HOME/.local/state/quickshell/.venv"
  fi
  local venv_python="$_ac_venv/bin/python3"
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

apply_code_editors() {
  # Generate code editor themes (Zed, VSCode, etc.) and update Zed settings
  local log_file="$STATE_DIR/user/generated/code_editor_themes.log"

  if [ ! -f "$STATE_DIR/user/generated/material_colors.scss" ]; then
    echo "[code-editors] material_colors.scss not found. Skipping." | tee -a "$log_file" 2>/dev/null
    return
  fi

  # Check if Zed is installed and enabled
  local enable_zed="true"
  if [ -f "$CONFIG_FILE" ]; then
    enable_zed=$(jq -r '.appearance.wallpaperTheming.enableZed // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
  fi

  if [[ "$enable_zed" == "true" ]] && { command -v zed &>/dev/null || command -v zeditor &>/dev/null; }; then
    echo "[code-editors] Generating Zed theme..." | tee -a "$log_file" 2>/dev/null

    # Run the Python script to generate Zed config
    local python_cmd="python3"
    local _ac_venv
    if [[ -n "${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-}" ]]; then
      _ac_venv="$(eval echo "$ILLOGICAL_IMPULSE_VIRTUAL_ENV")"
    else
      _ac_venv="$HOME/.local/state/quickshell/.venv"
    fi
    local venv_python="$_ac_venv/bin/python3"
    if [[ -x "$venv_python" ]]; then
      python_cmd="$venv_python"
    fi

    if command -v "$python_cmd" &>/dev/null || [[ -x "$python_cmd" ]]; then
      "$python_cmd" "$SCRIPT_DIR/generate_terminal_configs.py" \
        --scss "$STATE_DIR/user/generated/material_colors.scss" \
        --zed >> "$log_file" 2>&1

      if [ $? -eq 0 ]; then
        echo "[code-editors] Zed theme generated (Zed auto-reloads on file change)" >> "$log_file" 2>/dev/null
      else
        echo "[code-editors] ERROR: Failed to generate Zed theme" >> "$log_file" 2>/dev/null
      fi
    else
      echo "[code-editors] ERROR: Python not found ($python_cmd). Cannot generate Zed theme." >> "$log_file" 2>/dev/null
    fi
  fi
}

apply_gtk_kde() {
  # apply-gtk-theme.sh reads colors.json (matugen's output) directly
  # It generates: kdeglobals, Darkly.colors, pywalfox colors
  # GTK CSS is handled by matugen templates
  "$SCRIPT_DIR/apply-gtk-theme.sh"
}

apply_chrome() {
  # Apply Chrome/Chromium/Brave theme via managed policies using GM3 BrowserThemeColor
  # Chrome 142+ supports --refresh-platform-policy for instant theme application
  # Brave cherry-picked this for their Chrome 141-based release
  #
  # How it works:
  #   1. Write BrowserThemeColor policy to /etc/<browser>/policies/managed/
  #   2. Chrome's GM3 engine uses this as the seed color for its full Material Design 3 palette
  #   3. --refresh-platform-policy forces Chrome to re-read policies from disk instantly
  #   4. No browser restart needed — colors update in real-time
  local log_file="$STATE_DIR/user/generated/chrome_theme.log"
  : > "$log_file" 2>/dev/null

  local colors_json="$STATE_DIR/user/generated/colors.json"
  local scss_file="$STATE_DIR/user/generated/material_colors.scss"

  # Extract primary color for GM3 seed — prefer colors.json, fall back to SCSS
  local primary_color=""
  if [[ -f "$colors_json" ]] && command -v jq &>/dev/null; then
    primary_color=$(jq -r '.primary // empty' "$colors_json" 2>/dev/null)
  fi
  if [[ -z "$primary_color" && -f "$scss_file" ]]; then
    primary_color=$(grep '^\$primary:' "$scss_file" | sed 's/.*: *\(#[A-Fa-f0-9]\{6\}\).*/\1/')
  fi

  if [[ -z "$primary_color" ]]; then
    echo "[chrome] Could not determine primary color. Skipping." >> "$log_file"
    return
  fi

  echo "[chrome] GM3 seed color: $primary_color" >> "$log_file"

  # Build the managed policy JSON
  # BrowserThemeColor sets the GM3 seed — Chrome generates the full Material palette from it
  local policy_json="{
  \"BrowserThemeColor\": \"$primary_color\"
}"

  # Browser detection: binary names -> policy directories (Linux paths)
  local -a browser_names=()
  local -a browser_bins=()
  local -a policy_dirs=()

  # Google Chrome
  if command -v google-chrome-stable &>/dev/null; then
    browser_names+=("Google Chrome")
    browser_bins+=("google-chrome-stable")
    policy_dirs+=("/etc/opt/chrome/policies/managed")
  elif command -v google-chrome &>/dev/null; then
    browser_names+=("Google Chrome")
    browser_bins+=("google-chrome")
    policy_dirs+=("/etc/opt/chrome/policies/managed")
  fi

  # Chromium
  if command -v chromium &>/dev/null; then
    browser_names+=("Chromium")
    browser_bins+=("chromium")
    policy_dirs+=("/etc/chromium/policies/managed")
  elif command -v chromium-browser &>/dev/null; then
    browser_names+=("Chromium")
    browser_bins+=("chromium-browser")
    policy_dirs+=("/etc/chromium/policies/managed")
  fi

  # Brave
  if command -v brave &>/dev/null; then
    browser_names+=("Brave")
    browser_bins+=("brave")
    policy_dirs+=("/etc/brave/policies/managed")
  elif command -v brave-browser &>/dev/null; then
    browser_names+=("Brave")
    browser_bins+=("brave-browser")
    policy_dirs+=("/etc/brave/policies/managed")
  fi

  if [[ ${#browser_names[@]} -eq 0 ]]; then
    echo "[chrome] No Chromium-based browsers found. Skipping." >> "$log_file"
    return
  fi

  local any_applied=false
  local -a setup_needed=()

  for idx in "${!browser_names[@]}"; do
    local name="${browser_names[$idx]}"
    local bin="${browser_bins[$idx]}"
    local policy_dir="${policy_dirs[$idx]}"
    local policy_file="$policy_dir/ii-theme.json"

    if [[ -d "$policy_dir" && -w "$policy_dir" ]]; then
      # Policy dir exists and is writable — write directly
      if echo "$policy_json" > "$policy_file" 2>/dev/null; then
        echo "[chrome] Wrote GM3 theme policy for $name -> $policy_file" >> "$log_file"
        any_applied=true

        # Instant-apply via --refresh-platform-policy (Chrome 142+ / Brave 141+)
        # --no-startup-window prevents opening a new window if browser is already running
        if pgrep -f "$bin" &>/dev/null 2>&1; then
          {
            "$bin" --refresh-platform-policy --no-startup-window 2>/dev/null
          } & disown || true
          echo "[chrome] Sent --refresh-platform-policy to $name" >> "$log_file"
        else
          echo "[chrome] $name not running — theme will apply on next launch" >> "$log_file"
        fi
      else
        echo "[chrome] Failed to write $policy_file despite dir being writable" >> "$log_file"
      fi
    else
      # Policy dir missing or not writable — record setup command
      setup_needed+=("$name|$policy_dir")
      echo "[chrome] Policy dir not accessible for $name: $policy_dir" >> "$log_file"
    fi
  done

  # Provide one-time setup instructions for browsers that need it
  if [[ ${#setup_needed[@]} -gt 0 ]]; then
    echo "[chrome] ---" >> "$log_file"
    echo "[chrome] One-time setup needed for managed policies:" >> "$log_file"
    for entry in "${setup_needed[@]}"; do
      local name="${entry%%|*}"
      local dir="${entry##*|}"
      echo "[chrome]   $name: sudo mkdir -p \"$dir\" && sudo chown \"\$USER\" \"$dir\"" >> "$log_file"
    done
    echo "[chrome] After setup, wallpaper theming will auto-apply to Chrome/Chromium." >> "$log_file"

    # Send a one-time desktop notification if notify-send is available and this is the first failure
    local notified_flag="$STATE_DIR/user/generated/.chrome_policy_notified"
    if [[ ! -f "$notified_flag" ]] && command -v notify-send &>/dev/null; then
      local setup_cmds=""
      for entry in "${setup_needed[@]}"; do
        local dir="${entry##*|}"
        setup_cmds+="sudo mkdir -p $dir && sudo chown \$USER $dir\n"
      done
      notify-send -u normal \
        "iNiR: Chrome theme setup needed" \
        "Run in terminal to enable auto-theming:\n$(echo -e "$setup_cmds")" \
        2>/dev/null || true
      touch "$notified_flag" 2>/dev/null
    fi
  fi
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


# Apply code editor themes (Zed, etc.)
apply_code_editors &

# Apply Chrome/Chromium/Brave GM3 theme via managed policies
if [ -f "$CONFIG_FILE" ]; then
  enable_chrome=$(jq -r '.appearance.wallpaperTheming.enableChrome // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
  if [ "$enable_chrome" = "true" ]; then
    apply_chrome &
  fi
else
  apply_chrome &
fi

# Sync ii-pixel SDDM theme colors (if installed)
SDDM_SYNC_SCRIPT="$SCRIPT_DIR/../sddm/sync-pixel-sddm.py"
if [[ -d "/usr/share/sddm/themes/ii-pixel" && -f "$SDDM_SYNC_SCRIPT" ]]; then
  python3 "$SDDM_SYNC_SCRIPT" &
fi
