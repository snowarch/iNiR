---
name: inir-config-change
description: Use when adding/modifying iNiR configuration keys, defaults, or settings UI. Enforces schema/default sync groups and persistence verification.
---

# iNiR — Config Change (schema + defaults + consumers)

## Non-negotiable rules

- Read: `Config.options?.… ?? fallback`
- Write: `Config.setNestedValue(...)`
- Schema sync: new keys must exist in `modules/common/Config.qml` JsonAdapter schema or writes will not persist.

## 1) Identify the key path and owner

- Decide the canonical key path (`section.subsection.key`).
- Identify all consumers (UI modules/services/settings).

Use:

- `mcp7_get_config_schema(section?)` to see existing structure.
- `mcp7_find_examples` for similar keys.

## 2) Implement the sync group

Update together:

1. `modules/common/Config.qml` — add property in schema (correct type)
2. `defaults/config.json` — add distributed default
3. Consumer code — read with optional chaining + fallback
4. Settings UI (if exposed) — use existing config widgets

## 3) Safety checks

- Never break old configs: always `?.` + `??` fallbacks.
- If changing type/shape, prefer add-only migration strategy.

## 4) Verification

- Toggle/write the value through the UI/service.
- Confirm **persistence** by reading back the real user config:
  - `~/.config/illogical-impulse/config.json`
- Restart + check logs if you changed Config/schema or any singleton.

Use MCP gates:

- Pre: `mcp7_preflight_check(intent, files, evidence)`
- Post: `mcp7_postchange_audit(changes, validationEvidence)`
