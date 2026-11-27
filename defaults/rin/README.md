# Rin settings (~/.config/rin)

Rin, the compositor, reads the TOML files here and applies each change on save.
iNiR writes most of them. Edit only the files marked "you".

| File | Written by | What it sets |
|---|---|---|
| binds.d/70-inir.toml | iNiR, at each login | iNiR's keys and hot corners. Do not edit: a login replaces it. |
| binds.d/90-user.toml | you | Your keys. A key here replaces the same key in 70-inir.toml. |
| binds.d/95-settings.toml | iNiR Settings > Keybinds | Keys changed in Settings. They win over the files before. |
| rules.d/30-inir.toml | iNiR, at each login | Default window rules. Do not edit: a login replaces it. |
| rules.d/90-settings.toml | iNiR Settings > Window rules | Your per-app rules. |
| rin.windows.toml | iNiR Settings > Windows | Layout, gaps, corners, snap, overview layout, tearing. |
| rin.appearance.toml | iNiR Settings | Blur, blur radius, glass or liquid background. |
| rin.animation.toml | iNiR Settings | Animations on or off. |
| rin.pointer.toml | iNiR Settings, rin-settings | Mouse, touchpad, cursor theme and size. |
| rin.ime.toml | iNiR Settings, rin-settings | Keyboard layouts and options. |
| rin.displays.toml | iNiR Settings > Displays, rin-settings | Mode, position, scale, VRR, HDR per display. |
| rin.network.toml | rin-settings > Network | Proxy. |

Rin reads no other file here.

## Keys

- Files in binds.d load in name order. A later file replaces a key that an earlier file set.
- "Mod" is Super. When Rin runs in a window, it is Alt.
- Bind:   "Mod+T" = "spawn kitty"
- Unbind: "Mod+T" = ""
- Hot corners: [hot-corners] top-left = "overview-toggle", or "" for off.
- A bind is a table to set more: { action = "...", allow-when-locked = true, allow-inhibiting = false }.
- A file that does not parse is skipped as a whole; the keys stay as they were.

## Actions

Rin also takes Niri's spelling of each action (focus-column-left for window-focus-left).

- Programs: spawn ARGV, spawn-sh LINE, terminal, shell TARGET FUNCTION (calls iNiR: "shell overview toggle")
- Session: session-quit, switch-vt N, dpms-off, dpms-on, toggle-keyboard-shortcuts-inhibit
- Windows: window-close, window-minimize, window-toggle-fullscreen, window-toggle-maximize,
  window-toggle-floating, switch-focus-between-floating-and-tiling
- Focus: window-focus-left, -right, -up, -down; column-focus-first, column-focus-last
- Move: column-move-left, column-move-right, window-move-up, window-move-down,
  column-move-to-first, column-move-to-last, column-center
- Columns: window-consume-or-expel-left, -right; window-cycle-primary-extent;
  window-reset-secondary-extent; set-column-width +10% or -10%; set-window-height +10% or -10% (steps only)
- Workspaces: workspace-switch N, workspace-next, workspace-previous, workspace-focus-last,
  column-move-to-workspace N, window-move-to-workspace-silent N,
  column-move-to-workspace-next, column-move-to-workspace-previous
- Displays: output-focus-left, -right, -up, -down; column-move-to-output-left, -right, -up, -down
- Overview: overview-toggle, overview-open, overview-close, overview-layout-next,
  overview-layout expose|workspaces|grid|carousel
- Switcher: window-switcher, window-switcher-back
- Keyboard: keyboard-layout-next, keyboard-layout-prev, switch-layout next|prev|N

## Commands

    rin msg windows                       open windows
    rin msg overview-toggle               open or close the overview
    rin msg settings read rin.windows     show one settings file as Rin reads it
