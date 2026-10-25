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
    // As many names as fit, then how many more: a list cut off mid-word named nothing.
    FontMetrics { id: summaryType; font: summary.font }
    function say(room: real): string {
        const all = tune.names
        const whole = all.join(", ")
        if (all.length < 2 || summaryType.advanceWidth(whole) <= room) return whole
        for (let n = all.length - 1; n >= 1; n--) {
            const text = Translation.tr("%1 and %2").arg(all.slice(0, n).join(", ")).arg(Translation.tr("%1 more").arg(all.length - n))
            if (summaryType.advanceWidth(text) <= room) return text
        }
        return Translation.tr("%1 and %2").arg(all[0]).arg(Translation.tr("%1 more").arg(all.length - 1))
    }
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
            id: summary
            width: parent.width
            visible: !tune.open
            text: tune.say(summary.width)
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
