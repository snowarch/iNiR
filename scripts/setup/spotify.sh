#!/usr/bin/env bash
# scripts/setup/spotify.sh
# /setup-spotify — installs Spotify and configures Spicetify.
#
# @meta name: Setup Spotify + Spicetify
# @meta description: Install Spotify and configure Spicetify (AUR on Arch, Flatpak elsewhere)
# @meta icon: music_note
# @meta keywords: spotify music spicetify aur flatpak
#
# Arch family : `spotify` (AUR) + `spicetify-cli` (AUR). Tries
#               `spicetify backup apply` first; only launches Spotify
#               (so the user can sign in and Spotify can generate its
#               prefs file) if the first apply fails. Then sets prefs_path,
#               retries, installs the Marketplace, and — only if the user
#               has enabled `appearance.wallpaperTheming.enableSpicetify`
#               in config.json — applies the iNiR Spicetify theme.
# Other distros: falls back to the Flatpak build of Spotify. Spicetify is
#                skipped because it cannot patch the Flatpak install reliably.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/_lib.sh"

CONFIG_PATH="${XDG_CONFIG_HOME:-$HOME/.config}/illogical-impulse/config.json"

# Locate the spotify prefs file. Spicetify needs this; on the AUR `spotify`
# package it lives at ~/.config/spotify/prefs after the first run.
# `-print -quit` makes find return as soon as it sees the first hit.
_find_prefs() {
    find "$HOME" -path '*/spotify/prefs' -print -quit 2>/dev/null
}

# Wait for Spotify to exit, OR let the user press Enter in this terminal to
# force-quit Spotify and continue. Polls `pgrep -x spotify` every 2 s; if
# `read -t 2` succeeds during the same window, we kill Spotify ourselves.
_await_or_force_close_spotify() {
    echo
    echo "  ┌─────────────────────────────────────────────────────────────┐"
    echo "  │  Sign in to Spotify so it can write its prefs file.         │"
    echo "  │  Quit Spotify normally to continue, OR press Enter here     │"
    echo "  │  to force-quit it.                                          │"
    echo "  └─────────────────────────────────────────────────────────────┘"
    echo

    # Give Spotify up to 30s to actually appear (cold start, slow disks).
    local waited=0
    while ! pgrep -x spotify >/dev/null 2>&1; do
        sleep 1
        waited=$((waited + 1))
        (( waited >= 30 )) && { echo "  · Spotify did not start; continuing anyway." >&2; return 0; }
    done

    while pgrep -x spotify >/dev/null 2>&1; do
        if read -r -t 2 _; then
            echo "  · Force-closing Spotify…"
            pkill -x spotify || true
            for _ in 1 2 3 4 5; do
                pgrep -x spotify >/dev/null 2>&1 || break
                sleep 1
            done
            pgrep -x spotify >/dev/null 2>&1 && pkill -9 -x spotify || true
            break
        fi
    done
    echo "  · Spotify closed — resuming setup."
}

# Returns 0 iff config.json exists and explicitly enables the Spicetify
# wallpaper-theme integration. Defaults to "off" when jq is missing or the
# key is absent — we never opt the user in implicitly.
_theme_enabled_in_config() {
    [[ -f "$CONFIG_PATH" ]] || return 1
    have_cmd jq || return 1
    [[ "$(jq -r '.appearance.wallpaperTheming.enableSpicetify // false' \
        "$CONFIG_PATH" 2>/dev/null)" == "true" ]]
}

if is_arch_like; then
    TOTAL=5

    setup_progress 1 $TOTAL "Installing Spotify (AUR) and Spicetify CLI"
    install_arch -- spotify spicetify-cli

    # /opt/spotify is owned by root; spicetify needs write access to patch
    # app.asar in place. Run unconditionally so a missing dir surfaces as a
    # loud sudo error instead of a confusing later failure.
    setup_progress 2 $TOTAL "Granting Spicetify write access to /opt/spotify"
    sudo chmod a+wr /opt/spotify
    sudo chmod a+wr /opt/spotify/Apps -R

    setup_progress 3 $TOTAL "Applying Spicetify backup"
    # First attempt: with prefs_path pre-set if we can already find one.
    prefs="$(_find_prefs)"
    if [[ -n "$prefs" ]]; then
        echo "  · prefs already exists at $prefs"
        spicetify config prefs_path "$prefs" >/dev/null 2>&1 || true
    fi

    if ! spicetify backup apply; then
        echo
        echo "  · backup apply failed (likely no prefs file yet)."
        echo "  · Launching Spotify so it can generate its prefs…"
        # setsid -f detaches Spotify into its own session so closing the
        # window doesn't cascade SIGHUP back into this script.
        setsid -f spotify >/dev/null 2>&1 < /dev/null || \
            nohup spotify >/dev/null 2>&1 < /dev/null &
        setup_notify "Sign in to Spotify, then quit it (or press Enter in the terminal to force-quit)" "media-playback-start"
        _await_or_force_close_spotify

        prefs="$(_find_prefs)"
        if [[ -z "$prefs" ]]; then
            setup_fail "Could not locate spotify/prefs after first run; aborting."
            exit 1
        fi
        echo "  · Found prefs at $prefs"
        spicetify config prefs_path "$prefs" >/dev/null 2>&1 || true
        spicetify backup apply
    fi

    setup_progress 4 $TOTAL "Installing Spicetify Marketplace"
    if curl -fsSL https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.sh \
        | sh; then
        echo "Marketplace installed."
    else
        echo "warning: Marketplace installer failed; you can rerun it later." >&2
    fi

    if _theme_enabled_in_config; then
        setup_progress 5 $TOTAL "Applying iNiR Spicetify theme"
        # Generates color.ini + user.css from the current matugen palette
        # and runs `spicetify apply`. Idempotent and safe to rerun.
        theme_script="$SCRIPT_DIR/../colors/apply-spicetify-theme.sh"
        if [[ -x "$theme_script" ]]; then
            if "$theme_script"; then
                echo "iNiR theme applied."
            else
                echo "warning: theme script returned non-zero; rerun it manually if Spotify looks unstyled." >&2
            fi
        else
            echo "warning: $theme_script not found or not executable; skipping theme." >&2
        fi
    else
        setup_progress 5 $TOTAL "Skipping iNiR theme (appearance.wallpaperTheming.enableSpicetify is off)"
        echo "  · Enable it in Settings → Themes → 'Spotify theming' to apply the iNiR theme."
    fi

    setup_done "Spotify + Spicetify ready. Launch Spotify to verify."
else
    TOTAL=2
    setup_progress 1 $TOTAL "Installing Spotify via Flatpak (no Spicetify on non-Arch)"
    install_flatpak com.spotify.Client

    setup_progress 2 $TOTAL "Skipping Spicetify (unsupported on Flatpak Spotify)"
    setup_done "Spotify installed via Flatpak. Spicetify was skipped."
fi

setup_finish_pause
