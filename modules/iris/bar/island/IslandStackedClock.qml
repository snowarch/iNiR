pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.iris.style
import qs.modules.iris.components

Column {
    id: root

    property real pixelSize: IrisStyle.typeBody
    property color color: IrisStyle.text
    property color accent: IrisStyle.secondaryAccent
    property bool showDay: false

    readonly property var parts: {
        const raw = String(DateTime.timeDisplay ?? "").trim()
        const period = raw.match(/\s*([^\d:.\s]+)$/)
        const pieces = (period ? raw.slice(0, period.index) : raw).split(/[:.]/)
        const hours = String(pieces[0] ?? "")
        return { hours: hours.length === 1 ? "0" + hours : hours, minutes: String(pieces[1] ?? "") }
    }

    spacing: Math.round(-root.pixelSize * 0.12)

    IrisText {
        visible: root.showDay
        anchors.horizontalCenter: parent.horizontalCenter
        bottomPadding: Math.round(root.pixelSize * 0.3)
        text: Qt.locale().toString(DateTime.clock.date, "d")
        color: root.accent
        font.pixelSize: Math.round(root.pixelSize * 0.8)
        font.family: IrisStyle.fontNumbers
        font.weight: IrisStyle.weight(Font.Bold)
        font.features: ({ "tnum": 1 })
    }
    IrisNumber {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.parts.hours
        family: IrisStyle.fontNumbers
        pixelSize: root.pixelSize
        weight: IrisStyle.figureWeight
        color: root.color
    }
    IrisNumber {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.parts.minutes
        family: IrisStyle.fontNumbers
        pixelSize: root.pixelSize
        weight: IrisStyle.figureWeight
        color: root.color
    }
}
