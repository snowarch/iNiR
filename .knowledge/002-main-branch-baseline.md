# Discovery: Main branch actual state (pre-merge baseline)

**Date:** 2026-03-31
**Area:** Migration planning — main → dev

## Verified state of main branch

| Aspect | Main (current) | Dev (target) |
|--------|---------------|-------------|
| Runtime dir | `~/.config/quickshell/inir/` | Same |
| Config dir | `~/.config/illogical-impulse/` (hardcoded) | `~/.config/inir/` with symlink compat |
| Launch method | `qs -c inir` directly | `~/.local/bin/inir` wrapper |
| Niri config format | Monolithic `config.kdl` | Modular `config.d/` fragments |
| Niri IPC binds | `spawn "qs" "-c" "inir" "ipc" "call" ...` | `spawn "~/.local/bin/inir" ...` |
| Migrations | 001-015 | 001-019 |
| Makefile | None | Present (package-managed support) |
| Config path helper | None | `scripts/lib/config-path.sh` |

## Key insight: runtime dir was NOT `quickshell/ii`

I initially assumed main used `quickshell/ii` and needed migration. **Wrong.** Main's setup line 748 already sets `II_TARGET="${XDG_CONFIG_HOME}/quickshell/inir"`. The `quickshell/ii` fallbacks in dev are defensive code for pre-main (dots-hyprland era) installs.

## Transition flow

1. `./setup update` on main → git pull → re-exec with dev's setup code
2. Dev's `resolve_inir_config_dir()` finds `illogical-impulse` (real dir) → resolves correctly
3. Sync files → install launcher → PATH setup → migrations 016-019 → restart

## What NOT to assume

- `git pull` alone does NOT run migrations or install the launcher
- Main's 007/008 keybind migrations inserted `qs -c ii` format — dev modified them but they won't re-run (already applied). Migration 016 catches these with `ii|inir` regex alternation.
- `ILLOGICAL_IMPULSE_VIRTUAL_ENV` env var is NOT renamed in dev either
