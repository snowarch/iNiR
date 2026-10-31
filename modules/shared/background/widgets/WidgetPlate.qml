import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell
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

    // Below ~0.86 the wallpaper washes a container out.
    property real plateAlpha: root.backed ? Math.min(0.96, 0.86 + root.strength * 0.6) : 0
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
    property real glassBlur: 0.8
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

    // The mask and the blur targets go during fullscreen and game pauses; the decoded wallpaper stays for a quick resume.
    layer.enabled: root.glass && root.visible && root.surface.powerActive
    layer.effect: GE.OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: root.radius
        }
    }

    Loader {
        active: root.glass && root.visible
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
                blurMax: Math.max(1, Math.round(64 * root._blurScale))
                blur: root.glassBlur
            }
        }
    }
}
