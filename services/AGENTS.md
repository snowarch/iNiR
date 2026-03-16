# Services — Scoped Agent Rules

This file applies to `services/`.

## What lives here
- Runtime singletons
- External integrations
- IPC surfaces
- Background polling, state, and persistence helpers

## Why this directory is risky
A service change can affect startup, global state, multiple UI consumers, and user system interactions.

## Required workflow
1. Read the service you will change.
2. Verify its public API with MCP if the change is not purely local.
3. Check usage/dependents when changing behavior.
4. Check side effects: filesystem, commands, timers, polling, external programs, compositor assumptions.
5. Pass preflight before editing.
6. Restart and inspect logs after editing.

## Service rules
- Follow the real singleton/service pattern already used by the project.
- Keep `services/qmldir` aligned if you add new services.
- Be explicit and stable with IPC targets and return types.
- Handle missing data or missing dependencies gracefully.
- Avoid surprising background side effects.

## Completion standard
A service task is incomplete if you skipped:
- dependency/consumer review
- side-effect review
- startup/log verification
- feature-path verification
