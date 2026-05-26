pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.common

/**
 * ShellDesaturationEffect - Visual desaturation/dim effect for shell components.
 *
 * Usage:
 *   Item {
 *       id: root
 *       layer.enabled: Appearance.shouldDesaturate("bar") && visible
 *       layer.effect: ShellDesaturationEffect {}
 *   }
 *
 * The effect reads saturation/brightness values from Appearance.desaturation* properties.
 * Animates smoothly when enabled/disabled.
 */
MultiEffect {
    id: root

    // Read values from Appearance (reactive)
    readonly property real _targetSaturation: Appearance.desaturationEnabled ? Appearance.desaturationSaturation : 0
    readonly property real _targetBrightness: Appearance.desaturationEnabled ? Appearance.desaturationBrightness : 0

    saturation: _targetSaturation
    brightness: _targetBrightness

    Behavior on saturation {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }
    Behavior on brightness {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }
}
