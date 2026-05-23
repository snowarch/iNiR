#!/usr/bin/env bash
# scripts/setup/editors.sh
# /setup-editors — install a selected code editor/IDE.
#
# @meta name: Setup Code Editors
# @meta description: Choose and install VS Code, OSS Code, Zed, Cursor, or Neovim + LazyVim
# @meta icon: code
# @meta keywords: ide editor vscode code zed cursor neovim lazyvim aur arch
#
# Contributor guide:
# - Keep this script simple and single-file.
# - To add an editor, add one row to EDITORS below:
#     key|Display Name|arch repo packages|arch AUR packages|post install hook
# - Package lists are space-separated. Leave a field empty when unused.
# - Example:
#     "helix|Helix|helix||"
#     "some-editor|Some Editor||some-editor-bin|post_install_some_editor"
# - If extra setup is needed, add a small post_install_* function below.
#
# Current support:
# - Arch-like distros only, using pacman packages and/or AUR packages.
# - Other distros get an apology + support-coming-soon notice.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/_lib.sh"

# Add/edit supported editors here.
# Format: "key|Display Name|arch repo packages|arch AUR packages|post install hook"
EDITORS=(
    "vscode|VS Code||visual-studio-code-bin|"
    "oss-code|OSS Code||code|"
    "zed|Zed||zed-bin|"
    "cursor|Cursor||cursor-bin|"
    "neovim-lazyvim|Neovim + LazyVim||neovim git|post_install_lazyvim"
)

split_words_into_array() {
    local raw="$1"
    local -n out_ref="$2"
    out_ref=()
    [[ -z "$raw" ]] && return 0
    # Package names are expected to be whitespace-free tokens.
    # shellcheck disable=SC2206
    out_ref=($raw)
}

editor_field() {
    local row="$1" field_index="$2"
    local key label arch_repo arch_aur hook
    IFS='|' read -r key label arch_repo arch_aur hook <<< "$row"

    case "$field_index" in
        key) echo "$key" ;;
        label) echo "$label" ;;
        arch_repo) echo "$arch_repo" ;;
        arch_aur) echo "$arch_aur" ;;
        hook) echo "$hook" ;;
    esac
}

post_install_lazyvim() {
    local nvim_cfg nvim_data nvim_state nvim_cache
    nvim_cfg="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
    nvim_data="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
    nvim_state="${XDG_STATE_HOME:-$HOME/.local/state}/nvim"
    nvim_cache="${XDG_CACHE_HOME:-$HOME/.cache}/nvim"

    if [[ -d "$nvim_cfg" ]] || [[ -d "$nvim_data" ]] || [[ -d "$nvim_state" ]] || [[ -d "$nvim_cache" ]]; then
        echo "warning: Existing Neovim files detected; skipping LazyVim bootstrap to avoid overwriting your setup." >&2
        echo "         Back up/remove nvim dirs and rerun if you want the LazyVim starter." >&2
        return 0
    fi

    git clone https://github.com/LazyVim/starter "$nvim_cfg"
    rm -rf "$nvim_cfg/.git"
    echo "  · LazyVim starter installed to $nvim_cfg"
}

choose_editor_index() {
    local cancel_idx choice i row label arch_repo arch_aur details

    # This function returns only the selected array index on stdout; print the
    # interactive menu on stderr so command substitution does not capture it.
    echo >&2
    echo "Select one editor/IDE to install:" >&2
    for i in "${!EDITORS[@]}"; do
        row="${EDITORS[$i]}"
        label="$(editor_field "$row" label)"
        arch_repo="$(editor_field "$row" arch_repo)"
        arch_aur="$(editor_field "$row" arch_aur)"

        details=()
        [[ -n "$arch_repo" ]] && details+=("repo: $arch_repo")
        [[ -n "$arch_aur" ]] && details+=("aur: $arch_aur")

        if (( ${#details[@]} )); then
            printf '  %d) %s (%s)\n' "$((i + 1))" "$label" "$(IFS=', '; echo "${details[*]}")" >&2
        else
            printf '  %d) %s\n' "$((i + 1))" "$label" >&2
        fi
    done

    cancel_idx=$(( ${#EDITORS[@]} + 1 ))
    printf '  %d) Cancel\n\n' "$cancel_idx" >&2

    while true; do
        read -r -p "Enter choice [1-${cancel_idx}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= cancel_idx )); then
            break
        fi
        echo "Invalid choice. Please enter a number from 1 to ${cancel_idx}." >&2
    done

    if (( choice == cancel_idx )); then
        return 1
    fi

    echo "$((choice - 1))"
}

install_arch_editor() {
    local row="$1"
    local arch_repo arch_aur repo_pkgs aur_pkgs

    arch_repo="$(editor_field "$row" arch_repo)"
    arch_aur="$(editor_field "$row" arch_aur)"
    repo_pkgs=()
    aur_pkgs=()

    split_words_into_array "$arch_repo" repo_pkgs
    split_words_into_array "$arch_aur" aur_pkgs

    if (( ${#repo_pkgs[@]} == 0 )) && (( ${#aur_pkgs[@]} == 0 )); then
        echo "No Arch package mapping found for: $(editor_field "$row" label)" >&2
        return 1
    fi

    if (( ${#repo_pkgs[@]} )) && (( ${#aur_pkgs[@]} )); then
        install_arch "${repo_pkgs[@]}" -- "${aur_pkgs[@]}"
    elif (( ${#repo_pkgs[@]} )); then
        install_arch "${repo_pkgs[@]}"
    else
        install_arch -- "${aur_pkgs[@]}"
    fi
}

run_post_install_hook() {
    local row="$1"
    local hook label

    hook="$(editor_field "$row" hook)"
    label="$(editor_field "$row" label)"

    if [[ -n "$hook" ]]; then
        "$hook"
    else
        echo "  · No extra configuration required for ${label}."
    fi
}

setup_init "editors" "Setup Code Editors"

if ! is_arch_like; then
    TOTAL=1
    setup_progress 1 $TOTAL "Checking distro support"
    msg="Sorry — code editor setup currently supports Arch-based distros only. Support for other distros is coming soon."
    echo "$msg" >&2
    setup_fail "$msg"
    setup_finish_pause
    exit 0
fi

TOTAL=4
setup_progress 1 $TOTAL "Choose which editor/IDE to install"
if ! selected_index="$(choose_editor_index)"; then
    setup_progress 2 $TOTAL "No changes made"
    setup_done "Cancelled by user"
    setup_finish_pause
    exit 0
fi

selected_row="${EDITORS[$selected_index]}"
selected_name="$(editor_field "$selected_row" label)"

setup_progress 2 $TOTAL "Installing ${selected_name}"
install_arch_editor "$selected_row"

setup_progress 3 $TOTAL "Post-install configuration"
run_post_install_hook "$selected_row"

setup_progress 4 $TOTAL "Finalizing"
setup_done "${selected_name} setup complete"
setup_finish_pause
