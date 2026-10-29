import QtQuick
import QtQuick.Effects
import qs.modules.common

MultiEffect {
    id: root
    source: wallpaper
    anchors.fill: source
    contrast: Appearance.aurora.backdropContrast
    brightness: Appearance.aurora.backdropBrightness
    saturation: Appearance.effectsEnabled ? Appearance.aurora.backdropSaturation : 0
    blurEnabled: Appearance.effectsEnabled
    blurMax: 64
    blur: Appearance.effectsEnabled ? 1 : 0
}
