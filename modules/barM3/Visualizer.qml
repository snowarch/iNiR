import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.barM3
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: Config.options.bar.m3.cornerStyle === 3
    property bool spectrumMirrored: false
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool isPlaying: activePlayer?.isPlaying ?? false
    // The host bar owns one cava process and hands its spectrum to every
    // visualizer it loaded (the showcase layout uses two, mirrored). Falling
    // back to a private process keeps the widget usable standalone, but the
    // bar always supplies `sharedPoints`, so only one cava ever runs.
    property var sharedPoints: null
    property real sharedCeiling: -1
    property bool sharedSignalActive: false
    readonly property list<real> points: root.sharedPoints ?? localCava.points
    readonly property real normalizationCeiling: root.sharedCeiling > 0
        ? root.sharedCeiling : localCava.normalizationCeiling
    readonly property bool visualActive: root.sharedPoints === null
        ? localCava.audioSignalActive : root.sharedSignalActive
    property int barCount: 20

    CavaProcess {
        id: localCava
        active: root.isPlaying && root.sharedPoints === null
        sampleCount: root.barCount
    }
    property real dotSize: 3
    property real dotSpacing: 3
    property real maxBarHeight: (vertical
        ? Appearance.sizes.verticalBarWidth
        : Appearance.sizes.barHeight) * 0.7
    implicitWidth: vertical
        ? Appearance.sizes.verticalBarWidth
        : (isMaterial
            ? barsRow.implicitWidth + 16
            : barCount * (dotSize + dotSpacing))
    implicitHeight: vertical
        ? (isMaterial
            ? barsColumn.implicitHeight + 16
            : barCount * (dotSize + dotSpacing))
        : Appearance.sizes.barHeight

    transform: Scale {
        xScale: !root.vertical && root.spectrumMirrored ? -1 : 1
        origin.x: root.width / 2
    }


    Row {
        id: barsRow
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: root.dotSpacing

        Repeater {
            model: root.barCount
            Rectangle {
                required property int index
                width: root.dotSize
                property real pointValue: {
                    if (!root.visualActive || root.points.length === 0) return root.dotSize
                    const idx = Math.floor(index * root.points.length / root.barCount)
                    const v = root.points[idx] ?? 0
                    return Math.max(root.dotSize, (v / Math.max(1, root.normalizationCeiling)) * root.maxBarHeight)
                }
                height: pointValue
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: Appearance.colors.colPrimary
                opacity: root.visualActive ? 0.85 : 0
                Behavior on height { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
                Behavior on opacity { NumberAnimation { duration: 300 } }
            }
        }
    }

    Column {
        id: barsColumn
        visible: root.vertical
        anchors.centerIn: parent
        spacing: root.dotSpacing

        Repeater {
            model: root.barCount
            Rectangle {
                required property int index
                height: root.dotSize
                property real pointValue: {
                    if (!root.visualActive || root.points.length === 0) return root.dotSize
                    const rawIndex = root.spectrumMirrored ? (root.barCount - 1 - index) : index
                    const idx = Math.floor(rawIndex * root.points.length / root.barCount)
                    const v = root.points[idx] ?? 0
                    return Math.max(root.dotSize, (v / Math.max(1, root.normalizationCeiling)) * root.maxBarHeight)
                }
                width: pointValue
                radius: height / 2
                anchors.horizontalCenter: parent.horizontalCenter
                color: Appearance.colors.colPrimary
                opacity: root.visualActive ? 0.85 : 0
                Behavior on width { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
                Behavior on opacity { NumberAnimation { duration: 300 } }
            }
        }
    }
}
