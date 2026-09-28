# Panel Families

iNiR has three separate UI families that share the same service/config foundation. Switch between them at runtime with `Super+Shift+W`.

## Material ii

The default family. Material Design language with nine global styles that form a spectrum from structured to expressive.

### Styles

| Style | Character |
|-------|-----------|
| **material** | Clean Google-standard Material 3. Solid surfaces, standard elevation. The baseline. |
| **cards** | Material variant with a card-based layout. Same colors, different structure. |
| **aurora** | Professional glass transparency. Blur-backed surfaces, frosted panels. |
| **inir** | TUI-inspired elegance. Border and text hierarchy, muted tones, monospace accents. |
| **angel** | The flagship. Neo-brutalism meets glass. Offset shadows, partial borders, inset glow, warm golden palette. |
| **regalia** | Engineered luxury: dark structure, warm ivory, antique-gold and oxblood accents. |
| **zzz** | Zenless Zone Zero poster UI: wallpaper-generated signal colors, black console surfaces, technical grid frames, cut-corner plates, sticker badges, segmented metrics, halftone texture, and Oxanium type. |
| **cookie** | Material Expressive organic silhouettes, tonal plates and state morphing. |
| **editorial** | Paper-and-ink visual system with strong typographic hierarchy and restrained ornament. |

Style detection belongs to `Appearance.qml`. Prefer semantic tokens such as `Appearance.colors.*`, shared components, and the specific `Appearance.<style>Everywhere` flag when a style genuinely needs custom behavior. Do not reproduce a local style-priority chain: some capabilities deliberately overlap (for example Angel inherits Aurora glass/blur capability).

```qml
color: Appearance.colors.colLayer1
radius: Appearance.rounding.normal
```

### Layout

- **Bar**: top of screen (horizontal), or left/right edge (vertical). The horizontal bar is modular: left edge, two center-side zones, centered workspace pivot, right edge.
- **Sidebars**: left sidebar (AI chat, YT Music, widgets), right sidebar (toggles, calendar, tools)
- **Dock**: application dock (any of 4 edges)
- **Overview**: workspace overview with app launcher and search (`Super+Space`)
- **Settings**: shared page registry presented either as the shell overlay or the standalone `settings.qml` window, according to `settingsUi.overlayMode`

### Visual tokens

All ii components use `Appearance.*`:

```qml
color: Appearance.colors.colPrimary
radius: Appearance.rounding.normal
font.family: Appearance.font.main
```

Never hardcode colors, radii, or font sizes. The entire point of the token system is that switching styles, themes, or wallpapers changes everything at once.

### Panels

ii composition is split between `modules/ii/critical/ShellIiCriticalPanels.qml` and `modules/ii/ShellIiPanelsImpl.qml` (reached through the thin `ShellIiPanels.qml` wrapper). Some notable panel ids:

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
- **Settings**: Waffle-native standalone window by default; Waffle can be configured to reuse Material/shared Settings presentation

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

Waffle composition is split between `modules/waffle/critical/ShellWaffleCriticalPanels.qml` and `modules/waffle/ShellWafflePanelsImpl.qml` (reached through the thin `ShellWafflePanels.qml` wrapper):

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

## iRiS

iRiS is the Island family and the main new family in 2.31. It is built around one screen-edge chassis instead of a collection of unrelated floating windows. The resting Island can grow into pages and cards, pieces can move between the Island, screen contour and desktop, and the Dock can live on any edge.

### Layout and design

- **Island**: top, bottom, left or right. Side edges use a vertical compact form and opened content grows inward.
- **Full bar**: `iris.bar.layout = "full"` turns the Island edge into start/center/end zones for the Island, workspaces, focused window, time and pieces.
- **Pieces**: weather, notifications, sound, microphone, tools, media, tray and app bubbles can sit on the Island, attach to an edge owner or float on the desktop.
- **Dock**: top, bottom, left, right or `auto`; auto keeps it opposite the Island and both edge owners can trade places.
- **Palette / Spotlight**: keyboard-first apps, actions, clipboard and calculator surface.
- **Controls**: quick controls can live in the Island or open as their own body.
- **Studio**: live editor for appearance, motion, surfaces, layout and Themes.
- **Themes**: curated whole-family redesigns plus user themes stored as JSON in `~/.config/inir/iris/themes`.
- **Material**: iRiS glass uses the wallpaper below each body; Niri compositor blur is also available as an experimental material.
- **Visual owner**: `modules/iris/style/IrisStyle.qml`.
- **Desktop widgets**: the shared widget canvas gains iRiS faces, materials and controls instead of maintaining a separate persistence system.

iRiS composition is split between `modules/iris/critical/ShellIrisCriticalPanels.qml` and `modules/iris/ShellIrisPanelsImpl.qml` through `ShellIrisPanels.qml`. The chassis keeps the background and Island available first; heavier pages and transient surfaces are loaded on demand. See [iRiS](IRIS.md) for the user-facing family guide and `defaults/widgets/IRIS-SDK.md` for the extension API.

## Switching families

`Super+Shift+W` triggers a family transition with an animated overlay. The transition:

1. Overlay fades in
2. Current family panels unload
3. `panelFamily` config key changes
4. New family panels load
5. Overlay fades out

The transition is handled by `FamilyTransitionOverlay.qml`. Config persists the choice, so the next startup uses whichever family you last selected.

The shortcut only walks the families you want, in your order (`familyCycle`, all three by default). Pick them, and turn the animation off if you'd rather have a cut (`familyTransitionAnimation`), from any family: iRiS Settings > General > Shell family, Material's Modules page, or Waffle's Modules page.

Every family also arrives on its own when the shell starts, reloads or takes over from another one, instead of popping in: iRiS grows inward from just past the screen edges, Material's bar and dock slide in from their edge, Waffle's taskbar rises out of its edge, and desktop widgets settle in with them. With animations off, everything is simply there.

## Panel loading

All families use the same staged loading idea, but not every surface uses the same loader. Critical first-frame surfaces use `CriticalPanelLoader`; the implementation roots use `PanelLoader`, `DeferredPanelLoader`, and `OnDemandPanelLoader` according to lifecycle needs.

```qml
CriticalPanelLoader {
    identifier: "iiBackground"
    component: Background {}
}
```

The common conditions are:

1. **`Config.ready`** is true (config file loaded)
2. **Identifier in `enabledPanels`** (user hasn't disabled it)
3. **`extraCondition`** passes when the loader has one
4. **Lifecycle gate** is satisfied (`shellEntryReady`, `deferredPanelsReady`, or an on-demand `open`/resident state)

The critical host is deliberately tiny: ii starts background/bar/dock, Waffle starts taskbar/background/backdrop, and iRiS starts only background/bar. The heavier family tree becomes eligible after the first frame; many interactive surfaces stay unloaded until actually opened.

## For contributors

If you're adding a new panel:

1. Create the QML component in the appropriate module directory
2. Choose the correct owner: add only truly first-frame surfaces to the relevant `modules/*/critical/Shell*CriticalPanels.qml`; otherwise add the appropriate loader to `modules/*/Shell*PanelsImpl.qml`
3. Add the identifier to `enabledPanels` default in `defaults/config.json`
4. If it has settings, add them to the correct Settings UI

If your change affects multiple families, update every affected family. Shared component changes must be tested in each family that actually consumes that component.
