---
trigger: always_on
description: Hard invariants, safety rules, and verification requirements that apply to all iNiR tasks.
---

# Mandatory Rules — iNiR

## 1) Config read: ALWAYS `Config.options?.… ?? <fallback>`

`Config.options` is the only supported access point for config.

```qml
// Correct
Config.options?.bar?.autoHide?.enable ?? false
Config.options?.appearance?.globalStyle ?? "material"

// Wrong
Config.bar.autoHide.enable          // property does not exist
Config.options.bar.autoHide.enable  // can crash if key missing
```

## 2) Config write: ALWAYS `Config.setNestedValue(...)`

- Use `Config.setNestedValue("path.to.key", value)` or array-path.
- Do not assign into `Config.options` directly.

```qml
// Correct
Config.setNestedValue("bar.autoHide.enable", true)
Config.setNestedValue(["bar", "autoHide", "enable"], true)

// Wrong
Config.options.bar.autoHide.enable = true
```

### Schema sync rule (CRITICAL)

`setNestedValue` only persists keys that exist in the `Config.qml` JsonAdapter schema.

If you add a new config key, you MUST update together:

1. `modules/common/Config.qml` (schema)
2. `defaults/config.json` (distributed default)
3. Consumer(s) that read/write the key

## 3) Visual tokens: NEVER hardcode theme values

- **ii family**: use `Appearance.*` tokens (see `02-theming.md` / `design-system.md`).
- **waffle family**: use `Looks.*` tokens.

Common gotcha: tokens are `col*` names, not `primary/surface`.

## 4) Style dispatch: priority and flags

- Styles: `material`, `cards`, `aurora`, `inir`, `angel`.
- Dispatch priority: **angel > inir > aurora > material**.
- Cards is a material variant; it does not appear in ternary dispatch.

## 5) Compositor guards (Niri vs Hyprland)

Never assume compositor.

```qml
if (CompositorService.isNiri) { /* niri-only */ }
if (CompositorService.isHyprland) { /* hyprland-only */ }
```

## 6) IPC: explicit return types

IPC functions must declare return types.

```qml
IpcHandler {
    target: "audio"
    function volumeUp(): void { Audio.incrementVolume() }
    function getVolume(): string { return String(Audio.volume) }
}
```

Supported types: `string`, `int`, `bool`, `real`, `color`, `void`.

## 7) New QML files

- First line: `pragma ComponentBehavior: Bound`
- Prefer typed properties (`bool/int/real/string/list<string>`) over `var`.
- One component per file; PascalCase file names.
- Import order: Qt core → Quickshell → `qs.modules.common` → `qs.modules.common.widgets` → `qs.services` → local.

## 8) Danger zones: prefer add-only changes

Treat these as stability boundaries:

- `modules/common/Appearance.qml`
- `modules/common/Config.qml`
- `GlobalStates.qml`
- `services/Translation.qml`
- `modules/waffle/Looks.qml`

Prefer add-only changes; avoid renames/reshapes unless you confirm all dependents.

## 9) Sync groups: always update together

- `modules/common/Config.qml` ↔ `defaults/config.json`
- `services/qmldir` when adding services
- `modules/common/widgets/qmldir` when adding widgets
- `modules/<module>/qmldir` when adding module components

## 10) Verification after changes (required)

Restart + logs are mandatory for runtime changes:

```bash
inir restart
inir logs | tail -50
```

Then test the actual feature path (UI toggle / IPC call / persistence read-back).

Low-level fallback if the launcher is unavailable:

```bash
qs kill -c inir; qs -c inir
```

## 11) Public-surface follow-through (required)

If the change alters any public or distributed contract, update the collateral surfaces together:

- **Config/schema** → `modules/common/Config.qml` + `defaults/config.json` + consumer(s) + settings/migrations if needed
- **IPC/public callable behavior** → handler + caller(s) + `docs/IPC.md`
- **Dependencies / setup / scripts** → caller(s) + packaging/docs (`docs/PACKAGES.md`, distribution docs) when needed
- **User-visible shipped behavior** → ensure it is represented in changelog / release notes workflow

Release-prep tasks must keep `VERSION`, `CHANGELOG.md`, tag, and release notes in sync. Do not bump version or tag partially.

Known harmless warnings that are usually safe to ignore:

- `Failed to create DBusObjectManagerInterface for "org.bluez"` — no Bluetooth
- `failed to register listener: ...PolicyKit1...` — another polkit agent
- `QSGPlainTexture: Mipmap settings changed` — Qt cosmetic
- `Cannot open: file:///...coverart/...` — missing album art cache
- `$HYPRLAND_INSTANCE_SIGNATURE is unset` — running on Niri
- `qt.svg.draw: The requested buffer size is too big` — oversized SVG
- `qt.core.qfuture.continuations: Parent future has 2 result(s)` — Qt quirk
