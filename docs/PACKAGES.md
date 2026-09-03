# Package Reference

Complete list of packages used by iNiR, organized by category. These are what the setup script installs on Arch-based systems.

The PKGBUILDs live in `sdata/dist-arch/`.

> **`inir-deps`** is a meta-package that depends on all the groups below. It exists so that `pacman -Qdtq | pacman -Rns -` (clean orphans) doesn't remove iNiR's dependencies. It has no files of its own.

---

## Core (`inir-core`)

Essential packages for Niri + ii to function.

| Package | Purpose |
|---------|---------|
| `niri` | Compositor |
| `awww` | Wallpaper daemon |
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
| `xdg-desktop-portal` | XDG portal base |
| `xdg-desktop-portal-gtk` | GTK portal |
| `xdg-desktop-portal-gnome` | GNOME portal (screenshare) |
| `polkit` | Privilege elevation |
| `polkit-gnome` | Polkit auth-dialog agent (works universally) |
| `networkmanager` | Network management |
| `gnome-keyring` | Secrets storage |
| `nautilus` | File manager |
| `kitty` | Terminal (default) |
| `fish` | Fish shell (required for scripts) |
| `gum` | TUI for setup script |
| `xwayland-satellite` | X11 compatibility |

---

## Quickshell (`inir-quickshell`)

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

## Audio (`inir-audio`)

Audio stack and media controls.

| Package | Purpose |
|---------|---------|
| `pipewire` | Audio server |
| `pipewire-pulse` | PulseAudio compat |
| `pipewire-alsa` | ALSA compat |
| `wireplumber` | Session manager |
| `playerctl` | Media player control |
| `plasma-browser-integration` | Browser media sessions for MPRIS controls/artwork |
| `libdbusmenu-gtk3` | Tray menus |
| `pavucontrol` | Volume control GUI |
| `mpv` | Media playback backend |
| `mpv-mpris` | MPRIS bridge for mpv |
| `yt-dlp` | YouTube extraction backend |
| `deno` | JavaScript runtime used by yt-dlp for current YouTube challenges |
| `yt-dlp-ejs` | YouTube challenge solver scripts (Arch/package-managed path) |
| `socat` | IPC fallback for YTMusic control |
| `cava` | Audio visualizer |
| `easyeffects` | Audio effects |

`pipewire-jack` is an optional/recommended extra depending on your audio setup.

---

## Screenshots & Recording (`inir-screencapture`)

Region tools dependencies.

| Package | Purpose |
|---------|---------|
| `grim` | Screenshots |
| `slurp` | Region selection |
| `swappy` | Screenshot editor |
| `tesseract` | OCR engine |
| `tesseract-data-eng` / `spa` / `rus` | English, Spanish, Russian OCR data |
| `tesseract-data-jpn` / `jpn_vert` | Japanese horizontal/vertical OCR data |
| `tesseract-data-chi_sim*` / `chi_tra*` | Simplified/Traditional Chinese horizontal/vertical OCR data |
| `wf-recorder` | Screen recording |
| `imagemagick` | Image processing |
| `ffmpeg` | Video processing |

---

## Input Toolkit (`inir-toolkit`)

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
| `tesseract-data-eng` / `spa` / `rus` | English, Spanish, Russian OCR data |
| `tesseract-data-jpn` / `jpn_vert` | Japanese horizontal/vertical OCR data |
| `tesseract-data-chi_sim*` / `chi_tra*` | Simplified/Traditional Chinese horizontal/vertical OCR data |

---

## Fonts & Theming (`inir-fonts`)

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

### Official packages recently promoted from AUR

`ttf-material-symbols-variable`, `ttf-jetbrains-mono-nerd`, `adw-gtk-theme`,
`capitaine-cursors`, `mission-center`, and `uv` are installed from Arch `extra`.
Keeping them on the mirror path avoids unnecessary AUR builds and is friendlier
to users whose networks cannot reliably reach GitHub/AUR endpoints.

### From AUR

| Package | Purpose | Required |
|---------|---------|----------|
| `darkly-bin` | Darkly Qt style (Material You widget style for Qt apps) | Yes |
| `ttf-roboto-flex` | Roboto Flex variable font | Yes (default UI font) |
| `ttf-oxanium` | Oxanium font | Yes (ZZZ and Angel styles) |
| `ttf-gabarito-git` | Gabarito variable font | Yes (default title font) |
| `ttf-readex-pro` | Readex Pro font | No (has fallback) |
| `ttf-rubik-vf` | Rubik variable font | No (has fallback) |
| `otf-space-grotesk` | Space Grotesk font | No (has fallback) |
| `ttf-twemoji` | Twitter emoji | No (has fallback) |

> **Note:** Optional fonts will be downloaded directly from GitHub if AUR packages are unavailable (e.g., due to regional restrictions). The UI will use system fallback fonts if installation fails completely.

---

## Optional

Not installed by default, but useful. The shell handles their absence gracefully.

| Package | Purpose | Used by |
|---------|---------|---------|
| `warp-cli` | Cloudflare WARP VPN toggle | Quick toggles panel |
| `ollama` | Local LLM for AI chat | Sidebar AI assistant |
| `whisper-cpp` | Local speech-to-text, no API key needed | Voice input and voice search |
| `cava` | Audio visualizer | Bar widget (optional) |
| `easyeffects` | Audio effects | Quick toggles panel |
| `yt-dlp` | YouTube video/audio extraction | YTMusic sidebar |
| `mpv` | Media player | YTMusic sidebar |
| `deno` | JavaScript runtime for yt-dlp | YTMusic sidebar (YouTube challenge solving) |

> **Note:** `cava` and `easyeffects` are included in `inir-audio` but are optional features. The toggles will be hidden if the packages aren't installed.

> **YTMusic Requirements:** iNiR provisions its Python browsing runtime and a current playback `yt-dlp` (including SecretStorage and EJS support) in the managed venv. The shell selects that managed binary before an older distro copy. Playback also requires `mpv`, `socat`, and Deno >= 2.3. Package-managed Arch/Nix installations provide the equivalent closed runtime through their package metadata. `inir doctor` repairs the managed Python/Deno runtime instead of asking users to install Python packages manually.
