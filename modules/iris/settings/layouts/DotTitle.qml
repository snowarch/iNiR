import QtQuick
import qs.modules.iris.style
import qs.modules.iris.components

// An area's name in the figure voice (Archivo SemiExpanded, caps).
Item {
    id: root
    property string text: ""
    property real size: 40
    property real fit: 0
    // How small a fitted name may get before it is cut.
    property real least: 22
    property color color: IrisStyle.text
    implicitWidth: typed.implicitWidth
    implicitHeight: typed.implicitHeight
    width: root.fit > 0 ? Math.min(root.implicitWidth, root.fit) : root.implicitWidth
    height: root.implicitHeight
    IrisText {
        id: typed
        width: root.fit > 0 ? root.fit : implicitWidth
        text: root.text.toUpperCase()
        color: root.color
        elide: Text.ElideRight
        fontSizeMode: root.fit > 0 ? Text.HorizontalFit : Text.FixedSize
        minimumPixelSize: root.least
        font.family: IrisStyle.fontDot
        font.pixelSize: root.size
        font.weight: Font.Bold
    }
}
