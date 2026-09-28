pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common.widgets
import qs.modules.iris.components
import qs.modules.iris.style

MouseArea {
    id: root

    property var entry: ({})
    property bool tinted: true
    property bool last: true

    width: parent ? parent.width : 0
    height: Math.round(46 * IrisStyle.density)
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    Accessible.role: Accessible.Button
    Accessible.name: root.entry.label ?? ""
    onClicked: root.entry.action()

    Rectangle {
        anchors.fill: parent
        anchors.margins: 3 * IrisStyle.density
        radius: IrisStyle.radiusRow
        color: root.containsMouse ? IrisStyle.fillQuiet : "transparent"
        Behavior on color {
            enabled: IrisStyle.motionEnabled
            ColorAnimation { duration: IrisStyle.duration(110) }
        }
    }
    IrisSquircle {
        id: mark
        visible: root.tinted
        anchors.left: parent.left
        anchors.leftMargin: 14 * IrisStyle.density
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(26 * IrisStyle.density)
        height: width
        tint: root.entry.tint ?? IrisStyle.identity.gray
        glyph: root.entry.icon ?? "chevron_right"
    }
    MaterialSymbol {
        id: glyph
        visible: !root.tinted
        anchors.left: parent.left
        anchors.leftMargin: 18 * IrisStyle.density
        anchors.verticalCenter: parent.verticalCenter
        text: root.entry.icon ?? "chevron_right"
        iconSize: Math.round(18 * IrisStyle.density)
        color: IrisStyle.subtext
    }
    IrisText {
        id: label
        anchors.left: mark.visible ? mark.right : glyph.right
        anchors.leftMargin: 12 * IrisStyle.density
        anchors.right: value.visible ? value.left : chevron.left
        anchors.rightMargin: value.visible ? 8 * IrisStyle.density : 0
        anchors.verticalCenter: parent.verticalCenter
        text: root.entry.label ?? ""
        font.pixelSize: IrisStyle.typeLabel
        elide: Text.ElideRight
    }
    IrisText {
        id: value
        visible: (root.entry.value ?? "").length > 0
        anchors.right: chevron.left
        anchors.rightMargin: 8 * IrisStyle.density
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        text: root.entry.value ?? ""
        color: IrisStyle.muted
        font.pixelSize: IrisStyle.typeLabel
        elide: Text.ElideRight
    }
    MaterialSymbol {
        id: chevron
        anchors.right: parent.right
        anchors.rightMargin: 12 * IrisStyle.density
        anchors.verticalCenter: parent.verticalCenter
        text: "chevron_right"
        iconSize: Math.round(18 * IrisStyle.density)
        color: IrisStyle.textTertiary
    }
    Rectangle {
        anchors.left: label.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        visible: !root.last
        color: IrisStyle.hairline
    }
}
