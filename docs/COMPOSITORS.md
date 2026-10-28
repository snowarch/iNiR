# Compositors

iNiR is built and tested for Niri. Hyprland code is still in the source from the project's early days, but it is not tested, and other compositors are not supported.

Compositor blur needs Niri 26.04 or newer. On older versions the **Allow compositor blur** switch is hidden.

## Change displays, input and layout

Use **Settings › Compositor**. It has these areas:

- **Displays**: monitor, resolution, refresh rate, output position, scale, rotation and variable refresh rate (VRR).
- **Keyboard**, **Touchpad**, **Mouse**, **Cursor** and **General Input**.
- **Layout**: window gaps, focus, borders, focus ring, shadows, struts and overview zoom.
- **Window Rules**.

**Settings › Monitors** is different. It only chooses which monitors show the shell.

## Change keybinds

**Settings › Shortcuts** lists every keybind by category. Use **Add keybind** to add one: a key combination, an action and optional options. Each existing row can be edited or removed, and **Undo** on the notice brings a removed one back.

## Where Niri settings live

iNiR keeps its Niri settings in `~/.config/niri/config.d/`:

| File | Controls |
|---|---|
| `10-input-and-cursor.kdl` | Input and cursor |
| `15-outputs.kdl` | Displays saved from Settings |
| `20-layout-and-overview.kdl` | Layout, gaps, borders, shadows and overview |
| `30-window-rules.kdl` | Window rules |
| `40-environment.kdl` | Environment variables for apps |
| `50-startup.kdl` | Processes started at login |
| `60-animations.kdl` | Animations |
| `70-binds.kdl` | Keybinds |
| `80-layer-rules.kdl` | Layer rules for the shell |
| `90-user-extra.kdl` | Your own settings. Updates never touch it |
