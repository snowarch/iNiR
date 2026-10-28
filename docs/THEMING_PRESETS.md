# Colours and themes

By default the shell and the apps you switch on take their colours from your wallpaper. You can also pick a colour theme, build your own, and choose which apps follow along.

## Colours from the wallpaper

- **Settings › Quick › Wallpaper & Colors** has **Light** and **Dark** buttons, and **Wallpaper color strength (%)**, which sets how vivid the accents are.
- **Settings › Themes › Colors › Scheme Variant** sets how the palette is built: Auto (the default), Content, Expressive, Fidelity, Fruit Salad, Monochrome, Neutral, Rainbow or Tonal Spot.
- **Colour family**: **Around the accent** keeps the second and third colours close to the accent. **As generated** uses the scheme's own colours.
- **Auto light/dark from wallpaper** picks light or dark from each wallpaper's brightness. Pressing Light or Dark by hand turns it off.
- **Colors only** (Quick page) takes the colours from a thumbnail and keeps the wallpaper. **Derive theme colors from backdrop** (Wallpaper › Effects › Backdrop) takes them from the backdrop instead.

## Colour themes

**Settings › Themes › Colors › Color Themes** lists the themes, starting with **Auto (Wallpaper)**. Search, filter by tag (Pastel, Retro, Neon and others), or use the favourites and recent themes at the top. The 48 presets include Catppuccin, Gruvbox, Nord, Dracula, Tokyo Night, Rosé Pine, Everforest, Solarized, Monokai and Kanagawa, plus iNiR's own Angel, Regalia and iRiS Ink.

Some themes also change the corner rounding or the font style.

- **Soften colors (less intense)** tones the palette down.
- **Invert colors (complementary)** rotates every colour 180°. Only the shell changes. Terminals and other apps keep theirs.

## Custom themes

**Settings › Themes › Advanced › Custom Theme Editor** starts from a base preset. Adjust saturation, brightness and temperature, pick a colour harmony (Complementary, Analogous, Triadic or Split), then press **Apply**.

Name the theme and press Enter to save it. Saved themes appear under **Themes › Colors › Saved themes**. **Export** and **Import** copy a theme through the clipboard.

Light mode in the editor is experimental. For the best results, start from Angel Light, Catppuccin Latte or Sakura.

## Light and dark

The **Light** and **Dark** buttons switch the shell and the apps between the two. **Theme Scheduling** (Settings › Themes › Motion) switches between a day and a night theme at set times, 06:00 and 18:00 by default.

## Terminals and apps

**Settings › Themes › Advanced › Terminal Colors** chooses which terminals and tools follow the theme: kitty, alacritty, foot, WezTerm, Ghostty, Konsole, Starship, btop, lazygit and yazi. It also sets colour saturation, brightness and harmony. **Apply to open terminals** repaints windows that are already open.

**Settings › Advanced › Color generation** switches each app on or off:

- **Shell & utilities** (on): GTK apps, fuzzel, the login screen and other utilities. Qt apps and terminals need it.
- **Qt apps** (on): Qt and KDE apps.
- **Terminal** (on): terminal colour schemes.
- **Vesktop/Discord** (on): needs Vesktop with the system24 theme.
- **Spotify (Spicetify)** (on): pick the layout under **Spotify theme**.
- **Steam (Millennium)** and **Pear Desktop (YouTube Music)** (on).
- **VSCode editors** and **Zed editor** (on). **Neovim / LazyVim** (off).
- **Chrome / Chromium** (on): Chromium browsers, Brave included. A system-wide install asks for your password once.
- **Firefox** (on): Firefox, LibreWolf, Floorp, Waterfox and Zen. They follow the wallpaper from their next launch.
- **Theme standalone Cava** (on): the audio visualiser.
- **LiMusic**, **Claude Code** and **OpenCode** (off).

Turning Chrome or Firefox off gives their colours back.

## iRiS

**iRiS Settings › Style › Material** sets the colour style (iRiS, Washi or Material You) and what every surface is made of: Black, Graphite or Midnight, or Wallpaper or Theme. The three dark names change in the light and paper styles.

**Match the shell** makes the shell take the theme's accent, highlight and material too. It shows once a colour theme is picked.

The colour theme itself, **Softer colours** and **A theme for each** (one by day, one at night) are in iRiS's **Customize › Material**. Which apps and terminals follow along is **iRiS Settings › Style › App colours**.

## Waffle

**Waffle Settings › Themes** has the same pieces: **Appearance** (light or dark, the palette type, colour strength, softer or inverted colours), **Theming** (which apps follow) and **Terminal Colors**.
