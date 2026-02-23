# IPC Reference

inir exposes IPC targets you can call from Niri keybinds, scripts, or your terminal when you're feeling fancy.

From terminal (for testing, or showing off):

```bash
qs -c inir ipc call <target> <function>
```

In Niri config (for actual keybinds):

```kdl
bind "Key" { spawn "qs" "-c" "inir" "ipc" "call" "<target>" "<function>"; }
```

Yes, it's verbose. No, there's no shorter way. Welcome to IPC.

---

## Available Targets

Everything inir can do, exposed for your scripting pleasure.

### overview

Toggle the workspace overview panel. The one with all your windows looking tiny and organized.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close overview |

```kdl
bind "Mod+Space" { spawn "qs" "-c" "inir" "ipc" "call" "overview" "toggle"; }
```

---

### overlay

The central overlay. Search, quick actions, widgets. The thing that pops up and makes you feel productive.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close overlay |

```kdl
bind "Super+G" { spawn "qs" "-c" "inir" "ipc" "call" "overlay" "toggle"; }
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
bind "Super+V" { spawn "qs" "-c" "inir" "ipc" "call" "clipboard" "toggle"; }
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
bind "Alt+Tab" { spawn "qs" "-c" "inir" "ipc" "call" "altSwitcher" "next"; }
bind "Alt+Shift+Tab" { spawn "qs" "-c" "inir" "ipc" "call" "altSwitcher" "previous"; }
```

---

### region

Region selection tools. Screenshots, OCR, recording. Draw a box, get stuff done.

| Function | Description |
|----------|-------------|
| `screenshot` | Take a region screenshot |
| `search` | Image search (Google Lens) |
| `ocr` | OCR text recognition |
| `record` | Record region (no audio) |
| `recordWithSound` | Record region with audio |

```kdl
bind "Super+Shift+S" { spawn "qs" "-c" "inir" "ipc" "call" "region" "screenshot"; }
bind "Super+Shift+X" { spawn "qs" "-c" "inir" "ipc" "call" "region" "ocr"; }
bind "Super+Shift+A" { spawn "qs" "-c" "inir" "ipc" "call" "region" "search"; }
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
bind "Super+Shift+V" { spawn "qs" "-c" "inir" "ipc" "call" "voiceSearch" "toggle"; }
```

---

### session

Power menu. Logout, suspend, reboot, shutdown. The "I'm done for today" buttons.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close session menu |

```kdl
bind "Super+Shift+E" { spawn "qs" "-c" "inir" "ipc" "call" "session" "toggle"; }
```

---

### lock

Lock screen. For when you need to pretend you're working.

| Function | Description |
|----------|-------------|
| `activate` | Lock the screen |

```kdl
bind "Super+Alt+L" allow-when-locked=true { spawn "qs" "-c" "inir" "ipc" "call" "lock" "activate"; }
```

---

### cheatsheet

Keyboard shortcuts reference. For when you forget what you just configured five minutes ago.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close cheatsheet |

```kdl
bind "Super+Slash" { spawn "qs" "-c" "inir" "ipc" "call" "cheatsheet" "toggle"; }
```

---

### closeConfirm

Close window confirmation dialog. Shows a prompt before closing the focused window. Useful if you're the type who accidentally closes things and then regrets it.

| Function | Description |
|----------|-------------|
| `trigger` | Show close confirmation for focused window |
| `close` | Dismiss the dialog without closing |

```kdl
bind "Mod+Q" repeat=false { spawn "qs" "-c" "inir" "ipc" "call" "closeConfirm" "trigger"; }
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

```kdl
bind "Super+Comma" { spawn "qs" "-c" "inir" "ipc" "call" "settings" "open"; }
```

---

### sidebarLeft

Left sidebar (AI chat, apps).

| Function | Description |
|----------|-------------|
| `toggle` | Open/close left sidebar |

---

### sidebarRight

Right sidebar (quick toggles, notepad, settings).

| Function | Description |
|----------|-------------|
| `toggle` | Open/close right sidebar |

---

### bar

Top bar visibility.

| Function | Description |
|----------|-------------|
| `toggle` | Show/hide bar |

---

### wallpaperSelector

Wallpaper picker grid.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close wallpaper selector |

```kdl
bind "Ctrl+Alt+T" { spawn "qs" "-c" "inir" "ipc" "call" "wallpaperSelector" "toggle"; }
```

---

### mediaControls

Floating media controls panel.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close media controls |

---

### osk

On-screen keyboard.

| Function | Description |
|----------|-------------|
| `toggle` | Show/hide on-screen keyboard |

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
bind "Ctrl+Mod+Space" { spawn "qs" "-c" "inir" "ipc" "call" "mpris" "playPause"; }
bind "Mod+Alt+N" { spawn "qs" "-c" "inir" "ipc" "call" "mpris" "next"; }
bind "Mod+Alt+P" { spawn "qs" "-c" "inir" "ipc" "call" "mpris" "previous"; }
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
bind "Mod+M+Space" { spawn "qs" "-c" "inir" "ipc" "call" "ytmusic" "playPause"; }
```

---

### osdVolume

On-screen volume indicator.

| Function | Description |
|----------|-------------|
| `trigger` | Show volume OSD |

---

### cliphistService

Clipboard history service. The backend that makes clipboard panel work. You probably don't need to call this directly.

| Function | Description |
|----------|-------------|
| `update` | Refresh clipboard history |

---

### gamemode

Performance mode for gaming. Auto-detects fullscreen apps and disables animations/effects. Can also be toggled manually for those stubborn games that don't go fullscreen properly.

| Function | Description |
|----------|-------------|
| `toggle` | Toggle gamemode on/off |
| `activate` | Force enable gamemode |
| `deactivate` | Force disable gamemode |
| `status` | Print current status to logs |

```kdl
bind "Super+F12" { spawn "qs" "-c" "inir" "ipc" "call" "gamemode" "toggle"; }
```

---

### panelFamily

Switch between panel styles. inir supports two visual styles: Material inir (default) and Waffle (Windows 11-like).

| Function | Description |
|----------|-------------|
| `cycle` | Cycle to next panel family (inir → waffle → inir) |
| `set` | Set specific family ("inir" or "waffle") |

```kdl
bind "Mod+Shift+W" { spawn "qs" "-c" "inir" "ipc" "call" "panelFamily" "cycle"; }
```

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
