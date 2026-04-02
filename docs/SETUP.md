# Setup & Updates

## Interactive Menu

```bash
./setup
```

Running `./setup` without arguments launches an interactive menu with all available commands. The menu provides:

- Visual command selection
- Current version, install mode, and update status
- Pending migrations indicator
- Health checks (shell running, Niri detected)
- Snapshot availability

This is the recommended way to use the setup script if you're unsure which command to run.

## How the pieces fit together

There are now three complementary entry points:

- `./setup`
  - authoritative installer and maintenance entry point
  - owns install, update, doctor, status, migrate, rollback, my-changes, uninstall
- `inir`
  - daily launcher and operator CLI
  - owns runtime actions like `run`, `start`, `restart`, `settings`, `logs`, `repair`, `terminal`, and IPC calls
  - forwards maintenance commands like `install`, `update`, `doctor`, `status`, `migrate`, `rollback`, `my-changes`, and `uninstall` back to `setup`
- `make install`
  - packaging-style local install for packagers, testers, or source installs that should behave like a packaged shell payload

Use them like this:

- install once:
  - `./setup install`
- maintenance via launcher wrapper:
  - `inir update`
  - `inir doctor`
  - `inir status`
- runtime operation:
  - `inir run`
  - `inir settings`
  - `inir logs`
  - `inir repair`
- local distribution validation:
  - `make test-local`
  - `inir test-local`
  - `inir test-local --with-runtime`

## Install

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install
inir run
```

Add `-y` for non-interactive mode.

If you want a packaging-style local install surface instead of the repo-sync installer:

```bash
sudo make install
```

That installs:

- `inir` launcher into your install prefix `bin/`
- shell payload into `/usr/local/share/quickshell/inir` by default
- user service asset
- desktop entry
- runtime metadata so `status` / `doctor` can detect package-managed style installs

## Update

```bash
inir update
```

`inir update` and `./setup update` run the same update engine. `inir update` is the convenient launcher-facing entry point; `./setup update` is the underlying maintenance command and the better choice when you also want the interactive TUI nearby.

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

The runtime sync does not overwrite your user configs directly. If a release needs config changes, required or optional migrations may update `config.json` or `config.kdl` with backup/rollback coverage.

For legacy monolithic Niri configs, required migrations can now convert `~/.config/niri/config.kdl` into the modular `config.d/` layout automatically during update. The current config is preserved section-by-section, unknown top-level blocks are kept in `config.d/90-user-extra.kdl`, and the normal migration backup/rollback flow still applies.

If `setup` detects that the active iNiR installation is externally managed, `inir update` does **not** pull or sync repo files into the runtime. In that case it:

- Shows the detected install mode
- Shows the package update command when metadata provides one
- Leaves the shell payload unchanged
- Still applies required migrations if any are pending

## Doctor

```bash
inir doctor
```

`inir doctor` is a wrapper around `./setup doctor`.

Diagnoses and **automatically fixes** common issues:
- Missing directories
- Script permissions
- Python packages (via uv)
- Version tracking
- File manifest

For externally managed installs, `doctor` can rebuild `~/.config/illogical-impulse/version.json` from the runtime metadata already present under `~/.config/quickshell/inir/version.json`. It also skips the repo-sync manifest requirement when the install is package-managed.

If you want the same repair flow plus restart and filtered logs:

```bash
inir repair
```

## Rollback

```bash
./setup rollback
```

Restore a previous snapshot if something breaks after an update. Shows available snapshots with dates and lets you choose which one to restore.

For externally managed installs, `rollback` does not try to restore repo-managed snapshots or reset the checkout. It stops early and points you back to the package manager for shell payload changes.

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

When the installer detects an older unified Niri config, the required migration path can split it into:

- `config.kdl` include root
- `config.d/10-80-*.kdl` standard sections
- `config.d/90-user-extra.kdl` for preserved non-standard top-level content

### Modular Niri config at a glance

For new installs and migrated setups, `~/.config/niri/config.kdl` becomes a small include root and the real sections live in `config.d/`:

- `10-input-and-cursor.kdl`
  - keyboard, mouse, touchpad, cursor basics
- `20-layout-and-overview.kdl`
  - column layout, overview-related compositor behavior
- `30-window-rules.kdl`
  - per-app window rules and matching
- `40-environment.kdl`
  - environment variables exported into the session
- `50-startup.kdl`
  - startup programs and session bootstrap
- `60-animations.kdl`
  - compositor animation tuning
- `70-binds.kdl`
  - keybinds and launcher shortcuts
- `80-layer-rules.kdl`
  - layer-shell and overlay rules
- `90-user-extra.kdl`
  - preserved custom blocks that do not map to the standard split

If you want to change which apps iNiR launches, edit `~/.config/illogical-impulse/config.json` instead of hardcoding new executables into the distributed binds:

- `apps.terminal`
  - used by `inir terminal`
- `apps.browser`
  - used by `inir browser` and the default `Super+W` bind
- `sidebar.quickLaunch`
  - custom quick-launch entries shown by the shell UI

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
| `inir update` | Wrapper around `./setup update` |
| `./setup status` | Show install mode, update strategy, and health |
| `./setup migrate` | Review and apply config migrations |
| `./setup doctor` | Diagnose and auto-fix |
| `./setup rollback` | Restore previous snapshot |
| `./setup my-changes` | View and restore user modifications |
| `./setup uninstall` | Remove iNiR from system |
| `inir install` | Wrapper around `./setup install` from the repo/runtime root |
| `inir start` | Start iNiR in the background |
| `inir stop` | Stop the active runtime |
| `inir run` | Launch iNiR from the active runtime |
| `inir restart` | Restart the active runtime |
| `inir settings` | Open settings via IPC |
| `inir terminal` | Launch the configured terminal from `apps.terminal` |
| `inir browser` | Launch the configured browser from `apps.browser` |
| `inir doctor` | Wrapper around `./setup doctor` |
| `inir logs` | Show recent runtime logs |
| `inir repair` | Doctor + restart + filtered log check |
| `inir status` | Wrapper around `./setup status` |
| `inir test-local` | Run local distribution checks |

Options: `-y` (skip prompts), `-q` (quiet), `-h` (help)

## Status

```bash
./setup status
```

Shows:

- Installed version and commit
- Install mode
- Update strategy
- Repo path when relevant
- Health checks and snapshot availability

For externally managed installs, `status` also shows the detected package update command and makes it explicit that repo-sync updates are disabled for that installation mode.

It also reports:

- resolved runtime path
- launcher availability
- runtime metadata availability

You can reach the same status through:

```bash
inir status
```

`inir status` is a wrapper around `./setup status`.

## Local validation

For distribution, launcher, or install-flow changes, test locally with:

```bash
make test-local
inir test-local
inir test-local --with-runtime
```

These checks cover:

- shell syntax for `setup`, `doctor`, `versioning`, `package-installers`, and `scripts/inir`
- PKGBUILD syntax for the new Arch package roots
- local `make install` dry-run
- launcher path and status resolution
- optional runtime restart and filtered log/error smoke test

## What Gets Installed

### Core Files

| Source | Destination |
|--------|-------------|
| QML code (`./setup install`) | `~/.config/quickshell/inir/` |
| QML code (`make install` / package style) | `/usr/share/quickshell/inir/` or `/usr/local/share/quickshell/inir/` |
| User config | `~/.config/illogical-impulse/config.json` |
| State files | `~/.local/state/quickshell/user/` |
| Cache | `~/.cache/quickshell/inir/` |
| Launcher | `inir` in the install prefix |
| Super daemon | `~/.local/bin/inir_super_overview_daemon.py` |
| Daemon service | `~/.config/systemd/user/inir-super-overview.service` |

### Compositor & Themes

| Source | Destination |
|--------|-------------|
| Niri config | `~/.config/niri/config.kdl` |
| GTK themes | `~/.config/gtk-3.0/`, `~/.config/gtk-4.0/` |
| Qt themes | `~/.config/kdeglobals`, `~/.config/Kvantum/` |
| Color schemes | `~/.local/share/color-schemes/` |
| Theming templates | `~/.config/matugen/` |
| Fuzzel config | `~/.config/fuzzel/` |
| Vesktop themes | `~/.config/vesktop/themes/` |

### Behavior

- First install: Existing configs are backed up to `~/inir-backup/`
- Updates: Your configs are never touched, only QML code is synced
- Package-managed installs: `inir update` defers shell payload updates to the package manager instead of syncing from the current repo checkout
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
- Detects externally managed shell payloads and warns that package removal is separate
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

If the shell payload is externally managed, `uninstall` removes the user-side iNiR config/data it owns but does **not** remove the package-managed payload itself. The command warns about that explicitly.

### Files Removed Automatically

The following are removed without prompting (iNiR-exclusive):

```
~/.config/quickshell/inir/                       # Shell configuration
~/.config/illogical-impulse/                     # User preferences
~/.local/state/quickshell/user/                  # Notifications, todo
~/.cache/quickshell/inir/                        # Cache
~/.local/bin/inir_super_overview_daemon.py       # Super daemon
~/.config/systemd/user/inir-super-overview.service # Daemon service
~/.config/vesktop/themes/system24.theme.css      # Vesktop theme
~/.config/vesktop/themes/ii-colors.css           # Vesktop colors
```

### Shared Configs (Asked Before Removal)

These may be used by other applications. The script asks before removing:

| Path | Type | Default Action |
|------|------|----------------|
| `~/.config/niri/config.kdl` | Essential | Keep (especially if in Niri session) |
| `~/.config/matugen/` | Optional | Ask (remove if you do not want to keep iNiR theming templates) |
| `~/.config/fuzzel/` | Optional | Ask (remove if fuzzel not installed) |
| `~/.config/Kvantum/` | Optional | Ask (remove if Kvantum not installed) |
| `~/.config/kdeglobals` | Optional | Ask |
| `~/.config/dolphinrc` | Optional | Ask (remove if not using Dolphin) |
| `~/.config/gtk-3.0/gtk.css` | Optional | Ask |
| `~/.config/gtk-4.0/gtk.css` | Optional | Ask |
| `~/.config/fontconfig/` | Essential | Keep |
| `${XDG_DATA_HOME:-~/.local/share}/color-schemes/Darkly.colors` | iNiR default | Remove |

### Installed Packages

The script lists packages installed by iNiR but does not remove them automatically. Review the output and remove manually if not needed by other applications.

**Core packages:**
- `quickshell` - Shell framework (safe to remove if no other QS configs)
- `niri` - Wayland compositor (keep if using Niri)

**System tools:**
- `cliphist`, `fuzzel`, `swaylock`, `grim`, `slurp`
- `wl-clipboard`, `brightnessctl`, `playerctl`, `dunst`

**Optional tools:**
- `cava`, `easyeffects`

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
cp -r ~/.local/share/inir-uninstall-backup-*/illogical-impulse ~/.config/illogical-impulse
```

### Manual Uninstall (Fallback)

If the automated script fails or is unavailable:

```bash
# Stop services
qs kill -c inir
systemctl --user disable --now inir-super-overview.service 2>/dev/null

# Remove iNiR-exclusive files
rm -rf ~/.config/quickshell/inir
rm -rf ~/.config/illogical-impulse
rm -rf ~/.local/state/quickshell/user
rm -rf ~/.cache/quickshell/inir
rm -f ~/.local/bin/inir_super_overview_daemon.py
rm -f ~/.config/systemd/user/inir-super-overview.service
rm -f ~/.config/vesktop/themes/system24.theme.css
rm -f ~/.config/vesktop/themes/ii-colors.css
rm -f ~/.config/Vesktop/themes/system24.theme.css
rm -f ~/.config/Vesktop/themes/ii-colors.css

# Remove shared configs (review before running)
# rm -rf ~/.config/niri/config.kdl  # Only if not using Niri
# rm -rf ~/.config/matugen          # Optional: iNiR theming templates
# rm -rf ~/.config/fuzzel
# rm -rf ~/.config/Kvantum
# rm -f ~/.config/kdeglobals
# rm -f ~/.config/dolphinrc
# rm -f ~/.config/gtk-3.0/gtk.css
# rm -f ~/.config/gtk-4.0/gtk.css
# rm -f ${XDG_DATA_HOME:-~/.local/share}/color-schemes/Darkly.colors

# Remove Quickshell shared resources (only if no other QS configs)
# rm -rf ~/.local/state/quickshell/.venv
# rm -rf ~/.local/state/quickshell/themes

# Comment out spawn-at-startup in ~/.config/niri/config.kdl:
# spawn-at-startup "inir" "start"
```

### Reinstalling

To reinstall iNiR after uninstalling:

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install
inir run
```
