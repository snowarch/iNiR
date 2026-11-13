import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

QuickToggleModel {
    name: Translation.tr("Color picker")
    hasStatusText: false
    toggled: false
    icon: "colorize"

    // The picker waits for the sidebar to leave before it reads the screen.
    mainAction: () => {
        GlobalStates.sidebarRightOpen = false;
        GlobalStates.screenColorPickerOpen = true;
    }

    tooltipText: Translation.tr("Color picker")
}
