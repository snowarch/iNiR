# Setup Script Reference

How the `./setup` script works and what it does.

---

## Commands

```bash
./setup                 # Interactive TUI mode
./setup install         # Full install (deps + setup + files)
./setup install -y      # Non-interactive (skip prompts)
./setup install-deps    # Only install packages
./setup install-setups  # Only configure services/groups
./setup install-files   # Only copy config files
./setup update          # Update ii configs/QML only (alias of install-files)
./setup help            # Show help
```

---

## What Happens During Install

### 1. Dependencies (`install-deps`)

Installs packages from the PKGBUILDs in `sdata/dist-arch/`:

- `ii-niri-core` - Niri, basic utils, portals
- `ii-niri-quickshell` - Qt6 stack, Quickshell
- `ii-niri-audio` - PipeWire, playerctl
- `ii-niri-screencapture` - grim, slurp, wf-recorder
- `ii-niri-toolkit` - ydotool, brightnessctl
- `ii-niri-fonts` - fonts, matugen, theming

AUR packages are installed via yay or paru (auto-detected).

### 2. System Setup (`install-setups`)

- Adds user to `input` group (for ydotool)
- Enables `ydotool` systemd service
- Sets up Super-tap daemon (optional)

### 3. Config Files (`install-files`)

Copies configs to `~/.config/`:

| Source | Destination |
|--------|-------------|
| `*.qml`, `modules/`, `services/`, etc. | `~/.config/quickshell/ii/` |
| `defaults/niri/config.kdl` | `~/.config/niri/config.kdl` |
| `dots/.config/matugen/` | `~/.config/matugen/` |
| `dots/.config/fuzzel/` | `~/.config/fuzzel/` |
| `dots/.config/gtk-3.0/`, `gtk-4.0/` | GTK settings |
| `defaults/kde/kdeglobals`, `dolphinrc` | KDE/Qt app settings |
| `dots/.config/illogical-impulse/config.json` | ii runtime config |

Also sets up:

- **Environment variables** - Creates `~/.config/ii-niri-env.sh` with `ILLOGICAL_IMPULSE_VIRTUAL_ENV`
- **Fish config** - If fish is installed, creates `~/.config/fish/conf.d/ii-niri-env.fish`
- **Default wallpaper** - Sets `qs-niri.jpg` as the initial wallpaper
- **Initial theme** - Runs matugen to generate colors from the default wallpaper

---

## Config Handling

The script is careful not to overwrite your existing configs blindly.

### First Run

On first install, if a config file already exists:

1. Your existing file is renamed to `filename.old`
2. The new file is installed
3. You can compare and merge manually

### Subsequent Runs (Updates)

If you run the installer again:

1. New configs are saved as `filename.new`
2. Your current config is **not** touched
3. You can diff and merge the `.new` files yourself

This means:

- **Your `config.kdl` is safe** - updates won't overwrite it
- **Your `config.json` is safe** - same deal
- You can pull repo updates and re-run `./setup install-files` to get new defaults as `.new` files

### Backup Option

The installer prompts to backup your existing `~/.config/` before making changes. Backups go to a timestamped directory.

---

## Updating

To update ii after a `git pull` on this repo:

```bash
cd ~/quickshell-ii-niri  # or wherever you cloned
git pull
./setup update          # sync QML + configs into ~/.config
```

- This is equivalent to `./setup install-files`, but clearer for updates.
- Your existing `config.kdl` / `config.json` are still preserved as described above (new defaults go to `.new`).
- For the QML code itself (`modules/`, `services/`, etc.), the installer uses `rsync --delete` so you get a clean sync with the repo.

---

## Uninstalling

There's no uninstall command. To remove ii:

1. Remove from Niri startup:
   ```kdl
   // Comment out or delete this line in ~/.config/niri/config.kdl
   // spawn-at-startup "qs" "-c" "ii"
   ```

2. Delete the config:
   ```bash
   rm -rf ~/.config/quickshell/ii
   ```

3. Optionally remove packages installed by the script (check `sdata/dist-arch/` for the list)

---

## Troubleshooting

### First run marker

The script tracks first-run status in:
```
~/.local/state/ii-niri/first_run.txt
```

Delete this file to make the installer treat the next run as a fresh install (which will backup existing configs as `.old`).

### Installed files list

The script logs installed files to:
```
~/.local/state/ii-niri/installed_files.txt
```

This is informational only.

### Quickshell first-run

ii has its own first-run experience. The installer resets this so the welcome window appears after install:
```
~/.local/state/quickshell/user/first_run.txt
```
