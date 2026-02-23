# Known Limitations

Things that don't work, work weirdly, or will bite you when you least expect it. Read this before filing a bug report - I promise half your questions are answered here.

---

## Compositor Support

inir is built for **Niri**. Some features were inherited from the original Hyprland version and don't work on Niri.

### Niri-Only (Works)

| Feature | Status |
|---------|--------|
| Bar, sidebars, overview | ✅ Full support |
| Alt+Tab window switcher | ✅ Full support |
| Clipboard history | ✅ Full support |
| Region tools (screenshot, OCR, recording) | ✅ Full support |
| Lock screen | ✅ Full support |
| Wallpaper + theming | ✅ Full support |
| Notifications | ✅ Full support |
| Settings GUI | ✅ Full support |

### Hyprland-Only (Won't Work on Niri)

| Feature | Why |
|---------|-----|
| Screen zoom | Uses `hyprctl keyword cursor:zoom_factor`. |
| GlobalShortcut bindings | Hyprland's global shortcut system. On Niri, use `config.kdl` keybinds instead. |
| CompositorFocusGrab | Click-outside-to-close for sidebars uses Hyprland's focus grab. On Niri, click the backdrop or press Escape. |
| Lock screen blur hack | The "push windows off-screen for blur" trick is Hyprland-specific. |

### Works on Both

| Feature | Hyprland | Niri |
|---------|----------|------|
| Night light | `hyprsunset` | `wlsunset` (auto-detected) |
| Anti-flashbang brightness | ✅ | ✅ |

---

## Hardware & Drivers

### Brightness Control

- **Laptops**: Works via `brightnessctl` (backlight class).
- **External monitors**: Requires `ddcutil` and a monitor that supports DDC/CI. Many monitors don't, or have it disabled by default.
- **DDC is slow**: External monitor brightness changes have a 300ms debounce because DDC/CI is glacially slow.

### Audio

- **PipeWire required**: inir uses PipeWire APIs directly. PulseAudio-only setups won't work.
- **Volume protection**: The "prevent sudden volume spikes" feature can be overzealous after suspend/resume. Disable it in settings if it's annoying.

### GPS/Weather

- **GPS requires geoclue**: If `geoclue` isn't running or configured, GPS-based weather location silently falls back to IP geolocation.
- **Weather API**: Uses Open-Meteo (free, no key required). Fetch interval is configurable (default 10 min).

---

## AI Chat

### API Keys

- **Stored in gnome-keyring**: API keys are stored via `secret-tool`. If gnome-keyring isn't running or unlocked, keys won't persist.
- **No key = no chat**: Online models (Gemini, Mistral, OpenRouter) require API keys. The sidebar will tell you how to get one.

### Model Limitations

- **Function calling**: Only works reliably with Gemini API format. OpenAI/Mistral function calling is experimental.
- **Ollama**: Local models are auto-detected but require Ollama to be running (`ollama serve`).
- **Search tool**: Only Gemini models support the built-in Google Search tool. Other models get a "switch to search mode" function instead.

### Policy Restrictions

- `policies.ai = 2` in config disables all online AI models. Only local Ollama models will appear.

---

## Clipboard

- **Requires cliphist**: The clipboard panel is just a frontend for `cliphist`. No cliphist = no history.
- **Image previews**: Binary clipboard entries (images) show metadata only, not actual previews.
- **Max 400 entries**: Hardcoded limit to prevent the fuzzy search from choking on huge histories.

---

## Screenshots & Recording

### OCR

- **Requires tesseract**: OCR won't work without `tesseract` and language data packages installed.
- **English only by default**: Install `tesseract-data-<lang>` for other languages.

### Screen Recording

- **Requires wf-recorder**: Region recording uses `wf-recorder`. Not installed = recording fails silently.
- **No system audio by default**: "Record with sound" captures mic input, not system audio. For system audio, you need PipeWire loopback setup.

### Image Search

- **Google Lens**: Reverse image search uploads to Google Lens. Privacy-conscious users: don't use this feature.

---

## Theming

### Matugen

- **Required for wallpaper theming**: Without `matugen`, changing wallpapers won't update colors.
- **First run is slow**: Initial theme generation can take a few seconds on slower machines.

### Theme Presets

- Theme presets (Gruvbox, Catppuccin, etc.) override matugen colors. You can't have both "wallpaper-based colors" and "Catppuccin" at the same time.

### Terminal Theming

- **Supported tools**: Auto-theming covers foot, kitty, alacritty, starship, fuzzel, pywalfox, btop, lazygit, and yazi. Each can be toggled individually in Settings → Terminal Colors.
- **Other terminals**: Not supported. You'll need to manually set colors or use pywal/similar.

---

## Overview & Window Management

### Window Previews

- **No live previews**: Unlike some shells, inir doesn't capture live window thumbnails. You see app icons, not actual window content.
- **Workspace snapshots disabled**: The code for workspace screenshots exists but is disabled (too slow/unreliable).

### Window Matching

- **App ID matching**: inir matches windows by `app_id`. Some apps (especially Electron apps) have weird or missing app IDs, causing icon mismatches.
- **Quickshell windows**: All inir windows have `app_id: "org.quickshell"`. This is correct, not a bug.

### Backdrop & Wallpaper

- **Separate configs**: Material inir and Waffle have independent backdrop/wallpaper settings. If you enable both families, each manages its own background layer.
- **Niri layer rules required**: The backdrop uses Niri's `place-within-backdrop` layer rule. If your wallpaper doesn't show in overview, check that your `config.kdl` has the layer rules for `quickshell:inirBackdrop` and `quickshell:wBackdrop`.
- **Migration is automatic**: Switching between families auto-migrates your `enabledPanels` config. You shouldn't need to touch it manually.

---

## Lock Screen

### Security Notes

- **PAM authentication**: Uses system PAM. If PAM is misconfigured, you might lock yourself out.
- **Keyring unlock**: Optional feature to unlock gnome-keyring on login. Requires keyring to be set up with the same password as your user account.
- **Fingerprint**: Fingerprint unlock is attempted automatically if `fprintd` is available.

### Hyprlock Fallback

- `lock.useHyprlock = true` in config makes the lock keybind launch Hyprlock instead of inir's lock screen. Only works on Hyprland.

---

## Translations

- **Incomplete translations**: Not all strings are translated. English is the fallback.
- **Auto-detection**: Language is detected from system locale. Override with `language.ui` in config.
- **Generated translations**: AI-generated translations go to `~/.config/inir/translations/`. Quality varies.

---

## Performance

### Low Power Mode

- `performance.lowPower = true` disables blur effects and some animations. Use this on potato hardware or when on battery.

### Memory Usage

- inir loads modules lazily, but a fully-loaded shell with all features enabled uses ~200-400MB RAM. Disable panels you don't use in Settings → General → Enabled Panels.

### Startup Time

- First launch after reboot is slower due to config parsing and theme loading. Subsequent launches are faster.

---

## Miscellaneous

### Multi-Monitor

- inir spawns UI elements per-screen. Most features work, but some edge cases (like dragging windows between monitors in overview) aren't implemented.

### Touchscreen/Tablet

- Basic touch support exists but isn't well-tested. On-screen keyboard works but is basic.

### Wayland-Only

- inir is Wayland-only. No X11 support, no XWayland workarounds for the shell itself. (Your apps can still use XWayland via `xwayland-satellite`.)

### Config Hot-Reload

- Most config changes apply immediately. Some (like enabling/disabling modules) require restarting inir with `qs kill -c inir && qs -c inir`.

---

## Reporting Issues

Before opening an issue and making me read your bug report:

1. Check `qs log -c inir` for errors - the answer is usually right there
2. Verify the feature isn't listed as a known limitation above - yes, you have to actually read this page
3. Test with a fresh config: `mv ~/.config/inir/config.json ~/.config/inir/config.json.bak`
4. Include your Niri version (`niri --version`) and Quickshell version (`qs --version`)

If it's still broken after all that, congratulations - you found a real bug. Gold star for you.
