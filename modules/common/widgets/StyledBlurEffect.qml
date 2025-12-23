import QtQuick
import QtQuick.Effects
import qs.modules.common

MultiEffect {
    id: root
    anchors.fill: source
    saturation: Appearance.effectsEnabled ? 0.2 : 0
    blurEnabled: Appearance.effectsEnabled
    blurMax: 100
    blur: Appearance.effectsEnabled ? 1 : 0
}
