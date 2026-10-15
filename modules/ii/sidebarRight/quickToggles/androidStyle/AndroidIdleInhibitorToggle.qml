import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick

AndroidQuickToggleButton {
    name: Translation.tr("Keep awake")
    toggled: Idle.inhibit
    buttonIcon: "coffee"
    mainAction: () => Idle.toggleInhibit()
    StyledToolTip { text: Translation.tr("Keep system awake") }
}
