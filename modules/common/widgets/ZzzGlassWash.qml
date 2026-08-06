pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.services

// Shared ZZZ wallpaper-glass wash. It carries only the blurred wallpaper hue
// and a restrained sheen; the caller still owns the final plate fill/stroke.
//
// The wash samples the wallpaper AT THE HOST'S POSITION ON SCREEN. Filling the
// host rect instead (the old behaviour) squeezed the entire wallpaper into the
// panel's aspect ratio: a 1920x40 bar decoded the image to 1920x40 and then blurred
// it by 64px, which is a dead grey gradient, not glass. That is why the effect
// "wasn't visible anywhere" in either mode.
//
// Position is derived, not passed in. Wayland layer-shell gives PanelWindow no
// absolute x/y, but anchors+margins pin it to an edge, and mapToItem(null) locates
// the wash inside its own window. Hosts living in a fullscreen overlay window get
// the right answer for free (window origin 0,0).
Item {
    id: root

    // Default the mask to the ACTIVE zzz silhouette so the blurred wallpaper never
    // escapes past a rounded/chamfered plate. Mirrors ZzzPlate's own defaults:
    // round mode → panelRadius rounded; square mode → bottom-right cut corner.
    property real maskRadius: Appearance.zzz.round ? Appearance.zzz.panelRadius : 0
    property real chamfer: Appearance.zzz.cutCorner
    property bool chamferTopLeft: false
    property bool chamferTopRight: false
    property bool chamferBottomLeft: false
    property bool chamferBottomRight: !Appearance.zzz.round
    property bool glassEnabled: Appearance.zzzEverywhere
        && Appearance.effectsEnabled
        && (Config.options?.appearance?.zzz?.glass ?? true)
    // Lets a host dial the wash down without forking the component.
    property real strength: 1.0

    // Every host of this wash (bar, dock, every ZzzPanelBackdrop) keeps its OWN
    // screen-sized copy of the wallpaper plus its own screen-sized blur FBO. The
    // wallpaper is then blurred at full strength (blur: 1, blurMax: 64), so none
    // of that resolution survives to the screen — it is decoded, uploaded and
    // blurred away. Render the wash at half resolution instead: the blur radius
    // is halved with it (blurMax counts source pixels, so a half-size texture
    // would otherwise blur twice as wide) and the layer is smoothed on upscale,
    // which makes the result identical while quartering the memory per host.
    readonly property real _washScale: 0.5
    // When true the wash IS the host's background: opaque blurred wallpaper with a
    // chrome veil on top, so the desktop genuinely shows through. The host must
    // then paint its own fill transparent. When false it stays a translucent wash
    // layered over whatever the host already painted (the panel-backdrop case).
    property bool selfBacked: false
    // Veil opacity when selfBacked. This is what pins the surface luminance, so the
    // ink contrast stays predictable no matter what wallpaper is behind: the blur
    // is strong enough that the ground is locally flat, and the veil sets its level.
    property real veilAlpha: Appearance.zzz.dark ? 0.72 : 0.78

    // ── Where is this wash on the screen? ──
    readonly property var _win: root.QsWindow.window ?? null
    readonly property real screenWidth: root._win?.screen?.width ?? 1920
    readonly property real screenHeight: root._win?.screen?.height ?? 1080
    readonly property real _winW: root._win?.width ?? root.screenWidth
    readonly property real _winH: root._win?.height ?? root.screenHeight
    readonly property var _anchors: root._win?.anchors ?? null
    readonly property var _margins: root._win?.margins ?? null
    readonly property real _winX: !root._anchors ? 0
        : root._anchors.left ? (root._margins?.left ?? 0)
        : root._anchors.right ? (root.screenWidth - root._winW - (root._margins?.right ?? 0))
        : (root.screenWidth - root._winW) / 2
    readonly property real _winY: !root._anchors ? 0
        : root._anchors.top ? (root._margins?.top ?? 0)
        : root._anchors.bottom ? (root.screenHeight - root._winH - (root._margins?.bottom ?? 0))
        : (root.screenHeight - root._winH) / 2

    // mapToItem is a call, not a tracked binding — refresh it on every relayout.
    property point _inWindow: Qt.point(0, 0)
    function _resync(): void {
        if (!root.glassEnabled) return
        root._inWindow = root.mapToItem(null, 0, 0)
    }
    onWidthChanged: root._resync()
    onHeightChanged: root._resync()
    on_WinWChanged: root._resync()
    on_WinHChanged: root._resync()
    onGlassEnabledChanged: root._resync()
    Component.onCompleted: Qt.callLater(root._resync)

    readonly property real screenX: root._winX + root._inWindow.x
    readonly property real screenY: root._winY + root._inWindow.y

    visible: glassEnabled

    layer.enabled: glassEnabled
    layer.effect: GE.OpacityMask {
        maskSource: ZzzPlate {
            width: root.width
            height: root.height
            fillColor: "white"
            radius: root.maskRadius
            chamfer: root.chamfer
            chamferTopLeft: root.chamferTopLeft
            chamferTopRight: root.chamferTopRight
            chamferBottomLeft: root.chamferBottomLeft
            chamferBottomRight: root.chamferBottomRight
        }
    }

    Image {
        id: wallpaper
        // Screen-sized and screen-aligned; the root's layer clips it back down, so
        // what shows through is genuinely what sits behind the panel.
        x: -root.screenX
        y: -root.screenY
        width: root.screenWidth
        height: root.screenHeight
        visible: root.glassEnabled && status === Image.Ready
        // Overlay mode was 0.12-0.16, which on top of an opaque plate is
        // indistinguishable from no wash at all. selfBacked mode paints it fully and
        // lets the veil above set the level.
        opacity: (root.selfBacked ? 1.0 : (Appearance.zzz.dark ? 0.30 : 0.22)) * root.strength
        source: root.glassEnabled ? Wallpapers.effectiveWallpaperUrl : ""
        fillMode: Image.PreserveAspectCrop
        cache: true
        asynchronous: true
        sourceSize.width: Math.max(1, Math.round(root.screenWidth * root._washScale))
        sourceSize.height: Math.max(1, Math.round(root.screenHeight * root._washScale))

        layer.enabled: root.glassEnabled && root.visible
        layer.effect: MultiEffect {
            source: wallpaper
            anchors.fill: source
            saturation: -0.05
            blurEnabled: true
            blurMax: 64
            blur: 1
        }
    }

    // Tonal veil — only in selfBacked mode, where the wallpaper is the ground.
    Rectangle {
        anchors.fill: parent
        visible: root.selfBacked
        color: ColorUtils.applyAlpha(Appearance.zzz.chrome, root.veilAlpha)
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: ColorUtils.applyAlpha(
                    Appearance.zzz.onColor,
                    Appearance.zzz.dark ? 0.045 : 0.03
                )
            }
            GradientStop { position: 0.32; color: "transparent" }
            GradientStop { position: 0.78; color: "transparent" }
            GradientStop {
                position: 1.0
                color: ColorUtils.applyAlpha(
                    Appearance.zzz.bg0,
                    Appearance.zzz.dark ? 0.26 : 0.16
                )
            }
        }
    }
}
