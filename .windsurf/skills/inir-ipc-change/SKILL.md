---
name: inir-ipc-change
description: Use when adding/modifying IPC targets or functions in iNiR. Ensures explicit return types, stable naming, and runtime verification via the inir launcher or low-level qs IPC calls.
---

# iNiR — IPC Change (targets + functions)

## Rules

- IPC functions must declare explicit return types: `string | int | bool | real | color | void`.
- Keep targets/functions stable (bindings and docs depend on them).

## 1) Locate the authoritative handler

- Use `mcp7_find_examples` for `IpcHandler { target:`.
- Read the owning module/service file.

## 2) Implement

- Add function with explicit return type.
- If it calls compositor/system behavior, ensure compositor guards.

## 3) Verify

- Restart shell if you touched startup/singletons:
  - `inir restart`
- Call IPC directly:
  - `inir <target> <function> [args]`
  - low-level fallback: `qs -c inir ipc call <target> <function> [args]`
- No output = success. "Target not found" or errors in logs = broken.

Use MCP gates:

- Pre: `mcp7_preflight_check(intent, files, evidence)`
- Post: `mcp7_postchange_audit(changes, validationEvidence)`
