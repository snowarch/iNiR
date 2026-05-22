# iNiR Widget SDK

Custom desktop widgets that run on the iNiR shell. Full QML access to 73 services,
130+ UI components, and the entire Appearance token system.

Widgets live in `~/.config/inir/widgets/<name>/` and are loaded automatically.

## Quick Start

```bash
inir customWidgets create my-widget    # generates scaffold
# edit ~/.config/inir/widgets/my-widget/MyWidget.qml
inir customWidgets reload              # hot-reload without restart
```

Or copy the reference widget from `defaults/widgets/example-widget/`.

## File Structure

```
~/.config/inir/widgets/my-widget/
  widget.json       # manifest (name, icon, configKeys, resize behavior)
  MyWidget.qml      # main component — extends AbstractBackgroundWidget
  (any other .qml files, images, scripts)
```

## widget.json Manifest

```json
{
    "name": "My Widget",
    "icon": "dashboard",
    "version": "1.0",
    "author": "you",
    "description": "Short text shown in settings",
    "category": "system",
    "main": "MyWidget.qml",
    "defaultConfig": {
        "placementStrategy": "free",
        "widgetScale": 100,
        "widgetOpacity": 100,
        "colorMode": "auto",
        "x": 200,
        "y": 200
    },
    "configKeys": {
        "showLabel":  { "type": "bool",   "default": true,       "label": "Show label" },
        "fontSize":   { "type": "int",    "default": 14, "min": 8, "max": 48, "label": "Font size" },
        "message":    { "type": "string", "default": "Hello",    "label": "Message" },
        "style":      { "type": "string", "default": "pill",     "label": "Style",
                        "options": [{ "label": "Pill", "value": "pill" }, { "label": "Card", "value": "card" }] },
        "opacity":    { "type": "real",   "default": 0.8, "min": 0, "max": 1, "label": "Opacity" }
    },
    "resizableAxes": { "uniform": "widgetScale" },
    "defaultSize": { "width": 200, "height": 100 }
}
```

Supported configKey types: `bool`, `int`, `real`, `string`.

## Minimal Widget

```qml
import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "custom.my-widget"
    defaultConfig: ({ placementStrategy: "free", widgetScale: 100, widgetOpacity: 100, colorMode: "auto", x: 200, y: 200 })
    implicitWidth: Math.round(150 * scaleFactor)
    implicitHeight: Math.round(50 * scaleFactor)

    StyledText {
        anchors.centerIn: parent
        text: DateTime.time
        font.pixelSize: Math.round(Appearance.font.pixelSize.large * root.scaleFactor)
        color: root.colText
    }
}
```

---

## Imports Reference

| Import | What it gives you |
|--------|-------------------|
| `QtQuick` | Item, Rectangle, Column, Row, Repeater, Timer, MouseArea, Image, etc |
| `QtQuick.Layouts` | ColumnLayout, RowLayout, GridLayout, Layout.fillWidth/preferredWidth |
| `Quickshell` | Process, SystemClock, Quickshell.execDetached() |
| `Quickshell.Io` | FileView, StdioCollector, SplitParser |
| `qs` | Root module |
| `qs.services` | All 73 service singletons (see Services section) |
| `qs.modules.common` | Config, Appearance, Directories, GlobalStates |
| `qs.modules.common.functions` | ColorUtils, StringUtils, DateUtils, FileUtils, ObjectUtils |
| `qs.modules.common.widgets` | 130+ reusable UI components (see Components section) |
| `qs.modules.background.widgets` | AbstractBackgroundWidget base class |

---

## Services

All services are singletons — import `qs.services` and use them directly. Properties are
reactive (auto-update when system state changes).

### DateTime
```qml
DateTime.time       // "14:32" (formatted per user config)
DateTime.date       // "Wednesday, 14/05" (formatted per user config)
DateTime.shortDate  // "14/05"
DateTime.uptime     // "2d, 5h, 30m"
```

### Weather
```qml
Weather.enabled                // bool — user has weather enabled
Weather.data.temp              // "23" (string)
Weather.data.description       // "Partly cloudy"
Weather.data.humidity          // "65"
Weather.data.wind              // "12"
Weather.useUSCS                // bool — Fahrenheit vs Celsius
Weather.visibleCity            // "Buenos Aires" (respects privacy setting)
Weather.isNightNow()           // bool
Weather.describeWeather(code)  // weather code → "Sunny", "Rain", etc
```

### Battery
```qml
Battery.available     // bool — laptop has battery
Battery.percentage    // 0.0-1.0
Battery.isCharging    // bool
Battery.isPluggedIn   // bool
Battery.isLow         // bool (< 20%)
Battery.isCritical    // bool (< 10%)
Battery.isFull        // bool (> 95%)
Battery.timeToEmpty   // minutes until empty
Battery.timeToFull    // minutes until full
Battery.energyRate    // watts
```

### Audio
```qml
Audio.ready                  // bool
Audio.value                  // 0.0-2.0 (sink volume, 1.0 = 100%)
Audio.sink?.audio?.muted     // bool
Audio.micVolume              // 0.0-2.0
Audio.micMuted               // bool (use this, NOT source.audio.muted)
Audio.micBeingAccessed       // bool — app is using mic
Audio.toggleMute()
Audio.toggleMicMute()
Audio.setSinkVolume(0.75)
Audio.incrementVolume()
Audio.decrementVolume()
```

### Network
```qml
Network.wifi              // bool — connected to wifi
Network.ethernet          // bool — ethernet connected
Network.wifiEnabled       // bool — radio on
Network.wifiStatus        // "connected", "disconnected", "connecting", "disabled"
Network.networkName       // "MyNetwork" (SSID)
Network.networkStrength   // 0-100
Network.materialSymbol    // "wifi", "wifi_off", "signal_wifi_4_bar", etc
Network.toggleWifi()
Network.rescanWifi()
```

### ResourceUsage
```qml
// IMPORTANT: call ensureRunning() before reading, or keepAlive() for persistent widgets
ResourceUsage.ensureRunning()       // starts polling (auto-stops after 15s idle)
ResourceUsage.keepAlive()           // prevents auto-stop — call in Component.onCompleted
ResourceUsage.releaseKeepAlive()    // call in Component.onDestruction

ResourceUsage.cpuUsage              // 0.0-1.0
ResourceUsage.gpuUsage              // 0.0-1.0
ResourceUsage.memoryUsedPercentage  // 0.0-1.0
ResourceUsage.memoryTotal           // KB
ResourceUsage.memoryUsed            // KB
ResourceUsage.cpuTemp               // celsius
ResourceUsage.gpuTemp               // celsius
ResourceUsage.diskUsedPercentage    // 0.0-1.0
ResourceUsage.cpuUsageHistory       // list<real> — last 60 samples
ResourceUsage.memoryUsageHistory    // list<real>
ResourceUsage.kbToGbString(kb)      // "7.4 GB"
```

### MprisController (media players)
```qml
MprisController.activePlayer             // currently playing MprisPlayer (or null)
MprisController.displayPlayers           // list — use this for UI, not .players
MprisController.activePlayer?.trackTitle // "Song Name"
MprisController.activePlayer?.trackArtist
MprisController.activePlayer?.artUrl
MprisController.activePlayer?.isPlaying  // bool
MprisController.activePlayer?.position   // ms
MprisController.activePlayer?.length     // ms
MprisController.nextForPlayer(player)
MprisController.previousForPlayer(player)
```

### Notifications
```qml
Notifications.unread    // int
Notifications.list      // all notifications
Notifications.silent    // bool — Do Not Disturb
Notifications.toggleSilent()
Notifications.discardAllNotifications()
```

### Other Useful Services
```qml
CompositorService.isNiri        // bool — guard compositor-specific code
CompositorService.isHyprland    // bool
Brightness.screenBrightness     // 0.0-1.0
GameMode.active                 // bool
SystemInfo.hostname             // "mypc"
SystemInfo.distroName           // "Arch Linux"
```

---

## Components

Import `qs.modules.common.widgets`. The most useful ones for widgets:

### Text & Icons
```qml
StyledText {
    text: "Hello"
    font.pixelSize: Appearance.font.pixelSize.normal
    color: Appearance.colors.colOnLayer0
}

MaterialSymbol {
    text: "wifi"          // Material Symbols icon name
    iconSize: 24
    color: Appearance.colors.colPrimary
}
// Common icon names: schedule, wifi, battery_full, volume_up, thermostat,
// memory, speed, cloud, notifications, play_arrow, pause, skip_next,
// wb_sunny, nights_stay, bolt, download, upload, settings, edit, check
```

### Buttons
```qml
RippleButton {
    width: 80; height: 32
    buttonRadius: Appearance.rounding.small
    toggled: someCondition
    colBackground: toggled ? ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.16) : "transparent"
    colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.08)
    colRipple: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.12)
    downAction: () => { /* clicked */ }
    contentItem: StyledText { anchors.centerIn: parent; text: "Click me" }
}
```

### Progress Indicators
```qml
CircularProgress {
    width: 48; height: 48
    lineWidth: 4
    value: ResourceUsage.cpuUsage   // 0.0-1.0
    primaryColor: Appearance.colors.colPrimary
    secondaryColor: ColorUtils.applyAlpha(Appearance.colors.colOnLayer0, 0.1)
}

StyledProgressBar {
    width: 100; height: 4
    from: 0; to: 1
    value: Battery.percentage
}

Graph {
    width: 200; height: 60
    values: ResourceUsage.cpuUsageHistory
    lineColor: Appearance.colors.colPrimary
    fillColor: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.2)
}
```

### Audio Visualizer
```qml
CavaProcess {
    id: cava
    active: true  // starts cava subprocess
}
CavaVisualizer {
    width: 200; height: 60
    points: cava.points
    barColor: Appearance.colors.colPrimary
    barRadius: Appearance.rounding.verysmall
}
```

### Animated Loading
```qml
FadeLoader {
    shown: someCondition
    sourceComponent: Item { /* loaded when shown */ }
}
```

### Sliders & Inputs
```qml
StyledSlider {
    from: 0; to: 100; value: 50
    onMoved: Config.setNestedValue("background.widgets.custom.my-widget.myVal", value)
}
StyledSpinBox {
    from: 0; to: 100; stepSize: 5; value: 50
    onValueModified: Config.setNestedValue("background.widgets.custom.my-widget.myVal", value)
}
```

---

## Config System

Widget config persists in `~/.config/inir/config.json` under
`background.widgets.custom.<widget-id>`.

### Reading
```qml
// Via inherited helper (reads from configEntry):
readonly property bool showLabel: _readConfigKey("showLabel") ?? true

// Direct access through Config.getNestedValue() is required for custom widgets,
// because the custom namespace is stored outside JsonAdapter for VM safety:
readonly property int myVal: Config.getNestedValue("background.widgets.custom.my-widget.myVal", 42)

// Or via CustomWidgets helper:
readonly property var myVal: CustomWidgets.getConfigValue("my-widget", "myVal", 42)
```

### Writing (ONLY way that persists)
```qml
Config.setNestedValue("background.widgets.custom.my-widget.myVal", 42)

// Or via helper:
CustomWidgets.setConfigValue("my-widget", "myVal", 42)
```

**Never** assign directly to Config.options — it won't persist.

---

## AbstractBackgroundWidget Properties

Your widget inherits these from AbstractBackgroundWidget:

| Property | Type | Description |
|----------|------|-------------|
| `configEntryName` | string | Config path suffix, e.g. "custom.my-widget" |
| `configEntry` | var | Resolved config object (null-safe) |
| `scaleFactor` | real | Scale multiplier — multiply your dimensions by this |
| `widgetOpacity` | real | 0-1, from config |
| `colText` | color | Auto-adapts to wallpaper brightness |
| `backgroundOpacity` | real | Card background alpha |
| `borderWidth` | real | Card border width |
| `borderOpacity` | real | Card border alpha |
| `cornerRadiusOverride` | real | -1 = use theme token |
| `colorMode` | string | "auto", "light", "dark" |
| `placementStrategy` | string | "free", "leastBusy", "mostBusy", or zone name |
| `screenWidth` | int | Screen dimensions |
| `screenHeight` | int | |
| `scaledScreenWidth` | int | Scaled screen dimensions |
| `scaledScreenHeight` | int | |
| `resizableAxes` | var | `{}`, `{uniform: "key"}`, or `{width: "key", height: "key"}` |
| `editPopoverContent` | Component | Quick controls shown in edit mode toolbar |
| `defaultConfig` | var | Object of default values for resetToDefaults() |

### Functions
| Function | Description |
|----------|-------------|
| `_readConfigKey(key)` | Read nested key from configEntry |
| `snapToZone(zone)` | Snap to named zone ("topLeft", "center", "bottomRight", etc) |
| `syncFreePositionFromConfig()` | Re-read x/y from config |
| `resetToDefaults()` | Write all defaultConfig values to config |

---

## Theming Tokens

**Never hardcode colors, radii, font sizes, or animation durations.** Use tokens:

### Colors
```qml
Appearance.colors.colPrimary             // accent color (from wallpaper)
Appearance.colors.colOnLayer0            // text on background
Appearance.colors.colOnLayer1            // text on cards
Appearance.colors.colLayer1              // card surface
Appearance.colors.colLayer2              // popup surface
Appearance.colors.colError               // error red
Appearance.colors.colSecondaryContainer  // secondary container
Appearance.colors.colSubtext             // muted text
root.colText                             // adaptive text (use this in widgets)
```

### Rounding
```qml
Appearance.rounding.verysmall  // 8px  — tiny elements
Appearance.rounding.small      // 12px — tags, small cards
Appearance.rounding.normal     // 17px — cards, panels
Appearance.rounding.large      // 23px — feature cards
Appearance.rounding.full       // pill shape
```

### Fonts
```qml
Appearance.font.pixelSize.smaller  // very small
Appearance.font.pixelSize.small    // captions
Appearance.font.pixelSize.normal   // body
Appearance.font.pixelSize.large    // titles
Appearance.font.pixelSize.huge     // headlines
Appearance.font.family.main        // Roboto Flex
Appearance.font.family.numbers     // Rubik (digit readability)
Appearance.font.family.monospace   // JetBrainsMono NF
Appearance.font.family.title       // Gabarito
Appearance.font.family.expressive  // Space Grotesk
```

### Animations
```qml
Behavior on opacity {
    enabled: Appearance.animationsEnabled
    NumberAnimation {
        duration: Appearance.animation.elementMoveFast.duration
        easing.type: Appearance.animation.elementMoveFast.type
        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
    }
}
```

### Utility Functions
```qml
ColorUtils.applyAlpha(color, 0.5)          // set alpha
ColorUtils.mix(color1, color2, 0.3)        // blend colors
ColorUtils.transparentize(color, amount)   // make more transparent
```

---

## Running Shell Commands

```qml
import Quickshell
import Quickshell.Io

// Fire and forget
Quickshell.execDetached(["notify-send", "Hello"])

// With output capture
Process {
    id: myProc
    command: ["curl", "-s", "https://api.example.com/data"]
    stdout: StdioCollector {
        onStreamFinished: {
            const data = JSON.parse(text)
            // use data
        }
    }
}
// Start it: myProc.running = true

// Line-by-line streaming
Process {
    command: ["tail", "-f", "/var/log/syslog"]
    stdout: SplitParser {
        onRead: (line) => { /* process each line */ }
    }
}
```

---

## Edit Mode Features

### Resize Handles
```qml
// Aspect-locked (one config key controls overall size):
resizableAxes: ({ uniform: "widgetScale" })

// Independent width/height:
resizableAxes: ({ width: "contentWidth", height: "contentHeight" })

// Min/max constraints:
resizeMinWidth: 80
resizeMinHeight: 40
resizeMaxWidth: 800
resizeMaxHeight: 600
```

### Quick Controls Popover
```qml
editPopoverContent: Component {
    Item {
        implicitWidth: row.implicitWidth
        implicitHeight: row.implicitHeight
        Row {
            id: row
            spacing: 4
            StyledText { text: "Size"; color: Appearance.colors.colOnLayer2 }
            StyledSpinBox {
                from: 50; to: 300; value: root._readConfigKey("mySize") ?? 100
                onValueModified: Config.setNestedValue("background.widgets.custom.my-widget.mySize", value)
            }
        }
    }
}
```

---

## Tips

- Multiply ALL pixel values by `root.scaleFactor` for consistent resize behavior
- Use `root.colText` for text color — it adapts to wallpaper brightness
- Gate service data on availability: `visible: Battery.available`, `visible: Weather.enabled`
- For ResourceUsage, call `ensureRunning()` or the data will be stale/zero
- Use `FadeLoader { shown: condition }` for smooth show/hide of optional sections
- The widget runs in the same QML engine as the shell — same trust model as a shell extension
- Test with `inir customWidgets reload` (no restart needed)
- Check for errors: `inir logs | grep -i error`
