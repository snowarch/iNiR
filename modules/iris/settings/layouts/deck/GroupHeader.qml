import QtQuick
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// Deck's fold: the group's mark and name, what it holds in a line (its note in red when it has one) and a chevron; a
// click or ⏎ opens or folds it.
MouseArea {
    id: root
    property Item host
    readonly property real d: IrisStyle.settingsDensity
    readonly property bool open: root.host?.open ?? true
    readonly property bool noted: (root.host?.notes?.length ?? 0) > 0
    implicitHeight: Math.round(50 * root.d)
    enabled: root.host?.folds ?? false
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.host.toggle()
    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -Math.round(10 * root.d)
        anchors.rightMargin: -Math.round(10 * root.d)
        radius: IrisStyle.radiusTile
        color: root.noted ? Qt.rgba(IrisStyle.danger.r, IrisStyle.danger.g, IrisStyle.danger.b, root.containsMouse ? 0.2 : 0.13)
            : root.containsMouse ? IrisStyle.fillHover : IrisStyle.fillQuiet
    }
    MaterialSymbol {
        id: mark
        anchors.verticalCenter: parent.verticalCenter
        text: root.noted ? "error" : String(root.host?.glyph ?? "")
        iconSize: Math.round(20 * root.d)
        color: root.noted ? IrisStyle.danger : IrisStyle.subtext
    }
    IrisText {
        id: name
        anchors.verticalCenter: parent.verticalCenter
        x: mark.width + Math.round(12 * root.d)
        text: String(root.host?.title ?? "")
        color: IrisStyle.text
        font.family: IrisStyle.fontTitle
        font.pixelSize: IrisStyle.typeBody
        font.weight: Font.DemiBold
    }
    IrisText {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: chevron.left
        anchors.rightMargin: Math.round(10 * root.d)
        width: Math.min(implicitWidth, parent.width - name.x - name.width - chevron.width - Math.round(40 * root.d))
        elide: Text.ElideRight
        text: root.noted ? String(root.host.notes[0].text ?? "") : String(root.host?.summary ?? "")
        color: root.noted ? IrisStyle.text : IrisStyle.muted
        font.pixelSize: IrisStyle.typeMeta
    }
    MaterialSymbol {
        id: chevron
        visible: root.enabled
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: "expand_more"
        iconSize: Math.round(20 * root.d)
        color: IrisStyle.subtext
        rotation: root.open ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
    }
}
