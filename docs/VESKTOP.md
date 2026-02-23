# Vesktop Theming

iNiR includes automatic Discord/Vesktop theming that syncs with your wallpaper colors.

## Included Theme

### inir-system24
A Material Design Discord theme based on [refact0r/system24](https://github.com/refact0r/system24) with Material You colors from your wallpaper.

Features:
- Oxanium font (iNiR branding)
- Material Design styling (rounded corners, proper spacing)
- Compact server icons and scrollbars
- Full Material You color integration
- Auto-sync with wallpaper changes
- Auto-sync with theme preset changes

## Setup

1. Install [Vesktop](https://github.com/Vencord/Vesktop) (or any Vencord-based client)

2. The theme is automatically installed to `~/.config/vesktop/themes/` during iNiR setup

3. In Vesktop, go to Settings → Vencord → Themes and enable `system24`

4. Colors will automatically update when you change your wallpaper or theme preset!

## How It Works

### Wallpaper Changes (Auto mode)
When you change your wallpaper:
1. `switchwall.sh` runs matugen to generate Material You colors
2. `system24_palette.py` generates the complete theme with embedded palette
3. Vesktop should auto-reload theme changes (if it doesn't, use Ctrl+R)

### Theme Preset Changes
When you change theme preset in Settings:
1. `apply-gtk-theme.sh` applies GTK/KDE colors
2. It also calls `system24_palette.py` to regenerate Vesktop theme
3. Vesktop should auto-reload theme changes (if it doesn't, use Ctrl+R)

### Color Mapping

| system24 Variable | Material You Source |
|-------------------|---------------------|
| `--accent-*` | `primary` color ladder |
| `--accent-new` | `primary` (for NEW badge) |
| `--bg-*` | `surface_container_*` variants |
| `--text-*` | `on_surface` / `on_surface_variant` |
| `--red-*` | `error` color ladder |
| `--green-*` | `tertiary` color ladder |
| `--blue-*` | `secondary` color ladder |

## Manual Regeneration

If colors get out of sync, regenerate manually:

```fish
# Regenerate theme
python3 ~/.config/quickshell/inir/scripts/colors/system24_palette.py

# Or trigger a full wallpaper refresh
~/.config/quickshell/inir/scripts/colors/switchwall.sh --noswitch
```

## Customization

### Changing Fonts

Edit `scripts/colors/system24_palette.py` and change the font variables:

```css
body {
    --font: 'Your Font';        /* Main font */
    --code-font: 'Mono Font';   /* Code blocks */
}
```

Then regenerate the theme.

## Troubleshooting

### Colors not updating
- Check that `~/.config/vesktop/themes/system24.theme.css` exists
- Some installs use `~/.config/Vesktop/themes/` (capital V)
- Verify the theme is enabled in Vesktop settings
- Try Ctrl+R in Vesktop to force reload

### Theme not appearing
- Ensure the `.theme.css` file is in `~/.config/vesktop/themes/`
- Check Vesktop console for CSS errors (Ctrl+Shift+I)

### Visual inconsistencies / theme looks half-applied
- This theme relies on the System24 base CSS. If the remote `@import` fails (network/CSP), you may only get colors but not layout/styling.
- Open DevTools (Ctrl+Shift+I) and check:
  - Network tab for failed `system24.css` requests
  - Console tab for `@import`/CSP related errors
- Optional: place a local copy of System24 at `~/.config/vesktop/themes/system24.local.css` (same folder as the theme). If present, iNiR will import it first.

### Wrong colors
- Run `python3 ~/.config/quickshell/inir/scripts/colors/system24_palette.py` to regenerate
- Check `~/.local/state/quickshell/user/generated/colors.json` exists

### Debugging generation failures
- Run `python3 ~/.config/quickshell/inir/scripts/colors/system24_palette.py` in a terminal and check for errors
- If you're using preset themes (Settings), `apply-gtk-theme.sh` no longer suppresses Python errors, so `qs log -c inir` (or your shell logs) should show failures

### Hot-reload not working
- The theme palette is embedded in the main file, so Ctrl+R should work
- If Vesktop window is not focused, the reload script may not work
- Try manually pressing Ctrl+R in Vesktop

## Credits

- [refact0r](https://github.com/refact0r) for system24 theme base
- [Vencord](https://github.com/Vencord) for the Discord mod platform
