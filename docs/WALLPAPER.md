# Wallpaper System

Pick a wallpaper and the entire desktop follows. Colors propagate to the shell, GTK apps, terminals, Firefox, Discord, VS Code, and the SDDM login screen.

## Setting a wallpaper

**From the shell**: open the wallpaper selector (`Super+W` or through Settings) and browse your filesystem. Click a wallpaper to apply it. The color pipeline runs automatically.

**From the CLI**:

```bash
inir wallpapers set /path/to/image.jpg
```

**From Settings**: Appearance section lets you configure wallpaper behavior, blur, and auto-cycling.

## What happens when you set a wallpaper

```
Image selected
  |
switchwall.sh (orchestrator)
  |
generate_colors_material.py
  - Extracts dominant colors from the image
  - Generates a full Material 3 palette (50+ color tokens)
  - Writes colors.json
  |
applycolor.sh (runs per-app theming modules in parallel)
  - GTK 3/4 themes
  - Terminal configs (foot, kitty, alacritty)
  - Starship prompt
  - Fuzzel launcher
  - Firefox (pywalfox)
  - VS Code, Cursor, OpenCode (Go generators)
  - btop, lazygit, yazi
  - SDDM login theme
  - Discord/Vesktop
  |
MaterialThemeLoader (QML, watches colors.json)
  |
Appearance tokens update --> Every UI component re-renders
```

The whole pipeline takes 2-3 seconds. The shell updates immediately when colors.json changes. External apps update within a few seconds as their configs are rewritten.

## Supported formats

**Images**: jpg, jpeg, png, webp, avif, gif, bmp, tiff, jxl

**Video**: mp4, webm, mkv, avi, mov. The first frame is extracted for color generation. Video plays as a live wallpaper with optional blur.

## Multi-monitor

Each monitor can have its own wallpaper. Configure per-monitor wallpapers in Settings under Appearance > Background > Multi-monitor.

Per-monitor config includes:
- Wallpaper path
- Optional workspace range (for Niri's scrolling workspaces)
- Optional backdrop path (for glass blur effects in Aurora/Angel styles)

## Video wallpapers

Video files play as live wallpapers. First frame is automatically extracted and cached at `~/.cache/quickshell/video_thumbnails/` for color generation and thumbnail display.

Options:
- **Blur**: apply blur to the video
- **Freeze frame**: show only the first frame (saves GPU)
- **Loop**: video loops continuously

## Backdrop system

The Aurora and Angel styles use frosted glass effects. The "backdrop" is a separate wallpaper (or the main wallpaper with heavy blur) that renders behind glass surfaces. This lets you have a sharp wallpaper on the desktop and a blurred version showing through transparent panels.

## Auto-cycling

Set an interval and iNiR cycles through wallpapers in a directory automatically. Configurable per-directory with optional color regeneration on each change.

Settings -> Appearance -> Background -> Shuffle wallpapers controls:

- enable/disable automatic shuffle
- interval in minutes
- optional folder override
- whether theme colors regenerate after each shuffle

Leave the folder empty to shuffle inside the current wallpaper directory. Turn color regeneration off if you want the wallpaper to change without repainting GTK, terminals, Discord, SDDM, and the rest of the parade.

## Wallhaven integration

The left sidebar includes a Wallhaven browser. Search wallhaven.cc, preview results, and apply wallpapers directly from the shell. Supports NSFW filtering, resolution filtering, and category selection.

## Theme presets

44 built-in presets bypass the wallpaper color pipeline entirely and inject predefined color palettes. See [Theming Presets](THEMING_PRESETS.md).

When a preset is active, changing wallpapers still changes the background image but doesn't regenerate colors. Switch back to "Auto" mode in Settings to restore wallpaper-based theming.

## CLI reference

```bash
inir wallpapers set <path>          # Set wallpaper and regenerate colors
inir wallpapers get                 # Get current wallpaper path
inir wallpapers random <directory>  # Set a random wallpaper from directory
```
