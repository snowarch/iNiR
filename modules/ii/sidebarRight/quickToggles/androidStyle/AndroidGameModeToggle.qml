import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.services

AndroidQuickToggleButton {
    id: root

    name: Translation.tr("Game mode")
    statusText: GameMode.active ? Translation.tr("Active") : ""
    toggled: GameMode.active
    buttonIcon: "gamepad"

    mainAction: () => {
        GameMode.toggle()
    }

    StyledToolTip {
        text: GameMode.active 
            ? Translation.tr("Game mode") + " (" + (GameMode.manuallyActivated ? Translation.tr("manual") : Translation.tr("auto")) + ")"
            : Translation.tr("Game mode")
    }
}
