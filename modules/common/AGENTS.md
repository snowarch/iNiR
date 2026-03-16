# Modules/Common — Scoped Agent Rules

This file applies to `modules/common/` and its children.

## Why this directory is special
- `modules/common/` contains shared infrastructure used across the shell.
- Many files here have very high blast radius.
- A small mistake here can break multiple modules at once.

## Critical boundaries
Treat these as stability boundaries:
- `modules/common/Appearance.qml`
- `modules/common/Config.qml`
- shared widgets used widely across the UI
- shared helper singletons or theme primitives

## Required behavior
- Read the file fully or the authoritative relevant section before editing.
- Check who uses the file when the change is not obviously local.
- Prefer add-only changes to shared APIs.
- Avoid renaming or reshaping widely-used properties unless a verified bug fix requires it.
- If you touch config schema, keep `defaults/config.json` aligned.

## Verified patterns
- Config reads use `Config.options?.path?.to?.prop ?? default`.
- Config writes use `Config.setNestedValue("path.to.prop", value)`.
- Visual tokens come from `Appearance` in ii-family components.
- Shared widgets should stay generic and reusable instead of embedding feature-specific assumptions.

## Widget discipline
- Before creating a new shared widget, confirm an existing widget cannot be reused or lightly extended.
- Keep shared widget APIs minimal and stable.
- Do not leak feature-specific naming or business logic into shared primitives.

## Completion standard
A change in `modules/common/` is not complete until:
- downstream usage risk was considered
- sync groups were updated if needed
- APIs were verified
- runtime/log verification was done
