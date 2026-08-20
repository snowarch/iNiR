#!/usr/bin/env bash
# scripts/setup/terminals.sh
# /setup-terminals — install and set the default terminal emulator.
#
# @meta name: Setup Terminals
# @meta description: Install and set the default terminal emulator
# @meta icon: terminal
# @meta keywords: terminal kitty foot alacritty wezterm ghostty konsole
#
# --- Developer notes ---------------------------------------------------------
# To add a terminal, append one row to TERMINALS with this pipe-delimited format:
#   key|label|exec_prefix|arch_repo|arch_aur|fedora|flatpak
#
#   key         — short identifier used in config.json
#   label       — human-readable name shown in the menu
#   exec_prefix — command prefix used to launch the terminal with args
#   arch_repo   — space-separated Arch official repo packages (empty = none)
#   arch_aur    — space-separated AUR packages (empty = none)
#   fedora      — space-separated Fedora dnf packages (empty = none)
#   flatpak     — Flatpak app ID (empty = not available)
#
# Fallback chain:
#   Arch:   repo → AUR → Flatpak → error
#   Fedora: dnf  → Flatpak → error
#
# Set TRACE=1 to enable bash trace (set -x) for debugging.
# -----------------------------------------------------------------------------

[[ "${TRACE:-}" == "1" ]] && set -x
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/_lib.sh"

# -- Terminal definitions ------------------------------------------------------
TERMINALS=(
    "kitty|Kitty|kitty -e|kitty||kitty|com.termoneplus.kitty"
    "foot|Foot|foot|foot||foot|org.codeberg.dnkl.foot"
    "alacritty|Alacritty|alacritty -e|alacritty||alacritty|org.alacritty.Alacritty"
    "wezterm|WezTerm|wezterm start --|wezterm||wezterm|org.wezfurlong.wezterm"
    "ghostty|Ghostty|ghostty -e||ghostty||com.mitchellh.ghostty"
    "konsole|Konsole|konsole -e|konsole||konsole|org.kde.konsole"
)

# -- Field helper --------------------------------------------------------------
terminal_field() {
    local row="$1" field_index="$2"
    local key label exec_prefix arch_repo arch_aur fedora flatpak
    IFS='|' read -r key label exec_prefix arch_repo arch_aur fedora flatpak <<< "$row"

    case "$field_index" in
        key) echo "$key" ;;
        label) echo "$label" ;;
        exec_prefix) echo "$exec_prefix" ;;
        arch_repo) echo "$arch_repo" ;;
        arch_aur) echo "$arch_aur" ;;
        fedora) echo "$fedora" ;;
        flatpak) echo "$flatpak" ;;
    esac
}

# -- Package splitting helper --------------------------------------------------
split_words_into_array() {
    local raw="$1"
    local -n out_ref="$2"
    out_ref=()
    [[ -z "$raw" ]] && return 0
    # shellcheck disable=SC2206
    out_ref=($raw)
}

# -- Interactive selection -----------------------------------------------------
choose_terminal_index() {
    local count="${#TERMINALS[@]}"

    echo >&2
    echo "  ┌─────────────────────────────────────────────────────────────┐" >&2
    echo "  │  Choose a terminal emulator to install and set as default   │" >&2
    echo "  └─────────────────────────────────────────────────────────────┘" >&2
    echo >&2

    local i=0 row
    for row in "${TERMINALS[@]}"; do
        local label
        label="$(terminal_field "$row" label)"
        printf '  %d) %s\n' "$((i + 1))" "$label" >&2
        i=$((i + 1))
    done
    printf '  0) Cancel\n' >&2
    echo >&2

    local choice
    while true; do
        printf '  Enter choice [0-%d]: ' "$count" >&2
        read -r choice
        if [[ "$choice" == "0" ]]; then
            return 1
        fi
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= count )); then
            echo "$((choice - 1))"
            return 0
        fi
        echo "  Invalid choice. Please try again." >&2
    done
}

# -- Install function ---------------------------------------------------------
# Arch fallback chain: repo → AUR → Flatpak → error
# Fedora fallback chain: dnf → Flatpak → error
install_terminal() {
    local row="$1"
    local label flatpak_id
    label="$(terminal_field "$row" label)"
    flatpak_id="$(terminal_field "$row" flatpak)"

    if is_arch_like; then
        # 1. Try official repo
        local repo_pkgs_raw
        repo_pkgs_raw="$(terminal_field "$row" arch_repo)"
        local repo_pkgs=()
        split_words_into_array "$repo_pkgs_raw" repo_pkgs

        # 2. Try AUR
        local aur_pkgs_raw
        aur_pkgs_raw="$(terminal_field "$row" arch_aur)"
        local aur_pkgs=()
        split_words_into_array "$aur_pkgs_raw" aur_pkgs

        if (( ${#repo_pkgs[@]} )) && (( ${#aur_pkgs[@]} )); then
            echo "  · Installing ${label} (repo + AUR)…"
            install_arch "${repo_pkgs[@]}" -- "${aur_pkgs[@]}"
            return 0
        elif (( ${#repo_pkgs[@]} )); then
            echo "  · Installing ${label} (repo)…"
            install_arch "${repo_pkgs[@]}"
            return 0
        elif (( ${#aur_pkgs[@]} )); then
            echo "  · Installing ${label} (AUR)…"
            install_arch -- "${aur_pkgs[@]}"
            return 0
        fi

        # 3. Flatpak fallback
        if [[ -n "$flatpak_id" ]]; then
            echo "  · Installing ${label} via Flatpak…"
            install_flatpak "$flatpak_id"
            return 0
        fi

        setup_fail "${label} has no repo, AUR, or Flatpak mapping for Arch."
        setup_finish_pause
        exit 1

    else
        # Assume Fedora (or any dnf-based distro)
        local fedora_pkgs_raw
        fedora_pkgs_raw="$(terminal_field "$row" fedora)"
        local fedora_pkgs=()
        split_words_into_array "$fedora_pkgs_raw" fedora_pkgs

        if (( ${#fedora_pkgs[@]} )); then
            echo "  · Installing ${label} via dnf…"
            sudo dnf install -y "${fedora_pkgs[@]}"
            return 0
        fi

        # Flatpak fallback
        if [[ -n "$flatpak_id" ]]; then
            echo "  · Installing ${label} via Flatpak…"
            install_flatpak "$flatpak_id"
            return 0
        fi

        setup_fail "${label} has no dnf or Flatpak mapping for ${DISTRO_ID}."
        setup_finish_pause
        exit 1
    fi
}

# -- Config update function ----------------------------------------------------
update_terminal_config() {
    local row="$1"
    local key exec_prefix
    key="$(terminal_field "$row" key)"
    exec_prefix="$(terminal_field "$row" exec_prefix)"

    if ! have_cmd jq; then
        setup_fail "jq is required to update the configuration but is not installed."
        setup_finish_pause
        exit 1
    fi

    local config_path="${XDG_CONFIG_HOME:-$HOME/.config}/illogical-impulse/config.json"
    if [[ ! -f "$config_path" ]]; then
        setup_fail "Config file not found at $config_path"
        setup_finish_pause
        exit 1
    fi

    local tmp_config
    tmp_config="$(mktemp)"
    trap 'rm -f "$tmp_config"' EXIT

    jq --arg key "$key" --arg update_cmd "$exec_prefix arch-update" \
        '.apps.terminal = $key | .apps.update = $update_cmd' \
        "$config_path" > "$tmp_config"

    # If config is a symlink, overwrite the target instead of replacing the symlink
    if [[ -L "$config_path" ]]; then
        config_path="$(readlink -f "$config_path")"
    fi
    mv "$tmp_config" "$config_path"
    trap - EXIT
}

# -- Verification helper -------------------------------------------------------
verify_terminal_command() {
    local row="$1"
    local key
    key="$(terminal_field "$row" key)"

    if ! have_cmd "$key"; then
        echo "warning: $key is not in PATH yet. You may need to log out and back in, or open a new terminal." >&2
    fi
}

# -- Main flow -----------------------------------------------------------------
setup_init "terminals" "Setup Terminals"

TOTAL=4
setup_progress 1 "$TOTAL" "Choose terminal emulator"
if ! selected_index="$(choose_terminal_index)"; then
    setup_progress 2 "$TOTAL" "No changes made"
    setup_done "Cancelled by user"
    setup_finish_pause
    exit 0
fi

selected_row="${TERMINALS[$selected_index]}"
selected_name="$(terminal_field "$selected_row" label)"

setup_progress 2 "$TOTAL" "Installing ${selected_name}"
install_terminal "$selected_row"

setup_progress 3 "$TOTAL" "Updating iNiR default terminal"
update_terminal_config "$selected_row"
verify_terminal_command "$selected_row"

setup_progress 4 "$TOTAL" "Finalizing"
setup_done "${selected_name} is now the default iNiR terminal"
setup_finish_pause
