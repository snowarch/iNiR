# Global Actions

Global actions are commands you can run from the Overview search or bind to keys. They are the shell's command palette.

## Using actions

Open Overview (`Super+Space`) and type. Actions show up next to your apps. A prefix narrows the search:

| Prefix | What it does |
|--------|--------------|
| `/` | Action mode: browse actions by category |
| `=` | Calculator, through `qalc` |
| `$` | Run a shell command |
| `>` | Apps |
| `;` | Clipboard history |
| `:` | Emoji |
| `?` | Web search |

Any action can also run from a keybind or a script: `inir globalActions run <id>`. See [IPC.md](IPC.md).

## Categories

Actions belong to `system`, `appearance`, `tools`, `media`, `settings`, `setup` or `custom`. Package actions (install, remove, update) sit under `system`. The two iRiS-only actions appear only while iRiS is the active family.

Use the id in the first column with `inir globalActions run`.

### system

| Id | Name | What it does |
|----|------|--------------|
| `toggle-wifi` | Toggle WiFi | Enable or disable WiFi |
| `toggle-bluetooth` | Toggle Bluetooth | Open the Bluetooth manager |
| `toggle-nightlight` | Toggle Night Light | Toggle the blue light filter |
| `toggle-gamemode` | Toggle Game Mode | Enable or disable Game Mode |
| `toggle-dnd` | Toggle Do Not Disturb | Silence notifications |
| `lock-screen` | Lock Screen | Lock the screen |
| `open-session` | Session Menu | Power off, reboot, log out or suspend |
| `open-settings` | Open Settings | Open the shell settings |
| `toggle-dashboard` | Dashboard | Open the welcome hub: clock, notifications, media, agenda |
| `toggle-control-panel` | Toggle Quick Settings | Open or close the quick settings panel |
| `open-network-settings` | Network Settings | Open the network connection manager |
| `open-volume-mixer` | Volume Mixer | Open the system volume mixer |
| `open-task-manager` | Task Manager | Open the system monitor |
| `install-package` | Install Package | Install a package by name (pass it as an argument) |
| `remove-package` | Remove Package | Remove a package by name (pass it as an argument) |
| `update-system` | Update System | Run a full system update |

### appearance

| Id | Name | What it does |
|----|------|--------------|
| `dark-mode` | Switch to Dark Mode | Apply the dark colour scheme |
| `light-mode` | Switch to Light Mode | Apply the light colour scheme |
| `accent-color` | Change Accent Color | Set an accent colour (pass a hex code) |
| `change-wallpaper` | Change Wallpaper (Grid) | Open the grid wallpaper picker |
| `wallpaper-coverflow` | Change Wallpaper (Coverflow) | Open the coverflow wallpaper picker |
| `random-wallpaper` | Random Wallpaper (Konachan) | Set a random wallpaper from Konachan |
| `style-material` to `style-cookie` | Style: ... | Switch the Global Style: `material`, `cards`, `aurora`, `inir`, `angel`, `regalia`, `zzz`, `editorial` or `cookie` |
| `frame-music` | Frame Music | Toggle music on the iRiS frame (iRiS only) |
| `edge-music` | Edge Music | Toggle the Organic Edge music wave (iRiS only) |

### tools

| Id | Name | What it does |
|----|------|--------------|
| `screenshot` | Take Screenshot | Capture a region of the screen |
| `color-picker` | Color Picker | Pick a colour from the screen |
| `screen-record` | Toggle Screen Recording | Start or stop a fullscreen recording with the configured audio profile |
| `open-clipboard` | Clipboard History | Open the clipboard history |
| `wipe-clipboard` | Wipe Clipboard | Clear all clipboard history |
| `superpaste` | Superpaste | Paste several clipboard entries: a count, with `i` for images (e.g. `4i`) |
| `music-recognition` | Recognize Music | Identify the song that is playing |
| `open-notepad` | Open Notepad | Open the quick notepad in the sidebar |
| `todo` | Add Todo | Add a task (pass the text as an argument) |
| `open-cheatsheet` | Keyboard Shortcuts | Show the shortcut cheatsheet |
| `toggle-crosshair` | Toggle Crosshair | Show or hide the screen crosshair |
| `toggle-tiling` | Toggle Tiling Overlay | Open or close the tiling layout picker |

### media

| Id | Name | What it does |
|----|------|--------------|
| `media-play-pause` | Play / Pause | Toggle playback |
| `media-next` | Next Track | Skip to the next track |
| `media-previous` | Previous Track | Go to the previous track |
| `toggle-mute` | Toggle Mute | Mute or unmute the output |
| `toggle-mic-mute` | Toggle Microphone Mute | Mute or unmute the microphone |
| `volume-up` | Volume Up | Raise the volume |
| `volume-down` | Volume Down | Lower the volume |
| `brightness-up` | Increase Brightness | Raise screen brightness |
| `brightness-down` | Decrease Brightness | Lower screen brightness |
| `toggle-easyeffects` | Toggle EasyEffects | Enable or disable audio effects |
| `toggle-media-controls` | Toggle Media Controls | Open or close the fullscreen media controls |

### settings

| Id | Name | What it does |
|----|------|--------------|
| `toggle-bar-autohide` | Toggle Bar Auto-hide | Toggle auto-hide for the top bar |
| `toggle-dock` | Toggle Dock | Enable or disable the dock |
| `toggle-animations` | Toggle Reduced Animations | Turn reduced animations on or off |
| `toggle-low-power` | Toggle Low Power Mode | Toggle low power mode to save battery |
| `toggle-overview` | Toggle Overview | Open or close the overview |
| `open-sidebar-left` | Open Left Sidebar | Open the left sidebar |
| `open-sidebar-right` | Open Right Sidebar | Open the right sidebar |
| `toggle-osk` | Toggle On-Screen Keyboard | Show or hide the on-screen keyboard |
| `zoom-in` | Zoom In | Increase screen zoom |
| `zoom-out` | Zoom Out | Decrease screen zoom |
| `zoom-reset` | Reset Zoom | Reset screen zoom to 100% |
| `switch-family-ii` | Switch to ii Panel Family | Use the Material layout |
| `switch-family-waffle` | Switch to Waffle Panel Family | Use the Windows 11 style layout |
| `switch-family-iris` | Switch to iRiS Panel Family | Use the iRiS layout |

### setup

Every script in `scripts/setup/` becomes an action named `setup-<slug>`. Type `/setup` to list them. The one shipped recipe is `setup-spotify`, which installs Spotify and configures Spicetify. Each recipe runs in a terminal.

To add one:

1. Copy `scripts/setup/_template.sh.example` to `scripts/setup/<slug>.sh`.
2. Fill in its `@meta` header (name, description, icon, keywords) and write the body.
3. Make it executable with `chmod +x`.

The launcher finds new files in the folder without a reload. The maintainer notes are in `scripts/setup/README.md`.

### custom

Put an executable script in `~/.config/illogical-impulse/actions/`. The file name without its extension becomes the action name, and the id is `custom-<name>`. The shell runs the file directly, so it needs a shebang line and the executable bit. Arguments after the id are split on spaces.

For example, `~/.config/illogical-impulse/actions/deploy.sh`:

```bash
#!/bin/bash
cd ~/myproject && make deploy
notify-send "Deployed" "Project deployed successfully"
```

Run it with `inir globalActions run custom-deploy`.

## Turning categories off

Each category has a switch under `search.globalActions` in `config.json`: `enableSystem`, `enableAppearance`, `enableTools`, `enableMedia`, `enableSettings`, `enablePackages` (install, remove and update), `enableSetup` and `enableCustom`. All of them default to `true`.

```json
"search": {
  "globalActions": {
    "enableSetup": false
  }
}
```

## IPC

```bash
inir globalActions list                     # every action: id, category and name
inir globalActions list tools               # one category
inir globalActions search "screen"          # search by name, description and keywords
inir globalActions run <id>                 # run an action by id
inir globalActions runWithArgs <id> <args>  # run with arguments, e.g. install-package vim
inir globalActions open                     # open the overview in action mode
```
