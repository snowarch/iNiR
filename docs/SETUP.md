# Setup & Updates

## Interactive Menu

```bash
./setup
```

Running `./setup` without arguments launches an interactive menu with all available commands. The menu provides:

- Visual command selection
- Current version and update status
- Pending migrations indicator
- Health checks (shell running, Niri detected)
- Snapshot availability

This is the recommended way to use the setup script if you're unsure which command to run.

## Install

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install
```

Add `-y` for non-interactive mode.

## Update

```bash
./setup update
```

What happens:
1. Checks remote for new commits
2. Creates snapshot (for rollback)
3. Pulls changes
4. Syncs QML code, scripts, assets
5. Syncs Vesktop themes (if present)
6. Applies required migrations automatically
7. Offers optional migrations
8. Restarts shell
9. Checks for missing system packages
10. Updates Python venv packages

Your user configs (`config.json`, `config.kdl`) are never touched.

## Doctor

```bash
./setup doctor
```

Diagnoses and **automatically fixes** common issues:
- Missing directories
- Script permissions
- Python packages (via uv)
- Version tracking
- File manifest
- Starts shell if not running

## Rollback

```bash
./setup rollback
```

Restore a previous snapshot if something breaks after an update. Shows available snapshots with dates and lets you choose which one to restore.

## Migrate

```bash
./setup migrate
```

Review and apply pending config migrations. Migrations are changes to user configs (keybinds, layer rules, etc.) required by new features.

What happens:
- Shows list of pending migrations
- Displays exactly what each migration will change
- Creates automatic backup before applying
- Lets you choose which migrations to apply
- Required migrations are applied automatically during `update`
- Optional migrations can be applied manually

## My Changes

```bash
./setup my-changes
```

View and manage your modifications to distributed files. The setup script tracks which files you've customized.

What it shows:
- List of files you've modified from defaults
- Option to view differences
- Option to restore original versions
- Option to keep your modifications

Useful when you want to see what you've changed or restore defaults after customization.

## Commands

| Command | Description |
|---------|-------------|
| `./setup` | Interactive menu |
| `./setup install` | Full installation |
| `./setup update` | Check remote, pull, sync, restart |
| `./setup migrate` | Review and apply config migrations |
| `./setup doctor` | Diagnose and auto-fix |
| `./setup rollback` | Restore previous snapshot |
| `./setup my-changes` | View and restore user modifications |
| `./setup uninstall` | Remove iNiR from system |

Options: `-y` (skip prompts), `-q` (quiet), `-h` (help)

## What Gets Installed

### Core Files

| Source | Destination |
|--------|-------------|
| QML code | `~/.config/quickshell/inir/` |
| User config | `~/.config/inir/config.json` |
| State files | `~/.local/state/quickshell/user/` |
| Cache | `~/.cache/quickshell/inir/` |
| Super daemon | `~/.local/bin/inir_super_overview_daemon.py` |
| Daemon service | `~/.config/systemd/user/inir-super-overview.service` |

### Compositor & Themes

| Source | Destination |
|--------|-------------|
| Niri config | `~/.config/niri/config.kdl` |
| GTK themes | `~/.config/gtk-3.0/`, `~/.config/gtk-4.0/` |
| Qt themes | `~/.config/kdeglobals`, `~/.config/Kvantum/` |
| Color schemes | `~/.local/share/color-schemes/` |
| Matugen config | `~/.config/matugen/` |
| Fuzzel config | `~/.config/fuzzel/` |
| Vesktop themes | `~/.config/vesktop/themes/` |

### Behavior

- First install: Existing configs are backed up to `~/inir-backup/`
- Updates: Your configs are never touched, only QML code is synced
- Shared configs: Only installed if they don't exist or you approve overwrite

## Migrations

Some features need config changes (new keybinds, layer rules, etc). After `update`, you're asked if you want to apply pending migrations. Each shows exactly what will change, with automatic backup.

## Backups

- Install backups: `~/inir-backup/`
- Update backups: `~/.local/state/quickshell/backups/`

## Uninstall

### Automated Uninstall (Recommended)

```bash
./setup uninstall
```

The uninstall script intelligently removes iNiR while preserving shared resources and user data:

**What it does:**
- Creates automatic backup before removal
- Removes iNiR-exclusive files and directories
- Asks before removing shared configs (Niri, GTK, themes)
- Detects if you're in a Niri session (preserves compositor config)
- Detects other Quickshell configs (preserves shared resources)
- Lists installed packages with removal recommendations
- Shows commands to revert system changes (groups, modules)

**Interactive mode:**
```bash
./setup uninstall
```

Asks before removing each shared config. Recommended for most users.

**Quick mode:**
```bash
./setup uninstall -y
```

Removes only iNiR-exclusive files, keeps all shared configs and packages.

### Files Removed Automatically

The following are removed without prompting (iNiR-exclusive):

```
~/.config/quickshell/inir/                         # Shell configuration
~/.config/inir/                     # User preferences
~/.local/state/quickshell/user/                  # Notifications, todo
~/.cache/quickshell/inir/                          # Cache
~/.local/bin/inir_super_overview_daemon.py         # Super daemon
~/.config/systemd/user/inir-super-overview.service # Daemon service
~/.config/vesktop/themes/system24.theme.css      # Vesktop theme
~/.config/vesktop/themes/inir-colors.css           # Vesktop colors
```

### Shared Configs (Asked Before Removal)

These may be used by other applications. The script asks before removing:

| Path | Type | Default Action |
|------|------|----------------|
| `~/.config/niri/config.kdl` | Essential | Keep (especially if in Niri session) |
| `~/.config/matugen/` | Optional | Ask (remove if matugen not installed) |
| `~/.config/fuzzel/` | Optional | Ask (remove if fuzzel not installed) |
| `~/.config/Kvantum/` | Optional | Ask (remove if Kvantum not installed) |
| `~/.config/kdeglobals` | Optional | Ask |
| `~/.config/dolphinrc` | Optional | Ask (remove if not using Dolphin) |
| `~/.config/gtk-3.0/gtk.css` | Optional | Ask |
| `~/.config/gtk-4.0/gtk.css` | Optional | Ask |
| `~/.config/fontconfig/` | Essential | Keep |
| `~/.local/share/color-schemes/Darkly.colors` | iNiR default | Remove |

### Installed Packages

The script lists packages installed by iNiR but does not remove them automatically. Review the output and remove manually if not needed by other applications.

**Core packages:**
- `quickshell` - Shell framework (safe to remove if no other QS configs)
- `niri` - Wayland compositor (keep if using Niri)

**System tools:**
- `cliphist`, `fuzzel`, `swaylock`, `grim`, `slurp`
- `wl-clipboard`, `brightnessctl`, `playerctl`, `dunst`

**Optional tools:**
- `matugen`, `cava`, `easyeffects`

The script provides distro-specific removal commands (pacman, dnf, apt) with safety recommendations.

### System Changes Not Reverted

The following system changes are not automatically reverted. The script shows commands to revert them manually if desired:

- User groups: `video`, `i2c`, `input`
- i2c-dev module: `/etc/modules-load.d/i2c-dev.conf`
- ydotool service

### Backup Location

Backups are saved to:
```
~/.local/share/inir-uninstall-backup-YYYYMMDD-HHMMSS/
```

To restore from backup:
```bash
cp -r ~/.local/share/inir-uninstall-backup-*/quickshell-inir ~/.config/quickshell/inir
cp -r ~/.local/share/inir-uninstall-backup-*/inir ~/.config/inir
```

### Manual Uninstall (Fallback)

If the automated script fails or is unavailable:

```bash
# Stop services
qs kill -c inir
systemctl --user disable --now inir-super-overview.service 2>/dev/null

# Remove iNiR-exclusive files
rm -rf ~/.config/quickshell/inir
rm -rf ~/.config/inir
rm -rf ~/.local/state/quickshell/user
rm -rf ~/.cache/quickshell/inir
rm -f ~/.local/bin/inir_super_overview_daemon.py
rm -f ~/.config/systemd/user/inir-super-overview.service
rm -f ~/.config/vesktop/themes/system24.theme.css
rm -f ~/.config/vesktop/themes/inir-colors.css
rm -f ~/.config/Vesktop/themes/system24.theme.css
rm -f ~/.config/Vesktop/themes/inir-colors.css

# Remove shared configs (review before running)
# rm -rf ~/.config/niri/config.kdl  # Only if not using Niri
# rm -rf ~/.config/matugen
# rm -rf ~/.config/fuzzel
# rm -rf ~/.config/Kvantum
# rm -f ~/.config/kdeglobals
# rm -f ~/.config/dolphinrc
# rm -f ~/.config/gtk-3.0/gtk.css
# rm -f ~/.config/gtk-4.0/gtk.css
# rm -f ~/.local/share/color-schemes/Darkly.colors

# Remove Quickshell shared resources (only if no other QS configs)
# rm -rf ~/.local/state/quickshell/.venv
# rm -rf ~/.local/state/quickshell/themes

# Comment out spawn-at-startup in ~/.config/niri/config.kdl:
# spawn-at-startup "qs" "-c" "inir"
```

### Reinstalling

To reinstall iNiR after uninstalling:

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install
```
