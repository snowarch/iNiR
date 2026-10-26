# Vesktop theme

iNiR can colour Discord to match your wallpaper, through Vesktop. It comes with three themes, and they update when you change your wallpaper or theme preset.

## Turn it on

1. Install [Vesktop](https://github.com/Vencord/Vesktop).
2. Check that **Vesktop/Discord** is on. It is on by default. Find it under **Settings › Advanced › Color generation** in Material, **Waffle Settings › Themes › Theming** in Waffle, or **iRiS Settings › Style › App colours** in iRiS.
3. Setup copies the themes into `~/.config/vesktop/themes/`. In Vesktop, open **Settings › Vencord › Themes** and turn on one of them.

## The themes

- **iNiR Material** uses Material You colours on the System24 layout, with the Oxanium font.
- **iNiR TUI** is the same layout in a terminal style, with square panels and the JetBrainsMono Nerd Font.
- **iNiR Midnight** uses the Midnight layout with the same colours.

## When the colours change

Changing the wallpaper or the theme preset rebuilds the palette for all three themes. If Discord does not pick up the change, press **Ctrl+R** in Vesktop.

## If it looks wrong

- **Colours but no layout:** the themes load their base style from the internet. Check your connection, then press **Ctrl+R**.
- **Old colours:** change the wallpaper again, or pick the theme preset again, then press **Ctrl+R**.
- **Theme missing from the list:** check that it is turned on under **Settings › Vencord › Themes**.

The themes are built on System24 by [refact0r](https://github.com/refact0r), and on Vencord.
