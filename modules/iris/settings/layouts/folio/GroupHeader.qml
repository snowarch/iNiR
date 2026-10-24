import QtQuick
import qs.modules.iris.style
import qs.modules.iris.components

// Folio's group head: its name in spaced mono capitals (the one being read in full ink), a hairline to the edge.
Item {
    id: root
    property Item host
    readonly property real d: IrisStyle.settingsDensity
    readonly property bool lone: root.host?.lone ?? false
    readonly property real line: Math.max(Math.round(22 * root.d), root.lone ? Number(root.host?.switchHeight ?? 0) : 0)
    implicitHeight: root.line

    IrisText {
        id: name
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, parent.width - x - (root.lone ? Math.round(64 * root.d) : 0))
        elide: Text.ElideRight
        text: String(root.host?.title ?? "")
        color: (root.host?.reading ?? false) ? IrisStyle.text : IrisStyle.textTertiary
        Behavior on color { ColorAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
        font.family: IrisStyle.fontMono
        font.pixelSize: Math.max(10, IrisStyle.typeCaption)
        font.weight: Font.Medium
        font.capitalization: Font.AllUppercase
        font.letterSpacing: Math.round(Math.max(10, IrisStyle.typeCaption) * 0.08)
    }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: name.x + name.width + Math.round(12 * root.d)
        width: Math.max(0, parent.width - x - (root.lone ? Math.round(64 * root.d) : 0))
        height: 1
        color: IrisStyle.hairline
    }
}
