import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.services

// The plate a widget stands on: its fill and a thin edge in its accent. A family extends this with its own (part
// `widgetPlate`); a design that isn't the family's wears it as it is.
Rectangle {
    id: root

    required property var surface

    readonly property real strength: Math.max(0, Math.min(1, Number(root.surface.surfaceOpacity) || 0))
    readonly property bool backed: root.strength > 0.001

    // Below ~0.86 the wallpaper washes a container out (ink is picked against the plate as if it were opaque). Up to
    // the usual 16 % strength the plate keeps the alpha it always had; past it the rest of the slider reaches solid,
    // where before it stopped at 0.96 and everything over 17 % did nothing.
    readonly property real solidAlpha: root.strength <= 0.16 ? 0.86 + root.strength * 0.6
        : 0.956 + (root.strength - 0.16) / 0.84 * 0.044
    property real plateAlpha: root.backed ? root.solidAlpha : 0
    // Keeps the generated hue with a predictable ink on it; accent belongs to live data, not the whole card.
    readonly property color plateDark: {
        const accent = Qt.color(root.surface.surfaceAccent)
        return Qt.hsla(accent.hslHue, Math.min(0.22, accent.hslSaturation), 0.11, 1.0)
    }
    readonly property color plateLight: {
        const accent = Qt.color(root.surface.surfaceAccent)
        return Qt.hsla(accent.hslHue, Math.min(0.20, accent.hslSaturation), 0.93, 1.0)
    }
    readonly property bool plateIsDark: root.surface.colorMode === "light" ? true
        : root.surface.colorMode === "dark" ? false
        : ColorUtils.relativeLuminance(root.surface.surfaceFill) < 0.38
    // An explicit ink forces the opposite plate so that ink stays visible.
    readonly property color polarPlate: root.plateIsDark ? root.plateDark : root.plateLight
    readonly property color baseFill: root.surface.colorMode === "auto" ? root.surface.surfaceFill : root.polarPlate
    readonly property color flatFill: ColorUtils.applyAlpha(root.baseFill, root.plateAlpha)

    property bool rimShown: true
    property color rimColor: ColorUtils.applyAlpha(ColorUtils.ensureReadable(root.surface.surfaceAccent, root.flatFill, 3),
        Math.min(1, root.surface.surfaceBorderOpacity * 2))

    // The wallpaper behind the plate, frosted. Half size: nobody sees it through this blur, and the blur radius is in
    // source pixels, so it's halved too.
    property bool glass: false
    property real glassSaturation: 0.15
    // The widget's Blur strength scales what the family's style blurs by; the radius grows past 100 %.
    property real glassBlur: 0.8
    readonly property real _glassAmount: Math.max(0, root.glassBlur * (root.surface.widget?.blurStrength ?? 1))
    readonly property real _glassReach: Math.max(1, root._glassAmount)
    readonly property real _blurScale: 0.5

    property int moveDuration: FamilyStyle.revealDuration
    property int moveType: Easing.BezierSpline
    property var moveCurve: FamilyStyle.morphCurve

    radius: root.surface.surfaceRadius
    color: root.backed ? root.flatFill : "transparent"
    clip: true

    Behavior on radius {
        enabled: FamilyStyle.motionEnabled
        NumberAnimation { duration: root.moveDuration; easing.type: root.moveType; easing.bezierCurve: root.moveCurve }
    }
    Behavior on color {
        enabled: FamilyStyle.motionEnabled
        ColorAnimation { duration: root.moveDuration; easing.type: root.moveType; easing.bezierCurve: root.moveCurve }
    }

    // A drawn edge over whatever the family fills with: on the plate's own border it bled inward, and under the glass
    // it was never seen.
    Rectangle {
        z: 1
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        visible: root.rimShown && root.surface.surfaceBorderWidth > 0 && root.surface.surfaceBorderOpacity > 0
        border.width: root.surface.surfaceBorderWidth
        border.color: root.rimColor
    }

    // On Rin, desktop widgets sit above the Background wallpaper layer so Rin's GPU blur /
    // Liquid Glass blurs and refracts natively with zero per-widget Qt blur FBOs.
    readonly property var _host: QsWindow.window ?? root.QsWindow?.window ?? null
    readonly property bool compositorGlass: root.glass && root.visible && Boolean(root._host?.compositorWidgetGlass)
    readonly property string _blurKey: "plate:" + String(root.surface?.widget?.configEntryName ?? "") + "@" + String(root)
    function _syncCompositorBlur(): void {
        const win = root._host
        if (!win || typeof win.setWidgetBlurRect !== "function") return
        if (!root.compositorGlass || !root.backed || !(root.width >= 8) || !(root.height >= 8)) {
            win.clearWidgetBlurRect(root._blurKey)
            return
        }
        const pos = root.mapToItem(win.contentItem, 0, 0)
        win.setWidgetBlurRect(root._blurKey, {
            x: pos.x, y: pos.y, width: root.width, height: root.height, radius: root.radius
        })
    }
    onCompositorGlassChanged: root._syncCompositorBlur()
    onBackedChanged: root._syncCompositorBlur()
    onWidthChanged: if (root.compositorGlass) root._syncCompositorBlur()
    onHeightChanged: if (root.compositorGlass) root._syncCompositorBlur()
    onRadiusChanged: if (root.compositorGlass) root._syncCompositorBlur()
    Connections {
        target: root.surface?.widget ?? null
        ignoreUnknownSignals: true
        function onXChanged(): void { if (root.compositorGlass) root._syncCompositorBlur() }
        function onYChanged(): void { if (root.compositorGlass) root._syncCompositorBlur() }
        function onVisibleChanged(): void { root._syncCompositorBlur() }
    }
    Connections {
        target: root.surface?.widget?.parent ?? null
        ignoreUnknownSignals: true
        function onXChanged(): void { if (root.compositorGlass) root._syncCompositorBlur() }
        function onYChanged(): void { if (root.compositorGlass) root._syncCompositorBlur() }
    }
    Timer {
        id: blurSettleTimer
        interval: 80
        repeat: false
        onTriggered: if (root.compositorGlass) root._syncCompositorBlur()
    }
    Component.onCompleted: if (root.compositorGlass) { Qt.callLater(root._syncCompositorBlur); blurSettleTimer.restart() }
    Component.onDestruction: {
        const win = root._host
        if (win && typeof win.clearWidgetBlurRect === "function") win.clearWidgetBlurRect(root._blurKey)
    }

    // The mask and the blur targets go during fullscreen, game pauses, or when Rin compositor glass draws it.
    layer.enabled: root.glass && !root.compositorGlass && !GlobalStates.widgetEditMode && root.visible && root.surface.powerActive
    layer.effect: GE.OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: root.radius
        }
    }

    // On the desktop the glass copies the window's own wallpaper layer, what is really seen there (the glyph wallpaper,
    // a playing video), and again on each of its frames while it moves; elsewhere (the lock) the picture itself.
    readonly property Item _layer: root._host?.wallpaperLayer ?? null
    Loader {
        active: root.glass && !root.compositorGlass && !GlobalStates.widgetEditMode && root.visible && root._layer !== null
        sourceComponent: ShaderEffectSource {
            id: frosted
            readonly property int revision: root._host?.wallpaperLayerRevision ?? 0
            readonly property int frame: root._host?.wallpaperLayerFrame ?? 0
            readonly property point at: {
                void (root.surface.screenX + root.surface.screenY + root.width + root.height)
                return root.mapToItem(root._layer, 0, 0)
            }
            // Wide enough for the blur to find picture all round, so the rim does not fade to nothing.
            readonly property real margin: Math.round(40 * root._glassReach)
            x: -margin
            y: -margin
            width: root.width + margin * 2
            height: root.height + margin * 2
            sourceItem: root._layer
            live: GlobalStates.widgetEditMode
            sourceRect: Qt.rect(at.x - margin, at.y - margin, width, height)
            textureSize: Qt.size(Math.max(1, Math.round(width * root._blurScale)), Math.max(1, Math.round(height * root._blurScale)))
            smooth: true
            onRevisionChanged: scheduleUpdate()
            onFrameChanged: scheduleUpdate()
            onAtChanged: scheduleUpdate()
            layer.enabled: root.surface.powerActive
            layer.textureSize: frosted.textureSize
            layer.effect: MultiEffect {
                saturation: root.glassSaturation
                blurEnabled: true
                blurMax: Math.max(1, Math.round(64 * root._glassReach * root._blurScale))
                blur: Math.min(1, root._glassAmount)
            }
        }
    }
    Loader {
        active: root.glass && !root.compositorGlass && !GlobalStates.widgetEditMode && root.visible && root._layer === null
        sourceComponent: Image {
            id: blurredWallpaper
            x: -root.surface.screenX
            y: -root.surface.screenY
            width: root.surface.screenWidth
            height: root.surface.screenHeight
            visible: status === Image.Ready
            source: WallpaperListener.wallpaperUrlForScreen(root.QsWindow?.window?.screen ?? null)
            fillMode: Image.PreserveAspectCrop
            cache: true
            asynchronous: true
            sourceSize.width: Math.round(root.surface.screenWidth * root._blurScale)
            sourceSize.height: Math.round(root.surface.screenHeight * root._blurScale)

            layer.enabled: root.glass && root.visible && root.surface.powerActive
            layer.smooth: true
            layer.textureSize: Qt.size(Math.round(width * root._blurScale), Math.round(height * root._blurScale))
            layer.effect: MultiEffect {
                source: blurredWallpaper
                anchors.fill: source
                saturation: root.glassSaturation
                blurEnabled: true
                blurMax: Math.max(1, Math.round(64 * root._glassReach * root._blurScale))
                blur: Math.min(1, root._glassAmount)
            }
        }
    }
}
