# Audio and Media

How audio control and media player integration work in iNiR.

## Audio

### PipeWire integration

iNiR controls audio through PipeWire via the Quickshell PipeWire module and `wpctl` (WirePlumber's CLI). This means it works with PipeWire out of the box, no PulseAudio compatibility layer needed.

### Volume control

Keybinds and OSD handle the basics:

| Key | Action |
|-----|--------|
| Volume Up / Down | Adjust default sink volume |
| Mute | Toggle default sink mute |
| Mic Mute | Toggle default source mute |

The OSD (on-screen display) appears for volume and brightness changes, showing the current level with an animated bar.

### Per-app mixer

The right sidebar (ii) and action center (waffle) include a per-app volume mixer. Each app that's outputting audio appears with its own volume slider. You can mute individual apps or adjust their volume independently.

### Visualizer source filters

Visualizer app filters are exclusions, not an allowlist. In **Settings → Quick → Filters**, enabling a filter for an audio app prevents that app from being selected to drive Cava/visualizers. With no visualizer filters enabled, iNiR follows the active player automatically. Cava captures the monitor of the selected playback sink rather than a recording source, so source resolution never falls through to the system microphone. The list is populated from live PipeWire applications, and manual desktop-entry filters can be added when an app is not currently producing audio.

### Organic visualizer

Bars, M3, Pill and Vertical layouts can use the **Organic** visualizer mode. Instead of drawing a conventional spectrum inside the panel, Organic grows from the panel edges and follows the host geometry while keeping the bar's layout and exclusive zone unchanged. Its response, reach, glow, idle motion and related controls live with the normal visualizer settings.

### EasyEffects

If EasyEffects is installed, iNiR detects its virtual sink and controls the physical sink behind it instead. This means volume control works correctly whether EasyEffects is running or not. A toggle in the right sidebar/action center lets you enable/disable EasyEffects.

On EasyEffects 8.2.8 or newer, the ii media controls can also open a native 10-band output equalizer. It is opt-in under **Settings → Modules → Optional → EasyEffects Equalizer**. When disabled, iNiR does not construct the equalizer panel or its IPC owner. When enabled, iNiR talks to EasyEffects through its local server, discovers the actual `equalizer#N` instance, mirrors gain changes to left and right channels, and leaves the rest of the user's effects chain untouched. The audio bundle includes the Linux Studio Plugins LV2 backend used by EasyEffects' Equalizer. On a fresh EasyEffects setup with an empty output pipeline, iNiR creates and loads a neutral `iNiR Equalizer` preset so the 10-band control works immediately. If the output pipeline already contains other effects, iNiR never replaces them just to add Equalizer; the panel instead asks the user to add Equalizer in EasyEffects and detects it automatically.

### IPC

```bash
inir audio volumeUp         # Increase volume
inir audio volumeDown       # Decrease volume
inir audio mute             # Toggle output mute
inir audio micMute          # Toggle mic mute
```

## Media players

### MPRIS support

iNiR picks up any MPRIS-compatible media player automatically. Spotify, Firefox, mpv, VLC, Celluloid, Amberol, whatever speaks MPRIS shows up in the media controls.

The media player widget appears in:
- The bar (compact now-playing indicator)
- Media controls popup (`iiMediaControls`)
- Right sidebar
- Waffle action center

### Player prioritization

When multiple players are active, iNiR picks the most relevant one:

1. A player that's currently playing beats one that's paused
2. The user's manually selected ("tracked") player beats auto-detection
3. If nothing is playing, the last active player stays visible

### YT Music

The left sidebar includes a full YT Music player. It uses mpv for playback and yt-dlp for stream extraction. Search, queue management, playlists, and playback controls all work from within the shell.

When YT Music is playing via the sidebar AND a browser tab is also showing YT Music, iNiR deduplicates them in the media controls (you see one player, not two).

### Media controls layouts

The media controls popup has multiple layout presets you can choose from in Settings. Different presets show different arrangements of album art, controls, and track info.

## SongRec (music recognition)

If SongRec is installed, you can trigger music recognition from the shell. It listens to your audio output, identifies the song (Shazam-style), and shows the result. Useful when you hear something playing and want to know what it is.
