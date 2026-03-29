import qs.modules.common
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell

// Reusable glass/acrylic background component
// For correct blur positioning, parent must set screenX/screenY to component's screen position
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
    
    color: auroraEverywhere ? "transparent"
        : inirEverywhere ? inirColor
        : fallbackColor
    
    property bool hovered: false

    border.width: 0
    border.color: "transparent"

    clip: true
    
    layer.enabled: auroraEverywhere && !inirEverywhere
    layer.effect: GE.OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: root.radius
        }
    }
    
    Image {
        id: blurredWallpaper
        x: -root.screenX
        y: -root.screenY
        width: root.screenWidth
        height: root.screenHeight
        visible: root.auroraEverywhere && !root.inirEverywhere && status === Image.Ready
        source: (root.auroraEverywhere && !root.inirEverywhere) ? root.wallpaperUrl : ""
        fillMode: Image.PreserveAspectCrop
        // All GlassBackground instances share the same wallpaper URL and sourceSize,
        // so Qt's QPixmapCache serves a single decoded pixmap to all of them.
        // The old wallpaper is evicted naturally when the source URL changes.
        cache: true
        asynchronous: true
        // Constrain decoded size: this Image is always heavily blurred so full
        // native resolution is wasted.  Screen dimensions are more than enough.
        sourceSize.width: root.screenWidth
        sourceSize.height: root.screenHeight

        layer.enabled: Appearance.effectsEnabled && root.auroraEverywhere && !root.inirEverywhere
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

    Rectangle {
        anchors.fill: parent
        visible: root.auroraEverywhere && !root.inirEverywhere
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
