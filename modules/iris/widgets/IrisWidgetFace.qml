pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.iris.style

Item {
    id: root

    required property var widget
    property color light: "transparent"
    property real padding: root.dp(16)
    default property alias content: body.data

    readonly property string size: root.widget.irisSize
    readonly property bool small: root.size === "small"
    readonly property bool medium: root.size === "medium"
    readonly property bool large: root.size === "large"
    readonly property real k: IrisStyle.density * root.widget.scaleFactor
    readonly property real t: IrisStyle.typeScale * root.widget.scaleFactor
    readonly property real radius: root.widget.cornerRadiusOverride >= 0
        ? root.widget.cornerRadiusOverride : Math.round(root.widget.widgetCardRadius * root.widget.scaleFactor)
    readonly property real innerRadius: Math.max(root.dp(6), root.radius - root.padding)
    readonly property real gap: root.dp(10)
    readonly property real contentWidth: root.width - root.padding * 2
    readonly property bool live: root.widget.powerActive && root.widget.visible

    readonly property string material: root.widget.irisMaterial
    readonly property bool glass: root.material === "glass"
    readonly property bool clear: root.material === "clear"
    readonly property bool opaque: !root.glass && !root.clear
    readonly property real strength: root.widget.irisSurfaceOpacity
    // Glass and transparent faces over a light region turn over: frost and near-black ink instead of
    // a veil darkened until the glass is gone. An opaque plate keeps its own polarity.
    readonly property bool lightBackdrop: root.opaque ? root.widget.forceDarkInk
        : root.clear ? root.widget.inkOnLight : root.widget.glassInkOnLight
    readonly property real veil: root.opaque ? root.strength
        : root.lightBackdrop ? IrisStyle.legibleFrost(root.readMaterial, root.frostLevel, root.readSpread, root.strength)
        : IrisStyle.legibleVeil(root.readMaterial, root.readLevel, root.readSpread, root.strength)
    // Lume on every widget: the veil (light ink) is solved as if the region were bright and busy, the frost
    // (dark ink) as if it were dim and busy.
    readonly property real readLevel: root.widget.legibleAlways ? Math.max(0.72, root.widget.regionBrightness) : root.widget.regionBrightness
    // ...and to the contrast of a reading panel (7:1), so Transparent and Glass both carry a real backing.
    readonly property string readMaterial: root.widget.legibleAlways ? "panel" : root.material
    readonly property real frostLevel: root.widget.legibleAlways ? Math.min(0.5, root.widget.regionBrightness) : root.widget.regionBrightness
    readonly property real readSpread: root.widget.legibleAlways ? Math.max(0.24, root.widget.regionBrightnessSpread) : root.widget.regionBrightnessSpread

    readonly property color accent: root.lightBackdrop ? IrisStyle.deepAccent(root.widget.irisAccent, IrisStyle.inkOnLight) : root.widget.irisAccent
    readonly property color highlight: root.lightBackdrop ? IrisStyle.deepAccent(root.widget.irisAccent3, IrisStyle.inkOnLight) : root.widget.irisAccent3
    readonly property color accent2: root.lightBackdrop ? IrisStyle.deepAccent(root.widget.irisAccent2, IrisStyle.inkOnLight) : root.widget.irisAccent2
    readonly property color warm: root.lightBackdrop ? IrisStyle.deepAccent(IrisStyle.secondaryAccent, IrisStyle.inkOnLight) : IrisStyle.secondaryAccent
    readonly property color danger: root.lightBackdrop ? IrisStyle.deepAccent(IrisStyle.danger, IrisStyle.inkOnLight) : IrisStyle.danger
    readonly property color ink: root.lightBackdrop ? IrisStyle.inkOnLight : IrisStyle.text
    readonly property color inkSecondary: IrisStyle.secondaryOf(root.ink)
    readonly property color inkTertiary: IrisStyle.tertiaryOf(root.ink)
    readonly property color fillQuiet: root.lightBackdrop ? IrisStyle.fillQuietOf(root.ink) : IrisStyle.fillQuiet
    readonly property color fill: root.lightBackdrop ? IrisStyle.fillOf(root.ink) : IrisStyle.fill
    readonly property color fillHover: root.lightBackdrop ? IrisStyle.fillHoverOf(root.ink) : IrisStyle.fillHover
    readonly property color fillActive: root.lightBackdrop ? IrisStyle.fillActiveOf(root.ink) : IrisStyle.fillActive
    readonly property color hairline: root.lightBackdrop ? IrisStyle.hairlineOf(root.ink) : IrisStyle.hairline
    // Ink on a filled accent: light on the deep accents of a light face, the Island's dark otherwise.
    function onFill(tint: color): color { return root.lightBackdrop ? IrisStyle.onTint : IrisStyle.onTintFor(tint) }
    readonly property int figureWeight: root.widget.widgetTitleWeight
    readonly property string fontMain: IrisStyle.fontMain
    readonly property string fontNumbers: IrisStyle.fontNumbers
    readonly property bool rimShown: !root.clear || root.widget.irisRim || GlobalStates.widgetEditMode
    readonly property color plateColor: ColorUtils.applyAlpha(root.opaque ? root.widget.irisPlate
        : root.lightBackdrop ? IrisStyle.frost : IrisStyle.surface, root.veil)
    readonly property color knockout: root.opaque ? root.plateColor : root.lightBackdrop ? IrisStyle.frost : IrisStyle.surface

    function dp(value: real): real { return Math.round(value * root.k) }
    function px(value: real): real { return Math.round(value * root.t) }

    RectangularShadow {
        anchors.fill: parent
        visible: !root.clear
        radius: root.radius
        blur: root.dp(28)
        spread: -root.dp(4)
        offset.y: root.dp(8)
        color: root.glass ? IrisStyle.glassShadow : IrisStyle.plateShadow
    }

    Loader {
        anchors.fill: parent
        active: root.glass
        sourceComponent: ClippingRectangle {
            id: glassPane
            // The desktop's own wallpaper layer: live, parallax included, no second decoder.
            readonly property Item desktopLayer: root.QsWindow?.window?.wallpaperLayer ?? null
            readonly property point at: {
                void (root.widget.x + root.widget.y + (root.widget.parent?.x ?? 0) + (root.widget.parent?.y ?? 0))
                return glassPane.desktopLayer ? root.mapToItem(glassPane.desktopLayer, 0, 0) : Qt.point(root.widget.x, root.widget.y)
            }
            visible: glassPane.desktopLayer !== null || wallpaper.status === Image.Ready
            radius: root.radius
            color: "transparent"
            readonly property real margin: root.dp(24)

            Image {
                id: wallpaper
                visible: false
                width: root.widget.screenWidth
                height: root.widget.screenHeight
                source: glassPane.desktopLayer ? "" : WallpaperListener.wallpaperUrlForScreen(root.QsWindow?.window?.screen ?? null)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: Math.round(root.widget.screenWidth / 2)
                sourceSize.height: Math.round(root.widget.screenHeight / 2)
            }

            ShaderEffectSource {
                id: crop
                x: -glassPane.margin
                y: -glassPane.margin
                width: root.width + glassPane.margin * 2
                height: root.height + glassPane.margin * 2
                sourceItem: glassPane.desktopLayer ?? wallpaper
                sourceRect: Qt.rect(glassPane.at.x - glassPane.margin, glassPane.at.y - glassPane.margin, crop.width, crop.height)
                textureSize: Qt.size(Math.max(1, Math.round(crop.width / 2)), Math.max(1, Math.round(crop.height / 2)))
                smooth: true
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: IrisStyle.glassBlur
                    blurMax: IrisStyle.glassBlurMax
                    saturation: IrisStyle.glassSaturation
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.plateColor
        border.width: root.rimShown ? 1 : 0
        border.color: root.lightBackdrop ? root.hairline : root.clear ? IrisStyle.clearRim : IrisStyle.rim
        Behavior on color { ColorAnimation { duration: IrisStyle.revealDuration; easing.type: IrisStyle.feedbackEasing } }
        Behavior on border.width { NumberAnimation { duration: IrisStyle.revealDuration; easing.type: IrisStyle.feedbackEasing } }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        visible: !root.clear && root.light.a > 0
        opacity: root.glass ? IrisStyle.glassWash : 1
        radius: Math.max(0, root.radius - 1)
        gradient: Gradient {
            GradientStop { position: 0; color: IrisStyle.skyWash(root.light) }
            GradientStop { position: 1; color: IrisStyle.skyWashFade(root.light) }
        }
    }

    ShaderEffectSource {
        id: bodyCopy
        anchors.fill: body
        sourceItem: root.clear ? body : null
        hideSource: false
        visible: false
    }
    // The shadow comes from a copy behind the body: a layered body would resample its text.
    MultiEffect {
        x: body.x
        y: body.y + 1
        width: body.width
        height: body.height
        visible: root.clear
        source: bodyCopy
        brightness: root.lightBackdrop ? 1 : -1
        colorization: IrisStyle.glow > 0 && !root.lightBackdrop ? 1 : 0
        colorizationColor: Qt.rgba(IrisStyle.plateShadow.r, IrisStyle.plateShadow.g, IrisStyle.plateShadow.b, 1)
        blurEnabled: true
        blur: 0.5
        autoPaddingEnabled: true
        opacity: root.lightBackdrop ? IrisStyle.frostShadow : IrisStyle.plateShadow.a
    }

    Item {
        id: body
        anchors.fill: parent
        anchors.margins: root.padding
    }
}
