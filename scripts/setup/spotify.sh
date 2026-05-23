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

_find_prefs() {
    find "$HOME" -path '*/spotify/prefs' -print -quit 2>/dev/null
}

_await_or_force_close_spotify() {
    echo
    echo "  ┌─────────────────────────────────────────────────────────────┐"
    echo "  │  Sign in to Spotify so it can write its prefs file.         │"
    echo "  │  Quit Spotify normally to continue, OR press Enter here     │"
    echo "  │  to force-quit it.                                          │"
    echo "  └─────────────────────────────────────────────────────────────┘"
    echo

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

_theme_enabled_in_config() {
    [[ -f "$CONFIG_PATH" ]] || return 1
    have_cmd jq || return 1
    [[ "$(jq -r '.appearance.wallpaperTheming.enableSpicetify // false' \
        "$CONFIG_PATH" 2>/dev/null)" == "true" ]]
}

setup_init "spotify" "Setup Spotify + Spicetify"

if is_arch_like; then
    TOTAL=5

    setup_progress 1 $TOTAL "Installing Spotify (AUR) and Spicetify CLI"
    install_arch -- spotify spicetify-cli

    # Verify spicetify is actually available now
    if ! have_cmd spicetify; then
        setup_fail "spicetify was installed but is not in PATH. Open a new terminal and rerun /setup-spotify."
        setup_finish_pause
        exit 1
    fi

    # Detect the Spotify install directory. Prefer /opt/spotify (AUR package,
    # has .spa files spicetify needs) over the spotify-launcher expanded dir.
    _spotify_dir() {
        for d in /opt/spotify "$HOME/.local/share/spotify-launcher/install/usr/share/spotify"; do
            [[ -d "$d/Apps" ]] && echo "$d" && return
        done
    }

    setup_progress 2 $TOTAL "Configuring Spicetify paths"
    spotify_dir="$(_spotify_dir)"
    if [[ -z "$spotify_dir" ]]; then
        setup_fail "Could not find Spotify install directory."
        setup_finish_pause
        exit 1
    fi
    echo "  · Spotify at: $spotify_dir"

    # Ensure spicetify config directory exists so subsequent commands don't fail
    spicetify_cfg_dir="${XDG_CONFIG_HOME:-$HOME/.config}/spicetify"
    mkdir -p "$spicetify_cfg_dir"

    # Ensure spicetify points to the .spa-based install, not a launcher dir
    spicetify config spotify_path "$spotify_dir" >/dev/null 2>&1 || true

    # Spicetify needs write access to Spotify's files to inject the CSS/JS.
    # Try sudo; if it fails (no TTY, no passwordless sudo, etc.) warn and continue
    # because the user may have already set the permissions manually.
    if ! sudo chmod -R a+wr "$spotify_dir" 2>/dev/null; then
        echo "  · warning: could not chmod $spotify_dir (sudo failed or not needed)." >&2
    fi
    if [[ -d "$spotify_dir/Apps" ]] && ! sudo chmod -R a+wr "$spotify_dir/Apps" 2>/dev/null; then
        echo "  · warning: could not chmod $spotify_dir/Apps (sudo failed or not needed)." >&2
    fi

    setup_progress 3 $TOTAL "Applying Spicetify backup"

    # If Spotify is already running from a previous session, spicetify cannot
    # patch the files. Ask the user to close it first.
    if pgrep -x spotify >/dev/null 2>&1; then
        echo "  · Spotify is already running. Please close it before continuing."
        while pgrep -x spotify >/dev/null 2>&1; do
            sleep 1
        done
        echo "  · Spotify closed."
    fi

    prefs="$(_find_prefs)"
    if [[ -n "$prefs" ]]; then
        echo "  · prefs already exists at $prefs"
        spicetify config prefs_path "$prefs" >/dev/null 2>&1 || true
    fi

    _spicetify_apply() {
        if spicetify backup apply; then return 0; fi
        # Stale backup — try restore then redo
        if spicetify restore backup apply; then return 0; fi
        # Deadlocked (version mismatch) — nuke backup state and retry
        local cfg_dir=""
        local spicetify_c
        spicetify_c="$(spicetify -c 2>/dev/null)" || true
        if [[ -n "$spicetify_c" ]]; then
            cfg_dir="$(dirname "$spicetify_c")"
        fi
        if [[ -n "$cfg_dir" && -d "$cfg_dir" ]]; then
            echo "  · Clearing stale backup state…"
            rm -rf "${cfg_dir:?}/Backup" 2>/dev/null || true
            # Clear [Backup] section values in config
            if [[ -f "${cfg_dir}/config-xpui.ini" ]]; then
                sed -i '/^\[Backup\]/,/^\[/{/^\[Backup\]/!{/^\[/!d}}' \
                    "${cfg_dir}/config-xpui.ini" 2>/dev/null || true
            fi
        fi
        spicetify backup apply
    }

    if ! _spicetify_apply; then
        echo
        echo "  · backup apply failed (likely no prefs file yet)."
        echo "  · Launching Spotify so it can generate its prefs…"
        setsid -f spotify >/dev/null 2>&1 < /dev/null || \
            nohup spotify >/dev/null 2>&1 < /dev/null &
        setup_notify "Sign in to Spotify, then quit it (or press Enter in the terminal to force-quit)" "media-playback-start"
        _await_or_force_close_spotify

        prefs="$(_find_prefs)"
        if [[ -z "$prefs" ]]; then
            setup_fail "Could not locate spotify/prefs after first run; aborting."
            setup_finish_pause
            exit 1
        fi
        echo "  · Found prefs at $prefs"
        spicetify config prefs_path "$prefs" >/dev/null 2>&1 || true
        # Brief pause so Spotify releases file locks before we patch
        sleep 1
        if ! _spicetify_apply; then
            setup_fail "Spicetify backup apply failed even after generating prefs. Check the error above."
            setup_finish_pause
            exit 1
        fi
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
