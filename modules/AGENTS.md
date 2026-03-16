# Modules — Scoped Agent Rules

This file applies to `modules/` and its children unless a deeper `AGENTS.md` overrides it.

## What modules are in iNiR
- `modules/` contains the user-facing UI surface of the shell.
- Most requests touching `modules/` are visible, interaction-heavy, and style-sensitive.
- A module change can require companion updates in config, shared widgets, services, or docs.

## Expectations when working in modules
- Treat the request as user-facing behavior, not isolated code.
- Consider both panel families when relevant.
- Consider all global styles when visuals or layout are involved.
- Check loading, empty, disabled, hover, active, and overflow states when appropriate.

## Required workflow
1. Find the authoritative component and its nearby consumers.
2. Read the actual files you will touch.
3. Search for similar module patterns first.
4. Verify singleton and config APIs before using them.
5. Pass preflight before editing.
6. Verify runtime and the exact visible behavior after editing.

## Design rules
- Prefer existing shared widgets from `modules/common/widgets/` over new bespoke implementations.
- Keep visual tokens consistent with the owning family: `Appearance` for ii, `Looks` for waffle.
- Respect user settings such as animation and transparency preferences.
- Do not make the UI more repetitive or heavier unless the request explicitly calls for it.

## Completion standard
A module task is incomplete if any of the following were skipped:
- affected style/family review
- config compatibility review
- overflow and state handling review
- runtime/log verification
- direct feature test
