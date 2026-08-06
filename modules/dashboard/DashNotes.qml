import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sidebarRight.notepad

/**
 * Quick notes card. Reuses the sidebar notepad (tabs, autosave to the shared
 * notepad state) so notes stay in sync across surfaces. Fills column height.
 */
DashCard {
    id: root
    title: Translation.tr("Notes")
    icon: "edit_note"
    Layout.fillHeight: true

    NotepadWidget {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 180
    }
}
