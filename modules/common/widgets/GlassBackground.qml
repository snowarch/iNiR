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
    property color overlayColor: Appearance.colors.colLayer0Base
    property real auroraTransparency: Appearance.editorialEverywhere && Appearance.editorial.glassActive
        ? 1 - Appearance.editorial.glassOpacity : Appearance.aurora.popupTransparentize
    property bool wallpaperBackdropEnabled: true
    property string wallpaperUrl: WallpaperListener.wallpaperUrlForScreen(root.QsWindow?.window?.screen ?? null)
    
    // Screen-relative position for blur alignment (set by parent)
    property real screenX: 0
    property real screenY: 0
    property real screenWidth: Quickshell.screens[0]?.width ?? 1920
    property real screenHeight: Quickshell.screens[0]?.height ?? 1080

    // Menus and popups set this instead of screenX/screenY: the plate finds where its window sits (a panel by its
    // edges, a popup by its anchor) so the wallpaper behind it is the one under it, like the panel it opens from.
    property bool followWindow: false
    readonly property var _win: root.followWindow && root.useWallpaperBackdrop ? (root.QsWindow?.window ?? null) : null
    readonly property real _winW: root._win?.width ?? 0
    readonly property real _winH: root._win?.height ?? 0
    on_WinWChanged: root.placeOnScreen()
    on_WinHChanged: root.placeOnScreen()
    onXChanged: root.placeOnScreen()
    onYChanged: root.placeOnScreen()
    Component.onCompleted: Qt.callLater(root.placeOnScreen)

    function _origin(w): point {
        const sw = w.screen?.width ?? root.screenWidth
        const sh = w.screen?.height ?? root.screenHeight
        const an = w.anchor
        if (an?.window && an.window !== w) {
            const p = root._origin(an.window)
            const r = an.rect
            const tl = an.item ? an.item.mapToItem(null, r.x, r.y) : Qt.point(r.x, r.y)
            const aw = r.width || (an.item?.width ?? 0)
            const ah = r.height || (an.item?.height ?? 0)
            const e = an.edges, g = an.gravity
            const px = p.x + tl.x + ((e & Edges.Left) ? 0 : (e & Edges.Right) ? aw : aw / 2)
            const py = p.y + tl.y + ((e & Edges.Top) ? 0 : (e & Edges.Bottom) ? ah : ah / 2)
            const x = (g & Edges.Left) ? px - w.width : (g & Edges.Right) ? px : px - w.width / 2
            const y = (g & Edges.Top) ? py - w.height : (g & Edges.Bottom) ? py : py - w.height / 2
            // The compositor slides a popup back onto the screen.
            return Qt.point(Math.max(0, Math.min(x, sw - w.width)), Math.max(0, Math.min(y, sh - w.height)))
        }
        const a = w.anchors, m = w.margins
        return Qt.point(!a ? 0 : a.left ? (m?.left ?? 0) : a.right ? sw - w.width - (m?.right ?? 0) : (sw - w.width) / 2,
            !a ? 0 : a.top ? (m?.top ?? 0) : a.bottom ? sh - w.height - (m?.bottom ?? 0) : (sh - w.height) / 2)
    }
    function placeOnScreen(): void {
        const w = root._win
        if (!w)
            return
        const o = root._origin(w)
        const inWin = root.mapToItem(null, 0, 0)
        root.screenX = o.x + inWin.x
        root.screenY = o.y + inWin.y
        root.screenWidth = w.screen?.width ?? root.screenWidth
        root.screenHeight = w.screen?.height ?? root.screenHeight
    }

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
    property real blurStrength: Appearance.editorialEverywhere && Appearance.editorial.glassActive
        ? Appearance.editorial.glassBlur : 1
    property real saturationStrength: Appearance.editorialEverywhere && Appearance.editorial.glassActive ? 0.04 : Appearance.aurora.backdropSaturation
    readonly property bool useWallpaperBackdrop: root.forceBackdrop
        ? Appearance.effectsEnabled
        : (Appearance.blurBackendFor("panels", Appearance.blurTopology.unsupported) === "wallpaper"
            && root.wallpaperBackdropEnabled)
    readonly property bool backdropReady: !root.useWallpaperBackdrop
        || blurredWallpaper.status === Image.Ready
    
    // Never expose a raw transparent hole while the wallpaper is loading or
    // unavailable. Consumers can provide a solid style base as fallback; once
    // the backdrop is ready this becomes transparent and the glass stack takes over.
    color: root.useWallpaperBackdrop && root.backdropReady ? "transparent"
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
        // Blurred anyway: a quarter of the screen looks the same and every instance kept a full layer.
        readonly property real blur: Appearance.effectsEnabled
            ? (root.angelEverywhere ? Appearance.angel.blurIntensity : root.blurStrength) : 0
        readonly property real grain: blur >= 0.3 ? 0.25 : 1
        sourceSize.width: Math.round(root.screenWidth * grain)
        sourceSize.height: Math.round(root.screenHeight * grain)
        layer.textureSize: Qt.size(Math.round(width * grain), Math.round(height * grain))

        // CRITICAL: Only enable blur layer when VISIBLE AND enabled.
        // This releases the FBO when the panel is hidden, saving ~16 MiB per instance.
        layer.enabled: Appearance.effectsEnabled && root.useWallpaperBackdrop && root.visible
        layer.effect: MultiEffect {
            source: blurredWallpaper
            anchors.fill: source
            contrast: Appearance.aurora.backdropContrast
            brightness: Appearance.aurora.backdropBrightness
            saturation: root.angelEverywhere && !root.forceNeutralMaterial
                ? (Appearance.angel.blurSaturation * Appearance.angel.colorStrength)
                : (Appearance.effectsEnabled ? root.saturationStrength : 0)
            blurEnabled: Appearance.effectsEnabled
            blurMax: 64
            blur: blurredWallpaper.blur
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.useWallpaperBackdrop
        color: root.angelEverywhere && !root.forceNeutralMaterial
            ? ColorUtils.transparentize(Appearance.colors.colLayer0Base, Appearance.angel.overlayOpacity)
            : ColorUtils.transparentize(root.overlayColor, root.auroraTransparency)
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
