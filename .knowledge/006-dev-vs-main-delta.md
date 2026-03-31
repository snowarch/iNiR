# Dev vs Main: Complete delta reference

**Date:** 2026-03-31
**Area:** Branch comparison for merge planning

## Architecture changes

| Component | Main | Dev | Migration |
|-----------|------|-----|-----------|
| Launcher | None. `qs -c inir` directly | `scripts/inir` (1455 lines). Installed to `~/.local/bin/inir` | Migration 016 rewrites Niri config. Setup installs launcher + PATH |
| Config directory | `~/.config/illogical-impulse/` hardcoded | `~/.config/inir/` with symlink compat layer | Migration 019 renames + symlinks |
| Config path resolution | Hardcoded in `environment-variables.sh` | `scripts/lib/config-path.sh` helper with priority logic | Automatic via setup re-exec |
| Niri config format | Monolithic `config.kdl` | Modular `config.d/` (10-90 fragments) | Migration 018 splits automatically |
| Package manager support | None | `Makefile` with install/uninstall targets | New capability, no migration needed |
| Crash recovery | None. qs dies, shell is gone | Wrapper restart loop (max 5 in 60s) | Automatic via new launcher |
| ABI checking | None | Qt version mismatch detection in launcher | Automatic |
| systemd service | None | `assets/inir.service` with install command | `inir service install` |

## Launcher capabilities (NEW in dev)

The `scripts/inir` wrapper (1455 lines) provides:
- `inir start/stop/restart/status/logs/run`
- `inir doctor/migrate/update` (delegates to setup)
- `inir <target> <function> [args]` (IPC forwarding with kebab-to-camelCase normalization)
- `inir service install` (systemd user service)
- Environment setup (QT_SCALE_FACTOR, log suppression)
- Crash supervision with rapid-restart protection
- ABI mismatch detection (Qt version in qs vs system Qt)

## Infrastructure changes

| Area | Main | Dev |
|------|------|-----|
| Migrations | 001-015 | 001-019 (016-019 are REQUIRED auto-apply) |
| Update system | Basic rsync | Manifest v2 with checksums, user-mod detection, backup/rollback |
| Doctor | Basic checks | 18 checks with auto-fix (fonts, Qt ABI rebuild, conflicting services) |
| Setup | Install + update | Install + update + migrate + doctor + status |
| CI | None | GitHub Actions workflows |
| Docs | Minimal | README, CONTRIBUTING, CoC, SECURITY, CHANGELOG |

## Config key changes

| Key | Main | Dev | Migration |
|-----|------|-----|-----------|
| `blurStatic` | Exists | Removed | Migration 015 (auto) |
| `videoBlurStrength` | Exists | Renamed to `thumbnailBlurStrength` | Migration 015 (auto) |

## File structure changes

- `scripts/inir` — NEW (launcher wrapper)
- `scripts/lib/config-path.sh` — NEW (config resolution)
- `sdata/lib/robust-update.sh` — NEW (manifest v2 system)
- `sdata/lib/doctor.sh` — Major expansion (18 checks)
- `sdata/migrations/016-019` — NEW
- `Makefile` — NEW
- `assets/inir.service` — NEW (systemd)
- `.github/` — NEW (CI, templates)
- `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md` — NEW

## What stays the same

- Runtime directory: `~/.config/quickshell/inir/` (unchanged)
- QML module structure: `modules/`, `services/`, `scripts/`
- Config format: JSON at config dir
- Color pipeline: same flow, same output paths
- Panel families: ii + waffle
- `ILLOGICAL_IMPULSE_VIRTUAL_ENV` env var (not renamed)

## Breaking changes NOT handled by migration

1. Users who `git pull` without `./setup update` get QML changes but miss infrastructure
2. First v1-to-v2 manifest upgrade skips user-modification detection
3. Migration 017 pattern matching doesn't align with 016's output format (low risk)
4. External tools/scripts that hardcode `qs -c inir` will still work but bypass the wrapper
