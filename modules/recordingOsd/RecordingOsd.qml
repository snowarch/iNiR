pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Scope {
    id: root

    property bool isVertical: false
    property bool collapsed: false
    readonly property bool autoHide: Config.options?.screenRecord?.recordingOsd?.autoHide ?? false
    property bool revealed: true
    property bool osdTargetHovered: false

    function startHideTimer(): void {
        if (!autoHide) return
        if (osdTargetHovered) return
        hideTimer.restart()
    }

    function formatTime(totalSeconds: int): string {
        const hours = Math.floor(totalSeconds / 3600)
        const minutes = Math.floor((totalSeconds % 3600) / 60)
        const seconds = totalSeconds % 60
        const pad = (n) => n < 10 ? "0" + n : "" + n
        if (hours > 0) return pad(hours) + ":" + pad(minutes) + ":" + pad(seconds)
        return pad(minutes) + ":" + pad(seconds)
    }

    function stopRecording(): void {
        Quickshell.execDetached(["/usr/bin/pkill", "-SIGINT", "wf-recorder"])
    }

    Connections {
        target: RecorderStatus
        function onIsRecordingChanged(): void {
            if (RecorderStatus.isRecording) {
                root.collapsed = false
                root.isVertical = false
                root.revealed = true
                // Start auto-hide timer if enabled
                if (root.autoHide) {
                    root.startHideTimer()
                }
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 2000
        onTriggered: {
            if (!root.autoHide) return
            if (root.osdTargetHovered) return
            root.revealed = false
        }
    }

    Loader {
        id: osdLoader
        active: RecorderStatus.isRecording

        sourceComponent: PanelWindow {
            id: osdWindow
            visible: osdLoader.active && !GlobalStates.screenLocked
            screen: GlobalStates.primaryScreen

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:recordingOsd"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            color: "transparent"

            mask: Region { item: pill }

            readonly property real edgeMargin: Appearance.sizes.elevationMargin

            function snapToNearestEdge(): void {
                const margin = edgeMargin
                const pw = osdWindow.width
                const ph = osdWindow.height
                const pillW = pill.width
                const pillH = pill.height
                const cx = pill.x + pillW / 2
                const cy = pill.y + pillH / 2

                const distLeft = pill.x
                const distRight = pw - (pill.x + pillW)
                const distTop = pill.y
                const distBottom = ph - (pill.y + pillH)

                const minDist = Math.min(distLeft, distRight, distTop, distBottom)

                const wasVertical = root.isVertical
                const snapsToSide = (minDist === distLeft || minDist === distRight)
                root.isVertical = snapsToSide

                let targetX, targetY

                if (snapsToSide) {
                    targetX = (minDist === distLeft) ? margin : pw - pillW - margin
                    targetY = Math.max(margin, Math.min(ph - pillH - margin, pill.y))
                } else {
                    targetY = (minDist === distTop) ? margin : ph - pillH - margin
                    targetX = Math.max(margin, Math.min(pw - pillW - margin, pill.x))
                }

                if (root.isVertical !== wasVertical) {
                    Qt.callLater(() => {
                        const newPillW = pill.width
                        const newPillH = pill.height

                        let newX, newY
                        if (snapsToSide) {
                            newX = (minDist === distLeft) ? margin : pw - newPillW - margin
                            newY = Math.max(margin, Math.min(ph - newPillH - margin, cy - newPillH / 2))
                        } else {
                            newY = (minDist === distTop) ? margin : ph - newPillH - margin
                            newX = Math.max(margin, Math.min(pw - newPillW - margin, cx - newPillW / 2))
                        }

                        pill.animatePosition = true
                        pill.x = newX
                        pill.y = newY
                    })
                    return
                }

                pill.animatePosition = true
                pill.x = targetX
                pill.y = targetY
            }

            StyledRectangularShadow { 
                target: pill
                visible: false  // Remove shadow completely
            }

            Item {
                id: pill
                property bool animatePosition: false
                property real contentPadding: 6
                property bool _positioned: false
                property bool _osdHovered: false

                // When auto-hide is active and not revealed: fade + shrink away
                opacity: root.autoHide && !root.revealed ? 0 : (initScale < 0.95 ? 0 : 1)
                scale: root.autoHide && !root.revealed ? 0.5 : initScale

                width: root.isVertical
                    ? verticalContent.implicitWidth + contentPadding * 2
                    : horizontalContent.implicitWidth + contentPadding * 2
                height: root.isVertical
                    ? verticalContent.implicitHeight + contentPadding * 2
                    : horizontalContent.implicitHeight + contentPadding * 2

                HoverHandler {
                    onHoveredChanged: {
                        pill._osdHovered = (hovered === true)
                        root.osdTargetHovered = (hovered === true)
                        if (hovered) {
                            if (root.autoHide && !root.revealed)
                                root.revealed = true
                            hideTimer.stop()
                        } else if (root.autoHide && root.revealed) {
                            root.startHideTimer()
                        }
                    }
                }

                // Position once the window has its real size
                Connections {
                    target: osdWindow
                    function onWidthChanged(): void {
                        if (!pill._positioned && osdWindow.width > 0) {
                            pill.x = (osdWindow.width - pill.width) / 2
                            pill.y = Appearance.sizes.elevationMargin
                            pill._positioned = true
                            Qt.callLater(() => { pill.initScale = 1.0 })
                        }
                    }
                }

                property real initScale: 0.9
                transformOrigin: Item.Center

                GlassBackground {
                    id: pillBg
                    anchors.fill: parent
                    property point screenPos: mapToGlobal(0, 0)
                    screenX: screenPos.x
                    screenY: screenPos.y

                    fallbackColor: Appearance.colors.colLayer2
                    inirColor: Appearance.inir.colLayer1
                    auroraTransparency: Appearance.aurora.popupTransparentize

                    radius: Appearance.rounding.large
                    border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth : 1
                    border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                                : Appearance.inirEverywhere ? Appearance.inir.colBorder
                                : Appearance.colors.colOutlineVariant
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveEnter.duration
                        easing.type: Appearance.animation.elementMoveEnter.type
                        easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveEnter.duration
                        easing.type: Appearance.animation.elementMoveEnter.type
                        easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                    }
                }
                Behavior on x {
                    enabled: pill.animatePosition
                    NumberAnimation {
                        duration: Appearance.animation.elementMove.duration
                        easing.type: Appearance.animation.elementMove.type
                        easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                        onRunningChanged: if (!running) pill.animatePosition = false
                    }
                }
                Behavior on y {
                    enabled: pill.animatePosition
                    NumberAnimation {
                        duration: Appearance.animation.elementMove.duration
                        easing.type: Appearance.animation.elementMove.type
                        easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                    }
                }
                Behavior on width {
                    enabled: pill.animatePosition
                    NumberAnimation {
                        duration: Appearance.animation.elementResize.duration
                        easing.type: Appearance.animation.elementResize.type
                        easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                    }
                }
                Behavior on height {
                    enabled: pill.animatePosition
                    NumberAnimation {
                        duration: Appearance.animation.elementResize.duration
                        easing.type: Appearance.animation.elementResize.type
                        easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                    }
                }

                // Horizontal layout (default, top/bottom edge)
                RowLayout {
                    id: horizontalContent
                    visible: !root.isVertical
                    anchors.centerIn: parent
                    spacing: 2

                    OsdDragHandle { isVertical: false }

                    RecordingIndicator { isVertical: false }

                    OsdPillButton {
                        iconName: "stop"
                        filled: true
                        iconColor: Appearance.colors.colError
                        onClicked: root.stopRecording()
                        tooltip: Translation.tr("Stop recording")
                    }

                    OsdSeparator { isVertical: false; visible: !root.collapsed }

                    OsdPillButton {
                        visible: !root.collapsed
                        iconName: Audio.sink?.audio?.muted ? "volume_off" : "volume_up"
                        dimmed: Audio.sink?.audio?.muted ?? false
                        onClicked: Audio.toggleMute()
                        tooltip: Audio.sink?.audio?.muted
                            ? Translation.tr("Unmute audio") : Translation.tr("Mute audio")
                    }
                    OsdPillButton {
                        visible: !root.collapsed
                        iconName: Audio.micMuted ? "mic_off" : "mic"
                        dimmed: Audio.micMuted
                        onClicked: Audio.toggleMicMute()
                        tooltip: Audio.micMuted
                            ? Translation.tr("Unmute mic") : Translation.tr("Mute mic")
                    }

                    OsdPillButton {
                        iconName: root.collapsed ? "open_in_full" : "close_fullscreen"
                        onClicked: root.collapsed = !root.collapsed
                        tooltip: root.collapsed
                            ? Translation.tr("Expand controls") : Translation.tr("Minimize")
                    }
                }

                // Vertical layout (left/right edge)
                ColumnLayout {
                    id: verticalContent
                    visible: root.isVertical
                    anchors.centerIn: parent
                    spacing: 2

                    OsdDragHandle { isVertical: true }

                    RecordingIndicator { isVertical: true }

                    OsdPillButton {
                        iconName: "stop"
                        filled: true
                        iconColor: Appearance.colors.colError
                        onClicked: root.stopRecording()
                        tooltip: Translation.tr("Stop recording")
                    }

                    OsdSeparator { isVertical: true; visible: !root.collapsed }

                    OsdPillButton {
                        visible: !root.collapsed
                        iconName: Audio.sink?.audio?.muted ? "volume_off" : "volume_up"
                        dimmed: Audio.sink?.audio?.muted ?? false
                        onClicked: Audio.toggleMute()
                        tooltip: Audio.sink?.audio?.muted
                            ? Translation.tr("Unmute audio") : Translation.tr("Mute audio")
                    }
                    OsdPillButton {
                        visible: !root.collapsed
                        iconName: Audio.micMuted ? "mic_off" : "mic"
                        dimmed: Audio.micMuted
                        onClicked: Audio.toggleMicMute()
                        tooltip: Audio.micMuted
                            ? Translation.tr("Unmute mic") : Translation.tr("Mute mic")
                    }

                    OsdPillButton {
                        iconName: root.collapsed ? "open_in_full" : "close_fullscreen"
                        onClicked: root.collapsed = !root.collapsed
                        tooltip: root.collapsed
                            ? Translation.tr("Expand controls") : Translation.tr("Minimize")
                    }
                }
            }
        }
    }

    // Drag handle with hover feedback
    component OsdDragHandle: Item {
        id: dragHandle
        required property bool isVertical

        Layout.preferredWidth: 24
        Layout.preferredHeight: 24
        Layout.alignment: Qt.AlignCenter

        opacity: dragHover.hovered || dragHandler.active ? 0.8 : 0.4

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.full
            color: dragHandler.active
                ? (Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
                    : Appearance.colors.colLayer2Active ?? Appearance.colors.colLayer1Active)
                : dragHover.hovered
                    ? (Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                        : Appearance.colors.colLayer2Hover ?? Appearance.colors.colLayer1Hover)
                    : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: "drag_indicator"
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colOnLayer2
        }

        HoverHandler {
            id: dragHover
            cursorShape: dragHandler.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        }

        DragHandler {
            id: dragHandler
            target: pill
            xAxis.minimum: 0
            xAxis.maximum: osdLoader.item ? osdLoader.item.width - pill.width : 0
            yAxis.minimum: 0
            yAxis.maximum: osdLoader.item ? osdLoader.item.height - pill.height : 0
            onActiveChanged: {
                if (active) pill.animatePosition = false
                else if (osdLoader.item) osdLoader.item.snapToNearestEdge()
            }
        }
    }

    component OsdSeparator: Rectangle {
        required property bool isVertical

        Layout.preferredWidth: isVertical ? 22 : 1
        Layout.preferredHeight: isVertical ? 1 : 22
        Layout.alignment: Qt.AlignCenter
        color: Appearance.colors.colOutlineVariant
        opacity: 0.3
    }

    // Recording dot + timer
    component RecordingIndicator: Item {
        id: indicator
        required property bool isVertical

        readonly property string timeString: root.formatTime(RecorderStatus.elapsedSeconds)
        readonly property var timeParts: timeString.split(/([:])/)

        Layout.alignment: Qt.AlignCenter
        implicitWidth: isVertical ? verticalIndicator.implicitWidth : horizontalIndicator.implicitWidth
        implicitHeight: isVertical ? verticalIndicator.implicitHeight : horizontalIndicator.implicitHeight

        RowLayout {
            id: horizontalIndicator
            visible: !indicator.isVertical
            spacing: 4
            anchors.centerIn: parent

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: 8; height: 8; radius: 4
                color: Appearance.colors.colError
                SequentialAnimation on opacity {
                    running: osdLoader.active
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 800; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                }
            }

            Item {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: hTimerMetrics.width
                implicitHeight: hTimerText.implicitHeight

                TextMetrics {
                    id: hTimerMetrics
                    text: RecorderStatus.elapsedSeconds >= 3600 ? "00:00:00" : "00:00"
                    font: hTimerText.font
                }

                Text {
                    id: hTimerText
                    anchors.centerIn: parent
                    text: indicator.timeString
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer2
                }
            }
        }

        ColumnLayout {
            id: verticalIndicator
            visible: indicator.isVertical
            spacing: 1
            anchors.centerIn: parent

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 8; height: 8; radius: 4
                color: Appearance.colors.colError
                SequentialAnimation on opacity {
                    running: osdLoader.active
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 800; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                }
            }

            Repeater {
                model: indicator.timeParts

                Text {
                    required property string modelData
                    Layout.alignment: Qt.AlignHCenter
                    text: modelData === ":" ? "\u00B7\u00B7" : modelData
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: modelData === ":" ? Appearance.font.pixelSize.smaller : Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer2
                    opacity: modelData === ":" ? 0.5 : 1.0
                }
            }
        }
    }

    // Icon button with hover reveal
    component OsdPillButton: RippleButton {
        id: btn
        required property string iconName
        property string tooltip: ""
        property bool dimmed: false
        property bool filled: false
        property color iconColor: Appearance.colors.colOnLayer2

        Layout.preferredWidth: 30
        Layout.preferredHeight: 30
        Layout.alignment: Qt.AlignCenter
        buttonRadius: Appearance.rounding.full
        colBackground: "transparent"
        colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
            : Appearance.colors.colLayer2Hover ?? Appearance.colors.colLayer1Hover
        colRipple: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
            : Appearance.colors.colLayer2Active ?? Appearance.colors.colLayer1Active

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            text: btn.iconName
            iconSize: Appearance.font.pixelSize.larger
            fill: btn.filled ? 1 : 0
            color: btn.iconColor
            opacity: btn.dimmed ? 0.4 : 1.0
        }

        StyledToolTip {
            text: btn.tooltip
            visible: btn.tooltip && btn.buttonHovered
        }
    }

    IpcHandler {
        target: "recordingOsd"

        function toggle(): void {
            if (RecorderStatus.isRecording)
                root.stopRecording()
        }

        function show(): void {
            root.collapsed = false
            root.revealed = true
        }

        function hide(): void {
            root.collapsed = true
            if (root.autoHide)
                root.revealed = false
        }
    }
}
