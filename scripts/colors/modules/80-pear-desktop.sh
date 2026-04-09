#!/usr/bin/env bash
set -euo pipefail
# Pear Desktop (YouTube Music) theming module: generates Material You CSS
# and optionally injects it live via CDP if the app is running with debug port.
#
# CSS based on catppuccin/youtubemusic with Material You color mapping.
#
# Live reload requires CDP enabled. The module creates a desktop override
# that launches youtube-music with --remote-debugging-port=9222.
#
# Called from: scripts/colors/applycolor.sh (color pipeline)

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/module-runtime.sh"
COLOR_MODULE_ID="pear-desktop"

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
PEAR_CONFIG_DIR="$XDG_CONFIG_HOME/YouTube Music"
PEAR_CONFIG_FILE="$PEAR_CONFIG_DIR/config.json"

GENERATED_CSS="$STATE_DIR/user/generated/pear-desktop-theme.css"
COLORS_JSON="$STATE_DIR/user/generated/colors.json"
CDP_PORT=9222

# --- CSS generation from colors.json (catppuccin structure with Material You colors) ---

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
  # Material You → Catppuccin-style hierarchy mapping
  local base mantle crust
  local surface0 surface1 surface2
  local text subtext0 subtext1
  local overlay0 overlay1 overlay2
  local accent on_accent
  local green red

  base=$(read_hex surface "#1e1e2e")
  mantle=$(read_hex surface_container_low "#181825")
  crust=$(read_hex surface_dim "#11111b")
  surface0=$(read_hex surface_container "#313244")
  surface1=$(read_hex surface_container_high "#45475a")
  surface2=$(read_hex surface_container_highest "#585b70")
  text=$(read_hex on_surface "#cdd6f4")
  subtext0=$(read_hex on_surface_variant "#a6adc8")
  subtext1=$(read_hex outline "#7f849c")
  overlay0=$(read_hex outline_variant "#6c7086")
  overlay1=$(read_hex outline "#7f849c")
  overlay2=$(read_hex outline "#9399b2")
  accent=$(read_hex primary "#cba6f7")
  on_accent=$(read_hex on_primary "#1e1e2e")
  green=$(read_hex tertiary "#a6e3a1")
  red=$(read_hex error "#f38ba8")

  cat <<EOCSS
/**
 * iNiR Material You — Pear Desktop (YouTube Music)
 * Auto-generated from wallpaper colors. Do not edit.
 * Based on catppuccin/youtubemusic structure.
 */

html:not(.style-scope) {
  --ctp-rosewater: ${accent};
  --ctp-flamingo: ${accent};
  --ctp-pink: ${accent};
  --ctp-mauve: ${accent};
  --ctp-red: ${red};
  --ctp-maroon: ${red};
  --ctp-peach: ${accent};
  --ctp-yellow: ${accent};
  --ctp-green: ${green};
  --ctp-teal: ${green};
  --ctp-sky: ${accent};
  --ctp-sapphire: ${accent};
  --ctp-blue: ${accent};
  --ctp-lavender: ${accent};
  --ctp-text: ${text};
  --ctp-subtext1: ${subtext0};
  --ctp-subtext0: ${subtext1};
  --ctp-overlay2: ${overlay2};
  --ctp-overlay1: ${overlay1};
  --ctp-overlay0: ${overlay0};
  --ctp-surface2: ${surface2};
  --ctp-surface1: ${surface1};
  --ctp-surface0: ${surface0};
  --ctp-base: ${base};
  --ctp-mantle: ${mantle};
  --ctp-crust: ${crust};
  --ctp-accent: var(--ctp-mauve);
  --yt-spec-commerce-filled-hover: var(--ctp-accent) !important;
  --yt-spec-menu-background: var(--ctp-base) !important;
  --disabled-text-color: var(--ctp-surface0) !important;
  --ytmusic-scrollbar-width: 0px !important;
  --ytd-scrollbar-width: 0px !important;
}

* { scrollbar-width: none !important; }

/* In-app menu titlebar (Plugins/Options/View...) */
:root {
  --titlebar-background-color: var(--ctp-mantle) !important;
  --menu-bar-height: 32px !important;
}

#ytmd-title-bar-main-panel {
  background: var(--ctp-mantle) !important;
  border-bottom: 1px solid var(--ctp-surface0) !important;
  color: var(--ctp-text) !important;
}

#ytmd-title-bar-main-panel li,
#ytmd-title-bar-main-panel button {
  color: var(--ctp-text) !important;
}

#ytmd-title-bar-main-panel li:hover,
#ytmd-title-bar-main-panel button:hover {
  background-color: var(--ctp-surface0) !important;
}

#ytmd-title-bar-main-panel [data-selected='true'] {
  background-color: var(--ctp-surface1) !important;
}

#ytmd-title-bar-main-panel > div:last-child > *:last-child:hover {
  background: rgba(255, 0, 0, 0.45) !important;
}

#ytmd-title-bar-main-panel svg {
  color: var(--ctp-text) !important;
  fill: currentColor !important;
}

i.material-icons { color: var(--ctp-text) !important; }
i.material-icons:hover { color: var(--ctp-text) !important; }

body { background: var(--ctp-base) !important; }

ytmusic-nav-bar { background: var(--ctp-mantle) !important; }

/* Hide YouTube Music logo, keep hamburger */
ytmusic-nav-bar ytmusic-logo,
ytmusic-nav-bar .ytmusic-logo {
  display: none !important;
}

ytmusic-nav-bar .left-content.style-scope.ytmusic-nav-bar {
  width: auto !important;
  min-width: 56px !important;
  padding-left: 12px !important;
}

ytmusic-pivot-bar-item-renderer:hover,
ytmusic-pivot-bar-item-renderer.iron-selected { color: var(--ctp-accent) !important; }
ytmusic-pivot-bar-item-renderer { color: var(--ctp-text) !important; }

ytmusic-search-box { color: var(--ctp-text) !important; }
a.ytmusic-content-update-chip { color: var(--ctp-base) !important; background-color: var(--ytmusic-color-grey2) !important; }

ytmusic-detail-header-renderer { background-color: var(--ctp-base) !important; }
.title.ytmusic-detail-header-renderer { color: var(--ctp-text) !important; }
ytmusic-player-page { background-color: var(--ctp-base) !important; }
ytmusic-data-bound-header-renderer { background-color: var(--ctp-mantle) !important; }
ytmusic-list-item-renderer { background-color: var(--ctp-base) !important; }
ytmusic-responsive-list-item-renderer { background-color: var(--ctp-base) !important; }
ytmusic-player-queue-item { background-color: var(--ctp-base) !important; }

paper-tab.iron-selected.ytmusic-player-page { color: var(--ctp-text) !important; }
tp-yt-paper-tab.iron-selected.ytmusic-player-page { color: var(--ctp-text) !important; }
tp-yt-paper-tab.ytmusic-player-page { color: var(--ctp-text) !important; }
paper-tabs.ytmusic-player-page { --paper-tabs-selection-bar-color: var(--ctp-text) !important; }
#selectionBar.tp-yt-paper-tabs { border-bottom: 2px solid var(--ctp-text) !important; }

yt-formatted-string.byline.style-scope.ytmusic-player-queue-item { color: var(--ctp-accent) !important; }
yt-formatted-string.duration.style-scope.ytmusic-player-queue-item { color: var(--ctp-text) !important; }

ytmusic-player-bar { background: var(--ctp-mantle) !important; }
ytmusic-mealbar-promo-renderer { background: var(--ctp-base) !important; }
.messages.ytmusic-mealbar-promo-renderer { color: var(--ctp-subtext0) !important; }

#progress-bar.ytmusic-player-bar { --paper-slider-active-color: var(--ctp-accent) !important; }
#progress-bar.ytmusic-player-bar[focused],
ytmusic-player-bar:hover #progress-bar.ytmusic-player-bar {
  --paper-slider-knob-color: var(--ctp-accent) !important;
  --paper-slider-knob-start-color: var(--ctp-accent) !important;
  --paper-slider-knob-start-border-color: var(--ctp-accent) !important;
}

paper-slider#volume-slider {
  --paper-slider-container-color: var(--ctp-text) !important;
  --paper-slider-active-color: var(--ctp-text) !important;
  --paper-slider-knob-color: var(--ctp-text) !important;
}
.volume-slider.ytmusic-player-bar,
.expand-volume-slider.ytmusic-player-bar {
  --paper-slider-container-color: var(--ctp-text) !important;
  --paper-slider-active-color: var(--ctp-text) !important;
  --paper-slider-knob-color: var(--ctp-text) !important;
}

paper-icon-button#play-pause-button { --iron-icon-fill-color: var(--ctp-text) !important; }
tp-yt-iron-icon#icon { --iron-icon-fill-color: var(--ctp-accent) !important; }

.left-controls.ytmusic-player-bar paper-icon-button.ytmusic-player-bar,
.left-controls.ytmusic-player-bar .spinner-container.ytmusic-player-bar,
.toggle-player-page-button.ytmusic-player-bar { --iron-icon-fill-color: var(--ctp-text) !important; }
.menu.ytmusic-player-bar { --iron-icon-fill-color: var(--ctp-text) !important; }

.right-controls-buttons.ytmusic-player-bar paper-icon-button.ytmusic-player-bar,
ytmusic-player-expanding-menu.ytmusic-player-bar paper-icon-button.ytmusic-player-bar {
  --paper-icon-button_-_color: var(--ctp-text) !important;
}

.title.ytmusic-carousel-shelf-basic-header-renderer,
.title.ytmusic-immersive-header-renderer,
.description.ytmusic-immersive-header-renderer { color: var(--ctp-text) !important; }

div.content-wrapper.style-scope.ytmusic-play-button-renderer { background: var(--ctp-text) !important; }
ytmusic-subscribe-button-renderer { --ytmusic-subscribe-button-color: var(--ctp-red) !important; }
yt-button-renderer[is-paper-button] { background-color: var(--ctp-accent) !important; }
paper-icon-button { --paper-icon-button_-_color: var(--ctp-text) !important; }

ytmusic-data-bound-top-level-menu-item.ytmusic-data-bound-menu-renderer:not(:first-child) {
  --yt-button-color: var(--ctp-text) !important;
  border: 1px solid var(--ctp-text) !important;
  border-radius: 5px !important;
}

#top-level-buttons.ytmusic-menu-renderer > .outline-button.ytmusic-menu-renderer,
.edit-playlist-button.ytmusic-menu-renderer,
ytmusic-toggle-button-renderer.ytmusic-menu-renderer {
  --yt-button-color: var(--ctp-base) !important;
  border: 0px solid var(--ctp-base) !important;
}

yt-icon.ytmusic-inline-badge-renderer { color: var(--ctp-text) !important; }
.title.ytmusic-header-renderer { color: var(--ctp-text) !important; }

yt-formatted-string.strapline.text.style-scope.ytmusic-carousel-shelf-basic-header-renderer { color: var(--ctp-text) !important; }
yt-formatted-string[has-link-only_]:not([force-default-style]) a.yt-simple-endpoint.yt-formatted-string { color: var(--ctp-text) !important; }
yt-formatted-string[has-link-only_]:not([force-default-style]) a.yt-simple-endpoint.yt-formatted-string:hover { color: var(--ctp-text) !important; }

.previous-items-button.ytmusic-carousel,
.next-items-button.ytmusic-carousel {
  background-color: var(--ctp-accent) !important;
  color: var(--ctp-base) !important;
}

.content-wrapper.ytmusic-play-button-renderer,
ytmusic-play-button-renderer:hover .content-wrapper.ytmusic-play-button-renderer,
ytmusic-play-button-renderer:focus .content-wrapper.ytmusic-play-button-renderer {
  background: var(--ctp-accent) !important;
  --ytmusic-play-button-icon-color: var(--ctp-base) !important;
  --paper-spinner-color: var(--yt-spec-themed-blue) !important;
}

yt-icon.icon.style-scope.ytmusic-play-button-renderer { fill: var(--ctp-base) !important; }
.watch-button .yt-spec-button-shape-next__icon > yt-icon { fill: var(--ctp-base) !important; }
.play-button .yt-spec-button-shape-next__icon > yt-icon { fill: var(--ctp-base) !important; }
.radio-button .yt-spec-button-shape-next__icon > yt-icon { fill: var(--ctp-base) !important; }

ytmusic-tabs.stuck { background-color: var(--ctp-mantle) !important; }
paper-icon-button.ytmusic-like-button-renderer { color: var(--ctp-text) !important; }
.dropdown-content { background-color: var(--ctp-base) !important; }

yt-formatted-string.title.style-scope.ytmusic-two-row-item-renderer { color: var(--ctp-text) !important; }
yt-formatted-string.song-title.style-scope.ytmusic-player-queue-item { color: var(--ctp-text) !important; }
yt-formatted-string.title.style-scope.ytmusic-player-bar { color: var(--ctp-text) !important; }
span.time-info.style-scope.ytmusic-player-bar { color: var(--ctp-text) !important; }
yt-formatted-string#description.description.style-scope.ytmusic-detail-header-renderer { color: var(--ctp-text) !important; }

yt-formatted-string#text.style-scope.yt-button-renderer.style-default { color: var(--ctp-base) !important; }
yt-formatted-string#text.style-scope.yt-button-renderer.style-text { color: var(--ctp-base) !important; }

tp-yt-iron-icon#icon.style-scope.tp-yt-paper-icon-button { color: var(--ctp-accent) !important; }

div.style-scope.ytmusic-pivot-bar-renderer.navigation-item {
  --yt-endpoint-color: var(--ctp-accent) !important;
  --yt-endpoint-hover-color: var(--ctp-accent) !important;
  --yt-endpoint-visited-color: var(--ctp-accent) !important;
}

a.yt-simple-endpoint.style-scope.ytmusic-chip-cloud-chip-renderer {
  color: var(--ctp-text) !important;
  background-color: var(--ctp-mantle) !important;
}

div.label.style-scope.ytmusic-nerd-stats { color: var(--ctp-text) !important; }
ytmusic-nerd-stats.style-scope.ytmusic-player-bar {
  color: var(--ctp-text) !important;
  background-color: var(--ctp-base) !important;
}

div.song-media-controls.style-scope.ytmusic-player { color: var(--ctp-text) !important; }
div#header.style-scope.ytmusic-item-section-renderer { background-color: var(--ctp-base) !important; }
a.yt-simple-endpoint.style-scope.yt-formatted-string { color: var(--ctp-text) !important; }

yt-formatted-string.fixed-column.MUSIC_RESPONSIVE_LIST_ITEM_COLUMN_DISPLAY_PRIORITY_HIGH.style-scope.ytmusic-responsive-list-item-renderer { color: var(--ctp-accent) !important; }

yt-formatted-string.subtitle.style-scope.ytmusic-detail-header-renderer { color: var(--ctp-text) !important; }
yt-formatted-string.second-subtitle.style-scope.ytmusic-detail-header-renderer { color: var(--ctp-text) !important; }

ytmusic-like-button-renderer.style-scope.ytmusic-menu-renderer { color: var(--ctp-accent) !important; }
tp-yt-paper-icon-button.ytmusic-like-button-renderer { color: var(--ctp-accent) !important; }

yt-icon.icon.style-scope.ytmusic-menu-service-item-renderer {
  color: var(--ctp-accent) !important;
  fill: var(--ctp-accent) !important;
}

ytmusic-menu-navigation-item-renderer,
ytmusic-toggle-menu-service-item-renderer {
  --iron-icon-fill-color: var(--ctp-accent) !important;
  --icon-color: var(--ctp-accent) !important;
}

div#navigation-endpoint.yt-simple-endpoint.style-scope.ytmusic-menu-navigation-item-renderer,
div.text.ytmusic-menu-navigation-item-renderer { color: var(--ctp-text) !important; }

tp-yt-paper-listbox#items.style-scope.ytmusic-menu-popup-renderer {
  color: var(--ctp-mantle) !important;
  background-color: var(--ctp-mantle) !important;
  border: 1px solid var(--ctp-surface0) !important;
}

yt-formatted-string.text.style-scope.ytmusic-menu-service-item-renderer { color: var(--ctp-text) !important; }
yt-formatted-string.text.style-scope.ytmusic-menu-navigation-item-renderer { color: var(--ctp-text) !important; }
div#ytmcustom-pip.text.style-scope.ytmusic-menu-navigation-item-renderer { color: var(--ctp-text) !important; }
div#ytmcustom-download.text.style-scope.ytmusic-menu-navigation-item-renderer { color: var(--ctp-text) !important; }
span.style-scope.yt-formatted-string { color: var(--ctp-text) !important; }

div.icon.menu-icon.style-scope.ytmusic-menu-navigation-item-renderer {
  fill: var(--ctp-accent) !important;
  stroke: var(--ctp-accent) !important;
}

h2.form-title.style-scope.ytmusic-playlist-form { color: var(--ctp-text) !important; }
tp-yt-paper-tab.style-scope.ytmusic-playlist-form.iron-selected { color: var(--ctp-accent) !important; }
div.tab-content.style-scope.tp-yt-paper-tab { color: var(--ctp-text) !important; }

div.content.style-scope.ytmusic-playlist-form {
  caret-color: var(--ctp-accent) !important;
  background-color: var(--ctp-base) !important;
  color: var(--ctp-base) !important;
}

div#player-bar-background.style-scope.ytmusic-app-layout { background-color: var(--ctp-base) !important; }
yt-formatted-string.subtitle.style-scope.ytmusic-two-row-item-renderer { color: var(--ctp-text) !important; }

button.style-scope.ytmusic-navigation-button-renderer {
  background: var(--ctp-mantle) !important;
  color: var(--ctp-text) !important;
}

ytmusic-navigation-button-renderer.style-scope.ytmusic-carousel {
  --ytmusic-navigation-button-left-stripe-color: var(--ctp-accent) !important;
}

yt-icon.ytmusic-navigation-button-renderer { color: var(--ctp-accent) !important; }
yt-icon.style-scope.ytmusic-icon-link-renderer { fill: var(--ctp-accent) !important; }
tp-yt-iron-icon.chromecast.style-scope.ytmusic-cast-button { fill: var(--ctp-accent) !important; }

tp-yt-paper-toast {
  background: var(--ctp-mantle) !important;
  color: var(--ctp-text) !important;
}

.description.ytmusic-description-shelf-renderer,
.synced-lyrics-vlist { color: var(--ctp-text) !important; }

.lyrics-picker-dot { border: 1px solid var(--ctp-surface0) !important; }
.lyrics-picker-item > yt-icon {
  --icon-color: var(--ctp-accent) !important;
  --iron-icon-fill-color: var(--ctp-accent) !important;
  --iron-icon-stroke-color: var(--ctp-accent) !important;
}

ytd-multi-page-menu-renderer.style-scope.ytmusic-popup-container {
  color: var(--ctp-text) !important;
  background-color: var(--ctp-base) !important;
}

ytd-active-account-header-renderer.style-scope.ytd-multi-page-menu-renderer {
  color: var(--ctp-text) !important;
  background-color: var(--ctp-base) !important;
}

yt-formatted-string#account-name.style-scope.ytd-active-account-header-renderer { color: var(--ctp-text) !important; }
yt-formatted-string#channel-handle.style-scope.ytd-active-account-header-renderer { color: var(--ctp-accent) !important; }
yt-icon.ytd-compact-link-renderer { color: var(--ctp-accent) !important; }

yt-formatted-string.style-scope.ytmusic-shelf-renderer { color: var(--ctp-text) !important; }
yt-formatted-string.style-scope.ytmusic-menu-service-item-download-renderer { color: var(--ctp-text) !important; }
yt-formatted-string.strapline.style-scope.ytmusic-shelf-renderer { color: var(--ctp-text) !important; }

ytmusic-search-box[has-query] input.ytmusic-search-box { color: var(--ctp-text) !important; }
ytmusic-search-box[opened] input.ytmusic-search-box { color: var(--ctp-text) !important; }

div.background-gradient.style-scope.ytmusic-browse-response {
  background-image: linear-gradient(to bottom, var(--ctp-base), var(--ctp-base)) !important;
}

ytmusic-search-suggestion {
  color: var(--ctp-text) !important;
  background: var(--ctp-mantle) !important;
  --iron-icon-fill-color: var(--ctp-accent) !important;
}

ytmusic-background-promo-renderer[renderer-style="full-height"] { background: none !important; }
ytmusic-background-promo-renderer[renderer-style="full-height"] .promo-title.ytmusic-background-promo-renderer:not([hidden]) { color: var(--ctp-text) !important; }

ytmusic-search-box[is-bauhaus-sidenav-enabled] #suggestion-list.ytmusic-search-box { background: var(--ctp-mantle) !important; }
a.yt-simple-endpoint.style-scope.ytmusic-responsive-list-item-renderer { color: var(--ctp-text) !important; }
ytmusic-search-suggestions-section.style-scope.ytmusic-search-box { background: var(--ctp-mantle) !important; }
div.search-box.style-scope.ytmusic-search-box { background: var(--ctp-mantle) !important; }

yt-page-navigation-progress.style-scope.ytmusic-app {
  --yt-page-navigation-container-color: var(--ctp-base) !important;
  --yt-page-navigation-progress-color: var(--ctp-accent) !important;
}

tp-yt-paper-progress#sliderBar.style-scope.tp-yt-paper-slider { color: var(--ctp-mantle) !important; }

tp-yt-paper-slider#progress-bar.style-scope.ytmusic-player-bar {
  --paper-slider-secondary-color: var(--ctp-crust) !important;
  --paper-slider-container-color: var(--ctp-mantle) !important;
}

ytmusic-player-expanding-menu#expanding-menu.style-scope.ytmusic-player-bar { background-color: var(--ctp-mantle) !important; }

yt-icon.icon.style-scope.ytmusic-menu-navigation-item-renderer { fill: var(--ctp-accent) !important; }
yt-formatted-string.text.style-scope.ytmusic-toggle-menu-service-item-renderer { color: var(--ctp-text) !important; }
yt-icon.icon.style-scope.ytmusic-toggle-menu-service-item-renderer { fill: var(--ctp-accent) !important; }
yt-icon.ytmusic-menu-service-item-download-renderer { fill: var(--ctp-accent) !important; }
yt-formatted-string#label.style-scope.ytd-compact-link-renderer { color: var(--ctp-text) !important; }

ytmusic-upload-ineligible.style-scope.ytmusic-dialog { background-color: var(--ctp-base) !important; }
div.title.style-scope.ytmusic-upload-ineligible { color: var(--ctp-text) !important; }
div.message.style-scope.ytmusic-upload-ineligible { color: var(--ctp-text) !important; }
a.style-scope.ytmusic-upload-ineligible { color: var(--ctp-accent) !important; }
tp-yt-paper-button.switch-accounts.style-scope.ytmusic-upload-ineligible { color: var(--ctp-text) !important; }
tp-yt-paper-button.dismiss.style-scope.ytmusic-upload-ineligible { color: var(--ctp-text) !important; }

ytmusic-settings-page.style-scope.ytmusic-dialog {
  background-color: var(--ctp-base) !important;
  color: var(--ctp-text) !important;
}

ytmusic-settings-category-collection-renderer.style-scope.ytmusic-settings-page {
  border: 1px var(--ctp-accent) solid !important;
}

yt-formatted-string.title.style-scope.ytmusic-settings-page { color: var(--ctp-text) !important; }
span.dialog-title.style-scope.ytmusic-settings-page { color: var(--ctp-text) !important; }
yt-icon.icon.style-scope.ytmusic-settings-page { color: var(--ctp-accent) !important; }

yt-formatted-string.summary.style-scope.ytmusic-setting-read-only-item-renderer { color: var(--ctp-text) !important; }
yt-formatted-string.title.style-scope.ytmusic-setting-read-only-item-renderer { color: var(--ctp-text) !important; }
yt-formatted-string.summary.style-scope.ytmusic-setting-boolean-renderer { color: var(--ctp-text) !important; }
yt-formatted-string.title.style-scope.ytmusic-setting-boolean-renderer { color: var(--ctp-text) !important; }

tp-yt-paper-item.category-menu-item.style-scope.ytmusic-settings-page.iron-selected { background-color: var(--ctp-crust) !important; }

yt-formatted-string.tab.style-scope.ytmusic-item-section-tab-renderer { color: var(--ctp-text) !important; }
ytmusic-item-section-tab-renderer.iron-selected .tab.ytmusic-item-section-tab-renderer {
  color: var(--ctp-text) !important;
  border-bottom: 2px solid var(--ctp-text) !important;
}

ytmusic-item-section-tabs-container.style-scope.ytmusic-item-section-tabbed-header-renderer { color: var(--ctp-text) !important; }
div#end-items.style-scope.ytmusic-item-section-tabbed-header-renderer { border-top: 1px solid var(--ctp-base) !important; }

ytmusic-dropdown-item-renderer.style-scope.ytmusic-dropdown-renderer {
  background-color: var(--ctp-base) !important;
  color: var(--ctp-text) !important;
}

ytmusic-dropdown-item-renderer.style-scope.ytmusic-dropdown-renderer.iron-selected {
  background-color: var(--ctp-mantle) !important;
  color: var(--ctp-text) !important;
}

yt-formatted-string.label.style-scope.ytmusic-dropdown-item-renderer { color: var(--ctp-text) !important; }

ytmusic-dropdown-renderer.style-scope.ytmusic-item-section-tabbed-header-renderer {
  color: var(--ctp-text) !important;
  background-color: var(--ctp-base) !important;
  border: 1px solid var(--ctp-accent) !important;
}

input.style-scope.tp-yt-paper-input { color: var(--ctp-text) !important; }
yt-formatted-string.flex-column.style-scope.ytmusic-responsive-list-item-renderer { color: var(--ctp-text) !important; }
yt-formatted-string.title.style-scope.ytmusic-responsive-list-item-renderer { color: var(--ctp-text) !important; }

yt-icon.tab-icon.style-scope.ytmusic-message-renderer { color: var(--ctp-text) !important; }
yt-formatted-string.text.style-scope.ytmusic-message-renderer { color: var(--ctp-text) !important; }
yt-formatted-string.subtext.style-scope.ytmusic-message-renderer { color: var(--ctp-text) !important; }

div#header.style-scope.ytmusic-item-section-renderer {
  border-bottom: 1px solid var(--ctp-base) !important;
  box-shadow: none !important;
}

ytmusic-background-overlay-renderer#background.style-scope.ytmusic-item-thumbnail-overlay-renderer {
  --ytmusic-background-overlay-background: linear-gradient(var(--ctp-base), transparent) !important;
}

div.search-box.style-scope.ytmusic-search-box,
.search-box.ytmusic-search-box,
ytmusic-search-box[is-bauhaus-sidenav-enabled] .search-box.ytmusic-search-box {
  border: 1px solid var(--ctp-surface0) !important;
  border-radius: 999px !important;
  background: var(--ctp-base) !important;
  box-shadow: none !important;
}

ytmusic-search-box[opened][is-mobile-view] {
  left: 50% !important;
  transform: translateX(-50%) !important;
  margin-left: 0 !important;
  margin-right: 0 !important;
  width: min(680px, calc(100vw - 32px)) !important;
  max-width: min(680px, calc(100vw - 32px)) !important;
}

ytmusic-search-box[opened] .search-box.ytmusic-search-box {
  border-radius: 16px 16px 0 0 !important;
}

#suggestion-list.ytmusic-search-box {
  background: var(--ctp-base) !important;
  border: 1px solid var(--ctp-surface0) !important;
  border-top: none !important;
  border-radius: 0 0 16px 16px !important;
  box-shadow: 0 10px 24px rgba(0, 0, 0, 0.28) !important;
  overflow: hidden !important;
}

ytmusic-search-suggestions-section.style-scope.ytmusic-search-box {
  background: transparent !important;
}

ytmusic-tabs#tabs.style-scope.ytmusic-tabbed-search-results-renderer.stuck {
  background-color: var(--ctp-base) !important;
  box-shadow: none !important;
}

div#tabs.tab-container.style-scope.ytmusic-tabs { border-bottom: none !important; }

yt-formatted-string.tab.selected.style-scope.ytmusic-tabs {
  color: var(--ctp-text) !important;
  border-bottom: 2px solid var(--ctp-text) !important;
}

yt-formatted-string.tab.style-scope.ytmusic-tabs { color: var(--ctp-text) !important; }
span.italic.style-scope.yt-formatted-string { color: var(--ctp-accent) !important; }
yt-formatted-string#corrected.style-scope.yt-search-query-correction { color: var(--ctp-text) !important; }

ytmusic-chip-cloud-chip-renderer[enable-bauhaus-style][chip-style=STYLE_LARGE_TRANSLUCENT_AND_SELECTED_WHITE][is-selected]:not(.iron-selected) a.ytmusic-chip-cloud-chip-renderer {
  border: 1px solid var(--ctp-accent) !important;
}

yt-formatted-string.title.style-scope.ytmusic-visual-header-renderer { color: var(--ctp-text) !important; }
yt-formatted-string#text.style-scope.yt-button-renderer.style-dark-on-white { color: var(--ctp-base) !important; }
div.gradient-container.style-scope.ytmusic-visual-header-renderer { background: var(--ctp-base) !important; }

tp-yt-paper-icon-button#next-items-button.next-items-button.style-scope.ytmusic-carousel-shelf-renderer { border: solid 1px var(--ctp-accent) !important; }
tp-yt-paper-icon-button#previous-items-button.previous-items-button.style-scope.ytmusic-carousel-shelf-renderer { border: solid 1px var(--ctp-accent) !important; }

tp-yt-paper-toggle-button[checked]:not([disabled]) .toggle-bar.tp-yt-paper-toggle-button { background-color: var(--ctp-accent) !important; }
tp-yt-paper-toggle-button[checked]:not([disabled]) .toggle-button.tp-yt-paper-toggle-button { background-color: var(--ctp-accent) !important; }
.toggle-bar.tp-yt-paper-toggle-button { background-color: var(--ctp-text) !important; }
.toggle-button.tp-yt-paper-toggle-button { background-color: var(--ctp-text) !important; }

.items.ytmusic-setting-category-collection-renderer>*.ytmusic-setting-category-collection-renderer { border-bottom: none !important; }
.top-bar.ytmusic-settings-page { border-bottom: none; }

div.style-scope.ytmusic-setting-single-option-menu-renderer { color: var(--ctp-text) !important; }
span.style-scope.ytmusic-setting-single-option-menu-renderer { color: var(--ctp-text) !important; }

div.unfocused-line.style-scope.tp-yt-paper-input-container { background-color: var(--ctp-text) !important; }
.focused-line.tp-yt-paper-input-container { border-color: var(--ctp-accent) !important; }
tp-yt-iron-icon.style-scope.tp-yt-paper-dropdown-menu { color: var(--ctp-text) !important; }

ytd-multi-page-menu-renderer.style-scope.ytd-multi-page-menu-renderer { background: var(--ctp-base) !important; }
ytd-simple-menu-header-renderer.style-scope.ytd-multi-page-menu-renderer { background-color: var(--ctp-base) !important; }
yt-icon.style-scope.ytd-button-renderer { fill: var(--ctp-text) !important; }
yt-formatted-string.style-scope.ytd-simple-menu-header-renderer { color: var(--ctp-text) !important; }
yt-formatted-string#email.style-scope.ytd-google-account-header-renderer { color: var(--ctp-text) !important; }
yt-formatted-string#name.style-scope.ytd-google-account-header-renderer { color: var(--ctp-text) !important; }
yt-formatted-string.style-scope.ytd-account-item-renderer { color: var(--ctp-text) !important; }
yt-formatted-string.style-scope.ytd-account-item-section-header-renderer { color: var(--ctp-text) !important; }
ytd-account-item-renderer[enable-ring-for-active-account] yt-img-shadow.ytd-account-item-renderer { border: 2px solid var(--ctp-accent) !important; }

ytmusic-player[player-ui-state_=MINIPLAYER] .song-media-controls.ytmusic-player {
  background: linear-gradient(var(--ctp-base) 20%, transparent 100%) !important;
}

#thumbnail-corner-overlay.ytmusic-two-row-item-renderer>ytmusic-thumbnail-renderer.ytmusic-two-row-item-renderer {
  color: var(--ctp-text) !important;
  border: 1px solid var(--ctp-text) !important;
}

.container.ytmusic-custom-index-column-renderer { color: var(--ctp-text) !important; }
ytmusic-custom-index-column-renderer[icon-color-style=CUSTOM_INDEX_COLUMN_ICON_COLOR_STYLE_GREY] .icon.ytmusic-custom-index-column-renderer { color: var(--ctp-text) !important; }
ytmusic-custom-index-column-renderer[icon-color-style=CUSTOM_INDEX_COLUMN_ICON_COLOR_STYLE_GREEN] .icon.ytmusic-custom-index-column-renderer { color: var(--ctp-green) !important; }
ytmusic-custom-index-column-renderer[icon-color-style=CUSTOM_INDEX_COLUMN_ICON_COLOR_STYLE_RED] .icon.ytmusic-custom-index-column-renderer { color: var(--ctp-red) !important; }

button#button.style-scope.ytmusic-sort-filter-button-renderer {
  color: var(--ctp-text) !important;
  background-color: var(--ctp-base) !important;
  border: 1px solid var(--ctp-accent) !important;
}

#container.ytmusic-multi-select-menu-renderer {
  border: 1px solid var(--ctp-accent) !important;
  background: var(--ctp-base) !important;
}

#items.ytmusic-multi-select-menu-renderer { background: var(--ctp-base) !important; }
yt-formatted-string.text.style-scope.ytmusic-menu-title-renderer { color: var(--ctp-text) !important; }
yt-formatted-string.text.style-scope.ytmusic-multi-select-menu-item-renderer { color: var(--ctp-text) !important; }
.title.ytmusic-setting-action-renderer { color: var(--ctp-text) !important; }
.summary.ytmusic-setting-action-renderer { color: var(--ctp-text) !important; }

yt-formatted-string.primary-text.style-scope.ytmusic-tastebuilder-renderer { color: var(--ctp-text) !important; }
yt-formatted-string.secondary-text.style-scope.ytmusic-tastebuilder-renderer { color: var(--ctp-text) !important; }
yt-formatted-string.primary-text.style-scope.ytmusic-tastebuilder-item-renderer { color: var(--ctp-text) !important; }

div.overlay-effect.style-scope.ytmusic-tastebuilder-item-renderer {
  background: linear-gradient(var(--ctp-base) 0%, transparent 100%) !important;
  color: var(--ctp-base) !important;
}

yt-icon.ytmusic-tastebuilder-item-renderer { color: var(--ctp-text) !important; }
yt-button-renderer #button.yt-button-renderer { color: var(--ctp-base) !important; }
.buttons.ytmusic-tastebuilder-renderer { background: var(--ctp-mantle) !important; }

input.ytmusic-search-box,
#placeholder.ytmusic-search-box { color: var(--ctp-text) !important; }

ytmusic-toggle-button-renderer #button.ytmusic-toggle-button-renderer { color: var(--ctp-text) !important; }
ytmusic-responsive-list-item-renderer[show-checkbox] yt-checkbox-renderer.ytmusic-responsive-list-item-renderer { --yt-spec-text-primary: var(--ctp-accent) !important; }

yt-formatted-string.non-expandable.description.style-scope.ytmusic-description-shelf-renderer { color: var(--ctp-text) !important; }
yt-formatted-string.footer.style-scope.ytmusic-description-shelf-renderer { color: var(--ctp-text) !important; }
tp-yt-paper-icon-button.ytmusic-settings-button { background-color: var(--ctp-text) !important; }
yt-img-shadow#avatar.style-scope.ytd-active-account-header-renderer.no-transition { background-color: var(--ctp-text) !important; }

yt-multi-page-menu-section-renderer.style-scope.ytd-multi-page-menu-renderer { border-bottom: none !important; }
ytd-active-account-header-renderer.style-scope.ytd-multi-page-menu-renderer { border-bottom: none !important; }
ytd-multi-page-menu-renderer.style-scope.ytmusic-popup-container { border: 1px solid var(--ctp-surface0) !important; }
ytd-multi-page-menu-renderer { border-radius: 5px !important; }
ytmusic-setting-category-collection-renderer.style-scope.ytmusic-settings-page { border-left: none !important; }
tp-yt-paper-tabs.tab-header-container.style-scope.ytmusic-player-page { border-bottom: none !important; }
ytmusic-item-thumbnail-overlay-renderer.thumbnail-overlay.style-scope.ytmusic-two-row-item-renderer { background: transparent !important; }
yt-formatted-string.header.style-scope.ytmusic-description-shelf-renderer { color: var(--ctp-text) !important; }
yt-formatted-string.description.style-scope.ytmusic-description-shelf-renderer { color: var(--ctp-text) !important; }

ytmusic-app-layout {
  --ytmusic-fullscreen-player-overlay-gradient: linear-gradient(transparent 0%, transparent 75%, var(--ctp-base) 100%) !important;
}

div.song-media-controls.style-scope.ytmusic-player {
  background: linear-gradient(var(--ctp-base) 0%, transparent 50%) !important;
}

ytmusic-player-queue-item.style-scope.ytmusic-player-queue { border-bottom: none !important; }
yt-multi-page-menu-section-renderer.style-scope.ytd-multi-page-menu-renderer { border-top: none !important; }
div#container.style-scope.ytd-google-account-header-renderer { border-bottom: none !important; }
ytd-account-section-list-renderer.style-scope.ytd-multi-page-menu-renderer { border-top: none !important; }
ytmusic-responsive-list-item-renderer.style-scope.ytmusic-shelf-renderer { border-bottom: none !important; }
ytmusic-responsive-list-item-renderer.style-scope.ytmusic-playlist-shelf-renderer { border-bottom: none !important; }
yt-formatted-string.style-scope.ytmusic-grid-header-renderer { color: var(--ctp-text) !important; }

ytmusic-navigation-button-renderer[button-style=STYLE_SOLID] button.ytmusic-navigation-button-renderer {
  border-left: 6px solid var(--ctp-accent) !important;
}

yt-confirm-dialog-renderer.style-scope.ytmusic-popup-container { background: var(--ctp-mantle) !important; }
.buttons.yt-confirm-dialog-renderer { border-top: none !important; }
yt-formatted-string#title.style-scope.yt-confirm-dialog-renderer { color: var(--ctp-text) !important; }
yt-formatted-string.line-text.style-scope.yt-confirm-dialog-renderer { color: var(--ctp-text) !important; }

div.value.style-scope.ytmusic-nerd-stats { color: var(--ctp-text) !important; }
ytmusic-nerd-stats.style-scope.ytmusic-player { background-color: var(--ctp-base) !important; }
tp-yt-iron-overlay-backdrop.opened { color: var(--ctp-crust) !important; background: var(--ctp-crust) !important; }

iron-label#iron-label-1.title.style-scope.ytmusic-tab-renderer { color: var(--ctp-text) !important; }
div.subtitle.style-scope.ytmusic-tab-renderer { color: var(--ctp-text) !important; }
div.gradient-container.style-scope.ytmusic-immersive-header-renderer { background: linear-gradient(360deg, var(--ctp-base) 9.89%, transparent 100%) !important; }

yt-unlimited-page-header-renderer.style-scope.ytmusic-item-section-renderer { background: var(--ctp-base) !important; }
yt-formatted-string#header.style-scope.yt-music-pass-feature-info-renderer { color: var(--ctp-text) !important; }
yt-formatted-string#description.style-scope.yt-music-pass-feature-info-renderer { color: var(--ctp-text) !important; }
yt-formatted-string#header.style-scope.yt-music-pass-small-feature-info-renderer { color: var(--ctp-text) !important; }
yt-formatted-string#description.style-scope.yt-music-pass-small-feature-info-renderer { color: var(--ctp-text) !important; }
yt-formatted-string#subtitle.style-scope.yt-unlimited-page-header-renderer { color: var(--ctp-text) !important; }

ytmusic-multi-select-menu-bar.style-scope.ytmusic-dialog { background-color: var(--ctp-mantle) !important; }
ytmusic-dialog { background-color: var(--ctp-surface0) !important; border: 1px var(--ctp-surface0) solid !important; border-radius: 2px !important; }
yt-formatted-string.style-scope.ytmusic-multi-select-menu-bar { color: var(--ctp-text) !important; }
yt-checkbox-renderer.fixed-column.MUSIC_RESPONSIVE_LIST_ITEM_COLUMN_DISPLAY_PRIORITY_HIGH.style-scope.ytmusic-responsive-list-item-renderer { color: var(--ctp-accent) !important; }

.yt-icon { fill: var(--ctp-accent) !important; --icon-color: var(--ctp-accent) !important; }
button.yt-icon-button > yt-icon { fill: var(--ctp-accent) !important; }

button.yt-icon-button {
  color: var(--ctp-text) !important;
  --iron-icon-theme-color: var(--ctp-text) !important;
  --icon-color: var(--ctp-text) !important;
  --iron-icon-fill-color: var(--ctp-text) !important;
  --iron-icon-stroke-color: var(--ctp-text) !important;
}

yt-icon-button.previous-items-button,
yt-icon-button.next-items-button { border-color: var(--ctp-accent) !important; }

yt-icon-button.previous-items-button > button.yt-icon-button[aria-label="Previous"],
yt-icon-button.next-items-button > button.yt-icon-button[aria-label="Next"] {
  color: var(--ctp-accent) !important;
  --iron-icon-theme-color: var(--ctp-accent) !important;
  --icon-color: var(--ctp-accent) !important;
  --iron-icon-fill-color: var(--ctp-accent) !important;
  --iron-icon-stroke-color: var(--ctp-accent) !important;
}

ytmusic-player-bar:not([repeat-mode=NONE]) .repeat.ytmusic-player-bar { color: var(--ctp-text) !important; }
ytmusic-player-bar.repeat.ytmusic-player-bar { color: var(--ctp-text) !important; }

ytmusic-app-layout #mini-guide-background.ytmusic-app-layout,
ytmusic-app-layout #nav-bar-background.ytmusic-app-layout,
ytmusic-app-layout #nav-bar-divider.ytmusic-app-layout {
  background-color: var(--ctp-crust) !important;
  border-color: var(--ctp-crust) !important;
}

ytmusic-unified-share-panel-renderer.style-scope.ytmusic-popup-container { background-color: var(--ctp-mantle) !important; }
tp-yt-paper-dialog.style-scope.ytmusic-popup-container { background-color: var(--ctp-mantle) !important; }
div#title.style-scope.yt-share-target-renderer { color: var(--ctp-text) !important; }
h2#title.style-scope.yt-share-panel-title-v15-renderer { color: var(--ctp-text) !important; }
input#share-url.style-scope.yt-copy-link-renderer { color: var(--ctp-text) !important; }
div#bar.style-scope.yt-copy-link-renderer { background-color: var(--ctp-crust) !important; border: 1px var(--ctp-accent) solid !important; }
.scroll-button.yt-third-party-share-target-section-renderer { background-color: var(--ctp-crust) !important; }

ytmusic-playlist-form.style-scope.ytmusic-dialog { background-color: var(--ctp-mantle) !important; }
ytmusic-playlist-form[tabbed-ui-enabled] iron-pages.ytmusic-playlist-form .content.ytmusic-playlist-form { border-top: none !important; border-bottom: none !important; }
tp-yt-paper-button.submit-button.style-scope.ytmusic-playlist-form { color: var(--ctp-mantle) !important; background-color: var(--ctp-accent) !important; }
tp-yt-paper-button.cancel-button.style-scope.ytmusic-playlist-form { color: var(--ctp-accent) !important; }
div#caption.style-scope.yt-toggle-form-field-renderer { color: var(--ctp-text) !important; }
.floated-label-placeholder.tp-yt-paper-input-container { color: var(--ctp-text) !important; }

ytmusic-dropdown-renderer[dropdown-style=underline] .icon.ytmusic-dropdown-renderer { color: var(--ctp-accent) !important; }
.icon.ytmusic-dropdown-item-renderer { color: var(--ctp-accent) !important; }
yt-formatted-string.description.style-scope.ytmusic-dropdown-item-renderer { color: var(--ctp-text) !important; }
yt-formatted-string.headline.style-scope.ytmusic-add-to-playlist-renderer { color: var(--ctp-text) !important; }
yt-formatted-string.section-heading.style-scope.ytmusic-add-to-playlist-renderer { color: var(--ctp-text) !important; }
yt-formatted-string#title.style-scope.ytmusic-playlist-add-to-option-renderer { color: var(--ctp-text) !important; }

ytmusic-add-to-playlist-renderer {
  background-color: var(--ctp-mantle) !important;
  border: 1px solid var(--ctp-accent) !important;
}

ytmusic-carousel-shelf-renderer.ytmusic-add-to-playlist-renderer:not(:empty) { border-bottom: none !important; }
.top-bar.ytmusic-add-to-playlist-renderer { border-bottom: none !important; }
yt-formatted-string.byline.style-scope.ytmusic-playlist-add-to-option-renderer { color: var(--ctp-text) !important; }

tp-yt-paper-toast#toast.style-scope.ytmusic-notification-text-renderer.paper-toast-open {
  background-color: var(--ctp-mantle) !important;
  color: var(--ctp-text) !important;
}

tp-yt-paper-toast#toast.toast-button.style-scope.yt-notification-action-renderer.paper-toast-open {
  background-color: var(--ctp-mantle) !important;
  color: var(--ctp-text) !important;
}

yt-formatted-string#text.style-scope.yt-notification-action-renderer { color: var(--ctp-text) !important; }
tp-yt-paper-toast#toast.toast-button.style-scope.yt-notification-action-renderer { background-color: var(--ctp-mantle) !important; color: var(--ctp-text) !important; }
tp-yt-paper-toast#toast.style-scope.ytmusic-notification-text-renderer { background-color: var(--ctp-mantle) !important; color: var(--ctp-text) !important; }

div.title.style-scope.ytmusic-player-queue { color: var(--ctp-text) !important; opacity: 1 !important; }
yt-icon.icon.style-scope.ytmusic-multi-select-menu-item-renderer { fill: var(--ctp-accent) !important; }
ytmusic-icon-badge-renderer.thumbnail.style-scope.ytmusic-responsive-list-item-renderer { background-color: var(--ctp-mantle) !important; color: var(--ctp-text) !important; }
#title.ytmusic-multi-select-menu-renderer { border-bottom: none !important; }
ytmusic-menu-item-divider-renderer.style-scope.ytmusic-multi-select-menu-renderer { border-bottom: none !important; }
yt-formatted-string.title.style-scope.ytmusic-setting-single-option-menu-renderer { color: var(--ctp-text) !important; }

.yt-spec-button-shape-next--mono.yt-spec-button-shape-next--text { color: var(--ctp-accent) !important; }
.yt-spec-button-shape-next--mono.yt-spec-button-shape-next--filled { color: var(--ctp-base) !important; background-color: var(--ctp-accent) !important; }
.yt-spec-touch-feedback-shape--touch-response .yt-spec-touch-feedback-shape__fill { background-color: var(--ctp-text) !important; }
.yt-spec-button-shape-next--mono.yt-spec-button-shape-next--outline { color: var(--ctp-accent) !important; border-color: var(--ctp-accent) !important; border-radius: 36px !important; }

ytmusic-av-toggle[playback-mode=OMV_PREFERRED] .video-button.ytmusic-av-toggle { background-color: var(--ctp-mantle) !important; }
ytmusic-av-toggle[playback-mode=ATV_PREFERRED] .song-button.ytmusic-av-toggle { background-color: var(--ctp-mantle) !important; }
ytmusic-av-toggle[toggle-disabled] .song-button.ytmusic-av-toggle { color: var(--ctp-accent) !important; background-color: var(--ctp-crust); }
ytmusic-av-toggle[toggle-disabled] .video-button.ytmusic-av-toggle { color: var(--ctp-accent) !important; background-color: var(--ctp-crust); }
.av-toggle.ytmusic-av-toggle { opacity: 1 !important; background-color: var(--ctp-crust) !important; }

.yt-spec-button-shape-next--call-to-action-inverse.yt-spec-button-shape-next--text { color: var(--ctp-accent) !important; }

ytmusic-guide-entry-renderer { color: var(--ctp-accent) !important; }
ytmusic-guide-entry-renderer[active] tp-yt-paper-item.ytmusic-guide-entry-renderer { background-color: var(--ctp-base) !important; }
ytmusic-app[is-bauhaus-sidenav-enabled] #guide-wrapper.ytmusic-app { background: var(--ctp-mantle) !important; border: none !important; }
#divider.ytmusic-guide-section-renderer { border: none !important; }
.title.ytmusic-guide-entry-renderer { color: var(--ctp-text) !important; }
.yt-spec-button-shape-next--mono.yt-spec-button-shape-next--tonal { color: var(--ctp-text) !important; background-color: var(--ctp-base) !important; }
ytmusic-guide-entry-renderer:not([is-primary]) .subtitle.ytmusic-guide-entry-renderer { color: var(--ctp-text) !important; }
/* Mini-guide / collapsed sidebar */
#mini-guide-renderer,
ytmusic-guide-renderer[is-collapsed] {
  background: var(--ctp-mantle) !important;
}

/* Panel connection curves */
ytmusic-app[is-bauhaus-sidenav-enabled] #guide-wrapper.ytmusic-app {
  border-top-right-radius: 18px !important;
  border-bottom-right-radius: 18px !important;
  overflow: hidden !important;
}
#mini-guide-background.ytmusic-app-layout {
  background: var(--ctp-mantle) !important;
  overflow: hidden !important;
}
/* Collapsed sidebar item shape: keep native sizing, no hug curves */
ytmusic-guide-entry-renderer[is-collapsed] tp-yt-paper-item.ytmusic-guide-entry-renderer {
  border-radius: 14px !important;
}
ytmusic-guide-entry-renderer[is-collapsed][active] tp-yt-paper-item.ytmusic-guide-entry-renderer {
  background-color: var(--ctp-base) !important;
}
ytmusic-guide-entry-renderer[is-collapsed]:not([active]) tp-yt-paper-item.ytmusic-guide-entry-renderer:hover,
ytmusic-guide-entry-renderer[is-collapsed]:not([active]) tp-yt-paper-item.ytmusic-guide-entry-renderer:focus-visible {
  background-color: color-mix(in srgb, var(--ctp-surface0) 72%, transparent) !important;
}
ytmusic-guide-entry-renderer[is-collapsed] .yt-spec-touch-feedback-shape__fill,
#mini-guide-renderer .yt-spec-touch-feedback-shape__fill {
  background-color: transparent !important;
}
#nav-bar-background.ytmusic-app-layout { border-bottom-left-radius: 18px !important; }
ytmusic-player-page { border-top-left-radius: 18px !important; overflow: hidden !important; }

yt-start-at-renderer.yt-third-party-network-section-renderer { padding-top: 0 !important; border-top: none !important; }
yt-formatted-string.yt-start-at-renderer { color: var(--ctp-text) !important; }
#checkbox.tp-yt-paper-checkbox { border-color: var(--ctp-text) !important; }
#checkbox.checked.tp-yt-paper-checkbox { background-color: var(--ctp-text) !important; }
.unfocused-line.tp-yt-paper-input-container { border-bottom: none !important; }

ytmusic-player-page[is-mweb-modernization-enabled][player-page-ui-state=TABS_VIEW] #side-panel.ytmusic-player-page { background: var(--ctp-base) !important; }
ytmusic-player-page[is-mweb-modernization-enabled] .side-panel.ytmusic-player-page { background: var(--ctp-base) !important; }
ytmusic-player-page[is-mweb-modernization-enabled][player-page-ui-state=TABS_VIEW] #main-panel.ytmusic-player-page { background: var(--ctp-base) !important; }

.content-info-wrapper.ytmusic-player-bar .byline.ytmusic-player-bar { color: var(--ctp-accent) !important; }
.title.ytmusic-player-controls { color: var(--ctp-text) !important; }
.byline.ytmusic-player-controls { color: var(--ctp-accent) !important; }
.play-pause-button-wrapper.ytmusic-player-controls { background: var(--ctp-mantle) !important; color: var(--ctp-text) !important; }

#primaryProgress.tp-yt-paper-progress { background-color: var(--ctp-accent) !important; }
#secondaryProgress.tp-yt-paper-progress { background-color: var(--ctp-crust) !important; }
#progressContainer.tp-yt-paper-progress,
.indeterminate.tp-yt-paper-progress::after { background-color: var(--ctp-mantle) !important; }
.slider-knob-inner.tp-yt-paper-slider { background-color: var(--ctp-accent) !important; border: var(--ctp-accent) 2px solid !important; }

.current-time.ytmusic-player-controls,
.total-time.ytmusic-player-controls { color: var(--ctp-text) !important; }

.title.ytmusic-queue-header-renderer { color: var(--ctp-text) !important; }
.subtitle.ytmusic-queue-header-renderer { color: var(--ctp-text) !important; }
.autoplay.ytmusic-tab-renderer .title.ytmusic-tab-renderer { color: var(--ctp-text) !important; }
ytmusic-player-page[is-mweb-modernization-enabled] .background-gradient.ytmusic-player-page { background: var(--ctp-base) !important; }

ytmusic-guide-entry-renderer:not([is-primary]) #play-button.ytmusic-guide-entry-renderer { background-color: transparent !important; }

.go3564761155 { background-color: var(--ctp-mantle) !important; color: var(--ctp-text) !important; }

ytmusic-player-bar:is([repeat-mode=NONE]) .repeat.ytmusic-player-bar { opacity: 0.5; }

#nav-bar-background.ytmusic-app-layout { background: var(--ctp-mantle) !important; }
ytmusic-app-layout[is-bauhaus-sidenav-enabled] #nav-bar-background.ytmusic-app-layout { border-bottom: none !important; }

ytmusic-nav-bar[enable-bauhaus-style] .app-bar-button.ytmusic-nav-bar {
  background: var(--ctp-accent) !important;
  color: var(--ctp-base) !important;
}

yt-formatted-string.ytmusic-guide-signin-promo-renderer { color: var(--ctp-subtext0) !important; }
yt-icon.ytmusic-guide-signin-promo-renderer { fill: var(--ctp-accent) !important; }
.action-text.ytmusic-guide-signin-promo-renderer { color: var(--ctp-accent) !important; }
EOCSS
}

# --- Config registration ---

register_theme_in_config() {
  local css_path="$1"

  [[ -d "$PEAR_CONFIG_DIR" ]] || {
    log_module "YouTube Music config dir not found — app not installed?"
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

# --- Desktop override for CDP ---

ensure_desktop_override() {
  # Create a .desktop override that launches youtube-music with CDP enabled
  # This allows live CSS injection without requiring user to manually add flags
  local user_apps="$HOME/.local/share/applications"
  local override="$user_apps/youtube-music.desktop"
  local system_desktop="/usr/share/applications/youtube-music.desktop"

  [[ -f "$system_desktop" ]] || return 0
  mkdir -p "$user_apps"

  # Check if override already exists and has our flag
  if [[ -f "$override" ]] && grep -q "remote-debugging-port=$CDP_PORT" "$override" 2>/dev/null; then
    return 0
  fi

  # Create override with CDP flag
  sed "s|^Exec=youtube-music|Exec=youtube-music --remote-debugging-port=$CDP_PORT|" \
    "$system_desktop" > "$override"
  log_module "created desktop override with CDP enabled"
}

# --- Live reload via CDP ---

inject_css_cdp() {
  local css_file="$1"
  local inject_script="$SCRIPT_DIR/pear-css-inject.py"
  local py

  # Check if pear-desktop is running with CDP enabled
  if ! curl -s --connect-timeout 1 "http://127.0.0.1:${CDP_PORT}/json" >/dev/null 2>&1; then
    return 1
  fi

  py="$(venv_python)"
  if [[ -f "$inject_script" ]] && "$py" "$inject_script" "$css_file" --port "$CDP_PORT" 2>/dev/null; then
    log_module "injected CSS via CDP (live update)"
    return 0
  fi

  return 1
}

reload_pear() {
  local css_file="$1"

  # Try CDP injection first (instant, no flicker)
  if inject_css_cdp "$css_file"; then
    return 0
  fi

  # CDP unavailable — check if app is running at all
  if ! pgrep -f "youtube-music/app.asar" >/dev/null 2>&1; then
    log_module "pear-desktop not running"
    return 0
  fi

  # App is running but without CDP — CSS is deployed to config and will apply on next launch.
  # Never kill and restart the app: the user perceives it as the app crashing.
  # The desktop override ensures future launches have CDP enabled.
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

  # Check if YouTube Music / pear-desktop is installed
  if [[ ! -d "$PEAR_CONFIG_DIR" ]] && ! command -v youtube-music &>/dev/null; then
    log_module "pear-desktop (youtube-music) not installed — skipping"
    exit 0
  fi

  # Generate CSS from colors.json
  local css_file="$GENERATED_CSS"
  if [[ ! -f "$COLORS_JSON" ]]; then
    log_module "no colors.json — skipping"
    exit 0
  fi
  command -v jq &>/dev/null || { log_module "jq not installed — skipping"; exit 0; }
  ensure_generated_dirs
  generate_css_from_colors_json > "$css_file"
  log_module "generated CSS: $css_file"

  # Register theme in pear-desktop config (for disk-based loading on next app start)
  register_theme_in_config "$css_file" || true

  # Ensure desktop override exists for future launches
  ensure_desktop_override

  # Reload app with new CSS (CDP injection or restart)
  reload_pear "$css_file"

  log_module "done"
}

main "$@"
