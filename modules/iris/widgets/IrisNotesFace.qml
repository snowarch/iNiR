pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style

IrisWidgetFace {
    id: root
    designFace: IrisDesign.skin("widgetNotes")

    // Nothing written and nobody writing: the page says what it is for instead of one grey line on an empty card.
    readonly property bool blank: String(root.widget.noteText ?? "").length === 0 && !root.widget.editing
    readonly property color pencil: root.inked(IrisStyle.identity.yellow)
    readonly property int words: String(root.widget.noteText ?? "").trim().split(/\s+/).filter(word => word.length > 0).length

    FaceHeader {
        face: root
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.dp(20)
        glyph: "edit_note"
        text: Translation.tr("Notes")
        tint: root.inked(IrisStyle.identity.yellow)
        trailing: root.words > 0 && !root.small ? Translation.tr("%1 words").arg(root.words) : ""
    }

    FaceBlank {
        face: root
        visible: root.blank
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.dp(10)
        width: parent.width
        glyph: "edit"
        glyphFill: true
        tint: root.pencil
        title: Translation.tr("Write something")
        detail: Translation.tr("Click anywhere on the page to start")
    }
}
