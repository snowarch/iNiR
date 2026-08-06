# Theming Presets

46 built-in color presets that bypass wallpaper-based color generation and apply predefined palettes.

## How presets work

Normally, iNiR extracts colors from your wallpaper using Material You. Presets skip that step and inject a complete Material 3 color palette directly. The palette propagates to external apps (GTK, terminals, Firefox, etc.) the same way wallpaper colors do.

Apply presets from Settings > Appearance > Theme, or via IPC:

```bash
inir theme setPreset gruvbox-dark
inir theme setPreset catppuccin-mocha
inir theme auto                        # back to wallpaper-based
```

When a preset is active, changing wallpapers changes the background image but doesn't regenerate colors.

## Preset catalog

The full, current list of presets lives in `modules/common/ThemePresets.qml` and drifts as presets are added or renamed. Get the live list instead of trusting a copy here:

```bash
grep -oP '^\s*id:\s*"\K[^"]+' modules/common/ThemePresets.qml | grep -vE '^(auto|custom)$'
```

At time of writing there are 46 theme presets (plus the special `auto` and `custom` entries), spanning Catppuccin (4 flavors), Gruvbox, Nord, Dracula, Tokyo Night, Kanagawa, Rose Pine, Everforest, Solarized, Monokai, Ayu, the iNiR signature styles (Angel / Angel Light), and many more. Preset IDs are kebab-case (e.g. `rose-pine`, `gruvbox-dark`, `tokyo-night`, `one-dark`). Use the ID, not a display name, when scripting.

## Preset features

Some presets include metadata that affects more than just colors (all defined per-preset in `modules/common/ThemePresets.qml`):

- **Rounding scale** (`roundingScale`): multiplier for corner rounding. Varies widely (e.g. Matrix uses a tighter scale, Zen Garden a softer/larger one).
- **Font style** (`fontStyle`): `mono`, `serif`, or `sans` override. Used by many presets (most terminal/retro themes are `mono`, Angel is `serif`, etc.).
- **Border width** (`borderWidthScale`): a handful of presets tune border thickness (e.g. Matrix thicker, some lighter).

Don't rely on the exact value for a given preset. Read the preset's `meta` block in `ThemePresets.qml`.

## Variant system

Presets can be used as seeds for Material You scheme variants. Instead of using the preset colors directly, the engine generates a full Material 3 scheme from the preset's primary color:

- **Tonal Spot**: standard Material You mapping
- **Expressive**: more vibrant secondary/tertiary colors
- **Fidelity**: stays closer to the source color
- **Content**: muted, content-focused palette

## Custom presets

There's no UI for creating custom presets yet, but you can add them by editing `modules/common/ThemePresets.qml`. Each preset is a JavaScript object with the full Material 3 color token set.

The easiest way to create a custom preset is to copy an existing one and modify the colors. The token names follow the Material 3 specification.
