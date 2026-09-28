pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.iris.style

IrisWidgetFace {
    id: root

    readonly property int words: String(root.widget.noteText ?? "").trim().split(/\s+/).filter(word => word.length > 0).length

    FaceHeader {
        face: root
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.dp(20)
        glyph: "edit_note"
        text: Translation.tr("Notes")
        tint: IrisStyle.identity.yellow
        trailing: root.words > 0 && !root.small ? Translation.tr("%1 words").arg(root.words) : ""
    }
}
