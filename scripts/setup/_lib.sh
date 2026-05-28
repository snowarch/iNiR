#!/usr/bin/env bash
# scripts/setup/_lib.sh
# Shared helpers for /setup recipes invoked from GlobalActions.
#
# Sourced by every recipe script. Provides:
#   - distro detection         (DISTRO_ID, DISTRO_LIKE, is_arch_like)
#   - progress notifications   (setup_notify, setup_progress, setup_done, setup_fail)
#   - command/package helpers  (have_cmd, ensure_aur_helper, install_arch, install_flatpak)
#   - developer-friendly error reporting (_setup_err_trap, stack trace, TRACE mode)
#
# Conventions:
#   - The recipe must `set -Eeuo pipefail` and call `setup_init "<id>" "<title>"`
#     before doing any work. `setup_init` traps errors and emits a failure notify.
#   - All progress notifications share a synchronous tag so the desktop notifier
#     replaces the previous bubble in place instead of stacking.

# -- Debug / trace mode -------------------------------------------------------
# Set TRACE=1 to enable bash trace (set -x) for full command debugging.
[[ "${TRACE:-}" == "1" ]] && set -x

# -- Distro detection --------------------------------------------------------
_setup_load_distro() {
    DISTRO_ID="unknown"
    DISTRO_LIKE=""
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        DISTRO_ID="${ID:-unknown}"
        DISTRO_LIKE="${ID_LIKE:-}"
    fi
}
_setup_load_distro

is_arch_like() {
    case " $DISTRO_ID $DISTRO_LIKE " in
        *" arch "*|*" archlinux "*|*" endeavouros "*|*" cachyos "*|*" manjaro "*|*" garuda "*|*" artix "*)
            return 0 ;;
    esac
    return 1
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

# -- Notifications ------------------------------------------------------------
SETUP_TAG=""
SETUP_TITLE=""

setup_notify() {
    local body="$1"
    local icon="${2:-download}"
    [[ -z "$SETUP_TAG" ]] && return 0
    notify-send \
        -a "Setup" \
        -i "$icon" \
        -h "string:x-canonical-private-synchronous:${SETUP_TAG}" \
        -- "$SETUP_TITLE" "$body" 2>/dev/null || true
}

setup_progress() {
    local step="$1" total="$2" msg="$3"
    printf '\n\033[1;36m[%s/%s]\033[0m %s\n' "$step" "$total" "$msg"
    setup_notify "[$step/$total] $msg" "download"
}

setup_done() {
    local msg="${1:-Done}"
    printf '\n\033[1;32m✔ %s\033[0m\n' "$msg"
    setup_notify "$msg" "emblem-ok-symbolic"
}

setup_fail() {
    local msg="${1:-Setup failed}"
    printf '\n\033[1;31m✘ %s\033[0m\n' "$msg" >&2
    setup_notify "$msg" "dialog-error"
}

# -- Developer-friendly error reporting ---------------------------------------
_setup_err_trap() {
    local exit_code=$?
    local line_no=$LINENO
    local failed_cmd="$BASH_COMMAND"
    local src_file="${BASH_SOURCE[1]:-<unknown>}"
    local func_name="${FUNCNAME[1]:-<main>}"

    printf '\n' >&2
    printf '\033[1;31m┌─ Error ─────────────────────────────────────────────────────────────┐\033[0m\n' >&2
    printf '\033[1;31m│\033[0m Setup:    \033[1m%s\033[0m\n' "$SETUP_TITLE" >&2
    printf '\033[1;31m│\033[0m Exit:     \033[1;31m%d\033[0m\n' "$exit_code" >&2
    printf '\033[1;31m│\033[0m Line:     \033[1;33m%d\033[0m\n' "$line_no" >&2
    printf '\033[1;31m│\033[0m File:     \033[2m%s\033[0m\n' "$src_file" >&2
    printf '\033[1;31m│\033[0m Function: \033[2m%s\033[0m\n' "$func_name" >&2
    printf '\033[1;31m│\033[0m Command:  \033[2m%s\033[0m\n' "$failed_cmd" >&2

    if (( ${#FUNCNAME[@]} > 2 )); then
        printf '\033[1;31m├─ Stack trace ───────────────────────────────────────────────────────┤\033[0m\n' >&2
        local i
        for ((i=1; i<${#FUNCNAME[@]}; i++)); do
            printf '\033[1;31m│\033[0m  %s  at  %s:%s\n' "${FUNCNAME[$i]}" "${BASH_SOURCE[$i]:-<unknown>}" "${BASH_LINENO[$((i-1))]}" >&2
        done
    fi
    printf '\033[1;31m└─────────────────────────────────────────────────────────────────────┘\033[0m\n' >&2

    setup_fail "$SETUP_TITLE failed (exit $exit_code) at line $line_no: $failed_cmd"
    setup_finish_pause
    exit "$exit_code"
}

setup_init() {
    SETUP_TAG="setup-$1"
    SETUP_TITLE="$2"
    trap '_setup_err_trap' ERR
    setup_notify "Starting…" "download"
    printf '\033[1;35m▶ %s\033[0m  (distro: %s)\n' "$SETUP_TITLE" "$DISTRO_ID"
}

# -- Package install helpers --------------------------------------------------
# NOTE: We always use an AUR helper (paru or yay) for ALL packages,
# including official repo packages. This simplifies the flow and lets the
# helper handle dependency resolution, building, and caching consistently.
# Priority: paru > yay > bootstrap yay.
ensure_aur_helper() {
    if have_cmd paru; then echo paru; return 0; fi
    if have_cmd yay; then echo yay; return 0; fi
    setup_notify "Bootstrapping yay (AUR helper)…" "download"
    sudo pacman -S --needed --noconfirm git base-devel >&2
    local tmp
    tmp="$(mktemp -d)"
    git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" >&2
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm) >&2
    rm -rf "$tmp"
    echo yay
}

# install_arch <repo-pkgs...> -- <aur-pkgs...>
# Always uses an AUR helper (paru or yay) for every package.
# The repo/aur split is kept for callers; everything is merged and handed to
# the helper so repo packages are resolved through it as well.
install_arch() {
    local repo=() aur=() seen_split=0
    for a in "$@"; do
        if [[ "$a" == "--" ]]; then seen_split=1; continue; fi
        if (( seen_split )); then aur+=("$a"); else repo+=("$a"); fi
    done

    local all_pkgs=()
    (( ${#repo[@]} )) && all_pkgs+=("${repo[@]}")
    (( ${#aur[@]} )) && all_pkgs+=("${aur[@]}")

    if (( ${#all_pkgs[@]} == 0 )); then
        echo "warning: install_arch called with no packages" >&2
        return 0
    fi

    local helper
    helper="$(ensure_aur_helper)"

    echo "  · AUR helper: $helper"
    echo "  · Installing: ${all_pkgs[*]}"
    "$helper" -S --needed --noconfirm "${all_pkgs[@]}"
}

install_flatpak() {
    if ! have_cmd flatpak; then
        setup_fail "flatpak is not installed; cannot continue on this distro"
        return 1
    fi
    flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true
    flatpak install -y --user flathub "$@"
}

setup_finish_pause() {
    printf '\n\033[2mPress Enter to close this window…\033[0m '
    read -r _ || true
}
