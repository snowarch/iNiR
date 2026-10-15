pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    readonly property bool editorial: Appearance.editorialEverywhere

    required property int index
    required property var modelData
    property real minimumValue: -12
    property real maximumValue: 12
    property real _localValue: 0

    signal valueCommitted(int bandIndex, real value)

    readonly property real normalizedValue: Math.max(0, Math.min(1,
        (root._localValue - root.minimumValue) / (root.maximumValue - root.minimumValue)))
    readonly property real zeroNormalized: (0 - root.minimumValue) / (root.maximumValue - root.minimumValue)
    readonly property real handleCenterY: trackWell.y + 8 + (1 - root.normalizedValue) * (trackWell.height - 16)
    readonly property real zeroY: trackWell.y + 8 + (1 - root.zeroNormalized) * (trackWell.height - 16)
    readonly property color accentColor: Appearance.regaliaEverywhere ? Appearance.regalia.hardwarePrimary
        : Appearance.zzzEverywhere ? Appearance.zzz.accent
        : editorial ? Appearance.editorial.accent
        : Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary
        : Appearance.colors.colPrimary
    readonly property color trackColor: editorial ? Appearance.editorial.field
        : Appearance.angelEverywhere ? Appearance.angel.colGlassElevated
        : Appearance.inirEverywhere ? Appearance.inir.colLayer3
        : Appearance.colors.colSurfaceContainerHighest
    readonly property color quietText: Appearance.zzzEverywhere ? Appearance.zzz.inkMuted
        : editorial ? Appearance.editorial.muted
        : Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
        : Appearance.colors.colSubtext
    implicitWidth: 44
    implicitHeight: 214

    function syncFromModel(): void {
        if (!dragArea.pressed)
            root._localValue = Number(root.modelData?.gain ?? 0)
    }

    function updateFromPointer(y: real): void {
        const usableHeight = Math.max(1, trackWell.height - 16)
        const normalized = 1 - Math.max(0, Math.min(usableHeight, y)) / usableHeight
        const raw = root.minimumValue + normalized * (root.maximumValue - root.minimumValue)
        root._localValue = Math.round(raw * 10) / 10
    }

    Component.onCompleted: root.syncFromModel()
    onModelDataChanged: root.syncFromModel()
    Rectangle {
        id: valueBadge
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: Math.max(34, valueText.implicitWidth + 12)
        height: 23
        radius: root.editorial ? Appearance.rounding.small : Appearance.rounding.full
        color: dragArea.pressed || dragArea.containsMouse
            ? (Appearance.zzzEverywhere ? Appearance.zzz.paperAlt
                : root.editorial ? Appearance.editorial.layer(2)
                : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                : Appearance.colors.colSecondaryContainer)
            : "transparent"

        Behavior on color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }

        StyledText {
            id: valueText
            anchors.centerIn: parent
            text: root._localValue > 0 ? `+${root._localValue.toFixed(1)}` : root._localValue.toFixed(1)
            font.family: Appearance.font.family.numbers
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Math.abs(root._localValue) > 0.05 ? Font.DemiBold : Font.Medium
            color: dragArea.pressed || dragArea.containsMouse || Math.abs(root._localValue) > 0.05
                ? root.accentColor : root.quietText
        }
    }

    Rectangle {
        id: trackWell
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 31
        width: 14
        height: 142
        radius: Appearance.rounding.full
        color: "transparent"

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 5
            radius: 2
            color: Appearance.zzzEverywhere ? Appearance.zzz.metricTrack
                : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface
                : root.trackColor
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.min(root.handleCenterY - trackWell.y, root.zeroY - trackWell.y)
            width: 5
            height: Math.max(3, Math.abs(root.handleCenterY - root.zeroY))
            radius: Appearance.rounding.full
            color: root.accentColor
            opacity: Math.abs(root._localValue) < 0.05 ? 0 : 1

            Behavior on opacity { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.zeroY - trackWell.y - height / 2
            width: 10
            height: 2
            radius: 1
            color: root.quietText
            opacity: 0.48
        }
    }

    Rectangle {
        id: handle
        anchors.horizontalCenter: trackWell.horizontalCenter
        y: root.handleCenterY - height / 2
        width: dragArea.pressed ? 24 : (dragArea.containsMouse ? 22 : 20)
        height: dragArea.pressed ? 8 : (dragArea.containsMouse ? 7 : 6)
        radius: height / 2
        color: root.accentColor
        border.width: 0
        z: 3

        Behavior on width { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }
        Behavior on height { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }
        Behavior on color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }
        Behavior on y {
            enabled: Appearance.animationsEnabled && !dragArea.pressed
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }
    }

    MouseArea {
        id: dragArea
        x: 0
        y: trackWell.y
        width: parent.width
        height: trackWell.height
        hoverEnabled: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        onPressed: mouse => root.updateFromPointer(mouse.y - 8)
        onPositionChanged: mouse => {
            if (pressed) root.updateFromPointer(mouse.y - 8)
        }
        onReleased: root.valueCommitted(root.index, root._localValue)
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: trackWell.bottom
        anchors.topMargin: 12
        text: {
            const frequency = Number(root.modelData?.frequency ?? 0)
            if (frequency >= 1000)
                return Number.isInteger(frequency / 1000)
                    ? `${frequency / 1000}k`
                    : `${(frequency / 1000).toFixed(1)}k`
            return String(Math.round(frequency))
        }
        font.family: Appearance.font.family.numbers
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: root.quietText
    }
}
