import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell

// Hidden instances release their blur FBO; decoded wallpaper pixmaps remain shared.
Rectangle {
    id: root
    
    property color fallbackColor: Appearance.colors.colLayer1
    property color inirColor: Appearance.inir.colLayer1
    property real auroraTransparency: Appearance.aurora.popupTransparentize
    property bool wallpaperBackdropEnabled: true
    property string wallpaperUrl: WallpaperListener.wallpaperUrlForScreen(root.QsWindow?.window?.screen ?? null)
    
    // Screen-relative position for blur alignment (set by parent)
    property real screenX: 0
    property real screenY: 0
    property real screenWidth: Quickshell.screens[0]?.width ?? 1920
    property real screenHeight: Quickshell.screens[0]?.height ?? 1080
    
    readonly property bool angelEverywhere: Appearance.angelEverywhere
    readonly property bool auroraEverywhere: Appearance.auroraEverywhere
    readonly property bool inirEverywhere: Appearance.inirEverywhere
    // Bypasses the style gate, which is what its callers always documented it as
    // doing. It used to be AND-ed inside the backend check, so a surface asking
    // for a backdrop outside aurora — island glass, or a backdrop the user turned
    // on explicitly — silently got nothing. The effects gate still applies.
    property bool forceBackdrop: false
    property bool forceNeutralMaterial: false
    // Blur radius as a fraction of blurMax. 1 is the house default every existing
    // caller inherits; lower values are for surfaces that expose it to the user.
    property real blurStrength: 1
    property real saturationStrength: 0.2
    readonly property bool useWallpaperBackdrop: root.forceBackdrop
        ? Appearance.effectsEnabled
        : (Appearance.blurBackendFor("panels", Appearance.blurTopology.unsupported) === "wallpaper"
            && root.wallpaperBackdropEnabled)
    
    color: root.useWallpaperBackdrop ? "transparent"
        : root.inirEverywhere ? root.inirColor
        : root.fallbackColor
    
    property bool hovered: false

    border.width: 0
    border.color: "transparent"

    clip: true
    
    // Hidden persistent surfaces must not retain their mask FBO. The decoded
    // wallpaper stays in Qt's shared image cache, so remapping remains warm.
    layer.enabled: root.useWallpaperBackdrop && root.visible
    layer.effect: GE.OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: root.radius
        }
    }
    
    // Blurred wallpaper backdrop for aurora/angel styles.
    // OPTIMIZATION: layer.enabled is only active when the GlassBackground is
    // actually visible, reducing GPU memory when panels are hidden.
    Image {
        id: blurredWallpaper
        x: -root.screenX
        y: -root.screenY
        width: root.screenWidth
        height: root.screenHeight
        visible: root.useWallpaperBackdrop && status === Image.Ready
        source: root.useWallpaperBackdrop ? root.wallpaperUrl : ""
        fillMode: Image.PreserveAspectCrop
        // All GlassBackground instances share the same wallpaper URL and sourceSize,
        // so Qt's QPixmapCache serves a single decoded pixmap to all of them.
        cache: true
        asynchronous: true
        // Constrain decoded size to screen dimensions — the blur doesn't need more.
        sourceSize.width: root.screenWidth
        sourceSize.height: root.screenHeight

        // CRITICAL: Only enable blur layer when VISIBLE AND enabled.
        // This releases the FBO when the panel is hidden, saving ~16 MiB per instance.
        layer.enabled: Appearance.effectsEnabled && root.useWallpaperBackdrop && root.visible
        layer.effect: MultiEffect {
            source: blurredWallpaper
            anchors.fill: source
            saturation: root.angelEverywhere && !root.forceNeutralMaterial
                ? (Appearance.angel.blurSaturation * Appearance.angel.colorStrength)
                : (Appearance.effectsEnabled ? root.saturationStrength : 0)
            blurEnabled: Appearance.effectsEnabled
            blurMax: 64
            blur: Appearance.effectsEnabled
                ? (root.angelEverywhere ? Appearance.angel.blurIntensity : root.blurStrength)
                : 0
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.useWallpaperBackdrop
        color: root.angelEverywhere && !root.forceNeutralMaterial
            ? ColorUtils.transparentize(Appearance.colors.colLayer0Base, Appearance.angel.overlayOpacity)
            : ColorUtils.transparentize(Appearance.colors.colLayer0Base, root.auroraTransparency)
    }

    // Inset glow — light-from-above on top edge, angel only
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Appearance.angel.insetGlowHeight
        visible: root.angelEverywhere && !root.forceNeutralMaterial
        color: Appearance.angel.colInsetGlow
    }

    // Partial border — elegant half-borders, angel only
    AngelPartialBorder {
        visible: root.angelEverywhere && !root.forceNeutralMaterial
        targetRadius: root.radius
        hovered: root.hovered
    }
}
