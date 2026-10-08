# iRiS

iRiS is iNiR's Island family. It uses the same Niri, services, wallpaper state and application models as the rest of iNiR, but owns a separate visual and interaction system through `IrisStyle`.

It first ships publicly in 2.31.0.

## The Island

The Island is the family's main edge object. It can rest on the top, bottom, left or right edge and grow inward into Media, Activity, Desktop, Tray and Tools pages.

```bash
inir iris edge top
inir iris edge left
inir iris page media
inir iris close
```

On a side edge, the resting Island becomes a vertical compact capsule with a stacked clock. The same page/content model is kept; only the edge geometry changes.

Set `iris.bar.layout` to `full` to turn that edge into a full-width/full-height bar. Its start, center and end zones can contain the live Island, workspaces, the focused window, time or any enabled piece:

```bash
inir iris layout full
inir iris zone start workspaces+window
inir iris zone center island
inir iris zone end tray+notifications+sound+controls
```

## Pieces and the Dock

Weather, notifications, controls, sound, microphone, tools, media, tray and app bubbles are pieces. A piece can:

- live in the Island;
- sit on a screen edge;
- join the Island or Dock when it shares their edge;
- float freely on the desktop.

The Dock supports all four edges. `auto` keeps it opposite the Island; explicitly moving one edge owner onto the other's edge swaps their positions instead of stacking them on top of each other.

Slide an icon along the Dock to move it. Drop it among the pinned apps and it stays pinned there. Open apps line up in the order you opened them; Settings, Dock, Apps decides whether a pinned app keeps its place while it's open or joins them.

```bash
inir iris dockMove firefox 2
inir iris dockEdge auto
inir iris dockEdge left
inir iris bubble weather edge:right:0.35
inir iris appBubble kitty top-right
```

Frame Music can shape and illuminate the chassis while audio plays. In Spotlight, type `/frame-music` to toggle it or `/edge-music` to switch to the Organic Edge visualizer; repeating the active command turns the visualizer off. Floating panels and Spotlight keep clearance from the moving frame and return to the resting contour when Frame Music is off.

## Themes, glass and Customize

iRiS Themes are whole-family redesigns, not just color palettes. 20 curated Themes ship with iNiR, and your own live as JSON files in:

```text
~/.config/inir/iris/themes
```

Customize happens on the shell itself. The Island grows a small capsule with Themes, Look, Pieces, undo and Done, and each of those opens as a sheet under it. Click the Island, the Dock or a bubble and its own options grow right out of it; drag the knob on a selected bubble to resize them all. No giant panel parked over half your screen. Right click the desktop and pick *Customize iRiS*, or:

```bash
inir iris edit on
inir iris edit themes
inir iris theme list
inir iris theme apply:liquid-glass
inir iris theme save:my-theme
```

Rather have one panel? Settings, Appearance, *Customize opens*, Studio puts every area in a column beside the screen with one search.

Wallpaper glass samples the wallpaper beneath iRiS surfaces and raises its tint where needed to keep text readable. Niri compositor blur can blur windows below a surface too, but it is intentionally marked experimental because moving/transient surfaces can still expose compositor artifacts.

## Light, Ink and Dark

*Scheme* in Appearance follows the system, or stays Dark, Light or Ink: washi and sumi, softer than white. Each has its own tone, colour strength and frost. The scheme is the system's mode, so your apps switch with it.

Colour themes give the shell and your apps one palette (Catppuccin, Nord, Rosé Pine, Tokyo Night, iRiS Ink and more) instead of the wallpaper's. *Match the shell* also hands iRiS the theme's accent and material.

```bash
inir iris set iris.appearance.scheme ink
inir colorMode set light
inir iris palette catppuccin-mocha
inir iris palette auto
```

## Menu bar and shape

Menu bar is a thin strip along the top or bottom with your workspaces, window and pieces; the Island hangs from it as a notch and grows into what it opens. The strip is clear over the wallpaper, its items turning dark over a light one, or sits on a band. Twilight, Daybreak and Lume use it.

Settings, Appearance, Shape sets the Island and the Dock to the capsule, Round, Squircle or Square.

```bash
inir iris layout menubar
inir iris strip transparent
inir iris strip band
```

## Anime colours

An optional colour layer paints the iRiS accent, and the highlight if you ask, in one of five curated anime palettes. It changes colour only: shape, content, the desktop and the other families stay as they are.

Open Customize, Look, Colour, or iRiS Settings, Anime:

- **Anime colour layer** turns it on and off. Off is the exact accent and highlight you configured.
- **Palette** picks Sakura, Neo Tokyo, Unit-01, Magical Girl or Spirit Forest.
- **Strength** blends from your own accent (0) to the palette (100).
- **Recolour the highlight** decides whether the highlight follows the palette too. Off keeps the highlight you configured, even when it is set to Accent.

The Themes sheet filters between All and Anime, and each card shows your own pieces where you put them. Sakura, Neo Tokyo, Unit-01, Magical Girl and Spirit Forest are whole redesigns; Magical Girl and Spirit Forest turn the layer on, the others leave it off. Airing stays a separate piece: turn it on under Anime, and its card tracks the shows you follow. Applying a theme never turns Airing on or off.

```bash
inir iris set iris.appearance.anime.enabled true
inir iris set iris.appearance.anime.palette neo-tokyo
inir iris set iris.appearance.anime.strength 70
inir iris set iris.appearance.anime.highlight true
inir iris set iris.appearance.anime.enabled false
```

## Watching anime

Continue is a piece for watching anime without opening a terminal. It needs `ani-cli` installed; iRiS is the interface and `ani-cli` does the finding.

- Turn it on under iRiS Settings, Anime, Continue. Without `ani-cli` the row says so.
- Its card has a search field. Pick the show, pick the episode, and it plays in mpv. The shows you watched are listed under it with their cover; tap one to pick up where you stopped, to the second.
- While an episode plays, the Island's player skips to the previous or next episode and turns subtitles on or off. When an episode ends, the card asks what next: next, again, previous, another episode, quality or done.
- Audio (subtitled or dubbed) and Quality are under the same section. `ani-cli` only offers English subtitles and dubs, so there is no language list to pick from.
- `jerry` and `curd` are recognised too, but only to list what you watched and resume it in their own terminal.

```bash
inir iris watch              # what is in progress
inir iris watch 1            # resume the first one
inir iris watch "frieren"    # resume it, or search when nothing matches
inir iris watchPick          # what the card is asking, and answer it
inir iris watchSkip next     # next episode while one plays
```

## Desktop widgets

iRiS reuses the shared desktop-widget canvas and persistence. It adds family-specific faces and materials rather than creating another widget system.

The iRiS widget gallery covers the everyday desktop set, including clock, weather, calendar/agenda, media, notes, todo, timers, battery, vitals, profile, world clock, uptime, Controls and Screen Time. Widgets can use iRiS glass/transparent/solid/tinted presentation and keep their placement across family changes.

One design covers every widget: iRiS faces, Material, iNstrument (gauges, scales and monospace captions drawn straight on the wallpaper) or Readout. Pick it in Settings › Desktop › Widgets or in a widget's Look controls; *Use on every widget* and *Match* put widgets that kept a look of their own back in line, and *Undo* returns the mix you had before. The Lume theme puts every widget in iNstrument.

While arranging, drop one widget on another to stack them: the stack keeps one place and shows one widget at a time, turning by itself every 20 seconds, with the mouse wheel or from the dots on its edge. In a widget's quick controls you pick the page, change the order, set how often it turns, take a widget out or split the stack. Stacks are for the iRiS design.

*Lume on every widget* (Settings › Desktop › Widgets) backs every widget's text as if the wallpaper under it were bright and busy, for wallpapers where you want it even when it isn't needed.

In Spotlight, `/` lists iRiS's own switches and picks: type a few letters (`/lume`, `/night`, `/design`) and flip them in place; each row says where it lives in Settings.

```bash
inir background widgetDesign instrument
inir background widgetDesign undo
inir background widgetDesign status
inir widgetStacks create weather+monthCalendar
inir widgetStacks status
```

## Wallpaper gallery

The iRiS wallpaper picker can browse the local library, Wallhaven and live anime scenery. It supports showcase, strip and wall layouts, pinned folders and one-at-a-time muted live previews.

```bash
inir wallpaperSelector browse library -
inir wallpaperSelector browse wallhaven mountains
inir wallpaperSelector browse live -
```

The normal wallpaper service still owns apply/preview state. iRiS does not keep a second wallpaper database.

Live wallpapers download in 4K when MotionBgs has a 4K file; its HD files are compressed hard enough to look soft even at 1080p. Settings, Desktop & Wallpaper, Wallpaper gallery, Live wallpaper downloads, Light, takes HD instead for machines that would rather not decode 4K.

## Settings

iRiS Settings is laid out like a phone or Mac settings app: sections in the sidebar, grouped by what they are about, each group a row with its current values, and back and forward that remember where you were (the mouse's side buttons, Alt+arrows, Ctrl+Up/Down between sections). Search finds any option by what it does or what it draws; Return opens the first result.

Besides everything iRiS draws, it carries the shared settings iRiS acts on: time format and language, notifications and quiet hours, alert sounds, night light, battery, game mode, screen timeouts, screenshots and recording (Japanese lookup and Anki included). They are the same settings Material and Waffle use; Niri (windows, keyboard and mouse, screen resolution and scale) has native iRiS pages; More Settings has the shared pages that still apply to iRiS (wallpaper engine, desktop widgets, monitors, autostart, services, tools).

General opens on you: your picture (tap it to pick a new one), a greeting and the desktop you're looking at. Modules you write with the iRiS SDK (`defaults/widgets/IRIS-SDK.md`) are turned on under Island, Desktop page, Your modules.

```bash
inir iris settings notifications
inir iris settings lock/security
```

## Editing and scripting

Edit pieces directly on the desktop:

```bash
inir iris edit on
inir iris arrange on
```

The Control Center arranges in place. Each control comes in the sizes it is drawn well at (a toggle is one cell or a wide card, a slider a tall capsule, a wide bar or the full width), and the library beside the panel adds controls, applies layouts and sets columns, shape and width:

```bash
inir iris control edit
inir iris control tab:layouts
inir iris control compact
inir iris control undo
```

The lock screen opens as a rehearsal: the real surface, editable, with no PAM behind it. Its first page holds four layouts that move the blocks and change the clock without touching the picture behind them. Tap a widget on it to give it a design, material, corners and opacity of its own on the lock; the desktop keeps its look.

```bash
inir iris lock edit
inir iris lock page:layouts
inir iris lock centered
inir iris lock select:screenTime/look
```

Scripts can publish progress into the Island as live activities:

```bash
inir iris activity start build "Building"
inir iris activity progress build 42%
inir iris activity end build "Done"
```

For the complete command surface, see [IPC](IPC.md#iris).

## Runtime model

iRiS keeps the background and chassis available early, then loads expensive pages and transient surfaces on demand. The family reuses iNiR services for Niri windows/workspaces, media, tray, notifications, widgets and system controls. Closing a page or panel can keep a short warm cache to avoid rebuilding it during normal back-and-forth navigation.

This is why feature cost depends heavily on what is enabled and open. The base family is not supposed to keep every Settings preview, page, floating bubble and Control Center body resident just because iRiS is selected. Anything that moves behind your windows stops when it can't be seen: a live wallpaper and the edge wave hold still once tiled windows fill the screen or something goes fullscreen (Desktop & Wallpaper, Live wallpapers, Pause).
