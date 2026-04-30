# scripts/setup/

Recipes that back the launcher's `/setup-*` actions. Each `*.sh` file in this
directory is one recipe and is expected to be self-contained, idempotent and
distro-aware.

## How it wires up

```
launcher  ◀── auto-discover ──  scripts/setup/<slug>.sh
   │                                │ @meta name / description / icon / keywords
   │                                └─ sources _lib.sh
   ▼
GlobalActions._setupTargets   (rebuilt reactively when the folder changes)
```

A recipe becomes a launcher action **the moment its script lands in this
directory.** Discovery is driven by a `FolderListModel` watching
`scripts/setup/*.sh`; on every folder mutation it invokes `_scan.sh`, which
emits a JSON array of recipe metadata that QML parses with one
`JSON.parse`. No QML changes are needed and the shell does not have to be
restarted — adding, editing, or removing a `.sh` file is a pure filesystem
operation.

Files whose basename starts with `_` (e.g. `_lib.sh`, `_template.sh.example`,
`_scan.sh`) are never registered as actions, so they are safe to use for
shared helpers.

You can run the scanner by hand to debug what the launcher will see:

```bash
bash scripts/setup/_scan.sh | jq .
```

## Adding a recipe

1. `cp _template.sh.example <slug>.sh`.
2. Edit the `@meta` header and the body of the script.
3. `chmod +x <slug>.sh`.

That's it — the action `/setup-<slug>` is now live.

## Updating a recipe

Edit the `.sh` file. Scripts are read from disk on every invocation, so the
new behavior takes effect immediately. Editing `@meta` headers also takes
effect immediately — the next folder mutation triggers a re-scan, or you can
`touch <slug>.sh` to force one.

Keep changes idempotent — users will rerun setup when something breaks.

## Renaming or removing a recipe

Just rename or delete the `.sh` file. The launcher picks up the change on
the next folder mutation event.

## `@meta` header format

Optional, all fields default to a sensible value derived from the slug.

| Field | Default | Notes |
|-------|---------|-------|
| `name` | `Setup <Slug>` (capitalized) | Display name shown in the launcher. |
| `description` | `Run the <slug> setup recipe` | One-line description. |
| `icon` | `download` | Material Symbols name. |
| `keywords` | `<slug>` | Whitespace-separated extra search terms. The launcher auto-adds `setup`, `install`, and the slug, so don't list them again. |

Headers must appear in the first 60 lines of the file (the awk scanner
short-circuits past that for performance). The line format is exact:

```
# @meta <field>: <value>
```

## `_lib.sh` API

Source it once at the top of every recipe; everything below is then
available.

| Helper | Purpose |
|--------|---------|
| `setup_init <slug> <title>` | Required first call. Sets the notification tag, installs an `ERR` trap, prints the recipe banner and emits the initial "Starting…" bubble. |
| `setup_progress <step> <total> <msg>` | Print a `[step/total] msg` line and replace the notification bubble. |
| `setup_done [msg]` | Print a green check and emit the success bubble (`emblem-ok-symbolic`). |
| `setup_fail [msg]` | Print a red cross and emit the failure bubble (`dialog-error`). The `ERR` trap calls this automatically on uncaught errors. |
| `setup_notify <body> [icon]` | Low-level: emits/replaces the bubble with arbitrary text. Use the wrappers above whenever possible. |
| `setup_finish_pause` | Prompts the user to press Enter so the terminal stays open after `set -e` would otherwise close it. Always call this last. |
| `is_arch_like` | True for `arch`, `endeavouros`, `cachyos`, `manjaro`, `garuda`, `artix` (matches both `ID` and `ID_LIKE`). |
| `have_cmd <name>` | True if the binary is on `PATH`. |
| `ensure_aur_helper` | Echoes `yay` or `paru` if present; otherwise bootstraps `yay-bin` from the AUR. Used internally by `install_arch`. |
| `install_arch <repo…> [-- <aur…>]` | Pacman install for repo packages, AUR helper for anything after a literal `--`. `--needed --noconfirm` is implied. |
| `install_flatpak <ref…>` | Adds Flathub (user-scope) on demand and installs the given refs. Fails loudly if `flatpak` is missing. |

Constants exposed after sourcing: `DISTRO_ID`, `DISTRO_LIKE`, `SETUP_TAG`,
`SETUP_TITLE`.

## Conventions

- **Shebang:** `#!/usr/bin/env bash`.
- **Strict mode:** `set -Eeuo pipefail` immediately after the shebang.
- **Source `_lib.sh` via `$BASH_SOURCE` dirname**, not via a hardcoded path —
  recipes must work whether the user runs them via the launcher, by hand,
  or symlinked.
- **Always call `setup_init` before any work** so the `ERR` trap is armed.
- **Always end with `setup_finish_pause`** so the terminal window doesn't
  flash and disappear.
- **Use `setup_progress` with a fixed `TOTAL`** at the top of each branch so
  users see deterministic step counters.
- **Idempotency:** prefer `--needed`, `if-not-exists`, etc. so reruns are
  cheap. Don't blindly `rm -rf` user state.
- **No hardcoded `sudo` password prompts**, no piping `yes` into pacman.
  `install_arch` already passes `--noconfirm`; let sudo prompt the user
  interactively in the terminal.
- **Log warnings to stderr (`>&2`), not just stdout.** Failure paths that
  the user can recover from manually should print actionable instructions.
- **One concern per script.** If a recipe grows beyond ~80 lines, factor a
  helper into `_lib.sh` instead of duplicating logic.
