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

With iNiR installed, install Umbriel from your distribution (CachyOS has it; on Arch it is `umbriel-git` in the AUR; on Fedora, Terra's `umbriel-nightly`; elsewhere [its guide](https://docs.noctalia.dev/umbriel/installation/)), log out and pick **Umbriel** at the login screen. Nothing else: on that first login iNiR puts its config in `~/.config/umbriel/`, brings your Niri keybinds and keyboard layout along, and the shell starts as it does on Niri. A config of your own in `~/.config/umbriel/` is never touched.

`inir compositor add umbriel` does the same from a terminal, and installs Umbriel too where iNiR knows how (CachyOS's repository, then the AUR on Arch; Terra on Fedora).

The installer asks where iNiR runs. **Niri and Umbriel** sets iNiR up on both (it installs Umbriel when it is missing); **Niri only**, offered when Umbriel is already installed, leaves Umbriel exactly as it is: no config, and the shell does not start there. Without a terminal to ask, `./setup install --compositor niri|umbriel|both` picks; with none of them, Umbriel gets iNiR the first time you log into it. When another shell is installed, or Umbriel already has a config of your own, the question defaults to **Niri only**, and `-y` with another shell kept picks it too. `inir compositor remove umbriel` takes iNiR off Umbriel later, `inir compositor add umbriel` brings it back, and `inir compositor` alone shows what is installed, what starts iNiR and your pick.

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
| `config.d/90-user-extra.toml` | Your own settings. Updates never touch it |
| `config.d/95-settings.toml` | What you change in iRiS Settings. It loads last, so a key set here and in `90-user-extra.toml` follows Settings |

Your Niri keybinds (including the ones you added or removed), keyboard layout and key repeat come along: iNiR writes them to `config.d/60-from-niri.toml` when Umbriel is added, at every Umbriel login and on every update, and `inir compositor sync` does it again after you change them in Niri.

`inir update` refreshes iNiR's files and keeps any file you changed, and puts them in place by itself when Umbriel is installed and has no config yet. A config from the early iNiR-Umbriel port no longer loads in today's Umbriel: it is moved whole to `~/.config/umbriel.inir-old-<date>` and replaced. iNiR starts with either compositor as soon as one is installed (Niri alone if that was your pick), so one added later needs no other step. Colours for borders, the overview and tab bars follow your theme: iNiR writes them to `~/.local/state/quickshell/user/generated/umbriel-colors.toml`, which the config loads. Check a change with `umbriel config validate`.

Keys Umbriel adds: **Mod+W** tabs a column, **Mod+P** pins a window, **Mod+Shift+Tab** cycles the workspace layout, **Mod+`** shows the scratchpad and **Mod+Shift+`** sends a window there.

### What differs from Niri

- iRiS: **iRiS Settings** asks the compositor in use what it can do and shows only that, in one group of the sidebar named for it (**Umbriel** or **Niri**): Displays, Layout, Windows, Glass & effects, Movement, Keyboard, Mouse & pointer. Under Umbriel, **Layout** draws the arrangements (scrolling, dwindle, main and stack, floating) to pick from; **Windows** has borders, corners, shadows, tabs and title bars; **Glass & effects** the compositor's blur and the effects Umbriel draws (press the screen, a window, its border or the pointer on the drawn desk); **Movement** how windows move; **Displays** lets you drag your screens to where they stand, pick a scale from miniatures of your screen, and set HDR and colour depth, with 15 seconds to keep or undo a display change; an HDMI screen that looks darker at its highest refresh rate than at 60 Hz (it reads every signal as limited range, while the GPU sends its own modes in full range) gets **Fix a darker picture** under **Colour**, applied only at the rates that need it; hot corners are pressed on a drawn screen under **Mouse & pointer**. A row shows only when your machine can do it: variable refresh and HDR on a screen that has them, the trackpad's rows with a trackpad. Everything goes to `config.d/95-settings.toml`. If your own `config.toml` lists its files, Settings asks before adding the one line that loads it.
- Material: **Settings › Compositor** edits Niri's files, so it is hidden under Umbriel; its `config.d` files hold the same settings.
- **Compositor blur**: iRiS's *Blur* glass asks Umbriel to blur behind the shell through a layer rule. Material and Waffle use their own glass.
- Window previews are stills, refreshed when you open a surface that shows them; on Niri they can be live.
- Alt+Tab is iNiR's switcher. Screenshots of a whole screen or a region use `inir region`, as on Niri.
