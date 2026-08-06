pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects
import qs.modules.common

DropShadow {
    required property var target
    visible: Appearance.effectsEnabled && !Appearance.zzzEverywhere
    source: target
    anchors.fill: source
    radius: Appearance.effectsEnabled ? 8 : 0
    samples: radius * 2 + 1
    color: Appearance.colors.colShadow
    transparentBorder: true
}
