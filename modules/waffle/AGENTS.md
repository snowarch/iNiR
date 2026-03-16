# Modules/Waffle — Scoped Agent Rules

This file applies to `modules/waffle/` and its children.

## Scope
- `modules/waffle/` contains the Windows 11-style family.
- It is large and style-specific.
- Do not assume an ii-family pattern can be copied into waffle unchanged.

## Family rules
- Prefer `Looks.*` and waffle-native patterns for visuals and layout.
- Only use shared `Appearance` values when the existing waffle code already does so intentionally.
- Preserve family identity; do not accidentally make waffle behave like ii.

## Change discipline
- Read the target waffle component and nearby waffle siblings before editing.
- Check whether the request affects waffle settings pages, shell panels, or shared family transitions.
- Be careful with layout density, spacing, and visual chrome, because waffle relies heavily on composition.

## Cross-family rule
- If the user asks for a whole-feature change, determine whether waffle needs a parallel implementation or an explicit non-applicability decision.
- Do not silently fix only ii when the request obviously spans both families.

## Completion standard
A waffle change is incomplete if you did not verify:
- family-specific visuals
- interaction behavior
- compatibility with the family switching flow when relevant
