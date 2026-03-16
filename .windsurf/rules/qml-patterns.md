---
trigger: model_decision
description: Pull when creating or editing QML components, singleton patterns, bindings, null-safe config access, imports, animations, or common QML structure.
---

# QML Patterns — iNiR (Verified from source code)

## File Template

```qml
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services
```

Import order: Qt core → Quickshell → qs.modules.common → qs.modules.common.widgets → qs.services → local

## Component Internal Order

```qml
Item {
    id: root

    // 1. Required properties
    required property var modelData

    // 2. Regular properties (typed, never var unless truly variant)
    property bool someFlag: false
    property string configValue: Config.options?.section?.key ?? "default"

    // 3. Readonly / computed
    readonly property bool isActive: someFlag && GlobalStates.overviewOpen

    // 4. Signals
    signal itemSelected(var item)

    // 5. Functions (explicit return types)
    function toggle(): void { someFlag = !someFlag }

    // 6. Connections
    Connections {
        target: Config
        function onReadyChanged() { if (Config.ready) { /* init */ } }
    }

    // 7. Child components
    Rectangle { /* ... */ }
}
```

## Config Access

### Read (ALWAYS safe pattern)
```qml
readonly property bool enabled: Config.options?.bar?.modules?.weather ?? true
readonly property string position: Config.options?.bar?.position ?? "top"
readonly property var screenList: Config.options?.bar?.screenList ?? []
```

### Write (ALWAYS setNestedValue)
```qml
Config.setNestedValue("bar.modules.weather", false)
Config.setNestedValue(["bar", "modules", "weather"], false)
```

### Wait for ready
```qml
Connections {
    target: Config
    function onReadyChanged() {
        if (Config.ready) { /* safe to read */ }
    }
}
```

## Service Singleton Pattern

```qml
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool ready: false
    signal dataChanged()

    function refresh(): void { /* ... */ }

    IpcHandler {
        target: "myService"
        function doThing(): void { root.refresh() }
        function getStatus(): string { return root.ready ? "ok" : "loading" }
    }
}
```

Register in `services/qmldir`: `singleton MyService MyService.qml`

## Panel Loading

shell.qml uses PanelLoader for each panel:
```qml
PanelLoader {
    identifier: "iiBar"
    extraCondition: !(Config.options?.bar?.vertical ?? false)
    component: Bar {}
}
```
Loads when: Config.ready + identifier in enabledPanels + extraCondition.

## Lazy Loading

```qml
LazyLoader {
    active: GlobalStates.sidebarRightOpen && Config.ready
    component: PanelWindow { /* full implementation */ }
}
```
`active: false` → component destroyed, memory freed.

## Style-Aware Components

5-style dispatch (angel > inir > aurora > material, cards never in ternaries):

```qml
// Color
color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
     : Appearance.inirEverywhere ? Appearance.inir.colLayer1
     : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
     : Appearance.colors.colLayer1

// Border
border.width: Appearance.inirEverywhere ? 1
            : Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
            : 0

// Rounding
radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal
      : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
      : Appearance.rounding.normal
```

## Animation Pattern

```qml
Behavior on opacity {
    enabled: Appearance.animationsEnabled
    NumberAnimation { duration: Appearance.calcEffectiveDuration(200) }
}

// Or use presets:
Behavior on x {
    animation: Appearance.animation.elementMove.numberAnimation
}
```

## Null Safety

EVERY service/config access must be guarded:
```qml
property var windows: NiriService.windows ?? []
property string name: NiriService.focusedWindow?.title ?? ""
property real volume: Audio.volume ?? 0
```

## Compositor-Aware Code

```qml
Loader {
    active: CompositorService.isHyprland
    sourceComponent: HyprlandSpecificFeature {}
}

function focusWindow(id): void {
    if (CompositorService.isNiri) NiriService.focusWindow(id)
    else if (CompositorService.isHyprland) Hyprland.focusWindow(id)
}
```

## Key Widget APIs (verified gotchas)

| Widget | Icon property | Notes |
|--------|--------------|-------|
| ConfigSwitch | `buttonIcon` | NOT `icon` |
| ConfigSpinBox | `icon` | NOT `buttonIcon` |
| MaterialSymbol | `text` | icon name in `text`, NOT `icon` |
| GlassBackground | — | requires `screenX`, `screenY` from parent |
| StyledRectangularShadow | — | dispatches gaussian vs escalonado per style |

## Performance Patterns

### Debounce
```qml
Timer {
    id: debounceTimer
    interval: 300
    onTriggered: doExpensiveWork()
}
function onInputChanged(): void { debounceTimer.restart() }
```

### Visibility guard on timers
```qml
Timer {
    interval: 5000
    repeat: true
    running: root.visible && !root.isLoading
    onTriggered: root.refresh()
}
```

### Avoid binding loops
```qml
// WRONG: property int value: value + 1
// CORRECT:
property int value: 0
function increment(): void { value++ }
```

## Error Handling

```qml
try {
    let result = JSON.parse(dataString)
    data = result
} catch (e) {
    console.error("[ModuleName] Failed to parse:", e)
    data = []
}
```

Never let errors crash the shell. Always provide fallbacks.

## IPC Pattern

```qml
IpcHandler {
    target: "audio"
    function volumeUp(): void { Audio.incrementVolume() }
    function getVolume(): string { return String(Audio.volume) }
}
```

Types: `string`, `int`, `bool`, `real`, `color`, `void`. Canonical call: `inir audio volumeUp`

## Sync Groups (ALWAYS modify together)

- `Config.qml` ↔ `defaults/config.json`
- `services/qmldir` when adding services
- `modules/common/widgets/qmldir` when adding widgets
- `modules/[module]/qmldir` when adding module components
