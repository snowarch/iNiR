import QtQuick
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.settings.layouts.console as Skins

// An area's name in the Dot voice: Geist Pixel when it is installed, the drawn 5x7 dot type when it is not.
Item {
    id: root
    property string text: ""
    property real size: 40
    property real fit: 0
    property color color: IrisStyle.text
    readonly property string face: String(IrisStyle["fontDot"] ?? "")
    readonly property bool typed: root.face.length > 0 && Qt.fontFamilies().includes(root.face)
    implicitWidth: root.typed ? typed.implicitWidth : drawn.implicitWidth
    implicitHeight: root.typed ? typed.implicitHeight : drawn.implicitHeight
    width: root.fit > 0 ? Math.min(root.implicitWidth, root.fit) : root.implicitWidth
    height: root.implicitHeight
    IrisText {
        id: typed
        visible: root.typed
        width: root.fit > 0 ? root.fit : implicitWidth
        text: root.text.toUpperCase()
        color: root.color
        elide: Text.ElideRight
        fontSizeMode: root.fit > 0 ? Text.HorizontalFit : Text.FixedSize
        minimumPixelSize: 22
        font.family: root.face
        font.pixelSize: root.size
    }
    Skins.DotMatrix {
        id: drawn
        visible: !root.typed
        text: root.text
        color: root.color
        offColor: "transparent"
        pitch: Math.max(3, Math.round(root.size / 7.5))
        fit: root.fit
    }
}
