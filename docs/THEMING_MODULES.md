# Theming Modules

## Goal

`applycolor.sh` is the theming orchestrator.
It auto-discovers modules in `scripts/colors/modules/` and runs them in filename order.

This keeps the shell product understandable:

- `switchwall.sh`
- generates palette artifacts
- `applycolor.sh`
- fans those artifacts out to modules
- each module owns one integration surface

## Module contract

A module is a single shell file in `scripts/colors/modules/`.

Examples:

- `10-terminals.sh`
- `20-gtk-kde.sh`
- `30-editors.sh`
- `40-chrome.sh`
- `50-spicetify.sh`
- `60-sddm.sh`
- `70-steam.sh`

Rules:

- it must source `scripts/colors/lib/module-runtime.sh`
- it should exit `0` when its target is disabled or missing
- it should only own one integration area
- it should be safe to run after any wallpaper regeneration

## Shared runtime

`module-runtime.sh` provides:

- XDG/config/state paths
- `CONFIG_FILE`
- `STATE_DIR`
- `SCRIPT_DIR`
- `config_bool()`
- `config_json()`
- `venv_python()`
- `log_module()`

## How contributors add a new theming module

1. Create `scripts/colors/modules/NN-name.sh`
2. Source `lib/module-runtime.sh`
3. Gate it with config and dependency checks
4. Read palette artifacts from `~/.local/state/quickshell/user/generated/`
5. Exit cleanly when not applicable
6. Do not edit `applycolor.sh`

## Product boundary

The theming core should stay small:

- palette generation belongs in `switchwall.sh` + generators
- fan-out belongs in `applycolor.sh`
- integrations belong in modules

That split is what keeps iNiR maintainable as a Linux shell product instead of a pile of ad-hoc scripts.
