import QtQuick
import qs.modules.iris.style
import qs.modules.iris.components

// Folio's group head: the group's number in the accent, its name in spaced mono capitals, a hairline to the edge.
Item {
    id: root
    property Item host
    readonly property real d: IrisStyle.settingsDensity
    readonly property bool lone: root.host?.lone ?? false
    readonly property real line: Math.max(Math.round(22 * root.d), root.lone ? Number(root.host?.switchHeight ?? 0) : 0)
    implicitHeight: root.line

    IrisText {
        id: number
        anchors.verticalCenter: parent.verticalCenter
        text: String(Number(root.host?.folio ?? 0) + 1).padStart(2, "0")
        color: IrisStyle.accent
        font.family: IrisStyle.fontMono
        font.pixelSize: IrisStyle.typeFootnote
        font.weight: Font.DemiBold
        font.letterSpacing: Math.round(IrisStyle.typeFootnote * 0.1)
    }
    IrisText {
        id: name
        anchors.verticalCenter: parent.verticalCenter
        x: number.width + Math.round(12 * root.d)
        width: Math.min(implicitWidth, parent.width - x - (root.lone ? Math.round(64 * root.d) : 0))
        elide: Text.ElideRight
        text: String(root.host?.title ?? "")
        color: (root.host?.reading ?? false) ? IrisStyle.text : IrisStyle.subtext
        font.family: IrisStyle.fontMono
        font.pixelSize: IrisStyle.typeFootnote
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: Math.round(IrisStyle.typeFootnote * 0.2)
    }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: name.x + name.width + Math.round(12 * root.d)
        width: Math.max(0, parent.width - x - (root.lone ? Math.round(64 * root.d) : 0))
        height: 1
        color: IrisStyle.hairline
    }
}
