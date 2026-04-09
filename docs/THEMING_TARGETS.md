# Theming Targets

This document explains the first modular layer of the iNiR theming system.

## Goal

Users and contributors should be able to understand:

- which theming targets exist
- which generated inputs they consume
- how to apply a specific target
- how to add a new app integration without understanding the whole pipeline

## Current model

The theming pipeline has two phases:

1. **Palette generation**
   - `switchwall.sh`
   - `generate_colors_material.py`
   - `ThemePresets.qml`

2. **Target application**
   - `scripts/colors/applycolor.sh`
   - target modules under `scripts/colors/modules/`

The new modular layer adds **target manifests** under:

- `scripts/colors/targets/*.json`

Each manifest declares:

- stable target id
- backing module script
- category
- expected inputs
- high-level description

## Listing targets

```bash
inir theme list-targets
```

Output columns:

- `id`
- `label`
- `category`
- `module`
- `inputs`

## Inspecting a target

```bash
inir theme inspect terminals
```

This prints:

- manifest metadata
- backing module path
- whether the module exists
- whether it is executable
- resolved generated input paths

## Validating targets

Validate all declared targets:

```bash
inir theme doctor
```

Validate one target:

```bash
inir theme doctor editors
```

The doctor currently checks:

- manifest parseability
- backing module existence
- module executability
- declared generated inputs
- current config gate value when the target declares a `configKey`

## Applying targets selectively

Apply one target:

```bash
inir theme apply terminals
```

Apply several:

```bash
inir theme apply gtk-kde editors chrome
```

Apply all declared targets:

```bash
inir theme apply all
```

## Scaffolding a new target

Create a new target skeleton:

```bash
inir theme scaffold myapp
```

Example with custom metadata:

```bash
inir theme scaffold myapp \
  --label "My App" \
  --category custom \
  --inputs palette.json terminal.json \
  --config-key appearance.wallpaperTheming.enableAppsAndShell
```

If you do not pass `--inputs`, the scaffold now defaults to:

```text
palette.json
```

Use `terminal.json` or `material_colors.scss` only when the target really needs terminal/ANSI data.

This creates:

- `scripts/colors/targets/myapp.json`
- `scripts/colors/modules/70-myapp.sh`

The scaffold refuses to overwrite existing files.

## Declared targets today

- `gtk-kde`
- `terminals`
- `editors`
- `chrome`
- `spicetify`
- `sddm`
- `steam` — Adwaita-for-Steam Material You CSS

Current declared input model:

- palette-first targets: `gtk-kde`, `chrome`, `spicetify`, `sddm`, `steam`
- terminal-first targets: `terminals`
- mixed targets: `editors`

## Inputs

Current generated inputs are still:

- `~/.local/state/quickshell/user/generated/colors.json`
- `~/.local/state/quickshell/user/generated/material_colors.scss`
- `~/.local/state/quickshell/user/generated/palette.json`
- `~/.local/state/quickshell/user/generated/terminal.json`
- `~/.local/state/quickshell/user/generated/theme-meta.json`

Today:

- `colors.json` and `material_colors.scss` remain compatibility inputs used by current targets
- `palette.json`, `terminal.json`, and `theme-meta.json` are the new explicit contracts for future target work

This lets the target layer evolve without forcing a big-bang rewrite of existing integrations.

## Adding a new app target

### 1. Create the module

Add a script under:

- `scripts/colors/modules/<nn>-<name>.sh`

The module should:

- read the generated inputs it needs
- respect config toggles when appropriate
- generate/apply the app-specific output
- exit cleanly when the app is not installed or the integration is disabled

### 2. Create the manifest

Add:

- `scripts/colors/targets/<id>.json`

You can also generate both files automatically with:

```bash
inir theme scaffold <id>
```

Example:

```json
{
  "id": "myapp",
  "label": "My App",
  "module": "70-myapp.sh",
  "category": "custom",
  "inputs": ["palette.json"],
  "description": "Apply generated iNiR palette to My App.",
  "configKey": "appearance.wallpaperTheming.enableAppsAndShell"
}
```

### 3. Verify it

List targets:

```bash
inir theme list-targets
```

Apply only your target:

```bash
inir theme apply myapp
```

Inspect the generated target:

```bash
inir theme inspect myapp
```

Doctor-check it:

```bash
inir theme doctor myapp
```

## Design intent

This is the first compatibility slice, not the final architecture.

It deliberately does **not** replace the current pipeline yet.
Instead it gives iNiR:

- explicit target discovery
- selective apply
- a clearer mental model for contributors
- a migration path away from ad-hoc module discovery

Future work can build on this to add:

- stable palette schemas
- generator/apply separation per target
- `doctor`-style validation per target
- scaffolding for new app integrations

## Architecture summary

Today the modular layer is:

1. **Palette generation**
   - produces generated inputs under `~/.local/state/quickshell/user/generated/`
2. **Target manifests**
   - declare what each integration is and which generated inputs it expects
3. **Target modules**
   - the real implementation scripts that generate or apply app-specific output
4. **CLI layer**
    - `inir theme list-targets`
    - `inir theme inspect <id>`
    - `inir theme doctor [id]`
    - `inir theme scaffold <id>`
    - `inir theme apply <ids...|all>`

This means contributors can now reason about theming by target, instead of reverse-engineering the entire apply pipeline first.
