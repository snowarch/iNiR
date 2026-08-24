import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell

AndroidQuickToggleButton {
    id: root

    name: Translation.tr("Color picker")
    statusText: ""
    toggled: false
    buttonIcon: "colorize"

    mainAction: () => {
        GlobalStates.sidebarRightOpen = false;
        delayedActionTimer.start()
    }
    Timer {
        id: delayedActionTimer
        interval: 300
        repeat: false 
        onTriggered: {
            ShellExec.execDetachedArgs(["/usr/bin/hyprpicker", "-a"], "Pick color")
        }
    }

    StyledToolTip {
        text: Translation.tr("Color picker")
    }
}
