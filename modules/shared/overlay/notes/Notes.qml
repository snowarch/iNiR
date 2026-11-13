import QtQuick
import qs.services
import qs.modules.common
import qs.modules.shared.overlay

StyledOverlayWidget {
    id: root
    fact: notes.saveState === "saving" ? Translation.tr("Saving...")
        : notes.saveState === "saved" ? Translation.tr("Saved")
        : notes.saveState === "failed" ? Translation.tr("Couldn't save") : ""
    factColor: notes.saveState === "failed" ? OverlayLook.colError : OverlayLook.colFaint

    contentItem: NotesContent {
        id: notes
        anchors.fill: parent
    }
}
