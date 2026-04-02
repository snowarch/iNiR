// CompactSidebarRightContent.qml
//
// Two-column compact sidebar:
//   Left rail  (54 px) — icon navigation + system actions
//   Right area          — active section fills the rest
//
// Sections:
//   0 = Controls  (sliders + quick toggles)
//   1 = Notifications
//   2+ = Widgets  (calendar / events / todo / notepad / calc / sysmon / timer)
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
    property bool showEventsDialog: false
    property bool showNightLightDialog: false
    property bool showWifiDialog: false
    property bool editMode: false
    property bool layoutEditMode: false // Edit mode for reordering Controls sections
    property var eventsDialogEditEvent: null
    property bool reloadButtonEnabled: true
    property bool settingsButtonEnabled: true
    
    // Controls section order from config
    readonly property var defaultSectionOrder: ["sliders", "toggles", "devices", "media", "quickActions"]
    property var controlsSectionOrder: Config.options?.sidebar?.right?.controlsSectionOrder ?? defaultSectionOrder
    
    function moveSectionUp(index: int): void {
        if (index <= 0) return
        let order = [...root.controlsSectionOrder]
        const temp = order[index - 1]
        order[index - 1] = order[index]
        order[index] = temp
        root.controlsSectionOrder = order
        Config.setNestedValue("sidebar.right.controlsSectionOrder", order)
    }
    
    function moveSectionDown(index: int): void {
        if (index >= root.controlsSectionOrder.length - 1) return
        let order = [...root.controlsSectionOrder]
        const temp = order[index + 1]
        order[index + 1] = order[index]
        order[index] = temp
        root.controlsSectionOrder = order
        Config.setNestedValue("sidebar.right.controlsSectionOrder", order)
    }

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

    Component.onCompleted: Notifications.ensureInitialized()

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

    Component {
        id: calendarComponent
        Item {
            anchors.fill: parent

            StyledRectangularShadow {
                target: calendarSurface
                visible: !bg.inirEverywhere && !bg.auroraEverywhere && !bg.angelEverywhere
                blur: 0.35 * Appearance.sizes.elevationMargin
            }

            Rectangle {
                id: calendarSurface
                anchors.fill: parent
                anchors.margins: 8
                radius: bg.angelEverywhere ? Appearance.angel.roundingNormal
                    : bg.inirEverywhere ? Appearance.inir.roundingNormal
                    : Appearance.rounding.normal
                color: bg.angelEverywhere ? Appearance.angel.colGlassCard
                    : bg.inirEverywhere ? Appearance.inir.colLayer1
                    : bg.colDarkSurface
                border.width: bg.angelEverywhere ? Appearance.angel.cardBorderWidth : 1
                border.color: bg.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colCardBorder, 0.22)
                    : bg.inirEverywhere ? Appearance.inir.colBorder
                    : bg.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.78)
                    : ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.72)
                clip: true

                CalendarWidget {
                    anchors.fill: parent
                    anchors.margins: 6
                    onDayWithEventsClicked: (date) => {
                        const eventsIdx = root.sections.findIndex(s => s.id === "events")
                        if (eventsIdx !== -1) root.activeSection = eventsIdx
                    }
                }
            }
        }
    }
    Component { 
        id: eventsComponent
        Item {
            anchors.fill: parent

            StyledRectangularShadow {
                target: eventsSurface
                visible: !bg.inirEverywhere && !bg.auroraEverywhere && !bg.angelEverywhere
                blur: 0.35 * Appearance.sizes.elevationMargin
            }

            Rectangle {
                id: eventsSurface
                anchors.fill: parent
                anchors.margins: 8
                radius: bg.angelEverywhere ? Appearance.angel.roundingNormal
                    : bg.inirEverywhere ? Appearance.inir.roundingNormal
                    : Appearance.rounding.normal
                color: bg.angelEverywhere ? Appearance.angel.colGlassCard
                    : bg.inirEverywhere ? Appearance.inir.colLayer1
                    : bg.colDarkSurface
                border.width: bg.angelEverywhere ? Appearance.angel.cardBorderWidth : 1
                border.color: bg.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colCardBorder, 0.22)
                    : bg.inirEverywhere ? Appearance.inir.colBorder
                    : bg.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.78)
                    : ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.72)
                clip: true

                EventsWidget { 
                    anchors.fill: parent
                    anchors.margins: 6
                    onOpenEventsDialog: (editEvent) => {
                        root.eventsDialogEditEvent = editEvent
                        root.showEventsDialog = true
                    }
                }
            }
        }
    }
    Component {
        id: todoComponent
        Item {
            anchors.fill: parent

            StyledRectangularShadow {
                target: todoSurface
                visible: !bg.inirEverywhere && !bg.auroraEverywhere && !bg.angelEverywhere
                blur: 0.35 * Appearance.sizes.elevationMargin
            }

            Rectangle {
                id: todoSurface
                anchors.fill: parent
                anchors.margins: 8
                radius: bg.angelEverywhere ? Appearance.angel.roundingNormal
                    : bg.inirEverywhere ? Appearance.inir.roundingNormal
                    : Appearance.rounding.normal
                color: bg.angelEverywhere ? Appearance.angel.colGlassCard
                    : bg.inirEverywhere ? Appearance.inir.colLayer1
                    : bg.colDarkSurface
                border.width: bg.angelEverywhere ? Appearance.angel.cardBorderWidth : 1
                border.color: bg.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colCardBorder, 0.22)
                    : bg.inirEverywhere ? Appearance.inir.colBorder
                    : bg.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.78)
                    : ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.72)
                clip: true

                TodoWidget {
                    anchors.fill: parent
                    anchors.margins: 6
                }
            }
        }
    }
    Component {
        id: notepadComponent
        Item {
            anchors.fill: parent

            StyledRectangularShadow {
                target: notepadSurface
                visible: !bg.inirEverywhere && !bg.auroraEverywhere && !bg.angelEverywhere
                blur: 0.35 * Appearance.sizes.elevationMargin
            }

            Rectangle {
                id: notepadSurface
                anchors.fill: parent
                anchors.margins: 8
                radius: bg.angelEverywhere ? Appearance.angel.roundingNormal
                    : bg.inirEverywhere ? Appearance.inir.roundingNormal
                    : Appearance.rounding.normal
                color: bg.angelEverywhere ? Appearance.angel.colGlassCard
                    : bg.inirEverywhere ? Appearance.inir.colLayer1
                    : bg.colDarkSurface
                border.width: bg.angelEverywhere ? Appearance.angel.cardBorderWidth : 1
                border.color: bg.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colCardBorder, 0.22)
                    : bg.inirEverywhere ? Appearance.inir.colBorder
                    : bg.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.78)
                    : ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.72)
                clip: true

                NotepadWidget {
                    anchors.fill: parent
                    anchors.margins: 6
                }
            }
        }
    }
    Component {
        id: calculatorComponent
        Item {
            anchors.fill: parent

            StyledRectangularShadow {
                target: calculatorSurface
                visible: !bg.inirEverywhere && !bg.auroraEverywhere && !bg.angelEverywhere
                blur: 0.35 * Appearance.sizes.elevationMargin
            }

            Rectangle {
                id: calculatorSurface
                anchors.fill: parent
                anchors.margins: 8
                radius: bg.angelEverywhere ? Appearance.angel.roundingNormal
                    : bg.inirEverywhere ? Appearance.inir.roundingNormal
                    : Appearance.rounding.normal
                color: bg.angelEverywhere ? Appearance.angel.colGlassCard
                    : bg.inirEverywhere ? Appearance.inir.colLayer1
                    : bg.colDarkSurface
                border.width: bg.angelEverywhere ? Appearance.angel.cardBorderWidth : 1
                border.color: bg.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colCardBorder, 0.22)
                    : bg.inirEverywhere ? Appearance.inir.colBorder
                    : bg.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.78)
                    : ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.72)
                clip: true

                CalculatorWidget {
                    compactMode: true
                    centerContentVertically: true
                    anchors.fill: parent
                    anchors.margins: 6
                }
            }
        }
    }
    Component {
        id: sysmonComponent
        Item {
            anchors.fill: parent

            StyledRectangularShadow {
                target: sysmonSurface
                visible: !bg.inirEverywhere && !bg.auroraEverywhere && !bg.angelEverywhere
                blur: 0.35 * Appearance.sizes.elevationMargin
            }

            Rectangle {
                id: sysmonSurface
                anchors.fill: parent
                anchors.margins: 8
                radius: bg.angelEverywhere ? Appearance.angel.roundingNormal
                    : bg.inirEverywhere ? Appearance.inir.roundingNormal
                    : Appearance.rounding.normal
                color: bg.angelEverywhere ? Appearance.angel.colGlassCard
                    : bg.inirEverywhere ? Appearance.inir.colLayer1
                    : bg.colDarkSurface
                border.width: bg.angelEverywhere ? Appearance.angel.cardBorderWidth : 1
                border.color: bg.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colCardBorder, 0.22)
                    : bg.inirEverywhere ? Appearance.inir.colBorder
                    : bg.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.78)
                    : ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.72)
                clip: true

                SysMonWidget {
                    anchors.fill: parent
                    anchors.margins: 6
                }
            }
        }
    }
    Component {
        id: timerComponent
        Item {
            anchors.fill: parent

            StyledRectangularShadow {
                target: timerSurface
                visible: !bg.inirEverywhere && !bg.auroraEverywhere && !bg.angelEverywhere
                blur: 0.35 * Appearance.sizes.elevationMargin
            }

            Rectangle {
                id: timerSurface
                anchors.fill: parent
                anchors.margins: 8
                radius: bg.angelEverywhere ? Appearance.angel.roundingNormal
                    : bg.inirEverywhere ? Appearance.inir.roundingNormal
                    : Appearance.rounding.normal
                color: bg.angelEverywhere ? Appearance.angel.colGlassCard
                    : bg.inirEverywhere ? Appearance.inir.colLayer1
                    : bg.colDarkSurface
                border.width: bg.angelEverywhere ? Appearance.angel.cardBorderWidth : 1
                border.color: bg.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colCardBorder, 0.22)
                    : bg.inirEverywhere ? Appearance.inir.colBorder
                    : bg.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.78)
                    : ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.72)
                clip: true

                PomodoroWidget {
                    anchors.fill: parent
                    anchors.margins: 6
                    compactMode: true
                }
            }
        }
    }

    component ControlChipButton: Item {
        id: chip
        required property string chipIcon
        required property string chipLabel
        property string value: ""

        signal clicked()

        implicitHeight: value !== "" ? 50 : 44

        RippleButton {
            id: chipButton
            anchors.fill: parent
            buttonRadius: bg.angelEverywhere ? Appearance.angel.roundingSmall
                : bg.inirEverywhere ? Appearance.inir.roundingSmall
                : Appearance.rounding.small
            colBackground: bg.angelEverywhere ? Appearance.angel.colGlassCard
                : bg.inirEverywhere ? Appearance.inir.colLayer1
                : bg.colDarkSurface
            colBackgroundHover: bg.angelEverywhere ? Appearance.angel.colGlassCardHover
                : bg.inirEverywhere ? Appearance.inir.colLayer2Hover
                : bg.colDarkSurfaceHover
            colRipple: bg.angelEverywhere ? Appearance.angel.colGlassCardActive
                : bg.inirEverywhere ? Appearance.inir.colLayer2Active
                : bg.colDarkSurfaceActive
            onClicked: chip.clicked()

            contentItem: RowLayout {
                anchors.fill: parent
                anchors.margins: 9
                spacing: 7

                MaterialSymbol {
                    iconSize: 19
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
        const enabled = Config.options?.sidebar?.right?.enabledWidgets ?? ["calendar", "todo", "notepad", "calculator", "sysmon", "timer"]
        const all = [
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
                root.showEventsDialog      = false
                root.showAudioOutputDialog = false
                root.showAudioInputDialog  = false
                root.showNightLightDialog  = false
                root.eventsDialogEditEvent = null
            }
        }
        function onRequestWifiDialogChanged() {
            if (GlobalStates.requestWifiDialog) {
                GlobalStates.requestWifiDialog = false
                if (!GlobalStates.sidebarRightOpen) GlobalStates.sidebarRightOpen = true
                root.showWifiDialog = true
            }
        }
        function onRequestBluetoothDialogChanged() {
            if (GlobalStates.requestBluetoothDialog) {
                GlobalStates.requestBluetoothDialog = false
                if (!GlobalStates.sidebarRightOpen) GlobalStates.sidebarRightOpen = true
                root.showBluetoothDialog = true
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
            source: (Appearance.auroraEverywhere || Appearance.angelEverywhere) ? bg.wallpaperUrl : ""
            depth: 0
            rescaleSize: 10
        }
        readonly property color wallpaperDominantColor: bgQuant?.colors?.[0] ?? Appearance.colors.colPrimary
        readonly property QtObject blendedColors: AdaptedMaterialScheme {
            color: ColorUtils.mix(bg.wallpaperDominantColor, Appearance.colors.colPrimaryContainer, 0.8)
                   || Appearance.m3colors.m3secondaryContainer
        }
        readonly property color colDarkSurface: angelEverywhere
            ? ColorUtils.transparentize(Appearance.angel.colGlassCard, 0.76)
            : inirEverywhere ? ColorUtils.transparentize(Appearance.inir.colLayer1, 0.22)
            : auroraEverywhere ? ColorUtils.transparentize(
                (blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base),
                Math.max(0.10, Appearance.aurora.subSurfaceTransparentize - 0.16)
            )
            : ColorUtils.transparentize(Appearance.colors.colLayer1, 0.22)
        readonly property color colDarkSurfaceHover: angelEverywhere
            ? Appearance.angel.colGlassCardHover
            : inirEverywhere ? Appearance.inir.colLayer2Hover
            : auroraEverywhere ? ColorUtils.transparentize(
                (blendedColors?.colLayer1 ?? Appearance.colors.colLayer1),
                Math.max(0.16, Appearance.aurora.subSurfaceTransparentize - 0.10)
            )
            : ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 0.20)
        readonly property color colDarkSurfaceActive: angelEverywhere
            ? Appearance.angel.colGlassCardActive
            : inirEverywhere ? Appearance.inir.colLayer2Active
            : auroraEverywhere ? ColorUtils.transparentize(
                (blendedColors?.colLayer1 ?? Appearance.colors.colLayer1),
                Math.max(0.12, Appearance.aurora.subSurfaceTransparentize - 0.14)
            )
            : ColorUtils.transparentize(Appearance.colors.colLayer1Active, 0.18)

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

        layer.enabled: !gameModeMinimal
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
            sourceSize.width: root.screenWidth ?? 1920
            sourceSize.height: root.screenHeight ?? 1080
            layer.enabled: Appearance.effectsEnabled && bg.auroraEverywhere && !bg.inirEverywhere
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
                color: bg.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colGlassCard, 0.82)
                    : bg.inirEverywhere ? ColorUtils.transparentize(Appearance.inir.colLayer1, 0.40)
                    : bg.auroraEverywhere ? ColorUtils.transparentize((bg.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), 0.60)
                    : ColorUtils.transparentize(Appearance.colors.colLayer1, 0.72)

                // Thin separator on right edge
                Rectangle {
                    anchors {
                        top: parent.top; bottom: parent.bottom; right: parent.right
                        topMargin: bg.radius; bottomMargin: bg.radius
                    }
                    width: 1
                    color: bg.angelEverywhere  ? ColorUtils.transparentize(Appearance.angel.colCardBorder,  0.62)
                         : bg.inirEverywhere   ? ColorUtils.transparentize(Appearance.inir.colBorder, 0.45)
                         : bg.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.78)
                         : ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.72)
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
                         : bg.auroraEverywhere ? bg.colDarkSurfaceHover
                         : ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 0.20)
                    border.width: 1
                    border.color: bg.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colCardBorder, 0.38)
                        : bg.inirEverywhere ? ColorUtils.transparentize(Appearance.inir.colBorder, 0.36)
                        : bg.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.72)
                        : ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.66)
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
                                border.width: (navMA.containsMouse || navItem.isActive) ? 1 : 0
                                border.color: bg.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colCardBorder, 0.42)
                                    : bg.inirEverywhere ? ColorUtils.transparentize(Appearance.inir.colBorder, 0.34)
                                    : bg.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.74)
                                    : ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.68)
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
                        color: bg.angelEverywhere  ? ColorUtils.transparentize(Appearance.angel.colCardBorder, 0.68)
                             : bg.inirEverywhere   ? ColorUtils.transparentize(Appearance.inir.colBorder, 0.5)
                             : bg.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.80)
                             : ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.76)
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
                                border.width: sysMA.containsMouse ? 1 : 0
                                border.color: bg.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colCardBorder, 0.46)
                                    : bg.inirEverywhere ? ColorUtils.transparentize(Appearance.inir.colBorder, 0.36)
                                    : bg.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.75)
                                    : ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.70)
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
                            border.width: layoutMA.containsMouse ? 1 : 0
                            border.color: bg.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colCardBorder, 0.46)
                                : bg.inirEverywhere ? ColorUtils.transparentize(Appearance.inir.colBorder, 0.36)
                                : bg.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.75)
                                : ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.70)
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
                anchors.rightMargin: 10
                contentWidth: controlsColumn.width
                contentHeight: controlsColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    id: controlsVScroll
                    policy: controlsFlickable.contentHeight > controlsFlickable.height
                        ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                }

                ColumnLayout {
                    id: controlsColumn
                    width: controlsFlickable.width - ((controlsVScroll.visible ? controlsVScroll.width : 0) + 6)
                    spacing: Appearance.sizes.spacingSmall

                    // Section header
                    SectionHeader {
                        Layout.fillWidth: true
                        headerText: Translation.tr("Controls")
                        headerIcon: "tune"
                        // Layout edit button
                        showAction: true
                        actionIcon: root.layoutEditMode ? "check" : "reorder"
                        actionTooltip: root.layoutEditMode ? Translation.tr("Done editing") : Translation.tr("Reorder sections")
                        onActionClicked: root.layoutEditMode = !root.layoutEditMode
                        // Quick toggles edit (only for android style)
                        showSecondaryAction: (Config.options?.sidebar?.quickToggles?.style ?? "classic") === "android"
                        secondaryActionIcon: root.editMode ? "check" : "edit"
                        secondaryActionTooltip: Translation.tr("Edit quick toggles")
                        onSecondaryActionClicked: root.editMode = !root.editMode
                    }

                    // ═══════════════════════════════════════════════════════
                    // REORDERABLE CONTROLS SECTIONS
                    // ═══════════════════════════════════════════════════════
                    Repeater {
                        model: root.controlsSectionOrder
                        
                        delegate: ColumnLayout {
                            id: sectionDelegate
                            required property string modelData
                            required property int index
                            
                            Layout.fillWidth: true
                            spacing: 4
                            
                            // Move buttons (visible in edit mode)
                            RowLayout {
                                Layout.fillWidth: true
                                visible: root.layoutEditMode
                                spacing: 4
                                
                                StyledText {
                                    Layout.fillWidth: true
                                    text: {
                                        switch (sectionDelegate.modelData) {
                                            case "sliders": return Translation.tr("Sliders")
                                            case "toggles": return Translation.tr("Quick Toggles")
                                            case "devices": return Translation.tr("Devices")
                                            case "media": return Translation.tr("Media Player")
                                            case "quickActions": return Translation.tr("Quick Actions")
                                            default: return sectionDelegate.modelData
                                        }
                                    }
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Medium
                                    color: bg.inirEverywhere ? Appearance.inir.colPrimary
                                        : bg.angelEverywhere ? Appearance.angel.colPrimary
                                        : Appearance.colors.colPrimary
                                }
                                
                                RippleButton {
                                    implicitWidth: 28; implicitHeight: 28
                                    buttonRadius: 14
                                    enabled: sectionDelegate.index > 0
                                    opacity: enabled ? 1 : 0.3
                                    colBackground: "transparent"
                                    colBackgroundHover: bg.inirEverywhere ? Appearance.inir.colLayer1Hover
                                        : bg.angelEverywhere ? Appearance.angel.colGlassCardHover
                                        : Appearance.colors.colLayer1Hover
                                    onClicked: root.moveSectionUp(sectionDelegate.index)
                                    contentItem: MaterialSymbol { anchors.centerIn: parent; text: "arrow_upward"; iconSize: 16; color: bg.inirEverywhere ? Appearance.inir.colText : bg.angelEverywhere ? Appearance.angel.colText : Appearance.colors.colOnLayer1 }
                                    StyledToolTip { text: Translation.tr("Move up") }
                                }
                                
                                RippleButton {
                                    implicitWidth: 28; implicitHeight: 28
                                    buttonRadius: 14
                                    enabled: sectionDelegate.index < root.controlsSectionOrder.length - 1
                                    opacity: enabled ? 1 : 0.3
                                    colBackground: "transparent"
                                    colBackgroundHover: bg.inirEverywhere ? Appearance.inir.colLayer1Hover
                                        : bg.angelEverywhere ? Appearance.angel.colGlassCardHover
                                        : Appearance.colors.colLayer1Hover
                                    onClicked: root.moveSectionDown(sectionDelegate.index)
                                    contentItem: MaterialSymbol { anchors.centerIn: parent; text: "arrow_downward"; iconSize: 16; color: bg.inirEverywhere ? Appearance.inir.colText : bg.angelEverywhere ? Appearance.angel.colText : Appearance.colors.colOnLayer1 }
                                    StyledToolTip { text: Translation.tr("Move down") }
                                }
                            }
                            
                            // Section content based on modelData
                            Loader {
                                Layout.fillWidth: true
                                active: sectionDelegate.modelData === "sliders"
                                visible: active && (Config.options?.sidebar?.quickSliders?.enable && (Config.options?.sidebar?.quickSliders?.showMic || Config.options?.sidebar?.quickSliders?.showVolume || Config.options?.sidebar?.quickSliders?.showBrightness))
                                sourceComponent: QuickSliders {}
                            }
                            
                            Loader {
                                Layout.fillWidth: true
                                active: sectionDelegate.modelData === "toggles"
                                visible: active
                                sourceComponent: ColumnLayout {
                                    spacing: 4
                                    
                                    // ControlsCard
                                    Item {
                                        Layout.fillWidth: true
                                        implicitHeight: ccSurface.implicitHeight
                                        
                                        Rectangle {
                                            id: ccSurface
                                            anchors.fill: parent
                                            implicitHeight: ccCard.implicitHeight + 10
                                            radius: bg.angelEverywhere ? Appearance.angel.roundingNormal : bg.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
                                            color: bg.angelEverywhere ? Appearance.angel.colGlassCard : bg.inirEverywhere ? Appearance.inir.colLayer1 : bg.colDarkSurface
                                            border.width: bg.angelEverywhere ? Appearance.angel.cardBorderWidth : 1
                                            border.color: bg.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colCardBorder, 0.22)
                                                : bg.inirEverywhere ? Appearance.inir.colBorder
                                                : bg.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.78)
                                                : ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.72)
                                            ControlsCard { id: ccCard; anchors.fill: parent; anchors.margins: 4 }
                                            AngelPartialBorder { targetRadius: ccSurface.radius }
                                        }
                                    }
                                    
                                    // Classic/Android Quick Panel
                                    Loader {
                                        id: compactClassicQuickPanelLoader
                                        Layout.fillWidth: true
                                        Layout.leftMargin: 2; Layout.rightMargin: 8
                                        active: (Config.options?.sidebar?.quickToggles?.style ?? "classic") === "classic"
                                        sourceComponent: ClassicQuickPanel { compactMode: true }
                                        Connections {
                                            target: compactClassicQuickPanelLoader.item
                                            ignoreUnknownSignals: true
                                            function onOpenAudioOutputDialog() { root.showAudioOutputDialog = true }
                                            function onOpenAudioInputDialog()  { root.showAudioInputDialog  = true }
                                            function onOpenBluetoothDialog()   { root.showBluetoothDialog   = true }
                                            function onOpenNightLightDialog()  { root.showNightLightDialog  = true }
                                            function onOpenWifiDialog()        { root.showWifiDialog        = true }
                                        }
                                    }
                                    Loader {
                                        id: compactAndroidQuickPanelLoader
                                        Layout.fillWidth: true
                                        Layout.leftMargin: 2; Layout.rightMargin: 2
                                        active: (Config.options?.sidebar?.quickToggles?.style ?? "classic") === "android"
                                        sourceComponent: AndroidQuickPanel { editMode: root.editMode }
                                        Connections {
                                            target: compactAndroidQuickPanelLoader.item
                                            ignoreUnknownSignals: true
                                            function onOpenAudioOutputDialog() { root.showAudioOutputDialog = true }
                                            function onOpenAudioInputDialog()  { root.showAudioInputDialog  = true }
                                            function onOpenBluetoothDialog()   { root.showBluetoothDialog   = true }
                                            function onOpenNightLightDialog()  { root.showNightLightDialog  = true }
                                            function onOpenWifiDialog()        { root.showWifiDialog        = true }
                                        }
                                    }
                                }
                            }
                            
                            Loader {
                                Layout.fillWidth: true
                                active: sectionDelegate.modelData === "devices"
                                visible: active
                                sourceComponent: ColumnLayout {
                                    spacing: 6
                                    SectionDivider { text: Translation.tr("Devices"); visible: !root.layoutEditMode }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 2
                                        columnSpacing: 6
                                        rowSpacing: 6

                                        ControlChipButton { Layout.fillWidth: true; chipIcon: "media_output"; chipLabel: Translation.tr("Output"); value: Audio.sink?.description ?? ""; onClicked: root.showAudioOutputDialog = true }
                                        ControlChipButton { Layout.fillWidth: true; chipIcon: "mic_external_on"; chipLabel: Translation.tr("Input"); value: Audio.source?.description ?? ""; onClicked: root.showAudioInputDialog = true }
                                        ControlChipButton { Layout.fillWidth: true; chipIcon: "bluetooth"; chipLabel: Translation.tr("Bluetooth"); value: Bluetooth.defaultAdapter?.enabled ? Translation.tr("On") : Translation.tr("Off"); onClicked: root.showBluetoothDialog = true }
                                        ControlChipButton { Layout.fillWidth: true; chipIcon: Network.materialSymbol; chipLabel: Translation.tr("Wi-Fi"); value: Network.networkName ?? ""; onClicked: root.showWifiDialog = true }
                                    }
                                }
                            }
                            
                            Loader {
                                Layout.fillWidth: true
                                active: sectionDelegate.modelData === "media"
                                visible: active
                                sourceComponent: ColumnLayout {
                                    spacing: 8
                                    SectionDivider { text: Translation.tr("Media"); visible: !root.layoutEditMode }

                                    CompactMediaPlayer {
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                            
                            Loader {
                                Layout.fillWidth: true
                                active: sectionDelegate.modelData === "quickActions"
                                visible: active
                                sourceComponent: QuickActionsSection {}
                            }
                        }
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

    ToggleDialog {
        id: compactEventsToggle
        shownPropertyString: "showEventsDialog"
        dialog: EventsDialog {}
        onShownChanged: {
            if (shown && compactEventsToggle.item) {
                if (root.eventsDialogEditEvent) {
                    compactEventsToggle.item.loadEvent(root.eventsDialogEditEvent)
                } else {
                    compactEventsToggle.item.resetForm()
                }
            }
        }
        onActiveChanged: {
            if (!active) {
                root.eventsDialogEditEvent = null
            }
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
        Quickshell.execDetached(["/usr/bin/bash", Quickshell.shellPath("scripts/restart-shell.sh")])
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
        Qt.callLater(() => Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "settings"]))
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
            ignoreUnknownSignals: true
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
                colBackground: bg.inirEverywhere ? ColorUtils.transparentize(Appearance.inir.colLayer1, 0.35)
                    : bg.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colGlassCard, 0.72)
                    : bg.auroraEverywhere ? bg.colDarkSurface
                    : ColorUtils.transparentize(Appearance.colors.colLayer1, 0.68)
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
                    : (bg.inirEverywhere ? ColorUtils.transparentize(Appearance.inir.colLayer1, 0.35)
                     : bg.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colGlassCard, 0.72)
                     : bg.auroraEverywhere ? bg.colDarkSurface
                     : ColorUtils.transparentize(Appearance.colors.colLayer1, 0.68))
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
            width: Math.min(parent.width - 32, 280)
            spacing: 12

            MaterialPlaceholderMessage {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                maximumWidth: 280
                compact: true
                shown: emptyPlaceholder.visible
                icon: Notifications.silent ? "notifications_off" : "notifications_active"
                text: Notifications.silent ? Translation.tr("Muted") : Translation.tr("Clear")
                shape: MaterialShape.Shape.Ghostish
            }

            RippleButton {
                id: dndChip
                Layout.alignment: Qt.AlignHCenter
                implicitHeight: 32
                implicitWidth: dndChipContent.implicitWidth + 20
                buttonRadius: Appearance.rounding.full
                colBackground: Notifications.silent
                    ? (bg.inirEverywhere ? Appearance.inir.colSecondaryContainer
                        : bg.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colPrimary, 0.60)
                        : Appearance.colors.colSecondaryContainer)
                    : (bg.inirEverywhere ? Appearance.inir.colLayer1
                        : bg.angelEverywhere ? Appearance.angel.colGlassCard
                        : bg.colDarkSurface)
                colBackgroundHover: Notifications.silent
                    ? (bg.inirEverywhere ? Appearance.inir.colSecondaryContainerHover
                        : bg.angelEverywhere ? Appearance.angel.colPrimaryHover
                        : Appearance.colors.colSecondaryContainerHover)
                    : (bg.inirEverywhere ? Appearance.inir.colLayer1Hover
                        : bg.angelEverywhere ? Appearance.angel.colGlassCardHover
                        : bg.colDarkSurfaceHover)
                colRipple: Notifications.silent
                    ? (bg.inirEverywhere ? Appearance.inir.colSecondaryContainerActive
                        : bg.angelEverywhere ? Appearance.angel.colPrimaryActive
                        : Appearance.colors.colSecondaryContainerActive)
                    : (bg.inirEverywhere ? Appearance.inir.colLayer1Active
                        : bg.angelEverywhere ? Appearance.angel.colGlassCardActive
                        : bg.colDarkSurfaceActive)
                onClicked: Notifications.silent = !Notifications.silent

                contentItem: RowLayout {
                    id: dndChipContent
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialSymbol {
                        text: Notifications.silent ? "notifications_active" : "notifications_off"
                        iconSize: 16
                        color: Notifications.silent
                            ? (bg.inirEverywhere ? Appearance.inir.colOnSecondaryContainer
                                : bg.angelEverywhere ? Appearance.angel.colOnPrimary
                                : Appearance.m3colors.m3onSecondaryContainer)
                            : (bg.inirEverywhere ? Appearance.inir.colTextSecondary
                                : bg.angelEverywhere ? Appearance.angel.colTextSecondary
                                : Appearance.colors.colSubtext)
                    }

                    StyledText {
                        text: Notifications.silent
                            ? Translation.tr("Enable notifications")
                            : Translation.tr("Enable DND")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Notifications.silent
                            ? (bg.inirEverywhere ? Appearance.inir.colOnSecondaryContainer
                                : bg.angelEverywhere ? Appearance.angel.colOnPrimary
                                : Appearance.m3colors.m3onSecondaryContainer)
                            : (bg.inirEverywhere ? Appearance.inir.colText
                                : bg.angelEverywhere ? Appearance.angel.colText
                                : Appearance.colors.colOnLayer1)
                    }
                }
            }
        }
    }

    // ── Quick Actions Section ─────────────────────────────────────
    component QuickActionsSection: ColumnLayout {
        id: quickActions
        spacing: Appearance.sizes.spacingSmall

        SectionDivider {
            text: Translation.tr("Quick Actions")
        }

        // Action buttons — compact 3-column grid
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 6
            rowSpacing: 6

            QuickActionButton {
                Layout.fillWidth: true
                icon: "screenshot_monitor"
                label: Translation.tr("Screenshot")
                onClicked: {
                    GlobalStates.sidebarRightOpen = false
                    Qt.callLater(() => Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "region", "screenshot"]))
                }
            }

            QuickActionButton {
                Layout.fillWidth: true
                icon: "videocam"
                label: Translation.tr("Record")
                onClicked: {
                    GlobalStates.sidebarRightOpen = false
                    Qt.callLater(() => Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "region", "record"]))
                }
            }

            QuickActionButton {
                Layout.fillWidth: true
                icon: "document_scanner"
                label: Translation.tr("OCR")
                onClicked: {
                    GlobalStates.sidebarRightOpen = false
                    Qt.callLater(() => Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "region", "ocr"]))
                }
            }

            QuickActionButton {
                Layout.fillWidth: true
                icon: "travel_explore"
                label: Translation.tr("Search")
                onClicked: {
                    GlobalStates.sidebarRightOpen = false
                    Qt.callLater(() => Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "region", "search"]))
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

    component BubbleToolTip: PopupToolTip {
        id: bubble
        property string position: "left" // top | right | left
        delay: 0
        horizontalPadding: 12
        verticalPadding: 5
        anchorEdges: position === "left" ? Edges.Left
            : position === "right" ? Edges.Right
            : Edges.Top
        anchorGravity: anchorEdges
        contentItem: Item {
            id: bubbleContent
            property bool shown: false
            implicitWidth: bubbleBackground.implicitWidth
            implicitHeight: bubbleBackground.implicitHeight
            opacity: shown ? 1 : 0
            scale: shown ? 1 : 0.9

            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic }
            }

            Behavior on scale {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic }
            }

            Rectangle {
                id: bubbleBackground
                anchors.centerIn: parent
                color: bg.angelEverywhere ? Appearance.angel.colPrimary
                    : bg.inirEverywhere ? Appearance.inir.colPrimary
                    : Appearance.colors.colPrimary
                radius: Appearance.rounding.full
                implicitWidth: bubbleLabel.implicitWidth + 24
                implicitHeight: bubbleLabel.implicitHeight + 10

                StyledText {
                    id: bubbleLabel
                    anchors.centerIn: parent
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
                        : bg.colDarkSurfaceActive
                if (qaBtnMA.containsMouse)
                    return bg.inirEverywhere ? Appearance.inir.colLayer2Hover
                        : bg.angelEverywhere ? Appearance.angel.colGlassCardHover
                        : bg.colDarkSurfaceHover
                if (qaBtn.toggled)
                    return bg.inirEverywhere ? Appearance.inir.colSecondaryContainer
                        : bg.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colPrimary, 0.6)
                        : Appearance.colors.colSecondaryContainer
                return bg.inirEverywhere ? Appearance.inir.colLayer1
                    : bg.angelEverywhere ? Appearance.angel.colGlassCard
                    : bg.colDarkSurface
            }
            border.width: bg.angelEverywhere ? Appearance.angel.cardBorderWidth : 1
            border.color: bg.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colCardBorder, 0.28)
                : bg.inirEverywhere ? Appearance.inir.colBorder
                : bg.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.78)
                : ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.72)
            
            scale: qaBtnMA.containsPress ? 0.94 : 1.0
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
                spacing: 2

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: qaBtn.icon
                    iconSize: 18
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
                    Layout.maximumWidth: qaBtnBg.width - 8
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
                    horizontalAlignment: Text.AlignHCenter
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
