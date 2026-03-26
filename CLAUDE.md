# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is iNiR

Linux desktop shell built on **Quickshell** (QML-based Wayland shell framework) for the **Niri** compositor, with secondary Hyprland support. Originally forked from end-4's illogical-impulse. Production software used daily on real desktops.

**Stack**: QML (Quickshell), Bash, Python, Go
**Scale**: ~752 QML files, ~87 scripts, 70+ singletons, 129 shared widgets

## Commands

```bash
# Daily development
inir run                    # Launch the shell
inir restart                # Graceful restart (preserves state)
inir logs                   # View shell logs (last 50 lines)
inir logs | tail -50        # Check for errors after changes
inir status                 # Runtime health check
inir doctor                 # Auto-diagnose + fix
inir repair                 # doctor + restart + filter logs
inir settings               # Open settings GUI

# IPC calls (40+ targets)
inir <target> <function> [args...]
inir overview toggle
inir audio volumeUp

# Testing
inir test-local             # Validate distribution files
inir test-local --with-runtime  # Also validate running shell

# Installation
./setup install             # Repo-sync install (symlinks to ~/.config/quickshell/inir/)
./setup update              # Update + run migrations
./setup rollback            # Undo last update
make install                # Package-managed install (to /usr/share/quickshell/inir/)
make test-local             # Same as inir test-local

# Low-level restart (if launcher unavailable)
qs kill -c inir; qs -c inir
```

### Verification after changes (required)

Always restart + check logs after runtime changes:
```bash
inir restart && inir logs | tail -50
```

Verify the **exact surface you changed** — a generic `overview toggle` proves nothing about an unrelated config or IPC change.

## Architecture

```
shell.qml                     Entry point → loads services, selects panel family
  ├─ ShellIiPanels.qml        Material Design family (24 panels)
  └─ ShellWafflePanels.qml    Windows 11 family (24 panels, mixes waffle + shared ii)

GlobalStates.qml               Runtime UI state (panel open/closed booleans)
modules/common/Config.qml      Central config (JsonAdapter, 1385+ lines)
modules/common/Appearance.qml  ii visual tokens (881 lines, 400+ properties)
modules/waffle/looks/Looks.qml Waffle visual tokens (41 design tokens)

services/                      70+ singletons (Audio, Network, NiriService, etc.)
modules/                       30+ UI module dirs (bar, sidebars, dock, settings, waffle/...)
modules/common/widgets/        129 reusable widgets
scripts/inir                   CLI launcher (30KB bash, 40+ commands)
defaults/config.json           Shipped default config (1100+ lines)
sdata/                         Install/update lifecycle, migrations, packaging
```

### Panel Families

Two mutually exclusive UI families, switchable at runtime with `Super+Shift+W`:

| | **Material ii** | **Waffle** |
|---|---|---|
| Active when | `panelFamily !== "waffle"` | `panelFamily === "waffle"` |
| Visual tokens | `Appearance.*` | `Looks.*` |
| Styles | material, cards, aurora, inir, angel | Single fluent style |
| Bar | Top (or vertical) | Bottom (Win11 taskbar) |
| App launcher | Overview | StartMenu with search |
| Right panel | SidebarRight | ActionCenter + NotificationCenter |
| Panel exclusion | None (except overlay) | Auto-closes others |

Each panel uses `PanelLoader` (LazyLoader wrapper):
```qml
PanelLoader {
    identifier: "iiBar"
    extraCondition: !(Config.options?.bar?.vertical ?? false)
    component: Bar {}
}
```
Loads when ALL true: `Config.ready` + identifier in `enabledPanels` array + `extraCondition`.

### Key Singletons (blast radius)

| Singleton | Dependents | Domain |
|---|---|---|
| `Config` | 200+ | All config read/write |
| `Appearance` | 352+ | All ii module visuals |
| `Translation` | 260+ | All i18n strings |
| `GlobalStates` | 129+ | Panel visibility state |
| `Looks` | waffle modules | Waffle visuals |
| `NiriService` | compositor modules | Niri IPC, workspaces, windows |

These are **stability boundaries** — prefer add-only changes, verify all dependents before reshaping.

### Scoped Governance

The project uses scoped AGENTS.md files. **Read the relevant one before working in a domain:**

| Path | Governs |
|---|---|
| `modules/AGENTS.md` | All UI module work |
| `modules/common/AGENTS.md` | Shared widgets, core singletons |
| `modules/waffle/AGENTS.md` | Waffle family UI |
| `services/AGENTS.md` | Service/singleton creation |
| `scripts/AGENTS.md` | CLI, theming, helpers |
| `sdata/AGENTS.md` | Install, update, migrations |

17 detailed convention files also exist in `.windsurf/rules/`.

## Delegation Strategy

10 agents with tiered models — Opus orchestrates, Sonnet implements, Haiku validates:

| Agent | Model | Use for |
|---|---|---|
| `infra` | **opus** | Stability boundaries (Config, Appearance, GlobalStates, Translation, Looks) |
| `qml` | **sonnet** | UI module work in `modules/` |
| `services` | **sonnet** | Runtime singletons, IPC |
| `theming` | **sonnet** | Color pipeline, theme generators |
| `scripts` | **sonnet** | CLI, distribution, migrations |
| `niri` | **sonnet** | Compositor integration |
| `waffle` | **sonnet** | Waffle family UI |
| `reviewer` | **haiku** | Read-only code review |
| `scout` | **haiku** | Read-only search, blast radius, consumer counts |
| `checker` | **haiku** | Post-edit verification (restart + logs) |

### When to handle directly (Opus session)

- Architectural decisions and ambiguous requirements
- Changes under ~20 lines in a single file
- One-line fixes (agent spawn overhead > direct cost)
- Multi-agent task decomposition and final review

### When to delegate

- **Single domain work** → pick the domain agent (sonnet)
- **Code review** → `reviewer` (haiku)
- **Blast radius / dependency search** → `scout` (haiku)
- **Post-edit verification** → `checker` (haiku)
- **Stability boundary implementation** → `infra` (opus)

### Team templates (multi-agent)

**Full Feature** (spans 2+ domains): `scout` → domain agents in parallel → `reviewer` → `checker`
**Safe Refactor**: `scout` (map consumers) → `infra` or domain agent → `checker`
**Bug Fix**: `scout` (locate + trace) → domain agent (fix) → `checker`

## Mandatory Patterns

### 1. Config Read — ALWAYS optional chaining + fallback

```qml
// CORRECT
Config.options?.bar?.autoHide?.enable ?? false
Config.options?.appearance?.globalStyle ?? "material"

// WRONG — crashes if key missing
Config.options.bar.autoHide.enable
```

### 2. Config Write — ALWAYS setNestedValue

```qml
// CORRECT
Config.setNestedValue("bar.autoHide.enable", true)
Config.setNestedValue(["bar", "autoHide", "enable"], true)  // array path

// WRONG — not persisted
Config.options.bar.autoHide.enable = true
```

### 3. Config Sync Rule (CRITICAL)

When adding a new config key, update **all three together**:
1. `modules/common/Config.qml` — schema definition
2. `defaults/config.json` — default value
3. Consumer(s) — read/write the key + GUI in `modules/settings/` if user-facing

Also update together: `services/qmldir` when adding services, `modules/common/widgets/qmldir` when adding widgets.

### 4. Visual Tokens — NEVER hardcode

**ii family** uses `Appearance.*` tokens. **Waffle family** uses `Looks.*` tokens.

```qml
// CORRECT (ii)
color: Appearance.colors.colPrimary
radius: Appearance.rounding.normal

// WRONG
color: "#FF6200EE"
radius: 8
```

Token names use `col` prefix: `colPrimary`, `colLayer0`, `colOnSurface`. Names like `primary`, `surface`, `background` **do NOT exist**.

### 5. Style Dispatch — angel > inir > aurora > material

Five styles: `material`, `cards`, `aurora`, `inir`, `angel`. Cards is a material variant (no separate dispatch).

Use the boolean flags:
```qml
color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
     : Appearance.inirEverywhere ? Appearance.inir.colLayer1
     : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
     : Appearance.colors.colLayer1
```

Note: `auroraEverywhere` is true for BOTH aurora AND angel styles.

### 6. Compositor Guards

Never assume Niri. Hyprland support exists.

```qml
if (CompositorService.isNiri) { /* niri-only */ }
if (CompositorService.isHyprland) { /* hyprland-only */ }
```

### 7. IPC — explicit return types MANDATORY

```qml
IpcHandler {
    target: "myService"
    function getData(): string { return String(value) }   // OK
    function doThing(): void { /* ... */ }                 // OK
    function getData() { return "data" }                   // WRONG — no return type
}
```

Supported types: `string`, `int`, `bool`, `real`, `color`, `void`.

### 8. New QML Files

```qml
pragma ComponentBehavior: Bound  // ALWAYS first line

import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import "local-module"            // local imports last
```

- One component per file, PascalCase filename
- Prefer typed properties (`bool`, `int`, `string`, `list<string>`) over `var`
- `id: root` for the root element

For singletons, also add `pragma Singleton` and register in the appropriate `qmldir`.

### 9. Null Safety — EVERY service/config access

```qml
property var windows: NiriService.windows ?? []
property string name: NiriService.focusedWindow?.title ?? ""
```

## Widget API Gotchas

These inconsistencies cause silent failures:

| Widget | Icon property | WRONG property |
|---|---|---|
| `ConfigSwitch` | `buttonIcon` | ~~`icon`~~ (silently ignored) |
| `ConfigSpinBox` | `icon` | ~~`buttonIcon`~~ |
| `MaterialSymbol` | `text` | ~~`icon`~~ (icon name goes in `text`) |

`GlassBackground` requires `screenX` and `screenY` from parent via `mapToGlobal()` — without these, blur is misaligned.

`StyledRectangularShadow` must be placed BEFORE its target in z-order.

## Theming Pipeline

Colors flow: wallpaper image → `generate_colors_material.py` (matugen) → `colors.json` → `MaterialThemeLoader` → `Appearance` tokens → UI.

Theme generation scripts in `scripts/colors/`:
- `applycolor.sh` — orchestrator, runs all modules in parallel
- `modules/10-terminals.sh` through `60-sddm.sh` — per-app theming
- `lib/module-runtime.sh` — shared infrastructure (XDG paths, config reading)
- `targets/` — JSON manifests declaring what each module themes
- Go generators in `vscode_themegen/`, `zed_themegen/`, `opencode_themegen/` — built on-demand

## Migrations

Location: `sdata/migrations/` (numbered scripts: 001–018+).

**Rules**:
- Append-only — never rename, reorder, or delete existing migrations
- Idempotent — may run again if state is lost
- Next number: `019-descriptive-name.sh`
- All paths must be XDG-aware (`$XDG_CONFIG_HOME`, `$XDG_DATA_HOME`)

## Distribution

Two install modes tracked in `version.json`:
- **Repo-sync**: `./setup install` → symlinks to `~/.config/quickshell/inir/`
- **Package-managed**: `make install` → copies to `/usr/share/quickshell/inir/`

User config always lives at: `~/.config/illogical-impulse/config.json` (legacy namespace).

## Known Harmless Warnings

These log messages are safe to ignore:
- `Failed to create DBusObjectManagerInterface for "org.bluez"` — no Bluetooth adapter
- `failed to register listener: ...PolicyKit1...` — another polkit agent running
- `QSGPlainTexture: Mipmap settings changed` — Qt cosmetic
- `Cannot open: file:///...coverart/...` — missing album art cache
- `$HYPRLAND_INSTANCE_SIGNATURE is unset` — expected when running on Niri
