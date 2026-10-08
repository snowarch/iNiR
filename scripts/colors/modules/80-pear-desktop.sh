#!/usr/bin/env bash
set -euo pipefail
#
# Supports both package names: "pear-desktop" (AUR) and "youtube-music" (CachyOS).
# They are the same Electron app — auto-detected at runtime.
#
# Port 9223 avoids conflict with Spotify/Spicetify which uses 9222.
#
# Called from: scripts/colors/applycolor.sh (color pipeline)

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/module-runtime.sh"
COLOR_MODULE_ID="pear-desktop"

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
PEAR_CONFIG_DIR="$XDG_CONFIG_HOME/YouTube Music"
PEAR_CONFIG_FILE="$PEAR_CONFIG_DIR/config.json"

GENERATED_CSS="$STATE_DIR/user/generated/pear-desktop-theme.css"
PEAR_LITERALS_CSS="$SCRIPT_DIR/templates/pear-desktop-literals.css"
PEAR_FINISH_CSS="$SCRIPT_DIR/templates/pear-desktop-finish.css"
COLORS_JSON="$STATE_DIR/user/generated/app-palette.json"
[[ -f "$COLORS_JSON" ]] || COLORS_JSON="$STATE_DIR/user/generated/palette.json"
[[ -f "$COLORS_JSON" ]] || COLORS_JSON="$STATE_DIR/user/generated/colors.json"
CDP_PORT=9223

# --- Package detection ---
# Pear Desktop and YouTube Music are the same Electron app (th-ch/youtube-music
# renamed to pear-devs/pear-desktop). CachyOS ships "youtube-music", AUR ships
# "pear-desktop". They conflict — only one can be installed. Detect which.

PEAR_BINARY=""
PEAR_ASAR_PATTERN=""

detect_package() {
  if command -v pear-desktop &>/dev/null; then
    PEAR_BINARY="pear-desktop"
    PEAR_ASAR_PATTERN="pear-desktop/app.asar"
  elif command -v youtube-music &>/dev/null; then
    PEAR_BINARY="youtube-music"
    PEAR_ASAR_PATTERN="youtube-music/app.asar"
  elif [[ -d "$PEAR_CONFIG_DIR" ]]; then
    # No binary on PATH but the app's config is here (an AppImage): themed through that config; the DevTools flag stays alone without a known launcher.
    PEAR_ASAR_PATTERN="(pear-desktop|youtube-music)/app\.asar"
  else
    return 1
  fi
  return 0
}

# Pear inserts this file once at load (webContents.insertCSS) and the live update appends a <style> over it,
# so every value here must be able to lose to the next one: same selectors, no rule outside them.

read_hex() {
  local token="$1" fallback="${2:-#000000}"
  local hex
  hex=$(jq -r ".${token} // empty" "$COLORS_JSON" 2>/dev/null) || true
  if [[ -n "$hex" ]]; then
    printf '%s' "$hex"
  else
    printf '%s' "$fallback"
  fi
}

generate_css_from_colors_json() {
  local bg surface raised popup fg subtext border accent on_accent accent_container on_accent_container error selection

  bg=$(read_hex 'app_background // .surface' "#121318")
  surface=$(read_hex 'app_surface // .surface_container_low' "#1a1b20")
  raised=$(read_hex 'app_surface_elevated // .surface_container' "#1e1f25")
  popup=$(read_hex 'app_surface_popup // .surface_container_high' "#292a2f")
  fg=$(read_hex 'app_foreground // .on_surface' "#e3e2e9")
  subtext=$(read_hex 'app_subtext // .on_surface_variant' "#c5c6d0")
  border=$(read_hex 'app_border_subtle // .outline_variant' "#44464f")
  accent=$(read_hex 'app_accent // .primary' "#b2c5ff")
  on_accent=$(read_hex 'app_on_accent // .on_primary' "#182e60")
  accent_container=$(read_hex 'app_accent_container // .primary_container' "#304578")
  on_accent_container=$(read_hex on_primary_container "#dae2ff")
  error=$(read_hex error "#ffb4ab")
  selection=$(read_hex 'app_selection // .secondary_container' "#404659")

  cat <<EOCSS
/* iNiR — Pear Desktop (YouTube Music). Generated from the current palette; edits are overwritten. */

html, html[dark], html:not(.style-scope) {
  --inir-bg: ${bg};
  --inir-surface: ${surface};
  --inir-raised: ${raised};
  --inir-popup: ${popup};
  --inir-fg: ${fg};
  --inir-subtext: ${subtext};
  --inir-border: ${border};
  --inir-accent: ${accent};
  --inir-on-accent: ${on_accent};
  --inir-accent-container: ${accent_container};
  --inir-on-accent-container: ${on_accent_container};
  --inir-error: ${error};
  --inir-selection: ${selection};
  --inir-fg-05: color-mix(in srgb, var(--inir-fg) 5%, transparent);
  --inir-fg-10: color-mix(in srgb, var(--inir-fg) 10%, transparent);
  --inir-fg-15: color-mix(in srgb, var(--inir-fg) 15%, transparent);
  --inir-fg-20: color-mix(in srgb, var(--inir-fg) 20%, transparent);
  --inir-fg-30: color-mix(in srgb, var(--inir-fg) 30%, transparent);
  --inir-fg-50: color-mix(in srgb, var(--inir-fg) 50%, transparent);
  --inir-fg-70: color-mix(in srgb, var(--inir-fg) 70%, transparent);
  --inir-disabled: color-mix(in srgb, var(--inir-fg) 40%, var(--inir-bg));

  /* YouTube's system palette */
  --yt-sys-color-baseline--base-background: var(--inir-bg) !important;
  --yt-sys-color-baseline--raised-background: var(--inir-raised) !important;
  --yt-sys-color-baseline--menu-background: var(--inir-popup) !important;
  --yt-sys-color-baseline--static-black: var(--inir-bg) !important;
  --yt-sys-color-baseline--solid-background-inverse: var(--inir-bg) !important;
  --yt-sys-color-baseline--frosted-glass-desktop: color-mix(in srgb, var(--inir-bg) 85%, transparent) !important;
  --yt-sys-color-baseline--additive-background: var(--inir-fg-10) !important;
  --yt-sys-color-baseline--tonal-background: var(--inir-fg-10) !important;
  --yt-sys-color-baseline--tonal-wash: var(--inir-fg-05) !important;
  --yt-sys-color-baseline--tonal-rim: var(--inir-fg-10) !important;
  --yt-sys-color-baseline--button-chip-background-hover: var(--inir-fg-20) !important;
  --yt-sys-color-baseline--mono-tonal-hover: var(--inir-fg-20) !important;
  --yt-sys-color-baseline--state-mono-standard-hovered: var(--inir-fg-05) !important;
  --yt-sys-color-baseline--state-mono-standard-pressed: var(--inir-fg-10) !important;
  --yt-sys-color-baseline--state-overlay-standard-hovered: var(--inir-fg-05) !important;
  --yt-sys-color-baseline--state-overlay-standard-pressed: var(--inir-fg-05) !important;
  --yt-sys-color-baseline--text-primary: var(--inir-fg) !important;
  --yt-sys-color-baseline--text-secondary: var(--inir-subtext) !important;
  --yt-sys-color-baseline--text-disabled: var(--inir-disabled) !important;
  --yt-sys-color-baseline--text-primary-inverse: var(--inir-on-accent) !important;
  --yt-sys-color-baseline--inverted-background: var(--inir-accent) !important;
  --yt-sys-color-baseline--inverted-background-hover: color-mix(in srgb, var(--inir-accent) 88%, var(--inir-fg)) !important;
  --yt-sys-color-baseline--mono-filled-hover: color-mix(in srgb, var(--inir-accent) 88%, var(--inir-fg)) !important;
  --yt-sys-color-baseline--call-to-action: var(--inir-accent) !important;
  --yt-sys-color-baseline--call-to-action-hover: color-mix(in srgb, var(--inir-accent) 88%, var(--inir-fg)) !important;
  --yt-sys-color-baseline--call-to-action-inverse: var(--inir-accent) !important;
  --yt-sys-color-baseline--suggested-action: var(--inir-accent-container) !important;
  --yt-sys-color-baseline--suggested-action-hover: color-mix(in srgb, var(--inir-accent-container) 88%, var(--inir-fg)) !important;
  --yt-sys-color-baseline--outline: var(--inir-fg-20) !important;
  --yt-sys-color-baseline--outline-opaque: var(--inir-border) !important;
  --yt-sys-color-baseline--outline-rim: var(--inir-fg-15) !important;
  --yt-sys-color-baseline--touch-response: var(--inir-fg) !important;
  --yt-sys-color-baseline--wordmark-text: var(--inir-fg) !important;
  --yt-sys-color-baseline--scrim-background-gradient-1: color-mix(in srgb, var(--inir-bg) 0%, transparent) !important;
  --yt-sys-color-baseline--scrim-background-gradient-2: color-mix(in srgb, var(--inir-bg) 30%, transparent) !important;
  --yt-sys-color-baseline--scrim-background-gradient-3: color-mix(in srgb, var(--inir-bg) 60%, transparent) !important;
  --yt-sys-color-baseline--scrim-background-gradient-4: color-mix(in srgb, var(--inir-bg) 90%, transparent) !important;
  --yt-sys-color-baseline--scrim-background-gradient-5: var(--inir-bg) !important;

  /* YouTube Music's own palette */
  --ytmusic-background: var(--inir-bg) !important;
  --ytmusic-nav-bar: var(--inir-bg) !important;
  --ytmusic-detail-header: var(--inir-bg) !important;
  --ytmusic-player-page-background: var(--inir-bg) !important;
  --ytmusic-general-background-a: var(--inir-surface) !important;
  --ytmusic-general-background-c: var(--inir-bg) !important;
  --ytmusic-brand-background-solid: var(--inir-raised) !important;
  --ytmusic-player-bar-background: var(--inir-raised) !important;
  --ytmusic-search-background: var(--inir-raised) !important;
  --ytmusic-search-border: var(--inir-border) !important;
  --ytmusic-search-bar-background-bauhaus: var(--inir-fg-10) !important;
  --ytmusic-search-bar-border-bauhaus: var(--inir-fg-10) !important;
  --ytmusic-search-box-text-secondary: var(--inir-subtext) !important;
  --ytmusic-search-suggestion-text-secondary: var(--inir-subtext) !important;
  --ytmusic-search-suggestion-icon-color: var(--inir-subtext) !important;
  --ytmusic-search-suggestion-focus-active: var(--inir-accent) !important;
  --ytmusic-search-suggestion-focus-active-background: var(--inir-fg-10) !important;
  --ytmusic-dialog-background-color: var(--inir-popup) !important;
  --ytmusic-dropdown-background: var(--inir-popup) !important;
  --ytmusic-dropdown-border-color: var(--inir-fg-10) !important;
  --ytmusic-dropdown-item-hover-background: var(--inir-fg-10) !important;
  --ytmusic-alert-with-actions-background: var(--inir-popup) !important;
  --ytmusic-alert-with-actions-header-text: var(--inir-fg) !important;
  --ytmusic-confirm-dialog-outline: var(--inir-border) !important;
  --ytmusic-opalescence-dark-grey: var(--inir-popup) !important;
  --ytmusic-horizontal-action-card-background: var(--inir-surface) !important;
  --ytmusic-item-section-info-panel-overview-background: var(--inir-surface) !important;
  --ytmusic-static-brand-black: var(--inir-raised) !important;
  --ytmusic-white-5: var(--inir-border) !important;
  --ytmusic-text-primary: var(--inir-fg) !important;
  --ytmusic-text-secondary: var(--inir-subtext) !important;
  --ytmusic-text-disabled: var(--inir-disabled) !important;
  --ytmusic-text-primary-inverse: var(--inir-on-accent) !important;
  --ytmusic-display-2_-_color: var(--inir-fg) !important;
  --ytmusic-display-2_-_--yt-endpoint-color: var(--inir-fg) !important;
  --ytmusic-display-2_-_--yt-endpoint-hover-color: var(--inir-fg) !important;
  --ytmusic-display-2_-_--yt-endpoint-visited-color: var(--inir-fg) !important;
  --ytmusic-wordmark-text: var(--inir-fg) !important;
  --ytmusic-overlay-text-primary: var(--inir-fg) !important;
  --ytmusic-overlay-text-secondary: var(--inir-fg-70) !important;
  --ytmusic-overlay-text-disabled: var(--inir-fg-30) !important;
  --ytmusic-overlay-button-primary: var(--inir-fg-30) !important;
  --ytmusic-overlay-button-secondary: var(--inir-fg-10) !important;
  --ytmusic-inline-badge-color: var(--inir-fg-70) !important;
  --ytmusic-color-badge: var(--inir-subtext) !important;
  --ytmusic-icon-inactive: var(--inir-subtext) !important;
  --ytmusic-icon-disabled: var(--inir-disabled) !important;
  --ytmusic-inactive-tab: var(--inir-fg-50) !important;
  --ytmusic-divider: var(--inir-fg-10) !important;
  --ytmusic-guide-divider: var(--inir-fg-10) !important;
  --ytmusic-guide-hover: var(--inir-fg-10) !important;
  --ytmusic-guide-entry-focus-border: var(--inir-accent) !important;
  --ytmusic-guide-signin-promo-text-secondary: var(--inir-subtext) !important;
  --ytmusic-ten-percent-layer: var(--inir-fg-10) !important;
  --ytmusic-badge-chip-background: var(--inir-fg-10) !important;
  --ytmusic-badge-chip-inactive-hover: var(--inir-fg-20) !important;
  --ytmusic-explore-chip-background: var(--inir-fg-10) !important;
  --ytmusic-toggle-button-chip-active-background: var(--inir-accent) !important;
  --ytmusic-toggle-button-chip-border-color: var(--inir-fg-30) !important;
  --ytmusic-inverted-background: var(--inir-accent) !important;
  --ytmusic-menu-item-hover-background-color: var(--inir-fg-10) !important;
  --ytmusic-menu-item-focus-background-color: var(--inir-fg-10) !important;
  --ytmusic-multiselect-form-item-hover-background-color: var(--inir-fg-10) !important;
  --ytmusic-multiselect-form-item-focus-background-color: var(--inir-fg-10) !important;
  --ytmusic-responsive-list-item-checked-background-bauhaus: var(--inir-selection) !important;
  --ytmusic-navigation-button-outline-color: var(--inir-fg-30) !important;
  --ytmusic-immersive-carousel-button-border: var(--inir-fg-30) !important;
  --ytmusic-shelf-bottom-button-border-color: var(--inir-fg-30) !important;
  --ytmusic-carousel-shelf-button-disabled: var(--inir-raised) !important;
  --ytmusic-color-close-button: var(--inir-fg-50) !important;
  --ytmusic-color-input-border: var(--inir-border) !important;
  --ytmusic-message-renderer-icon-color: var(--inir-subtext) !important;
  --ytmusic-message-renderer-text-color: var(--inir-subtext) !important;
  --ytmusic-call-to-action: var(--inir-accent) !important;
  --ytmusic-call-to-action-disclaimer: var(--inir-fg-70) !important;
  --ytmusic-focus-active: var(--inir-accent) !important;
  --ytmusic-themed-blue: var(--inir-accent) !important;
  --ytmusic-color-lightblue: var(--inir-accent) !important;
  --ytmusic-setting-item-toggle-active: var(--inir-accent) !important;
  --ytmusic-setting-item-toggle-inactive-bar: var(--inir-fg-30) !important;
  --ytmusic-setting-item-toggle-inactive-button: var(--inir-subtext) !important;
  --ytmusic-brand-link-text: var(--inir-accent) !important;
  --ytmusic-playback-progress-color: var(--inir-accent) !important;
  --ytmusic-progress-container: var(--inir-fg-30) !important;
  --ytmusic-play-pause-button-background: var(--inir-accent) !important;
  --ytmusic-play-button-disabled-icon-color: var(--inir-disabled) !important;
  --ytmusic-player-bar-container-color: var(--inir-fg-20) !important;
  --ytmusic-player-bar-ink-color: var(--inir-fg-70) !important;
  --ytmusic-player-bar-disabled-secondary-color: var(--inir-fg-50) !important;
  --ytmusic-player-bar-repeat-disabled: var(--inir-fg-30) !important;
  --ytmusic-player-controls-button-disabled: var(--inir-fg-20) !important;
  --ytmusic-touch-response: var(--inir-fg) !important;
  --ytmusic-color-white1: var(--inir-fg) !important;
  --ytmusic-color-white1-alpha10: var(--inir-fg-10) !important;
  --ytmusic-color-white1-alpha15: var(--inir-fg-15) !important;
  --ytmusic-color-white1-alpha20: var(--inir-fg-20) !important;
  --ytmusic-color-white1-alpha25: var(--inir-fg-20) !important;
  --ytmusic-color-white1-alpha30: var(--inir-fg-30) !important;
  --ytmusic-color-white1-alpha50: var(--inir-fg-50) !important;
  --ytmusic-color-white1-alpha70: var(--inir-fg-70) !important;
  --ytmusic-color-white1-alpha95: var(--inir-fg) !important;
  --ytmusic-color-white-opacity-0-05: var(--inir-fg-05) !important;
  --ytmusic-color-white-opacity-0-5: var(--inir-fg-50) !important;
  --ytmusic-color-grey2: var(--inir-subtext) !important;
  --ytmusic-color-grey3: var(--inir-subtext) !important;
  --ytmusic-color-grey4: var(--inir-disabled) !important;
  --ytmusic-color-grey5: var(--inir-disabled) !important;
  --ytmusic-color-grey-4: var(--inir-subtext) !important;
  --ytmusic-color-black1: var(--inir-raised) !important;
  --ytmusic-color-black2: var(--inir-surface) !important;
  --ytmusic-color-black4: var(--inir-bg) !important;
  --ytmusic-color-blackpure: var(--inir-bg) !important;
  --ytmusic-color-navyblue: var(--inir-accent-container) !important;

  /* Older components still read the legacy spec names */
  --yt-spec-general-background-a: var(--inir-surface) !important;
  --yt-spec-general-background-b: var(--inir-bg) !important;
  --yt-spec-general-background-c: var(--inir-bg) !important;
  --yt-spec-base-background: var(--inir-bg) !important;
  --yt-spec-raised-background: var(--inir-raised) !important;
  --yt-spec-menu-background: var(--inir-popup) !important;
  --yt-spec-text-primary: var(--inir-fg) !important;
  --yt-spec-text-secondary: var(--inir-subtext) !important;
  --yt-spec-10-percent-layer: var(--inir-fg-10) !important;
  --yt-spec-call-to-action: var(--inir-accent) !important;
  --yt-spec-themed-blue: var(--inir-accent) !important;
  --yt-spec-commerce-filled-hover: var(--inir-accent) !important;

  /* Pear's own title bar */
  --titlebar-background-color: var(--inir-bg) !important;
  --ytmusic-scrollbar-width: 0px !important;
  --ytd-scrollbar-width: 0px !important;
}

html, body { background: var(--inir-bg) !important; color-scheme: $([[ "$(theme_mode)" == light ]] && printf light || printf dark); }
* { scrollbar-width: none !important; }
::selection { background: var(--inir-selection); color: var(--inir-fg); }

/* Pear's in-app menu (Plugins, Options, View...) */
#ytmd-title-bar-main-panel {
  background: var(--inir-bg) !important;
  border-bottom: 1px solid var(--inir-fg-10) !important;
  color: var(--inir-fg) !important;
}
#ytmd-title-bar-main-panel li,
#ytmd-title-bar-main-panel button,
#ytmd-title-bar-main-panel svg { color: var(--inir-fg) !important; }
#ytmd-title-bar-main-panel li:hover,
#ytmd-title-bar-main-panel button:hover { background-color: var(--inir-fg-10) !important; }
#ytmd-title-bar-main-panel [data-selected='true'] { background-color: var(--inir-fg-15) !important; }

/* The guide and the bars paint fixed colours instead of reading the palette */
#guide-wrapper.ytmusic-app,
#mini-guide-background.ytmusic-app-layout,
#nav-bar-background.ytmusic-app-layout,
ytmusic-nav-bar,
ytmusic-tabs.stuck { background: var(--inir-bg) !important; }
#nav-bar-divider.ytmusic-app-layout,
#guide-wrapper.ytmusic-app { border-color: var(--inir-fg-10) !important; }
#player-bar-background.ytmusic-app-layout,
ytmusic-player-bar { background: var(--inir-raised) !important; }

/* Pills and buttons that hardcode white */
a.sign-in-link.app-bar-button {
  background: var(--inir-accent) !important;
  color: var(--inir-on-accent) !important;
}
ytmusic-chip-cloud-chip-renderer[chip-style="STYLE_DEFAULT"] a.ytmusic-chip-cloud-chip-renderer,
ytmusic-chip-cloud-chip-renderer[chip-style="STYLE_UNKNOWN"] a.ytmusic-chip-cloud-chip-renderer {
  background-color: var(--inir-fg-10) !important;
  color: var(--inir-fg) !important;
}
.content-wrapper.ytmusic-play-button-renderer { background: var(--inir-accent) !important; }
ytmusic-play-button-renderer { --ytmusic-play-button-icon-color: var(--inir-on-accent) !important; }

/* YouTube's button shapes: "mono" is white on dark in its stylesheet, here it is the palette's text */
.ytSpecButtonShapeNextMono.ytSpecButtonShapeNextFilled {
  background: var(--inir-fg) !important;
  color: var(--inir-bg) !important;
  border-color: transparent !important;
}
.ytSpecButtonShapeNextMono.ytSpecButtonShapeNextFilled:hover { background: color-mix(in srgb, var(--inir-fg) 88%, var(--inir-bg)) !important; }
.ytSpecButtonShapeNextMono.ytSpecButtonShapeNextTonal { background: var(--inir-fg-10) !important; color: var(--inir-fg) !important; border-color: var(--inir-fg-20) !important; }
.ytSpecButtonShapeNextMono.ytSpecButtonShapeNextOutline,
.ytSpecButtonShapeNextMono.ytSpecButtonShapeNextText { color: var(--inir-fg) !important; border-color: var(--inir-fg-20) !important; }
.ytSpecButtonShapeNextMono.ytSpecButtonShapeNextTonal:hover,
.ytSpecButtonShapeNextMono.ytSpecButtonShapeNextOutline:hover,
.ytSpecButtonShapeNextMono.ytSpecButtonShapeNextText:hover { background: var(--inir-fg-20) !important; }
.ytSpecTouchFeedbackShapeTouchResponse .ytSpecTouchFeedbackShapeFill { background-color: var(--inir-fg) !important; }

/* Player page tabs (Up next, Lyrics, Related) */
tp-yt-paper-tab.ytmusic-player-page { color: var(--inir-subtext) !important; }
tp-yt-paper-tab.ytmusic-player-page.iron-selected { color: var(--inir-fg) !important; }
tp-yt-paper-tabs.ytmusic-player-page { --paper-tabs-selection-bar-color: var(--inir-accent) !important; }

/* Popups, menus and toasts */
tp-yt-paper-listbox.ytmusic-menu-popup-renderer,
ytmusic-menu-popup-renderer,
ytd-multi-page-menu-renderer,
tp-yt-paper-dialog,
ytmusic-dialog { background-color: var(--inir-popup) !important; color: var(--inir-fg) !important; }
tp-yt-paper-toast { background: var(--inir-popup) !important; color: var(--inir-fg) !important; }

/* Progress and volume */
#progress-bar.ytmusic-player-bar,
#volume-slider.ytmusic-player-bar,
#expand-volume-slider.ytmusic-player-bar {
  --paper-slider-active-color: var(--inir-accent) !important;
  --paper-slider-knob-color: var(--inir-accent) !important;
  --paper-slider-knob-start-color: var(--inir-accent) !important;
  --paper-slider-knob-start-border-color: var(--inir-accent) !important;
  --paper-slider-container-color: var(--inir-fg-20) !important;
  --paper-slider-secondary-color: var(--inir-fg-30) !important;
}

/* The YouTube Music logo; the menu button stays */
ytmusic-nav-bar ytmusic-logo,
ytmusic-nav-bar .ytmusic-logo { display: none !important; }
ytmusic-nav-bar .left-content.ytmusic-nav-bar { width: auto !important; min-width: 56px !important; padding-left: 12px !important; }
EOCSS
  [[ -f "$PEAR_LITERALS_CSS" ]] && cat "$PEAR_LITERALS_CSS"
  cat <<'EOCHIPS'
ytmusic-chip-cloud-chip-renderer[is-selected] a.ytmusic-chip-cloud-chip-renderer,
ytmusic-chip-cloud-chip-renderer[chip-style="STYLE_PRIMARY"] a.ytmusic-chip-cloud-chip-renderer {
  background-color: var(--inir-accent) !important;
}
ytmusic-chip-cloud-chip-renderer[is-selected] a.ytmusic-chip-cloud-chip-renderer,
ytmusic-chip-cloud-chip-renderer[is-selected] a.ytmusic-chip-cloud-chip-renderer .text.ytmusic-chip-cloud-chip-renderer,
ytmusic-chip-cloud-chip-renderer[chip-style="STYLE_PRIMARY"] a.ytmusic-chip-cloud-chip-renderer,
ytmusic-chip-cloud-chip-renderer[chip-style="STYLE_PRIMARY"] a.ytmusic-chip-cloud-chip-renderer .text.ytmusic-chip-cloud-chip-renderer {
  color: var(--inir-on-accent) !important;
  --iron-icon-fill-color: var(--inir-on-accent) !important;
  --icon-color: var(--inir-on-accent) !important;
}
/* The white pills (Save, Add to library) read as YouTube's filled mono button */
ytmusic-chip-cloud-chip-renderer[chip-style="STYLE_TRANSPARENT"]:not([is-selected]) a.ytmusic-chip-cloud-chip-renderer,
ytmusic-chip-cloud-chip-renderer[chip-style="STYLE_SECONDARY"]:not([is-selected]) a.ytmusic-chip-cloud-chip-renderer {
  background-color: var(--inir-fg) !important;
}
ytmusic-chip-cloud-chip-renderer[chip-style="STYLE_TRANSPARENT"]:not([is-selected]) a.ytmusic-chip-cloud-chip-renderer,
ytmusic-chip-cloud-chip-renderer[chip-style="STYLE_TRANSPARENT"]:not([is-selected]) .text.ytmusic-chip-cloud-chip-renderer,
ytmusic-chip-cloud-chip-renderer[chip-style="STYLE_SECONDARY"]:not([is-selected]) a.ytmusic-chip-cloud-chip-renderer,
ytmusic-chip-cloud-chip-renderer[chip-style="STYLE_SECONDARY"]:not([is-selected]) .text.ytmusic-chip-cloud-chip-renderer {
  color: var(--inir-bg) !important;
  --iron-icon-fill-color: var(--inir-bg) !important;
  --icon-color: var(--inir-bg) !important;
}
EOCHIPS
  local font
  font="$(shell_font_family)"
  printf '\n:root { --inir-font: "%s"; }\n' "${font:-Roboto}"
  [[ -f "$PEAR_FINISH_CSS" ]] && cat "$PEAR_FINISH_CSS"
  return 0
}

# --- Config registration ---

register_theme_in_config() {
  local css_path="$1"

  [[ -d "$PEAR_CONFIG_DIR" ]] || {
    log_module "config dir not found — app not installed?"
    return 1
  }

  # Create config.json if missing
  [[ -f "$PEAR_CONFIG_FILE" ]] || echo '{}' > "$PEAR_CONFIG_FILE"

  # Check if our theme is already registered
  if jq -e --arg p "$css_path" '.options.themes // [] | index($p) != null' "$PEAR_CONFIG_FILE" >/dev/null 2>&1; then
    return 0
  fi

  # Add theme to themes array
  local tmp
  tmp=$(mktemp)
  if jq --arg p "$css_path" '.options.themes = ((.options.themes // []) + [$p] | unique)' "$PEAR_CONFIG_FILE" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$PEAR_CONFIG_FILE"
    log_module "registered theme CSS in pear-desktop config"
  else
    rm -f "$tmp"
    log_module "failed to update pear-desktop config"
    return 1
  fi
}

# The Arch wrapper appends ~/.config/pear-flags.conf to every launch (menu, tray, autostart, terminal),
# so the port goes there. Other packages get a user .desktop override of the entry that runs the binary.

PEAR_FLAGS_FILE="$XDG_CONFIG_HOME/pear-flags.conf"

ensure_cdp_flag() {
  [[ -n "$PEAR_BINARY" ]] || return 0
  local flag="--remote-debugging-port=$CDP_PORT" launcher
  launcher="$(command -v "$PEAR_BINARY" 2>/dev/null || true)"

  if [[ -n "$launcher" ]] && grep -qs 'pear-flags.conf' "$launcher"; then
    if append_line_once "$PEAR_FLAGS_FILE" "$flag"; then
      log_module "added $flag to $PEAR_FLAGS_FILE (live theme updates from the next launch)"
    fi
    return 0
  fi

  local user_apps="$HOME/.local/share/applications" system_desktop="" candidate override
  for candidate in /usr/share/applications/*.desktop; do
    [[ -f "$candidate" ]] || continue
    if grep -qE "^Exec=(/usr/bin/)?${PEAR_BINARY}( |$)" "$candidate"; then
      system_desktop="$candidate"
      break
    fi
  done
  [[ -n "$system_desktop" ]] || return 0
  override="$user_apps/$(basename "$system_desktop")"
  if [[ -f "$override" ]] && grep -q -- "$flag" "$override" 2>/dev/null; then
    return 0
  fi
  mkdir -p "$user_apps"
  sed -E "s|^Exec=((/usr/bin/)?${PEAR_BINARY})|Exec=\\1 $flag|" "$system_desktop" > "$override"
  log_module "created $(basename "$override") override with $flag"
}

# --- Live reload via CDP ---

inject_css_cdp() {
  local css_file="$1"
  local inject_script="$SCRIPT_DIR/pear-css-inject.py"
  local py result

  # Check if pear-desktop is running with CDP enabled
  if ! curl -s --connect-timeout 1 "http://127.0.0.1:${CDP_PORT}/json" >/dev/null 2>&1; then
    return 1
  fi

  py="$(venv_python)"
  [[ -f "$inject_script" ]] || return 1
  result="$("$py" "$inject_script" "$css_file" --port "$CDP_PORT" 2>/dev/null)" || return 1
  if [[ "$result" == "injected" ]]; then
    log_module "injected CSS via CDP (live update)"
  else
    log_module "live CSS already current"
  fi
  return 0
}

reload_pear() {
  local css_file="$1"

  # Try CDP injection first (instant, no flicker)
  if inject_css_cdp "$css_file"; then
    return 0
  fi

  # CDP unavailable — check if app is running at all
  if ! pgrep -f "$PEAR_ASAR_PATTERN" >/dev/null 2>&1; then
    log_module "pear-desktop not running"
    return 0
  fi

  # App is running but without CDP — CSS is deployed to config and will apply on next launch.
  # Never kill and restart the app: the user perceives it as the app crashing.
  log_module "CDP unavailable — CSS registered in config, will apply on next app launch"
}

# --- Main ---

main() {
  local enabled
  enabled=$(config_bool '.appearance.wallpaperTheming.enablePearDesktop' true)
  [[ "$enabled" == 'true' ]] || {
    log_module "disabled in config"
    exit 0
  }

  # Detect which package is installed (youtube-music or pear-desktop)
  if ! detect_package; then
    log_module "pear-desktop / youtube-music not installed — skipping"
    exit 0
  fi
  log_module "detected package: ${PEAR_BINARY:-an install without a binary on PATH (AppImage)}"

  # Generate CSS from generated palette
  local css_file="$GENERATED_CSS"
  if [[ ! -f "$COLORS_JSON" ]]; then
    log_module "no generated palette — skipping"
    exit 0
  fi
  command -v jq &>/dev/null || { log_module "jq not installed — skipping"; exit 0; }
  ensure_generated_dirs
  if generate_css_from_colors_json | write_if_changed "$css_file"; then
    log_module "generated CSS: $css_file"
  fi

  # Register theme in pear-desktop config (for disk-based loading on next app start)
  register_theme_in_config "$css_file" || true

  ensure_cdp_flag

  # Reload app with new CSS (CDP injection or restart)
  reload_pear "$css_file"

  log_module "done"
}

main "$@"
