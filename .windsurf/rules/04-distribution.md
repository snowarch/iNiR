---
trigger: model_decision
description: Pull when installation, packaging, distro support, dependencies, updater behavior, or user-environment assumptions matter.
---

# iNiR Distribution & Packaging (Verified from sdata/ and scripts/)

## Overview

iNiR is distributed as a git repo with a TUI installer: `./setup`.
NOT published to AUR — PKGBUILDs are internal dependency manifests read by the installer.

## Install Flow

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup                  # Interactive TUI
./setup install -y       # Fully automated
./setup update           # Pull + sync + restart
./setup doctor           # Diagnose + auto-fix
./setup rollback         # Restore previous snapshot
```

### 3 Install Stages

1. **Dependencies** — routes to distro-specific installer (Arch/Fedora/Debian/generic)
2. **System Config** — groups, gsettings, Kvantum, xdg-portal, ydotool
3. **Config Files** — copies runtime QML to `~/.config/quickshell/inir/`, installs configs (niri, matugen, fish, foot, kitty, GTK, KDE, etc.), runs matugen for initial colors, creates version metadata

## Multi-Distro Support

| Distro | Strategy |
|--------|----------|
| **Arch** | pacman + yay/paru (AUR) for fonts. Conflict-detects quickshell variants. |
| **Fedora** | dnf + COPR repos (quickshell, niri). RPM Fusion for ffmpeg. Binary tools from GitHub. |
| **Debian/Ubuntu** | apt + compile from source (niri, quickshell, xwayland-satellite). Requires 12+/24.04+. |
| **Generic** | Guidance-only. Checks installed tools, attempts Cargo/Go installs. |

## 6 Internal PKGBUILDs (dependency manifests)

| Package | Key deps |
|---------|----------|
| **inir-core** | niri, cliphist, curl, ripgrep, jq, wl-clipboard, networkmanager, fish, gum, python |
| **inir-quickshell** | quickshell, qt6-declarative, qt6-wayland, qt6-5compat, qt6-webengine (optional), kirigami |
| **inir-audio** | pipewire, pipewire-pulse, playerctl, cava, mpv, yt-dlp |
| **inir-fonts** | ttf-roboto-flex (CRITICAL), ttf-material-symbols-variable-git (CRITICAL), ttf-jetbrains-mono-nerd, ttf-oxanium, kvantum |
| **inir-toolkit** | brightnessctl, ddcutil, grim, slurp, swayidle, swaylock, tesseract, ydotool, hyprpicker |
| **inir-screencapture** | grim, slurp, swappy, wf-recorder, ffmpeg, imagemagick |

## Critical Fonts (shell breaks without)

- `ttf-material-symbols-variable-git` — ALL UI icons
- `ttf-roboto-flex` — default UI font
- `ttf-jetbrains-mono-nerd` — monospace + inir style
- `ttf-oxanium` — angel style font

## Python Environment

`uv` creates venv at `~/.local/state/quickshell/.venv` from `sdata/uv/requirements.txt`.
Exported as `ILLOGICAL_IMPULSE_VIRTUAL_ENV` in shell profiles (legacy env-var name kept for compatibility).
Used by: color generation, music recognition, voice search.

## Update System

`./setup update`:
1. Snapshot (rollback point) → 2. `git pull --ff-only` → 3. Detect user modifications (save to timestamped dir) → 4. `rsync -a --delete` runtime dirs → 5. Apply migrations → 6. Restart via launcher (`inir restart` / `scripts/inir restart`) → 7. Dep check → 8. Update Python venv

User-modified files preserved and restorable via `./setup my-changes`.

## User Impact Considerations

- Old configs may be missing new keys → ALWAYS use `?.` + `??` in code
- Users may have custom enabledPanels list → never overwrite, only additive merge
- Multi-monitor setups → screen filtering is per-PanelWindow, test with multiple screens
- Some users on Hyprland (not just Niri) → compositor guards required
- Fonts may be missing on non-Arch → fallback font behavior matters
- Config is at `~/.config/illogical-impulse/config.json` (legacy name from fork origin)
