# Known limitations

These are the things that do not work, work differently, or will catch you out. Read this before you report a bug. Half your questions are answered here.

## Compositor

iNiR is built for Niri. Hyprland is not supported, so anything that only worked on Hyprland does not work here.

## Hardware

**Brightness.** Laptop screens work through the backlight. External monitors need `ddcutil` and DDC/CI switched on in the monitor's own menu. DDC/CI is slow, so brightness changes on external monitors can lag.

**Power profiles.** Setup and `inir update` install a power profiles daemon and turn it on: `power-profiles-daemon`, or `tuned-ppd` on Fedora. A machine where TLP, tuned, auto-cpufreq or system76-power manages power keeps that one. There Material hides its profile controls, iRiS's control grid and Waffle's action center show the toggle as unavailable, and the saved profile is not restored at start. When nothing manages power, `inir doctor` lists the daemon as missing and installs it.

**Audio.** iNiR needs PipeWire. PulseAudio-only setups do not work. Volume protection can be too strict after suspend. Turn it off in Settings › System › Audio (Waffle: General › Audio › Volume protection; iRiS: Sound & Feedback › Volume › Ear protection).

**Weather and location.** Weather comes from Open-Meteo and needs no key. It refreshes every 10 minutes by default. Change that in Settings › Services › Weather (Waffle: Waffle Style › Weather; iRiS: Sources › Weather). GPS is off by default. When you turn on "Use GPS location", it needs geoclue.

## AI

- Online models (Gemini, Mistral, OpenRouter) need an API key. Keys are stored in your keyring through `secret-tool`, so the keyring has to be running and unlocked.
- Ollama models appear only while Ollama is running on this machine.
- Only Gemini models have Google Search built in. Other models get a "switch to search mode" function instead.
- To block online models, set Settings › System › Safety › Policies › AI Policy to Local only.

## Clipboard

Clipboard history needs `cliphist`. It keeps the latest 400 entries. Image entries show thumbnails.

## Screenshots and recording

- OCR needs Tesseract. The installer adds English, Spanish, Russian, Japanese, Chinese (Simplified and Traditional) and their vertical variants. Pick the language in Settings › Tools › Snipping (iRiS: Screenshots & Recording › Read text). Auto follows your system language.
- Recording needs `wf-recorder`. Record with sound uses the audio set in Settings › Tools › Recording (Waffle: Interface › Screen Recording; iRiS: Screenshots & Recording › Recording). It defaults to system audio, not your microphone.
- Google Lens search (Super+Shift+A) sends the picture to Google. Do not use it if that matters to you.

## Theming

- Theme presets, such as Catppuccin, replace the colours from your wallpaper.
- Firefox and its forks (LibreWolf, Floorp, Waterfox, Zen) read the new colours when they start.
- Chromium browsers (Chrome, Chromium, ungoogled-chromium, Brave, Helium, Thorium) repaint a few seconds after a wallpaper change. The first time, iNiR asks for your password once, to set up their policy folders.
- Vivaldi, Edge and Opera are not themed.
- Terminal colours are set in Settings › Themes › Advanced › Terminal Colors (Waffle: Themes › Terminal Colors; iRiS: Colour › App colours). That covers alacritty, btop, foot, ghostty, kitty, konsole, lazygit, starship, wezterm and yazi. Other terminals need their colours set by hand.

## Overview and windows

- The overview shows live window previews while it is open. Game mode turns them off.
- The wallpaper behind the overview needs Niri's layer rules for `quickshell:iiBackdrop` and `quickshell:wBackdrop`. They ship in the default Niri config. If the wallpaper does not show there, those rules are missing from your config.

## Lock screen

- The lock screen uses your system's PAM setup. Test it before you rely on it.
- Fingerprint unlock is tried when `fprintd` is installed.
- Unlocking the keyring at login is optional.

## Language

Language follows your system locale. Change it in Settings › System › Language › Interface Language (Waffle: General › Time & Language; iRiS: Home › Language).

## Performance

Low power effects, in Settings › Effects (Waffle: Effects › Motion and power; iRiS: Home › Performance › Low power), turns off visual effects such as blur and animations. Use it on slow hardware or on battery.

## Display server

iNiR runs on Wayland only. There is no X11 mode.

## Reporting a bug

1. Run `inir logs --issues`. It lists every warning and error since the shell started, grouped.
2. Check this page.
3. Note your versions (`niri --version` and `qs --version`) and what you changed: `inir ipc factory changed`.

If it is still broken after that, report it. If you would rather ask someone first, the Discord is faster.
