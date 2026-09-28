# Compositor Integration

iNiR is built and tested for Niri. Legacy Hyprland compatibility code remains from the project's origins as a fork of end-4's Hyprland dots, but Hyprland is not the primary supported/tested target.

## Detection

`CompositorService` figures out which compositor is running by checking environment variables at startup:

1. `$HYPRLAND_INSTANCE_SIGNATURE` set? Hyprland.
2. `$NIRI_SOCKET` set? Niri.
3. `$XDG_CURRENT_DESKTOP` contains "GNOME"? GNOME (unsupported, but detected).
4. None of the above? Unknown.

Code that behaves differently per compositor uses guards:

```qml
if (CompositorService.isNiri) {
    // niri-only path
}

visible: CompositorService.isHyprland  // hide on other compositors
```

## Niri

Primary compositor. Full IPC integration.

### How it connects

`NiriService` opens a Unix socket at `$NIRI_SOCKET` and subscribes to the event stream. Every workspace change, window open/close, output hotplug, and keyboard layout switch arrives as a JSON event and updates reactive QML properties.

For commands (focus workspace, move window, etc.), a separate socket connection sends requests and reads responses.

### What it exposes

| Property | What it tracks |
|----------|---------------|
| `workspaces` | All workspaces with IDs, names, active state, output assignment |
| `windows` | All windows with title, app ID, position, size, workspace |
| `outputs` | All monitors with name, scale, resolution, position |
| `activeWindow` | Currently focused window |
| `focusedWorkspaceId` | Current workspace on the focused monitor |
| `keyboardLayoutNames` | Available keyboard layouts |
| `displayScales` | Per-monitor scale factors |

### Niri config management

iNiR manages Niri's config through modular KDL files in `~/.config/niri/config.d/`:

| File | What it controls |
|------|-----------------|
| `10-input-and-cursor.kdl` | Mouse, touchpad, keyboard, cursor theme |
| `20-layout-and-overview.kdl` | Workspace layout, gaps, struts |
| `30-window-rules.kdl` | Window rules (floating, size, opacity) |
| `40-environment.kdl` | Environment variables for apps |
| `50-startup.kdl` | Autostart entries (clipboard, polkit, etc.) |
| `60-animations.kdl` | Window animation settings |
| `70-binds.kdl` | All keybinds |
| `80-layer-rules.kdl` | Layer shell rules (for the shell itself) |
| `90-user-extra.kdl` | User overrides. Never touched by updates. |

`scripts/niri-config.py` does surgical edits to these files, preserving comments and unknown settings. It never rewrites entire files.

## Hyprland compatibility paths

Legacy paths use the built-in Quickshell Hyprland module plus `hyprctl` for queries that the module does not cover. They are retained for compatibility and code reuse, but their presence should not be read as the same support/test guarantee as Niri.

### Differences from Niri

| Aspect | Niri | Hyprland |
|--------|------|----------|
| IPC | Unix socket, JSON events | Quickshell module + hyprctl |
| Window sorting | Native via IPC | Complex 300+ line sort (monitor > workspace > column > Y) |
| Workspace model | Scrolling (infinite horizontal) | Fixed grid |
| Config | KDL, modular files | hyprland.conf |

### What's Hyprland-only

- `HyprlandData.qml`: window list, workspaces, monitors, layers
- `HyprlandKeybinds.qml`: keybind parsing for cheatsheet
- `HyprlandXkb.qml`: keyboard layout tracking

### What doesn't work on Hyprland

Some features require Niri-specific IPC that has no Hyprland equivalent:

- Workspace scrolling gestures
- Column-based window management
- Some Overview features

Where a legacy path is still wired, missing Niri-only features should be gated rather than crashing. That is a compatibility goal, not a claim that the complete shell is validated on Hyprland.

## Shared abstractions

`CompositorService` provides compositor-agnostic APIs that modules use instead of talking to Niri/Hyprland directly:

- `sortedToplevels`: sorted window list (delegates to the active compositor's sorting logic)
- `filterCurrentWorkspace(toplevels, screen)`: workspace-aware window filtering
- `powerOffMonitors()` / `powerOnMonitors()`: DPMS control

This means most UI components don't need compositor guards at all. They just read `CompositorService.sortedToplevels` and it works regardless of which compositor is running.

## For contributors

**Use compositor guards** when shared code contains a compositor-specific path. Niri remains the supported product target, but legacy/unsupported environments should not crash merely because an old adapter is present.

**Prefer shared abstractions** over direct NiriService/HyprlandData access when possible. If you need something that only Niri provides, gate it with `CompositorService.isNiri` and provide a fallback (even if the fallback is just hiding the feature).

For product acceptance, test Niri. If a change deliberately touches a retained Hyprland compatibility path, verify that path separately and describe the result as compatibility evidence rather than broad support.
