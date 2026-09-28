pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

Item {
    id: wave
    property bool running: false
    property color tint: IrisStyle.text
    property real barHeight: 16 * IrisStyle.density
    readonly property int bars: 5
    implicitWidth: wave.bars * 3 * IrisStyle.density + (wave.bars - 1) * 2 * IrisStyle.density
    implicitHeight: wave.barHeight

    CavaProcess { id: cava; active: wave.running && wave.visible }
    readonly property var raw: {
        const pts = cava.points ?? []
        if (pts.length === 0) return []
        const per = pts.length / wave.bars
        const out = []
        for (let i = 0; i < wave.bars; i++) {
            const from = Math.floor(i * per)
            const to = Math.max(from + 1, Math.floor((i + 1) * per))
            let band = 0
            for (let k = from; k < to && k < pts.length; k++) band = Math.max(band, pts[k] ?? 0)
            out.push(band)
        }
        return out
    }
    readonly property var restShape: [0.45, 0.8, 0.6, 0.9, 0.5]

    Row {
        anchors.centerIn: parent
        spacing: 2 * IrisStyle.density
        Repeater {
            model: wave.bars
            Rectangle {
                required property int index
                anchors.verticalCenter: parent.verticalCenter
                width: 3 * IrisStyle.density
                radius: width / 2
                color: wave.tint
                height: {
                    const level = !wave.running ? 0
                        : wave.raw.length > 0 ? Math.min(1, (wave.raw[index] ?? 0) / Math.max(1, cava.normalizationCeiling))
                        : wave.restShape[index]
                    return Math.max(3 * IrisStyle.density, level * wave.barHeight)
                }
                Behavior on height { NumberAnimation { duration: IrisStyle.duration(90); easing.type: IrisStyle.feedbackEasing } }
            }
        }
    }
}
