import QtQuick
import qs.modules.iris.style

// A panel opens on its name: a mono caption, the name wide and in lower case, and its kanji faint at the right
// (decoration, never information: the name says it in the person's language).
Item {
    id: root
    property string caption
    property string title
    property string kanji
    implicitHeight: column.implicitHeight
    Column {
        id: column
        width: parent.width
        spacing: Math.round(2 * Airisu.d)
        AText { voice: "mono"; text: root.caption; color: Airisu.quiet }
        AText { voice: "wide"; size: IrisStyle.typeDisplay + Math.round(4 * IrisStyle.typeScale); text: root.title; font.capitalization: Font.AllLowercase }
    }
    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        text: root.kanji
        font.pixelSize: IrisStyle.typeTitleLarge
        font.weight: Font.Black
        color: Airisu.quiet
        opacity: 0.5 // iris-literal: the kanji is a watermark
        renderType: Text.NativeRendering
    }
}
