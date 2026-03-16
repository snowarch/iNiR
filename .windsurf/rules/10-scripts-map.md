---
trigger: model_decision
description: Pull when tracing shell scripts, theming pipeline scripts, AI integration scripts, systemd helpers, or runtime script dependencies.
---

# iNiR Scripts Map (Verified from source code)

Every script, what it does, what calls it, what tools it needs.

## scripts/colors/ — Theming Pipeline

| Script | Purpose | Called by | Needs |
|--------|---------|-----------|-------|
| `switchwall.sh` (851 lines) | Master wallpaper switch: matugen → colors.json → applycolor → GTK/KDE/terminal/SDDM | Wallpapers service, keybinds | jq, matugen, python3 |
| `applycolor.sh` (415 lines) | Apply colors to terminals (OSC sequences), Kvantum, Chrome, GTK, foot, kitty, starship | switchwall.sh | jq, sed, pgrep |
| `generate_colors_material.py` | Generate M3 color scheme from wallpaper image → colors.json | switchwall.sh | materialyoucolor, Pillow |
| `generate_terminal_configs.py` (1395 lines) | Generate terminal configs from M3 colors | switchwall.sh | jq, python3 |
| `scheme_for_image.py` | Extract M3 scheme from image (CLI tool) | Direct use | materialyoucolor, Pillow |
| `system24_palette.py` | Generate System24 Discord theme palette | switchwall.sh (optional) | python3 |
| `apply-gtk-theme.sh` | Write GTK CSS from M3 colors | applycolor.sh | gsettings |
| `apply-chrome-theme.sh` | Write Chrome manifest.json from M3 colors | applycolor.sh | jq |
| `random/` | Random wallpaper selection logic | switchwall.sh | — |

### Theming Flow
```
Wallpaper change (user or auto)
  → switchwall.sh
    → matugen (Rust binary): wallpaper → Material You palette
    → generate_colors_material.py: palette → colors.json (M3 tokens)
    → applycolor.sh: colors.json → terminals, GTK, KDE, Kvantum, foot, kitty, starship
    → MaterialThemeLoader.qml reads colors.json → Appearance tokens update
```

## scripts/ai/ — AI Integration

| Script | Purpose | Called by | Needs |
|--------|---------|-----------|-------|
| `gemini-translate.sh` | Send en_US.json to Gemini API → translated JSON | Settings UI button | curl, jq, secret-tool, notify-send |
| `gemini-categorize-wallpaper.sh` | AI categorize wallpaper | WallpaperListener | curl, jq, secret-tool |
| `show-installed-ollama-models.sh` | List local Ollama models | Ai service (model discovery) | ollama |

## scripts/daemon/ — System Daemons

| Script | Purpose | Called by | Needs |
|--------|---------|-----------|-------|
| `ii_super_overview_daemon.py` | Monitor Super key press/release via evdev → IPC toggle overview | systemd service | python3-evdev, qs IPC |

## scripts/systemd/ — Systemd Units

| File | Purpose |
|------|---------|
| `ii-super-overview.service` | Systemd user unit for Super key daemon |
| `suspend_with_lock.py` | Lock screen before suspend (systemd sleep hook) |

## scripts/videos/ — Screen Recording

| Script | Purpose | Called by | Needs |
|--------|---------|-----------|-------|
| `record.sh` (330 lines) | Screen recording: region/monitor/window, VAAPI/NVENC/SW, audio capture | RecorderStatus service via IPC | wf-recorder, slurp, grim, pactl, ffmpeg, niri msg/hyprctl |

## scripts/voiceSearch/ & musicRecognition/

| Script | Purpose | Called by | Needs |
|--------|---------|-----------|-------|
| `record-voice.sh` | Record mic → transcribe via Whisper/Gemini | VoiceSearch service | ffmpeg, curl, secret-tool |
| `recognize-music.sh` | Record audio → identify via SongRec | SongRec service | songrec, pactl |

## scripts/keyring/ — Secret Storage

| Script | Purpose | Called by | Needs |
|--------|---------|-----------|-------|
| `is_unlocked.sh` | Check if gnome-keyring is unlocked | KeyringStorage service | secret-tool |
| `try_lookup.sh` | Try reading secret from keyring | KeyringStorage service | secret-tool |
| `unlock.sh` | Unlock gnome-keyring (PAM fallback) | KeyringStorage service | secret-tool, gnome-keyring-daemon |

## scripts/images/ — Image Analysis

| Script | Purpose | Called by | Needs |
|--------|---------|-----------|-------|
| `find_regions.py` / `find-regions-venv.sh` | Find busy/calm regions in image | Background module | opencv, numpy (venv) |
| `least_busy_region.py` / `least-busy-region-venv.sh` | Find least busy region in image | Background module | opencv, numpy (venv) |

## scripts/thumbnails/ — Wallpaper Previews

| Script | Purpose | Called by | Needs |
|--------|---------|-----------|-------|
| `thumbgen.py` | Generate wallpaper thumbnails (resize + cache) | WallpaperSelector | Pillow (venv) |
| `generate-thumbnails-magick.sh` | Thumbnail generation fallback | WallpaperSelector | imagemagick |
| `thumbgen-venv.sh` | Venv wrapper for thumbgen.py | WallpaperSelector | python3, pip |

## scripts/sddm/ — Login Manager

| Script | Purpose | Called by | Needs |
|--------|---------|-----------|-------|
| `install-pixel-sddm.sh` | Install Pixel SDDM theme | setup | git, sddm |
| `sync-pixel-sddm.py` | Sync M3 colors to SDDM theme | switchwall.sh (optional) | python3, jq |

## scripts/kvantum/ — Qt App Theming

| Script | Purpose | Called by | Needs |
|--------|---------|-----------|-------|
| `materialQT.sh` | Apply M3 colors to Kvantum Qt theme | applycolor.sh | kvantum, sed |
| `changeAdwColors.py` / `adwsvg.py` / `adwsvgDark.py` | Modify Adwaita SVG assets | applycolor.sh | python3, sed |

## Root-Level Scripts

| Script | Purpose | Called by | Needs |
|--------|---------|-----------|-------|
| `close-window.sh` | Close focused window (compositor-aware) | Keybinds | niri msg/hyprctl |
| `launch-terminal.sh` | Launch preferred terminal emulator | Keybinds | foot/kitty/alacritty |
| `launch_first_available.sh` | Try launching first available command from list | Various | — |
| `capture-windows.sh` / `.fish` | Capture window screenshots | WindowPreviewService | grim, niri msg |
| `tiling-cycle.fish` | Cycle tiling layouts (Niri) | Keybinds | niri msg |
| `qml-check.fish` | Lint QML files for common errors | Development | — |
| `detect_sensors.py` | Detect hardware temp sensors | ResourceUsage service | python3, psutil |
| `parse_niri_keybinds.py` | Parse niri config.kdl → keybind JSON | NiriKeybinds service | python3 |
| `add-plugin.py` | Add plugin/webapp to shell | Manual / setup | python3 |
| `scan-plugins.py` | Discover installed plugins | PluginsTab | python3 |

## scripts/cava/

Config templates for Cava (audio visualizer).

## scripts/emoji/

Emoji data files. Read by Emojis service.

## scripts/hyprland/

| Script | Purpose | Called by | Needs |
|--------|---------|-----------|-------|
| `get_keybinds.py` | Parse Hyprland config → keybind JSON | HyprlandKeybinds service | python3 |
