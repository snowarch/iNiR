import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell

AndroidQuickToggleButton {
    id: root

    name: Translation.tr("Audio input")
    statusText: toggled ? Translation.tr("Enabled") : Translation.tr("Muted")
    toggled: !Audio.micMuted
    buttonIcon: Audio.micMuted ? "mic_off" : "mic"
    mainAction: () => {
        Audio.toggleMicMute()
    }

    altAction: () => {
        root.openMenu()
    }

    StyledToolTip {
        text: Translation.tr("Audio input | Right-click for volume mixer & device selector")
    }
}
