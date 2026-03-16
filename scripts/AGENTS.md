# Scripts — Scoped Agent Rules

This file applies to `scripts/`.

## Scope
- Shell, fish, and python helpers used by the runtime, setup, theming, and system integration flows.
- Script changes can affect installation, update, capture, daemon behavior, and external tooling.

## Required workflow
1. Read the script you will edit.
2. Find the caller if the script is invoked from QML, setup, or another script.
3. Confirm interpreter expectations and external tool assumptions.
4. Pass preflight before editing.
5. Verify the specific behavior after editing.

## Safety rules
- Prefer portable paths and environment-aware behavior.
- Avoid destructive filesystem operations unless explicitly required.
- Be careful with shell differences; fish syntax is not bash syntax.
- If dependencies change, consider whether packaging or docs must also change.
- Preserve executable expectations for distributed scripts.

## Completion standard
A script change is incomplete if you did not verify:
- caller expectations
- side effects
- runtime behavior or syntax as appropriate
