import QtQuick
import qs.services
import qs.modules.iris.style
import qs.modules.iris.components

// Deck's switch: a lamp and its word on a sunk key. On, the lamp is lit in the accent inside a soft ring; off, a hollow
// ring and a quieter word.
Item {
    id: root
    property Item host
    readonly property bool on: root.host?.on ?? false
    readonly property real d: IrisStyle.settingsDensity
    readonly property real wantWidth: 78
    readonly property real wantHeight: 34
    Rectangle {
        anchors.fill: parent
        radius: IrisStyle.radiusRow
        color: (root.host?.hovered ?? false) ? IrisStyle.fillHover : Qt.rgba(0, 0, 0, IrisStyle.light ? 0.06 : 0.26) // iris-literal: a key sunk into the card
        border.width: 1
        border.color: IrisStyle.hairline
    }
    Rectangle {
        id: lamp
        x: Math.round(14 * root.d)
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(12 * root.d)
        height: width
        radius: width / 2
        color: root.on ? IrisStyle.accent : "transparent"
        border.width: root.on ? 0 : Math.max(1, Math.round(2 * root.d))
        border.color: IrisStyle.muted
        Behavior on color { ColorAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
        Rectangle {
            visible: root.on
            anchors.centerIn: parent
            width: parent.width + Math.round(6 * root.d)
            height: width
            radius: width / 2
            color: "transparent"
            border.width: Math.round(3 * root.d)
            border.color: Qt.rgba(IrisStyle.accent.r, IrisStyle.accent.g, IrisStyle.accent.b, 0.24)
        }
    }
    IrisText {
        anchors.verticalCenter: parent.verticalCenter
        x: lamp.x + lamp.width + Math.round(10 * root.d)
        text: root.on ? Translation.tr("On") : Translation.tr("Off")
        color: root.on ? IrisStyle.text : IrisStyle.muted
        font.pixelSize: IrisStyle.typeLabel
        font.weight: root.on ? Font.Bold : Font.DemiBold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: Math.round(IrisStyle.typeLabel * 0.06)
    }
}
