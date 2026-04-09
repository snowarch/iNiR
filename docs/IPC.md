# IPC Reference

iNiR exposes IPC targets you can call from Niri keybinds, scripts, or your terminal.

> **Quick discovery:** `inir help` lists all targets, `inir <target> --help` shows available functions.
> Shell completions: `eval "$(inir completions bash)"` (also zsh, fish).

From terminal (for testing, or showing off):

```bash
inir <target> <function>
```

In Niri config (for actual keybinds):

```kdl
bind "Key" { spawn "inir" "<target>" "<function>"; }
```

For low-level debugging, `inir ipc <target> <function>` still works.

---

## Available Targets

Everything iNiR can do, exposed for your scripting pleasure.

### overview

Toggle the workspace overview panel. The one with all your windows looking tiny and organized.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close overview |
| `open` | Open overview |
| `close` | Close overview |
| `clipboardToggle` | Open clipboard search, or close if already open |
| `actionOpen` | Open overview in action search mode |
| `toggleReleaseInterrupt` | Clear the super-key release interrupt flag |

```kdl
bind "Mod+Space" { spawn "inir" "overview" "toggle"; }
```

---

### overlay

The central overlay. Search, quick actions, widgets. The thing that pops up and makes you feel productive.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close overlay |

```kdl
bind "Super+G" { spawn "inir" "overlay" "toggle"; }
```

---

### clipboard

Clipboard history panel. Because Ctrl+V only remembers one thing, and that's not enough for power users.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close panel |
| `open` | Open panel |
| `close` | Close panel |

```kdl
bind "Super+V" { spawn "inir" "clipboard" "toggle"; }
```

---

### altSwitcher

Alt+Tab window switcher. Works across workspaces, unlike some other implementations we won't name.

| Function | Description |
|----------|-------------|
| `toggle` | Toggle switcher |
| `open` | Open switcher |
| `close` | Close switcher |
| `next` | Focus next window |
| `previous` | Focus previous window |

```kdl
bind "Alt+Tab" { spawn "inir" "altSwitcher" "next"; }
bind "Alt+Shift+Tab" { spawn "inir" "altSwitcher" "previous"; }
```

---

### region

Region selection tools. Screenshots, OCR, recording. Draw a box, get stuff done.

| Function | Description |
|----------|-------------|
| `screenshot` | Take a region screenshot |
| `search` | Image search (Google Lens) |
| `googleLens` | Start a region capture for Google Lens |
| `ocr` | OCR text recognition |
| `record` | Record region (no audio) |
| `recordWithSound` | Record region with audio |

```kdl
bind "Super+Shift+S" { spawn "inir" "region" "screenshot"; }
bind "Super+Shift+X" { spawn "inir" "region" "ocr"; }
bind "Super+Shift+A" { spawn "inir" "region" "search"; }
```

---

### voiceSearch

Voice search using Gemini API. Records from microphone, transcribes with Gemini, opens Google search.

| Function | Description |
|----------|-------------|
| `start` | Start recording |
| `stop` | Stop recording |
| `toggle` | Toggle recording |

```kdl
bind "Super+Shift+V" { spawn "inir" "voiceSearch" "toggle"; }
```

---

### session

Power menu. Logout, suspend, reboot, shutdown. The "I'm done for today" buttons.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close session menu |
| `open` | Show session screen |
| `close` | Hide session screen |

```kdl
bind "Super+Shift+E" { spawn "inir" "session" "toggle"; }
```

---

### lock

Lock screen. For when you need to pretend you're working.

| Function | Description |
|----------|-------------|
| `activate` | Lock the screen |
| `deactivate` | Cancel lock and mark screen unlocked |
| `status` | Return lock state (`locked`, `activating`, or `unlocked`) |
| `focus` | Refocus the lock screen input |

```kdl
bind "Super+Alt+L" allow-when-locked=true { spawn "inir" "lock" "activate"; }
```

---

### cheatsheet

Keyboard shortcuts reference. For when you forget what you just configured five minutes ago.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close cheatsheet |
| `open` | Show cheatsheet overlay |
| `close` | Hide cheatsheet overlay |

```kdl
bind "Super+Slash" { spawn "inir" "cheatsheet" "toggle"; }
```

---

### closeConfirm

Close window confirmation dialog. Shows a prompt before closing the focused window. Useful if you're the type who accidentally closes things and then regrets it.

| Function | Description |
|----------|-------------|
| `trigger` | Show close confirmation for focused window |
| `close` | Dismiss the dialog without closing |

```kdl
bind "Mod+Q" repeat=false { spawn "inir" "close-window"; }
```

By default, confirmation is disabled (closes immediately). Enable it in settings or config:

```json
"closeConfirm": {
  "enabled": true
}
```

---

### settings

Open the settings window. GUI config so you don't have to edit JSON like it's 2005.

| Function | Description |
|----------|-------------|
| `open` | Open settings window |
| `toggle` | Toggle settings (overlay mode toggles, window mode opens) |

```kdl
bind "Super+Comma" { spawn "inir" "settings"; }
```

---

### controlPanel

Quick settings panel. Toggles, sliders, and system controls without opening full settings.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close control panel |
| `open` | Open control panel |
| `close` | Close control panel |

---

### sidebarLeft

Left sidebar (AI chat, apps).

| Function | Description |
|----------|-------------|
| `toggle` | Open/close left sidebar |
| `open` | Show left sidebar |
| `close` | Hide left sidebar |

---

### sidebarRight

Right sidebar (quick toggles, notepad, settings).

| Function | Description |
|----------|-------------|
| `toggle` | Open/close right sidebar |
| `open` | Show right sidebar |
| `close` | Hide right sidebar |

---

### bar

Top bar visibility.

| Function | Description |
|----------|-------------|
| `toggle` | Show/hide bar |
| `open` | Show bar |
| `close` | Hide bar |

---

### globalActions

Command palette / action registry. Search and execute shell actions from scripts or keybinds.

| Function | Description |
|----------|-------------|
| `run <id> [args]` | Execute action by ID (e.g. `toggle-mute`, `install-package vim`) |
| `list [category]` | List all actions, optionally filtered by category |
| `search <query>` | Fuzzy search actions by name/description/keywords |
| `open` | Open the overview in action mode |

Categories: `system`, `appearance`, `tools`, `media`, `settings`, `custom`.

```kdl
bind "Super+Slash" { spawn "inir" "globalActions" "open"; }
bind "Super+M" { spawn "inir" "globalActions" "run" "toggle-mute"; }
```

---

### wallpaperSelector

Wallpaper picker grid.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close wallpaper selector |
| `open` | Open wallpaper selector |
| `close` | Close wallpaper selector |
| `toggleOnMonitor <name>` | Open wallpaper selector on a specific monitor |
| `random` | Pick a random wallpaper from the current folder |

```kdl
bind "Ctrl+Alt+T" { spawn "inir" "wallpaperSelector" "toggle"; }
```

---

### coverflowSelector

Wallpaper coverflow (3D card) picker.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close coverflow selector |
| `open` | Open coverflow selector |
| `close` | Close coverflow selector |

---

### mediaControls

Floating media controls panel.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close media controls |
| `open` | Show media controls |
| `close` | Hide media controls |

---

### osk

On-screen keyboard.

| Function | Description |
|----------|-------------|
| `toggle` | Show/hide on-screen keyboard |
| `open` | Show on-screen keyboard |
| `close` | Hide on-screen keyboard |

---

### audio

Volume and mute control.

| Function | Description |
|----------|-------------|
| `volumeUp` | Increase volume |
| `volumeDown` | Decrease volume |
| `mute` | Toggle speaker mute |
| `micMute` | Toggle microphone mute |

---

### zoom

Screen zoom. Accessibility feature, or for reading tiny text without squinting.

| Function | Description |
|----------|-------------|
| `zoomIn` | Increase zoom level |
| `zoomOut` | Decrease zoom level |

---

### brightness

Display brightness control.

| Function | Description |
|----------|-------------|
| `increment` | Increase brightness |
| `decrement` | Decrease brightness |

---

### mpris

Media player control. Automatically detects and uses YtMusic controls when active, otherwise uses the active MPRIS player.

| Function | Description |
|----------|-------------|
| `pauseAll` | Pause all players |
| `playPause` | Toggle play/pause (uses YtMusic if active) |
| `previous` | Previous track (uses YtMusic if active) |
| `next` | Next track (uses YtMusic if active) |

```kdl
bind "Ctrl+Mod+Space" { spawn "inir" "mpris" "playPause"; }
bind "Mod+Alt+N" { spawn "inir" "mpris" "next"; }
bind "Mod+Alt+P" { spawn "inir" "mpris" "previous"; }
```

---

### ytmusic

Direct YtMusic player control. Use these if you want to control YtMusic specifically, regardless of what other players are active.

| Function | Description |
|----------|-------------|
| `playPause` | Toggle YtMusic play/pause |
| `next` | Play next track in YtMusic |
| `previous` | Play previous track in YtMusic |
| `stop` | Stop YtMusic playback |

```kdl
bind "Mod+M+Space" { spawn "inir" "ytmusic" "playPause"; }
```

---

### osdVolume

On-screen volume indicator.

| Function | Description |
|----------|-------------|
| `trigger` | Show volume OSD |
| `toggle` | Toggle volume OSD |
| `hide` | Hide volume OSD |

---

### cliphistService

Clipboard history service. The backend that makes clipboard panel work. You probably don't need to call this directly.

| Function | Description |
|----------|-------------|
| `update` | Refresh clipboard history |

---

### ai

AI chat service. Multi-provider (Gemini, OpenAI, Mistral) with tool support.

| Function | Description |
|----------|-------------|
| `ensureInitialized` | Force-load models and API keys |
| `diagnose` | Dump current AI state (model, keys, config) as JSON |
| `run <text>` | Send a message or `/command` to the AI chat |
| `runGet <text>` | Run AI command and return the last response |

---

### packageSearch

Package search service. Searches pacman repos and installed packages.

| Function | Description |
|----------|-------------|
| `search <query>` | Start a package search |
| `results` | Print current search results |

---

### appCatalog

App catalog service. Browse, search, and install curated applications.

| Function | Description |
|----------|-------------|
| `refresh` | Refresh the installed-state cache |
| `search <query>` | Filter catalog entries by query |
| `install <id>` | Install app by catalog ID |
| `list` | List catalog apps with install status and descriptions |

---

### gamemode

Performance mode for gaming. Auto-detects fullscreen apps and disables animations/effects. Can also be toggled manually for those stubborn games that don't go fullscreen properly.

| Function | Description |
|----------|-------------|
| `toggle` | Toggle gamemode on/off |
| `activate` | Force enable gamemode |
| `deactivate` | Force disable gamemode |
| `status` | Print current gamemode state (e.g. `active (manual)`, `inactive (off)`) |

```kdl
bind "Super+F12" { spawn "inir" "gamemode" "toggle"; }
```

---

### panelFamily

Switch between panel styles. ii supports two visual styles: Material ii (default) and Waffle (Windows 11-like).

| Function | Description |
|----------|-------------|
| `cycle` | Cycle to next panel family (ii → waffle → ii) |
| `set` | Set specific family ("ii" or "waffle") |

```kdl
bind "Mod+Shift+W" { spawn "inir" "panelFamily" "cycle"; }
```

---

### shellUpdate

Shell update checker. Monitors the git repo for new commits and shows an update overlay.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close update overlay |
| `open` | Open update overlay |
| `close` | Close update overlay |
| `check` | Check for updates now |
| `performUpdate` | Run the update |
| `dismiss` | Dismiss update notification |
| `undismiss` | Un-dismiss update notification |
| `diagnose` | Dump update state as JSON |

---

### notifications

Notification management.

| Function | Description |
|----------|-------------|
| `test` | Send test notifications |
| `clearAll` | Dismiss all notifications |
| `toggleSilent` | Toggle Do Not Disturb mode |

---

### minimize

Window minimization (Niri workaround - moves windows to hidden workspace).

| Function | Description |
|----------|-------------|
| `minimize` | Minimize focused window |
| `restore` | Restore a minimized window by ID |

---

### tiling

Tiling layout overlay. Pick or cycle through tiling presets for the current workspace.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close tiling picker |
| `open` | Open tiling picker |
| `hide` | Close picker and OSD |
| `cycle` | Cycle to next tiling preset (shows OSD) |
| `showOsd` | Flash the current tiling preset OSD |
| `promote` | Promote focused window to master position |

---

## Waffle-Specific Targets

These targets only work when using the Waffle (Windows 11) panel style.

### search

Waffle start menu / search.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close start menu |
| `open` | Open start menu |
| `close` | Close start menu |

---

### wactionCenter

Waffle action center (quick settings).

| Function | Description |
|----------|-------------|
| `toggle` | Open/close action center |

---

### wnotificationCenter

Waffle notification center.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close notification center |

---

### wwidgets

Waffle widgets panel.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close widgets |
| `open` | Open widgets |
| `close` | Close widgets |

---

### wbar

Waffle taskbar visibility.

| Function | Description |
|----------|-------------|
| `toggle` | Show/hide taskbar |
| `open` | Show taskbar |
| `close` | Hide taskbar |

---

### taskview

Waffle task view (Win+Tab style).

| Function | Description |
|----------|-------------|
| `toggle` | Open/close task view |
| `open` | Show task view |
| `close` | Hide task view |

---

### osd

Waffle on-screen display indicator (volume, brightness).

| Function | Description |
|----------|-------------|
| `trigger` | Show the OSD indicator |

---

### waffleAltSwitcher

Waffle Alt+Tab window switcher. Separate from the ii `altSwitcher` — supports quick-switch (first tab switches instantly, second opens UI) and no-visual-UI mode.

| Function | Description |
|----------|-------------|
| `open` | Open switcher |
| `close` | Close switcher |
| `toggle` | Toggle switcher |
| `next` | Focus next window |
| `previous` | Focus previous window |
