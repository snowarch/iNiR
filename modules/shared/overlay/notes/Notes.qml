import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.shared.overlay

StyledOverlayWidget {
    id: root
    title: Translation.tr("Notes")
    showCenterButton: true

    contentItem: NotesContent {
        radius: root.contentRadius
        isClickthrough: root.clickthrough
    }
}
