# Panel Families

iNiR has two completely separate UI families that share the same services and config backend. Switch between them at runtime with `Super+Shift+W`.

## Material ii

The default family. Material Design language with five style variants that form a spectrum from structured to expressive.

### Styles

| Style | Character |
|-------|-----------|
| **material** | Clean Google-standard Material 3. Solid surfaces, standard elevation. The baseline. |
| **cards** | Material variant with a card-based layout. Same colors, different structure. |
| **aurora** | Professional glass transparency. Blur-backed surfaces, frosted panels. |
| **inir** | TUI-inspired elegance. Border and text hierarchy, muted tones, monospace accents. |
| **angel** | The flagship. Neo-brutalism meets glass. Offset shadows, partial borders, inset glow, warm golden palette. |

Style dispatch priority: **angel > inir > aurora > material**. This means if you're checking which style to apply, check angel first:

```qml
color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
     : Appearance.inirEverywhere ? Appearance.inir.colLayer1
     : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
     : Appearance.colors.colLayer1
```

### Layout

- **Bar**: top of screen (horizontal), or left/right edge (vertical). The horizontal bar is modular: left edge, two center-side zones, centered workspace pivot, right edge.
- **Sidebars**: left sidebar (AI chat, YT Music, widgets), right sidebar (toggles, calendar, tools)
- **Dock**: application dock (any of 4 edges)
- **Overview**: workspace overview with app launcher and search (`Super+Space`)
- **Settings**: overlay panel rendered on top of the current desktop

### Visual tokens

All ii components use `Appearance.*`:

```qml
color: Appearance.colors.colPrimary
radius: Appearance.rounding.normal
font.family: Appearance.font.main
```

Never hardcode colors, radii, or font sizes. The entire point of the token system is that switching styles, themes, or wallpapers changes everything at once.

### Panels

ii loads about 25 panels through `ShellIiPanels.qml`. Some notable ones:

| Panel ID | What it is |
|----------|-----------|
| `iiBar` | Top bar (horizontal mode) |
| `iiVerticalBar` | Side bar (vertical mode) |
| `iiDock` | Application dock |
| `iiSidebarLeft` | Left sidebar (AI, music, widgets) |
| `iiSidebarRight` | Right sidebar (toggles, calendar, system) |
| `iiOverview` | Workspace overview + app search |
| `iiBackground` | Desktop wallpaper layer |
| `iiMediaControls` | MPRIS media player popup |
| `iiClipboard` | Clipboard history browser |

### Bar zones

The ii horizontal bar uses five zones:

| Zone | Role |
|------|------|
| `left` | Left edge controls, usually sidebar button + active window/taskbar |
| `centerLeft` | Left center pill, usually resources/media |
| `center` | Pivot, normally workspaces |
| `centerRight` | Right center pill, usually clock/util/battery |
| `right` | Right edge controls, usually sidebar button/tray/timer/update/weather |

Change it from Settings -> Bar -> Bar module layout. Do not hand-edit unless you enjoy typo archaeology.

## Waffle

Windows 11 Fluent Design. Not "ii with a different skin" but a completely separate family with its own design language, interaction patterns, and density.

### Layout

- **Taskbar**: bottom of screen (Windows 11 style)
- **Start Menu**: app grid with search, pinned apps, recent files
- **Action Center**: quick settings (WiFi, Bluetooth, volume, brightness, toggles)
- **Screen Time**: optional entry in Action Center when usage tracking is enabled
- **Notification Center**: notification list with calendar
- **Settings**: standalone window (separate from ii settings)

### Visual tokens

Waffle uses `Looks.*` exclusively. Never `Appearance.*` in waffle code:

```qml
color: Looks.colors.accent
radius: Looks.rounding.medium
font.family: Looks.font.fontFamily
```

### Design differences from ii

| Aspect | ii | waffle |
|--------|-----|--------|
| Density | Spacious Material spacing | Dense Win11 information density |
| Motion | Organic, 200-500ms durations | Snappy and mechanical, 67-250ms |
| Surfaces | Layered elevation (5 layers) | 3-tier chrome (bg0/bg1/bg2) |
| Controls | Material ripple, elevation | Flat with subtle hover reveals |
| Typography | 6 font families, expressive | Single family, pragmatic sizing |

### Panels

Waffle loads about 22 panels through `ShellWafflePanels.qml`:

| Panel ID | What it is |
|----------|-----------|
| `wBar` | Bottom taskbar |
| `wStartMenu` | Start menu |
| `wActionCenter` | Quick settings panel |
| `wNotificationCenter` | Notification center + calendar |
| `wTaskView` | Task view (workspace overview) |
| `wWidgets` | Desktop widgets panel |
| `wBackground` | Desktop wallpaper layer |

Some panels are shared between families (cheatsheet, region selector, on-screen keyboard, screen corners) and keep their `ii` prefix even when running under waffle.

## Switching families

`Super+Shift+W` triggers a family transition with an animated overlay. The transition:

1. Overlay fades in
2. Current family panels unload
3. `panelFamily` config key changes
4. New family panels load
5. Overlay fades out

The transition is handled by `FamilyTransitionOverlay.qml`. Config persists the choice, so the next startup uses whichever family you last selected.

## Panel loading

Both families use the same loading system. Each panel is a `PanelLoader`:

```qml
PanelLoader {
    identifier: "iiBar"
    extraCondition: !(Config.options?.bar?.vertical ?? false)
    component: Bar {}
}
```

Three conditions must all be true for a panel to load:

1. **`Config.ready`** is true (config file loaded)
2. **Identifier in `enabledPanels`** (user hasn't disabled it)
3. **`extraCondition`** passes (panel-specific logic)

Panels are split into immediate (bar, background, OSD) and deferred (sidebars, overview, clipboard). Deferred panels load 500ms after the first frame to keep startup fast.

## For contributors

If you're adding a new panel:

1. Create the QML component in the appropriate module directory
2. Add a `PanelLoader` entry in `ShellIiPanels.qml` or `ShellWafflePanels.qml`
3. Add the identifier to `enabledPanels` default in `defaults/config.json`
4. If it has settings, add them to the correct Settings UI

If your change affects both families, update both. If your change touches a shared component (notifications, lock screen, polkit), test under both families.
