# Package Reference

Complete list of packages used by inir, organized by category. These are what the setup script installs on Arch-based systems.

The PKGBUILDs live in `sdata/dist-arch/`.

---

## Core (`iNiR-core`)

Essential packages for Niri + inir to function.

| Package | Purpose |
|---------|---------|
| `niri` | Compositor |
| `bc` | Math in scripts |
| `coreutils` | Basic utils |
| `cliphist` | Clipboard history |
| `curl` | HTTP requests |
| `wget` | Downloads |
| `ripgrep` | Fast search |
| `jq` | JSON parsing |
| `python` | Python interpreter (scripts) |
| `xdg-user-dirs` | User directories |
| `xdg-utils` | xdg-settings, xdg-open |
| `rsync` | File sync |
| `git` | Version control |
| `wl-clipboard` | Wayland clipboard (wl-copy, wl-paste) |
| `libnotify` | Notifications |
| `pacman-contrib` | checkupdates for update notifications |
| `wlsunset` | Night light / blue light filter |
| `dolphin` | File manager (KDE, optional — nautilus is default) |
| `xdg-desktop-portal` | XDG portal base |
| `xdg-desktop-portal-gtk` | GTK portal |
| `xdg-desktop-portal-gnome` | GNOME portal (screenshare) |
| `polkit` | Privilege elevation |
| `networkmanager` | Network management |
| `gnome-keyring` | Secrets storage |
| `nautilus` | File manager |
| `kitty` | Terminal (default) |
| `foot` | Terminal (fallback) |
| `fish` | Fish shell (required for scripts) |
| `gum` | TUI for setup script |
| `xwayland-satellite` | X11 compatibility |

---

## Quickshell (`iNiR-quickshell`)

Qt6 stack and Quickshell runtime.

### From official repos

| Package | Purpose |
|---------|---------|
| `qt6-declarative` | QML engine |
| `qt6-base` | Qt core |
| `qt6-svg` | SVG support |
| `qt6-wayland` | Wayland integration |
| `qt6-5compat` | Qt5 compatibility |
| `qt6-imageformats` | Image formats |
| `qt6-multimedia` | Media playback |
| `qt6-positioning` | Geolocation |
| `qt6-quicktimeline` | Timeline animations |
| `qt6-sensors` | Sensor APIs |
| `qt6-tools` | Qt tools |
| `qt6-translations` | Translations |
| `qt6-virtualkeyboard` | Virtual keyboard |
| `jemalloc` | Memory allocator |
| `libpipewire` | PipeWire integration |
| `libxcb` | X11 bridge |
| `wayland` | Wayland libs |
| `libdrm` | DRM/display |
| `mesa` | OpenGL |
| `kirigami` | KDE components |
| `kdialog` | KDE dialogs |
| `syntax-highlighting` | Code highlighting |
| `qt6ct` | Qt6 config tool |
| `breeze-icons` | Breeze icon theme (lightweight) |
| `plasma-integration` | KDE platform theme (reads kdeglobals for Qt colors) |

### From AUR

| Package | Purpose |
|---------|---------|
| `qt6-avif-image-plugin` | AVIF image support |

---

## Audio (`iNiR-audio`)

Audio stack and media controls.

| Package | Purpose |
|---------|---------|
| `pipewire` | Audio server |
| `pipewire-pulse` | PulseAudio compat |
| `pipewire-alsa` | ALSA compat |
| `wireplumber` | Session manager |
| `playerctl` | Media player control |
| `libdbusmenu-gtk3` | Tray menus |
| `pavucontrol` | Volume control GUI |
| `mpv` | Media playback backend |
| `mpv-mpris` | MPRIS bridge for mpv |
| `yt-dlp` | YouTube extraction backend |
| `socat` | IPC fallback for YTMusic control |
| `cava` | Audio visualizer |
| `easyeffects` | Audio effects |

`pipewire-jack` and `nodejs` are optional/recommended extras depending on your audio and YTMusic setup.

---

## Screenshots & Recording (`iNiR-screencapture`)

Region tools dependencies.

| Package | Purpose |
|---------|---------|
| `grim` | Screenshots |
| `slurp` | Region selection |
| `swappy` | Screenshot editor |
| `tesseract` | OCR engine |
| `tesseract-data-eng` | English OCR data |
| `wf-recorder` | Screen recording |
| `imagemagick` | Image processing |
| `ffmpeg` | Video processing |

---

## Input Toolkit (`iNiR-toolkit`)

Input simulation, hardware control, and idle management.

| Package | Purpose |
|---------|---------|
| `upower` | Power management |
| `wtype` | Wayland typing |
| `ydotool` | Input simulation |
| `python-evdev` | Evdev bindings |
| `python-pillow` | Image processing |
| `brightnessctl` | Backlight control |
| `ddcutil` | DDC/CI for monitors |
| `geoclue` | Geolocation |
| `swayidle` | Idle management (screen off, lock, suspend) |
| `swaylock` | Screen locker |
| `blueman` | Bluetooth manager GUI |
| `fprintd` | Fingerprint authentication (lock screen) |
| `libqalculate` | Calculator backend |
| `tesseract` | OCR engine |
| `tesseract-data-eng` | English OCR data |
| `tesseract-data-spa` | Spanish OCR data |

---

## Fonts & Theming (`iNiR-fonts`)

Fonts, theming, and utilities.

### From official repos

| Package | Purpose |
|---------|---------|
| `fontconfig` | Font configuration |
| `ttf-dejavu` | DejaVu fonts |
| `ttf-liberation` | Liberation fonts |
| `fuzzel` | Application launcher |
| `glib2` | GLib utilities |
| `translate-shell` | Translation CLI |
| `kvantum` | Qt theming |
| `matugen` | Material You colors |

### From AUR

| Package | Purpose | Required |
|---------|---------|----------|
| `darkly-bin` | Darkly Qt style (Material You widget style for Qt apps) | Yes |
| `ttf-jetbrains-mono-nerd` | JetBrains Mono Nerd | Yes (monospace) |
| `ttf-material-symbols-variable-git` | Material icons | Yes (UI icons) |
| `ttf-readex-pro` | Readex Pro font | No (has fallback) |
| `ttf-rubik-vf` | Rubik variable font | No (has fallback) |
| `otf-space-grotesk` | Space Grotesk font | No (has fallback) |
| `ttf-twemoji` | Twitter emoji | No (has fallback) |
| `adw-gtk-theme-git` | Adwaita GTK theme | Yes |
| `capitaine-cursors` | Capitaine cursor theme | Yes |
| `xwayland-satellite` | Xwayland helper for legacy apps | Yes |

> **Note:** Optional fonts will be downloaded directly from GitHub if AUR packages are unavailable (e.g., due to regional restrictions). The UI will use system fallback fonts if installation fails completely.

---

## Optional

Not installed by default, but useful. The shell handles their absence gracefully.

| Package | Purpose | Used by |
|---------|---------|---------|
| `warp-cli` | Cloudflare WARP VPN toggle | Quick toggles panel |
| `ollama` | Local LLM for AI chat | Sidebar AI assistant |
| `cava` | Audio visualizer | Bar widget (optional) |
| `easyeffects` | Audio effects | Quick toggles panel |
| `yt-dlp` | YouTube video/audio extraction | YTMusic sidebar |
| `mpv` | Media player | YTMusic sidebar |
| `deno` / `node` / `bun` | JavaScript runtime for yt-dlp | YTMusic sidebar (YouTube anti-bot) |

> **Note:** `cava` and `easyeffects` are included in `iNiR-audio` but are optional features. The toggles will be hidden if the packages aren't installed.

> **YTMusic Requirements:** The YTMusic sidebar requires `yt-dlp` and `mpv` for playback. Additionally, yt-dlp needs a JavaScript runtime (`deno`, `node` ≥20, or `bun` ≥1.0.31) to solve YouTube's anti-bot challenges. Install at least one: `deno` (recommended), `nodejs`, or `bun`.
