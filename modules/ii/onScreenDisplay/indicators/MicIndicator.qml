import qs.services
import QtQuick
import qs.modules.ii.onScreenDisplay

OsdValueIndicator {
    id: osdValues
    value: Audio.micVolume
    icon: Audio.micMuted ? "mic_off" : "mic"
    name: Translation.tr("Mic")
}
