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
    height: Math.round(46 * IrisStyle.settingsDensity)
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    Accessible.role: Accessible.Button
    Accessible.name: root.entry.label ?? ""
    onClicked: root.entry.action()

    // Concentric with the card it lies in; cut like it under a chamfer.
    IrisCutPlate {
        anchors.fill: plate
        visible: IrisStyle.fieldChamfer
        cutLength: IrisStyle.nestedCut(IrisStyle.chamferCut, plate.anchors.margins)
        color: plate.color
    }
    Rectangle {
        id: plate
        anchors.fill: parent
        anchors.margins: 3 * IrisStyle.settingsDensity
        visible: !IrisStyle.fieldChamfer
        radius: IrisStyle.concentric(IrisStyle.radiusTile, plate.anchors.margins, IrisStyle.radiusRow)
        color: root.containsMouse ? IrisStyle.fillQuiet : "transparent"
        Behavior on color {
            enabled: IrisStyle.motionEnabled
            ColorAnimation { duration: IrisStyle.duration(110) }
        }
    }
    // The link's glyph in its area's colour, without a tile under it, as the sidebar marks its areas: a column of
    // coloured squares is every settings app, and the colour alone already tells the links apart.
    MaterialSymbol {
        id: mark
        anchors.left: parent.left
        anchors.leftMargin: 14 * IrisStyle.settingsDensity
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(26 * IrisStyle.settingsDensity)
        horizontalAlignment: Text.AlignHCenter
        text: root.entry.icon ?? "chevron_right"
        iconSize: Math.round(19 * IrisStyle.settingsDensity)
        color: !root.tinted || IrisStyle.plainMarks ? IrisStyle.textSecondary : (root.entry.tint ?? IrisStyle.identity.gray)
    }
    IrisText {
        id: label
        anchors.left: mark.right
        anchors.leftMargin: 12 * IrisStyle.settingsDensity
        anchors.right: value.visible ? value.left : chevron.left
        anchors.rightMargin: value.visible ? 8 * IrisStyle.settingsDensity : 0
        anchors.verticalCenter: parent.verticalCenter
        text: root.entry.label ?? ""
        font.pixelSize: IrisStyle.typeLabel
        elide: Text.ElideRight
    }
    IrisText {
        id: value
        visible: (root.entry.value ?? "").length > 0
        anchors.right: chevron.left
        anchors.rightMargin: 8 * IrisStyle.settingsDensity
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
        anchors.rightMargin: 12 * IrisStyle.settingsDensity
        anchors.verticalCenter: parent.verticalCenter
        text: "chevron_right"
        iconSize: Math.round(18 * IrisStyle.settingsDensity)
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
