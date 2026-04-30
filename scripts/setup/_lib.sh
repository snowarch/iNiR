#!/usr/bin/env bash
# scripts/setup/_lib.sh
# Shared helpers for /setup recipes invoked from GlobalActions.
#
# Sourced by every recipe script. Provides:
#   - distro detection         (DISTRO_ID, DISTRO_LIKE, is_arch_like)
#   - progress notifications   (setup_notify, setup_progress, setup_done, setup_fail)
#   - command/package helpers  (have_cmd, ensure_aur_helper, install_arch, install_flatpak)
#
# Conventions:
#   - The recipe must `set -Eeuo pipefail` and call `setup_init "<id>" "<title>"`
#     before doing any work. `setup_init` traps errors and emits a failure notify.
#   - All progress notifications share a synchronous tag so the desktop notifier
#     replaces the previous bubble in place instead of stacking.

# ── Distro detection ────────────────────────────────────────────────────────
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

# ── Notifications ───────────────────────────────────────────────────────────
# A single tag per recipe so successive progress messages replace each other.
SETUP_TAG=""
SETUP_TITLE=""

setup_notify() {
    # setup_notify <body> [icon]
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
    # setup_progress <step> <total> <message>
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

setup_init() {
    # setup_init <id> <title>
    SETUP_TAG="setup-$1"
    SETUP_TITLE="$2"
    trap 'setup_fail "$SETUP_TITLE failed at line $LINENO"' ERR
    setup_notify "Starting…" "download"
    printf '\033[1;35m▶ %s\033[0m  (distro: %s)\n' "$SETUP_TITLE" "$DISTRO_ID"
}

# ── Package install helpers ─────────────────────────────────────────────────
# Returns the name of an available AUR helper, installing yay if needed.
ensure_aur_helper() {
    if have_cmd yay; then echo yay; return 0; fi
    if have_cmd paru; then echo paru; return 0; fi
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
# Splits args on a literal `--`; everything before goes via pacman, after via AUR.
install_arch() {
    local repo=() aur=() seen_split=0
    for a in "$@"; do
        if [[ "$a" == "--" ]]; then seen_split=1; continue; fi
        if (( seen_split )); then aur+=("$a"); else repo+=("$a"); fi
    done
    if (( ${#repo[@]} )); then
        sudo pacman -S --needed --noconfirm "${repo[@]}"
    fi
    if (( ${#aur[@]} )); then
        local helper
        helper="$(ensure_aur_helper)"
        "$helper" -S --needed --noconfirm "${aur[@]}"
    fi
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
    # Keeps the terminal open so the user can read sudo / build output.
    printf '\n\033[2mPress Enter to close this window…\033[0m '
    read -r _ || true
}
