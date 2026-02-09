import QtQuick
import qs.services
import qs.modules.common

QuickToggleModel {
    name: Translation.tr("Game mode")
    statusText: GameMode.active ? Translation.tr("Active") : ""
    toggled: GameMode.active
    icon: "gamepad"

    mainAction: () => {
        GameMode.toggle()
    }

    tooltipText: GameMode.active
            ? Translation.tr("Game mode") + " (" + (GameMode.manuallyActivated ? Translation.tr("manual") : Translation.tr("auto")) + ")"
            : Translation.tr("Game mode")
}
