# Autostart and Session

How iNiR starts, how apps autostart, and how sessions end.

## Shell startup

iNiR itself runs as a systemd user service. It does not start via niri's `spawn-at-startup`. This gives it crash recovery, proper lifecycle management, and journal logging.

The service connects to your compositor via a wants link:

```
~/.config/systemd/user/niri.service.wants/inir.service
```

When Niri starts, `inir.service` waits for the `Type=notify` compositor service to report ready, so it inherits Niri's authoritative `DISPLAY`, `WAYLAND_DISPLAY` and `NIRI_SOCKET`. When Niri stops, iNiR stops. Manage the link with:

```bash
inir service enable     # create wants link
inir service disable    # remove it
inir service status     # check state
```

For the full boot sequence, see [Runtime and Boot Pipeline](RUNTIME.md).

## App autostart

There are two layers of autostart in a typical iNiR setup:

### Compositor level (spawn-at-startup)

These are defined in `~/.config/niri/config.d/50-startup.kdl` and managed by the compositor:

- `wl-paste --type text --watch cliphist store` (clipboard text history)
- `wl-paste --type image --watch ~/.config/quickshell/inir/scripts/clipboard-image-store.sh` (clipboard image history; internal preview frames are filtered)
- `polkit-mate-authentication-agent-1` (GUI sudo prompts)
- `kbuildsycoca6` (KDE desktop entry cache)

These run before iNiR starts and are independent of the shell.

### Shell level (Autostart service)

iNiR has its own autostart manager that handles:

- **Desktop entries**: standard `.desktop` files in `~/.config/autostart/`
- **Custom commands**: user-defined commands configured through Settings
- **Systemd units**: user-level systemd services

Manage autostart entries from Settings > System > Autostart (there is no CLI for this, it is managed through the settings UI, backed by `services/Autostart.qml`).

## Lock screen

The lock screen uses Wayland's session lock protocol (WlSessionLock). This is a security protocol: when active, all other surfaces are hidden and only the lock surface is visible. There's no way to bypass it by switching workspaces or killing processes.

### Authentication

- **Password**: PAM authentication (same as your login password)
- **Fingerprint**: supported if your system has fprintd configured

### Fallback

If the QML lock surface fails to render within 2 seconds, iNiR falls back to swaylock or hyprlock (whichever is installed). This prevents the session from being locked with no visible unlock UI.

### IPC

```bash
inir lock activate     # lock the session
inir lock deactivate   # unlock (requires auth)
inir lock status       # check lock state
```

### Config

Lock settings are in Settings > System > Lock:
- Blur background (on/off)
- Auto-lock on startup
- Unlock GNOME Keyring after authentication

## Session screen

The session screen provides logout, reboot, shutdown, and suspend actions. Access it from:
- Keybind (configurable)
- Power button in the bar/taskbar
- IPC: `inir session open`

Before executing an action, the session screen checks for running package managers and active downloads. If found, it warns you before proceeding.

## Polkit agent

iNiR includes a PolicyKit authentication agent. When a privileged operation needs authorization (installing a package, mounting a disk), a dialog appears asking for your password.

The shell's polkit agent coexists with the system one (mate-polkit, which niri starts). If the shell's agent fails to register (because another one is already active), that's fine. You'll still get prompted.

Disable the shell's agent with `QS_DISABLE_POLKIT=1` if it causes issues.

## Idle management

Idle timeouts are handled by swayidle, configured through Settings or IPC:

- **Screen off**: turn off monitors after inactivity (default: 5 minutes)
- **Lock**: lock the session after inactivity (default: 10 minutes)
- **Suspend**: suspend the system after inactivity (default: off)

Idle timeouts are configured in Settings (backed by `services/Idle.qml`); there is no `inir idle` CLI command.

Fullscreen video players and presentations automatically inhibit idle via the idle-inhibit Wayland protocol.
