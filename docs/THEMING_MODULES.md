# Theming Modules

A module is one shell script in `scripts/colors/modules/` that themes one app. `applycolor.sh` runs it through its target manifest. The modules and their targets are listed in [Theming Targets](THEMING_TARGETS.md).

## How they run

- A module runs only when a manifest names it: one in `scripts/colors/targets/`, or one an installed plugin brings in `modules/<plugin>/colors/targets/` (its module beside it in `colors/modules/`). Once any manifest exists, a module that no manifest names never runs.
- `applycolor.sh` skips the whole run when the generated files, config, scripts and app installs are unchanged. `--force` or `INIR_THEME_FORCE=1` runs it anyway.
- Enabled modules run in parallel under `nice` and `ionice`, two to four at a time: half your CPUs by default, and `INIR_THEME_MAX_JOBS` overrides it.
- Runs take a lock (`applycolor.lock`, waiting up to 120 s). Each module logs to `~/.local/state/quickshell/user/generated/theming_modules.log`, tagged with its target id.

## Module contract

- File name `NN-name.sh`, one integration area per module.
- Source `scripts/colors/lib/module-runtime.sh` first, and set `COLOR_MODULE_ID` so the log names the target.
- Gate on the config key with `config_bool`. Exit 0 when the key is off, or the app or its files are missing.
- Read palette files from `~/.local/state/quickshell/user/generated/`, not from the wallpaper.
- Do not edit `applycolor.sh`.

## Shared runtime

`module-runtime.sh` sets `SCRIPT_DIR`, `STATE_DIR` (`$XDG_STATE_HOME/quickshell`), `CONFIG_FILE`, `TARGETS_DIR`, `MODULES_DIR` and `PLUGINS_DIR`, and exports its own path as `INIR_COLOR_RUNTIME` for a plugin's module to source. Its helpers include:

- `config_bool '<jq path>' <fallback>`, for example `.appearance.wallpaperTheming.enableChrome`.
- `log_module`, `write_if_changed` and `theme_mode`, which returns `dark` or `light` from `theme-meta.json`.

## Adding a module

Scaffold the target with `inir theme scaffold <id>`. It writes the manifest and a stub module. See [Theming Targets](THEMING_TARGETS.md).
