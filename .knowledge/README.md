# .knowledge — iNiR Project Knowledge Base

Discovery notes from development sessions. Each file documents a specific finding, gotcha, or architectural decision with evidence and context.

## Index

| # | File | Area | Summary |
|---|------|------|---------|
| 001 | [crash-restart-loop-bug](001-crash-restart-loop-bug.md) | scripts/inir | `\|\| true` clobbers `$?` — wrapper never restarted qs after crash |
| 002 | [main-branch-baseline](002-main-branch-baseline.md) | Migration | Verified state of main branch before dev merge |
| 003 | [migration-ordering](003-migration-ordering.md) | sdata/migrations | Dependencies between migrations 016-019 |
| 004 | [quickshell-hot-reload](004-quickshell-hot-reload.md) | Quickshell runtime | Hot-reload is qs-native (QFileSystemWatcher), not wrapper-controlled |
| 005 | [manifest-v1-v2-gap](005-manifest-v1-v2-gap.md) | robust-update | First v1→v2 upgrade skips user-modification detection |
| 006 | [dev-vs-main-delta](006-dev-vs-main-delta.md) | Branch comparison | Complete diff between main and dev for merge planning |
| 007 | [project-direction](007-project-direction.md) | Strategy | Naming archaeology, merge readiness, post-merge debt |
| 008 | [config-path-resolution](008-config-path-resolution.md) | Config system | Priority chain for resolving config directory |
| 009 | [setup-reexec-pattern](009-setup-reexec-pattern.md) | Setup | How setup re-execs itself after git pull for safe updates |
| 010 | [install-update-flow](010-install-update-flow.md) | User workflow | Full install/update/transition flow from README + docs |
| 011 | [gap2-reassessment](011-gap2-reassessment.md) | Migration audit | Version sync check is dev-only useful, harmless for repo-copy |

## How to use

- Each note is self-contained with date, area, evidence, and lessons
- Notes are numbered sequentially — new discoveries get the next number
- The Kai agent indexes these for cross-session recall via `focus_save`
