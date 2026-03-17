import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

QuickToggleModel {
    name: Translation.tr("Audio input")
    statusText: toggled ? Translation.tr("Enabled") : Translation.tr("Muted")
    toggled: !Audio.micMuted
    icon: Audio.micMuted ? "mic_off" : "mic"
    mainAction: () => {
        Audio.toggleMicMute()
    }
    hasMenu: true

    tooltipText: Translation.tr("Audio input | Right-click for volume mixer & device selector")
}
