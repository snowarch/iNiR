# Contributing to iNiR

## How to Contribute

1. Fork the repository and clone your fork
2. Create a branch from `main`: `git checkout -b fix/descriptive-name`
3. Make your changes following the patterns below
4. Test: `inir restart && inir logs | tail -50`
5. Commit with a clear message (see conventions below)
6. Push and open a pull request against `main`

## Development Setup

```bash
git clone https://github.com/YOUR_USERNAME/inir.git
cd inir
./setup install
inir run
```

After making changes:

```bash
inir restart                    # Restart the running shell
inir logs | tail -50            # Check for errors
```

For direct stdout/stderr debugging:

```bash
qs kill -c inir && qs -c inir
```

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
3. Consumer(s) + settings UI if user-facing

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

Five styles with priority **angel > inir > aurora > material**:

```qml
color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
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
- Use the next sequential number (currently 021+)
- Migrations must be idempotent (safe to run twice)
- Never rename, reorder, or delete existing migrations

## Translations

- Strings go in `translations/`
- Use `Translation.tr("key", "default text")` in QML
- See existing translations for the format

## Code of Conduct

This project follows a [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to uphold it.

## Getting Help

- [Discord](https://discord.gg/pAPTfAhZUJ)
- [Issue tracker](https://github.com/snowarch/inir/issues)
