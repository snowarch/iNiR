pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// The line a scene ends on. It sits directly in its PreviewScene, and its text also titles the Settings hero that
// shows the preview in compact form.
Rectangle {
    id: caption
    property string text: ""
    property string glyph: "info"
    readonly property Item preview: caption.parent?.preview ?? null
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    anchors.margins: Math.round(14 * IrisStyle.density)
    implicitWidth: captionRow.implicitWidth + Math.round(22 * IrisStyle.density)
    implicitHeight: Math.round(28 * IrisStyle.density)
    radius: IrisStyle.capsule(height)
    // A plate Design (AIRISU) labels the scene as a part: a die-cut tag, the words in mono capitals.
    readonly property bool tagged: IrisStyle.plateSelection
    color: caption.tagged ? "transparent" : IrisStyle.veilHeavy
    IrisCutPlate { anchors.fill: parent; visible: caption.tagged; color: IrisStyle.veilHeavy; cutLength: Math.round(caption.height / 3) }
    visible: caption.text.length > 0 && !(caption.preview?.compact ?? false)
    Binding { target: caption.preview; property: "caption"; value: caption.text }
    RowLayout {
        id: captionRow
        anchors.centerIn: parent
        spacing: Math.round(6 * IrisStyle.density)
        MaterialSymbol { text: caption.glyph; iconSize: Math.round(14 * IrisStyle.density); color: IrisStyle.subtext }
        IrisText {
            text: caption.text
            font.pixelSize: caption.tagged ? IrisStyle.typeFootnote : IrisStyle.typeMeta
            font.family: caption.tagged ? IrisStyle.fontMono : IrisStyle.fontMain
            font.capitalization: caption.tagged ? Font.AllUppercase : Font.MixedCase
            font.letterSpacing: caption.tagged ? Math.round(IrisStyle.typeFootnote * 0.12) : 0
            color: IrisStyle.text
        }
    }
}
