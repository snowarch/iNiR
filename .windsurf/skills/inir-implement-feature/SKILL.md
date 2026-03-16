---
name: inir-implement-feature
description: Use when asked to add or modify an iNiR feature (QML modules/services) end-to-end. Covers mapping the authoritative layer (module/service/config), choosing ii vs waffle scope, using existing widgets/tokens, and delivering verified runtime behavior.
---

# iNiR — Implement Feature (end-to-end)

## Operating constraints (do not skip)

- Follow repo contract: `AGENTS.md` root + scoped `AGENTS.md`.
- Mandatory invariants: `.windsurf/rules/00-mandatory.md`.
- Use MCP gates for edits:
  - Pre: `mcp7_preflight_check(intent, files, evidence)`
  - Post: `mcp7_postchange_audit(changes, validationEvidence)`

## 1) Triage the request

Write down (briefly):

- **User outcome**: what changes visually/behaviorally.
- **Surface**: UI module vs service vs script vs config.
- **Scope**: `ii`, `waffle`, or both.
- **Risk**: danger zones? (`Config.qml`, `Appearance.qml`, `GlobalStates.qml`, `Translation.qml`, `Looks.qml`).

## 2) Find the authoritative implementation

Prefer this tool order:

1. `mcp7_search_codebase` for component names / IPC targets / config keys.
2. `mcp7_get_file_context` for top candidates.
3. `mcp7_get_blast_radius` / `mcp7_get_dependency_graph` when touching shared files.
4. `mcp7_find_examples` to reuse established patterns.
5. Read the real files (`mcp7_read_file` / `read_file`) before editing.

## 3) Decide where the logic belongs

- **If it is persistent user intent**: config (`Config.options` read, `Config.setNestedValue` write).
- **If it touches system/compositor/network/audio/fs**: service singleton.
- **If it is presentation/interaction**: module UI.
- **If it is heavy repeated UI**: widget in `modules/common/widgets`.

Avoid moving logic across layers unless necessary.

## 4) Implement with iNiR patterns

- **Config read**: `Config.options?.… ?? fallback`.
- **Config write**: `Config.setNestedValue("path.to.key", value)`.
- **Theming**:
  - ii family: `Appearance.*` tokens only (no hardcoded colors).
  - waffle family: `Looks.*`.
  - Style priority: angel > inir > aurora > material.
- **Compositor guards**: never assume Niri vs Hyprland.
- **IPC**: explicit return types.

## 5) Sync groups (if applicable)

- New config key: update together
  - `modules/common/Config.qml`
  - `defaults/config.json`
  - consumers

## 6) Verification (required for runtime changes)

- Restart: `inir restart`
- Logs: `inir logs | tail -50` (no new errors)
- Feature test: exercise the exact changed flow (UI toggle / launcher IPC call / persistence read-back).

If errors appear, investigate and fix before concluding.
