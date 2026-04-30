#!/usr/bin/env bash
# scripts/setup/spotify.sh
# /setup-spotify — installs Spotify and configures Spicetify.
#
# @meta name: Setup Spotify + Spicetify
# @meta description: Install Spotify and configure Spicetify (AUR on Arch, Flatpak elsewhere)
# @meta icon: music_note
# @meta keywords: spotify music spicetify aur flatpak
#
# Arch family : `spotify` (AUR) + `spicetify-cli` (AUR). Spotify is launched
#               so the user can sign in (Spicetify's `backup apply` fails on
#               a fresh install that has never been run), then permissions on
#               /opt/spotify are relaxed, the backup is applied, the
#               Marketplace installer is run, and finally the iNiR Spicetify
#               theme is applied via scripts/colors/apply-spicetify-theme.sh.
# Other distros: falls back to the Flatpak build of Spotify. Spicetify is
#                skipped because it cannot patch the Flatpak install reliably.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/_lib.sh"

# Wait for the user to sign in and quit Spotify before continuing.
# Polls `pgrep -x spotify`:
#   1. up to ~60s for the process to appear (user might launch it manually);
#   2. then forever until it disappears (the user closing Spotify is the
#      explicit signal that this step is done).
# Falls back to a manual "press Enter" prompt if Spotify never shows up.
_await_spotify_login() {
    echo
    echo "  ┌─────────────────────────────────────────────────────────────┐"
    echo "  │  Spotify is starting. Sign in to your account, then quit    │"
    echo "  │  Spotify (Ctrl+Q or close the window) to continue setup.    │"
    echo "  └─────────────────────────────────────────────────────────────┘"
    echo

    local waited=0
    while ! pgrep -x spotify >/dev/null 2>&1; do
        sleep 1
        waited=$((waited + 1))
        if (( waited >= 60 )); then
            echo "  · Spotify hasn't appeared after 60s." >&2
            echo "    If you've already finished logging in, press Enter to continue." >&2
            read -r _ || true
            return 0
        fi
    done

    echo "  · Spotify is running (PID $(pgrep -x spotify | head -n1)). Waiting for you to quit it…"
    while pgrep -x spotify >/dev/null 2>&1; do
        sleep 2
    done
    echo "  · Spotify closed — resuming setup."
}

if is_arch_like; then
    TOTAL=6

    setup_progress 1 $TOTAL "Installing Spotify (AUR) and Spicetify CLI"
    install_arch -- spotify spicetify-cli

    setup_progress 2 $TOTAL "Launching Spotify — log in, then quit it to continue"
    # Detach Spotify from this terminal so closing the window doesn't cascade
    # back into the script via a SIGHUP. setsid puts it in its own session.
    setsid -f spotify >/dev/null 2>&1 < /dev/null || \
        nohup spotify >/dev/null 2>&1 < /dev/null &
    setup_notify "Sign in to Spotify, then quit it to continue setup" "media-playback-start"
    _await_spotify_login

    # Spotify must have been run at least once before these chmods + backup
    # apply will succeed reliably on a fresh install. Run unconditionally —
    # if /opt/spotify is missing the previous install silently failed and we
    # want a loud error from sudo here.
    setup_progress 3 $TOTAL "Granting Spicetify write access to /opt/spotify"
    sudo chmod a+wr /opt/spotify
    sudo chmod a+wr /opt/spotify/Apps -R

    setup_progress 4 $TOTAL "Applying Spicetify backup"
    # `backup apply` both backs up the original Spotify and applies Spicetify;
    # safe to rerun (it overwrites its own backup).
    spicetify backup apply

    setup_progress 5 $TOTAL "Installing Spicetify Marketplace"
    if curl -fsSL https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.sh \
        | sh; then
        echo "Marketplace installed."
    else
        echo "warning: Marketplace installer failed; you can rerun it later." >&2
    fi

    setup_progress 6 $TOTAL "Applying iNiR Spicetify theme"
    # Generates color.ini + user.css from the current matugen palette and
    # runs `spicetify apply`. Idempotent and safe to rerun.
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

    setup_done "Spotify + Spicetify ready. Launch Spotify to verify."
else
    TOTAL=2
    setup_progress 1 $TOTAL "Installing Spotify via Flatpak (no Spicetify on non-Arch)"
    install_flatpak com.spotify.Client

    setup_progress 2 $TOTAL "Skipping Spicetify (unsupported on Flatpak Spotify)"
    setup_done "Spotify installed via Flatpak. Spicetify was skipped."
fi

setup_finish_pause
