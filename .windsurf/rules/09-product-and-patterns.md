---
trigger: model_decision
description: Pull when you need product-level understanding, family differences, settings architecture, external dependency expectations, or cross-cutting implementation patterns.
---

# iNiR Product Concept, Waffle Family & Cross-cutting Patterns

## Product Identity

**What**: Linux desktop shell for Niri (scrolling tiling WM) and Hyprland. Treat **iNiR** as the product identity; upstream origin is illogical-impulse.
**Stack**: Quickshell (QML-based Wayland shell framework), Qt6, Python.
**Users**: Daily driver Linux desktop users who want a polished, opinionated, feature-rich shell.
**Philosophy**: Usability-first. Material Design 3 colors from wallpaper. Familiar keybinds (Windows/GNOME style). Opinionated defaults. Everything configurable.
**Inspirations**: osu!lazer, Windows 11, Material Design 3, AvdanOS.
**Version**: follow the `VERSION` file. User config path remains `~/.config/illogical-impulse/config.json` (legacy namespace from fork origin).

## Panel Family Architecture

Two mutually exclusive families loaded via LazyLoader in shell.qml:

### ii Family (Material Design)
Active when `panelFamily !== "waffle"`. 24 panels. Uses `Appearance.*` tokens.
Panels: iiBar, iiBackground, iiBackdrop, iiCheatsheet, iiControlPanel, iiDock, iiLock, iiMediaControls, iiNotificationPopup, iiOnScreenDisplay, iiOnScreenKeyboard, iiOverlay, iiOverview, iiPolkit, iiRegionSelector, iiScreenCorners, iiSessionScreen, iiSidebarLeft, iiSidebarRight, iiTilingOverlay, iiVerticalBar, iiWallpaperSelector, iiCoverflowSelector, iiClipboard.

### waffle Family (Windows 11)
Active when `panelFamily === "waffle"`. Uses `Looks.*` tokens for visuals.
Own panels: wBar, wBackground, wBackdrop, wStartMenu, wActionCenter, wNotificationCenter, wNotificationPopup, wOnScreenDisplay, wWidgets, wLock, wPolkit, wSessionScreen.
Shared ii panels: iiCheatsheet, iiControlPanel, iiLock, iiOnScreenKeyboard, iiOverlay, iiOverview, iiPolkit, iiRegionSelector, iiScreenCorners, iiSessionScreen, iiTilingOverlay, iiWallpaperSelector, iiCoverflowSelector, iiClipboard.
Always loaded: wAltSwitcher, wClipboard (when waffle active).

### Family Switching
`shell.qml → cyclePanelFamily()` or `setPanelFamily(family)`.
Animated via `FamilyTransitionOverlay` (slide direction based on ii→waffle=left, waffle→ii=right).
Mid-animation: `applyPendingFamily()` writes config. Panels swap. `finishFamilyTransition()`.
Instant if `familyTransitionAnimation` config is false.

### Looks.qml (Waffle Theming)
Singleton with own color/font/radius/transition system.

### Key waffle↔ii Differences

| Aspect | ii | waffle |
|--------|-----|--------|
| Theming singleton | `Appearance` | `Looks` (maps to Appearance when useMaterial=true) |
| Bar position | Top (or vertical) | Bottom (Win11 taskbar) |
| Start menu | Overview | WaffleStartMenu with search |
| Right sidebar | SidebarRight | ActionCenter + NotificationCenter (separate) |
| Panel mutual exclusion | None (except overlay) | Waffle panels auto-close others |
| Settings | Material overlay/window | Win11-style separate window (waffleSettings.qml) |
| Alt-tab | AltSwitcher | WaffleAltSwitcher |
| Clipboard | ClipboardPanel | WaffleClipboard |

## PanelLoader Pattern

Every panel uses this lazy-loading gate:
```qml
component PanelLoader: LazyLoader {
    required property string identifier
    property bool extraCondition: true
    active: Config.ready && (Config.options?.enabledPanels ?? []).includes(identifier) && extraCondition
}
```
Loads when ALL true: Config.ready + identifier in enabledPanels array + extraCondition.
Users can disable panels by removing identifiers from enabledPanels.
New panels auto-added via `migrateEnabledPanels()` on startup.

## Settings System

Settings open via launcher/IPC `inir settings open`:
- ii + overlayMode → inline SettingsOverlay panel
- ii + window mode (default) → separate `qs -n -p settings.qml` process
- waffle → separate `qs -n -p waffleSettings.qml` process (Win11-style)

### SettingsSearchRegistry
Global singleton that indexes all ConfigSwitch/ConfigSpinBox/CollapsibleSection controls.

## Cross-cutting Patterns

### Null Safety — EVERY config/service access
```qml
Config.options?.bar?.autoHide?.enable ?? false
NiriService.windows ?? []
Audio.volume ?? 0
```

### Debounce Pattern
```qml
Timer { id: debounce; interval: 300; onTriggered: doWork() }
function onInput(): void { debounce.restart() }
```

### Visibility Guard on Timers
```qml
Timer { interval: 5000; repeat: true; running: root.visible && !root.isLoading }
```

### Error Handling
```qml
try { data = JSON.parse(str) } catch (e) { console.error("[Module]", e); data = [] }
```
