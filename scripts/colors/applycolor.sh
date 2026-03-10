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
  local all_supported=(kitty alacritty foot wezterm ghostty konsole starship omp btop lazygit yazi)

  # Build enabled list: config-enabled (default true) AND installed
  local enabled_terminals=()
  for term in "${all_supported[@]}"; do
    local term_enabled="true"
    if [ -f "$CONFIG_FILE" ]; then
      term_enabled=$(jq -r ".appearance.wallpaperTheming.terminals.${term} // true" "$CONFIG_FILE" 2>/dev/null || echo "true")
    fi

    local binary_name="$term"
    [[ "$term" == "omp" ]] && binary_name="oh-my-posh"

    [[ "$term_enabled" == "true" ]] && command -v "$binary_name" &>/dev/null && enabled_terminals+=("$term")
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
        # Kitty: SIGUSR1 triggers config reload (updates all windows and tab bar)
        if pgrep -x kitty &>/dev/null; then
          pkill --signal SIGUSR1 -x kitty 2>/dev/null && \
            echo "[terminal-colors] Kitty: sent SIGUSR1 reload signal"
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
      btop)
        if pgrep -x btop &>/dev/null; then
          pkill -SIGUSR2 btop 2>/dev/null && \
            echo "[terminal-colors] btop: sent SIGUSR2 reload signal"
        fi
        ;;
      omp)
        if command -v oh-my-posh &>/dev/null; then
          oh-my-posh enable reload &>/dev/null
          echo "[terminal-colors] oh-my-posh: reload enabled (config will auto-reload)"
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
  # Generate code editor themes (Zed, VSCode, etc.)
  local log_file="$STATE_DIR/user/generated/code_editor_themes.log"

  if [ ! -f "$STATE_DIR/user/generated/material_colors.scss" ]; then
    echo "[code-editors] material_colors.scss not found. Skipping." | tee -a "$log_file" 2>/dev/null
    return
  fi

  # Get Python command
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

  if ! command -v "$python_cmd" &>/dev/null && [[ ! -x "$python_cmd" ]]; then
    echo "[code-editors] ERROR: Python not found ($python_cmd). Cannot generate themes." >> "$log_file" 2>/dev/null
    return
  fi

  # Check if Zed is installed and enabled
  local enable_zed="true"
  if [ -f "$CONFIG_FILE" ]; then
    enable_zed=$(jq -r 'if .appearance.wallpaperTheming | has("enableZed") then .appearance.wallpaperTheming.enableZed else true end' "$CONFIG_FILE" 2>/dev/null || echo "true")
  fi

  if [[ "$enable_zed" == "true" ]] && { command -v zed &>/dev/null || command -v zeditor &>/dev/null; }; then
    echo "[code-editors] Generating Zed theme..." | tee -a "$log_file" 2>/dev/null
    "$python_cmd" "$SCRIPT_DIR/generate_terminal_configs.py" \
      --scss "$STATE_DIR/user/generated/material_colors.scss" \
      --zed >> "$log_file" 2>&1

    if [ $? -eq 0 ]; then
      echo "[code-editors] Zed theme generated (Zed auto-reloads on file change)" >> "$log_file" 2>/dev/null
    else
      echo "[code-editors] ERROR: Failed to generate Zed theme" >> "$log_file" 2>/dev/null
    fi
  fi

  # Check if VSCode editors are enabled
  local enable_vscode="true"
  if [ -f "$CONFIG_FILE" ]; then
    enable_vscode=$(jq -r 'if .appearance.wallpaperTheming | has("enableVSCode") then .appearance.wallpaperTheming.enableVSCode else true end' "$CONFIG_FILE" 2>/dev/null || echo "true")
  fi

  if [[ "$enable_vscode" == "true" ]]; then
    # Build list of enabled forks from config
    local enabled_forks=()
    if [ -f "$CONFIG_FILE" ]; then
      # Read individual fork settings, default to true if not specified
      local editors_config
      editors_config=$(jq -r '.appearance.wallpaperTheming.vscodeEditors // {}' "$CONFIG_FILE" 2>/dev/null || echo "{}")
      
      # Map config keys to script fork keys
      [[ $(echo "$editors_config" | jq -r '.code // true') == "true" ]] && [[ -d "$HOME/.config/Code" ]] && enabled_forks+=("code")
      [[ $(echo "$editors_config" | jq -r '.codium // true') == "true" ]] && [[ -d "$HOME/.config/VSCodium" ]] && enabled_forks+=("codium")
      [[ $(echo "$editors_config" | jq -r '.codeOss // true') == "true" ]] && [[ -d "$HOME/.config/Code - OSS" ]] && enabled_forks+=("code-oss")
      [[ $(echo "$editors_config" | jq -r '.codeInsiders // true') == "true" ]] && [[ -d "$HOME/.config/Code - Insiders" ]] && enabled_forks+=("code-insiders")
      [[ $(echo "$editors_config" | jq -r '.cursor // true') == "true" ]] && [[ -d "$HOME/.config/Cursor" ]] && enabled_forks+=("cursor")
      [[ $(echo "$editors_config" | jq -r '.windsurf // true') == "true" ]] && [[ -d "$HOME/.config/Windsurf" ]] && enabled_forks+=("windsurf")
      [[ $(echo "$editors_config" | jq -r '.windsurfNext // true') == "true" ]] && [[ -d "$HOME/.config/Windsurf - Next" ]] && enabled_forks+=("windsurf-next")
      [[ $(echo "$editors_config" | jq -r '.qoder // true') == "true" ]] && [[ -d "$HOME/.config/Qoder" ]] && enabled_forks+=("qoder")
      [[ $(echo "$editors_config" | jq -r '.antigravity // true') == "true" ]] && [[ -d "$HOME/.config/Antigravity" ]] && enabled_forks+=("antigravity")
      [[ $(echo "$editors_config" | jq -r '.positron // true') == "true" ]] && [[ -d "$HOME/.config/Positron" ]] && enabled_forks+=("positron")
      [[ $(echo "$editors_config" | jq -r '.voidEditor // true') == "true" ]] && [[ -d "$HOME/.config/Void" ]] && enabled_forks+=("void")
      [[ $(echo "$editors_config" | jq -r '.melty // true') == "true" ]] && [[ -d "$HOME/.config/Melty" ]] && enabled_forks+=("melty")
      [[ $(echo "$editors_config" | jq -r '.pearai // true') == "true" ]] && [[ -d "$HOME/.config/PearAI" ]] && enabled_forks+=("pearai")
      [[ $(echo "$editors_config" | jq -r '.aide // true') == "true" ]] && [[ -d "$HOME/.config/Aide" ]] && enabled_forks+=("aide")
    fi

    if [ ${#enabled_forks[@]} -gt 0 ]; then
      echo "[code-editors] Generating VSCode themes for: ${enabled_forks[*]}" | tee -a "$log_file" 2>/dev/null
      "$python_cmd" "$SCRIPT_DIR/generate_terminal_configs.py" \
        --scss "$STATE_DIR/user/generated/material_colors.scss" \
        --vscode --vscode-forks "${enabled_forks[@]}" >> "$log_file" 2>&1

      if [ $? -eq 0 ]; then
        echo "[code-editors] VSCode themes generated (auto-reloads instantly)" >> "$log_file" 2>/dev/null
      else
        echo "[code-editors] ERROR: Failed to generate VSCode themes" >> "$log_file" 2>/dev/null
      fi
    else
      echo "[code-editors] No enabled VSCode forks found" >> "$log_file" 2>/dev/null
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
  # apply-chrome-theme.sh applies GM3 BrowserThemeColor to Chromium-based browsers
  # Supports: Google Chrome, Chromium, Brave (and Omarchy fork with CLI theming)
  "$SCRIPT_DIR/apply-chrome-theme.sh"
}

apply_spicetify() {
  # apply-spicetify-theme.sh creates/updates a dedicated Spicetify theme from colors.json
  "$SCRIPT_DIR/apply-spicetify-theme.sh"
}

# Check if terminal theming is enabled in config
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/illogical-impulse/config.json"
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

# Apply OpenCode TUI theme
apply_opencode_theme() {
  local log_file="$STATE_DIR/user/generated/code_editor_themes.log"
  local scss_file="$STATE_DIR/user/generated/material_colors.scss"
  local generator="$SCRIPT_DIR/opencode/theme_generator.py"

  if [ ! -f "$scss_file" ]; then
    return
  fi

  if [ ! -f "$generator" ]; then
    return
  fi

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

  "$python_cmd" "$generator" "$scss_file" >> "$log_file" 2>&1
}

if [ -f "$CONFIG_FILE" ]; then
  enable_opencode=$(jq -r '.appearance.wallpaperTheming.enableOpenCode // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
  if [ "$enable_opencode" = "true" ] && command -v opencode &>/dev/null; then
    apply_opencode_theme &
  fi
else
  if command -v opencode &>/dev/null; then
    apply_opencode_theme &
  fi
fi

# Apply Chrome/Chromium/Brave GM3 theme via managed policies
if [ -f "$CONFIG_FILE" ]; then
  enable_chrome=$(jq -r '.appearance.wallpaperTheming.enableChrome // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
  if [ "$enable_chrome" = "true" ]; then
    apply_chrome &
  fi
else
  apply_chrome &
fi

# Apply Spotify theme via Spicetify (opt-in)
if [ -f "$CONFIG_FILE" ]; then
  enable_spicetify=$(jq -r '.appearance.wallpaperTheming.enableSpicetify // false' "$CONFIG_FILE" 2>/dev/null || echo "false")
  if [ "$enable_spicetify" = "true" ] && command -v spicetify &>/dev/null; then
    apply_spicetify &
  fi
fi

# Sync ii-pixel SDDM theme colors (if installed)
SDDM_SYNC_SCRIPT="$SCRIPT_DIR/../sddm/sync-pixel-sddm.py"
if [[ -d "/usr/share/sddm/themes/ii-pixel" && -f "$SDDM_SYNC_SCRIPT" ]]; then
  python3 "$SDDM_SYNC_SCRIPT" &
fi
