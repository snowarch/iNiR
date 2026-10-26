# Theming Targets

A target is one app integration. It has a manifest in `scripts/colors/targets/<id>.json` and a module in `scripts/colors/modules/`. The `inir theme` command lists, checks, applies and scaffolds them.

## Declared targets

The gate is the `configKey` under `appearance.wallpaperTheming`. `applycolor.sh` skips a target while its gate is `false`. `module` means the module checks its own key.

| Target | Module | Gate | Reads |
|---|---|---|---|
| `gtk-kde` (GTK, KDE, Qt) | `20-gtk-kde.sh` | `enableAppsAndShell` | `app-palette.json`, `palette.json` |
| `terminals` | `10-terminals.sh` | `enableTerminal` | `app-palette.json`, `palette.json`, `terminal.json`, `material_colors.scss` |
| `editors` (VSCode, OpenCode, Neovim) | `30-editors.sh` | module | `app-palette.json`, `palette.json`, `terminal.json`, `material_colors.scss` |
| `zed` | `31-zed.sh` | `enableZed` | `app-palette.json`, `palette.json`, `terminal.json`, `material_colors.scss` |
| `chrome` (Chromium family) | `40-chrome.sh` | module | `app-palette.json`, `palette.json`, `theme-meta.json` |
| `firefox` (Firefox family) | `45-firefox.sh` | module | `app-palette.json` |
| `spicetify` | `50-spicetify.sh` | `enableSpicetify` | `app-palette.json`, `palette.json` |
| `sddm` | `60-sddm.sh` | `enableAppsAndShell` | `app-palette.json`, `palette.json` |
| `steam` | `70-steam.sh` | `enableSteam` | `app-palette.json`, `palette.json`, `colors.json` |
| `pear-desktop` | `80-pear-desktop.sh` | `enablePearDesktop` | `app-palette.json`, `palette.json`, `colors.json` |
| `limusic` | `85-limusic.sh` | module | `app-palette.json`, `palette.json`, `colors.json` |
| `cava` | `90-cava.sh` | `enableCava` | `palette.json` |
| `claude-code` | `95-claude-code.sh` | `enableClaudeCode` | `terminal.json`, `palette.json`, `theme-meta.json` |

The toggles are in Material Settings › Advanced › Color. iRiS Settings has its own App colours group. Vesktop has no target: `ThemeService` runs `system24_palette.sh` for it.

## Commands

```bash
inir theme list-targets          # id, label, category, module, inputs
inir theme inspect terminals     # manifest, module path, inputs that exist
inir theme doctor [id]           # errors on a missing module; warns on missing inputs, a non-executable module or a gate that is off
inir theme apply <id...|all>     # runs the modules now, ignoring the configKey gate
inir theme scaffold <id>         # writes a manifest and a stub module, never overwrites
```

`scaffold` takes `--label`, `--category` (default `custom`), `--inputs` (default `app-palette.json palette.json`), `--config-key` (default `appearance.wallpaperTheming.enableAppsAndShell`), `--index` (the module number, default `70`), `--module` and `--description`.

## Adding a target

1. Run `inir theme scaffold myapp --label "My App" --inputs palette.json`.
2. Fill in `scripts/colors/modules/70-myapp.sh`. Read the palette from `~/.local/state/quickshell/user/generated/` and write the app's files.
3. Run `inir theme doctor myapp`, then `inir theme apply myapp`.

Declare only `palette.json` unless the app needs ANSI colours. Then add `terminal.json` or `material_colors.scss`.
