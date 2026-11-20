pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.common
import qs.services

/**
 * PaletteFade - Crossfades a surface across palette/theme swaps.
 * Freezes `target` into a ShaderEffectSource snapshot (`live: false`), parked
 * outside the window while capturing so it is invisible until the fade out runs,
 * using awww's wallpaper transition bezier curve so the shell and wallpaper fade together.
 */
Item {
    id: root

    required property Item target
    property real radius: 0
    property real topLeftRadius: root.radius
    property real topRightRadius: root.radius
    property real bottomLeftRadius: root.radius
    property real bottomRightRadius: root.radius
    property bool active: Appearance.animationsEnabled

    visible: fade.running
    z: 999
    clip: root.radius > 0 || root.topLeftRadius > 0 || root.topRightRadius > 0
        || root.bottomLeftRadius > 0 || root.bottomRightRadius > 0

    function snap(): void {
        if (!root.active || !root.target || !root.target.visible
                || root.width < 2 || root.height < 2)
            return
        fade.stop()
        root.opacity = 1
        shot.x = -root.width - 64
        shot.scheduleUpdate()
        begin.restart()
    }

    Connections {
        target: MaterialThemeLoader
        enabled: root.active
        function onAboutToApplyColors(): void {
            root.snap()
        }
    }

    ShaderEffectSource {
        id: shot
        x: -root.width - 64
        width: root.width
        height: root.height
        sourceItem: root.target
        live: false
        hideSource: false
    }

    Timer {
        id: begin
        interval: 24
        onTriggered: {
            shot.x = 0
            fade.restart()
        }
    }

    NumberAnimation {
        id: fade
        target: root
        property: "opacity"
        from: 1
        to: 0
        duration: Config.options?.background?.transition?.duration ?? 700
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.54, 0, 0.34, 0.99, 1, 1]
    }
}
