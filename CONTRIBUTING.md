# Contributing to iNiR

## Branch Model

| Branch | Role |
|--------|------|
| `main` | Stable. What users install and what `./setup update` ships. |
| `prerelease` | Development. All changes land here first. |

Every pull request targets `prerelease`. The maintainer tests `prerelease`
on a real setup before merging it into `main` — nothing reaches users
without that pass.

## How to Contribute

1. Fork the repository and clone your fork
2. Create a branch from `prerelease`: `git checkout -b fix/descriptive-name origin/prerelease`
3. Make your changes following the patterns below
4. Test: `inir restart && inir logs | tail -50`
5. Commit with a clear message (see conventions below)
6. Push and open a pull request against `prerelease`

## Development Setup

```bash
git clone https://github.com/YOUR_USERNAME/inir.git
cd inir
./setup install
inir run
```

iNiR hot-reloads: saving a file applies it to the running shell
immediately. When you need a clean slate:

```bash
inir restart                    # Restart the supervised shell service
inir logs -f                    # Follow live logs while you test
```

Do not run `qs kill -c inir` or a bare `qs -c inir` — the shell runs as a
supervised systemd service, and raw quickshell commands leave it unmanaged.

## Commit Conventions

- **Imperative mood**, max 72 characters: `Fix bar crash when weather widget is disabled`
- Be specific — not "fix bug" or "update code"
- One logical change per commit (one feature, one fix, one refactor)
- Body (optional): explain **why**, not what

## Branch Naming

| Type | Format | Example |
|------|--------|---------|
| Feature | `feat/short-description` | `feat/bluetooth-battery-level` |
| Bug fix | `fix/short-description` | `fix/bar-crash-on-resize` |
| Refactor | `refactor/short-description` | `refactor/audio-service-cleanup` |

## Project Structure

See [ARCHITECTURE.md](ARCHITECTURE.md) for a detailed breakdown. Key directories:

| Directory | What it contains |
|-----------|-----------------|
| `modules/` | UI components (30+ subdirs) |
| `modules/common/` | Shared infrastructure — **high risk, be careful** |
| `modules/waffle/` | Windows 11-style panel family |
| `services/` | 70+ runtime singletons |
| `scripts/` | CLI launcher, theming pipeline, helpers |
| `sdata/` | Install/update lifecycle, migrations |
| `defaults/` | Shipped default config and app configs |
| `translations/` | i18n strings (15+ languages) |

## Mandatory Patterns

### Config System

```qml
// Reading — always available after Config.ready
Config.options.bar.autoHide.enable        // schema-declared, typed
Config.options?.bar?.autoHide?.enable      // also fine — ?. is harmless

// Writing — ALWAYS setNestedValue, never direct assignment
Config.setNestedValue("bar.autoHide.enable", true)    // persisted
Config.options.bar.autoHide.enable = true              // NOT persisted
```

**Adding a new config key** requires updating together:
1. `modules/common/Config.qml` — schema definition
2. `defaults/config.json` — default value
3. Consumer(s)
4. Settings UI in **both** families (ii and waffle) if user-facing

### Visual Tokens

Never hardcode colors, rounding, or spacing:

```qml
// ii family
color: Appearance.colors.colPrimary
radius: Appearance.rounding.normal

// waffle family
color: Looks.surfaceColor

// NEVER
color: "#FF6200EE"
radius: 8
```

### Style Dispatch

Six styles with priority **zzz > angel > inir > aurora > material** (cards
is derived from material):

```qml
color: Appearance.zzzEverywhere ? Appearance.zzz.paper
     : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
     : Appearance.inirEverywhere ? Appearance.inir.colLayer1
     : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
     : Appearance.colors.colLayer1
```

### Compositor Guards

Never assume a single compositor:

```qml
if (CompositorService.isNiri) { /* niri-only */ }
if (CompositorService.isHyprland) { /* hyprland-only */ }
```

### IPC Functions

All IPC functions must declare return types:

```qml
IpcHandler {
    target: "myService"
    function getData(): string { return String(value) }
    function doThing(): void { /* ... */ }
}
```

### New QML Files

```qml
pragma ComponentBehavior: Bound  // always first line

import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services
```

- One component per file, PascalCase filename
- `id: root` for the root element
- Typed properties (`bool`, `int`, `string`, `list<string>`) over `var`

### Null Safety

```qml
property var windows: NiriService.windows ?? []
property string name: NiriService.focusedWindow?.title ?? ""
```

## High-Risk Areas

These files have hundreds of consumers — prefer add-only changes:

- `modules/common/Appearance.qml` — all ii module visuals
- `modules/common/Config.qml` — all config read/write
- `GlobalStates.qml` — panel visibility state
- `services/Translation.qml` — all i18n strings
- `modules/waffle/looks/Looks.qml` — all waffle modules

## Sync Groups

Always update these together:

| When you change... | Also update... |
|---|---|
| Config schema | `defaults/config.json` + consumer(s) |
| A service | `services/qmldir` (if new) |
| A shared widget | `modules/common/widgets/qmldir` (if new) |
| IPC targets | `docs/IPC.md` |
| Dependencies | `docs/PACKAGES.md` |

## Migrations

When a config or data format changes between versions:

- Add a new script at `sdata/migrations/NNN-descriptive-name.sh`
- Use the next sequential number (check `sdata/migrations/` for the latest)
- Migrations are **sourced**, not executed — no top-level `exit` or `set -e`
- Migrations must be idempotent (safe to run twice)
- Never rename, reorder, or delete existing migrations

## Translations

- Strings go in `translations/`
- Use `Translation.tr("key", "default text")` in QML
- See existing translations for the format

## AI-Assisted Contributions

Using AI tools to write code is fine — shipping their output untested is
not. Before opening a PR:

- Run your change on a real iNiR setup and exercise the exact flow you
  touched. "It looks right" is not testing.
- Describe in the PR what you ran and what you observed.
- No invented APIs — every Quickshell/iNiR API you call must exist. Check
  existing code or the [Quickshell docs](https://quickshell.org/docs/).
- No drive-by reformatting, file restructuring, or boilerplate comments
  around code you did not change.
- Keep AI attributions (bot co-author trailers, "generated with" footers)
  out of commits and code.
- Disclose AI usage in the PR template's checklist (which tool/model) —
  it is not held against you; it tells the reviewer where to look.

PRs with no evidence of real testing may be closed without detailed review.

## Code of Conduct

This project follows a [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to uphold it.

## Getting Help

- [Discord](https://discord.gg/pAPTfAhZUJ)
- [Issue tracker](https://github.com/snowarch/inir/issues)
