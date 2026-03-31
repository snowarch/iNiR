# Install and Update Flow

## How users install iNiR

Three installation modes, documented in README, INSTALL.md, and SETUP.md:

### 1. repo-copy (the standard path — what everyone uses)

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install
inir run
```

- Clone lives anywhere (e.g. `~/inir/`)
- `./setup install` copies QML, scripts, assets to `~/.config/quickshell/inir/` (the runtime dir)
- Installs `scripts/inir` launcher to `~/.local/bin/inir`
- Copies user config to `~/.config/illogical-impulse/config.json`
- Patches Niri config for spawn-at-startup and keybinds
- Runs auto-migrations, generates initial theme colors
- Creates `version.json` in runtime dir
- **Clone and runtime are separate** — `git pull` in the clone does NOT update the runtime

### 2. package-managed (make install)

```bash
sudo make install
```

- Shell payload goes to `/usr/local/share/quickshell/inir/` (or `$PREFIX/share/quickshell/inir`)
- For packagers, testers, or source installs
- `inir update` defers shell payload updates to the package manager
- Migrations still run

### 3. repo-link (manual / dev-only)

```bash
git clone https://github.com/snowarch/inir.git ~/.config/quickshell/inir
cp -r dots/.config/* ~/.config/
```

- Clone IS the runtime dir — no separate copy
- `git pull` directly changes QML (qs hot-reloads)
- Only snowf uses this for development
- Manual section in INSTALL.md shows `spawn-at-startup "inir" "start"` but doesn't explain launcher installation step

## How users update

```bash
inir update
# or equivalently:
./setup update
```

Both run the same update engine. What happens:
1. Check remote for new commits
2. Create snapshot (for rollback)
3. `git pull --ff-only` in the repo clone
4. Re-exec: `exec "$REPO_ROOT/setup" update` with `_II_POST_PULL=1`
   - This ensures the NEW setup code runs after pull
5. Sync QML/scripts/assets to runtime dir (rsync with manifest tracking)
6. Install/update launcher to `~/.local/bin/inir`
7. Run REQUIRED migrations automatically
8. Offer OPTIONAL migrations interactively
9. Restart shell
10. Check missing system packages, update Python venv

## Key behaviors

- **User configs are never touched by updates** — only QML code is synced
- **Config changes are handled by migrations** — backup + rollback coverage
- **User file modifications are detected** via manifest checksums — interactive preserve/view/overwrite/cancel
- **Rollback**: `./setup rollback` restores previous snapshot
- **Doctor**: `inir doctor` auto-diagnoses and fixes common issues

## Three entry points (SETUP.md)

| Entry point | Owns | Notes |
|---|---|---|
| `./setup` | install, update, doctor, status, migrate, rollback, my-changes, uninstall | Authoritative maintenance |
| `inir` | run, start, restart, settings, logs, repair, terminal, browser, IPC | Daily launcher; forwards maintenance to setup |
| `make install` | system-level install for packagers | Package-managed mode |

## Main→dev transition (what happens when dev merges to main)

Existing main-branch users:
- Have repo cloned somewhere, ran `./setup install` previously
- Runtime at `~/.config/quickshell/inir/` (already on both main and dev)
- Config at `~/.config/illogical-impulse/config.json`
- Launch via `qs -c inir` (NO launcher on main)
- Niri config has `spawn-at-startup "qs" "-c" "inir"` patterns

Update path:
1. `cd <their-clone> && ./setup update`
2. Pull brings dev code, re-exec picks up dev's setup
3. Sync installs `scripts/inir` launcher to `~/.local/bin/inir` (new for them)
4. Migration 016: rewrites Niri `qs -c inir` → `~/.local/bin/inir` full-path format
5. Migration 018: modularizes monolithic Niri config.kdl into config.d/ fragments
6. Migration 019: renames `~/.config/illogical-impulse` → `~/.config/inir` with symlink back
7. Migration 020: renames `ILLOGICAL_IMPULSE_VIRTUAL_ENV` → `INIR_VENV` in shell profiles
8. Shell restarts via new launcher
