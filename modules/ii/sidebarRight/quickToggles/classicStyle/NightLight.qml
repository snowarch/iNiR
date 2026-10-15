import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell.Io

QuickToggleButton {
    id: nightLightButton
    toggled: Hyprsunset.active
    buttonIcon: (Config.options?.light?.night?.automatic ?? false) ? "night_sight_auto" : "bedtime"
    onClicked: {
        Hyprsunset.toggle()
    }

    altAction: () => {
        Config.setNestedValue("light.night.automatic", !(Config.options?.light?.night?.automatic ?? false))
    }

    Component.onCompleted: {
        Hyprsunset.fetchState()
    }
    
    StyledToolTip {
        text: Translation.tr("Night Light | Right-click to toggle Auto mode")
    }
}
