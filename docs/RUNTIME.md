# Runtime and Boot

What happens between login and the shell on screen.

## The sequence

```
Login: Niri starts and publishes DISPLAY, WAYLAND_DISPLAY and NIRI_SOCKET
  -> inir.service (systemd, after niri.service), or a runit service on Void
  -> inir run --session                       (scripts/inir)
  -> Quickshell on ~/.config/quickshell/inir  (loads shell.qml)
  -> Tier 0, at once: Idle, PowerProfilePersistence, DevNavigation,
     ShellEditSession, TrayService, MemoryPressureService, GlobalActions,
     PackageSearch; FirstRunExperience and ConflictKiller load
  -> Config.ready: apply the theme, init the icon theme, load the
     family's critical host (ii: background, bar, dock; Waffle: taskbar,
     background, backdrop; iRiS: background and Island chassis)
  -> shell entry: 200 ms after Config.ready (0 with animations off)
  -> Tier 3, 500 ms after the first frame: GameMode, FontSyncService,
     Hyprsunset; then WindowPreviewService, Weather, VoiceSearch and
     CavaTheme (not iRiS); ScreenTime if enabled. Sets
     GlobalStates.deferredPanelsReady, so the family's deferred panels load
  -> Tier 4, 1000 ms after Tier 3: ShellUpdates, Autostart, Hub,
     NiriAnimationPresets; CalendarSync, Todo, Notepad (not iRiS)
```

Boot phases are written to `~/.cache/inir/last-boot.json`, and `inir status` shows them.

## systemd (`assets/systemd/inir.service`)

- The unit is `PartOf` and `Requisite` `niri.service` and starts `After` it. It waits for `org.kde.StatusNotifierWatcher` (`Type=dbus`).
- It is enabled by a wants link, `~/.config/systemd/user/niri.service.wants/inir.service`, never by `graphical-session.target`. That keeps it off other desktops.
- Manage the link with `inir service enable`, `inir service disable` and `inir service status`.

## Void (runit)

Setup renders a run file under `~/.config/service/`, and one of two owners starts it:

- **Turnstile**: runit starts iNiR with the session environment that Niri hands over. This run file sets `QS_DISABLE_POLKIT=1`, so the polkit agent that Niri starts in the seat session handles authentication.
- **Fallback**: Niri starts a single `runsvdir ~/.config/service`. This path does not set `QS_DISABLE_POLKIT`.

`sv` controls the service on this tier.

## The launcher

`scripts/inir` is about 5,000 lines of bash. `inir run` does what a bare `qs` does not:

- Checks Quickshell and Qt ABI compatibility.
- Sets `QT_SCALE_FACTOR=1` and `QT_SCALE_FACTOR_ROUNDING_POLICY=RoundPreferFloor`, and a `QT_LOGGING_RULES` filter.
- Unsets `QT_WAYLAND_FORCE_DPI`, `QT_FONT_DPI`, `QT_AUTO_SCREEN_SCALE_FACTOR`, `QT_SCREEN_SCALE_FACTORS`, `GDK_SCALE` and `GDK_DPI_SCALE`.
- With `--session`, uses the environment Niri already published. It never guesses sockets.
- Runs Quickshell on the runtime directory: `~/.config/quickshell/inir`, or a system copy under `/usr/local/share/quickshell/inir` or `/usr/share/quickshell/inir`.

Do not start Quickshell by hand. That bypasses the launcher's ownership and can duplicate the supervised shell. Use `inir restart`, `inir logs` and `inir doctor` instead.

`inir logs --debug` stops the supervised shell and runs it in the foreground with `QS_DEBUG=1`. Press Ctrl+C, then run `inir restart`.

## Config loading

1. `Config.qml` reads `Directories.shellConfigPath`, which is `~/.config/illogical-impulse/config.json`. Since v2 that path is a link to `~/.config/inir/`, where the installer writes the file.
2. A `JsonAdapter` parses the file. Schema properties bind to the values, with fallbacks.
3. `Config.ready` turns true, and everything waiting on config starts.

The installer copies `defaults/config.json` into place (`sdata/subcmd-install/3.files.sh`, around line 669). Config.qml does not create the file. An external edit reloads after `readWriteDelay` (50 ms). QML writes go through `Config.setNestedValue`.

## Crash recovery

- **systemd**: restarts on failure after 5 s, at most 3 starts in 30 s. `ExecStopPost` runs `inir cleanup-orphans`. Exit code 143 (SIGTERM) counts as success.
- **runit**: runit restarts the service.
- **Session start**: stale helpers owned by iNiR (old `swayidle` instances, for example) are removed before the next shell starts.

## Debugging

```bash
inir logs             # recent runtime logs
inir logs --issues    # every warning and error since start, grouped
inir logs --full      # all log categories
inir logs --debug     # foreground run with QS_DEBUG=1
inir status           # install state and boot timing
inir doctor           # health checks
inir doctor --perf    # read-only snapshot of the running shell
inir repair           # automated repair
```
