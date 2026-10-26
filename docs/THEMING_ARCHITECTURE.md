# Theming Architecture

Theming runs in two stages. `switchwall.sh` writes palette files to `~/.local/state/quickshell/user/generated/`, then `applycolor.sh` hands them to each app.

## Palette generation

- Inputs: a wallpaper (`switchwall.sh --image`), a seed colour (`--color`), light or dark (`--mode`), a scheme (`--scheme`), and iRiS's surface (`iris-surface.json`) when iRiS is the family and its apps follow Material. Presets in `modules/common/ThemePresets.qml` write `colors.json` and `palette.json` directly.
- `scripts/colors/generate_colors_material.py` is the only palette generator. It renders the templates in `~/.config/matugen` (installed from `defaults/matugen/`) with `{{colors.<token>.<mode>.<prop>}}` placeholders. matugen is gone, but the paths keep its name.

| File | Use |
|---|---|
| `colors.json` | Shell and UI palette, read by `MaterialThemeLoader.qml` |
| `palette.json` | Shell palette, read by most target modules |
| `app-palette.json` | Palette for the app targets |
| `terminal.json` | Terminal palette |
| `material_colors.scss` | Compatibility values for the terminal, editor and Zed targets |
| `theme-meta.json` | `source`, `mode` and `scheme` |

`palette.json` and `terminal.json` override matching values from `material_colors.scss`.

## Target application

- `applycolor.sh` runs every enabled target module. `MaterialThemeLoader.qml`, the installer and the Settings button for open terminals call it.
- `apply-targets.sh` runs the targets you name (`inir theme apply`).
- Manifests are in `scripts/colors/targets/`, modules in `scripts/colors/modules/`. See [Theming Targets](THEMING_TARGETS.md) and [Theming Modules](THEMING_MODULES.md).

## Runtime

- `services/ThemeService.qml` picks the theme. Auto themes run `switchwall.sh`. A manual change also runs `system24_palette.sh` for Vesktop when `enableVesktop` is on.
- `services/MaterialThemeLoader.qml` reads `colors.json` and `app-palette.json`, and debounces the `applycolor.sh` run.
- `services/Lume.qml` keeps text readable over the wallpaper. It reads `WallpaperLuma`, not these files.
