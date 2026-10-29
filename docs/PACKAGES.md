# Packages

The installer installs everything listed here. Use it to see what a feature needs, or what is missing when something stops working.

Some fonts come with iNiR itself, on every distro: Geist and Geist Mono (iRiS), Inter, Archivo, Google Sans Flex, Montserrat and Rubik. They live in `assets/fonts` and the shell links them into `~/.local/share/fonts/inir`, so no package is needed.

Power profiles come from `power-profiles-daemon` (`tuned-ppd` on Fedora), installed and turned on unless TLP, tuned,
auto-cpufreq or system76-power already manages power.

## Arch

On Arch, the installer uses the bundles in `sdata/dist-arch/`. Most packages come from the official repositories.

| Bundle | Covers |
|---|---|
| `inir-core` | Niri, awww, portals, polkit, NetworkManager, nautilus, kitty, fish, gum, xwayland-satellite |
| `inir-quickshell` | Quickshell and the Qt 6 and KDE libraries it loads |
| `inir-audio` | PipeWire with WirePlumber, playerctl, pavucontrol, cava, EasyEffects, mpv, yt-dlp, deno, socat |
| `inir-screencapture` | grim, slurp, swappy, wf-recorder, ffmpeg, ImageMagick, Tesseract with its language data |
| `inir-toolkit` | ydotool, wtype, upower, brightnessctl, ddcutil, geoclue, fprintd, swayidle, swaylock, blueman, libqalculate |
| `inir-fonts` | fontconfig, Noto emoji, DejaVu, Liberation, Roboto, Kvantum, Plasma integration |
| `inir-deps` | The same packages, listed directly, so orphan cleanup does not remove them. It has no files of its own |

Fonts and themes come from the official repositories where they exist: `adw-gtk-theme`, `capitaine-cursors`, `ttf-material-symbols-variable` and `ttf-jetbrains-mono-nerd`. `mission-center` is official too.

### AUR packages

- `ttf-roboto-flex`, `ttf-oxanium` (the ZZZ and Angel styles) and `ttf-gabarito-git` (the default title font). Oxanium and Gabarito fall back to a download from GitHub.
- `darkly-bin`, the Material You Qt style. The installer skips it when Darkly is already installed.
- `otf-space-grotesk`, `ttf-readex-pro`, `ttf-rubik-vf` and `ttf-twemoji` are optional. The UI has fallbacks for them.

## Void Linux

Void uses XBPS packages for the same profiles. These names differ from Arch:

| Capability | Void package |
|---|---|
| Fish shell | `fish-shell` (provides `/usr/bin/fish`) |
| Qt 6 compatibility | `qt6-qt5compat` |
| Quickshell | `quickshell` |
| Geolocation | `geoclue2` |
| ImageMagick | `ImageMagick` |
| Network editor | `network-manager-applet` |
| Syntax highlighting | `kf6-syntax-highlighting` |
| KDE config | `kf6-kconfig`, `plasma-integration` |
| OCR | `tesseract-ocr` with its language packages |
| Night light | `wlsunset` |
| Wallpaper | `awww` |
| Notification client | `dunst` (provides `dunstify`) |

Packages with no XBPS version come from pinned upstream sources: ydotool, Cloudflare WARP, adw-gtk3, WhiteSur, Capitaine, Darkly, some UI fonts and the vertical OCR models. Mission Center comes from Flathub.

Package search, install and remove run through XBPS in the left sidebar's Software view.

## Optional

These are not installed by default. Without them the feature stays hidden or says what is missing.

| Package | Used for | Where |
|---|---|---|
| `warp-cli` | Cloudflare WARP | Quick toggles |
| `ollama` | Local AI models | Settings › AI |
| whisper.cpp (`whisper-cli`) | Local speech-to-text | Settings › AI, Local Whisper |
| `easyeffects` and `lsp-plugins-lv2` | 10-band equalizer | Settings › Modules › EasyEffects Equalizer |
| `cava` | Bar audio spectrum | Settings › Bar › Audio spectrum |
| `yt-dlp`, `mpv`, `socat`, `deno` | YTMusic playback | Left sidebar, YTMusic |
| Qt WebEngine | Web apps in Material's left sidebar | On qs-rs, `inir webengine` downloads it; on Quickshell, `qt6-webengine` |
| `qt6-webengine` and `layer-shell-qt` | Interactive web wallpaper | Settings › Wallpaper › Source |

YTMusic needs yt-dlp 2025.11.12 or newer and Deno 2.3 or newer. `inir doctor` checks the Deno runtime.
