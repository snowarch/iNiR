import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// The last row of a group: its fine-tuning waits behind it and the row names what it holds.
MouseArea {
    id: tune
    property bool open: false
    property var names: []
    readonly property real d: IrisStyle.settingsDensity
    implicitHeight: Math.round((tune.open ? 44 : 54) * tune.d)
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    Accessible.role: Accessible.Button
    Accessible.name: tune.open ? Translation.tr("Fewer settings") : Translation.tr("Fine-tune")
    Accessible.description: tune.names.join(", ")
    IrisCutPlate {
        anchors.fill: plate
        visible: IrisStyle.fieldChamfer
        cutLength: IrisStyle.nestedCut(IrisStyle.chamferCut, plate.anchors.margins)
        color: plate.color
    }
    Rectangle {
        id: plate
        anchors.fill: parent
        anchors.margins: Math.round(4 * tune.d)
        visible: !IrisStyle.fieldChamfer
        radius: IrisStyle.concentric(IrisStyle.radiusTile, plate.anchors.margins, IrisStyle.radiusRow)
        color: tune.pressed ? IrisStyle.fillActive : tune.containsMouse ? IrisStyle.fillQuiet : "transparent"
        Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
    }
    Column {
        anchors.left: parent.left
        anchors.leftMargin: Math.round(16 * tune.d)
        anchors.right: chevron.left
        anchors.rightMargin: Math.round(12 * tune.d)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(2 * tune.d)
        IrisText {
            width: parent.width
            text: tune.open ? Translation.tr("Fewer settings") : Translation.tr("Fine-tune")
            color: tune.containsMouse ? IrisStyle.text : IrisStyle.textSecondary
            font.pixelSize: IrisStyle.typeLabel
            font.weight: IrisStyle.weight(Font.Medium)
            elide: Text.ElideRight
        }
        IrisText {
            width: parent.width
            visible: !tune.open
            text: tune.names.join(", ")
            color: IrisStyle.textTertiary
            font.pixelSize: IrisStyle.typeFootnote
            elide: Text.ElideRight
        }
    }
    MaterialSymbol {
        id: chevron
        anchors.right: parent.right
        anchors.rightMargin: Math.round(16 * tune.d)
        anchors.verticalCenter: parent.verticalCenter
        text: "expand_more"
        iconSize: Math.round(18 * tune.d)
        color: tune.containsMouse ? IrisStyle.text : IrisStyle.textTertiary
        rotation: tune.open ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
    }
}
