import QtQuick
import qs.modules.iris.style

// The battery as iRiS draws it everywhere (bubbles, notices, the lock): a rounded body, its terminal, and the charge
// inside it in the state's colour. Every measure comes from the height in whole pixels, so the outline and the gap
// around the charge stay crisp at any size.
Item {
    id: root

    property real level: 0
    property color tint: IrisStyle.text
    property color frame: IrisStyle.textTertiary
    property int markHeight: Math.round(10 * IrisStyle.density)

    readonly property int line: Math.max(1, Math.round(root.markHeight / 10))
    readonly property int inset: root.line * 2
    readonly property int terminal: Math.max(2, Math.round(root.markHeight / 5))

    implicitHeight: root.markHeight
    implicitWidth: Math.round(root.markHeight * 2.1)

    Rectangle {
        id: body
        width: root.width - root.terminal - root.line
        height: root.height
        radius: Math.round(root.height * 0.3)
        color: "transparent"
        border.width: root.line
        border.color: root.frame
        Rectangle {
            readonly property int room: body.width - 2 * root.inset
            x: root.inset
            y: root.inset
            height: body.height - 2 * root.inset
            // Down to 1 % a sliver two lines wide stays visible; it never stands for more charge than there is.
            width: root.level <= 0 ? 0 : Math.max(2 * root.line, Math.round(room * Math.min(1, root.level)))
            radius: Math.max(1, body.radius - root.inset)
            color: root.tint
        }
    }
    Rectangle {
        x: body.width + root.line
        anchors.verticalCenter: body.verticalCenter
        width: root.terminal
        height: Math.round(root.height * 0.4)
        radius: IrisStyle.capsule(width)
        color: root.frame
    }
}
