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
#               Detects incompatible installs (Flatpak, Snap, spotify-launcher,
#               and conflicting spicetify-cli-git package) and asks before any
#               removal. It leaves declined conflicts untouched and explains
#               why setup cannot continue until they are resolved. It then
#               configures paths and permissions, repairs missing Spicetify
#               v2.44+ wrapper assets, generates prefs if needed, applies
#               Spicetify backup with progressive recovery, installs Marketplace,
#               automatically enables Spicetify theming in iNiR config, and
#               applies the theme.
# Other distros: falls back to the Flatpak build of Spotify. Spicetify is
#                skipped because it cannot patch the Flatpak install reliably.
#
# --- Developer notes ---------------------------------------------------------
# Set TRACE=1 to enable bash trace (set -x) for debugging.
# ------------------------------------------------------------------------------

[[ "${TRACE:-}" == "1" ]] && set -x
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/_lib.sh"
# shellcheck source=scripts/lib/config-path.sh
. "$SCRIPT_DIR/../lib/config-path.sh"

# ------------------------------------------------------------------------------
# Config & Paths
# ------------------------------------------------------------------------------
CONFIG_PATH="$(inir_config_file)"
THEME_SCRIPT="$SCRIPT_DIR/../colors/apply-spicetify-theme.sh"

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

# Print an error and exit, holding the terminal open.
_die() {
    setup_fail "$1"
    setup_finish_pause
    exit 1
}

_run_may_fail() {
    set +e
    "$@"
    local status=$?
    set -e
    return "$status"
}

_find_prefs() {
    find "$HOME" -path '*/spotify/prefs' -print -quit 2>/dev/null
}

_have_spotify_and_spicetify() {
    have_cmd spotify && have_cmd spicetify
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

_spotify_dir() {
    for d in /opt/spotify "$HOME/.local/share/spotify-launcher/install/usr/share/spotify"; do
        [[ -d "$d/Apps" ]] && echo "$d" && return 0
    done
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

# Wait for the user to close Spotify (or force-close with Enter).
_await_spotify_close() {
    echo
    cat <<'BANNER'
  ┌─────────────────────────────────────────────────────────────┐
  │  Sign in to Spotify so it can write its prefs file.         │
  │  Quit Spotify normally to continue, OR press Enter here     │
  │  to force-quit it.                                          │
  └─────────────────────────────────────────────────────────────┘
BANNER
    echo

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

_enable_spicetify_theming() {
    if ! have_cmd jq; then
        echo "  · jq not available; cannot enable Spicetify theming in config." >&2
        return 1
    fi
    echo "  · Enabling Spicetify theming in iNiR config…"
    if [[ ! -f "$CONFIG_PATH" ]]; then
        mkdir -p "$(dirname "$CONFIG_PATH")"
        echo '{}' > "$CONFIG_PATH"
    fi
    local lockfile="$CONFIG_PATH.lock"
    (
        flock -w 5 200 || { echo "  · Config lock timeout." >&2; return 1; }
        jq '.appearance.wallpaperTheming.enableSpicetify = true' \
            "$CONFIG_PATH" > "$CONFIG_PATH.tmp" \
            && mv "$CONFIG_PATH.tmp" "$CONFIG_PATH"
    ) 200>"$lockfile"
}

# ------------------------------------------------------------------------------
# Phase 1 — Check and optionally remove incompatible installs
# ------------------------------------------------------------------------------
# Spicetify can only patch the official AUR package at /opt/spotify.
# Conflicting package formats are detected first. Every removal requires an
# explicit confirmation; declining any removal leaves the existing installs
# untouched and stops setup before package installation begins.
# ------------------------------------------------------------------------------
_confirm_removal() {
    local description="$1"
    local answer

    printf '\n  · Detected %s.\n' "$description"
    printf '    Remove it before continuing with the AUR setup? [y/N] '
    if ! read -r answer; then
        printf '\n    No confirmation received; leaving it installed.\n' >&2
        return 1
    fi
    [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
}

_arch_package_installed() {
    have_cmd pacman && pacman -Q "$1" >/dev/null 2>&1
}

_remove_incompatible() {
    local flatpak_installed=false
    local snap_installed=false
    local launcher_package_installed=false
    local launcher_command_present=false
    local launcher_data_present=false
    local spicetify_git_installed=false
    local helper=""
    local -a refused=()
    local -a manual_conflicts=()

    # Detect everything before asking or removing anything, avoiding partial
    # cleanup when the user declines one of several conflicts.
    if have_cmd flatpak && _run_may_fail flatpak info com.spotify.Client >/dev/null 2>&1; then
        flatpak_installed=true
    fi
    if have_cmd snap && _run_may_fail snap list spotify >/dev/null 2>&1; then
        snap_installed=true
    fi
    if _arch_package_installed spotify-launcher; then
        launcher_package_installed=true
    fi
    if have_cmd spotify-launcher; then
        launcher_command_present=true
    fi
    if [[ -d "$HOME/.local/share/spotify-launcher" ]]; then
        launcher_data_present=true
    fi
    if _arch_package_installed spicetify-cli-git; then
        spicetify_git_installed=true
    fi

    if ! $flatpak_installed && ! $snap_installed &&
        ! $launcher_package_installed && ! $launcher_command_present &&
        ! $launcher_data_present &&
        ! $spicetify_git_installed; then
        return 0
    fi

    # A binary or data directory without a package owner may come from a
    # manual install. Do not guess how to remove user-managed files.
    if ! $launcher_package_installed; then
        if $launcher_command_present; then
            manual_conflicts+=("spotify-launcher executable on PATH")
        fi
        if $launcher_data_present; then
            manual_conflicts+=("spotify-launcher data at $HOME/.local/share/spotify-launcher")
        fi
    fi
    if (( ${#manual_conflicts[@]} )); then
        echo >&2
        echo "  · Found spotify-launcher files without a removable package owner." >&2
        echo "  · Leaving them untouched; remove them manually if they belong to an old install:" >&2
        printf '    - %s\n' "${manual_conflicts[@]}" >&2
        echo "  · Setup cannot continue until this conflict is resolved." >&2
        return 1
    fi

    if $flatpak_installed && ! _confirm_removal "Flatpak Spotify (com.spotify.Client)"; then
        refused+=("Flatpak Spotify")
    fi
    if $snap_installed && ! _confirm_removal "Snap Spotify"; then
        refused+=("Snap Spotify")
    fi
    if $launcher_package_installed &&
        ! _confirm_removal "the spotify-launcher AUR package"; then
        refused+=("spotify-launcher")
    fi
    if $spicetify_git_installed &&
        ! _confirm_removal "the conflicting spicetify-cli-git package"; then
        refused+=("spicetify-cli-git")
    fi

    if (( ${#refused[@]} )); then
        echo >&2
        echo "  · Existing installations were left unchanged." >&2
        echo "  · Resolve these conflicts manually, or rerun and approve their removal:" >&2
        printf '    - %s\n' "${refused[@]}" >&2
        echo "  · Setup cannot continue alongside these installations." >&2
        return 1
    fi

    if $launcher_package_installed || $spicetify_git_installed; then
        helper="$(ensure_aur_helper)"
    fi

    if $flatpak_installed; then
        echo "  · Removing Flatpak Spotify…"
        _run_may_fail flatpak uninstall -y --user com.spotify.Client >/dev/null 2>&1 || true
        _run_may_fail flatpak uninstall -y --system com.spotify.Client >/dev/null 2>&1 || true
        if _run_may_fail flatpak info com.spotify.Client >/dev/null 2>&1; then
            echo "  · Could not remove Flatpak Spotify; leaving it installed." >&2
            return 1
        fi
    fi

    if $snap_installed; then
        echo "  · Removing Snap Spotify…"
        if ! _run_may_fail sudo snap remove spotify >/dev/null 2>&1 ||
            _run_may_fail snap list spotify >/dev/null 2>&1; then
            echo "  · Could not remove Snap Spotify; leaving it installed." >&2
            return 1
        fi
    fi

    if $launcher_package_installed; then
        echo "  · Removing spotify-launcher…"
        if ! _run_may_fail "$helper" -Rns --noconfirm spotify-launcher >/dev/null 2>&1 ||
            _arch_package_installed spotify-launcher; then
            echo "  · Could not remove spotify-launcher; leaving it installed." >&2
            return 1
        fi
    fi

    if $launcher_data_present; then
        echo "  · Leaving spotify-launcher data untouched at $HOME/.local/share/spotify-launcher."
    fi

    if $launcher_command_present && have_cmd spotify-launcher; then
        echo "  · A spotify-launcher executable is still on PATH after package removal." >&2
        return 1
    fi

    if $spicetify_git_installed; then
        echo "  · Removing spicetify-cli-git…"
        if ! _run_may_fail "$helper" -Rns --noconfirm spicetify-cli-git >/dev/null 2>&1 ||
            _arch_package_installed spicetify-cli-git; then
            echo "  · Could not remove spicetify-cli-git; leaving it installed." >&2
            return 1
        fi
    fi
}

# ------------------------------------------------------------------------------
# Phase 2 — Install packages
# ------------------------------------------------------------------------------
_install_packages() {
    if _have_spotify_and_spicetify; then
        echo "  · Spotify and Spicetify are already installed."
    elif ! _run_may_fail install_arch -- spotify spicetify-cli; then
        if _have_spotify_and_spicetify; then
            echo "  · Package install reported an error, but Spotify and Spicetify are available; continuing." >&2
        else
            _die "Could not install Spotify and Spicetify CLI."
        fi
    fi

    # Verify spicetify is in PATH; fall back to the curl installer location if present.
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
_configure_spicetify() {
    spotify_dir="$(_spotify_dir || true)"
    if [[ -z "$spotify_dir" ]]; then
        _die "Could not find Spotify install directory (/opt/spotify)."
    fi
    echo "  · Spotify at: $spotify_dir"

    # Ensure Spicetify config directory exists
    local spicetify_cfg_dir
    spicetify_cfg_dir="${XDG_CONFIG_HOME:-$HOME/.config}/spicetify"
    mkdir -p "$spicetify_cfg_dir"

    # Ensure spicetify points to the .spa-based install
    spicetify config spotify_path "$spotify_dir" >/dev/null 2>&1 || true

    if ! _ensure_spotify_writable "$spotify_dir"; then
        _die "Could not make Spotify writable for Spicetify patching."
    fi

    if ! _ensure_spicetify_wrapper_asset; then
        _die "Could not build/install Spicetify wrapper asset."
    fi
}

# ------------------------------------------------------------------------------
# Phase 4 — First-run: generate prefs file (if needed)
# ------------------------------------------------------------------------------
_generate_prefs_if_needed() {
    local prefs
    prefs="$(_find_prefs)"
    if [[ -n "$prefs" ]]; then
        echo "  · prefs already exists at $prefs"
        spicetify config prefs_path "$prefs" >/dev/null 2>&1 || true
        return 0
    fi

    # Close any lingering Spotify process first
    if pgrep -x spotify >/dev/null 2>&1; then
        echo "  · Spotify is running. Closing it before first-run setup…"
        pkill -x spotify || true
        sleep 2
    fi

    echo "  · Launching Spotify so it can generate its prefs file…"
    setsid -f spotify >/dev/null 2>&1 < /dev/null || \
        nohup spotify >/dev/null 2>&1 < /dev/null &

    setup_notify "Sign in to Spotify, then quit it (or press Enter in the terminal to force-quit)" "media-playback-start"
    _await_spotify_close

    prefs="$(_find_prefs)"
    if [[ -z "$prefs" ]]; then
        _die "Could not locate spotify/prefs after first run; aborting."
    fi
    echo "  · Found prefs at $prefs"
    spicetify config prefs_path "$prefs" >/dev/null 2>&1 || true
}

# ------------------------------------------------------------------------------
# Phase 5 — Apply Spicetify backup with progressive recovery
# ------------------------------------------------------------------------------
_apply_spicetify() {
    local spotify_root="$1"

    if _run_may_fail spicetify backup apply; then
        _sync_spotify_wrapper_asset "$spotify_root"
        return 0
    fi

    # Stale backup — try restore then redo
    if _run_may_fail spicetify restore backup apply; then
        _sync_spotify_wrapper_asset "$spotify_root"
        return 0
    fi

    # Deadlocked (version mismatch) — nuke backup state and retry
    local cfg_dir
    cfg_dir="$(dirname "$(spicetify -c 2>/dev/null)" 2>/dev/null)"
    if [[ -n "$cfg_dir" ]]; then
        echo "  · Clearing stale backup state…"
        rm -rf "${cfg_dir:?}/Backup" 2>/dev/null || true
        if [[ -f "${cfg_dir}/config-xpui.ini" ]]; then
            sed -i '/^\[Backup\]/,/^\[/{/^\[Backup\]/!{/^\[/!d}}' \
                "${cfg_dir}/config-xpui.ini" 2>/dev/null || true
        fi
    fi

    if _run_may_fail spicetify backup apply; then
        _sync_spotify_wrapper_asset "$spotify_root"
        return 0
    fi

    return 1
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
    if ! _enable_spicetify_theming; then
        echo "  · warning: Could not enable Spicetify theming in config; continuing." >&2
    fi

    if [[ -x "$THEME_SCRIPT" ]]; then
        local theme_name
        theme_name="$(jq -r '.appearance.wallpaperTheming.spicetifyTheme // "Inir"' "$CONFIG_PATH" 2>/dev/null || printf 'Inir')"
        if [[ "$theme_name" != "Inir" && "$theme_name" != "InirTUI" ]]; then
            theme_name="Inir"
        fi
        echo "  · Applying iNiR theme ($theme_name)…"
        if "$THEME_SCRIPT" --theme "$theme_name"; then
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

    setup_progress 1 $TOTAL "Checking for incompatible Spotify installs"
    if ! _remove_incompatible; then
        _die "Could not resolve existing Spotify installation conflicts. Review the message above and rerun setup."
    fi

    setup_progress 2 $TOTAL "Installing Spotify (AUR) and Spicetify CLI"
    _install_packages

    setup_progress 3 $TOTAL "Configuring Spicetify paths and assets"
    _configure_spicetify

    setup_progress 4 $TOTAL "Checking Spotify configuration and preferences"
    prefs="$(_find_prefs)"
    if [[ -z "$prefs" ]]; then
        _generate_prefs_if_needed
    else
        echo "  · Found existing prefs at $prefs"
        spicetify config prefs_path "$prefs" >/dev/null 2>&1 || true
    fi

    setup_progress 5 $TOTAL "Applying Spicetify backup"
    spotify_dir="$(_spotify_dir)"
    if ! _apply_spicetify "$spotify_dir"; then
        # If first apply fails and prefs were missing or incomplete, try first-run launch
        echo "  · backup apply failed; launching Spotify to refresh preferences…"
        _generate_prefs_if_needed
        if ! _apply_spicetify "$spotify_dir"; then
            _die "Spicetify backup apply failed even after generating prefs. Check the error above."
        fi
    fi

    setup_progress 6 $TOTAL "Installing Spicetify Marketplace and applying theme"
    _install_marketplace
    _apply_theme

    setup_done "Spotify + Spicetify ready with iNiR theming enabled. Launch Spotify to verify."
else
    TOTAL=2
    setup_progress 1 $TOTAL "Installing Spotify via Flatpak (no Spicetify on non-Arch)"
    install_flatpak com.spotify.Client

    setup_progress 2 $TOTAL "Skipping Spicetify (unsupported on Flatpak Spotify)"
    setup_done "Spotify installed via Flatpak. Spicetify was skipped."
fi

setup_finish_pause
