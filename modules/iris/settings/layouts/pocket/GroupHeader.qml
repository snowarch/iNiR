import QtQuick
import qs.modules.iris.style
import qs.modules.iris.components

// Pocket's group head: the group's name a step down over its card, as a phone's settings name a list; a lone switch
// keeps its line.
Item {
    id: root
    property Item host
    readonly property real d: IrisStyle.settingsDensity
    readonly property bool lone: root.host?.lone ?? false
    readonly property real line: Math.max(Math.round(20 * root.d), root.lone ? Number(root.host?.switchHeight ?? 0) : 0)
    implicitHeight: root.line

    IrisText {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - (root.lone ? Math.round(64 * root.d) : 0)
        elide: Text.ElideRight
        text: String(root.host?.title ?? "")
        color: root.lone ? IrisStyle.text : IrisStyle.muted
        font.pixelSize: root.lone ? IrisStyle.typeBody : IrisStyle.typeMeta
        font.weight: IrisStyle.weight(root.lone ? Font.Medium : Font.DemiBold)
    }
}
