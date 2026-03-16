---
trigger: model_decision
description: Pull when changing or testing IPC targets, command names, or shell/service callable functions.
---

# iNiR IPC Reference (Verified from source code)

Canonical IPC launcher form: `inir <target> <function> [args]`
Low-level Quickshell form: `qs -c inir ipc call <target> <function> [args]`
No output = success. "Target not found" = broken.

## Shell-level targets

### settings
```
open(): void    — opens settings (overlay, window, or waffle window based on config)
toggle(): void  — alias for open()
```

### panelFamily
```
cycle(): void              — ii→waffle→ii with transition animation
set(family: string): void  — "ii" or "waffle"
```

### zoom (Hyprland only)
```
zoomIn(): void    — +0.4 (max 3.0)
zoomOut(): void   — -0.4 (min 1.0)
```

## Panel targets (defined in each module)

### altSwitcher
```
open(): void
close(): void
toggle(): void
next(): void       — select next window
previous(): void   — select previous window
```

### sidebar
```
toggleLeft(): void
toggleRight(): void
openLeft(): void
closeLeft(): void
openRight(): void
closeRight(): void
```

### overview
```
open(): void
close(): void
toggle(): void
```

### bar
```
toggle(): void     — show/hide bar
```

### dock
```
toggle(): void
```

### mediaControls
```
toggle(): void
open(): void
close(): void
```

### osd
```
volumeUp(): void
volumeDown(): void
brightnessUp(): void
brightnessDown(): void
showMedia(action: string): void  — "play"|"pause"|"next"|"previous"
```

### notifications
```
dismiss(): void         — dismiss all
toggleDnd(): void       — toggle Do Not Disturb
```

### overlay
```
toggle(): void
```

### cheatsheet
```
toggle(): void
```

### clipboard
```
toggle(): void
open(): void
close(): void
```

### controlPanel
```
toggle(): void
open(): void
close(): void
```

### session
```
open(): void
close(): void
toggle(): void
```

### lock
```
lock(): void
```

### regionSelector
```
open(): void
close(): void
toggle(): void
```

### wallpaperSelector
```
open(): void
close(): void
toggle(): void
```

### coverflowSelector
```
open(): void
close(): void
toggle(): void
```

### tilingOverlay
```
show(): void
hide(): void
```

### osk (on-screen keyboard)
```
toggle(): void
open(): void
close(): void
```

## Service targets

### audio
```
volumeUp(): void
volumeDown(): void
toggleMute(): void
toggleMicMute(): void
getVolume(): string
setVolume(vol: string): void
```

### brightness
```
increase(): void
decrease(): void
```

### idle
```
toggleInhibit(): void
```

### gameMode
```
toggle(): void
```

### hyprsunset
```
toggle(): void
increase(): void
decrease(): void
getTemperature(): string
```

### wallpaper
```
next(): void
random(): void
set(path: string): void
```

### theme
```
set(id: string): void
cycle(): void
```

### recorder
```
toggle(): void
togglePause(): void
```

### updates
```
check(): void
```

## Waffle-specific targets

### wStartMenu
```
open(): void
close(): void
toggle(): void
```

### wActionCenter
```
open(): void
close(): void
toggle(): void
```

### wNotificationCenter
```
open(): void
close(): void
toggle(): void
```

### wWidgets
```
toggle(): void
```

### wClipboard
```
toggle(): void
```

### wTaskView
```
toggle(): void
```

### wAltSwitcher
```
open(): void
close(): void
next(): void
previous(): void
```
