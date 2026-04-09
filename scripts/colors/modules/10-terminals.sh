#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/module-runtime.sh"
COLOR_MODULE_ID="terminals"

SCSS_FILE="$STATE_DIR/user/generated/material_colors.scss"
PALETTE_FILE="$STATE_DIR/user/generated/palette.json"
TERMINAL_FILE="$STATE_DIR/user/generated/terminal.json"
SEQUENCES_TEMPLATE="$SCRIPT_DIR/terminal/sequences.txt"

# Known terminal emulators and their config keys.
# Maps /proc/*/comm name → config key under .appearance.wallpaperTheming.terminals
declare -A KNOWN_TERMINALS=(
  [kitty]=kitty
  [alacritty]=alacritty
  [foot]=foot
  [footclient]=foot
  [wezterm]=wezterm
  [wezterm-gui]=wezterm
  [ghostty]=ghostty
  [konsole]=konsole
)

# Walk /proc ancestor chain from $1 to find the terminal emulator.
# Returns the config key (e.g. "alacritty") or empty string if unknown.
find_terminal_ancestor() {
  local pid="$1"
  local visited=0
  while [[ "$pid" -gt 1 ]] && [[ $visited -lt 20 ]]; do
    local comm
    comm=$(< "/proc/$pid/comm" 2>/dev/null) || break
    [[ -n "$comm" ]] || break
    if [[ -n "$comm" && -n "${KNOWN_TERMINALS[$comm]+_}" ]]; then
      printf '%s\n' "${KNOWN_TERMINALS[$comm]}"
      return 0
    fi
    local ppid
    ppid=$(awk '/^PPid:/{print $2}' "/proc/$pid/status" 2>/dev/null) || break
    [[ "$ppid" != "$pid" ]] || break
    pid="$ppid"
    ((visited++))
  done
  return 1
}

# Check if a terminal has theming enabled in config.
# $1 = config key (e.g. "alacritty")
is_terminal_themed() {
  local term_key="$1"
  local enabled
  enabled=$(config_bool ".appearance.wallpaperTheming.terminals.${term_key}" true)
  [[ "$enabled" == 'true' ]]
}

apply_term_sequences() {
  [[ -f "$SEQUENCES_TEMPLATE" ]] || return 0
  mkdir -p "$STATE_DIR/user/generated/terminal"
  cp "$SEQUENCES_TEMPLATE" "$STATE_DIR/user/generated/terminal/sequences.txt"

  if [[ -f "$TERMINAL_FILE" ]] && command -v jq &>/dev/null; then
    local idx value
    for idx in $(seq 0 15); do
      value=$(jq -r ".term${idx} // empty" "$TERMINAL_FILE" 2>/dev/null || true)
      [[ -n "$value" ]] || continue
      sed -i "s/\$term${idx} #/${value#\#}/g" "$STATE_DIR/user/generated/terminal/sequences.txt"
    done
  else
    local color_names color_values
    mapfile -t color_names < <(cut -d: -f1 "$SCSS_FILE")
    mapfile -t color_values < <(cut -d: -f2 "$SCSS_FILE" | cut -d ' ' -f2 | cut -d ';' -f1)

    for i in "${!color_names[@]}"; do
      sed -i "s/${color_names[$i]} #/${color_values[$i]#\#}/g" "$STATE_DIR/user/generated/terminal/sequences.txt"
    done
  fi

  sed -i 's/\$alpha/100/g' "$STATE_DIR/user/generated/terminal/sequences.txt"

  local shell_pids
  shell_pids=$(pgrep -x 'fish|bash|zsh|nu|elvish|xonsh' 2>/dev/null || true)
  [[ -n "$shell_pids" ]] || return 0

  # Collect pts numbers grouped by their terminal emulator.
  # Only include pts devices whose terminal ancestor has theming enabled.
  local safe_pts=()
  for pid in $shell_pids; do
    [[ -d "/proc/$pid" ]] || continue

    local tty_link
    tty_link=$(readlink "/proc/$pid/fd/0" 2>/dev/null || true)
    [[ "$tty_link" =~ ^/dev/pts/([0-9]+)$ ]] || continue
    local pts_num="${BASH_REMATCH[1]}"

    # Deddup check
    local seen=false
    for existing in "${safe_pts[@]}"; do
      [[ "$existing" == "$pts_num" ]] && seen=true && break
    done
    $seen && continue

    # Identify which terminal emulator owns this shell
    local term_key
    term_key=$(find_terminal_ancestor "$pid") || {
      # Unknown terminal — send sequences (backwards compat)
      safe_pts+=("$pts_num")
      continue
    }

    # Skip if this terminal's theming is disabled
    is_terminal_themed "$term_key" || continue
    safe_pts+=("$pts_num")
  done

  for pts_num in "${safe_pts[@]}"; do
    local pts_file="/dev/pts/$pts_num"
    if [[ -w "$pts_file" ]]; then
      { cat "$STATE_DIR/user/generated/terminal/sequences.txt" > "$pts_file"; } & disown || true
    fi
  done
}

reload_terminal_colors() {
  local terminals=("$@")
  local home="$HOME"

  for term in "${terminals[@]}"; do
    case "$term" in
      kitty)
        pgrep -x kitty &>/dev/null && pkill --signal SIGUSR1 -x kitty 2>/dev/null || true
        ;;
      foot)
        pgrep -x foot &>/dev/null && pkill -USR1 foot 2>/dev/null || true
        ;;
      alacritty)
        pgrep -x alacritty &>/dev/null && [[ -f "$home/.config/alacritty/alacritty.toml" ]] && touch "$home/.config/alacritty/alacritty.toml" 2>/dev/null || true
        ;;
      wezterm)
        pgrep -x wezterm &>/dev/null && [[ -f "$home/.config/wezterm/wezterm.lua" ]] && touch "$home/.config/wezterm/wezterm.lua" 2>/dev/null || true
        ;;
      konsole)
        if pgrep -x konsole &>/dev/null && command -v qdbus6 &>/dev/null; then
          while IFS= read -r session; do
            qdbus6 org.kde.konsole "$session" org.kde.konsole.Session.setProfile 'ii-auto' 2>/dev/null || true
          done < <(qdbus6 org.kde.konsole 2>/dev/null | grep -E '/Sessions/[0-9]+$' || true)
        fi
        ;;
      btop)
        pgrep -x btop &>/dev/null && pkill -SIGUSR2 btop 2>/dev/null || true
        ;;
      omp)
        command -v oh-my-posh &>/dev/null && oh-my-posh enable reload &>/dev/null || true
        ;;
    esac
  done
}

apply_terminal_configs() {
  [[ -f "$SCSS_FILE" ]] || return 0

  local all_supported=(kitty alacritty foot wezterm ghostty konsole starship omp btop lazygit yazi)
  local enabled_terminals=()
  for term in "${all_supported[@]}"; do
    local enabled
    enabled=$(config_bool ".appearance.wallpaperTheming.terminals.${term}" true)
    local binary_name="$term"
    [[ "$term" == "omp" ]] && binary_name='oh-my-posh'
    [[ "$enabled" == 'true' ]] && command -v "$binary_name" &>/dev/null && enabled_terminals+=("$term")
  done

  [[ ${#enabled_terminals[@]} -gt 0 ]] || return 0

  local python_cmd
  python_cmd=$(venv_python)
  "$python_cmd" "$SCRIPT_DIR/generate_terminal_configs.py" --scss "$SCSS_FILE" --colors "$PALETTE_FILE" --terminal-json "$TERMINAL_FILE" --terminals "${enabled_terminals[@]}" >> "$STATE_DIR/user/generated/terminal_colors.log" 2>&1
  reload_terminal_colors "${enabled_terminals[@]}" >> "$STATE_DIR/user/generated/terminal_colors.log" 2>&1 &
}

main() {
  local enable_terminal
  enable_terminal=$(config_bool '.appearance.wallpaperTheming.enableTerminal' true)
  [[ "$enable_terminal" == 'true' ]] || exit 0
  [[ -f "$SCSS_FILE" ]] || exit 0
  apply_term_sequences &
  apply_terminal_configs &
  wait || true
}

main "$@"
