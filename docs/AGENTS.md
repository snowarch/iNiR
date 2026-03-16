# Docs — Scoped Agent Rules

This file applies to `docs/`.

## Scope
- `docs/` is the canonical user-facing documentation source for the repo.
- Documentation here should describe the real product, not temporary implementation chatter.

## Authoring rules
- Prefer short, direct, verifiable instructions.
- Keep docs aligned with actual runtime behavior and code.
- If code and docs disagree, update docs from verified code, not from memory.
- Avoid duplicating the same rule in many docs when one canonical location is enough.
- Preserve the documented tone of each doc family where applicable.

## Governance-specific rule
- `AGENTS.md`, `.windsurf/rules/`, and `.windsurf/workflows/` define agent behavior.
- User docs in `docs/` should reference those systems only when the user or contributor actually needs to know about them.
- Do not leak internal agent-only process into end-user docs unless it serves contributors explicitly.

## Completion standard
A docs change is incomplete if:
- it cannot be traced to real behavior
- it duplicates a more canonical source unnecessarily
- it leaves contradictory instructions elsewhere
