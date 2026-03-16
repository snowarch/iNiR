---
trigger: model_decision
description: Pull when using or modifying shared widgets, especially config widgets, MaterialSymbol, GlassBackground, shadows, dialogs, and widget API gotchas.
---

# iNiR Widget API Reference (Verified from source code)

127 widgets in `modules/common/widgets/`, registered in `widgets/qmldir`.

## Critical Widget APIs

### ConfigSwitch (extends RippleButton)
```qml
ConfigSwitch {
    text: "Enable feature"           // label text
    buttonIcon: "settings"           // icon name — NOT "icon"!
    checked: Config.options?.x ?? false
    onCheckedChanged: Config.setNestedValue("x", checked)
    enabled: true                    // grayed out when false (opacity 0.4)
    iconSize: Appearance.font.pixelSize.larger  // default
    enableSettingsSearch: true        // auto-registers in settings search
}
```
**GOTCHA**: icon property is `buttonIcon`, NOT `icon`. Using `icon` silently does nothing.

### ConfigSpinBox (extends RowLayout)
```qml
ConfigSpinBox {
    text: "Count"
    icon: "counter_5"               // icon name — NOT "buttonIcon"!
    value: Config.options?.x ?? 10
    from: 0; to: 100; stepSize: 1
    onValueChanged: Config.setNestedValue("x", value)
    hovered: false                   // exposed alias for tooltips
    enableSettingsSearch: true
}
```
**GOTCHA**: icon property is `icon`, NOT `buttonIcon`. Opposite of ConfigSwitch.

### ConfigSelectionArray (extends ColumnLayout)
```qml
ConfigSelectionArray {
    title: "Position"
    icon: "dock_to_bottom"
    options: [
        { value: "top", label: Translation.tr("Top"), icon: "vertical_align_top" },
        { value: "bottom", label: Translation.tr("Bottom"), icon: "vertical_align_bottom" }
    ]
    selectedValue: Config.options?.bar?.position ?? "top"
    onSelectedValueChanged: Config.setNestedValue("bar.position", selectedValue)
}
```

### ConfigTimeInput (extends RowLayout)
```qml
ConfigTimeInput {
    text: "Start time"
    icon: "schedule"
    hours: 8; minutes: 0
    onTimeChanged: (h, m) => Config.setNestedValue("schedule.start", h * 60 + m)
}
```

### ConfigRow (extends RowLayout)
```qml
ConfigRow {
    text: "Label"
    icon: "info"
    // default slot for custom content on the right side
}
```

### MaterialSymbol (extends Item)
```qml
MaterialSymbol {
    text: "home"                    // icon name goes in TEXT, not icon!
    iconSize: 24                    // default: Appearance.font.pixelSize.small (15)
    color: Appearance.m3colors.m3onSurface  // default
    fill: 0                         // 0 = outlined, 1 = filled (animated)
    forceNerd: false                // force Nerd Font glyph
    // Auto-switches to Nerd Font when inirEverywhere is active
    // Uses NerdIconMap.get(text) for material→nerd translation
}
```
**GOTCHA**: icon name goes in `text` property, NOT `icon`.

### OptionalMaterialSymbol
Same as MaterialSymbol but `visible: icon !== ""` — renders nothing when icon is empty.
```qml
OptionalMaterialSymbol {
    icon: root.buttonIcon           // empty string = invisible
    iconSize: Appearance.font.pixelSize.larger
}
```

### GlassBackground (extends Rectangle)
```qml
GlassBackground {
    anchors.fill: parent
    radius: 12
    screenX: root.mapToGlobal(0, 0).x   // REQUIRED for blur alignment
    screenY: root.mapToGlobal(0, 0).y   // REQUIRED for blur alignment
    screenWidth: Quickshell.screens[0]?.width ?? 1920
    screenHeight: Quickshell.screens[0]?.height ?? 1080
    hovered: mouseArea.containsMouse     // drives angel border state
    fallbackColor: Appearance.colors.colLayer1    // material/cards
    inirColor: Appearance.inir.colLayer1          // inir
    auroraTransparency: Appearance.aurora.popupTransparentize  // aurora glass level
}
```
Renders: material=solid color, inir=solid inirColor, aurora/angel=blurred wallpaper + overlay.
Angel adds: inset glow + AngelPartialBorder automatically.
**GOTCHA**: Without screenX/screenY the blur is misaligned. Parent MUST provide via mapToGlobal.

### StyledRectangularShadow (extends Item)
```qml
StyledRectangularShadow {
    target: myCard                  // REQUIRED — the element to shadow
    hovered: mouseArea.containsMouse // animates escalonado offset in angel
    radius: myCard.radius           // auto from target if not set
    // Material: gaussian blur shadow
    // Angel: escalonado offset golden rectangle (2px→7px on hover)
}
```
52+ usages. Place BEFORE target in z-order.

### EscalonadoShadow (extends Item)
```qml
EscalonadoShadow {
    target: myCard                  // REQUIRED
    hovered: false
    screenX: root.mapToGlobal(0, 0).x   // for glass blur alignment
    screenY: root.mapToGlobal(0, 0).y
    screenWidth: ...; screenHeight: ...
    // Offset defaults from Appearance.angel.shadowOffset*
    // Glass-backed variant — shows blurred wallpaper through shadow
}
```
Only visible when angelEverywhere. Place BEFORE target in z-order.

### AngelPartialBorder (extends Item)
```qml
AngelPartialBorder {
    targetRadius: card.radius
    hovered: mouseArea.containsMouse
    coverage: Appearance.angel.borderCoverage  // 0.0-1.0
    borderWidth: Appearance.angel.borderWidth
    borderColor: Appearance.angel.colBorder    // auto-switches hover
}
```
Gradient fade borders: top-left flows right+down, bottom-right flows left+up. Angel only.

### AngelAccentBar (extends Item)
```qml
AngelAccentBar {
    showTop: true; showLeft: false
    hovered: mouseArea.containsMouse
    active: root.isSelected
    topBarHeight: Appearance.angel.accentBarHeight
    leftBarWidth: Appearance.angel.accentBarWidth
    barColor: Appearance.angel.colAccentBar
}
```
Primary-colored accent lines that scale in on hover/active. Angel only.

### RippleButton (extends Button)
```qml
RippleButton {
    buttonText: "Click me"
    toggled: false
    buttonRadius: Appearance.rounding.small
    pointingHandCursor: true
    rippleEnabled: true
    rippleDuration: 1200
    // Actions
    onClicked: { }
    altAction: (event) => { }       // right-click
    middleClickAction: () => { }    // middle-click
    downAction: () => { }           // on press
    releaseAction: () => { }        // on release
    moveAction: (event) => { }      // drag while pressed
    // Colors (auto-themed per style)
    colBackground, colBackgroundHover, colBackgroundToggled, colRipple
}
```

### RippleButtonWithIcon (extends RippleButton)
Adds icon to left of text. Additional properties:
```qml
RippleButtonWithIcon {
    buttonIcon: "settings"
    buttonIconSize: Appearance.font.pixelSize.larger
    buttonIconFill: 0
}
```

### CollapsibleSection (extends ColumnLayout)
```qml
CollapsibleSection {
    title: "Advanced"
    icon: "tune"                    // optional icon
    expanded: true                  // initial state
    collapsible: true               // false = always expanded
    // default property: children go inside
    ConfigSwitch { ... }
    ConfigSpinBox { ... }
}
```

### ContentSection (extends ColumnLayout)
Non-collapsible section header with icon + title. Children go in default slot.

### ContentPage (extends StyledFlickable)
Scrollable container for settings pages. Wraps content in flickable with edge fade.

### NavigationRail (extends ColumnLayout)
```qml
NavigationRail {
    expanded: true
    currentIndex: 0
    // Children: NavigationRailButton items
}
```

### NavigationRailButton
```qml
NavigationRailButton {
    icon: "settings"
    text: "Settings"
    selected: navRail.currentIndex === 0
    onClicked: navRail.currentIndex = 0
}
```

### WindowDialog (extends Item)
```qml
WindowDialog {
    id: dialog
    visible: false
    WindowDialogTitle { text: "Confirm" }
    WindowDialogParagraph { text: "Are you sure?" }
    WindowDialogButtonRow {
        DialogButton { text: "Cancel"; onClicked: dialog.visible = false }
        DialogButton { text: "OK"; highlighted: true; onClicked: { /* action */ } }
    }
}
```

### StyledToolTip / PopupToolTip
```qml
StyledToolTip {
    text: "Hover info"
    // Appears on parent hover
}
PopupToolTip {
    text: "Popup info"
    // Manual show/hide via visible
}
```

### StyledListView (extends ListView)
Themed list with ScrollBar. Same API as QML ListView.

### StyledFlickable (extends Flickable)
Themed flickable with ScrollBar and edge fade.

### FadeLoader
```qml
FadeLoader {
    shown: GlobalStates.sidebarRightOpen
    component: MySidebar {}
    // Fades in/out with animation. Non-layout-affecting.
}
```

### Revealer
```qml
Revealer {
    reveal: someCondition
    // Clip-animated show/hide
}
```

### NoticeBox
Inline warning/info box for settings pages.
```qml
NoticeBox {
    icon: "warning"
    text: "This requires restart"
    type: "warning"  // "info", "warning", "error"
}
```

## Singleton Widgets

Two widgets are singletons (registered with `singleton` in qmldir):
- `SettingsMaterialPreset` — shared visual constants for settings UI
- `SettingsSearchRegistry` — global search index for settings controls
