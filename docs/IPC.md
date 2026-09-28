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

### dev

Development navigation for loading lazy surfaces and internal views without
automating pointer or keyboard input. Destination identifiers are stable and
returned as JSON by `list`.

| Function | Description |
|----------|-------------|
| `list` | Return the destination inventory as JSON |
| `open` | Open a destination by semantic identifier |
| `close` | Close development-opened surfaces and clear the request |
| `current` | Return the current destination or `closed` |
| `meter` | Measure frame gaps for the given milliseconds (250–20000, default 2500) |
| `metered` | Return the last measurement as JSON: frames, mean, p95, worst, frames over 20 and 50 ms |
| `dragSim` | Simulate carrying an iRiS bubble (slot id, default `extra-clock`) around the focused output for 2.5 s, publishing the given number of moves per frame (1–16); never writes the config |

```bash
inir dev list | jq -r '.[].id'
inir dev open sidebar-left/anime-schedule
inir dev close
inir dev audit
inir dev audit sidebar-left/ai settings/ai
inir dev audit --all --all-families
inir dev meter 2500; sleep 3; inir dev metered
inir dev dragSim extra-clock 8; inir dev meter 2400; sleep 3; inir dev metered
```

`inir dev audit` selects destinations related to changed area-specific files in
the current worktree. Destination arguments select an exact scope, while
`--all` requests every safe destination and `--all-families` includes both ii
and waffle. Each visited destination is closed again and new QML warnings or
errors are attributed to the destination that triggered them. Destructive
actions such as locking, recording, power commands, and wallpaper mutation are
excluded.

---

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

### orbit

Niri-only Material session navigator for the ii family. Orbit presents nearby workspaces and readable window previews, with MRU Trail navigation and temporary Stash parking.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close Orbit |
| `open` | Open Orbit on the focused output |
| `close` | Close Orbit if it is active |
| `pocket` | Open Orbit directly into Pocket |
| `studio` | Open Orbit directly into the live Studio editor |
| `find` | Open Orbit Focus Lens and filter session windows by app or title |
| `stage` | Open Orbit in the classic Stage view for this session |
| `orbital` | Open Orbit in the Orbital workspace view for this session |
| `next` | Switch Niri to the next workspace while Orbit stays open |
| `previous` | Switch Niri to the previous workspace while Orbit stays open |
| `status` | Print the effective Orbit runtime state used by diagnostics and visual audits |
| `toggleView` | Switch the open Orbit session between Stage and Orbital |

---

### taskview

Compatibility entry point for task navigation. On Waffle it opens the Waffle Task View; on ii/Niri it routes to Orbit.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close the active family's task navigator |
| `open` | Open the active family's task navigator |
| `close` | Close the active family's task navigator |

---

### workspaceStrip

Workspace edge strip. Shows a compact per-workspace rail and expands it for switching without opening the full overview.

| Function | Description |
|----------|-------------|
| `open` | Keep the strip expanded |
| `close` | Return the strip to hover/peek mode |
| `toggle` | Toggle forced expansion |
| `status` | Return strip state (`open` or `auto`) |

```kdl
bind "Super+Tab" { spawn "inir" "workspaceStrip" "toggle"; }
```

---

### overlay

Floating tools (Super+G): notes, images, crosshair, recorder, resources and other pinnable desktop tools.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close Floating tools |
| `tool` | Show or hide one floating tool by id (`crosshair`, `fpsLimiter`, `floatingImage`, `recorder`, `resources`, `notes`, `discord`, `volumeMixer`, `notifications`): `on`, `off` or `toggle` |

```kdl
bind "Super+G" { spawn "inir" "overlay" "toggle"; }
```

---

### pill

The pill bar's morphing surfaces (only registered while Bar appearance is set to Pill). Valid surface names: `power`, `media`, `battery`, `calendar`, `link`, `mixer`, `sysmon`, `clipboard`, `glance`, `launcher`, `recorder`.

| Function | Description |
|----------|-------------|
| `open` | Open a surface by name on the focused monitor |
| `close` | Close the open surface |
| `toggle` | Open a surface, or close it if already open |
| `state` | Print the open surface name, or `closed` |

```kdl
bind "Super+V" repeat=false { spawn "inir" "pill" "toggle" "clipboard"; }
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
bind "Super+V" repeat=false { spawn "inir" "clipboard" "toggle"; }
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
| `screenshot` | Take a rectangular region screenshot |
| `search` | Image search (Google Lens) |
| `googleLens` | Start a region capture for Google Lens |
| `ocr` | OCR text recognition |
| `record` | Record region (no audio) |
| `recordWithSound` | Record region with audio |
| `menu` | Open the unified snip menu, optionally restoring its last toolbar choice |
| `dismiss` | Close the selector overlay |
| `current` | Return the selector state (open/action/mode) as JSON |

```kdl
bind "Super+Shift+S" { spawn "inir" "region" "screenshot"; }
bind "Super+Shift+X" { spawn "inir" "region" "ocr"; }
bind "Super+Shift+A" { spawn "inir" "region" "search"; }
bind "Ctrl+Shift+S" { spawn "inir" "region" "menu"; }
```

---

### voiceSearch

Provider-neutral voice input for web search and AI dictation. Auto prefers local whisper.cpp, then connected Groq, Gemini and OpenAI speech backends. Keys stay in the system keyring and are passed to adapters through the process environment.

| Function | Description |
|----------|-------------|
| `start` | Start recording for voice web search |
| `stop` | Stop the active recording or transcription |
| `toggle` | Toggle recording |
| `refresh` | Re-detect local and connected speech backends |
| `status` | Return backend, local detection, recording and error state as JSON |

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
| `prepareSleep` | Suspend handshake: activate immediately and wait until the compositor confirms the session lock is secure |
| `deactivate` | Cancel lock and mark screen unlocked |
| `status` | Return lock state (`secure`, `locked`, `activating`, or `unlocked`) |
| `focus` | Refocus the lock screen input |

```kdl
bind "Super+Alt+L" allow-when-locked=true { spawn "inir" "lock" "activate"; }
```

---

### memory

Memory pressure monitoring for JSGCHeap accumulation (Qt V4 memfd leak). Notifies user when memory is high, lets them decide when to restart.

| Function | Description |
|----------|-------------|
| `stats` | Return JSON with deleted mappings count, threshold, and state |
| `collect` | Force JavaScript garbage collection |
| `restart` | Restart the shell to free accumulated memory |
| `dismiss` | Dismiss the memory warning notification |
| `reset` | Reset notification state (re-enables warnings) |

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
| `triggerWindow <windowId> <appId>` | Close or confirm the exact window captured by `inir close-window` |
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

Open or toggle the settings window. GUI config so you don't have to edit JSON by hand.

| Function | Description |
|----------|-------------|
| `open` | Open the settings window |
| `toggle` | Toggle settings in the active host (overlay or window) |
| `openOverlay` | Switch to overlay mode and open Settings |
| `openOverlayAt index` | Switch to overlay mode, open Settings and preserve/jump to page `index` |
| `openWindowAt index` | Switch to standalone Window mode and open page `index` |
| `setOverlayStyle style index` | Switch overlay chrome while preserving page `index` |

```kdl
bind "Super+Comma" { spawn "inir" "settings"; }
```

---

### settingsNav

Navigate the settings overlay to a specific page (same as clicking the nav rail). `inir settings` toggles the current Settings host; use the `settings` IPC target above when you need explicit open/toggle semantics.

| Function | Description |
|----------|-------------|
| `page(index)` | Open the overlay and jump to page `index` |
| `section(index, name)` | Open a page at its named section; for example `inir settingsNav section 28 sidebars` |
| `count` | Number of settings pages |
| `current` | Current page index, or `-1` when no page is open |

```sh
inir ipc settingsNav page 5
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

### dashboard

Centered welcome hub panel (ii family): greeting, clock, notifications, media, weather, calendar, todo, system usage and GitHub activity.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close dashboard |
| `open` | Open dashboard |
| `close` | Close dashboard |

---

### mascot

Playful mascot companion (needs `mascot.enable` and the companion switch in Settings › Mascot). She peeks from screen edges and reacts to events; every reaction and its pose is configurable in the dedicated Mascot settings page. Never appears over fullscreen apps, game mode, the lock screen or the session screen.

| Function | Description |
|----------|-------------|
| `poke` | Ask her to peek from a random edge with a random pose |
| `status` | Return JSON diagnostics for mood, configured/effective voice, companion state and non-sensitive Screen Time counters |
| `setVoice <mode>` | Set the idle voice register to `adaptive`, `casual`, `dry`, `composed` or `chaotic` |
| `appear <pose> <edge>` | Show a specific catalog pose from `left`, `right`, `top` or `bottom` |
| `appearContextual <pose> <sourceWidget>` | Show near the triggering widget (`battery`, `media`, `update`, `network`, `dnd`). Requires `mascot.companion.contextualPlacement` to be enabled for event reactions; this IPC call bypasses that check for testing. |
| `appearWithLine <pose> <edge> <line>` | Show a specific pose saying an exact line (used by the bar widget easter eggs) |
| `romp` | Chaos mode: she runs across the desktop and bonks a widget, wrecks one onto the floor, hurls one to a new spot, rampages through several, kicks the bar/dock, or ground-slams so everything rattles. Needs `mascot.chaos.enable`; widgets only keep new positions with `mascot.chaos.allowRearrange` |
| `chase` | Chase game: she hunts your mouse, every click is a spot she pounces on; click *her* to catch her and win |
| `hideSeek` | Hide-and-seek: she tucks into a spot on the desktop. Click her before the 20s timeout to find her, otherwise she wins by default |
| `tidy` | Undo the chaos: every displaced widget returns to its pre-chaos position |
| `hide` | Dismiss the peek or active chaos, cancel follow-ups, tidy widgets and pause automatic visits for 30 minutes |
| `snooze <minutes>` | Dismiss Kira and pause automatic visits for 1–480 minutes |

---

### mascotMood

Session-long mood state that flavors the mascot's idle lines (needs `mascot.personality.enabled`). The mood re-rolls on a jittered interval and starts from the time of day.

| Function | Description |
|----------|-------------|
| `set <mood>` | Force a mood: `neutral`, `sleepy`, `hyper`, `snarky` or `contemplative` |
| `current` | Print the current mood |

---

### sidebarLeft

Left sidebar: AI chat and apps in Material; the customizable Focus panel in iRiS. In iRiS, `open`, `close` and `toggle` use the family-owned panel; AI detach and expanded-layout actions apply to Material.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close left sidebar |
| `open` | Show left sidebar |
| `close` | Hide left sidebar |
| `expand` | Open the sidebar in its wide Ctrl+O layout |
| `compact` | Return the sidebar to its normal width |
| `status` | Return open, expanded and detached state as JSON |
| `detach` | Move AI chat into its Ctrl+P standalone window |
| `attach` | Return AI chat from the standalone window to the sidebar |

---

### sidebarRight

Right sidebar: quick toggles, notepad and settings in Material; the customizable Today panel in iRiS.

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

Wallpaper picker with grid, coverflow and compact launcher styles.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close wallpaper selector |
| `open` | Open wallpaper selector |
| `close` | Close wallpaper selector |
| `openLauncher <mode>` | Open the compact launcher in `static` or `animated` mode |
| `toggleOnMonitor <name>` | Open wallpaper selector on a specific monitor |
| `random` | Pick a random wallpaper from the current folder |
| `set <path>` | Apply a wallpaper (picture, GIF or video) by path, the same way the picker does |
| `preview <path>` | Show a wallpaper on the desktop without applying it: no config write, no recoloring |
| `cancelPreview` | Drop the preview and go back to the applied wallpaper |
| `kind <name>` | Show only one kind of wallpaper in the library: `all`, `still`, `live` (videos) or `gif`. iRiS only; the filter also sits beside the search field whenever the folder holds more than one kind |
| `browse <source> <query>` | Open the picker on a source — `library`, `wallhaven` or `live` (anime live wallpapers) — with a search, a folder to open (`~/Videos`), or `-` for none. Sources are an iRiS feature; other families just open the picker |
| `status` | Return picker style, open surface, target monitor and selection target as JSON |

```kdl
bind "Ctrl+Alt+T" { spawn "inir" "wallpaperSelector" "toggle"; }
bind "Ctrl+Alt+L" { spawn "inir" "wallpaperSelector" "browse" "live" "-"; }
bind "Ctrl+Alt+A" { spawn "inir" "wallpaperSelector" "openLauncher" "animated"; }
```

---

### wallpaperLauncher

Navigation and apply controls for the compact wallpaper launcher.

| Function | Description |
|----------|-------------|
| `next` | Select the next wallpaper |
| `previous` | Select the previous wallpaper |
| `applyCurrent` | Apply the selected wallpaper and keep the launcher open |
| `status` | Return launcher mode, index, count, path, target and monitor as JSON |

Open the launcher before calling its controls:

```bash
inir wallpaperSelector openLauncher static
inir wallpaperLauncher next
inir wallpaperLauncher applyCurrent
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

### equalizer

Open the ii-family EasyEffects output equalizer. The integration is optional and disabled until you enable it. Run `inir settings`, then go to **Modules → Optional → EasyEffects Equalizer** and enable the switch. While it is disabled the IPC target is intentionally not constructed. On a fresh empty EasyEffects output pipeline, iNiR bootstraps a neutral 10-band `iNiR Equalizer` preset. Existing non-empty effect chains are never replaced automatically.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close equalizer |
| `open` | Show equalizer |
| `close` | Hide equalizer |
| `refresh` | Refresh EasyEffects equalizer state |
| `ensure` | Ensure Equalizer control is available; bootstraps a neutral Equalizer only when the output pipeline is empty |
| `status` | Return current equalizer state as JSON |
| `setBand <index> <gain>` | Set one 0-based band gain in dB |
| `preset <name>` | Apply one built-in EQ preset |
| `configure` | Convert the active Equalizer to the iNiR 10-band layout |

```kdl
bind "Ctrl+Alt+F" { spawn "inir" "equalizer" "toggle"; }
```

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
| `playEvent <event>` | Play a shell event sound (e.g. `notification`, `batteryLow`, `timerDone`), honoring the user's per-event override |

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

### osd

On-screen feedback for any family. The active family's OSD or Island decides where it is drawn.

| Function | Description |
|----------|-------------|
| `volume` | Show the volume level |
| `brightness` | Show the brightness level |
| `mic` | Show the microphone level |
| `keyboard` | Show the keyboard layout |
| `media <action>` | Show now playing with a transport action: `play`, `pause`, `next` or `previous` |
| `hide` | Hide whatever is showing |

```kdl
bind "Mod+Shift+K" { spawn "inir" "osd" "keyboard"; }
```

---

### cliphistService

Clipboard history service. The backend that makes clipboard panel work. You probably don't need to call this directly.

| Function | Description |
|----------|-------------|
| `update` | Refresh clipboard history |

---

### ai

Shared multi-provider AI service. It supports Gemini, OpenAI-compatible chat and Responses APIs, Mistral and Anthropic; live provider catalogs are normalized into capability-aware model records. Catalog visibility is separate from execution readiness, so public model lists remain browseable without pretending an API key exists. OpenCode Zen and Go resolve their current model lists and per-model API routes dynamically. Normal shell tools use typed actions and approval cards, while arbitrary commands are isolated in Advanced mode.

| Function | Description |
|----------|-------------|
| `ensureInitialized` | Force-load models, provider catalogs and API keys |
| `diagnose` | Dump current AI, catalog and tool state as JSON |
| `refreshCatalog` | Refresh every live provider model catalog |
| `catalog <query>` | Search up to 100 normalized live model records |
| `providers` | Return provider health, key state and live model counts |
| `run <text>` | Send a message or compatibility `/command` to AI chat |
| `runGet <text>` | Run an AI command and return the last response |

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

### connections

Short notices when something is plugged in, connected, unplugged or lost: networks, the internet, Bluetooth devices, USB devices by name (mice, keyboards, controllers, cameras, phones), the charger, the sound output, displays, and drives and memory cards with their name and size. Each family shows them its own way: a pill under the bar in Material, a panel in Waffle, the Island in iRiS. Settings has a switch for each kind.

| Function | Description |
|----------|-------------|
| `sample <kind>` | Show how a notice looks without plugging anything: `network`, `internet`, `bluetooth`, `usb`, `power`, `audio`, `displays` or `drives` |
| `status` | Print which kinds are on as JSON, and whether udev is there to watch USB devices and drives |
| `enable` / `disable` / `toggle` | Turn connection notices on or off |

---

### network

Whether the shell can reach the internet, as NetworkManager sees it. Surfaces that show online content (wallpaper sources, news, anime, weather, calendars, lyrics) read this to say why they are empty instead of failing quietly.

| Function | Description |
|----------|-------------|
| `status` | Print the state as JSON: `online`, `connectivity` (`full`, `limited`, `portal`, `none`, `unknown`), connection name |
| `check` | Ask NetworkManager to check connectivity again, for example after signing in to a captive portal |
| `simulate <state>` | Pretend the connectivity is `none`, `limited`, `portal` or `full` until the shell restarts; any other value clears it. For testing |

---

### vpn

NetworkManager VPN profiles (OpenVPN, WireGuard, anything with an NM plugin) and Tailscale, as the VPN piece and its card show them.

| Function | Description |
|----------|-------------|
| `status` | Print the state as JSON: connected, through what, Tailscale's state, its devices and how many are online, your profiles |
| `toggle` | Turn every active VPN off, or connect Tailscale (else your first profile) when none is on |
| `details <state>` | `on`, `off` or `toggle` the card's details: addresses, name, account, exit node, devices and live traffic |
| `refresh` | Read profiles and Tailscale again |
| `importFile <path>` | Add a WireGuard `.conf` or OpenVPN `.ovpn` file as a NetworkManager profile; with no path, open the file chooser (*Import a file…* in the card) |
| `add <kind>` | Create a VPN in NetworkManager's connection editor: `wireguard`, or `vpn` for the installed plugins (OpenVPN, L2TP…); `nmtui` in your terminal when the editor is not installed |

```kdl
bind "Super+Alt+V" { spawn "inir" "vpn" "toggle"; }
```

---

### niriAnimations

Presets for Niri's own window, workspace and overview animations. Applying one rewrites the animations in `config.d/60-animations.kdl` and keeps `off` and `slowdown` as they were. The same picker lives in Settings in every family. Your own presets go in `~/.config/inir/niri-animation-presets.json` as `{"presets": [...]}`, in the same shape as `defaults/niri-animation-presets.json`; one with a shipped id replaces it.

| Function | Description |
|----------|-------------|
| `list` | List the presets; `*` marks the one your config matches |
| `active` | Print the preset your config matches, or `custom` after hand edits |
| `apply <id>` | Apply a preset: `snappy`, `niri`, `material`, `bouncy`, `gentle`, `instant` or one of yours |

```kdl
bind "Super+Alt+A" { spawn "inir" "niriAnimations" "apply" "snappy"; }
```

---

### iris

iRiS bar and Island design. Available while the iRiS bar is enabled.

| Function | Description |
|----------|-------------|
| `open` | Expand the island on the focused output |
| `close` | Collapse the island |
| `page` | Expand the island on a page: `media`, `activity`, `desktop`, `tray` or `tools`, or step through its navigation with `next` / `prev` (the same path as scrolling over the navigation row) |
| `toggle` | Expand or collapse the island on the focused output |
| `card` | `open`, `close` or `toggle` the media bubble's floating card, or `pin` to keep it open |
| `settings` | Open iRiS Settings on a section: `general`, `appearance`, `motion`, `bar`, `bubbles`, `dock`, `desktop`, `windows`, `sidebars`, `controlCenter`, `spotlight`, `notifications`, `sound`, `capture`, `display`, `keyboard`, `battery`, `gaming`, `lock`, `player`, `anime`, `sources` or `system`; add `/<group>` to open that group, e.g. `bubbles/behaviour` or `lock/security`. It also takes `next`, `prev`, `back`, `forward` (the history), `search:<words>` and `open` (the first result) |
| `bubble` | Place an Island bubble (`left`, `right`, `utility`) or an extra bubble (`weather`, `notifications`, `controls`, `sound`, `mic`, `tools`, `media`, `tray`): a zone (`top-left`, `top-right`, `left`, `right`, `bottom-left`, `bottom-right`), `edge:<top|bottom|left|right>` with an optional `:<fraction>` along that edge (e.g. `edge:top:0.3`), `x,y` fractions of the output, `island` (slots) or `off` (extras) |
| `dock` | `reveal`, `hide` or `toggle` the iRiS Dock (revealed stays until hidden or an app is chosen) |
| `dockApp` | Open a Dock app's `windows` or `menu` by app id (e.g. `kitty windows`), or `<any> close` |
| `appBubble` | Carry a Dock app out as a bubble of its own (e.g. `kitty right`): a zone, `x,y` fractions of the output, or `dock` to send it back |
| `pin` | Keep the `left` (Focus) or `right` (Today) panel open beside windows, or stop |
| `accent` | Set iRiS accent: `blue`, `mint`, `rose`, `lilac` or `wallpaper` |
| `arrange` | Arrange the Island's desktop page in place — move, remove and add its blocks: `on`, `off` or `toggle` |
| `activity` | Publish a live activity into the Island from any script: `<action> <id> <value>` — `start <id> <title>`, `title`, `progress` (`0.4`, `40`, `40%` or `-1` for indeterminate), `detail`, `glyph` (a Material Symbol), `tint` (`blue`, `sky`, `teal`, `green`, `yellow`, `orange`, `red`, `pink`, `indigo`, `purple`, `lavender`, `gray`), `end <id> <detail>` (shows a done event and retires), `dismiss <id> -`, `clear all -`. Values cannot contain commas |
| `activities` | Return the live activities scripts have published, as JSON |
| `motion <target>` | Measure how a Place opens, closes and reverses halfway, from the expanded Island: `spotlight`, `gallery`, `settings`, `focus` or `today`. Read the result with `motioned` |
| `motioned` | The last `motion` measurement as JSON: frame pace, continuity, material, one surface, origin and a clean end, each passed or not, with the numbers behind them |
| `edit` | Customize iRiS on the shell itself: the Island grows a capsule (Themes, Look, Pieces, undo, Done) and whatever you click (a piece, the Island, the Dock) grows its own options: `on`, `off`, `toggle`, a sheet (`themes`, `pieces`, or a Look tab: `material`, `colour`, `type`, `motion`, `bodies`, `places`, `transients`, `desktop`), `island`, `dock` or a piece to inspect (`vitals`, `left`, `app:kitty`) |
| `control` | Arrange the Control Center in place (drag controls, resize them from a corner, add or take them out): `edit`, `done`, `toggle`, `undo`, `tab:<controls\|layouts\|panel>` to open the side library on that page, `expand:<display\|system\|devices\|network\|bluetooth\|none>` to open the Control Center with that expansion unfolded, or a layout (`iris`, `discs`, `compact`, `glance`, `studio`, `everything`) |
| `lock` | Rehearse the lock screen (the real surface, editable, with nothing to unlock): `edit`, `done`, `toggle`, `page:<name>` to open the inspector on a page (`layouts`, `scene`, `type`, `clock`, `widgets`…), `widget:<key>` to put a desktop widget on the lock or take it off (`clock`, `weather`, `monthCalendar`…), `select:<key>` to select one on the lock and open its controls in the inspector (`select:<key>/look` for shape, material and opacity; `/arrange`, `/widget`), or a layout (`iris`, `centered`, `corner`, `minimal`) |
| `studio` | Same as `edit`, kept for old keybinds: `on`, `off`, `toggle` or a sheet/target to open Customize on |
| `barPiece` | Turn one of the Island's own pieces on or off: `weather`, `notifications`, `controls`, `sound`, `mic`, `tools`, `media` or `tray`, plus `on`, `off` or `toggle` |
| `notch` | Melt the Island into its edge (or into the Surround band): `on`, `off` or `toggle` |
| `surround` | Close the shell around the screen with a band on every edge: `on`, `off` or `toggle` |
| `layout` | How the Island sits on its edge: `island`, `left`, `right`, `full` or `menubar` (top or bottom) |
| `strip` | What the menu bar lays under its items: `transparent` (on the wallpaper) or `band` |
| `edge` | Move the Island to a screen edge: `top`, `bottom`, `left` or `right` (on a side edge it rests as an upright capsule and its pages grow inward) |
| `dockEdge` | Move the Dock: `auto` (opposite the Island), `top`, `bottom`, `left` or `right` |
| `zone` | What a full-width Island carries in a zone: `start`, `center` or `end`, then kinds joined by `+` (`island`, `workspaces`, `window`, `time` or a piece kind), or `none` |
| `preset` | Set the iRiS appearance preset: `iris`, `soft`, `round`, `crisp`, `angular` or `contrast` |
| `theme <action>` | iRiS themes, each a whole redesign of the family: `list`, `apply:<id>`, `save:<name>` (what you see now becomes a theme file), `import:<path>` (a shared `.json`), `export` or `export:<id>` (prints the theme as JSON to share) and `folder` (where theme files live, `~/.config/inir/iris/themes`) |
| `morph` | Set how iRiS morphs: `direct`, `liquid`, `glide`, `snap`, `elastic` or `instant` |
| `set` | Set any iRiS option by path, e.g. `iris.appearance.theme.pieceShape squircle` or `iris.bubbles.scale 120` (values are JSON when they parse) |
| `adaptive` | How much the wallpaper shapes iRiS, `0`-`100`; any other word prints what was read from the wallpaper |
| `spotlight` | Open Spotlight with a query already typed, e.g. `firefox` or `12*7` (empty for suggestions) |
| `spotlightClose` | Close Spotlight |
| `gallerySource` | Show or hide an online source in the wallpaper gallery: `wallhaven`, `live`, `konachan` or `yandere`, then `on`, `off` or `toggle`; returns the sources shown, in order |
| `bubbleCard` | Grow a bubble's own card: `weather`, `notifications`, `sound`, `mic`, `tools` or `tray` (from the bubble showing it, else the Island), or `close` |
| `tap` | Tap a piece the Island carries (`controls`, `sound`, `tray`, `notifications`, `weather`…) as a click would: its card or page grows from it, or says the focused screen's bar has no such piece |
| `bubbleMenu` | Open a floating bubble's own menu — what it opens, where it rests and how to put it away — by kind (`weather`, `sound`, …) or piece id (`app:kitty`) |
| `icon <piece> <glyph>` | Choose the glyph a piece wears: `controls`, `tools`, `focus`, `notifications`, `bluetooth`, `updates`, `anime` or `watching`, then a Material Symbol name (e.g. `inir iris icon controls settings`) or `reset` to go back to its own face |
| `utility` | Set the utility satellite: `tray`, `tools`, `sound`, `mic` or `none` |
| `desktopMenu <x> <y>` | Open the desktop menu on the focused output at that point, in pixels; no point opens it in the middle |
| `menuClose` | Close whichever iRiS or shell context menu is open |
| `watch` | What the Continue bubble has in progress, or resume one of them: no argument lists them numbered with the episode and saved position, a number or part of a title resumes that show. Anything that matches nothing in progress starts a search instead. Only ani-cli can be pointed at one show; jerry and curd run their own picker |
| `watchPick` | Answer whatever the Continue bubble is asking (which show, which episode, what next once one ends, which quality): no argument lists the options, a number or part of a label chooses one, `cancel` stops the run |
| `watchSkip` | Close the episode that is playing and start the `next` (default) or `previous` one without searching again. Its place is saved first |
| `watchSubs` | Subtitles of the episode that is playing: `size+`, `size-` (kept for every episode), `delay+`, `delay-`, `delay0` (this episode), `off`, `track:<id>`, `file:<path>` to load one. No argument lists the tracks |
| `watchSeek` | Jump inside the episode that is playing by seconds: `85` skips an opening, `-10` goes back |
| `status` | JSON with the Island, Dock, Control Center, Spotlight and side panel state, which edit modes, Settings or the wallpaper gallery hold the screen (`editing`, `settings`, `gallery`), plus the player the Island follows (title, position, length) |

```bash
inir iris open
inir iris page desktop
inir iris toggle
inir iris dock toggle
inir iris card toggle
inir iris bubble right top-right
inir iris appBubble kitty top-right
inir iris pin right
inir iris status
inir iris close
```

### panelFamily

Switch between the three shell families: Material ii (default), Waffle (Windows 11-like), and iRiS (the Island family).

| Function | Description |
|----------|-------------|
| `cycle` | Switch to the next family in the switch list (`familyCycle`, in its order; all three by default, set in any family's Settings) |
| `set` | Set specific family ("ii", "waffle", or "iris") |

```kdl
bind "Mod+Shift+W" { spawn "inir" "panelFamily" "cycle"; }
```

---

### globalStyle

The Global Style every Material surface and desktop widget follows: material, cards, aurora, inir, angel, regalia, zzz, cookie or editorial.

| Function | Description |
|----------|-------------|
| `set` | Switch to a style by name, with its bar corner and card defaults |
| `get` | Return the active style |
| `list` | List the styles |

```kdl
bind "Mod+Alt+S" { spawn "inir" "globalStyle" "set" "aurora"; }
```

---

### shellLayout

Dedicated persistent-shell layout editing and diagnostics. It is independent
from desktop widget edit mode. It moves the ii bar and dock, swaps semantic ii
sidebars between physical edges, resizes sidebar roles, and moves the Waffle
taskbar through validated operations over canonical Config keys.

| Function | Description |
|----------|-------------|
| `toggle` | Enter or leave shell edit mode |
| `open` | Enter shell edit mode on the focused output |
| `openOn` | Enter shell edit mode on a named output |
| `close` | Leave shell edit mode and clear transient selection |
| `select` | Select a surface for deterministic editing or diagnostics |
| `lift` | Select and lift a surface for placement |
| `preview` | Preview a legal slot without writing Config |
| `place` | Commit the lifted surface to a validated slot; occupied sidebar edges require the same call twice |
| `cancel` | Cancel the current lift, preview, confirmation or gesture |
| `dragStart` | Lift a surface and start a pointer-style drag |
| `dragUpdate` | Feed screen coordinates to the active drag; previews the nearest legal edge |
| `dragEnd` | Drop the dragged surface: commits the previewed edge (occupied sidebar edges swap directly) or cancels in the center |
| `reset` | Restore one surface to its default placement and supported dimensions |
| `setProperty` | Set a supported surface property (`sizeMode`, sidebar `height`, sidebar `thickness`, or dock `thickness`) |
| `handleEscape` | Apply editor Escape priority: cancel pending work, then leave edit mode |
| `status` | Return edit-session, host diagnostics and active-family surface descriptors as JSON |
| `validate` | Validate a surface and slot combination without changing Config |

```bash
inir shellLayout open
inir shellLayout lift featureSidebar
inir shellLayout preview right
inir shellLayout place right   # prepares the occupied-edge swap
inir shellLayout place right   # confirms and commits it
inir shellLayout setProperty featureSidebar sizeMode fit
inir shellLayout reset featureSidebar
inir shellLayout close
```

```kdl
bind "Super+W" { spawn "inir" "shellLayout" "toggle"; }
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
| `minimizeId` | Minimize a window by Niri window ID |
| `restore` | Restore a minimized window by ID |
| `restoreOriginal` | Restore a minimized window to the workspace it came from |

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

### keyboard

Keyboard layout switching (Niri only). Cycles through configured keyboard layouts and queries layout info.

| Function | Description |
|----------|-------------|
| `switchLayout` | Switch to next keyboard layout |
| `switchLayoutPrevious` | Switch to previous keyboard layout |
| `getCurrentLayout` | Get the current layout name |
| `getLayouts` | Get all configured layout names (JSON array) |

```kdl
bind "Mod+Alt+K" { spawn "inir" "keyboard" "switchLayout"; }
```

---

### zoom

Screen zoom. Accessibility feature, or for reading tiny UI without pretending your monitor is the problem.

| Function | Description |
|----------|-------------|
| `zoomIn` | Increase compositor zoom |
| `zoomOut` | Decrease compositor zoom |

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
| `open` | Open action center |
| `close` | Close action center |

---

### wnotificationCenter

Waffle notification center.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close notification center |
| `open` | Open notification center |
| `close` | Close notification center |

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

### waffleAltSwitcher

Waffle Alt+Tab window switcher. Separate from the ii `altSwitcher`, supports quick-switch (first tab switches instantly, second opens UI) and no-visual-UI mode.

| Function | Description |
|----------|-------------|
| `open` | Open switcher |
| `close` | Close switcher |
| `toggle` | Toggle switcher |
| `next` | Focus next window |
| `previous` | Focus previous window |

---

### background

Desktop background and widget controls.

| Function | Description |
|----------|-------------|
| `widgetDesign name` | Put every desktop widget on `iris`, `material`, `individual`, `instrument` or `readout`; `undo` brings back the design and each widget's own look from before; `status` reports the design, how many widgets keep their own look and whether an undo is available. |
| `toggleEditMode` | Toggle widget edit mode (drag, resize, configure desktop widgets) |
| `toggleWidgetManager` | Enter edit mode if needed and toggle the widget manager on the focused output |
| `setEditMode enabled` | Set widget edit mode explicitly |
| `editState` | Report the active selection, physical panel insets, full desktop work area and panel-aware zone work area for each output |
| `desktopItemsState` | Report desktop-item persistence, availability, item count, validation errors and undo state |
| `quickControlsPage page` | Show a page of the selected widget's quick controls: widget, look or arrange |
| `quickControlsGeometry` | Report where the selected widget's toolbar and quick-controls sheet sit, as JSON |
| `legibilityState` | Report what each desktop widget reads under itself (brightness, spread, light or dark backdrop) and the ink and accent it chose |
| `focusWidget widgetName openControls` | Select a desktop widget and optionally open its quick controls |
| `promoteWidget widgetName` | Move a desktop widget to the top of the persistent layer order |
| `resetLayerOrder` | Reset desktop widgets to their built-in stacking order |
| `setWidgetEnabled widgetName enabled` | Enable or disable a built-in desktop widget |
| `applyOrganicEdgePreset name` | Apply an Organic Edge scene by name without changing enabled displays |
| `applyOrganicEdgeComposition name` | Apply only an Organic Edge topology/geometry preset |
| `applyOrganicEdgeMaterial name` | Apply only an Organic Edge material/light preset |
| `applyOrganicEdgeResponse name` | Apply only an Organic Edge music-response preset |
| `organicEdgeState` | Report each Organic Edge output, selected edges, frame, audio subscription and shader status |
| `setOrganicEdgeEnabled enabled` | Enable or disable the independent Organic Edge screen field |
| `clockDebugState` | Report clock palette, renderer and quick-control geometry diagnostics |
| `clockDebugSetMode digital\|cookie adaptToWallpaper` | Temporarily select a diagnostic clock mode |
| `clockDebugSetRegion color brightness spread` | Inject a temporary wallpaper-region sample |
| `clockDebugSetLayout x y quickControlsOpen` | Probe quick-control geometry at a hypothetical clock position without moving the widget |
| `clockDebugRestore` | Restore the config captured by clock diagnostics |

The mutating diagnostic functions require the supervised shell to be loaded
with `INIR_REGION_DEBUG=1`. They snapshot the clock's relevant config on first
use; always finish a diagnostic run with `clockDebugRestore` before removing
the environment flag.

```kdl
bind "Super+W" { spawn "inir" "background" "toggleEditMode"; }
```

---

### customWidgets

Custom widget management. Create, list, reload, and remove user-installed widgets from `~/.config/inir/widgets/`.

| Function | Description |
|----------|-------------|
| `reload` | Re-scan widgets directory and reload all custom widgets |
| `list` | List all discovered custom widgets (JSON output) |
| `create` | Create a new widget scaffold in the widgets directory |
| `remove` | Remove a custom widget by ID |

---

### widgetpower

Desktop-widget power management (pauses widget rendering on game mode, fullscreen, present windows, or edit mode). Service: `services/WidgetPowerManager.qml`.

| Function | Description |
|----------|-------------|
| `status` | Returns JSON: `enabled`, `widgetsActive`, `pauseReason`, and the active `triggers` (gameMode, fullscreen, windowsPresent, editMode) |

---

### recordingOsd

Screen recording floating pill OSD. Shows elapsed time and stop button during active recording.

| Function | Description |
|----------|-------------|
| `toggle` | Stop the current recording (if active) |
| `show` | Reveal the recording OSD pill |
| `hide` | Collapse/hide the recording OSD pill |

---

### autostart

Niri login autostart manager. Reads and writes the managed section of
`~/.config/niri/config.d/50-startup.kdl` (delimited by `// >>> inir-managed-autostart >>>` /
`// <<< inir-managed-autostart <<<`). Base iNiR lines and any hand-written
`spawn-at-startup` lines outside the markers are preserved verbatim; toggling an
entry comments the line out instead of deleting it. Safe no-op on non-Niri
compositors (the page shows a guard instead).

| Function | Description |
|----------|-------------|
| `status` | Return `niri\|<path>\|<managedCount>\|<externalCount>\|<state>` |
| `addApp <desktopId>` | Append a managed `gtk-launch <desktopId>` entry |
| `addCommand <cmd>` | Append a managed `spawn-sh-at-startup` shell line |
| `removeLast` | Remove the last managed entry |
| `reload` | Force re-read the startup file |

The Settings UI (ii: AutostartConfig, waffle: WAutostartPage) is the primary
interface; these IPC calls exist for scripts/keybinds. Apps the user already
launches via hand-written lines outside the markers are detected and shown as
"External" (read-only) in the list.

---

## Standalone Commands

These are top-level `inir` commands that work directly, without going through IPC.

### colorpicker

Launch `hyprpicker` to pick a color from anywhere on the screen. The hex value is copied to the clipboard (`-a` flag).

```kdl
bind "Super+Shift+C" { spawn "inir" "colorpicker"; }
```

Requires `hyprpicker` installed.
