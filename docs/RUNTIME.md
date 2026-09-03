# Runtime and Boot Pipeline

What happens between "user logs in" and "shell is on screen", step by step.

## The full sequence

```
User logs in
  |
Display manager starts Niri through its managed session
  |
Niri publishes DISPLAY, WAYLAND_DISPLAY and NIRI_SOCKET to the user manager
  |
niri.service reports READY
  |
systemd starts inir.service (niri.service.wants link)
  |
ExecStart calls: /usr/bin/inir run --session
  |
inir script (bash):
  - Validates QS/Qt ABI compatibility
  - Sets QT_SCALE_FACTOR=1
  - Suppresses noisy Qt log categories
  - Inherits Niri's published session environment without guessing sockets
  - Launches: qs -c inir
  |
Quickshell loads shell.qml
  |
ShellRoot initialization:
  1. Force-instantiate Idle and PowerProfilePersistence
  2. Load FirstRunExperience (checks if first run)
  3. Load ConflictKiller (kills conflicting trays/notification daemons)
  4. Wait for Config.ready
  |
Config.ready fires:
  1. Apply current theme (ThemeService.applyCurrentTheme)
  2. Initialize icon theme
  3. Migrate enabledPanels if needed
  4. Start shell entry timer (200ms delay for animation)
  5. Schedule deferred init (500ms for non-critical services)
  |
Panel loading:
  - Selects ShellIiPanels or ShellWafflePanels based on panelFamily
  - Each PanelLoader activates when its conditions are met
  - Immediate panels load first (bar, background, OSD)
  - Deferred panels load after GlobalStates.deferredPanelsReady
  |
Shell entry animation completes
  |
Deferred services load (GameMode, Weather, etc.)
  |
Shell fully operational
```

## Service wiring

The systemd service is the key piece. It does not use `systemctl enable` in the traditional sense because there's no `[Install]` section. iNiR is Niri-only, so it creates a wants link from `niri.service`:

`~/.config/systemd/user/niri.service.wants/inir.service`

`inir.service` is ordered **after** the `Type=notify` Niri service and requires it to be active. This means iNiR starts only after Niri has published the authoritative graphical-session environment, and stops/restarts with Niri. It will never accidentally start under KDE, GNOME, or another compositor.

Managing the link:

```bash
inir service enable    # create the wants link
inir service disable   # remove it
inir service status    # check current state
```

## The inir launcher

`scripts/inir` is a 3600+ line bash script that wraps Quickshell. It's not the same as running `qs -c inir` directly:

| | `inir run` | `qs -c inir` |
|---|---|---|
| Environment setup | Sets shell-only Qt policy and inherits Niri's session env | Raw environment |
| Output | Backgrounded, logs to journal | Foreground, direct stdout |
| Crash recovery | systemd restarts on failure (max 3 in 30s) | None |
| ABI check | Validates Quickshell/Qt compatibility | None |
| Orphan cleanup | ExecStopPost cleans stale runtime | None |

For development and debugging, `qs -c inir` (direct mode) is usually better because you get stdout immediately. For daily use, the systemd service handles everything.

## Environment variables

The launcher sets these before starting Quickshell:

| Variable | Value | Why |
|----------|-------|-----|
| `QT_SCALE_FACTOR` | `1` | Shell handles its own scaling in QML |
| `QT_SCALE_FACTOR_ROUNDING_POLICY` | `RoundPreferFloor` | Prevents blurry rendering with fractional compositor scaling (1.25 etc) |
| `QT_LOGGING_RULES` | (long list) | Suppress known-harmless Qt/QML warnings |

The launcher also unsets inherited DPI variables that would cause blur: `QT_WAYLAND_FORCE_DPI`, `QT_FONT_DPI`, `QT_AUTO_SCREEN_SCALE_FACTOR`, `QT_SCREEN_SCALE_FACTORS`, `GDK_SCALE`, `GDK_DPI_SCALE`.

The `--session` flag (used by systemd) consumes the graphical environment that Niri has already published to the user manager. iNiR does not rewrite `DISPLAY`, `WAYLAND_DISPLAY`, or `NIRI_SOCKET`; manual recovery launches may copy missing values from the manager, but they never infer them from filesystem sockets.

## Config loading

`Config.qml` uses Quickshell's `FileView` to read the user's JSON config file. The loading sequence:

1. FileView reads `~/.config/illogical-impulse/config.json`
2. JsonAdapter parses the content
3. Schema properties bind to parsed values (with fallbacks)
4. `Config.ready` becomes true
5. Everything that was waiting on config starts loading

If the config file doesn't exist (fresh install), Config creates it from `defaults/config.json`.

Hot-reload: if you edit config.json externally, FileView detects the change and re-parses within 50ms.

## Panel loading

Each panel is wrapped in a `PanelLoader`:

```qml
PanelLoader {
    identifier: "iiBar"
    extraCondition: !(Config.options?.bar?.vertical ?? false)
    component: Bar {}
}
```

A panel loads when all three conditions are true:

1. `Config.ready` is true
2. The identifier exists in `Config.options.enabledPanels`
3. `extraCondition` evaluates to true

Panels are split into immediate (load at first frame) and deferred (load after `deferredPanelsReady`):

**Immediate**: bar, background, notification popup, OSD. These need to be visible right away.

**Deferred**: sidebars, overview, clipboard, lock screen, cheatsheet. These load after the shell is already on screen and responsive.

## Crash recovery

The systemd service has:

- `Restart=on-failure` with `StartLimitBurst=3` and `StartLimitIntervalSec=30`
- If iNiR crashes, systemd restarts it (up to 3 times in 30 seconds)
- `ExecStopPost` runs `inir cleanup-orphans` to clear stale Quickshell runtime entries
- Exit code 143 (SIGTERM) is treated as success, not failure

## Deferred initialization

Non-critical services load 500ms after the first frame to reduce boot contention:

- GameMode (fullscreen detection)
- WindowPreviewService (alt-tab previews)
- Weather (API polling)
- VoiceSearch (Gemini transcription)
- FontSyncService (GTK/KDE font sync)
- Hyprsunset (night light)

This keeps the initial frame fast. The bar and background appear immediately, everything else fills in shortly after.

## Debugging startup

If the shell won't start:

```bash
# Direct stdout (bypass systemd)
qs -c inir

# Verbose internal logging
qs -v -c inir

# Extra verbose
qs -vv -c inir

# Debug-level service logging
QS_DEBUG=1 qs -c inir
```

Check `inir logs` for recent journal output, or `inir doctor` for automated diagnostics.

## Performance diagnostics

`inir doctor --perf` prints a read-only snapshot of the running shell. It reports
process memory and threads, the observed Qt Quick RHI and render loop, DRM render
nodes, Qt Multimedia decoder ownership, open video and GIF files, mapped Niri
layer surfaces, child processes, and the `inir.service` cgroup.

```bash
inir doctor --perf
```

Use it before changing graphics environment variables or blaming one feature for
the complete service cgroup. The snapshot distinguishes Quickshell from helpers
and applications, and flags duplicate media files opened by more than one
renderer.
