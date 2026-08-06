import qs.modules.common
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property list<real> points: []
    property real maxVisualizerValue: 1000
    property int smoothing: 2
    property bool live: true
    readonly property var _cavaPalette: CavaTheme.visualizerColors
    property color colorLow: root._cavaPalette.length > 0
        ? root._cavaPalette[0] : Appearance.colors.colSecondaryContainer
    property color colorMed: root._cavaPalette.length > 0
        ? root._cavaPalette[Math.floor(root._cavaPalette.length / 2)]
        : Appearance.colors.colPrimary
    property color colorHigh: root._cavaPalette.length > 0
        ? root._cavaPalette[root._cavaPalette.length - 1]
        : Appearance.colors.colPrimary
    property int barCount: 50
    property real barSpacing: 2
    property real barMinHeight: 2
    property real barRadius: 3

    Row {
        id: barsRow
        anchors.fill: parent
        spacing: root.barSpacing

        Repeater {
            id: barsRepeater
            model: root.visible ? root.barCount : 0

            Item {
                id: barWrapper
                required property int index
                width: (root.width - (root.barCount - 1) * root.barSpacing) / root.barCount
                height: root.height

                property real barValue: {
                    if (!root.visible || !root.live || root.points.length === 0) return 0;
                    const start = Math.floor(index * root.points.length / root.barCount);
                    const end = Math.min(root.points.length,
                        Math.max(start + 1, Math.ceil((index + 1) * root.points.length / root.barCount)));
                    let sum = 0;
                    let count = 0;
                    for (let i = start; i < end; i++) {
                        sum += root.points[i] || 0;
                        count++;
                    }
                    return count > 0 ? sum / count : 0;
                }

                property real normalizedValue: Math.min(1, barValue / root.maxVisualizerValue)
                property real barHeight: Math.max(root.barMinHeight, normalizedValue * (root.height / 2 - 2))
                property string intensity: normalizedValue > 0.7 ? "high" : normalizedValue > 0.35 ? "med" : "low"
                property color barColor: intensity === "high" ? root.colorHigh 
                                       : intensity === "med" ? root.colorMed 
                                       : root.colorLow

                Column {
                    anchors.centerIn: parent
                    spacing: 1

                    // Top bar (grows upward)
                    Rectangle {
                        width: barWrapper.width
                        height: barWrapper.barHeight
                        radius: root.barRadius
                        color: barWrapper.barColor
                        opacity: 0.9

                        Behavior on height {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                        }
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: 100 }
                        }
                    }

                    // Bottom bar (grows downward, mirror)
                    Rectangle {
                        width: barWrapper.width
                        height: barWrapper.barHeight
                        radius: root.barRadius
                        color: barWrapper.barColor
                        opacity: 0.9

                        Behavior on height {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                        }
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: 100 }
                        }
                    }
                }
            }
        }
    }
}
