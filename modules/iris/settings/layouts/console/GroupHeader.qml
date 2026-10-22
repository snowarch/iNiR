import QtQuick
import qs.services
import qs.modules.iris.style
import qs.modules.iris.components

// Console's group head: its name in spaced mono capitals over a dotted rule; a note puts a red dot before it and says
// itself at the rule's end.
Item {
    id: root
    property Item host
    readonly property real d: IrisStyle.settingsDensity
    readonly property bool noted: (root.host?.notes?.length ?? 0) > 0
    implicitHeight: Math.round(30 * root.d)
    Rectangle {
        id: dot
        visible: root.noted
        anchors.verticalCenter: name.verticalCenter
        width: Math.round(7 * root.d)
        height: width
        radius: width / 2
        color: IrisStyle.danger
    }
    IrisText {
        id: name
        x: root.noted ? dot.width + Math.round(8 * root.d) : 0
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(6 * root.d)
        text: String(root.host?.title ?? "")
        color: IrisStyle.subtext
        font.family: IrisStyle.fontMono
        font.pixelSize: IrisStyle.typeCaption
        font.weight: Font.Medium
        font.capitalization: Font.AllUppercase
        font.letterSpacing: Math.round(IrisStyle.typeCaption * 0.16)
    }
    Canvas {
        id: rule
        x: name.x + name.width + Math.round(12 * root.d)
        width: parent.width - x - (note.visible ? note.width + Math.round(12 * root.d) : 0)
        height: 2
        anchors.verticalCenter: name.verticalCenter
        readonly property color ink: Qt.rgba(IrisStyle.text.r, IrisStyle.text.g, IrisStyle.text.b, 0.22)
        onWidthChanged: requestPaint()
        onInkChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = rule.ink
            for (let x = 0; x < width; x += 4) ctx.fillRect(x, 0, 1, 1)
        }
    }
    IrisText {
        id: note
        visible: root.noted
        anchors.right: parent.right
        anchors.verticalCenter: name.verticalCenter
        width: Math.min(implicitWidth, root.width * 0.55)
        elide: Text.ElideRight
        text: root.noted ? String(root.host.notes[0].text ?? "") : ""
        color: IrisStyle.danger
        font.family: IrisStyle.fontMono
        font.pixelSize: IrisStyle.typeCaption
        font.letterSpacing: Math.round(IrisStyle.typeCaption * 0.06)
    }
}
