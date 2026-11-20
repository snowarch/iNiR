pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.common
import qs.services

/**
 * PaletteFade - Crossfades a surface across palette/theme swaps.
 * When the loader is about to apply new colours it holds them, snapshots `target` in its old colours, lets the new
 * ones in and fades the snapshot out over them, on the wallpaper transition's bezier curve so the shell and the
 * wallpaper change together. It sits inside its target (give it `anchors.fill: parent`): the source is recursive and
 * is set only for the swap, so no texture is kept at rest.
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

    // true from the grab request until the fade ends; the only time the snapshot exists
    property bool _swapping: false
    // true while this surface holds the recolour
    property bool _holding: false

    visible: root._swapping
    z: 999
    clip: root.radius > 0 || root.topLeftRadius > 0 || root.topRightRadius > 0
        || root.bottomLeftRadius > 0 || root.bottomRightRadius > 0

    function _release(): void {
        if (!root._holding)
            return
        root._holding = false
        MaterialThemeLoader.releaseRecolour()
    }

    function _end(): void {
        root._release()
        fade.stop()
        root._swapping = false
        shot.sourceItem = null
        guard.stop()
    }

    Connections {
        target: MaterialThemeLoader
        enabled: root.active
        function onAboutToApplyColors(): void {
            if (root._swapping || !root.target || !root.target.visible
                    || !root.target.Window.window?.visible || root.width < 2 || root.height < 2)
                return
            root._swapping = true
            root._holding = true
            MaterialThemeLoader.holdRecolour()
            root.opacity = 1
            shot.sourceItem = root.target
            shot.scheduleUpdate()
            guard.restart()
        }
    }

    ShaderEffectSource {
        id: shot
        anchors.fill: parent
        sourceItem: null
        recursive: true
        live: false
        hideSource: false
        onScheduledUpdateCompleted: {
            if (!root._swapping || fade.running)
                return
            root._release()
            fade.restart()
        }
    }

    // The grab never answered (window hidden meanwhile): give the colours back and drop the snapshot.
    Timer {
        id: guard
        interval: 400
        onTriggered: root._end()
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
        onFinished: root._end()
    }
}
