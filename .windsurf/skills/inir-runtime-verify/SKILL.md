---
name: inir-runtime-verify
description: Use when a task involves verifying or debugging iNiR runtime behavior after QML/service/config changes. Provides the minimum restart+logs+feature-test bar and common failure triage.
---

# iNiR — Runtime Verification & Debugging

## Minimum verification bar (required)

1. Restart:
   - `inir restart`
2. Logs:
   - `inir logs | tail -50`
   - Look for: `TypeError`, `ReferenceError`, QML binding loops, missing imports, target not found.
3. Feature test:
   - Execute the exact UI/IPC flow that changed.

## Common iNiR failure modes

- **Config key not persisting**:
  - Key missing in `Config.qml` schema.
  - Consumer reads without `?.` and crashes on older configs.
- **Panel not loading**:
  - `enabledPanels` missing identifier.
  - `extraCondition` false (e.g. vertical bar).
  - `Config.ready` gating.
- **Theme regressions**:
  - Hardcoded colors.
  - Wrong token names (missing `col*` prefix).
  - Style dispatch ordering violated.
- **Waffle mismatch**:
  - Used `Appearance` where `Looks` should be used (or vice versa).

## Debugging discipline

- Reproduce once, then instrument with narrow logs.
- Prefer root-cause fixes (schema sync, optional chaining, correct import order).
- Do not ship with new errors in logs.
