import QtQuick
import qs.modules.iris.style
import qs.modules.iris.components

// Drawer's group head: its name in the read voice, a hairline running to the column's edge; a lone switch keeps its line.
Item {
    id: root
    property Item host
    readonly property real d: IrisStyle.settingsDensity
    readonly property bool lone: root.host?.lone ?? false
    readonly property real line: Math.max(Math.round(24 * root.d), root.lone ? Number(root.host?.switchHeight ?? 0) : 0)
    implicitHeight: root.line

    IrisText {
        id: name
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, parent.width - (root.lone ? Math.round(64 * root.d) : 0))
        elide: Text.ElideRight
        text: String(root.host?.title ?? "")
        color: root.lone ? IrisStyle.text : (root.host?.reading ?? false) ? IrisStyle.text : IrisStyle.muted
        Behavior on color { ColorAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
        font.pixelSize: root.lone ? IrisStyle.typeBody : IrisStyle.typeMeta
        font.weight: IrisStyle.weight(root.lone ? Font.Medium : Font.DemiBold)
    }
    Rectangle {
        visible: !root.lone
        anchors.verticalCenter: parent.verticalCenter
        x: name.x + name.width + Math.round(12 * root.d)
        width: Math.max(0, parent.width - x)
        height: 1
        color: IrisStyle.hairline
    }
}
