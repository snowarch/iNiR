import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell

AndroidQuickToggleButton {
    id: root
    
    property bool auto: Config.options?.light?.night?.automatic ?? false

    name: Translation.tr("Anti-flashbang")

    toggled: Config.options?.light?.antiFlashbang?.enable ?? false
    buttonIcon: "flash_off"
    
    mainAction: () => {
        Config.setNestedValue("light.antiFlashbang.enable", !(Config.options?.light?.antiFlashbang?.enable ?? false));
    }

    altAction: () => {
        root.openMenu()
    }

    StyledToolTip {
        text: Translation.tr("Anti-flashbang")
    }
}

