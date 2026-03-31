# Project direction and future considerations

**Date:** 2026-03-31
**Area:** Strategic context

## Where iNiR is going

iNiR started as end-4's dots-hyprland — a dotfiles collection. It evolved into an opinionated desktop shell with:
- Proper installer/updater (`setup`)
- CLI launcher with process supervision (`scripts/inir`)
- Package manager support (`Makefile`)
- Automated migration system (19 migrations and counting)
- Doctor/diagnostics system (18 health checks)
- Two complete panel families (ii: Material Design, waffle: Windows 11)
- GitHub community infrastructure (CI, CoC, Contributing guide)

The dev branch represents the transition from "dotfiles project" to "installable desktop shell product."

## Naming archaeology

```
dots-hyprland (original)
  -> illogical-impulse (config dir, env var, still in use)
  -> ii (quickshell config name, panel family name)
  -> inir (current project name, new config dir, launcher name)
```

Each rename left artifacts. The compat layer (symlinks, fallbacks, regex alternations) handles the technical debt. The branding debt (`ILLOGICAL_IMPULSE_VIRTUAL_ENV`, `ii-pixel` SDDM theme, comments) remains.

## Merge readiness (dev -> main)

The dev branch is ~120 commits ahead. The migration path for existing main-branch users is:

1. **Well-covered:** config dir rename, launcher transition, Niri config rewrite, config key renames
2. **Needs work:** manifest v1->v2 user-mod detection, git-pull-without-setup guard
3. **Acceptable debt:** env var naming, stale comments, migration 017 pattern mismatch

After fixing gaps 1-2, the merge is safe for the vast majority of users. Edge cases (pre-main dots-hyprland installs, heavily customized QML) have recovery paths via backups.

## Technical debt to address post-merge

- Rename `ILLOGICAL_IMPULSE_VIRTUAL_ENV` (needs migration + shell profile update)
- Clean stale `quickshell/ii` references in comments and disabled code
- Evaluate if `ii-pixel` SDDM theme name should change
- Consider deprecation timeline for `~/.config/illogical-impulse/` symlink
- Migration 017 pattern alignment (cosmetic, no user impact)
