# Managed desktop items

The ii desktop can store references to applications, files, folders and URLs.
Dropping an item creates a shortcut at that position without moving, copying or
deleting the original target. One click selects it; double click opens it.

Applications dragged from Overview search or All Apps carry only their
installed desktop-entry ID through a native desktop drag. The drop is resolved
by the desktop surface under the pointer, so mixed-resolution monitor layouts
use that output's own work area and grid. iNiR resolves the ID through its
normal launcher path and never executes a dropped `.desktop` file directly.
Overview releases only its input region during the drag; canceling it restores
normal Overview interaction and creates no desktop item.

The context menu can move an item to another connected monitor. Its relative
position is preserved and clamped to that monitor's panel-safe work area.
Dragging an item that was recovered from a disconnected output adopts the
output where it is released. The menu opens at the pointer position that
invoked it rather than at a fixed edge of the icon.

Desktop references share the desktop-widget edit grid. When grid snapping is
enabled, drops, drag releases and monitor moves choose the nearest free cell
using `background.widgets.editGrid.size`; occupied cells are skipped so icons
stay aligned and do not stack on top of each other. Locked references are not
rearranged when the grid changes.

## Dropping images

Dropping an image on an empty desktop opens three choices:

| Choice | Result |
| --- | --- |
| File access | Stores a shortcut that opens the original image. |
| Decorative image | Enables and moves the single Custom Image widget to the drop point. If several images are dropped, the first one is used. |
| Convert image | Sends the files to the existing Image Converter queue. When conversion finishes, **Place result here** creates a shortcut to the output. |

Drops directly on the Custom Image or Image Converter widget keep that
widget's existing action.

## Repair and removal

Missing targets stay visible with a broken-state marker. For file and folder
references, **Locate target** opens the target's parent folder. Missing
application references are repaired with **Edit destination**. **Remove from desktop** only
removes iNiR's reference. It never deletes the application or file. The latest
removal can be restored with **Undo remove**.

Desktop items are stored in:

```text
${XDG_STATE_HOME:-~/.local/state}/quickshell/user/desktop-items.json
```

The file is included in setup snapshots and restored with the rest of the
shell state.
