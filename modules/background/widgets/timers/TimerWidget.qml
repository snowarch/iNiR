pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.background.widgets
import qs.modules.background.widgets.instrument
import qs.modules.iris.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "timers"
    defaultConfig: ({
        placementStrategy: "free", vertical: false, style: "cards", glow: true,
        showProgress: true, showState: true, showHundredths: true,
        widgetScale: 100, widgetOpacity: 100,
        showBackground: false, useBlur: false, showBorder: false,
        backgroundOpacity: 0, borderWidth: 0, borderOpacity: 0.16,
        cornerRadius: -1, colorMode: "auto", dim: 0,
        x: 360, y: 420
    })

    readonly property bool vertical: Boolean(root._readConfigKey("vertical") ?? false)
    readonly property bool instrument: String(root._readConfigKey("style") ?? "cards") === "instrument"
    widgetSurfaceEnabled: !root.instrument
    resizableAxes: ({ uniform: "widgetScale" })
    readonly property bool pulse: Boolean(root._readConfigKey("glow") ?? true)
    readonly property bool showProgress: Boolean(root._readConfigKey("showProgress") ?? true)
    readonly property bool showState: Boolean(root._readConfigKey("showState") ?? true)
    readonly property bool showHundredths: Boolean(root._readConfigKey("showHundredths") ?? true)
    readonly property real cardWidth: Math.round((root.instrument ? 176 : 136) * root.scaleFactor)
    readonly property real cardHeight: Math.round((root.instrument ? 132 : 120) * root.scaleFactor)
    readonly property real cardSpacing: Math.round(12 * root.scaleFactor)

    implicitWidth: root.irisFaced ? root.irisFaceWidth : timerGrid.implicitWidth
    implicitHeight: root.irisFaced ? root.irisFaceHeight : timerGrid.implicitHeight
    irisFace: Component { IrisTimerFace { widget: root } }
    irisSizes: ["small", "medium"]
    irisDefaultSize: "medium"
    visibleWhenLocked: true
    needsColText: true
    draggable: GlobalStates.widgetEditMode && !GlobalStates.screenLocked && !root.locked

    function formatSeconds(seconds: real): string {
        const total = Math.max(0, Math.floor(Number(seconds) || 0))
        const minutes = Math.floor(total / 60).toString().padStart(2, "0")
        const secs = (total % 60).toString().padStart(2, "0")
        return minutes + ":" + secs
    }

    function formatStopwatch(ticks: real): string {
        const total = Math.max(0, Math.floor(Number(ticks) || 0))
        const minutes = Math.floor(total / 6000).toString().padStart(2, "0")
        const seconds = Math.floor(total / 100 % 60).toString().padStart(2, "0")
        if (!root.showHundredths)
            return minutes + ":" + seconds
        const centiseconds = (total % 100).toString().padStart(2, "0")
        return minutes + ":" + seconds + "." + centiseconds
    }

    function addCountdownMinutes(minutes: int): void {
        TimerService.adjustCountdownDuration(minutes * 60)
    }

    editPopoverContent: Component {
        ColumnLayout {
            spacing: 14
            WidgetQuickSection {
                title: Translation.tr("Style")
                WidgetQuickChoices {
                    current: root.instrument ? "instrument" : "cards"
                    model: [
                        { label: Translation.tr("Cards"), icon: "dashboard_2", value: "cards" },
                        { label: Translation.tr("Instrument"), icon: "timer", value: "instrument" }
                    ]
                    onPicked: value => root._setOutputValue("style", value)
                }
            }
            WidgetQuickSection {
                title: Translation.tr("Layout")
                WidgetQuickChoices {
                    current: root.vertical
                    model: [
                        { label: Translation.tr("Horizontal"), icon: "view_week", value: false },
                        { label: Translation.tr("Vertical"), icon: "view_agenda", value: true }
                    ]
                    onPicked: value => root._setOutputValue("vertical", value)
                }
            }
            WidgetQuickSection {
                visible: root.instrument
                title: Translation.tr("Show")
                Repeater {
                    model: [
                        { label: Translation.tr("Progress"), icon: "linear_scale", key: "showProgress", fallback: true },
                        { label: Translation.tr("Details"), icon: "label", key: "showState", fallback: true },
                        { label: Translation.tr("Hundredths"), icon: "timer_10_alt_1", key: "showHundredths", fallback: true }
                    ]
                    WidgetQuickToggle {
                        required property var modelData
                        Layout.fillWidth: true
                        iconName: modelData.icon
                        label: modelData.label
                        checked: Boolean(root._readConfigKey(modelData.key) ?? modelData.fallback)
                        onToggled: root._setOutputValue(modelData.key, !checked)
                    }
                }
            }
        }
    }

    component TimerCard: Rectangle {
        id: timerCard

        required property string icon
        required property string value
        required property string label
        required property bool running
        required property bool paused
        required property int shape
        required property string semanticRole
        property var toggleAction: () => {}
        property var resetAction: () => {}
        property var secondaryAction: null
        property string secondaryIcon: ""
        property string secondaryTip: ""
        property real progress: 0
        property bool progressMeaningful: false
        default property alias footerData: footerSlot.data

        readonly property bool instrumentMode: root.instrument
        readonly property color face: root.widgetSemanticContainer(timerCard.semanticRole)
        readonly property color cardInk: root.widgetSemanticOnContainer(timerCard.semanticRole)
        readonly property color signal: root.widgetSemanticForeground(timerCard.semanticRole)
        readonly property color ink: instrumentMode ? root.widgetInk : timerCard.cardInk
        readonly property color mutedInk: instrumentMode ? root.widgetInkMuted : ColorUtils.applyAlpha(timerCard.cardInk, 0.68)

        implicitWidth: root.cardWidth
        implicitHeight: root.cardHeight
        radius: instrumentMode ? 0 : Math.min(Appearance.rounding.verylarge, height / 3)
        color: instrumentMode ? "transparent" : timerCard.face
        border.width: instrumentMode ? 0 : (root.showBorder ? Math.max(1, Math.round(root.borderWidth)) : 0)
        border.color: ColorUtils.applyAlpha(timerCard.cardInk, root.borderOpacity)
        Behavior on color {
            enabled: root.animationsActive
            ColorAnimation { duration: Appearance.animation.elementMove.duration }
        }
        Behavior on radius {
            enabled: root.animationsActive
            NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Easing.OutCubic }
        }
        Behavior on implicitWidth {
            enabled: root.animateGeometry
            NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Easing.OutCubic }
        }
        Behavior on implicitHeight {
            enabled: root.animateGeometry
            NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Easing.OutCubic }
        }

        StyledRectangularShadow {
            target: timerCard
            visible: !timerCard.instrumentMode && Appearance.effectsEnabled && !Appearance.gameModeMinimal
            z: -2
        }

        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: timerCard.resetAction()
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Math.round((timerCard.instrumentMode ? 7 : 12) * root.scaleFactor)
            spacing: Math.round((timerCard.instrumentMode ? 3 : 4) * root.scaleFactor)

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(5 * root.scaleFactor)

                MaterialSymbol {
                    visible: timerCard.instrumentMode
                    text: timerCard.icon
                    iconSize: Math.round(16 * root.scaleFactor)
                    color: timerCard.signal
                }

                InstrumentLabel {
                    visible: timerCard.instrumentMode
                    Layout.fillWidth: true
                    text: timerCard.label
                    color: timerCard.mutedInk
                    scaleFactor: root.scaleFactor
                    size: 10
                    strong: true
                }

                StyledText {
                    visible: !timerCard.instrumentMode
                    Layout.fillWidth: true
                    text: timerCard.label
                    color: timerCard.mutedInk
                    font.family: root.widgetBodyFamily
                    font.pixelSize: timerCard.instrumentMode
                        ? Math.max(10, Math.round(11 * root.scaleFactor))
                        : Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                    font.weight: root.widgetLabelWeight
                    font.letterSpacing: timerCard.instrumentMode ? root.widgetMetadataTracking : 0
                    font.capitalization: timerCard.instrumentMode ? root.widgetCapitalization : Font.MixedCase
                    elide: Text.ElideRight
                }

                InstrumentLabel {
                    visible: timerCard.instrumentMode && root.showState && timerCard.paused
                    text: Translation.tr("Paused")
                    color: timerCard.signal
                    scaleFactor: root.scaleFactor
                    size: 8
                    strong: true
                }

                RippleButton {
                    visible: !timerCard.instrumentMode
                    Layout.preferredWidth: Math.round(34 * root.scaleFactor)
                    Layout.preferredHeight: Math.round(34 * root.scaleFactor)
                    buttonRadius: Appearance.rounding.full
                    colBackground: ColorUtils.applyAlpha(timerCard.cardInk, 0.10)
                    colBackgroundHover: ColorUtils.applyAlpha(timerCard.cardInk, 0.16)
                    colRipple: ColorUtils.applyAlpha(timerCard.cardInk, 0.20)
                    releaseAction: () => timerCard.toggleAction()
                    contentItem: MaterialShapeWrappedMaterialSymbol {
                        anchors.centerIn: parent
                        shape: timerCard.shape
                        color: "transparent"
                        colSymbol: timerCard.cardInk
                        text: timerCard.running && !timerCard.paused ? "pause" : timerCard.icon
                        iconSize: Math.round(17 * root.scaleFactor)
                        fill: 1
                        padding: 0
                    }
                }
            }

            Item { Layout.fillHeight: true }

            StyledText {
                Layout.fillWidth: true
                text: timerCard.value
                color: timerCard.ink
                horizontalAlignment: Text.AlignLeft
                fontSizeMode: Text.Fit
                minimumPixelSize: Math.max(15, Math.round(16 * root.scaleFactor))
                font.pixelSize: timerCard.instrumentMode
                    ? Math.max(24, Math.round(30 * root.scaleFactor))
                    : Math.round(Appearance.font.pixelSize.large * root.scaleFactor)
                font.weight: timerCard.instrumentMode
                    ? (root.widgetEditorial ? Appearance.editorial.titleWeight : Font.Bold)
                    : Font.Bold
                font.family: root.widgetNumbersFamily
                font.features: ({ "tnum": 1 })
                font.letterSpacing: timerCard.instrumentMode ? -1 : 0
            }

            Item {
                visible: timerCard.instrumentMode && root.showProgress && timerCard.progressMeaningful
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(3, Math.round(3 * root.scaleFactor))

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: Math.max(1, Math.round(root.scaleFactor))
                    color: ColorUtils.applyAlpha(root.widgetInk, 0.16)
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * Math.max(0, Math.min(1, timerCard.progress))
                    height: Math.max(2, Math.round(2 * root.scaleFactor))
                    radius: height / 2
                    color: timerCard.signal
                    Behavior on width {
                        enabled: root.animationsActive
                        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: timerCard.instrumentMode
                    ? Math.max(27, Math.round(29 * root.scaleFactor))
                    : (footerSlot.children.length > 0 ? Math.round(22 * root.scaleFactor) : 0)
                spacing: Math.round(4 * root.scaleFactor)

                RippleButton {
                    visible: timerCard.instrumentMode
                    Layout.preferredWidth: Math.max(30, Math.round(32 * root.scaleFactor))
                    Layout.preferredHeight: Math.max(26, Math.round(28 * root.scaleFactor))
                    buttonRadius: root.widgetControlRadius
                    colBackground: ColorUtils.applyAlpha(timerCard.signal, 0.16)
                    colBackgroundHover: ColorUtils.applyAlpha(timerCard.signal, 0.24)
                    colRipple: ColorUtils.applyAlpha(timerCard.signal, 0.3)
                    releaseAction: () => timerCard.toggleAction()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: timerCard.running && !timerCard.paused ? "pause" : "play_arrow"
                        color: timerCard.signal
                        iconSize: Math.max(14, Math.round(16 * root.scaleFactor))
                        fill: 1
                    }
                    StyledToolTip { text: timerCard.running && !timerCard.paused ? Translation.tr("Pause") : Translation.tr("Start") }
                }

                RippleButton {
                    visible: timerCard.instrumentMode && timerCard.secondaryAction !== null
                    Layout.preferredWidth: Math.max(27, Math.round(29 * root.scaleFactor))
                    Layout.preferredHeight: Math.max(26, Math.round(28 * root.scaleFactor))
                    buttonRadius: root.widgetControlRadius
                    colBackground: "transparent"
                    colBackgroundHover: ColorUtils.applyAlpha(timerCard.signal, 0.12)
                    colRipple: ColorUtils.applyAlpha(timerCard.signal, 0.22)
                    releaseAction: () => timerCard.secondaryAction()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: timerCard.secondaryIcon
                        color: timerCard.signal
                        iconSize: Math.max(13, Math.round(15 * root.scaleFactor))
                    }
                    StyledToolTip { text: timerCard.secondaryTip }
                }

                RippleButton {
                    visible: timerCard.instrumentMode && footerSlot.children.length === 0
                        && timerCard.secondaryAction === null
                    Layout.preferredWidth: Math.round(28 * root.scaleFactor)
                    Layout.preferredHeight: Math.round(28 * root.scaleFactor)
                    buttonRadius: root.widgetControlRadius
                    colBackground: "transparent"
                    colBackgroundHover: ColorUtils.applyAlpha(timerCard.signal, 0.12)
                    releaseAction: () => timerCard.resetAction()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "restart_alt"
                        color: timerCard.mutedInk
                        iconSize: Math.round(16 * root.scaleFactor)
                    }
                    StyledToolTip { text: Translation.tr("Reset") }
                }

                Item { Layout.fillWidth: timerCard.instrumentMode }

                Item {
                    id: footerSlot
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }
    }

    Grid {
        id: timerGrid
        opacity: 1
        visible: !root.irisFaced
        enabled: !GlobalStates.widgetEditMode
        move: Transition {
            enabled: root.animateGeometry
            NumberAnimation { properties: "x,y"; duration: Appearance.animation.elementMove.duration; easing.type: Easing.OutCubic }
        }
        columns: root.vertical ? 1 : 3
        spacing: root.cardSpacing

        TimerCard {
            icon: TimerService.pomodoroBreak ? "coffee" : "target"
            value: root.formatSeconds(TimerService.pomodoroSecondsLeft)
            label: TimerService.pomodoroLongBreak ? Translation.tr("Long break")
                : TimerService.pomodoroBreak ? Translation.tr("Break") : Translation.tr("Focus")
            running: TimerService.pomodoroRunning
            paused: TimerService.pomodoroPaused
            shape: MaterialShape.Shape.Flower
            semanticRole: root.widgetTertiaryRole
            toggleAction: () => TimerService.togglePomodoro()
            resetAction: () => TimerService.resetPomodoro()
            progressMeaningful: true
            progress: 1 - TimerService.pomodoroSecondsLeft / Math.max(1, TimerService.pomodoroLapDuration)
        }

        TimerCard {
            icon: "timer"
            value: root.instrument ? root.formatStopwatch(TimerService.stopwatchTime)
                : root.formatSeconds(TimerService.stopwatchTime / 100)
            label: Translation.tr("Stopwatch")
            running: TimerService.stopwatchRunning
            paused: TimerService.stopwatchPaused
            shape: MaterialShape.Shape.Sunny
            semanticRole: root.widgetSecondaryRole
            toggleAction: () => TimerService.toggleStopwatch()
            resetAction: () => TimerService.stopwatchReset()
            secondaryAction: TimerService.stopwatchRunning ? (() => TimerService.stopwatchRecordLap()) : null
            secondaryIcon: "flag"
            secondaryTip: Translation.tr("Record lap")
        }

        TimerCard {
            icon: "hourglass_top"
            value: root.formatSeconds(TimerService.countdownSecondsLeft)
            label: Translation.tr("Countdown")
            running: TimerService.countdownRunning
            paused: TimerService.countdownPaused
            shape: MaterialShape.Shape.Bun
            semanticRole: root.widgetPrimaryRole
            toggleAction: () => TimerService.toggleCountdown()
            resetAction: () => TimerService.resetCountdown()
            progressMeaningful: true
            progress: 1 - TimerService.countdownSecondsLeft / Math.max(1, TimerService.countdownDuration)

            RowLayout {
                anchors.fill: parent
                spacing: Math.round(4 * root.scaleFactor)

                Repeater {
                    model: [1, 5]
                    RippleButton {
                        id: minuteButton
                        required property int modelData
                        Layout.fillWidth: true
                        Layout.minimumWidth: Math.round(32 * root.scaleFactor)
                        Layout.fillHeight: true
                        buttonRadius: root.instrument || root.widgetEditorial
                            ? root.widgetControlRadius : Appearance.rounding.full
                        colBackground: root.instrument
                            ? "transparent" : ColorUtils.applyAlpha(root.primaryInk, 0.10)
                        colBackgroundHover: ColorUtils.applyAlpha(
                            root.instrument ? root.widgetAccentVisible : root.primaryInk, 0.16)
                        colRipple: ColorUtils.applyAlpha(
                            root.instrument ? root.widgetAccentVisible : root.primaryInk, 0.24)
                        onClicked: root.addCountdownMinutes(minuteButton.modelData)

                        contentItem: StyledText {
                            anchors.centerIn: parent
                            text: "+" + modelData + "m"
                            color: root.instrument ? root.widgetInkMuted : root.primaryInk
                            font.family: root.widgetNumbersFamily
                            font.pixelSize: Math.max(10, Math.round(11 * root.scaleFactor))
                            font.weight: root.instrument || root.widgetEditorial
                                ? root.widgetLabelWeight : Font.DemiBold
                        }

                    }
                }
            }
        }
    }

    readonly property color primaryInk: root.widgetSemanticOnContainer(root.widgetPrimaryRole)

}
