import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services

// Style-aware widget background surface.
// Adapts to the active ii style: blur for aurora/angel, border-only for inir, solid for material.
// Parent widget must set screenX/screenY for correct blur alignment.
Rectangle {
    id: root

    property real screenX: 0
    property real screenY: 0
    property real screenWidth: 1920
    property real screenHeight: 1080

    // Widget customization passthrough
    property real surfaceOpacity: 0.06
    property real surfaceBorderWidth: 1
    property real surfaceBorderOpacity: 0.08
    property color surfaceColor: Appearance.colors.colOnLayer0
    // Auto preserves each global style's native plate. Explicit ink modes
    // force the opposite plate polarity so the selected ink remains visible.
    property string colorMode: "auto"
    // The widget's accent identity (usually root.widgetAccent) — gives the plate
    // an actual color seat instead of a neutral wallpaper-luminance scrim.
    property color surfaceAccent: Appearance.colors.colPrimary
    property real surfaceRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.rounding.small
    // Allows per-widget blur override. When false, blur is disabled even if the
    // active style (aurora/angel) supports it. Lets users get a flat,
    // non-blurred resources widget while keeping a frosted-glass clock, etc.
    property bool surfaceUseBlur: true

    // Follow the owning widget's per-output power state. Standalone surfaces
    // keep the global summary as a compatibility fallback.
    property bool powerActive: parent?.powerActive ?? WidgetPowerManager.widgetsActive

    // The glass behind a widget is a screen-sized crop of the wallpaper, and
    // every WidgetSurface keeps its own copy plus its own screen-sized FBO (see
    // the note on blurredWallpaper below). At full resolution that was ~15 MB of
    // GPU memory per widget for something the user only ever sees through a
    // 64px blur. Rendering the source and its layer at half resolution is
    // invisible once blurred — provided the blur radius is scaled by the same
    // factor (blurMax is measured in source pixels, so a half-size texture would
    // otherwise blur twice as wide) and the layer is smoothed on upscale.
    readonly property real _blurScale: 0.5

    readonly property bool _angel: Appearance.angelEverywhere
    readonly property bool _aurora: Appearance.auroraEverywhere && !Appearance.inirEverywhere
    readonly property bool _inir: Appearance.inirEverywhere
    readonly property bool _zzz: Appearance.zzzEverywhere
    readonly property bool _cookie: Appearance.cookieEverywhere
    // Ricelin island dialect is an optional widget skin, but it must not
    // override a selected global style with its own surface worldview.
    readonly property bool _island: !root._zzz && !root._cookie && !root._angel
        && !root._aurora && !root._inir
        && (Config.options?.background?.widgets?.style ?? "panel") === "island"
    readonly property real _surfaceStrength: Math.max(0, Math.min(1, Number(root.surfaceOpacity) || 0))
    readonly property bool _backgroundVisible: root._surfaceStrength > 0.001
    readonly property real _plateAlpha: root._backgroundVisible
        ? Math.min(0.96, 0.72 + root._surfaceStrength * 0.24) : 0
    readonly property real _islandOpacity: Config.options?.appearance?.island?.opacity ?? 1
    readonly property bool _islandGlass: _island && root._backgroundVisible && root.surfaceUseBlur
        && (Config.options?.appearance?.island?.glass ?? true) && _islandOpacity < 0.999
    // Auto preserves the selected global style; an explicit Widgets override
    // is allowed to opt any card into the shared wallpaper backend.
    readonly property bool _glass: root._backgroundVisible
        && Appearance.blurBackendFor("widgets",
            Appearance.blurTopology.unsupported) === "wallpaper"
        && root.surfaceUseBlur
    readonly property string _wallpaperUrl: Wallpapers.effectiveWallpaperUrl

    // Wallpaper region brightness behind the widget (0-1; -1 = unknown).
    // Parent widgets bind their own regionBrightness so the plate opposes the
    // wallpaper: near-black on bright regions, theme container on dark ones.
    property real regionBrightness: -1
    readonly property bool _regionBright: regionBrightness >= 0
        ? regionBrightness > 0.55
        : !Appearance.m3colors.darkmode

    // A widget surface is a Material container, not another wallpaper sample.
    // Keep the generated hue while preserving a predictable surface/on-surface
    // relationship. Accent belongs to active data and icons, not to the whole card.
    readonly property color _plateDark: {
        const p = Qt.color(Appearance.colors.colPrimary);
        return Qt.hsla(p.hslHue, Math.min(0.22, p.hslSaturation), 0.11, 1.0);
    }
    readonly property color _plateLight: {
        const p = Qt.color(Appearance.colors.colPrimary);
        return Qt.hsla(p.hslHue, Math.min(0.20, p.hslSaturation), 0.93, 1.0);
    }
    // Mirrors AbstractBackgroundWidget.widgetPlateIsDark — dark theme stays black
    // everywhere; light theme gets a paper plate except over a bright wallpaper
    // region, where a light card would read as glare.
    readonly property bool _plateIsDark: root.colorMode === "light" ? true
        : root.colorMode === "dark" ? false
        : Appearance.m3colors.darkmode || root._regionBright
    readonly property color _plate: root._plateIsDark ? root._plateDark : root._plateLight
    readonly property color _flatFill: ColorUtils.applyAlpha(root._plate, root._plateAlpha)
    readonly property color _cookieFillBase: root.colorMode === "auto"
        ? Appearance.colors.colLayer2 : root._plate
    readonly property color _cookieFill: root._backgroundVisible
        ? ColorUtils.applyAlpha(root._cookieFillBase, root._plateAlpha)
        : "transparent"
    readonly property color _cookieStrokeBase: root.colorMode === "auto"
        ? Appearance.cookie.onColor : ColorUtils.contrastColor(root._plate)
    readonly property string surfaceReport: JSON.stringify({
        style: root._cookie ? "cookie"
            : root._zzz ? "zzz"
            : root._island ? "island"
            : root._angel ? "angel"
            : root._aurora ? "aurora"
            : root._inir ? "inir" : "material",
        cookie: root._cookie,
        island: root._island,
        glass: root._glass,
        visible: root.visible,
        backgroundOpacity: root.surfaceOpacity,
        backgroundVisible: root._backgroundVisible,
        borderWidth: root.surfaceBorderWidth,
        borderOpacity: root.surfaceBorderOpacity,
        radius: root.radius,
        fill: String(root._cookie ? root._cookieFill : root.color)
    })

    radius: surfaceRadius
    color: _island ? "transparent"
        : _glass ? "transparent"
        : _zzz ? "transparent"
        : _cookie ? "transparent"
        : _inir ? "transparent"
        : root._backgroundVisible ? _flatFill : "transparent"
    border.width: 0
    border.color: "transparent"
    clip: true

    ZzzPlate {
        anchors.fill: parent
        visible: root._zzz
        // ZZZ separates by FILL contrast, not outlines (maintainer design law:
        // bright edge strokes read as accent borders on every card). But the
        // per-widget showBackground/showBorder toggles still apply —
        // INDEPENDENTLY, so "border only" (transparent fill + hairline) is
        // reachable like material. Before this, ZzzPlate always filled with
        // paper, so toggling Border read as adding a background plate.
        fillColor: root._backgroundVisible
            ? ColorUtils.applyAlpha(root.colorMode === "auto" ? Appearance.zzz.paper : root._plate,
                root._plateAlpha)
            : "transparent"
        // ZZZ hairline is subtle by design (plates separate by FILL, not
        // outlines). Respect the per-widget borderOpacity so the slider works in
        // zzz too, but cap at 0.5 so it never becomes a loud accent border.
        strokeColor: ColorUtils.applyAlpha(Appearance.zzz.onColor,
            Math.min(0.5, root.surfaceBorderOpacity * 1.4))
        strokeWidth: root.surfaceBorderWidth > 0 ? Appearance.zzz.hairlineThick : 0
        chamfer: Appearance.zzz.cutCorner
        radius: Appearance.zzz.round ? root.radius : 0
    }

    Loader {
        anchors.fill: parent
        active: root._cookie && root.visible
            && (root.surfaceOpacity > 0
                || (root.surfaceBorderWidth > 0 && root.surfaceBorderOpacity > 0))
        sourceComponent: CookieFace {
            role: "card"
            radius: root.radius
            color: root._cookieFill
            strokeWidth: root.surfaceBorderWidth
            strokeColor: ColorUtils.applyAlpha(root._cookieStrokeBase, root.surfaceBorderOpacity)
        }
    }

    Behavior on radius {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    Behavior on color {
        enabled: Appearance.animationsEnabled
        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    Behavior on border.width {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    Behavior on border.color {
        enabled: Appearance.animationsEnabled
        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }

    // Separate border overlay — avoids Qt's interior bleed when border.width > 0 on a transparent Rectangle
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        visible: !root._zzz && !root._cookie && !root._island && !root._angel
            && root.surfaceBorderWidth > 0 && root.surfaceBorderOpacity > 0
        border.width: root.surfaceBorderWidth
        border.color: root._inir
            ? ColorUtils.applyAlpha(Appearance.inir.colBorder, root.surfaceBorderOpacity * 3)
            : root._aurora
                ? ColorUtils.applyAlpha(Appearance.aurora.colTooltipBorder,
                    root.surfaceBorderOpacity)
                : ColorUtils.applyAlpha(
                    ColorUtils.ensureReadable(Appearance.colors.colPrimary, root._flatFill, 3),
                    Math.min(1, root.surfaceBorderOpacity * 2))
    }

    // Removed: the ZZZ accent registration tick. Every fix to keep it inside
    // the rounded/chamfered corner still read as visual clutter across every
    // desktop widget at once — removed outright per explicit request instead
    // of iterating on its geometry again.

    // Blur mask FBO is only useful while the surface can contribute pixels.
    // Keep the decoded wallpaper cached for instant resume, but release the
    // per-widget mask and blur targets during fullscreen/GameMode pauses.
    layer.enabled: root._glass && root.visible && root.powerActive
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
        // Don't load/blur when the compositor is already blurring underneath.
        // Each WidgetSurface keeps its own FBO when layer.enabled is true; with
        // many widgets enabled this multiplies fast. See #159.
        visible: root._glass && status === Image.Ready
        source: root._glass ? root._wallpaperUrl : ""
        fillMode: Image.PreserveAspectCrop
        cache: true
        asynchronous: true
        sourceSize.width: Math.round(root.screenWidth * root._blurScale)
        sourceSize.height: Math.round(root.screenHeight * root._blurScale)

        // OPTIMIZATION: Release FBO when widget is not visible or power is off
        layer.enabled: root._glass && root.visible && root.powerActive
        layer.smooth: true
        layer.textureSize: Qt.size(Math.round(width * root._blurScale),
                                   Math.round(height * root._blurScale))
        layer.effect: MultiEffect {
            source: blurredWallpaper
            anchors.fill: source
            saturation: root._angel
                ? (Appearance.angel.blurSaturation * Appearance.angel.colorStrength)
                : 0.15
            blurEnabled: true
            blurMax: Math.max(1, Math.round(64 * root._blurScale))
            blur: root._angel ? Appearance.angel.blurIntensity
                : root._islandGlass ? (Config.options?.appearance?.island?.glassBlur ?? 1)
                : 0.8
        }
    }

    // Tinted overlay for aurora/angel — island tints with its own gradient below.
    Rectangle {
        anchors.fill: parent
        visible: root._glass && !root._island
        color: root._angel
            ? ColorUtils.transparentize(Appearance.colors.colLayer0Base, Appearance.angel.overlayOpacity)
            : ColorUtils.transparentize(Appearance.colors.colLayer0Base, Appearance.aurora.popupTransparentize * 1.2)
    }

    // Island card: washi gradient + hairline border + lit top sheen (the blur
    // above provides the glass; screenX/Y keep its crop aligned per widget).
    Rectangle {
        id: islandCard
        anchors.fill: parent
        visible: root._island && (root._backgroundVisible
            || (root.surfaceBorderWidth > 0 && root.surfaceBorderOpacity > 0))
        radius: root.radius
        border.width: root.surfaceBorderWidth
        border.color: ColorUtils.applyAlpha(Appearance.colors.colLayer0Border,
            root.surfaceBorderOpacity)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(Appearance.colors.colLayer3,
                root._islandOpacity * root._plateAlpha) }
            GradientStop { position: 1.0; color: Qt.alpha(Appearance.colors.colLayer1,
                root._islandOpacity * root._plateAlpha) }
        }
        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors.topMargin: 1
            anchors.leftMargin: islandCard.radius * 0.6
            anchors.rightMargin: islandCard.radius * 0.6
            height: 1
            visible: root._backgroundVisible && (Config.options?.appearance?.island?.sheen ?? true)
            color: Qt.alpha(Appearance.colors.colOnLayer0, 0.07)
        }
    }

    // Inset glow — angel only
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: Appearance.angel.insetGlowHeight
        visible: root._angel && root._backgroundVisible
        color: Appearance.angel.colInsetGlow
    }

    // Partial border — angel only
    AngelPartialBorder {
        visible: root._angel && root.surfaceBorderWidth > 0 && root.surfaceBorderOpacity > 0
        targetRadius: root.radius
        borderWidth: Math.max(1, root.surfaceBorderWidth)
        borderColor: ColorUtils.applyAlpha(Appearance.angel.colBorder,
            root.surfaceBorderOpacity)
    }

    // Inir subtle fill
    Rectangle {
        anchors.fill: parent
        visible: root._inir && root._backgroundVisible
        radius: root.radius
        color: ColorUtils.applyAlpha(root._plate, Math.min(0.96, 0.72 + root.surfaceOpacity * 0.24))
    }
}
