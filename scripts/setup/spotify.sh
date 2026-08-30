#!/usr/bin/env bash
# scripts/setup/spotify.sh
# /setup-spotify — installs Spotify and configures Spicetify.
#
# @meta name: Setup Spotify + Spicetify
# @meta description: Install Spotify and configure Spicetify (AUR on Arch, Flatpak elsewhere)
# @meta icon: music_note
# @meta keywords: spotify music spicetify aur flatpak
#
# Arch family : `spotify` (AUR) + `spicetify-cli` (AUR). Repairs the
#               Spicetify v2.44+ wrapper asset when source-built packages omit
#               it, then tries `spicetify backup apply` first. It only launches
#               Spotify (so the user can sign in and Spotify can generate its
#               prefs file) if the first apply fails. Then sets prefs_path,
#               retries, installs the Marketplace, and — only if the user has
#               enabled `appearance.wallpaperTheming.enableSpicetify` in
#               config.json — applies the iNiR Spicetify theme.
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

_have_spotify_and_spicetify() {
    have_cmd spotify && have_cmd spicetify
}

_run_may_fail() {
    set +e
    "$@"
    local status=$?
    set -e
    return "$status"
}

_spicetify_version() {
    local version
    version="$(spicetify -v 2>/dev/null | sed -E 's/\x1b\[[0-9;]*m//g; s/^v//; s/[^0-9.].*$//' | head -n1)"
    [[ -n "$version" ]] && printf '%s\n' "$version"
}

_find_spicetify_source() {
    local version="${1:-}"
    local base candidate

    if [[ -n "$version" ]]; then
        for candidate in \
            "$HOME/.cache/paru/clone/spicetify-cli/src/spicetify-cli-$version" \
            "$HOME/.cache/yay/spicetify-cli/src/spicetify-cli-$version"; do
            if [[ -f "$candidate/scripts/build-wrapper.mjs" ]]; then
                printf '%s\n' "$candidate"
                return 0
            fi
        done
    fi

    for base in "$HOME/.cache/paru/clone/spicetify-cli" "$HOME/.cache/yay/spicetify-cli"; do
        [[ -d "$base" ]] || continue
        find "$base" -maxdepth 4 -type f -path '*/scripts/build-wrapper.mjs' -print 2>/dev/null
    done | sed 's|/scripts/build-wrapper.mjs$||' | sort -Vr | head -n1
}

_download_spicetify_source() {
    local version="$1"
    local target_base="$2"
    local archive="$target_base/spicetify-cli-$version.tar.gz"
    local source_dir="$target_base/spicetify-cli-$version"

    mkdir -p "$target_base"
    curl -fsSL \
        -o "$archive" \
        "https://github.com/spicetify/cli/archive/refs/tags/v$version.tar.gz"
    tar -xzf "$archive" -C "$target_base"
    if [[ -d "$target_base/cli-$version" ]]; then
        mv "$target_base/cli-$version" "$source_dir"
    fi
    [[ -f "$source_dir/scripts/build-wrapper.mjs" ]] || return 1
    printf '%s\n' "$source_dir"
}

_build_spicetify_wrapper() {
    local source_dir="$1"

    if [[ -s "$source_dir/jsHelper/spicetifyWrapper.js" ]]; then
        return 0
    fi

    if ! have_cmd node || ! have_cmd npm; then
        echo "  · Installing Node.js/npm to build Spicetify's wrapper…"
        install_arch nodejs npm
    fi

    echo "  · Building missing spicetifyWrapper.js…"
    if have_cmd pnpm && (cd "$source_dir" && _run_may_fail pnpm install --frozen-lockfile && _run_may_fail pnpm build:wrapper); then
        [[ -s "$source_dir/jsHelper/spicetifyWrapper.js" ]]
        return
    fi

    echo "  · pnpm build failed or is unavailable; trying npm fallback…"
    if ! (
        cd "$source_dir" &&
            _run_may_fail env NPM_CONFIG_ENGINE_STRICT=false npm install --include=optional --no-audit --no-fund &&
            _run_may_fail env NPM_CONFIG_ENGINE_STRICT=false npm run build:wrapper
    ); then
        return 1
    fi
    [[ -s "$source_dir/jsHelper/spicetifyWrapper.js" ]]
}

_ensure_spicetify_wrapper_asset() {
    local wrapper_dest="/opt/spicetify-cli/jsHelper/spicetifyWrapper.js"
    local version source_dir tmp_base

    if [[ -s "$wrapper_dest" ]]; then
        echo "  · Spicetify wrapper asset exists."
        return 0
    fi

    # Spicetify v2.44 made spicetifyWrapper.js a generated release asset.
    # Some source-built packages installed jsHelper without running
    # scripts/build-wrapper.mjs, so the generated Spotify index.html references
    # helper/spicetifyWrapper.js but the file is absent. That leaves injected
    # Spicetify code without the global Spicetify object and Spotify opens as a
    # blank XPUI window. Repair the package asset before applying Spicetify.
    version="$(_spicetify_version || true)"
    if [[ -n "$version" ]]; then
        echo "  · Spicetify wrapper asset missing; repairing package assets for v$version."
    else
        echo "  · Spicetify wrapper asset missing; repairing package assets from cached source."
    fi

    source_dir="$(_find_spicetify_source "$version")"
    if [[ -z "$source_dir" ]]; then
        if [[ -z "$version" ]]; then
            echo "  · Could not determine a release version and no cached source was found." >&2
            return 1
        fi
        tmp_base="$(mktemp -d)"
        if ! source_dir="$(_download_spicetify_source "$version" "$tmp_base")"; then
            echo "  · Failed to download Spicetify source for v$version." >&2
            return 1
        fi
    fi

    _build_spicetify_wrapper "$source_dir" || return 1
    sudo install -Dm644 "$source_dir/jsHelper/spicetifyWrapper.js" "$wrapper_dest"
    echo "  · Installed $wrapper_dest"
}

_spotify_xpui_dir() {
    local root="$1"
    for d in "$root/Apps/xpui" "$root/xpui"; do
        [[ -f "$d/index.html" ]] && echo "$d" && return 0
    done
}

_sync_spotify_wrapper_asset() {
    local spotify_root="$1"
    local xpui_dir index_html live_wrapper source_wrapper

    xpui_dir="$(_spotify_xpui_dir "$spotify_root")"
    [[ -n "$xpui_dir" ]] || return 0

    index_html="$xpui_dir/index.html"
    grep -q "helper/spicetifyWrapper.js" "$index_html" 2>/dev/null || return 0

    live_wrapper="$xpui_dir/helper/spicetifyWrapper.js"
    [[ -s "$live_wrapper" ]] && return 0

    source_wrapper="/opt/spicetify-cli/jsHelper/spicetifyWrapper.js"
    if [[ ! -s "$source_wrapper" ]]; then
        _ensure_spicetify_wrapper_asset || return 1
    fi

    mkdir -p "$xpui_dir/helper"
    install -m 600 "$source_wrapper" "$live_wrapper" 2>/dev/null \
        || sudo install -m 600 "$source_wrapper" "$live_wrapper"
    echo "  · Synced missing Spotify XPUI wrapper asset."
}

_ensure_spotify_writable() {
    local spotify_root="$1"
    local apps_dir="$spotify_root/Apps"

    if [[ -w "$spotify_root" && -w "$apps_dir" ]]; then
        return 0
    fi

    echo "  · Granting write access so Spicetify can patch Spotify…"
    if _run_may_fail sudo chmod a+wr "$spotify_root" &&
        _run_may_fail sudo chmod a+wr "$apps_dir" -R; then
        return 0
    fi

    if [[ -w "$spotify_root" && -w "$apps_dir" ]]; then
        echo "  · chmod reported an error, but Spotify paths are writable; continuing." >&2
        return 0
    fi

    echo "  · Could not make Spotify install writable: $spotify_root" >&2
    return 1
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
    TOTAL=6

    setup_progress 1 $TOTAL "Installing Spotify (AUR) and Spicetify CLI"
    if _have_spotify_and_spicetify; then
        echo "  · Spotify and Spicetify are already installed."
    elif ! _run_may_fail install_arch -- spotify spicetify-cli; then
        if _have_spotify_and_spicetify; then
            echo "  · Package install reported an error, but Spotify and Spicetify are available; continuing." >&2
        else
            setup_fail "Could not install Spotify and Spicetify CLI."
            setup_finish_pause
            exit 1
        fi
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
    # Ensure spicetify points to the .spa-based install, not a launcher dir
    spicetify config spotify_path "$spotify_dir" >/dev/null 2>&1 || true
    if ! _ensure_spotify_writable "$spotify_dir"; then
        setup_fail "Could not make Spotify writable for Spicetify patching."
        setup_finish_pause
        exit 1
    fi

    setup_progress 3 $TOTAL "Repairing Spicetify wrapper assets"
    if ! _ensure_spicetify_wrapper_asset; then
        setup_fail "Could not build/install Spicetify wrapper asset."
        setup_finish_pause
        exit 1
    fi

    setup_progress 4 $TOTAL "Applying Spicetify backup"
    prefs="$(_find_prefs)"
    if [[ -n "$prefs" ]]; then
        echo "  · prefs already exists at $prefs"
        spicetify config prefs_path "$prefs" >/dev/null 2>&1 || true
    fi

    _spicetify_apply() {
        if _run_may_fail spicetify backup apply; then
            _sync_spotify_wrapper_asset "$spotify_dir"
            return 0
        fi
        # Stale backup — try restore then redo
        if _run_may_fail spicetify restore backup apply; then
            _sync_spotify_wrapper_asset "$spotify_dir"
            return 0
        fi
        # Deadlocked (version mismatch) — nuke backup state and retry
        local cfg_dir
        cfg_dir="$(dirname "$(spicetify -c 2>/dev/null)" 2>/dev/null)"
        if [[ -n "$cfg_dir" ]]; then
            echo "  · Clearing stale backup state…"
            rm -rf "${cfg_dir:?}/Backup" 2>/dev/null || true
            # Clear [Backup] section values in config
            sed -i '/^\[Backup\]/,/^\[/{/^\[Backup\]/!{/^\[/!d}}' \
                "${cfg_dir}/config-xpui.ini" 2>/dev/null || true
        fi
        if _run_may_fail spicetify backup apply; then
            _sync_spotify_wrapper_asset "$spotify_dir"
            return 0
        fi
        return 1
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
        if ! _spicetify_apply; then
            setup_fail "Spicetify backup/apply failed after Spotify generated prefs."
            setup_finish_pause
            exit 1
        fi
    fi

    setup_progress 5 $TOTAL "Installing Spicetify Marketplace"
    if curl -fsSL https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.sh \
        | sh; then
        echo "Marketplace installed."
    else
        echo "warning: Marketplace installer failed; you can rerun it later." >&2
    fi

    if _theme_enabled_in_config; then
        setup_progress 6 $TOTAL "Applying iNiR Spicetify theme"
        theme_script="$SCRIPT_DIR/../colors/apply-spicetify-theme.sh"
        if [[ -x "$theme_script" ]]; then
            theme_name="$(jq -r '.appearance.wallpaperTheming.spicetifyTheme // "Inir"' "$CONFIG_PATH" 2>/dev/null)"
            if [[ "$theme_name" != "Inir" && "$theme_name" != "InirTUI" ]]; then
                theme_name="Inir"
            fi
            if "$theme_script" --theme "$theme_name"; then
                echo "iNiR theme applied."
            else
                echo "warning: theme script returned non-zero; rerun it manually if Spotify looks unstyled." >&2
            fi
        else
            echo "warning: $theme_script not found or not executable; skipping theme." >&2
        fi
    else
        setup_progress 6 $TOTAL "Skipping iNiR theme (appearance.wallpaperTheming.enableSpicetify is off)"
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
