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
    radius: height / 2
    color: IrisStyle.veilHeavy
    visible: caption.text.length > 0 && !(caption.preview?.compact ?? false)
    Binding { target: caption.preview; property: "caption"; value: caption.text }
    RowLayout {
        id: captionRow
        anchors.centerIn: parent
        spacing: Math.round(6 * IrisStyle.density)
        MaterialSymbol { text: caption.glyph; iconSize: Math.round(14 * IrisStyle.density); color: IrisStyle.subtext }
        IrisText { text: caption.text; font.pixelSize: IrisStyle.typeMeta; color: IrisStyle.text }
    }
}
