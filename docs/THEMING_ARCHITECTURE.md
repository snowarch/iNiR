# Theming Architecture

This document describes the current iNiR theming pipeline at a high level.

## Pipeline overview

The theming system has two big stages:

1. **Palette generation**
2. **Target application**

## 1. Palette generation

Inputs can come from:

- wallpaper image
- explicit seed color
- manual preset theme
- dark/light mode choice
- palette type / scheme variant

Main generators today:

- `scripts/colors/switchwall.sh`
- `scripts/colors/generate_colors_material.py`
- `modules/common/ThemePresets.qml`

Main generated artifacts today:

- `~/.local/state/quickshell/user/generated/colors.json`
- `~/.local/state/quickshell/user/generated/material_colors.scss`
- `~/.local/state/quickshell/user/generated/palette.json`
- `~/.local/state/quickshell/user/generated/terminal.json`
- `~/.local/state/quickshell/user/generated/theme-meta.json`

## 2. Target application

Target application consumes the generated artifacts and writes app-specific outputs.

Current orchestrators:

- `scripts/colors/applycolor.sh`
- `scripts/colors/apply-targets.sh`

Target metadata lives in:

- `scripts/colors/targets/*.json`

Target implementations live in:

- `scripts/colors/modules/*.sh`

## Runtime authority

Important practical rule:

- `colors.json` is the runtime shell/UI palette authority
- `material_colors.scss` is still a compatibility input for terminal/editor targets
- `palette.json` is the explicit shell palette contract for future target consumers
- `terminal.json` is the explicit terminal palette contract for future target consumers
- `theme-meta.json` carries generation metadata such as source, mode, scheme, and generator
- `generate_colors_material.py` is the single authoritative palette generator — it handles
  both Material You color extraction AND template rendering (GTK, fuzzel, KDE, etc.)

Current state:

- `matugen` has been removed as a dependency — all color generation and template rendering
  is handled by Python (`materialyoucolor` library + built-in template engine)
- templates use `{{colors.token.mode.hex}}` syntax (compatible with former matugen templates)
- template manifest: `defaults/matugen/templates.json` (declares input/output paths)
- first shell/UI consumers now prefer `palette.json` and fall back to `colors.json`
- terminal/editor generators and terminal escape-sequence application now prefer `terminal.json` + `palette.json` and keep `material_colors.scss` as compatibility fallback
- browser mode detection now prefers `theme-meta.json` instead of scraping SCSS state
- new scaffolded targets now default to `palette.json` as their declared input
- the existing Go VSCode generator now also consumes `terminal.json` explicitly instead of relying only on SCSS for ANSI data
- the editors target now has a small shared Go theming core used by both VSCode and OpenCode generators
- the migration remains compatibility-first, not big-bang

## Current target model

Each target manifest declares:

- `id`
- `label`
- `module`
- `category`
- `inputs`
- `description`
- optional `configKey`

This is the first compatibility slice of the modular system.

## Near-term direction

The intended next improvements are:

- stronger `doctor` checks per target
- target scaffolding for new integrations
- migrate target consumers from compatibility files toward the explicit generated contracts
- cleaner separation between `generate`, `apply`, and `reload`

A compiled-language migration (Go themegen) is partially in place for some targets. See `scripts/colors/system24_themegen/` for the current Go generator.
