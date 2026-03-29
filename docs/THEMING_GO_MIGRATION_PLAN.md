# Theming Go Migration Plan

This document defines the current Go migration strategy for the iNiR theming subsystem.

## Current reality

The theming system is now partially normalized around explicit generated contracts:

- `palette.json`
- `terminal.json`
- `theme-meta.json`

Compatibility outputs still exist:

- `colors.json`
- `material_colors.scss`

Go already exists in the theming pipeline today via:

- `scripts/colors/vscode_themegen/main.go`

That generator is now a real proof point because it consumes:

- palette data
- terminal data
- SCSS fallback

and is exercised by the real `editors` target.

## Decision

Do **not** rewrite the whole theming pipeline to Go at once.

Instead:

1. keep the current Python core palette generation for now
2. migrate pure transform/generator targets to Go incrementally
3. only reconsider the Python palette core after the contract migration is complete

## Why this is the right split

### Keep Python for now

These remain poor immediate rewrite targets:

- `generate_colors_material.py`
- `scheme_for_image.py`

Why:

- they still depend on Python-native/image-native ecosystem pieces
- they encode the shell's real Material generation behavior today
- regressions here would hit the whole product, not one target

### Good Go targets now

These are strong next candidates because they are mostly deterministic transform/generate steps:

- `system24_palette.py`
- `zed/theme_generator.py`
- `opencode/theme_generator.py`
- selective pieces of `generate_terminal_configs.py`

Why:

- they mostly consume normalized JSON contracts
- they mostly emit config/theme files
- they are easier to test in isolation
- they benefit from a single static binary approach

## Recommended phases

## Phase 1 — stabilize contract migration

Before more Go work, ensure targets prefer:

- `palette.json`
- `terminal.json`
- `theme-meta.json`

and only fall back to:

- `colors.json`
- `material_colors.scss`

Success criteria:

- target manifests match actual inputs
- `theme doctor` reflects real dependencies
- explicit contracts are enough to generate most target outputs

## Phase 2 — expand the existing Go lane

Next concrete Go targets:

### 1. Vesktop/system24

Migrate:

- `scripts/colors/system24_palette.py`

Status:

- done via `scripts/colors/system24_themegen/main.go`
- invoked through stable wrapper `scripts/colors/system24_palette.sh`

Reason:

- palette-only input
- pure file generation
- no runtime-critical shell logic

### 2. OpenCode theme generator

Migrate:

- `scripts/colors/opencode/theme_generator.py`

Reason:

- deterministic mapping from palette/terminal tokens to JSON theme
- already close to the VSCode-style transform shape

Status:

- done via `scripts/colors/opencode_themegen/main.go`
- editors target now prefers the Go binary and falls back to Python

### 3. Zed theme generator

Migrate:

- `scripts/colors/zed/theme_generator.py`

Reason:

- also mostly deterministic generation from palette + terminal data
- more complex than OpenCode, but still a reasonable Go target after Vesktop/OpenCode

## Phase 3 — extract terminal generator helpers

Do not rewrite `generate_terminal_configs.py` wholesale first.

Instead, peel off the pure generation pieces that already consume:

- `terminal.json`
- `palette.json`

Possible shape:

- a Go helper library or binary that renders terminal configs
- shell modules remain orchestrators during transition

## What should *not* move to Go yet

- `generate_colors_material.py`
- `scheme_for_image.py`
- `switchwall.sh` orchestration

Not yet, because the highest value right now is contract cleanup and target isolation, not replacing the palette core.

## Concrete next Go milestone

The next best Go implementation target is:

- `system24_palette.py`

because it is:

- already contract-driven
- isolated
- user-visible
- easy to verify
- low blast radius compared to the palette core

## Verification rule for any Go migration

A theming rewrite to Go is incomplete unless it verifies:

1. generated output matches the previous target behavior closely enough
2. target-specific application still works through the real target module
3. fallback/compatibility behavior remains intact during transition

This keeps the Go migration product-first instead of language-first.
