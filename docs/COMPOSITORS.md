# Compositors

iNiR runs on two compositors: **Niri** and **Umbriel**, the compositor from the Noctalia team. The shell finds out which one it runs under by itself; you pick at the login screen, and you can have both installed. Hyprland code is still in the source from the project's early days, but it is not tested, and other compositors are not supported.

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

## Umbriel

[Umbriel](https://github.com/noctalia-dev/umbriel) scrolls columns like Niri, and also lays a workspace out as dwindle, master or stacking, tabs a column, pins windows and keeps a scratchpad. Every family works on it: the bar, the dock, Orbit, the overview, Alt+Tab, window previews, the cheatsheet, autostart, keyboard layouts and the lock screen.

### Add it

On a machine that already has iNiR:

```
inir compositor add umbriel
```

It installs Umbriel where iNiR knows how (CachyOS's repository, then the AUR on Arch; Terra on Fedora), puts iNiR's config in `~/.config/umbriel/` and starts the shell with Umbriel's session. Log out and pick **Umbriel** at the login screen. On other distributions, install Umbriel by [its guide](https://docs.noctalia.dev/umbriel/installation/) first and run the same command.

A new install can ask for it from the start: `./setup install --compositor umbriel` (or `both`). `inir compositor` alone shows which compositors are installed and which start iNiR.

### Where Umbriel settings live

| File | Controls |
|---|---|
| `config.toml` | Loads the rest, in order |
| `config.d/10-input.toml` | Keyboard, touchpad and cursor |
| `config.d/20-layout.toml` | Layout, gaps, corners, shadows and the overview |
| `config.d/30-window-rules.toml` | Window rules |
| `config.d/40-environment.toml` | Environment variables for apps |
| `config.d/50-startup.toml` | Processes started at login, including **Settings › Autostart** |
| `config.d/70-binds.toml` | Keybinds |
| `config.d/80-layer-rules.toml` | Layer rules for the shell |
| `config.d/90-user-extra.toml` | Your own settings. Updates never touch it, and it loads last |

Your Niri keybinds (including the ones you added or removed), keyboard layout and key repeat come along: iNiR writes them to `config.d/60-from-niri.toml` when Umbriel is added and on every update, and `inir compositor sync` does it again after you change them in Niri.

`inir update` refreshes iNiR's files and keeps any file you changed, and puts them in place by itself when Umbriel is installed and has no config yet. A config from the early iNiR-Umbriel port no longer loads in today's Umbriel: it is moved whole to `~/.config/umbriel.inir-old-<date>` and replaced. iNiR starts with either compositor as soon as one is installed, so one added later needs no other step. Colours for borders, the overview and tab bars follow your theme: iNiR writes them to `~/.local/state/quickshell/user/generated/umbriel-colors.toml`, which the config loads. Check a change with `umbriel config validate`.

Keys Umbriel adds: **Mod+W** tabs a column, **Mod+P** pins a window, **Mod+Shift+Tab** cycles the workspace layout, **Mod+`** shows the scratchpad and **Mod+Shift+`** sends a window there.

### What differs from Niri

- **Settings › Compositor** (Material) and the window, keyboard and display rows of iRiS edit Niri's files, so they are hidden under Umbriel; its `config.d` files hold the same settings.
- **Compositor blur**: iRiS's *Blur* glass asks Umbriel to blur behind the shell through a layer rule. Material and Waffle use their own glass.
- Window previews are stills, refreshed when you open a surface that shows them; on Niri they can be live.
- Alt+Tab is iNiR's switcher. Screenshots of a whole screen or a region use `inir region`, as on Niri.
