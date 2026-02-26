// CompactSidebarRightContent.qml
//
// Two-column compact sidebar:
//   Left rail  (54 px) — icon navigation + system actions
//   Right area          — active section fills the rest
//
// Sections:
//   0 = Controls  (sliders + quick toggles)
//   1 = Notifications
//   2+ = Widgets  (dashboard / calendar / todo / notepad / calc / sysmon / timer)
//
// Fully compatible with all global styles: material, aurora, inir, angel.

import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE

import qs.modules.sidebarRight.quickToggles
import qs.modules.sidebarRight.quickToggles.classicStyle
import qs.modules.sidebarRight.bluetoothDevices
import qs.modules.sidebarRight.nightLight
import qs.modules.sidebarRight.volumeMixer
import qs.modules.sidebarRight.wifiNetworks
import qs.modules.sidebarLeft.widgets

import qs.modules.sidebarRight.dashboard
import qs.modules.sidebarRight.calendar
import qs.modules.sidebarRight.todo
import qs.modules.sidebarRight.pomodoro
import qs.modules.sidebarRight.notepad
import qs.modules.sidebarRight.calculator
import qs.modules.sidebarRight.sysmon
import qs.modules.sidebarRight.events

Item {
    id: root

    // ── Public API (same as SidebarRightContent) ──────────────────
    property int sidebarWidth: Appearance.sizes.sidebarWidth
    property int sidebarPadding: 10
    property int screenWidth: 1920
    property int screenHeight: 1080
    property var panelScreen: null

    property bool showAudioOutputDialog: false
    property bool showAudioInputDialog: false
    property bool showBluetoothDialog: false
    property bool showNightLightDialog: false
    property bool showWifiDialog: false
    property bool editMode: false
    property bool reloadButtonEnabled: true
    property bool settingsButtonEnabled: true

    // Active section index — persisted
    property int activeSection: Persistent.states?.sidebar?.compactGroup?.tab ?? 0

    onActiveSectionChanged: {
        if (Persistent.states?.sidebar?.compactGroup)
            Persistent.states.sidebar.compactGroup.tab = activeSection
        Qt.callLater(() => {
            // Focus the newly active section's content
            const idx = activeSection
            if (idx >= 0 && idx < sectionRepeater.count) {
                const item = sectionRepeater.itemAt(idx)
                if (item && item.sectionLoader && item.sectionLoader.item) {
                    item.sectionLoader.item.forceActiveFocus()
                }
            }
        })
    }

    // Notification count for badge
    readonly property int notificationCount: Notifications.list?.length ?? 0

    property int configVersion: 0
    Connections {
        target: Config
        function onConfigChanged() { root.configVersion++ }
    }

    // ── Section definitions ───────────────────────────────────────
    readonly property var baseSections: [
        { id: "controls",      icon: "tune",          label: Translation.tr("Controls")      },
        { id: "notifications", icon: "notifications", label: Translation.tr("Notifications") },
    ]

    Component { id: dashboardComponent;  DashboardWidget  { anchors.fill: parent; anchors.margins: 8 } }
    Component { id: calendarComponent;   CalendarWidget   { anchors.fill: parent; anchors.margins: 8 } }
    Component { id: eventsComponent;     EventsWidget     { anchors.fill: parent; anchors.margins: 8 } }
    Component { id: todoComponent;       TodoWidget       { anchors.fill: parent; anchors.margins: 8 } }
    Component { id: notepadComponent;    NotepadWidget    { anchors.fill: parent; anchors.margins: 8 } }
    Component { id: calculatorComponent; CalculatorWidget { anchors.fill: parent; anchors.margins: 8 } }
    Component { id: sysmonComponent;     SysMonWidget     { anchors.fill: parent; anchors.margins: 8 } }
    Component {
        id: timerComponent
        PomodoroWidget {
            anchors.fill: parent
            anchors.margins: 8
            compactMode: true
        }
    }

    component ControlChipButton: Item {
        id: chip
        required property string chipIcon
        required property string chipLabel
        property string value: ""

        signal clicked()

        implicitHeight: value !== "" ? 48 : 42

        StyledRectangularShadow {
            target: chipButton
            visible: !bg.inirEverywhere && !bg.auroraEverywhere
            blur: 0.3 * Appearance.sizes.elevationMargin
        }

        RippleButton {
            id: chipButton
            anchors.fill: parent
            buttonRadius: bg.angelEverywhere ? Appearance.angel.roundingSmall
                : bg.inirEverywhere ? Appearance.inir.roundingSmall
                : Appearance.rounding.small
            colBackground: bg.angelEverywhere ? Appearance.angel.colGlassCard
                : bg.inirEverywhere ? Appearance.inir.colLayer1
                : Appearance.colors.colLayer1
            colBackgroundHover: bg.angelEverywhere ? Appearance.angel.colGlassCardHover
                : bg.inirEverywhere ? Appearance.inir.colLayer2Hover
                : Appearance.colors.colLayer1Hover
            colRipple: bg.angelEverywhere ? Appearance.angel.colGlassCardActive
                : bg.inirEverywhere ? Appearance.inir.colLayer2Active
                : Appearance.colors.colLayer1Active
            onClicked: chip.clicked()

            contentItem: RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                MaterialSymbol {
                    iconSize: 20
                    text: chip.chipIcon
                    color: bg.inirEverywhere ? Appearance.inir.colPrimary
                        : bg.angelEverywhere ? Appearance.angel.colPrimary
                        : Appearance.colors.colPrimary
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: chip.chipLabel
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: bg.inirEverywhere ? Appearance.inir.colText
                            : bg.angelEverywhere ? Appearance.angel.colText
                            : Appearance.colors.colOnLayer1
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: chip.value !== ""
                        text: chip.value
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: Font.Medium
                        color: bg.inirEverywhere ? Appearance.inir.colTextSecondary
                            : bg.angelEverywhere ? Appearance.angel.colTextSecondary
                            : Appearance.colors.colSubtext
                        elide: Text.ElideRight
                    }
                }

                MaterialSymbol {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    iconSize: 16
                    text: "chevron_right"
                    color: bg.inirEverywhere ? Appearance.inir.colTextSecondary
                        : bg.angelEverywhere ? Appearance.angel.colTextSecondary
                        : Appearance.colors.colSubtext
                }
            }
        }

        BubbleToolTip {
            visible: chipButton.hovered
            position: "left"
            text: chip.chipLabel
        }
    }

    readonly property var widgetSections: {
        root.configVersion // Force dependency
        const enabled = Config.options?.sidebar?.right?.enabledWidgets ?? ["dashboard", "calendar", "events", "todo", "notepad", "calculator", "sysmon", "timer"]
        const all = [
            {id: "dashboard",  icon: "dashboard",     label: Translation.tr("Dashboard"),  component: dashboardComponent},
            {id: "calendar",   icon: "calendar_month", label: Translation.tr("Calendar"),   component: calendarComponent},
            {id: "events",     icon: "event_upcoming", label: Translation.tr("Events"),     component: eventsComponent},
            {id: "todo",       icon: "done_outline",  label: Translation.tr("To Do"),      component: todoComponent},
            {id: "notepad",    icon: "edit_note",     label: Translation.tr("Notepad"),    component: notepadComponent},
            {id: "calculator", icon: "calculate",     label: Translation.tr("Calc"),       component: calculatorComponent},
            {id: "sysmon",     icon: "monitor_heart", label: Translation.tr("System"),     component: sysmonComponent},
            {id: "timer",      icon: "schedule",      label: Translation.tr("Timer"),      component: timerComponent},
        ]
        return all.filter(w => enabled.includes(w.id))
    }

    readonly property var sections: baseSections.concat(widgetSections)

    // ── Close dialogs when sidebar is hidden ─────────────────────
    Connections {
        target: GlobalStates
        function onSidebarRightOpenChanged() {
            if (!GlobalStates.sidebarRightOpen) {
                root.showWifiDialog        = false
                root.showBluetoothDialog   = false
                root.showAudioOutputDialog = false
                root.showAudioInputDialog  = false
                root.showNightLightDialog  = false
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Background (identical pattern to SidebarRightContent)
    // ─────────────────────────────────────────────────────────────
    StyledRectangularShadow {
        target: bg
        visible: !Appearance.inirEverywhere && !Appearance.gameModeMinimal
    }

    Rectangle {
        id: bg
        anchors.fill: parent

        property bool cardStyle: Config.options?.sidebar?.cardStyle ?? false
        readonly property bool angelEverywhere:  Appearance.angelEverywhere
        readonly property bool auroraEverywhere: Appearance.auroraEverywhere
        readonly property bool inirEverywhere:   Appearance.inirEverywhere
        readonly property bool gameModeMinimal:  Appearance.gameModeMinimal

        readonly property string wallpaperUrl: {
            const _d1 = WallpaperListener.multiMonitorEnabled
            const _d2 = WallpaperListener.effectivePerMonitor
            const _d3 = Wallpapers.effectiveWallpaperUrl
            return WallpaperListener.wallpaperUrlForScreen(root.panelScreen)
        }

        ColorQuantizer {
            id: bgQuant
            source: bg.wallpaperUrl
            depth: 0
            rescaleSize: 10
        }
        readonly property color wallpaperDominantColor: bgQuant?.colors?.[0] ?? Appearance.colors.colPrimary
        readonly property QtObject blendedColors: AdaptedMaterialScheme {
            color: ColorUtils.mix(bg.wallpaperDominantColor, Appearance.colors.colPrimaryContainer, 0.8)
                   || Appearance.m3colors.m3secondaryContainer
        }

        color: gameModeMinimal  ? "transparent"
             : inirEverywhere   ? (cardStyle ? Appearance.inir.colLayer1 : Appearance.inir.colLayer0)
             : auroraEverywhere ? ColorUtils.applyAlpha((blendedColors?.colLayer0 ?? Appearance.colors.colLayer0), 1)
             : (cardStyle ? Appearance.colors.colLayer1 : Appearance.colors.colLayer0)

        border.width: gameModeMinimal ? 0 : (angelEverywhere ? Appearance.angel.panelBorderWidth : 1)
        border.color: angelEverywhere  ? Appearance.angel.colPanelBorder
                    : inirEverywhere   ? Appearance.inir.colBorder
                    : Appearance.colors.colLayer0Border

        radius: angelEverywhere  ? Appearance.angel.roundingNormal
              : inirEverywhere   ? (cardStyle ? Appearance.inir.roundingLarge : Appearance.inir.roundingNormal)
              : cardStyle        ? Appearance.rounding.normal
              : (Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1)
        clip: true

        layer.enabled: auroraEverywhere && !inirEverywhere && !gameModeMinimal
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: bg.width; height: bg.height; radius: bg.radius
            }
        }

        // Aurora blurred wallpaper
        Image {
            id: bgBlurWallpaper
            x: -(root.screenWidth - bg.width - Appearance.sizes.hyprlandGapsOut)
            y: -Appearance.sizes.hyprlandGapsOut
            width:  root.screenWidth  ?? 1920
            height: root.screenHeight ?? 1080
            visible: bg.auroraEverywhere && !bg.inirEverywhere && !bg.gameModeMinimal
            source: bg.wallpaperUrl
            fillMode: Image.PreserveAspectCrop
            cache: true; asynchronous: true
            layer.enabled: Appearance.effectsEnabled
            layer.effect: MultiEffect {
                source: bgBlurWallpaper
                anchors.fill: source
                saturation: bg.angelEverywhere
                    ? (Appearance.angel.blurSaturation * Appearance.angel.colorStrength)
                    : (Appearance.effectsEnabled ? 0.2 : 0)
                blurEnabled: Appearance.effectsEnabled
                blurMax: 100
                blur: Appearance.effectsEnabled
                    ? (bg.angelEverywhere ? Appearance.angel.blurIntensity : 1) : 0
            }
            Rectangle {
                anchors.fill: parent
                color: bg.angelEverywhere
                    ? ColorUtils.transparentize((bg.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base),
                                               Appearance.angel.overlayOpacity * Appearance.angel.panelTransparentize)
                    : ColorUtils.transparentize((bg.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base),
                                               Appearance.aurora.overlayTransparentize)
            }
        }

        // Angel inset glow — top edge
        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height:  Appearance.angel.insetGlowHeight
            visible: bg.angelEverywhere
            color:   Appearance.angel.colInsetGlow
            z: 10
        }

        AngelPartialBorder { targetRadius: bg.radius; z: 10 }

        // ─────────────────────────────────────────────────────────
        // Two-column layout
        // ─────────────────────────────────────────────────────────
        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ── LEFT RAIL ─────────────────────────────────────────
            Rectangle {
                id: leftRail
                Layout.fillHeight: true
                Layout.preferredWidth: 56
                color: "transparent"

                // Thin separator on right edge
                Rectangle {
                    anchors {
                        top: parent.top; bottom: parent.bottom; right: parent.right
                        topMargin: bg.radius; bottomMargin: bg.radius
                    }
                    width: 1
                    color: bg.angelEverywhere  ? ColorUtils.transparentize(Appearance.angel.colCardBorder,  0.3)
                         : bg.inirEverywhere   ? Appearance.inir.colBorder
                         : bg.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.6)
                         : Appearance.colors.colLayer0Border
                }

                // ── Sliding selection highlight (declared before ColumnLayout = behind it) ──
                Rectangle {
                    id: navIndicator
                    // Layout constants — must match ColumnLayout margins and nav item dimensions
                    readonly property int colTop: 12
                    readonly property int colLeft: 4
                    readonly property int colRight: 5
                    readonly property int navBgLeft: 7
                    readonly property int navItemH: 46
                    readonly property int navBgH: 38
                    readonly property int navSpacing: 4
                    readonly property int clampedIdx: Math.max(0, Math.min(root.activeSection, root.sections.length - 1))

                    x: colLeft + navBgLeft
                    y: colTop + clampedIdx * (navItemH + navSpacing) + (navItemH - navBgH) / 2
                    width: leftRail.width - colLeft - colRight - navBgLeft
                    height: navBgH
                    radius: bg.angelEverywhere ? Appearance.angel.roundingSmall
                          : bg.inirEverywhere  ? Appearance.inir.roundingSmall
                          : Appearance.rounding.small
                    color: bg.inirEverywhere  ? Appearance.inir.colSecondaryContainer
                         : bg.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colPrimary, 0.60)
                         : bg.auroraEverywhere ? Appearance.aurora.colElevatedSurface
                         : Appearance.colors.colSecondaryContainer
                    visible: root.activeSection >= 0 && root.activeSection < root.sections.length

                    Behavior on y {
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration * 1.5
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                }

                // ── Sliding active pill on left edge ──
                Rectangle {
                    id: navPill
                    x: navIndicator.colLeft + 1
                    y: navIndicator.colTop + navIndicator.clampedIdx * (navIndicator.navItemH + navIndicator.navSpacing) + (navIndicator.navItemH - height) / 2
                    width: 3
                    height: 26
                    radius: 2
                    color: bg.inirEverywhere  ? Appearance.inir.colPrimary
                         : bg.angelEverywhere ? Appearance.angel.colPrimary
                         : Appearance.colors.colPrimary
                    visible: navIndicator.visible

                    Behavior on y {
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration * 1.5
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                // Section scroll navigation on rail
                WheelHandler {
                    orientation: Qt.Vertical
                    onWheel: (event) => {
                        if (event.angleDelta.y < 0)
                            root.activeSection = Math.min(root.activeSection + 1, root.sections.length - 1)
                        else if (event.angleDelta.y > 0)
                            root.activeSection = Math.max(root.activeSection - 1, 0)
                    }
                }

                ColumnLayout {
                    anchors {
                        fill: parent
                        topMargin: 12; bottomMargin: 12
                        leftMargin: 4; rightMargin: 5
                    }
                    spacing: 4

                    // ── Section navigation buttons ──────────────
                    Repeater {
                        model: root.sections
                        delegate: Item {
                            id: navItem
                            required property int index
                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight: 46

                            readonly property bool isActive: root.activeSection === navItem.index
                            readonly property bool isNotifications: navItem.modelData.id === "notifications"

                            // Button background (active highlight provided by navIndicator behind)
                            Rectangle {
                                id: navBg
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 7
                                }
                                height: 38
                                radius: bg.angelEverywhere ? Appearance.angel.roundingSmall
                                      : bg.inirEverywhere  ? Appearance.inir.roundingSmall
                                      : Appearance.rounding.small

                                color: {
                                    if (navMA.containsPress)
                                        return bg.inirEverywhere  ? Appearance.inir.colLayer2Active
                                             : bg.angelEverywhere ? Appearance.angel.colGlassCardActive
                                             : Appearance.colors.colLayer1Active
                                    if (navMA.containsMouse)
                                        return bg.inirEverywhere  ? Appearance.inir.colLayer2Hover
                                             : bg.angelEverywhere ? Appearance.angel.colGlassCardHover
                                             : Appearance.colors.colLayer1Hover
                                    return "transparent"
                                }
                                Behavior on color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    iconSize: 24
                                    fill: navItem.isActive ? 1 : 0
                                    font.weight: (navItem.isActive || navMA.containsMouse) ? Font.DemiBold : Font.Normal
                                    text: navItem.modelData.icon
                                    color: navItem.isActive
                                        ? (bg.inirEverywhere  ? Appearance.inir.colOnSecondaryContainer
                                         : bg.angelEverywhere ? Appearance.angel.colOnPrimary
                                         : Appearance.m3colors.m3onSecondaryContainer)
                                        : (bg.inirEverywhere  ? Appearance.inir.colTextSecondary
                                         : bg.angelEverywhere ? Appearance.angel.colTextSecondary
                                         : Appearance.colors.colOnLayer1)
                                    Behavior on color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                                }

                                // ── Notification badge ──────────
                                Rectangle {
                                    id: notifBadge
                                    visible: navItem.isNotifications && root.notificationCount > 0 && !navItem.isActive
                                    anchors {
                                        top: parent.top
                                        right: parent.right
                                        topMargin: 2
                                        rightMargin: 2
                                    }
                                    width: Math.max(16, badgeLabel.implicitWidth + 8)
                                    height: 16
                                    radius: 8
                                    color: bg.inirEverywhere  ? Appearance.inir.colPrimary
                                         : bg.angelEverywhere ? Appearance.angel.colPrimary
                                         : Appearance.colors.colPrimary

                                    StyledText {
                                        id: badgeLabel
                                        anchors.centerIn: parent
                                        text: root.notificationCount > 99 ? "99+" : root.notificationCount.toString()
                                        font.pixelSize: 9
                                        font.weight: Font.Bold
                                        font.family: Appearance.font.family.numbers
                                        color: bg.inirEverywhere  ? Appearance.inir.colOnPrimary
                                             : bg.angelEverywhere ? Appearance.angel.colOnPrimary
                                             : Appearance.colors.colOnPrimary
                                    }

                                    // Subtle entrance animation
                                    scale: visible ? 1.0 : 0.0
                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: Appearance.animation.elementMoveFast.duration
                                            easing.type: Easing.OutBack
                                        }
                                    }
                                }

                                MouseArea {
                                    id: navMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.activeSection = navItem.index
                                }
                                BubbleToolTip {
                                    visible: navMA.containsMouse
                                    position: "left"
                                    text: navItem.isNotifications && root.notificationCount > 0
                                        ? navItem.modelData.label + " (" + root.notificationCount + ")"
                                        : navItem.modelData.label
                                }
                            }
                        }
                    }

                    // ── Vertical spacer ──────────────────────────
                    Item { Layout.fillHeight: true }

                    // Subtle separator between nav and system buttons
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.leftMargin: 10
                        Layout.rightMargin: 4
                        height: 1
                        color: bg.angelEverywhere  ? ColorUtils.transparentize(Appearance.angel.colCardBorder, 0.5)
                             : bg.inirEverywhere   ? Appearance.inir.colBorder
                             : bg.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.6)
                             : Appearance.colors.colLayer0Border
                    }

                    // ── System action buttons ────────────────────
                    Repeater {
                        model: [
                            { icon: "restart_alt",       label: Translation.tr("Reload Quickshell"),
                              action: function() { doReload() } },
                            { icon: "settings",          label: Translation.tr("Settings"),
                              action: function() { doSettings() } },
                            { icon: "power_settings_new",label: Translation.tr("Session"),
                              action: function() { GlobalStates.sessionOpen = true } },
                        ]
                        delegate: Item {
                            id: sysItem
                            required property int index
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 40

                            Rectangle {
                                id: sysActBg
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 7
                                }
                                height: 34
                                radius: bg.angelEverywhere ? Appearance.angel.roundingSmall
                                      : bg.inirEverywhere  ? Appearance.inir.roundingSmall
                                      : Appearance.rounding.small
                                color: {
                                    if (sysMA.containsPress)
                                        return bg.inirEverywhere  ? Appearance.inir.colLayer2Active
                                             : bg.angelEverywhere ? Appearance.angel.colGlassCardActive
                                             : Appearance.colors.colLayer1Active
                                    if (sysMA.containsMouse)
                                        return bg.inirEverywhere  ? Appearance.inir.colLayer2Hover
                                             : bg.angelEverywhere ? Appearance.angel.colGlassCardHover
                                             : Appearance.colors.colLayer1Hover
                                    return "transparent"
                                }
                                Behavior on color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    iconSize: 20
                                    text: sysItem.modelData.icon
                                    color: bg.inirEverywhere  ? Appearance.inir.colTextSecondary
                                         : bg.angelEverywhere ? Appearance.angel.colTextSecondary
                                         : Appearance.colors.colOnLayer1
                                }
                                MouseArea {
                                    id: sysMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: sysItem.modelData.action()
                                }
                                BubbleToolTip {
                                    visible: sysMA.containsMouse
                                    position: "left"
                                    text: sysItem.modelData.label
                                }
                            }
                        }
                    }

                    // ── Layout toggle ────────────────────────────
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 40
                        Rectangle {
                            anchors {
                                left: parent.left; right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 7
                            }
                            height: 34
                            radius: bg.angelEverywhere ? Appearance.angel.roundingSmall
                                  : bg.inirEverywhere  ? Appearance.inir.roundingSmall
                                  : Appearance.rounding.small
                            color: {
                                if (layoutMA.containsPress)
                                    return bg.inirEverywhere  ? Appearance.inir.colLayer2Active
                                         : bg.angelEverywhere ? Appearance.angel.colGlassCardActive
                                         : Appearance.colors.colLayer1Active
                                if (layoutMA.containsMouse)
                                    return bg.inirEverywhere  ? Appearance.inir.colLayer2Hover
                                         : bg.angelEverywhere ? Appearance.angel.colGlassCardHover
                                         : Appearance.colors.colLayer1Hover
                                return "transparent"
                            }
                            Behavior on color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                iconSize: 18
                                text: "view_agenda"
                                color: bg.inirEverywhere  ? Appearance.inir.colPrimary
                                     : bg.angelEverywhere ? Appearance.angel.colPrimary
                                     : Appearance.colors.colPrimary
                            }
                            MouseArea {
                                id: layoutMA
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Config.setNestedValue("sidebar.layout", "default")
                            }
                            BubbleToolTip {
                                visible: layoutMA.containsMouse
                                position: "left"
                                text: Translation.tr("Switch to default layout")
                            }
                        }
                    }
                } // ColumnLayout (rail)
            } // leftRail

            // ── RIGHT CONTENT AREA ────────────────────────────────
            Item {
                id: contentArea
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Crossfade container — all sections stacked, only active one visible
                Repeater {
                    id: sectionRepeater
                    model: root.sections

                    delegate: Item {
                        id: sectionItem
                        required property int index
                        required property var modelData
                        anchors.fill: parent

                        readonly property bool isCurrent: root.activeSection === sectionItem.index
                        readonly property bool isBase: sectionItem.modelData.id === "controls" || sectionItem.modelData.id === "notifications"
                        property alias sectionLoader: sectionContentLoader

                        // Crossfade opacity
                        opacity: isCurrent ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.animation.elementMoveFast.duration
                                easing.type: Easing.OutCubic
                            }
                        }

                        // Subtle slide-in from direction of navigation
                        transform: Translate {
                            y: sectionItem.isCurrent ? 0 : (root.activeSection > sectionItem.index ? -6 : 6)
                            Behavior on y {
                                enabled: Appearance.animationsEnabled
                                NumberAnimation {
                                    duration: Appearance.animation.elementMove.duration
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        // ── Section content ──────────────────────
                        Loader {
                            id: sectionContentLoader
                            anchors.fill: parent
                            // Lazy loading: base sections always loaded, widgets only when adjacent or current
                            active: sectionItem.isBase
                                || sectionItem.isCurrent
                                || Math.abs(root.activeSection - sectionItem.index) <= 1

                            sourceComponent: {
                                if (sectionItem.modelData.id === "controls")
                                    return controlsSectionComponent
                                if (sectionItem.modelData.id === "notifications")
                                    return notificationsSectionComponent
                                // Widget sections — use component from data
                                return sectionItem.modelData.component ?? null
                            }
                        }
                    }
                }
            } // contentArea
        } // RowLayout (two columns)
    } // bg Rectangle

    // ── Section content components ────────────────────────────────

    Component {
        id: controlsSectionComponent
        Item {
            // Scrollable content for Controls section
            Flickable {
                id: controlsFlickable
                anchors.fill: parent
                anchors.topMargin: 8
                anchors.bottomMargin: 8
                anchors.leftMargin: 8
                anchors.rightMargin: 14
                contentWidth: width
                contentHeight: controlsColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: controlsFlickable.contentHeight > controlsFlickable.height
                        ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                }

                ColumnLayout {
                    id: controlsColumn
                    width: controlsFlickable.width
                    spacing: Appearance.sizes.spacingMedium

                    // Section header
                    SectionHeader {
                        Layout.fillWidth: true
                        headerText: Translation.tr("Controls")
                        headerIcon: "tune"
                        showAction: (Config.options?.sidebar?.quickToggles?.style ?? "classic") === "android"
                        actionIcon: root.editMode ? "check" : "edit"
                        actionTooltip: Translation.tr("Edit quick toggles")
                        onActionClicked: root.editMode = !root.editMode
                    }

                    // Quick Sliders (Volume, Brightness, Mic)
                    Loader {
                        Layout.fillWidth: true
                        Layout.maximumWidth: controlsColumn.width
                        visible: active
                        active: {
                            const cfg = Config.options?.sidebar?.quickSliders
                            return (cfg?.enable && (cfg?.showMic || cfg?.showVolume || cfg?.showBrightness))
                        }
                        sourceComponent: QuickSliders {}
                    }

                    // Compact quick controls row (reuse ControlsCard)
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: controlsCardSurface.implicitHeight

                        StyledRectangularShadow {
                            target: controlsCardSurface
                            visible: !bg.inirEverywhere && !bg.auroraEverywhere
                        }

                        Rectangle {
                            id: controlsCardSurface
                            anchors.fill: parent
                            implicitHeight: controlsCard.implicitHeight + 10
                            radius: bg.angelEverywhere ? Appearance.angel.roundingNormal
                                : bg.inirEverywhere ? Appearance.inir.roundingNormal
                                : Appearance.rounding.normal
                            color: bg.angelEverywhere ? Appearance.angel.colGlassCard
                                : bg.inirEverywhere ? Appearance.inir.colLayer1
                                : bg.auroraEverywhere ? "transparent"
                                : Appearance.colors.colLayer1
                            border.width: bg.angelEverywhere ? Appearance.angel.cardBorderWidth
                                : bg.inirEverywhere ? 1 : (bg.auroraEverywhere ? 0 : 1)
                            border.color: bg.angelEverywhere ? Appearance.angel.colCardBorder
                                : bg.inirEverywhere ? Appearance.inir.colBorder
                                : Appearance.colors.colLayer0Border

                            ControlsCard {
                                id: controlsCard
                                anchors.fill: parent
                                anchors.margins: 4
                            }

                            AngelPartialBorder { targetRadius: controlsCardSurface.radius }
                        }
                    }

                    // Device shortcuts
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Appearance.sizes.spacingSmall
                        spacing: Appearance.sizes.spacingSmall

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: bg.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colCardBorder, 0.5)
                                : bg.inirEverywhere ? Appearance.inir.colBorder
                                : Appearance.colors.colLayer0Border
                        }

                        StyledText {
                            text: Translation.tr("Devices")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: Font.Medium
                            color: bg.inirEverywhere ? Appearance.inir.colTextSecondary
                                : bg.angelEverywhere ? Appearance.angel.colTextSecondary
                                : Appearance.colors.colSubtext
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: bg.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colCardBorder, 0.5)
                                : bg.inirEverywhere ? Appearance.inir.colBorder
                                : Appearance.colors.colLayer0Border
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 8
                        rowSpacing: 8

                        ControlChipButton {
                            Layout.fillWidth: true
                            chipIcon: "media_output"
                            chipLabel: Translation.tr("Output")
                            value: Audio.sink?.description ?? ""
                            onClicked: root.showAudioOutputDialog = true
                        }

                        ControlChipButton {
                            Layout.fillWidth: true
                            chipIcon: "mic_external_on"
                            chipLabel: Translation.tr("Input")
                            value: Audio.source?.description ?? ""
                            onClicked: root.showAudioInputDialog = true
                        }

                        ControlChipButton {
                            Layout.fillWidth: true
                            chipIcon: "bluetooth"
                            chipLabel: Translation.tr("Bluetooth")
                            value: Bluetooth.defaultAdapter?.enabled ? Translation.tr("On") : Translation.tr("Off")
                            onClicked: root.showBluetoothDialog = true
                        }

                        ControlChipButton {
                            Layout.fillWidth: true
                            chipIcon: Network.materialSymbol
                            chipLabel: Translation.tr("Wi-Fi")
                            value: Network.networkName ?? ""
                            onClicked: root.showWifiDialog = true
                        }
                    }

                    // Quick Toggles
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: toggleLoader.item?.implicitHeight ?? 0
                        visible: toggleLoader.active
                        Layout.leftMargin: 2
                        Layout.rightMargin: 4

                        Loader {
                            id: toggleLoader
                            anchors.fill: parent
                            active: (Config.options?.sidebar?.quickToggles?.style ?? "classic") === "classic"
                            sourceComponent: ClassicQuickPanel { compactMode: true }
                            Connections {
                                target: toggleLoader.item
                                function onOpenAudioOutputDialog() { root.showAudioOutputDialog = true }
                                function onOpenAudioInputDialog()  { root.showAudioInputDialog  = true }
                                function onOpenBluetoothDialog()   { root.showBluetoothDialog   = true }
                                function onOpenNightLightDialog()  { root.showNightLightDialog  = true }
                                function onOpenWifiDialog()        { root.showWifiDialog        = true }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: androidToggleLoader.item?.implicitHeight ?? 0
                        visible: androidToggleLoader.active
                        Layout.leftMargin: 2
                        Layout.rightMargin: 4

                        Loader {
                            id: androidToggleLoader
                            anchors.fill: parent
                            active: (Config.options?.sidebar?.quickToggles?.style ?? "classic") === "android"
                            sourceComponent: AndroidQuickPanel {
                                editMode: root.editMode
                            }
                            Connections {
                                target: androidToggleLoader.item
                                function onOpenAudioOutputDialog() { root.showAudioOutputDialog = true }
                                function onOpenAudioInputDialog()  { root.showAudioInputDialog  = true }
                                function onOpenBluetoothDialog()   { root.showBluetoothDialog   = true }
                                function onOpenNightLightDialog()  { root.showNightLightDialog  = true }
                                function onOpenWifiDialog()        { root.showWifiDialog        = true }
                            }
                        }
                    }

                    // Media player (shows when music is playing)
                    CompactMediaPlayer {
                        Layout.fillWidth: true
                    }

                    // Quick Actions section
                    QuickActionsSection {
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }

    Component {
        id: notificationsSectionComponent
        Item {
            ColumnLayout {
                anchors {
                    fill: parent
                    margins: 8
                }
                spacing: 8

                // Section header with notification count + actions
                SectionHeader {
                    headerText: Translation.tr("Notifications")
                    headerIcon: "notifications"
                    badgeText: root.notificationCount > 0 ? root.notificationCount.toString() : ""
                    // DND toggle
                    showAction: true
                    actionIcon: Notifications.silent ? "notifications_off" : "notifications_active"
                    actionTooltip: Notifications.silent ? Translation.tr("Unmute notifications") : Translation.tr("Mute notifications")
                    actionToggled: Notifications.silent
                    onActionClicked: Notifications.silent = !Notifications.silent
                    // Clear all button
                    showSecondaryAction: root.notificationCount > 0
                    secondaryActionIcon: "delete_sweep"
                    secondaryActionTooltip: Translation.tr("Clear all notifications")
                    onSecondaryActionClicked: Notifications.discardAllNotifications()
                }

                // Notification list or empty state
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // Notification list
                    CenterWidgetGroup {
                        anchors.fill: parent
                        visible: root.notificationCount > 0
                    }

                    // Enhanced empty state placeholder
                    EmptyNotificationsPlaceholder {
                        anchors.fill: parent
                        visible: root.notificationCount === 0
                    }
                }
            }
        }
    }

    // ── Dialogs (identical to SidebarRightContent) ────────────────
    ToggleDialog {
        shownPropertyString: "showAudioOutputDialog"
        dialog: VolumeDialog { isSink: true }
    }
    ToggleDialog {
        shownPropertyString: "showAudioInputDialog"
        dialog: VolumeDialog { isSink: false }
    }
    ToggleDialog {
        shownPropertyString: "showBluetoothDialog"
        dialog: BluetoothDialog {}
        onShownChanged: {
            if (!Bluetooth.defaultAdapter) return
            if (!shown) {
                Bluetooth.defaultAdapter.discovering = false
            } else {
                Bluetooth.defaultAdapter.enabled = true
                Bluetooth.defaultAdapter.discovering = true
            }
        }
    }
    ToggleDialog {
        shownPropertyString: "showNightLightDialog"
        dialog: NightLightDialog {}
    }
    ToggleDialog {
        shownPropertyString: "showWifiDialog"
        dialog: WifiDialog {}
        onShownChanged: {
            if (!shown) return
            Network.enableWifi()
            Network.rescanWifi()
        }
    }

    // ── Cooldown timers ───────────────────────────────────────────
    Timer { id: reloadCooldown;   interval: 500; onTriggered: root.reloadButtonEnabled  = true }
    Timer { id: settingsCooldown; interval: 500; onTriggered: root.settingsButtonEnabled = true }

    // ── System action implementations ────────────────────────────
    function doReload() {
        if (!root.reloadButtonEnabled) return
        root.reloadButtonEnabled = false
        reloadCooldown.restart()
        if (CompositorService.isHyprland)
            Hyprland.dispatch("reload")
        else if (CompositorService.isNiri)
            Quickshell.execDetached(["/usr/bin/niri", "msg", "action", "load-config-file"])
        Quickshell.reload(true)
    }

    function doSettings() {
        if (!root.settingsButtonEnabled) return
        root.settingsButtonEnabled = false
        settingsCooldown.restart()
        if (CompositorService.isNiri) {
            const wins = NiriService.windows || []
            for (let i = 0; i < wins.length; i++) {
                const w = wins[i]
                if (w.title === "illogical-impulse Settings" && w.app_id === "org.quickshell") {
                    GlobalStates.sidebarRightOpen = false
                    Qt.callLater(() => NiriService.focusWindow(w.id))
                    return
                }
            }
        }
        GlobalStates.sidebarRightOpen = false
        Qt.callLater(() => Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "settings", "open"]))
    }

    // ═════════════════════════════════════════════════════════════
    // INLINE COMPONENTS
    // ═════════════════════════════════════════════════════════════

    component ToggleDialog: Loader {
        id: tdLoader
        required property string shownPropertyString
        property alias dialog: tdLoader.sourceComponent
        readonly property bool shown: root[shownPropertyString]
        anchors.fill: parent
        active: shown
        onItemChanged: {
            if (item) { item.show = true; item.forceActiveFocus() }
        }
        Connections {
            target: tdLoader.item
            function onDismiss() { root[tdLoader.shownPropertyString] = false }
        }
    }

    // ── Section Header ───────────────────────────────────────────
    component SectionHeader: Item {
        id: sectionHeader
        required property string headerText
        property string headerIcon: ""
        property string badgeText: ""
        property bool showAction: false
        property string actionIcon: ""
        property string actionTooltip: ""
        property bool actionToggled: false
        property bool showSecondaryAction: false
        property string secondaryActionIcon: ""
        property string secondaryActionTooltip: ""

        signal actionClicked()
        signal secondaryActionClicked()

        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight

        RowLayout {
            id: headerRow
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 8

            MaterialSymbol {
                visible: sectionHeader.headerIcon !== ""
                text: sectionHeader.headerIcon
                iconSize: 18
                fill: 1
                color: bg.inirEverywhere  ? Appearance.inir.colPrimary
                     : bg.angelEverywhere ? Appearance.angel.colPrimary
                     : Appearance.colors.colPrimary
            }

            StyledText {
                Layout.fillWidth: true
                text: sectionHeader.headerText
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: bg.inirEverywhere  ? Appearance.inir.colText
                     : bg.angelEverywhere ? Appearance.angel.colText
                     : Appearance.colors.colOnLayer0
            }

            // Badge (notification count)
            Rectangle {
                visible: sectionHeader.badgeText !== ""
                implicitWidth: Math.max(18, badgeLabelInHeader.implicitWidth + 8)
                implicitHeight: 18
                radius: 9
                color: bg.inirEverywhere  ? Appearance.inir.colSecondaryContainer
                     : bg.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colPrimary, 0.70)
                     : Appearance.colors.colSecondaryContainer

                StyledText {
                    id: badgeLabelInHeader
                    anchors.centerIn: parent
                    text: sectionHeader.badgeText
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Bold
                    font.family: Appearance.font.family.numbers
                    color: bg.inirEverywhere  ? Appearance.inir.colOnSecondaryContainer
                         : bg.angelEverywhere ? Appearance.angel.colOnPrimary
                         : Appearance.m3colors.m3onSecondaryContainer
                }
            }

            // Secondary action button
            RippleButton {
                visible: sectionHeader.showSecondaryAction
                implicitWidth: 28; implicitHeight: 28
                buttonRadius: bg.angelEverywhere ? Appearance.angel.roundingSmall
                    : bg.inirEverywhere ? Appearance.inir.roundingSmall : 14
                colBackground: "transparent"
                colBackgroundHover: bg.angelEverywhere ? Appearance.angel.colGlassCardHover
                    : bg.inirEverywhere ? Appearance.inir.colLayer1Hover
                    : Appearance.colors.colLayer1Hover
                onClicked: sectionHeader.secondaryActionClicked()
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent; text: sectionHeader.secondaryActionIcon; iconSize: 16
                    color: bg.inirEverywhere  ? Appearance.inir.colTextSecondary
                         : bg.angelEverywhere ? Appearance.angel.colTextSecondary
                         : Appearance.colors.colSubtext
                }
                StyledToolTip {
                    position: "left"
                    text: sectionHeader.secondaryActionTooltip
                }
            }

            // Primary action button
            RippleButton {
                visible: sectionHeader.showAction
                implicitWidth: 28; implicitHeight: 28
                buttonRadius: bg.angelEverywhere ? Appearance.angel.roundingSmall
                    : bg.inirEverywhere ? Appearance.inir.roundingSmall : 14
                colBackground: sectionHeader.actionToggled
                    ? (bg.inirEverywhere ? Appearance.inir.colSecondaryContainer
                     : bg.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colPrimary, 0.60)
                     : Appearance.colors.colSecondaryContainer)
                    : "transparent"
                colBackgroundHover: bg.angelEverywhere ? Appearance.angel.colGlassCardHover
                    : bg.inirEverywhere ? Appearance.inir.colLayer1Hover
                    : Appearance.colors.colLayer1Hover
                onClicked: sectionHeader.actionClicked()
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent; text: sectionHeader.actionIcon; iconSize: 16
                    fill: sectionHeader.actionToggled ? 1 : 0
                    color: sectionHeader.actionToggled
                        ? (bg.inirEverywhere  ? Appearance.inir.colOnSecondaryContainer
                         : bg.angelEverywhere ? Appearance.angel.colOnPrimary
                         : Appearance.m3colors.m3onSecondaryContainer)
                        : (bg.inirEverywhere  ? Appearance.inir.colTextSecondary
                         : bg.angelEverywhere ? Appearance.angel.colTextSecondary
                         : Appearance.colors.colSubtext)
                }
                StyledToolTip {
                    position: "left"
                    text: sectionHeader.actionTooltip
                }
            }
        }
    }

    // ── Empty Notifications Placeholder ───────────────────────────
    component EmptyNotificationsPlaceholder: Item {
        id: emptyPlaceholder

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 12
            width: parent.width - 32

            // Animated icon container
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 56
                Layout.preferredHeight: 56
                radius: 28
                color: bg.inirEverywhere ? Appearance.inir.colLayer1
                    : bg.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colPrimary, 0.85)
                    : bg.auroraEverywhere ? Appearance.aurora.colSubSurface
                    : Appearance.colors.colSecondaryContainer

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: Notifications.silent ? "notifications_off" : "notifications_none"
                    iconSize: 28
                    fill: 0
                    color: bg.inirEverywhere ? Appearance.inir.colPrimary
                        : bg.angelEverywhere ? Appearance.angel.colPrimary
                        : Appearance.m3colors.m3onSecondaryContainer

                    // Subtle breathing animation
                    SequentialAnimation on opacity {
                        running: emptyPlaceholder.visible && Appearance.animationsEnabled
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.6; duration: 2000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 2000; easing.type: Easing.InOutSine }
                    }
                }
            }

            // Title
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Notifications.silent
                    ? Translation.tr("Do Not Disturb")
                    : Translation.tr("All caught up!")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Medium
                color: bg.inirEverywhere ? Appearance.inir.colText
                    : bg.angelEverywhere ? Appearance.angel.colText
                    : Appearance.colors.colOnLayer1
            }

            // Subtitle
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Notifications.silent
                    ? Translation.tr("Notifications are muted")
                    : Translation.tr("No new notifications")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: bg.inirEverywhere ? Appearance.inir.colTextSecondary
                    : bg.angelEverywhere ? Appearance.angel.colTextSecondary
                    : Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
            }

            // Quick action - toggle DND
            RippleButton {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                implicitWidth: dndRow.implicitWidth + 20
                implicitHeight: 32
                buttonRadius: bg.angelEverywhere ? Appearance.angel.roundingSmall
                    : bg.inirEverywhere ? Appearance.inir.roundingSmall : 18
                colBackground: bg.inirEverywhere ? Appearance.inir.colLayer1
                    : bg.angelEverywhere ? Appearance.angel.colGlassCard
                    : Appearance.colors.colLayer1
                colBackgroundHover: bg.inirEverywhere ? Appearance.inir.colLayer1Hover
                    : bg.angelEverywhere ? Appearance.angel.colGlassCardHover
                    : Appearance.colors.colLayer1Hover
                onClicked: Notifications.silent = !Notifications.silent

                contentItem: RowLayout {
                    id: dndRow
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialSymbol {
                        text: Notifications.silent ? "notifications_active" : "notifications_off"
                        iconSize: 16
                        color: bg.inirEverywhere ? Appearance.inir.colPrimary
                            : bg.angelEverywhere ? Appearance.angel.colPrimary
                            : Appearance.colors.colPrimary
                    }

                    StyledText {
                        text: Notifications.silent
                            ? Translation.tr("Enable notifications")
                            : Translation.tr("Enable DND")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: bg.inirEverywhere ? Appearance.inir.colText
                            : bg.angelEverywhere ? Appearance.angel.colText
                            : Appearance.colors.colOnLayer1
                    }
                }
            }
        }
    }

    // ── Quick Actions Section ─────────────────────────────────────
    component QuickActionsSection: ColumnLayout {
        id: quickActions
        spacing: Appearance.sizes.spacingSmall

        // Section divider with label
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: bg.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colCardBorder, 0.5)
                    : bg.inirEverywhere ? Appearance.inir.colBorder
                    : Appearance.colors.colLayer0Border
            }

            StyledText {
                text: Translation.tr("Quick Actions")
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.weight: Font.Medium
                color: bg.inirEverywhere ? Appearance.inir.colTextSecondary
                    : bg.angelEverywhere ? Appearance.angel.colTextSecondary
                    : Appearance.colors.colSubtext
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: bg.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colCardBorder, 0.5)
                    : bg.inirEverywhere ? Appearance.inir.colBorder
                    : Appearance.colors.colLayer0Border
            }
        }

        // Action buttons — 2×3 grid
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

            QuickActionButton {
                Layout.fillWidth: true
                icon: "screenshot_monitor"
                label: Translation.tr("Screenshot")
                onClicked: {
                    GlobalStates.sidebarRightOpen = false
                    Qt.callLater(() => Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "region", "screenshot"]))
                }
            }

            QuickActionButton {
                Layout.fillWidth: true
                icon: "videocam"
                label: Translation.tr("Record")
                onClicked: {
                    GlobalStates.sidebarRightOpen = false
                    Qt.callLater(() => Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "region", "record"]))
                }
            }

            QuickActionButton {
                Layout.fillWidth: true
                icon: "document_scanner"
                label: Translation.tr("OCR")
                onClicked: {
                    GlobalStates.sidebarRightOpen = false
                    Qt.callLater(() => Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "region", "ocr"]))
                }
            }

            QuickActionButton {
                Layout.fillWidth: true
                icon: "travel_explore"
                label: Translation.tr("Search")
                onClicked: {
                    GlobalStates.sidebarRightOpen = false
                    Qt.callLater(() => Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "region", "search"]))
                }
            }

            QuickActionButton {
                Layout.fillWidth: true
                icon: "color_lens"
                label: Translation.tr("Color Picker")
                onClicked: {
                    GlobalStates.sidebarRightOpen = false
                    Qt.callLater(() => Quickshell.execDetached(["/usr/bin/hyprpicker", "-a"]))
                }
            }

            QuickActionButton {
                Layout.fillWidth: true
                icon: "folder_open"
                label: Translation.tr("Files")
                onClicked: Quickshell.execDetached(["xdg-open", Quickshell.env("HOME")])
            }
        }
    }

    component BubbleToolTip: ToolTip {
        id: bubble
        property string position: "left" // top | right | left
        delay: 0
        padding: 0
        x: position === "left"
            ? -width - 6
            : position === "right"
            ? parent.width + 4
            : (parent.width - width) / 2
        y: position === "left" || position === "right"
            ? (parent.height - height) / 2
            : -height - 6
        background: Rectangle {
            color: bg.angelEverywhere ? Appearance.angel.colPrimary
                : bg.inirEverywhere ? Appearance.inir.colPrimary
                : Appearance.colors.colPrimary
            radius: Appearance.rounding.full
            implicitWidth: bubbleLabel.implicitWidth + 24
            implicitHeight: bubbleLabel.implicitHeight + 10
        }
        contentItem: StyledText {
            id: bubbleLabel
            text: bubble.text
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Medium
            color: bg.angelEverywhere ? Appearance.angel.colOnPrimary
                : bg.inirEverywhere ? Appearance.inir.colOnPrimary
                : Appearance.colors.colOnPrimary
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    // ── Quick Action Button ───────────────────────────────────────
    component QuickActionButton: Item {
        id: qaBtn
        required property string icon
        required property string label
        property bool toggled: false

        signal clicked()

        implicitHeight: 44

        StyledRectangularShadow {
            target: qaBtnBg
            visible: !bg.inirEverywhere && !bg.auroraEverywhere
            blur: 0.3 * Appearance.sizes.elevationMargin
        }

        Rectangle {
            id: qaBtnBg
            anchors.fill: parent
            radius: bg.angelEverywhere ? Appearance.angel.roundingSmall
                : bg.inirEverywhere ? Appearance.inir.roundingSmall
                : Appearance.rounding.small
            color: {
                if (qaBtnMA.containsPress)
                    return bg.inirEverywhere ? Appearance.inir.colLayer2Active
                        : bg.angelEverywhere ? Appearance.angel.colGlassCardActive
                        : Appearance.colors.colLayer1Active
                if (qaBtnMA.containsMouse)
                    return bg.inirEverywhere ? Appearance.inir.colLayer2Hover
                        : bg.angelEverywhere ? Appearance.angel.colGlassCardHover
                        : Appearance.colors.colLayer1Hover
                if (qaBtn.toggled)
                    return bg.inirEverywhere ? Appearance.inir.colSecondaryContainer
                        : bg.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colPrimary, 0.6)
                        : Appearance.colors.colSecondaryContainer
                return bg.inirEverywhere ? Appearance.inir.colLayer1
                    : bg.angelEverywhere ? Appearance.angel.colGlassCard
                    : Appearance.colors.colLayer1
            }
            border.width: bg.inirEverywhere ? 1 : 0
            border.color: bg.inirEverywhere ? Appearance.inir.colBorder : "transparent"
            
            scale: qaBtnMA.containsPress ? 0.96 : 1.0
            Behavior on scale {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
            }
            Behavior on color { 
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } 
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 4

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: qaBtn.icon
                    iconSize: 20
                    fill: qaBtn.toggled ? 1 : 0
                    color: qaBtn.toggled
                        ? (bg.inirEverywhere ? Appearance.inir.colOnSecondaryContainer
                         : bg.angelEverywhere ? Appearance.angel.colOnPrimary
                         : Appearance.m3colors.m3onSecondaryContainer)
                        : (bg.inirEverywhere ? Appearance.inir.colPrimary
                         : bg.angelEverywhere ? Appearance.angel.colPrimary
                         : Appearance.colors.colPrimary)
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qaBtn.label
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Medium
                    color: qaBtn.toggled
                        ? (bg.inirEverywhere ? Appearance.inir.colOnSecondaryContainer
                         : bg.angelEverywhere ? Appearance.angel.colOnPrimary
                         : Appearance.m3colors.m3onSecondaryContainer)
                        : (bg.inirEverywhere ? Appearance.inir.colText
                         : bg.angelEverywhere ? Appearance.angel.colText
                         : Appearance.colors.colOnLayer1)
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: qaBtnMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: qaBtn.clicked()
            }

            BubbleToolTip {
                visible: qaBtnMA.containsMouse
                position: "left"
                text: qaBtn.label
            }
        }
    }
}
