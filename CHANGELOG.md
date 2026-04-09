# Changelog

All notable changes to iNiR will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.18.0] - 2026-04-09

### Added
- **Systemd shell startup**: Shell startup migrated from niri `spawn-at-startup` to a systemd user service (`inir.service`). Migration 021 handles the transition — removes compositor startup lines, installs and enables the service. `KillMode=process` prevents systemd from terminating child apps on shell restart.
- **CLI discoverability overhaul**: Rich `--help` with dynamic IPC target listing by panel family, per-target `--help`, typo suggestions, function validation. New shell completions for bash, zsh, and fish. IPC registry generated from source with `generate-ipc-registry.py`.
- **Waffle settings redesign**: Complete Fluent-styled redesign of Quick Settings, Background, Themes, Interface, Modules, Bar, Shortcuts, and Waffle Style pages. New shared components: `WSettingsSection`, `WSettingsSlider`, `WSettingsInfoBar`, `WSettingsChoiceGroup`.
- **Gowall wallpaper editor**: New gowall page in waffle settings with theme browser, preview, and apply. Apply routes by active panel family. Shim dir prevents gowall from spawning image viewers after processing.
- **Pear Desktop theming**: New color module (`80-pear-desktop.sh`) with live CSS injection via Chrome DevTools Protocol. Config toggle `enablePearDesktop` with settings UI integration.
- **All-apps grid view**: Grid layout with letter jump strip added to waffle start menu.
- **Overview active-screen-only**: New `overview.activeScreenOnly` config option — shows overview only on the focused monitor in multi-monitor setups.
- **Equicord Discord client support**: Vesktop theme generation now includes `~/.config/equicord/` and `~/.config/Equicord/` paths.

### Changed
- **GameMode rewrite**: Replaced size-based fullscreen heuristic (60px margin) with niri's native `is_fullscreen` flag. New `shouldHidePanels` property — panels only hide when auto-detected AND focused window is fullscreen. Manual GameMode never hides panels. Eliminates false positives on maximized windows with small gaps.
- **Context-aware panel hiding**: Bar, Dock, and VerticalBar use `GameMode.shouldHidePanels` instead of blunt `GameMode.active`. Panels return when user opens Niri overview. Input regions (mask + exclusiveZone) nullified during gamemode to prevent invisible mouse traps.
- **Unified external theming**: Manual preset themes now fan out through the same `applycolor.sh` pipeline as wallpaper auto-generation. 120ms debounced timer ensures FileView flush before script execution. All targets (terminals, editors, chrome, spicetify, steam, pear) stay in sync.
- **GTK/Qt theme overhaul**: Selection colors changed from raw accent to blended surface tones. New hover/active/focus interaction states for buttons, menus, and entries. Added `Colors:Header` section for Darkly. qt6ct/qt5ct config generation hardened.
- **Parallax defaults**: Disabled by default for fresh installs. Zoom values normalized to 1.0 — headroom is now applied internally by the parallax engine.
- **ThemeService family awareness**: Detects `panelFamily` change and re-runs full color pipeline even for manual themes. Waffle wallpaper apply now triggers color regeneration.
- **Terminal color generation**: WCAG contrast-aware tone search prevents low-contrast terminal output. Tone capping prevents whitewash on bright colors. Force-dark terminal mode generates isolated `terminal.json`.
- **Discord theme rename**: Vesktop/midnight themes renamed from `ii-midnight` to `inir-midnight`. Subtler hover/active states, refined mention gradients, softer borders. Legacy CSS auto-cleaned on next color generation.
- **Compact sidebar media**: Redesigned media player and controls cards layout.
- **Bar/dock stale monitor guard**: Screen filter fallback prevents stale monitor names (e.g. after VRR re-enumeration) from hiding all panels.
- **Steam/Pear reload safety**: Removed `pkill` fallbacks for steamwebhelper and youtube-music. Apps are never force-killed — CSS deploys to disk and applies on next app restart.

### Fixed
- **Gowall waffle apply bleeding into ii**: Apply now routes by active panel family and restores waffle color regen.
- **Looks.ensureMinOpacity null guard**: `Qt.color()` returns null, not an invalid object — guard updated.
- **Gowall opening image viewer**: Shim dir with no-op `kitty`/`xdg-open` prevents unwanted window spawns.
- **WaffleWidgets layer**: Changed to `Top` with missing `WButton` import added.
- **Broken fluent icons in WInterfacePage**: Missing `WButton` import restored.
- **Glass opacity floor**: Enforced minimum for waffle aurora/angel surfaces.
- **Overview vertical centering**: Replaced anchor-based centering with calculated `topMargin` approach to prevent subpixel blur and erratic positioning.
- **Volume OSD on gamemode activation**: Prevented spurious OSD trigger during gamemode state change.
- **Slider handle-track desync**: Fixed during drag interaction, added tabular numbers for consistent width.
- **Parallax sizing and crossfader artifacts**: Reworked transition logic and hardened skew selector sync.
- **Click-outside backdrops**: Declarative visibility prevents orphaned input capture layers.
- **Niri output key rejection**: Compositor settings backend now rejects unsupported output keys.
- **Volume controls after output switch**: Fixed, with easyeffects crash avoidance.
- **Alacritty migration**: Hoisted misplaced `live_config_reload` key.
- **Duplicate inir instances**: Guard on `inir run`, kill foreground wrappers on stop, loop `qs kill` for multi-instance cleanup.
- **Foot terminal colors**: Switched to `[colors-dark]` section to drop deprecation spam.
- **Keyboard layout save key**: Fixed save path, stopped language fallback to `en_US`.
- **Theme regen consistency**: Aligned regeneration across settings, family switch, and external targets.
- **Preset theme color propagation**: Fixed propagation to external apps and family switch regen.
- **Fullscreen surface handling**: Unmap all shell surfaces during fullscreen for direct scanout.

### Removed
- **`overview.centerLauncher`**: Config option removed — overview always uses calculated vertical centering.
- **`spawn-at-startup` compositor entry**: Shell startup ownership moved to systemd user service.

## [2.17.4] - 2026-04-05

### Added
- **Complete Internationalization**: 14 new languages fully translated with 3400+ keys each (es_AR, fr_FR, de_DE, it_IT, pt_BR, ru_RU, uk_UA, hi_IN, ar_SA, he_HE, zh_CN, ja_JP, ko_KR, vi_VN).
- **Translation Auto-Updater**: Added `translations/tools/auto-translate.js` script to bulk translate missing keys via Google Translate API without hitting limits.

### Changed
- **Bug Report Template**: Updated GitHub issue templates to require explicit Qt, Quickshell, and Distro version fields for better debugging.

### Fixed
- **Niri Display Config State**: Fixed combo box bindings breaking after user interaction. State is now imperatively resynced after output data refreshes, and reads are deferred by 300ms to avoid stale values.
- **Settings Status Banner UI**: Improved the error/info status banner in NiriConfig with distinct colors (error/primary), larger icons, and solid-styled Dismiss/Retry buttons.

## [2.17.3] - 2026-04-04

### Added
- **Configurable sidebar animations**: Sidebars now support 4 animation types — slide (default), fade, pop, and reveal — selectable from Settings > Panels. Uses Material Design motion tokens with enter/exit transitions.
- **Lock screen video/GIF support**: Video and animated GIF wallpapers now render on the lock screen with first-frame fallback. Animation is off by default (Settings > Lock Screen toggle). Supports both ii and waffle families including the Niri-safe variant.

### Fixed
- **YTMusic track selection race**: Clicking a song while another was playing could advance to the next track instead of the selected one. Added `_userInitiatedPlay` guard to suppress spurious `playNext()` from the old mpv's exit handler during the 200ms handoff window.
- **Cloudflare WARP toggle misalignment**: WARP toggle in the classic quick panel broke grid alignment because its `contentItem` lacked the Item wrapper other toggles use.
- **Classic quick toggles left-aligned in compact mode**: Grid was anchored to left/right edges in compact mode instead of centering. Now always horizontally centered.
- **Waffle lock screen GIF detection**: `wallpaperIsVideo`/`wallpaperIsGif` were checking the thumbnail-resolved path instead of the raw source path, which could miss animated wallpapers when a thumbnail was set.

## [2.17.2] - 2026-04-04

### Added
- **Arch dependency tracker meta-package**: New `inir-deps` package registered during setup so pacman orphan cleanup does not remove iNiR runtime dependencies.
- **Post-install extras flow**: `./setup extras` now exposes optional installs for iNiR-Walls and ii-pixel-sddm after initial setup.
- **Curated software catalog sidebar tab**: Added software discovery surface with bundled catalog data and AppCatalog service wiring.
- **Material background clock controls**: Added full clock customization for the ii background widget (schema/defaults/settings + widget surfaces).

### Changed
- **Arch install hardening**: Dependency install flow now handles known Noctalia package conflicts before iNiR package resolution.
- **Path model normalization**: Runtime/services/settings/welcome surfaces now consume centralized XDG-derived paths from `Directories.qml` instead of scattered literals.
- **Setup UX flow**: Fresh install keeps optional content opt-in (SDDM/iNiR-Walls), update path handling and theme actions were hardened, and the setup TUI received the new Ink visual refactor.
- **README localization refresh**: Main README and localized docs/readme pages were rewritten/synced for current project messaging.
- **Technical docs sync**: IPC, theming, package, and project-map docs were aligned with real runtime/distribution behavior.

### Fixed
- **Wallpaper status resolution**: Setup now reads `theme-meta.json` via `.wallpaper` with `.source_path` fallback so active wallpaper no longer shows as `none` when metadata uses source-path shape.
- **iNiR-Walls feedback**: Extras flow now shows visible clone/download progress and no longer suppresses user-facing install logs.
- **Theming target wiring**: Spicetify target config key corrected to `appearance.wallpaperTheming.enableSpicetify`, and terminal theming applies with safer terminal ancestry detection.
- **Runtime interaction edge cases**: Cheatsheet key handling and wallpaper coverflow monitor targeting/cleanup were corrected for more reliable focus and close behavior.
- **YTMusic playback/state reliability**: Fixed media source switching sync and autoplay recovery when mpv hangs at EOF.
- **Background media widget blur placement**: Corrected half-pixel placement artifact that caused blur instability.
- **Settings/overlay alignment polish**: Fixed variable-width action tab underline alignment, removed settings nav scrollbar rail bleed, and prevented overlay-mode hover bubble from shifting nav alignment.
- **Anime schedule watch fallback**: Migrated fallback target to 9animetv for broken/legacy watch links.

## [2.17.1] - 2026-04-02

### Added
- **SDDM session popup selector**: Session switcher on the login screen now opens a popup list instead of blindly cycling through entries.
- **CLI command forwarding**: `inir config`, `inir info`, `inir backup`, and `inir logs` forwarded through the launcher to the setup TUI.
- **TUI library expansion**: Rich chooser menus, task progress tracker, key-value detail views, and section helpers for setup subcommands.

### Fixed
- **Dock/taskbar icon resolution**: Reverse-lookup maps in AppSearch match Electron, AppImage, and reverse-domain window IDs to their desktop entries (#105).
- **Backdrop hideWallpaper gate**: `hideWallpaper` now respects `backdrop.enable` instead of firing unconditionally (#104).
- **Repo-link version detection**: `get_installed_version()` and `get_installed_commit()` return live git state for repo-link installs instead of stale `version.json`.
- **Migration 009 modular config**: Handles both monolithic `config.kdl` and post-018 `config.d/40-environment.kdl` layouts for the dbus log spam fix.
- **SDDM theme idempotent copy**: Checksum comparison skips the copy when source and target are already identical.

### Changed
- **PKGBUILD optdepends**: Added `gowall-bin` and `nm-connection-editor`; synced `.SRCINFO`.

### Removed
- **CI workflow**: GitHub Actions workflow removed — not viable on current repo plan.

## [2.17.0] - 2026-04-01

### Added
- **Shell entry animation**: Panels slide in on startup with a 400ms delay, and hide during wallpaper coverflow transitions for a cleaner visual flow.
- **Family transition overlay**: Snapshotted color preservation during panel family switches, native iNiR logo, and cleaner Material Design text styling.
- **Steam theming rewrite**: Template-based pipeline with CDP (Chrome DevTools Protocol) live injection replaces the old Adwaita for Steam approach. Includes visual quality overhaul and real-time color updates.
- **Python-only color pipeline**: Unified Material You color generation using pure Python, removing the external `matugen` binary dependency entirely.
- **MaterialPlaceholderMessage widget**: New M3-style empty-state component replaces `PagePlaceholder` across 17 modules for consistent placeholder messaging.
- **Version divergence warning**: `inir` CLI warns when installed code version doesn't match the running runtime, preventing stale-code confusion after updates.
- **Config directory compatibility layer**: Transparent bridge for the legacy config path, easing future migration without breaking existing setups.
- **v1→v2 manifest upgrade protection**: `setup update` detects and preserves user modifications to runtime files when upgrading manifest versions.
- **Wallpaper selector rewrite**: Skew view rebuilt with blur backdrop overlay, refined exit animation, and shell panel hiding during selection.
- **Alt-tab switcher improvements**: Responsive geometry adapting to window count, Vim-style keybindings (`hjkl`), and `Shape` drop shadows.
- **Control panel enhancements**: State-driven open/close animations, compact mode, and config-driven section visibility.
- **Color strength and accent color config**: Extended schema with `color-strength` and `accent-color` options for finer theming control.
- **Scheme variant control**: Material scheme variant (Content, Expressive, Fidelity, etc.) selection wired into QML theme services.
- **Waffle display scaling**: `dp()` function applied across waffle panel layout dimensions for DPI-aware sizing.
- **CI, code of conduct, and security policy**: GitHub Actions workflow, community standards, and vulnerability reporting process.

### Changed
- **INIR_VENV rename**: Environment variable `ILLOGICAL_IMPULSE_VIRTUAL_ENV` renamed to `INIR_VENV` across all scripts and services (migration 020).
- **Auto scheme detection tuning**: Expressive and Rainbow scheme variants are now much rarer in automatic selection, favoring more predictable palettes.
- **Spotify behavior**: Minimize to tray instead of close; moves to workspace 99 on shell exit to preserve session.
- **Dual-path PopupToolTip**: Tooltip system refactored for both inline and popup rendering paths with migrations across consumers.
- **GTK/KDE/Qt external app theming**: Enhanced template rendering for GTK3/4, KDE kdeglobals, and Qt Darkly color schemes.
- **README and CONTRIBUTING rewrite**: Documentation refreshed for clarity and accuracy.
- **Shebang standardization**: All shell scripts use consistent `#!/usr/bin/env bash` with project-wide shellcheck configuration.
- **iceicerice legacy backend removed**: Old theming backend fully excised in favor of the unified Python pipeline.

### Fixed
- **Workspace numbers per monitor**: Bar workspace indicators now stay local to each screen instead of showing global workspace IDs (#90).
- **Calculator sizing and focus**: Sidebar calculator no longer jitters on resize; focus management stabilized (#99).
- **Niri center lone columns**: Default Niri config centers single columns instead of left-aligning them (#91).
- **Crash restart loop**: Background launcher wrapper detects rapid crash loops and stops respawning after a threshold.
- **Bar module toggle orientation**: Settings toggle for ii bar modules remains orientation-safe regardless of bar position.
- **Migration 017 keybind dedup**: Full launcher path matching prevents false positives in keybind deduplication.
- **kde-material-you-colors wrapper**: Proper process detachment prevents blocking the color pipeline.
- **Spicetify color mapping**: Improved token mapping and prevented Spotify from auto-opening during theme application.
- **YouTube Music OAuth**: Restructured OAuth section out of advanced popup to fix layout overflow.
- **Qt session env preservation**: `inir` CLI no longer unsets Qt environment variables inherited from the session.
- **Theme race conditions**: Serialized shell script writes to `config.json` with `flock`; theme switching sequences properly gated.
- **GTK CSS symlink safety**: Color pipeline breaks symlinks before writing GTK4 CSS files to prevent cross-contamination.
- **Update version persistence**: Handles empty `version.json` gracefully in update tracking.
- **Avatar binding break**: QtObject resolver pattern prevents property binding loops in avatar component.
- **Settings DropShadow import**: Qualified `DropShadow` with `GE` alias in SettingsOverlay to resolve import ambiguity.
- **Hardcoded path resolution**: Distribution scripts use dynamic paths for AUR and system-wide install compatibility.
- **Running instance detection**: Launcher detects running instance by path to resolve identity mismatches between dev and installed copies.
- **Waffle fluent icons**: Expanded icon mappings for common applications in waffle taskbar.
- **PropertyCache warnings**: Resolved duplicate IPC handler registrations and stale property cache warnings.
- **Waffle UI bugs**: Six fixes across widgets, settings, theming, and family transition in waffle panels.

### Removed
- **matugen binary dependency**: Fully replaced by the Python-only color generation pipeline. External `matugen` package is no longer required.
- **Adwaita for Steam script**: `apply-adwsteam-theme.sh` removed, replaced by template-based Steam theming.
- **iceicerice theming backend**: Legacy color backend removed after migration to unified pipeline.
- **Unused config key**: `adwSteamColorTheme` removed from config schema.

### Performance
- **Color output chroma scaling**: Chroma adjustments applied to output tokens instead of seed color for more predictable palette behavior.
- **Doctor diagnostics**: Added missing dependency checks, dynamic Qt path detection, and clearer fix guidance messages.
- **Bootstrap hardening**: Setup bootstrap and update flow made more resilient against partial failures.

## [2.16.0] - 2026-03-26

### Added
- **AUR-ready Arch packaging**: Complete PKGBUILD ecosystem (`inir-shell-git`, `inir-shell`, `inir-meta`) with 51 dependencies and 37 optional dependencies, `.SRCINFO` generation, and AUR publish workflow. Installs runtime to `/usr/share/quickshell/inir/` with package-managed metadata.
- **Compositor/Niri settings page**: New settings page with scrollable tiling presets, gaps, window rules, decoration, and animation controls.
- **Target-driven palette generation**: Theming pipeline supports target-driven Material You palette extraction for more precise color matching.
- **Font verification in doctor**: `setup doctor` now checks for critical fonts (Material Symbols, Roboto Flex, JetBrains Mono NF, Oxanium) and offers automatic installation.
- **Centralized app command execution**: App launcher routes all launch commands through a unified execution path with compositor-aware dispatching.
- **Expanded Niri controls in settings**: Tools surface split with additional Niri-specific compositor controls.
- **Qt/Quickshell ABI mismatch detection**: Three-layer detection (startup check, restart guard, doctor probe) prevents crashes from Qt↔Quickshell version incompatibility.

### Changed
- **Hardened shell transitions**: Improved family transition animation stability and runtime robustness.
- **Hardened doctor/metadata fallback**: Doctor diagnostics and runtime metadata discovery use safer fallback paths and handle missing metadata gracefully.
- **Restart loop prevention**: Launcher detects rapid crash loops and stops respawning after a configurable threshold instead of spinning indefinitely.
- **Repository hygiene**: AI-driven guidance documents and module architecture docs removed from version tracking; gitignore updated for agent artifacts.

### Fixed
- **Close-window double-close race**: `Mod+Q` no longer fires duplicate close commands on Niri.
- **Font token alignment**: Corrected font token references and config schema synchronization across Appearance and settings surfaces.
- **XDG path safety**: Hardened XDG path construction in distribution and setup scripts.
- **Dead code cleanup**: Removed unused code paths and stale references found during comprehensive audit.

## [2.15.0] - 2026-03-23

### Added
- **Wallpaper pan/zoom**: Reposition and zoom wallpapers within the fill-crop frame with interactive drag-and-scroll settings UI (`background.pan.{x, y, zoom}`).
- **Gowall wallpaper effects**: New `GowallService` and settings editor for wallpaper color manipulation — convert with builtin/custom/Material themes, invert, pixelate, and live preview.
- **Material scheme variant selector**: Choose between Content, Expressive, Fidelity, Monochrome, Neutral, Rainbow, and Tonal Spot color schemes in Control Panel, Waffle Widgets panel, and theme settings pages.
- **InputChip widget**: M3-style compact tag component with optional icon, label, and removable close button.
- **Fields of the Shire theme presets**: New dark and light nature-inspired theme presets with warm earthy tones.
- **Niri keybinds overhaul**: Expanded default keybinds with session dialog, power-off monitors, browser launch, column layout/resize, consume/expel, monitor navigation, media controls, and comprehensive inline documentation.

### Changed
- **Wallpaper selector rewrite**: Skew view rebuilt with rapid-nav velocity tracking, adaptive wheel thresholds (trackpad vs mouse), focus pulse animations, increased cache buffer (600→1400), and adaptive width animation.
- **VSCode theme generators**: Python and Go generators now use HSL color manipulation for richer, more readable syntax highlighting with saturation boosting and contrast-aware token colors.
- **Dock preview**: Live toplevel tracking with stable per-window keys and smart capture-signature deduplication to avoid redundant screenshots.
- **Vertical bar aurora/angel**: Blur layer separated into sibling Item with screen-sized wallpaper image for correct corner alignment; added angel inset glow and partial border.
- **Quick settings redesign**: Hero wallpaper preview with style-aware card, next/random overlay buttons, and improved layout.
- **Waffle system button**: Battery percentage text shown next to icon; network icon filled.
- **Waffle Looks.qml**: Danger/warning colors derived from Material tokens instead of hardcoded values.
- **Color pipeline improvements**: GTK theme application, terminal config generation, material color generation, and Kvantum theming all refined.
- **Launcher restart flow**: `start_background()` uses nohup for proper process detachment; restart via `inir start` instead of direct `qs` exec.

### Fixed
- **Settings direct mutations**: Converted legacy `Config.options` property assignments to `Config.setNestedValue()` in InterfaceConfig (overlay, crosshair, dock settings) and Translator (language persistence).
- **ThumbnailImage path resolution**: Fixed non-absolute path handling and improved URI encoding compliance for thumbnail cache lookup.
- **Scheme variant on manual themes**: Settings pages now use `MaterialThemeLoader.applySchemeVariant()` with seed color for non-auto themes instead of only running `switchwall.sh`.
- **Distribution scripts**: `robust-update.sh`, `snapshots.sh`, and `uninstall.sh` use path-based `qs -p` targeting consistent with the launcher.
- **Super overview daemon**: PID detection matches both legacy `qs -c inir` and path-based `qs -p <path>` process forms.

### Removed
- **OpenCode theme preset**: Removed from ThemePresets (opt-in only via `enableOpenCode` config).

## [2.14.0] - 2026-03-20

### Added
- **`inir` launcher CLI**: Unified daily-use command (`inir run`, `inir restart`, `inir settings`, `inir overview toggle`, etc.) replacing direct `qs` invocation. Supports direct IPC shorthand, maintenance delegation, systemd service management, and version inspection.
- **Per-monitor workspaces (Niri)**: Each bar can show workspaces for its own monitor (`bar.workspaces.perMonitor`).
- **Waffle quick action switches**: Individual toggles for Files/Terminal/Settings/Wallpaper/Screenshot/Screen Record/Session in the Widgets panel.
- **Waffle background clock widget**: Configurable clock overlay on the desktop background with font, position, and style settings.
- **Waffle Interface settings page**: New dedicated page for waffle-specific UI customization.
- **Configurable browser action**: `apps.browser` config key for the global "open browser" action.
- **Colors-only wallpaper mode**: Extract Material You colors from a wallpaper without displaying it (`appearance.wallpaperTheming.colorsOnlyMode`).
- **Systemd service asset**: `inir.service` for managed startup via `inir service install/enable`.
- **Desktop entry**: `inir.desktop` for XDG application launchers.
- **DMS-style install surface**: Root `Makefile` with `make install`/`make uninstall` for system-level deployment.
- **Arch Linux packaging**: First-class PKGBUILDs for `inir-shell`, `inir-shell-git`, and `inir-meta` under `distro/arch/`.
- **Modular Niri config**: Default Niri configuration split into `config.d/` fragments (input, layout, window-rules, environment, startup, animations, binds, layer-rules, user-extra).
- **Migration 016**: Converts legacy `qs`/`ii`-era Niri keybindings to the `inir` launcher.
- **Migration 017**: Deduplicates hardware keybinds (brightness/media) that accumulated from prior migration bugs.
- **Migration 018**: Automatically splits monolithic Niri configs into the modular `config.d/` layout.
- **Install/update metadata model**: Runtime metadata now records `installMode`, `updateStrategy`, `repoPath`, `source` for package-aware lifecycle management.
- **Manifest-driven file sync**: Install and update flows now use `sdata/runtime-payload-dirs.txt` and `sdata/runtime-root-files.txt` instead of hard-coded rsync patterns.

### Changed
- **Dark mode toggles**: Routed through `MaterialThemeLoader` to ensure a reliable `colors.json` reload after switching.
- **Style selection**: No longer forces `appearance.transparency.enable` when selecting styles.
- **Color system modularized**: `applycolor.sh` rewritten from monolithic script to modular dispatcher with individual modules (terminals, GTK, Qt, Spicetify, SDDM) and shared runtime library.
- **Shell RC namespace**: Setup-managed shell integration files moved from `~/.config/ii/` to `~/.config/inir/`; existing RC includes are migrated in place.
- **Setup behavior for packaged installs**: `setup status`, `setup update`, `setup rollback`, and `setup uninstall` now detect externally-managed installs and provide appropriate guidance instead of assuming repo-based updates.
- **Shell lifecycle commands**: Internal kill/restart/IPC flows use path-based `qs -p <path>` targeting instead of config-name-based `qs -c inir`.
- **Alt-Switcher refactor**: Major refactoring of both ii and waffle alt-switcher components with expanded configuration options.
- **Niri keybinds documentation**: Complete rewrite of `docs/KEYBINDS.md`.

### Fixed
- **Cloudflare WARP toggle**: Periodic status polling to stay in sync.
- **EasyEffects sink control**: Volume/mute resolves to the physical sink when EasyEffects is the default sink.
- **Wallpaper transitions**: New wallpaper changes fast-forward an in-progress transition; background widget placement is debounced.
- **VS Code Material Code theming**: Respects `appearance.wallpaperTheming.enableVSCode`.
- **Waffle user avatar**: More reliable fallback loading.
- **Waffle settings UI**: Improved loading indicator and multiple polish fixes.
- **Weather location privacy**: Toggle now synchronized across all shell surfaces (bar, overview, lock screen, sidebar, control panel) instead of only affecting the Control Panel card.
- **Weather payload parsing**: Updated to handle current `wttr.in` nested response shape (`data.current_condition`).
- **GameMode toast suppression**: Fullscreen/gamemode states now suppress desktop toasts.
- **Waffle "Colors only" preview**: Persists and previews correctly; clears stale preview state when disabled.
- **Migration target file creation**: Required migrations that create their own target file are no longer skipped.
- **WaffleConfig direct mutation**: Legacy settings writes converted from direct `Config.options` mutation to `Config.setNestedValue()`.
- **Stale `qs -c inir` references**: Setup scripts (robust-update, snapshots, uninstall) and daemon now use path-based targeting consistent with the launcher.
- **Sandbox leak in uninstall**: `Darkly.colors` paths now use `XDG_DATA_HOME` instead of hardcoded `$HOME/.local/share`.

## [2.13.2] - 2026-03-13

### Added
- **Keyboard-Pro Action Mode**: Comprehensive keyboard-driven command palette accessible via `/` prefix in the overview launcher. Navigate the entire shell without a mouse.
- **Category tab bar**: SecondaryTabBar with animated indicator for All, System, Appearance, Tools, Media, and Settings categories.
- **Arrow key navigation**: Left/Right arrows and Tab/Shift+Tab cycle categories; Up/Down navigate action list; Enter executes.
- **Media playback actions**: Play/Pause, Next Track, Previous Track via MprisController integration.
- **Volume controls**: Volume Up and Volume Down actions via Audio service.
- **Screen recording toggle**: Start/stop wf-recorder from the action palette.
- **Clipboard history action**: Open clipboard manager directly from action mode.
- **Music recognition action**: Trigger SongRec music identification from the palette.
- **Notepad action**: Quick-open the sidebar notepad.
- **EasyEffects toggle**: Enable/disable audio equalizer from action mode.
- **Wallpaper Coverflow action**: Open the coverflow wallpaper selector alongside the existing grid selector.
- **Zoom controls**: Zoom In, Zoom Out, and Reset Zoom actions for accessibility.
- **On-Screen Keyboard toggle**: Show/hide OSK from action mode.
- **Panel family switching**: Switch between ii and waffle panel families from the palette.
- **Paru package manager support**: All package actions (install, remove, update) detect and use paru as AUR helper alongside yay.
- **Todo feedback**: Adding a todo now shows a desktop notification confirming the task was added, with usage hint when no text provided.

- **Keyboard navigation hints footer**: Shows keybind hints (↑↓ Navigate, ↵ Run, Tab/←→ Category, Esc Close) at the bottom of the action panel for discoverability.

### Changed
- **Wallpaper selector split**: "Change Wallpaper" action now explicitly labeled as Grid or Coverflow, each closing the other before opening.
- **AUR badge theming**: Replaced hardcoded `#1793d1` color with `Appearance.colors.colPrimary` / `Appearance.inir.colPrimary` tokens for proper style-aware rendering.
- **System update action**: Now auto-detects yay/paru/pacman instead of using a hardcoded command.
- **Package install action**: Uses runtime AUR helper detection (`yay > paru > sudo pacman`) instead of hardcoded `yay`.
- **Tab bar spacing**: Added horizontal margins (12px) and increased indicator padding (12px) for proper visual separation between category tabs.
- **Package action refactor**: Deduplicated package install/remove logic into `_executePackageActionStatic` with value capture before component destruction.

### Fixed
- **iNiR style icon**: Replaced invalid "spark" Material Symbol with "terminal" for the Style: iNiR action.
- **Left/Right arrows in search input**: Removed Left/Right arrow key interception from SearchBar to prevent conflict with text cursor movement. Category cycling from search now uses Tab/Shift+Tab only; Left/Right remain available from the action list delegates where there is no text cursor conflict.
- **Up arrow on first item**: Pressing Up on the first action list item now returns focus to the search input via `returnToSearch` signal.
- **Escape key**: Pressing Escape from within the action list now closes the overview.
- **ReferenceError on action execute**: Refactored `onClicked` to capture action/package references before closing the overview, preventing use-after-destroy crashes.

## [2.13.1] - 2026-03-12

### Added
- **Backdrop wallpaper transitions**: Both ii and waffle backdrops now use `WallpaperCrossfader` for smooth wallpaper transition animations matching their workspace counterparts.
- **Animated blur toggle**: New `enableAnimatedBlur` config key for GIF/video wallpapers in both families.
- **Blur transition suppression**: Blur fades out before wallpaper transitions so the change is visible even with windows open, then fades back in after transition completes.
- **Waffle backdrop effects controls**: Vignette, saturation, contrast, and animated blur controls added to waffle backdrop settings.
- **Waffle transition config**: Independent transition settings for waffle wallpapers (`waffles.background.transition`).
- **Spicetify wallpaper theming**: Opt-in Material You color scheme for Spotify via Spicetify with live watch mode — colors update on wallpaper change without restarting Spotify (PR #80 by @yukazakiri).
- **Migration 013**: Auto-patch kde-material-you-colors wrapper on update.
- **Migration 014**: Malloc arena optimization (`MALLOC_ARENA_MAX=2`, `MALLOC_MMAP_THRESHOLD_=131072`) for reduced glibc memory overhead.
- **Migration 015**: Clean orphan config keys (`blurStatic`, `videoBlurStrength` → `thumbnailBlurStrength`) from existing user configs.

### Changed
- **Blur decoupled from awww renderer**: Blur now reads from the crossfader texture regardless of who renders the visible wallpaper, fixing blur not working when parallax is disabled.
- **blurStatic removed**: Blur only activates when windows are present on the workspace. The always-on `blurStatic` option caused rendering issues in both families and has been removed.
- **videoBlurStrength → thumbnailBlurStrength**: Renamed for clarity; migration preserves user values.
- **Saturation/contrast defaults**: Changed from 1.0 to 0 (neutral) for new installs. Existing users keep their values.
- **Backend provider hardcoded**: `awww` backend is now always active (config key ignored, no UI change).
- **Settings surfaces refreshed**: Updated quick options, control panel, and shell surfaces.

### Fixed
- **Wallpaper double-apply**: Prevent duplicate `switchwall.sh` runs with `_applyInProgress` suppression flag and 3-second timer.
- **kde-material-you-colors stacking**: Kill previous daemon instance before launching new one to prevent orphan processes.
- **StyledListView animations**: Use `Transition.enabled` instead of `running` on child animations to prevent animation glitches.
- **Blur alignment**: Reverted `sourceSize÷4` to screen resolution for correct blur positioning.
- **Blur source loading**: Keep wallpaper source always loaded to avoid style-switch freeze.
- **Todo.qml runtime error**: Replaced invalid `Process.exec` with `Quickshell.execDetached`.
- **Config schema sync**: Added `enableOpenCode`, `vscodeEditors` (14 editor forks), and `omp` (oh-my-posh) to schema and defaults — keys existed in theming scripts but were missing from Config.qml.
- **Kitty tab bar colors**: Update live via SIGUSR1 and atomic symlink swap.
- **WaffleConfig stale reference**: Removed UI control for deleted `blurStatic` config key.

### Performance
- **Animation instances**: Replaced 402 `createObject` calls with inline `Animation` instances, eliminating per-animation QObject allocation overhead.
- **Blur GPU gating**: Style-gated `layer.enabled` and `source` on all blur Images — GPU blur work only runs when the active style uses it. Reduced `blurMax` from 100 to 64.
- **Wallpaper caching**: `cache:false` on all wallpaper Images across both families with `sourceSize` constraints to cap decoded pixmap resolution.
- **Thumbnail caching**: Skip `magick` subprocess when thumbnail is already loaded; cache `magick identify` results.
- **Crossfader optimization**: `cache:false` on crossfader slots, release inactive slot texture after transition completes.
- **ColorQuantizer gating**: Only run wallpaper ColorQuantizer when aurora/angel style is active.

### Community
- PR #80 by @yukazakiri — Spicetify wallpaper theming support

## [2.13.0] - 2026-03-08

### Added
- **Wallpaper Coverflow selector**: Browse wallpapers with 3D perspective cards, folder navigation, skew view with momentum physics, and hero crossfade transitions. Full aurora/inir/angel style support.
- **Wallpaper transitions**: Multi-type transitions between wallpapers — crossfade, slide, zoom, and blur-fade — with configurable duration and per-type settings.
- **Bar Taskbar**: Dock apps integrated directly into the horizontal and vertical bar as a taskbar with live window previews, pin/unpin, and window management actions.
- **Fluid Ripple shader**: New pixel-art inspired ripple effect for interactive elements with configurable visual parameters (PR #55).
- **NVENC recording support**: Screen recorder auto-detects Nvidia GPUs and uses hardware NVENC encoding, with VAAPI fallback for AMD/Intel and software fallback chain.
- **GPU resource monitoring**: GPU usage indicator added to bar/vertical bar resource monitors. Configurable indicators (CPU, RAM, GPU, temperature) via settings.
- **Primary monitor selection**: Choose which monitor is primary for bar, dock, and panel targeting in Display settings.
- **Bar scroll customization**: Configure left/right scroll actions on the bar, including workspace scroll direction inversion (PR #53).
- **Overview center launcher**: Option to center the app launcher in the overview dashboard with refined glass surfaces.
- **AwwwBackend service**: External wallpaper rendering via the awww daemon with automatic sync from iNiR's wallpaper config and seamless internal fallback.
- **OpenCode theme generator**: Material You color integration for OpenCode editor via matugen pipeline.
- **Oh-my-posh theme generator**: Material You prompt theme with wallpaper-synced colors.
- **YT Music OAuth**: OAuth setup flow and song rating support for YouTube Music integration.
- **Wallpaper upscale notification toggle**: Hide the "wallpaper was upscaled" notification in background settings.
- **Screen recording settings**: Exposed wf-recorder configuration (codec, format, audio) in settings UI.

### Changed
- **CompactMediaPlayer redesign**: Cleaner blur, centered controls, unified glass surfaces in compact sidebar mode.
- **Settings theming**: Complete aurora/inir/angel style support across all settings pages — cards, overlays, material presets, and section backgrounds.
- **StyledComboBox rewrite**: Full shell theming with proper aurora/inir/angel style dispatch, replacing the stock Qt combo box.
- **Dock performance**: Optimized rebuild logic and reduced binding churn for smoother animations with many windows.
- **MprisController debounce**: Rapid signal bursts from media players are now debounced to prevent UI stutter.
- **Network service debounce**: WiFi scan results debounced to reduce unnecessary UI rebuilds.
- **GTK theming improvements**: GTK3 CSS support, improved GTK4 token mapping, and hardened switchwall color pipeline.
- **btop theme generator**: Rewritten to use Material You design tokens directly.
- **Clipboard panel**: Dark glass background for aurora/angel styles, reset count on wipe.
- **Dark glass unification**: Consistent glass surfaces across compact sidebar controls and quick action cards.

### Fixed
- **Audio volume slider**: Restored `setSinkVolume` with ramp curve to prevent illegal volume increment on slider click.
- **Wallpaper Skew view focus**: Fixed focus-on-reopen bug where the coverflow panel showed wrong image after external wallpaper change.
- **FloatingImage overlay**: Simplified implementation with proper Config access (optional chaining + setNestedValue) and zero-dimension fallback.
- **MaterialSymbol axes**: Clamped `fill` (0–1) and `opsz` (20–48) values to prevent Qt rendering warnings.
- **Booru context menu**: Opens at button edge outside sidebar bounds; fixed Niri grab-loss dismiss.
- **Clipboard self-trigger**: Dock previews no longer contaminate clipboard history; fixed stale `_selfCopy` flag.
- **Booru wallpaper downloads**: Save to `~/Pictures/Wallpapers` instead of unintended directory.
- **Animation guards**: Added `animationsEnabled` checks to Behaviors across multiple widgets to respect reduced-motion preference.
- **Bar GPU icon**: Fixed `memory_alt` icon name; clamped media player width to prevent overflow.
- **Close animations & keyboard focus**: Improved panel close transitions and focus handling (PR #63).
- **Fish autosuggestion contrast**: Fixed low-contrast autosuggestion colors in fish shell (PR #69).
- **Chrome variant theming**: Corrected Material You color mapping for Chrome theme generation (PR #70).
- **Settings overlay background**: Solid background for material/cards/inir styles instead of transparent.
- **Compact sidebar warnings**: Suppressed spurious Connections warnings in compact mode.
- **Screen recording UI**: Simplified layout and fixed style issues in recording settings.
- **Various setup fixes**: Extracted WebEngine build helper, fixed wayland-protocols makedep, SDDM local variable bug, and CRASH_HANDLER build flag.

### Community
- PR #53 by @hakimshifat — Bar scroll customization
- PR #55 — Pixel Fluid Ripple shader
- PR #63 — Close animations, keyboard focus, YtMusic OAuth
- PR #69, #70 — Fish autosuggestion contrast, Chrome variant theming
- PR #74 by @orcusforyou — Lock screen fixes

## [2.12.0] - 2026-02-28

### Added
- **Overview Dashboard panel**: New control center below workspace previews with quick toggles, media player, volume/brightness sliders, weather summary, and system stats. Configurable via `overview.dashboard.*` settings.
- **Events & Reminders system**: Full event management with date-based notifications, calendar integration with event dots, and professional add/edit dialog.
- **Calendar event indicators**: Days with events show colored dots; clicking navigates to Events tab.
- **Reorderable Controls sections**: Drag to reorder sidebar sections (sliders, toggles, devices, media, quick actions) in compact layout. Persisted via `sidebar.right.controlsSectionOrder`.
- **VSCode/Cursor theme generation**: Material You integration for VS Code and Cursor editors with wallpaper-synced colors.
- **Zed editor theme generation**: Material You theme support for Zed (PR #62).
- **Lock screen display name**: Show user's full name (GECOS) instead of username on lock screen.
- **Documentation site**: Next.js static site with GitHub Pages deployment, full feature documentation.
- **Launcher search prefixes**: Document search prefix shortcuts in launcher.

### Changed
- **Dashboard moved to Overview**: DashboardWidget removed from right sidebar; functionality consolidated into OverviewDashboard in the Overview panel.
- **Compact sidebar polish**: Simplified SectionDivider (no lines, just text), enhanced CompactMediaPlayer with cleaner blur and centered controls.
- **README install instructions**: Updated with explicit `./setup install`, `./setup update`, and TUI menu documentation.
- **Events reactivity**: Replaced property-based reactivity with trigger pattern (`_eventsTrigger` counter) for reliable UI updates when events change.
- **ProfileHeader greeting**: Uses primary color instead of subtext for warmer appearance.

### Fixed
- **SDDM install script**: Improved privilege escalation (try cached sudo before pkexec), force X11 display server (kwin_wayland crashes in VMs), handle conflicting display-manager.service symlinks.
- **Installer robustness**: Quote variables for filenames with spaces, correct pacman -Syu logic for interactive/non-interactive modes, i2c-dev module config without subshell functions.
- **DatePicker compatibility**: Fix ComponentBehavior: Bound compatibility issues.
- **Notifications null safety**: Filter null values in stringifyList, add null check in notifToJSON.
- **CompactMediaPlayer**: Add fallback for undefined effectiveIdentity, use MPRIS player volume instead of system audio.
- **Config fallbacks**: Respect false values in enableZed/enableVSCode, use fallback path when XDG_CONFIG_HOME unset.
- **Pomodoro centering**: Properly centered in both compact and default sidebar modes.
- **Settings border color**: Replace undefined colLayer1Border with colLayer0Border.

## [2.11.1] - 2026-02-22

### Changed
- **Cheatsheet keybinds grouped by category**: Keybinds now display in separate cards per category (System, ii Shell, Window Management, etc.) with icon headers and count badges. Search still shows flat filtered results.
- **Periodic table responsive sizing**: Element tiles dynamically scale to fit the cheatsheet panel width (36–70px) instead of hardcoded 70px. No more horizontal scrolling required.
- **Quick Launch editor redesign**: Replaced bulky outlined text fields with compact pill-shaped inline fields. Single-row layout per shortcut with icon preview, hover effects, and animated delete button.
- **Displays settings moved to General**: Per-monitor bar/dock visibility controls moved from Interface to General settings page, always visible regardless of monitor count. Shows monitor name and resolution.

### Fixed
- **SDDM password characters blinking**: Password shape indicators no longer re-animate when typing new characters. Replaced integer Repeater model (which recreates all delegates) with ListModel (preserves existing delegates). Matches lockscreen behavior.
- **Cheatsheet style consistency**: Added angel and aurora style branches to keybind rows and periodic table cards for proper 5-style support.
- **SongRec music recognition**: Updated command from deprecated `audio-file-to-recognized-song` to `recognize -j` for compatibility with newer songrec versions.

## [2.11.0] - 2026-02-21

### Added
- **SDDM Pixel theme**: Material You login screen — session selector, cycling fail messages, wallpaper-synced colors. Auto-applied on fresh install.
- **Angel global style**: Fifth visual style (neo-brutalism glass) across all shell surfaces
- **Firefox MaterialFox theming**: Auto-generated Material You colors for Firefox via matugen template
- **Terminal theming: btop, lazygit, yazi**: 10 TUI tools now auto-theme with wallpaper colors (foot, kitty, alacritty, starship, fuzzel, pywalfox, btop, lazygit, yazi). Individual toggles in Settings.
- **Terminal color controls**: Saturation and brightness sliders for fine-tuning generated terminal colors
- **Overlay theming options**: Scrim dim, background opacity, and blur toggle in Settings
- **Waffle per-monitor wallpaper**: Full UI with monitor frame preview + thumbnail grid in Waffle settings

### Changed
- **Color pipeline centralized**: Matugen generates `colors.json` only; Python handles all app configs (GTK, KDE, terminals, Vesktop, Fuzzel) — consistent primary color across everything
- **Qt theming via plasma-integration**: Required dependency for Material You in Qt apps. Migration 011 auto-patches existing installs. New doctor check verifies it's working.
- **darkly → darkly-bin**: Pre-built binary on Arch saves ~5 min on fresh install
- **Setup TUI overhaul**: Consistent `log_*/tui_*` branding across Arch, Debian, and Fedora installers
- **GTK4 dark mode**: Template applies dark mode unconditionally
- **Dolphin integration**: SingleClick mode + "Open terminal here" context menu via kservicemenurc
- **quickshell-git conflict**: Installer handles existing `-git` package, prefers official repos; adds ffmpeg as dependency

### Fixed
- **Terminal colors not updating**: Root cause — venv activation failed in QML `execDetached` context when `ILLOGICAL_IMPULSE_VIRTUAL_ENV` was unset
- **SDDM Qt5 compatibility**: Full rewrite for SDDM's Qt5 runtime (model roles, easing curves, font loading)
- **Wallpaper theming**: Stop guessing thumbnails by basename, clear stale paths on video→image switch, kill previous switchwall before starting new
- **Video first-frame**: `seek(0)` after pause ensures frame display
- **Qt apps white on dark**: Fixed GTK4 CSS and terminal venv resolution for Nautilus and KDE apps
- **Waffle notifications**: Expand direction, calendar lag, animation cleanup
- **Pomodoro timer**: Timer editing no longer requires double-tap
- **Settings search**: Improved result relevance — dynamic registry results scored higher, section delimiter parsing unified
- **Capture windows**: No longer trashes clipboard during screenshot
- **Foot colors**: Switched to `inir-colors.ini`, removed stale `colors.ini` include
- **Matugen config**: Use user config at `~/.config/matugen/`, not non-existent defaults path
- **Config safety audit**: 34 fixes — unsafe writes→`setNestedValue()`, unsafe reads→safe defaults
- **Waffle video backdrop**: Show frozen first frame when animated wallpapers disabled (was showing nothing)
- **Fresh install**: 0-byte wallpaper recovery, version.json tracking, polkit auto-detection, env vars in all shells, conflict auto-disable, dynamic wallpaper selection

## [2.10.1] - 2026-02-13

### Added
- **Desktop right-click context menu**: Right-click on the desktop background opens a context menu with Mission Center, Overview/Task View, Settings, Wallpaper Selector, Terminal, Media Controls, Lock Screen, and Power Menu
- **Bar right-click context menu (ii family)**: Right-click on the horizontal or vertical bar opens a context menu with Mission Center and Settings
- **DesktopShellContextMenu component**: Reusable context menu widget for desktop backgrounds, respects all three global styles (Material, Aurora, iNiR)

### Changed
- **Bar context menu positioning**: Vertical bar popup opens toward screen center (right when bar is left, left when bar is right) following the dock pattern; horizontal bar popup opens above when bar is at bottom, below when at top
- **Desktop context menu close behavior**: Left-click on desktop closes the menu; right-click repositions it — avoids layer-shell backdrop conflict on Niri

## [2.10.0] - 2026-02-13

### Added
- **Multi-monitor wallpaper support**: Per-monitor wallpaper and backdrop paths via WallpaperListener service
- **Video first-frame system**: Automatic ffmpeg extraction and caching of first-frame JPGs for video wallpapers
- **Per-monitor aurora/glass**: Bar, dock, and sidebars use per-screen wallpaper for blur and color quantization
- **Wallpaper selector multi-monitor targeting**: Auto-detects focused monitor, opens on target screen, per-monitor selection
- **Per-monitor backdrop paths**: Each monitor can have its own backdrop wallpaper independent of global setting
- **Derive theme colors from backdrop**: New toggle in settings — all color generation sources (matugen, ColorQuantizer, aurora) switch to backdrop wallpaper when enabled
- **Card right-click swap**: Right-click on the front card toggles between main wallpaper and backdrop views
- **Backdrop card focus borders**: Selection border overlay when backdrop card is in front and selected
- **DockPreview toplevel reactivity**: Auto-close preview when app exits, update on toplevel changes
- **Per-monitor random wallpapers**: Random wallpaper scripts (konachan, osu) support focused monitor targeting

### Changed
- **Card clipping**: Parent-level `layer.enabled + OpacityMask` replaces per-image masking — all children (gradients, labels, badges) now properly clip to rounded corners
- **Card scaling quality**: `layer.smooth` on scaled cards for sharper text and badges when zoomed out
- **Video/GIF display**: Always load AnimatedImage for GIFs (frozen when animation disabled); replaced QtMultimedia Video with first-frame Image in previews
- **Color pipeline**: ColorQuantizer and effectiveWallpaperUrl return image-safe sources for videos (first-frame cache → config thumbnail → trigger generation)
- **switchwall.sh**: Per-monitor wallpaper changes skip global color regeneration; `--noswitch` reads current wallpaper from config
- **CryptoWidget**: Cache staleness check — only refresh if older than refreshInterval (default 300s)
- **WaffleConfig**: Use `Config.setNestedValue()` instead of direct property mutation

### Fixed
- **Black peaks on cards**: Gradient and label overlays no longer escape rounded corners (`clip:true` only clips rectangular)
- **Aurora colors for video wallpapers**: ColorQuantizer receives first-frame images instead of undecoded video URLs
- **Backdrop changes all monitors**: Per-monitor backdrop selection now only affects the selected monitor
- **White line above wallpaper path**: Removed hardcoded separator — `Layout.topMargin` provides sufficient spacing
- **Derive theme colors noop**: Toggle now wires through to Appearance.qml ColorQuantizer, Wallpapers.effectiveWallpaperPath, and switchwall.sh matugen source

## [2.9.1] - 2026-02-11

### Added
- **Weather location debouncing**: Wait 1.5 seconds after user finishes typing before triggering geocoding to reduce API calls
- **Weather geocoding improvements**: Smarter display name formatting (city, country) for manual location entries
- **Cliphist lazy image decode**: Only decode images when they become visible, reducing process spam
- **YtMusic dependency reporting**: Show exactly which dependencies are missing and how to install them

### Changed
- **GitHub templates**: Streamlined issue and PR templates for clarity and conciseness
- **Package dependencies**: Added missing required commands to doctor.sh and PKGBUILDs (python, xdg-utils, curl, git, swayidle, fuzzel, pacman-contrib, ddcutil, translate-shell)
- **PACKAGES.md documentation**: Synchronized with actual package requirements

### Fixed
- **Video wallpaper blur**: Blur effect now works correctly with video wallpapers (removed video guard clause)
- **Overlay pinned widgets**: Pinned widgets now display correctly when the overlay is closed
- **Clipboard self-trigger**: Prevented clipboard from refreshing when copying its own entries
- **YtMusic mpv-mpris**: Made mpv-mpris plugin optional so playback works without it
- **YtMusic cookie path**: Fixed path for cookie file used by mpv
- **Weather re-fetch**: Prevent duplicate location resolution on shell restart with manual coordinates

## [2.9.0] - 2026-02-11

### Added
- **Shell update overlay**: New layer-shell panel with commit log, changelog preview, and local modifications detection
- **Shell update details**: Click bar indicator to open detailed overlay instead of direct update
- **Weather manual location**: City name input, manual lat/lon coordinates, and GPS support via geoclue
- **Weather geocoding**: Forward geocoding (city → coords) and reverse geocoding (coords → display name) via Nominatim
- **Waffle themes redesign**: Theme cards with live color preview circles, quick-apply, inline rename, import/export
- **WWaffleStylePage options**: Start menu scale slider, clock format options, bar sizing controls (height, icon size, corner radius), desktop peek section
- **Waffle pages icon audit**: Replaced generic icons with descriptive FluentIcons across all settings pages
- **Ko-fi funding**: Added ko_fi to FUNDING.yml

### Changed
- **Waffle settings isolation**: Waffle family always opens its own Win11-style settings window, simplified IPC toggle logic
- **Win11 visual polish**: Redesigned waffle settings widgets with shadows, compact sizing, animated transitions using Looks.transition tokens
- **Weather priority**: Manual coords > manual city > GPS > IP auto-detect
- **ShellUpdates service**: Added overlay state management, manifest parsing, IPC handlers (toggle/open/close/check/update/dismiss)

### Fixed
- **Config schema sync**: Added 6 missing altSwitcher properties, enableAnimation for WaffleBackground, noVisualUi and taskView.closeOnSelect defaults
- **Settings bugs**: Fixed BarConfig layout property name, WaffleConfig bindings and spacing
- **YtMusic persistence**: Connection state and resolvedBrowserArg now persist across restarts
- **YtMusic cookies**: Always use --cookies-from-browser instead of intermediate cookie files, resolve Firefox fork profile paths
- **YtMusic debugging**: Added stderr capture and logging for mpv, converted shell commands to proper array-based Process commands
- **Waffle start menu overflow**: Added clip, Flickable wrapper, min/max height constraints, reduced recommended items from 6 to 4

## [2.8.2] - 2026-02-09

### Added
- **Dock screen filtering**: `screenList` config option for per-monitor dock control, matching bar behavior (thanks @ainia for the reminder)

### Fixed
- **Dock animations**: Resolved flickering during app launch and drag operations (PR #40 by @Legnatbird)

## [2.8.1] - 2026-02-08

### Added
- **Settings search**: Granular per-option search index with spotlight scroll-to navigation
- **Terminal detection**: Auto-detect installed terminals in color config section on first expand
- **Crypto cache**: Persist crypto widget prices and sparkline data across shell restarts
- **Notification options**: `ignoreAppTimeout` and `scaleOnHover` config properties

### Changed
- **Bar center layout**: Both center groups now share effective width so workspaces stay perfectly centered regardless of active utility button count
- **Screen cast toggle (PR #29)**: Simplified to always-interactive toggle with configurable output; removed monitor count detection overhead

### Fixed
- **Media player duplication**: Bottom overlay now uses `displayPlayers` with title/position dedup, matching bar popup behavior
- **Notification popup animations**: Differentiated popup vs sidebar behavior — popups use instant height changes to avoid Wayland resize stair-stepping, with height buffer and clip to prevent content overflow
- **Hardcoded animations**: Replaced raw `NumberAnimation`/`ColorAnimation` with `Appearance.animation` and `Looks.transition` design tokens across TimerIndicator, KeyboardKey, BarMediaPlayerItem, ThemePresetCard, TilingOverlay, and WidgetsContent
- **Screen cast settings**: Added null safety, `setNestedValue` for output field, synced defaults with Config.qml schema
- **Shell updates**: Prevented double repository search fallback when version.json exists but lacks `repo_path`

## [2.8.0] - 2026-02-04

### Added
- **Screen cast toggle**: Bar utility button for Niri screen casting with configurable output (PR #29 by @levpr1c)
- **System sounds volume control**: Configurable volume for timer, pomodoro, and battery notification sounds

### Changed
- **Video wallpapers**: Replaced mpvpaper with Qt Multimedia for native video wallpaper support

### Fixed
- **Terminal color theming**: Auto-fix for Alacritty v0.13+ import order requirement - colors now update correctly with wallpaper changes (Issue #30)
- **Package installation**: Replaced non-existent `matugen-bin` AUR package with `matugen` from official Arch repos (Issue #32)
- **Waffle background**: Added missing optional chaining in config access to prevent startup errors

## [2.7.0] - 2026-01-21

### Added
- **Bar module toggles**: Individual enable/disable options for bar modules (resources, media, workspaces, clock, utility buttons, battery, sidebar buttons)
- **Region search**: Google Lens action via IPC (`region.googleLens`)

### Changed
- **Media player pipeline**: Centralized filtering/deduping via `MprisController.displayPlayers` for consistent behavior across widgets
- **Cava visualizer**: Debounced process activation to avoid rapid stop/start loops

### Fixed
- **Shell performance**: Reduced stutter by rebuilding MPRIS player lists imperatively instead of hot bindings
- **Bar stability**: Null-safe config access for bar components to prevent startup `ReferenceError`
- **Darkly theme generation**: Adaptive clamping to prevent icons/colors from collapsing to pure black/white

## [2.6.0] - 2026-01-11

### Added
- **User modification detection**: Setup now detects user-modified files and preserves them during updates
- **Themes UI favorites**: Star your favorite color themes for quick access in settings
- **Quick Access section**: Combined favorites + recently used themes in compact grid
- **Temperature sensor support**: Extended hwmon detection for older hardware (k10temp, coretemp, etc.)
- **Control Panel**: New unified control panel with modular sections
- **Tiling Overlay**: Visual overlay for tiling operations
- **Tools tab**: New tools section in settings
- **GIF wallpaper support**: Native animated GIF wallpapers with performance optimizations
