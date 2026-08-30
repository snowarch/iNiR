pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.common
import qs.modules.pill

IslandPanel {
    id: root

    property bool barShadow: Config.options?.appearance?.island?.shadow ?? true
    property bool compactShadow: true
    readonly property real shadowShapeRadius: Math.max(0,
        Math.min(root.radius, root.width / 2, root.height / 2))
    readonly property real shadowBlur: Math.max(3,
        Appearance.sizes.elevationMargin * 0.45)

    shadow: !root.compactShadow && root.barShadow

    RectangularShadow {
        anchors.fill: parent
        visible: root.compactShadow && Appearance.effectsEnabled
            && root.barShadow && root.visible
        z: -1
        color: Appearance.colors.colShadow
        radius: root.shadowShapeRadius
        blur: root.shadowBlur
        offset: Qt.vector2d(0, 2)
        spread: 0
        cached: true
    }
}
