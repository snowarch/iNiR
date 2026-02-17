import qs.modules.common
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell

// Angel-style glass background with refined blur, noise grain, and inset glow.
// Enhanced version of GlassBackground for the angel global style.
// Falls back to GlassBackground behavior when angel is not active.
Rectangle {
    id: root

    property color fallbackColor: Appearance.colors.colLayer1
    property color inirColor: Appearance.inir.colLayer1
    property real auroraTransparency: Appearance.aurora.popupTransparentize

    // Screen-relative position for blur alignment (set by parent)
    property real screenX: 0
    property real screenY: 0
    property real screenWidth: Quickshell.screens[0]?.width ?? 1920
    property real screenHeight: Quickshell.screens[0]?.height ?? 1080

    readonly property bool angelEverywhere: Appearance.angelEverywhere
    readonly property bool auroraEverywhere: Appearance.auroraEverywhere
    readonly property bool inirEverywhere: Appearance.inirEverywhere
    readonly property string wallpaperUrl: Wallpapers.effectiveWallpaperUrl

    property bool hovered: false

    color: angelEverywhere ? "transparent"
        : auroraEverywhere ? "transparent"
        : inirEverywhere ? inirColor
        : fallbackColor

    clip: true

    layer.enabled: (auroraEverywhere || angelEverywhere) && !inirEverywhere
    layer.effect: GE.OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: root.radius
        }
    }

    // Wallpaper blur layer
    Image {
        id: blurredWallpaper
        x: -root.screenX
        y: -root.screenY
        width: root.screenWidth
        height: root.screenHeight
        visible: (root.auroraEverywhere || root.angelEverywhere) && !root.inirEverywhere
        source: root.wallpaperUrl
        fillMode: Image.PreserveAspectCrop
        cache: true
        asynchronous: true

        layer.enabled: Appearance.effectsEnabled
        layer.effect: MultiEffect {
            source: blurredWallpaper
            anchors.fill: source
            saturation: root.angelEverywhere
                ? (Appearance.angel.blurSaturation * Appearance.angel.colorStrength)
                : (Appearance.effectsEnabled ? 0.2 : 0)
            blurEnabled: Appearance.effectsEnabled
            blurMax: 100
            blur: Appearance.effectsEnabled
                ? (root.angelEverywhere ? Appearance.angel.blurIntensity : 1)
                : 0
        }
    }

    // Color overlay — angel uses higher opacity for refined look
    Rectangle {
        anchors.fill: parent
        visible: (root.auroraEverywhere || root.angelEverywhere) && !root.inirEverywhere
        color: root.angelEverywhere
            ? ColorUtils.transparentize(Appearance.colors.colLayer0Base, Appearance.angel.overlayOpacity)
            : ColorUtils.transparentize(Appearance.colors.colLayer0Base, root.auroraTransparency)
    }

    // Inset glow — light-from-above on top edge, angel only
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Appearance.angel.insetGlowHeight
        visible: root.angelEverywhere
        color: Appearance.angel.colInsetGlow
    }

    // Partial border — elegant half-borders, angel only
    AngelPartialBorder {
        targetRadius: root.radius
        hovered: root.hovered
    }
}
