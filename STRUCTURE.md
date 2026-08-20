# Codebase Structure

## Directory Layout

```
inir/
├── shell.qml                     # Root entry — loads services, selects panel family
├── ShellIiPanels.qml             # Material Design panel family
├── ShellWafflePanels.qml         # Windows 11 panel family
├── GlobalStates.qml              # Runtime UI state (panel open/closed booleans)
├── FamilyTransitionOverlay.qml   # Animated family switch
├── settings.qml                  # Settings GUI (separate Quickshell config)
├── waffleSettings.qml            # Waffle-specific settings GUI
├── welcome.qml                   # First-run wizard
├── killDialog.qml                # Process kill confirmation
├── modules/                      # UI module directories
│   ├── common/                   # Shared infrastructure
│   │   ├── Appearance.qml        # ii visual tokens
│   │   ├── Config.qml            # Central config (JsonAdapter)
│   │   └── widgets/              # Reusable widgets + qmldir
│   ├── bar/                      # Top bar (ii family)
│   ├── barM3/                    # Material 3 bar — independent layout model, bar.appearanceStyle "m3"
│   ├── background/               # Wallpaper backdrop + desktop widgets + desktop items
│   ├── sidebarLeft/              # AI chat, YT Music, widgets
│   ├── sidebarRight/             # Toggles, calendar, tools
│   ├── settings/                 # All config UI pages
│   ├── dock/                     # App dock (all 4 positions)
│   ├── overview/                 # Workspace overview + app search
│   ├── wallpaperLauncher/        # Shared compact wallpaper carousel
│   ├── waffle/                   # Windows 11 family
│   │   ├── bar/                  # Bottom taskbar
│   │   ├── startMenu/            # Start menu with search
│   │   ├── actionCenter/         # Quick settings
│   │   ├── notificationCenter/   # Notification list + calendar
│   │   ├── looks/Looks.qml       # Waffle visual tokens
│   │   └── [13 more subdirs]
│   ├── ii/                       # ii-family overlay and sidebarRight components
│   │   ├── overlay/
│   │   └── sidebarRight/
│   └── [more modules]
├── services/                     # Runtime singletons (+ services/deferred/)
│   ├── qmldir                    # Service module registration
│   ├── Audio.qml                 # PipeWire volume, mute, per-app mixer
│   ├── NiriService.qml           # Niri compositor IPC
│   ├── CompositorService.qml     # Compositor detection (Niri vs Hyprland)
│   ├── Network.qml               # NetworkManager integration
│   ├── Weather.qml               # Weather polling + privacy-aware location
│   ├── BluetoothStatus.qml       # BlueZ device management
│   ├── Translation.qml           # i18n string lookup
│   ├── DevNavigation.qml         # Session-only semantic UI navigation + dev IPC
│   ├── DesktopItems.qml          # Desktop item persistence + undo (desktop-items.json)
│   ├── DesktopWidgetLayout.qml   # Per-output widget layout (background.widgets.outputOverrides)
│   ├── LyricsService.qml         # Synchronized lyrics for media controls
│   └── [more services]
├── scripts/                      # Shell/fish/python helpers
│   ├── inir                      # CLI launcher (bash, IPC + lifecycle commands)
│   ├── colors/                   # Color generation pipeline
│   │   ├── applycolor.sh         # Orchestrator
│   │   ├── generate_colors_material.py  # Material You color generation
│   │   ├── modules/              # Per-app theming (terminals, GTK, etc.)
│   │   └── lib/                  # Shared infrastructure
│   └── [more scripts]
├── sdata/                        # Install/update lifecycle
│   ├── lib/                      # Shared bash libraries
│   ├── migrations/               # Numbered scripts
│   ├── subcmd-install/           # Install phases
│   └── subcmd-uninstall/         # Uninstall phases
├── defaults/                     # Shipped defaults
│   ├── config.json               # Default config
│   ├── niri/                     # Niri config templates
│   └── [GTK, KDE, fuzzel, etc.]
├── translations/                 # i18n strings (15 languages)
├── distro/arch/                  # Arch PKGBUILDs (dependency manifests)
├── assets/                       # Icons, wallpapers, systemd unit, desktop entry
├── docs/                         # User documentation
└── wiki/                         # Wiki documentation
```

## Directory Purposes

**modules/:**
- Purpose: All UI module directories organized by panel family and feature area
- Contains: QML components, qmldir registration files, subdirectories per feature
- Key files: `modules/common/Config.qml`, `modules/common/Appearance.qml`, `modules/common/widgets/qmldir`

**modules/common/:**
- Purpose: Shared infrastructure used across both panel families
- Contains: Visual token definitions (Appearance.qml), config schema (Config.qml), reusable widget library (widgets/)
- Key files: `modules/common/Config.qml`, `modules/common/Appearance.qml`, `modules/common/widgets/qmldir`

**modules/waffle/:**
- Purpose: Windows 11-style panel family components
- Contains: Bottom taskbar, start menu, action center, notification center, visual tokens (Looks.qml), settings pages
- Key files: `modules/waffle/looks/Looks.qml`, `modules/waffle/bar/WaffleBar.qml`, `modules/waffle/settings/WSettingsContent.qml`

**modules/ii/:**
- Purpose: ii-family-specific overlay and sidebarRight components
- Contains: Overlay system (crosshair, discord, floatingImage, fpsLimiter, notes, recorder, volumeMixer), sidebarRight integration
- Key files: `modules/ii/overlay/Overlay.qml`, `modules/ii/sidebarRight/`

**modules/background/:**
- Purpose: Per-output desktop surface rendering the wallpaper and hosting desktop widgets and desktop items
- Contains: Background render surface (Background.qml), desktop items (desktopItems/), widget instances (widgets/)
- Key files: `modules/background/Background.qml`, `modules/background/desktopItems/DesktopItemDelegate.qml`, `modules/background/widgets/WidgetManagerPanel.qml`

**modules/barM3/:**
- Purpose: Separate Material 3 bar implementation selected by `bar.appearanceStyle === "m3"`
- Contains: M3Bar.qml and its own widget components; the layout contract lives under `bar.m3` in Config
- Key files: `modules/barM3/M3Bar.qml`, `modules/barM3/M3Palette.qml`

**services/:**
- Purpose: Runtime singletons providing backend functionality (audio, network, compositor IPC, theming, etc.)
- Contains: QML singleton services, qmldir for module registration, deferred/ subdirectory for lazy-loaded services
- Key files: `services/qmldir`, `services/DevNavigation.qml`, `services/GlobalActions.qml`

**scripts/:**
- Purpose: Shell/fish/python helper scripts for theming, CLI, and automation
- Contains: CLI launcher (`inir`), color generation pipeline (`colors/`), utility scripts
- Key files: `scripts/inir` (CLI launcher), `scripts/colors/applycolor.sh` (orchestrator)

**sdata/:**
- Purpose: Install/update lifecycle scripts and migration history
- Contains: Shared bash libraries (lib/), numbered migration scripts (migrations/), install/uninstall subcommands
- Key files: `sdata/migrations/` (numbered scripts), `sdata/lib/` (shared libraries)

**defaults/:**
- Purpose: Shipped default configuration files
- Contains: config.json (default config), niri/ (Niri config templates), GTK/KDE/fuzzel/ etc. templates
- Key files: `defaults/config.json`

**translations/:**
- Purpose: i18n string files for all supported languages
- Contains: JSON translation files (ar_SA, de_DE, en_US, es_AR, fr_FR, he_HE, hi_IN, it_IT, ja_JP, ko_KR, pt_BR, ru_RU, uk_UA, vi_VN, zh_CN)
- Key files: `translations/en_US.json`

**distro/arch/:**
- Purpose: Arch Linux packaging files (PKGBUILDs and dependency manifests)
- Contains: inir-shell, inir-shell-git, inir-meta PKGBUILDs
- Key files: `distro/arch/inir-shell/PKGBUILD`, `distro/arch/inir-shell-git/PKGBUILD`

**assets/:**
- Purpose: Static assets (icons, wallpapers, systemd units, desktop entries)
- Contains: applications/, icons/, images/, systemd/, wallpapers/

**docs/:**
- Purpose: User-facing documentation (IPC, packages, setup, etc.)
- Contains: Markdown documentation files

**wiki/:**
- Purpose: Internal wiki documentation (architecture, modules, compositors, etc.)
- Contains: Categorized documentation pages and assets

## Key File Locations

**Entry Points:**
- `shell.qml`: Root entry — loads services, selects panel family, triggers panel loading
- `ShellIiPanels.qml`: Material Design panel family loader
- `ShellWafflePanels.qml`: Windows 11 panel family loader
- `settings.qml`: Settings GUI (separate Quickshell config)
- `welcome.qml`: First-run wizard

**Configuration:**
- `modules/common/Config.qml`: Config schema (JsonAdapter, typed QML properties)
- `defaults/config.json`: Default config values
- `Config.options.path.to.key`: Read config values in QML
- `Config.setNestedValue("path.to.key", value)`: Write config values from QML

**Core Logic:**
- `modules/common/Appearance.qml`: ii visual tokens and style dispatch
- `modules/waffle/looks/Looks.qml`: Waffle visual tokens
- `services/DevNavigation.qml`: Session-only semantic UI navigation + dev IPC
- `services/GlobalActions.qml`: Global keybind and action handling
- `services/CompositorService.qml`: Compositor detection (Niri vs Hyprland)

**Tests:**
- `scripts/test-local-distribution.sh`: Local distribution test script
- Co-located test files are not present in this repo

## Naming Conventions

**Files:**
- QML components: `PascalCase.qml` (e.g., `BarTaskbar.qml`, `WaffleActionCenter.qml`)
- Services: `PascalCase.qml` (e.g., `Audio.qml`, `NiriService.qml`)
- Scripts: `snake_case.sh` or `snake_case.py` (e.g., `applycolor.sh`, `generate_colors_material.py`)
- Config JSON: `config.json`
- Translation files: `ll_CC.json` (e.g., `en_US.json`, `de_DE.json`)

**Directories:**
- Module directories: `snake_case` (e.g., `sidebarLeft/`, `actionCenter/`)
- Widget subdirectories: `snake_case` (e.g., `widgets/`, `tasks/`)
- Settings pages: `W` prefix + PascalCase (e.g., `WAboutPage.qml`, `WBackgroundPage.qml`)

## Where to Add New Code

**New QML component:** `modules/common/widgets/` for shared widgets, `modules/[module-name]/` for module-specific components
**New service:** `services/` as a top-level `PascalCase.qml` singleton, register in `services/qmldir`
**New module directory:** Scaffold and register it through the owning family loader and Config contract
**New script:** `scripts/[category]/` following existing category conventions (colors/, inir/, lib/, etc.)
**New migration:** `sdata/migrations/` with next sequential number (check `ls sdata/migrations/` for current maximum)
**New config key:** Update `modules/common/Config.qml`, consumers, and every owning Settings family; use `defaults/config.json` only for curated fresh-install preferences
**New translation:** Wrap a literal in `Translation.tr(...)`, then synchronize and audit every locale catalog
**New waffle subdir:** `modules/waffle/[subdir]/` following existing waffle subdir patterns
**New ii-family component:** `modules/ii/[subdir]/` for overlay or sidebarRight additions
**New desktop widget:** `modules/background/widgets/[name]/` — declare a `background.widgets.<name>` key in `modules/common/Config.qml` and expose it in both Settings families
**New M3 bar widget:** `modules/barM3/<Name>.qml` — reference it from the `bar.m3` layout lists in `modules/common/Config.qml`
