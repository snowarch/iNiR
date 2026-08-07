#!/usr/bin/env bash
# scripts/setup/spotify.sh
# /setup-spotify — installs Spotify and configures Spicetify.
#
# @meta name: Setup Spotify + Spicetify
# @meta description: Install Spotify and configure Spicetify (AUR on Arch, Flatpak elsewhere)
# @meta icon: music_note
# @meta keywords: spotify music spicetify aur flatpak
#
# Arch family : `spotify` (AUR) + `spicetify-cli` (AUR).
#               Follows the official Spicetify docs for Linux setup:
#               https://spicetify.app/docs/getting-started
#
#               We enforce the AUR package because Spicetify CANNOT patch
#               Flatpak, Snap, or spotify-launcher installs reliably.
# Other distros: falls back to the Flatpak build of Spotify. Spicetify is
#                skipped because it cannot patch the Flatpak install reliably.
#
# --- Developer notes ---------------------------------------------------------
# To add/remove an incompatible install type, edit _remove_incompatible().
# To change the theme script path, edit the THEME_SCRIPT variable below.
# Set TRACE=1 to enable bash trace (set -x) for debugging.
# ------------------------------------------------------------------------------

[[ "${TRACE:-}" == "1" ]] && set -x
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/_lib.sh"

# ------------------------------------------------------------------------------
# Config
# ------------------------------------------------------------------------------
CONFIG_PATH="${XDG_CONFIG_HOME:-$HOME/.config}/illogical-impulse/config.json"
THEME_SCRIPT="$SCRIPT_DIR/../colors/apply-spicetify-theme.sh"
SPOTIFY_DIR="/opt/spotify"

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

# Print an error and exit, but always hold the terminal open.
_die() {
    setup_fail "$1"
    setup_finish_pause
    exit 1
}

_find_prefs() {
    find "$HOME" -path '*/spotify/prefs' -print -quit 2>/dev/null
}

_theme_enabled_in_config() {
    [[ -f "$CONFIG_PATH" ]] || return 1
    have_cmd jq || return 1
    [[ "$(jq -r '.appearance.wallpaperTheming.enableSpicetify // false' \
        "$CONFIG_PATH" 2>/dev/null)" == "true" ]]
}

# Wait for the user to close Spotify (or force-close with Enter).
_await_spotify_close() {
    echo
    cat <<'BANNER'
  ┌─────────────────────────────────────────────────────────────┐
  │  Sign in to Spotify so it can write its prefs file.       │
  │  Quit Spotify normally to continue, OR press Enter here   │
  │  to force-quit it.                                        │
  └─────────────────────────────────────────────────────────────┘
BANNER

    local waited=0
    while ! pgrep -x spotify >/dev/null 2>&1; do
        sleep 1
        waited=$((waited + 1))
        if (( waited >= 30 )); then
            echo "  · Spotify did not start; continuing anyway." >&2
            return 0
        fi
    done

    while pgrep -x spotify >/dev/null 2>&1; do
        if read -r -t 2 _; then
            echo "  · Force-closing Spotify…"
            pkill -x spotify || true
            sleep 2
            pgrep -x spotify >/dev/null 2>&1 && pkill -9 -x spotify || true
            break
        fi
    done
    echo "  · Spotify closed — resuming setup."
}

# ------------------------------------------------------------------------------
# Phase 1 — Remove incompatible installs
# ------------------------------------------------------------------------------
# Spicetify can only patch the official AUR package at /opt/spotify.
# Anything else (Flatpak, Snap, launcher) must go first.
# ------------------------------------------------------------------------------
_remove_incompatible() {
    local helper
    helper="$(ensure_aur_helper)"

    # Flatpak
    if have_cmd flatpak; then
        echo "  · Checking for Flatpak Spotify…"
        flatpak uninstall -y --user com.spotify.Client 2>/dev/null || \
            flatpak uninstall -y com.spotify.Client 2>/dev/null || true
    fi

    # Snap
    if have_cmd snap; then
        echo "  · Checking for Snap Spotify…"
        sudo snap remove spotify >/dev/null 2>&1 || true
    fi

    # spotify-launcher (AUR) — installs to user dir, not /opt/spotify
    if have_cmd spotify-launcher; then
        echo "  · Removing spotify-launcher…"
        "$helper" -Rns --noconfirm spotify-launcher 2>/dev/null || true
        rm -rf "$HOME/.local/share/spotify-launcher" 2>/dev/null || true
    fi

    # Conflicting spicetify packages (prevent interactive "Remove X? [y/N]" prompt)
    if "$helper" -Q spicetify-cli-git >/dev/null 2>&1; then
        echo "  · Removing spicetify-cli-git (conflicts with spicetify-cli)…"
        "$helper" -Rns --noconfirm spicetify-cli-git 2>/dev/null || true
    fi
    if "$helper" -Q spicetify-cli >/dev/null 2>&1; then
        echo "  · Reinstalling spicetify-cli…"
        "$helper" -Rns --noconfirm spicetify-cli 2>/dev/null || true
    fi
}

# ------------------------------------------------------------------------------
# Phase 2 — Install packages
# ------------------------------------------------------------------------------
_install_packages() {
    install_arch -- spotify spicetify-cli

    # Verify spicetify is in PATH; fall back to the curl installer location.
    if ! have_cmd spicetify && [[ -x "$HOME/.spicetify/spicetify" ]]; then
        export PATH="$HOME/.spicetify:$PATH"
    fi
    if ! have_cmd spicetify; then
        _die "spicetify was installed but is not in PATH. Open a new terminal and rerun /setup-spotify."
    fi
}

# ------------------------------------------------------------------------------
# Phase 3 — Configure Spicetify paths & permissions
# ------------------------------------------------------------------------------
# Per Spicetify docs: set spotify_path and grant write permissions.
# https://spicetify.app/docs/getting-started
# ------------------------------------------------------------------------------
_configure_spicetify() {
    echo "  · Spotify at: $SPOTIFY_DIR"

    if [[ ! -d "$SPOTIFY_DIR/Apps" ]]; then
        _die "Could not find $SPOTIFY_DIR/Apps. AUR install may have failed."
    fi

    spicetify config spotify_path "$SPOTIFY_DIR" >/dev/null 2>&1 || true

    echo "  · Granting write permissions…"
    sudo chmod a+wr "$SPOTIFY_DIR" 2>/dev/null || \
        echo "  · warning: sudo chmod $SPOTIFY_DIR failed (may already be writable)." >&2
    sudo chmod a+wr "$SPOTIFY_DIR/Apps" -R 2>/dev/null || \
        echo "  · warning: sudo chmod $SPOTIFY_DIR/Apps failed (may already be writable)." >&2
}

# ------------------------------------------------------------------------------
# Phase 4 — First-run: generate prefs file
# ------------------------------------------------------------------------------
# Spicetify docs: "If this is a fresh Spotify install, open Spotify and
# log in for at least 60 seconds before running Spicetify."
# ------------------------------------------------------------------------------
_generate_prefs() {
    local prefs
    prefs="$(_find_prefs)"
    if [[ -n "$prefs" ]]; then
        echo "  · prefs already exists at $prefs"
        spicetify config prefs_path "$prefs" >/dev/null 2>&1 || true
        return 0
    fi

    # Close any lingering Spotify process first
    if pgrep -x spotify >/dev/null 2>&1; then
        echo "  · Spotify is already running. Closing it first…"
        pkill -x spotify || true
        sleep 2
    fi

    echo "  · Launching Spotify for first-run (needs ~60s to generate prefs)…"
    setsid -f spotify >/dev/null 2>&1 < /dev/null || \
        nohup spotify >/dev/null 2>&1 < /dev/null &

    setup_notify "Sign in to Spotify, then quit it (or press Enter to force-quit)" "media-playback-start"
    _await_spotify_close

    prefs="$(_find_prefs)"
    if [[ -z "$prefs" ]]; then
        _die "Could not locate spotify/prefs after first run; aborting."
    fi
    echo "  · Found prefs at $prefs"
    spicetify config prefs_path "$prefs" >/dev/null 2>&1 || true
}

# ------------------------------------------------------------------------------
# Phase 5 — Apply Spicetify backup
# ------------------------------------------------------------------------------
# Official recovery flow from the docs.
# ------------------------------------------------------------------------------
_apply_spicetify() {
    if spicetify backup apply; then return 0; fi

    # Stale backup — try restore then redo
    if spicetify restore backup apply; then return 0; fi

    # Deadlocked (version mismatch) — nuke backup state and retry
    local cfg_dir="" spicetify_c
    spicetify_c="$(spicetify -c 2>/dev/null)" || true
    if [[ -n "$spicetify_c" ]]; then
        cfg_dir="$(dirname "$spicetify_c")"
    fi
    if [[ -n "$cfg_dir" && -d "$cfg_dir" ]]; then
        echo "  · Clearing stale backup state…"
        rm -rf "${cfg_dir:?}/Backup" 2>/dev/null || true
        if [[ -f "${cfg_dir}/config-xpui.ini" ]]; then
            sed -i '/^\[Backup\]/,/^\[/{/^\[Backup\]/!{/^\[/!d}}' \
                "${cfg_dir}/config-xpui.ini" 2>/dev/null || true
        fi
    fi
    spicetify backup apply
}

# ------------------------------------------------------------------------------
# Phase 6 — Marketplace & theme
# ------------------------------------------------------------------------------
_install_marketplace() {
    if curl -fsSL https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.sh \
        | sh; then
        echo "  · Marketplace installed."
    else
        echo "  · warning: Marketplace installer failed; you can rerun it later." >&2
    fi
}

_apply_theme() {
    if ! _theme_enabled_in_config; then
        echo "  · Skipping iNiR theme (appearance.wallpaperTheming.enableSpicetify is off)"
        echo "    Enable it in Settings → Themes → 'Spotify theming' to apply the iNiR theme."
        return 0
    fi

    echo "  · Applying iNiR Spicetify theme…"
    if [[ -x "$THEME_SCRIPT" ]]; then
        if "$THEME_SCRIPT"; then
            echo "  · iNiR theme applied."
        else
            echo "  · warning: theme script returned non-zero; rerun it manually if Spotify looks unstyled." >&2
        fi
    else
        echo "  · warning: $THEME_SCRIPT not found or not executable; skipping theme." >&2
    fi
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------
setup_init "spotify" "Setup Spotify + Spicetify"

if is_arch_like; then
    TOTAL=6

    setup_progress 1 $TOTAL "Removing incompatible Spotify installs"
    _remove_incompatible

    setup_progress 2 $TOTAL "Installing Spotify (AUR) and Spicetify CLI"
    _install_packages

    setup_progress 3 $TOTAL "Configuring Spicetify paths"
    _configure_spicetify

    setup_progress 4 $TOTAL "First-run: launch Spotify to generate prefs"
    _generate_prefs

    setup_progress 5 $TOTAL "Applying Spicetify backup"
    if ! _apply_spicetify; then
        _die "Spicetify backup apply failed. Check the error above."
    fi

    setup_progress 6 $TOTAL "Installing Spicetify Marketplace"
    _install_marketplace
    _apply_theme

    setup_done "Spotify + Spicetify ready. Launch Spotify to verify."
else
    TOTAL=2
    setup_progress 1 $TOTAL "Installing Spotify via Flatpak"
    install_flatpak com.spotify.Client

    setup_progress 2 $TOTAL "Skipping Spicetify (unsupported on Flatpak)"
    setup_done "Spotify installed via Flatpak. Spicetify was skipped."
fi

setup_finish_pause
