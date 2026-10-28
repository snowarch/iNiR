# Optimization

These settings trade some looks for speed, battery or game performance. Turn on only what your machine needs.

## Blur and glass

In **Settings › Effects › Glass**:

- **Default blur backend** picks how blur is drawn:
  - **Style default** keeps what your global style asks for.
  - **Wallpaper glass** blurs the wallpaper behind each surface.
  - **Compositor blur** lets Niri do the blur.
  - **Off** removes it.
- **Allow compositor blur** appears on Niri 26.04 or newer. Shapes Niri cannot blur fall back to the shell's own blur.
- **Settings › Effects › Areas** sets the backend for **Bars**, **Dock**, **Panels and popups**, **Islands and Ricelin** and **Desktop widgets**. Each one can **Inherit** the default or use any of the four backends.

**Waffle Settings › Effects** has the same options. In iRiS, **iRiS Settings › Windows › Glass behind apps** sets the blur behind apps and **iRiS Settings › Wallpaper › Behind windows** the wallpaper's.

## Motion and power

In **Settings › Effects › Motion**:

- **Reduce animations** turns off the shell's animations.
- **Low power effects** is the same switch as **iRiS Settings › Home › Performance › Low power**. In iRiS it turns glass, blur and heavy wallpaper effects off everywhere.
- **Notify when a restart would free memory** watches the shell's memory use and tells you when a restart would free some. It is off by default.

Waffle has both in **Waffle Settings › Effects › Motion and power**.

## Animated wallpapers

Video and GIF wallpapers cost more than still ones. In **Settings › Wallpaper › Screens**:

- **Enable animated wallpapers (videos/GIFs)**. When it is off, the wallpaper shows a still image instead.
- **Pause animated wallpapers on battery**.
- **Blur animated wallpapers (videos/GIFs)**. Blurring them costs more.

Waffle: **Waffle Settings › Background › Wallpaper Effects**. iRiS: **Animate on the desktop** in **iRiS Settings › Wallpaper › Live wallpapers**.

## Game Mode

Game Mode starts by itself when an app goes fullscreen, if **Automatically enable Game Mode when apps go fullscreen** is on. In **Settings › Quick › Game mode**, pick what it turns off:

- **Turn off UI animations when Game Mode is active**
- **Turn off blur and shadows when Game Mode is active**
- **Disable audio visualizers**: stops Cava and hides the visualizers.
- **Turn off compositor animations when Game Mode is active**
- **Stop discover-overlay while Game Mode is active**. It only appears when discover-overlay is installed.
- **Minimal mode**: makes panels transparent and hides backgrounds.
- **Suppress notifications**: hides notification popups.

**Waffle Settings › General › Game Mode** has most of the same switches. In iRiS, they are under **iRiS Settings › Gaming & Fullscreen › Game mode**.

## Audio spectrum

The bar spectrum only draws while audio plays. In **Settings › Bar › Audio spectrum**:

- **Primary only** (the default) draws it on the primary monitor.
- **All monitors** draws it on every monitor.

These options are greyed out unless the bar uses the **Pill** appearance, set in **Settings › Bar › Shape & position**.
