import QtQuick
import QtQuick.Layouts
import Quickshell
import org.kde.kirigami as Kirigami
import qs
import qs.services
import qs.modules.common
import qs.modules.waffle.looks

AppButton {
    id: root

    iconName: (down && !checked) ? "task-view-pressed" : "task-view"
    pressedScale: checked ? 5/6 : 1
    separateLightDark: true

    checked: GlobalStates.waffleTaskViewOpen
    onClicked: {
        // Use IPC to toggle TaskView - this triggers preview capture before opening
        Quickshell.execDetached(["/usr/bin/qs", "-c", "inir", "ipc", "call", "taskview", "toggle"])
    }

    BarToolTip {
        extraVisibleCondition: root.shouldShowTooltip
        text: Translation.tr("Task View")
    }
}
