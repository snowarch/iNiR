pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.components
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
    // In the light scheme a plate is light, so its ink is the dark one; a bare widget still follows the wallpaper.
    // A glass face is the shell's material in every scheme, veiled as reading needs: turning it white over a bright region
    // left white cards among a dark shell. Only a transparent face, which has no material, follows the wallpaper.
    readonly property bool lightBackdrop: IrisStyle.light && !root.clear ? true : root.clear ? root.widget.inkOnLight
        : root.widget.forceDarkInk
    readonly property bool ownInk: root.lightBackdrop || (IrisStyle.light && root.clear)
    // A paper scheme's face is the shell's paper with the shell's own ink and accents, as the quick-controls sheet is;
    // the light-backdrop path (white frost, accents deepened to 0.3-0.4 lightness) turned orange brown there.
    readonly property bool paper: IrisStyle.light && !root.clear
    readonly property real textShadow: root.clear ? 1
        : root.glass && !root.widget.legibleAlways ? Math.min(1, (1 - root.strength) * 1.4) : 0
    readonly property real veil: root.opaque ? root.strength
        : root.clear && !root.widget.legibleAlways ? 0
        : (root.paper ? IrisStyle.legibleVeil(root.readMaterial, root.frostLevel, root.readSpread, 1)
            : root.lightBackdrop ? IrisStyle.legibleFrost(root.readMaterial, root.frostLevel, root.readSpread, 1)
            : IrisStyle.legibleVeil(root.readMaterial, root.readLevel, root.readSpread, 1))
            * (root.widget.legibleAlways ? 1 : root.paperGlass ? 0.52 + 0.48 * root.strength : root.strength)
    // On paper, Surface opacity thins a frost; it never turns the face into clear glass lit by the wallpaper's colour.
    readonly property bool paperGlass: root.paper && root.glass
    // Lume on every widget: the veil (light ink) is solved as if the region were bright and busy, the frost
    // (dark ink) as if it were dim and busy.
    readonly property real readLevel: root.widget.legibleAlways ? Math.max(0.72, root.widget.regionBrightness) : root.widget.regionBrightness
    // ...and to the contrast of a reading panel (7:1), so Transparent and Glass both carry a real backing.
    readonly property string readMaterial: root.widget.legibleAlways ? "panel" : root.material
    readonly property real frostLevel: root.widget.legibleAlways ? Math.min(0.5, root.widget.regionBrightness) : root.widget.regionBrightness
    readonly property real readSpread: root.widget.legibleAlways ? Math.max(0.24, root.widget.regionBrightnessSpread) : root.widget.regionBrightnessSpread

    // One palette: the widget's data colours and the shell's status colours. Only a face that is not paper and sits over a
    // light region (a transparent face, or forced dark ink) solves them again, against what Lume read behind it.
    readonly property bool resolvesMarks: root.lightBackdrop && !root.paper
    readonly property real seenLevel: root.clear ? root.widget.regionBrightness
        : root.widget.regionBrightness * (1 - root.veil) + Math.pow(ColorUtils.relativeLuminance(IrisStyle.frost), 1 / 2.2) * root.veil
    function mark(seed: color): color {
        return root.resolvesMarks ? Lume.mark(seed, root.seenLevel, root.clear ? root.readSpread : 0, true, 3) : seed
    }
    readonly property color accent: root.mark(root.widget.irisAccent)
    readonly property color highlight: root.mark(root.widget.irisAccent3)
    readonly property color accent2: root.mark(root.widget.irisAccent2)
    readonly property color warm: root.mark(IrisStyle.secondaryAccent)
    readonly property color danger: root.mark(IrisStyle.danger)
    readonly property color ink: root.paper ? IrisStyle.text : root.lightBackdrop ? IrisStyle.inkOnLight : IrisStyle.light ? IrisStyle.inkOnDark : IrisStyle.text
    readonly property color inkSecondary: IrisStyle.secondaryOf(root.ink)
    readonly property color inkTertiary: IrisStyle.tertiaryOf(root.ink)
    readonly property color fillQuiet: root.ownInk ? IrisStyle.fillQuietOf(root.ink) : IrisStyle.fillQuiet
    readonly property color fill: root.ownInk ? IrisStyle.fillOf(root.ink) : IrisStyle.fill
    readonly property color fillHover: root.ownInk ? IrisStyle.fillHoverOf(root.ink) : IrisStyle.fillHover
    readonly property color fillActive: root.ownInk ? IrisStyle.fillActiveOf(root.ink) : IrisStyle.fillActive
    readonly property color hairline: root.ownInk ? IrisStyle.hairlineOf(root.ink) : IrisStyle.hairline
    // Ink on a filled accent: light on the deep accents of a light face, the Island's dark otherwise.
    function onFill(tint: color): color { return IrisStyle.onTintFor(tint) }
    readonly property int figureWeight: root.widget.widgetTitleWeight
    readonly property string fontMain: IrisStyle.fontMain
    readonly property string fontNumbers: IrisStyle.fontNumbers
    // Outline: Auto follows the shell's outline and leaves Transparent bare; while arranging it always shows.
    readonly property bool rimShown: GlobalStates.widgetEditMode || root.widget.irisOutline === "always"
        || (root.widget.irisOutline === "auto" && (!root.clear || root.widget.irisRim))
    readonly property bool glassEdge: (root.glass || IrisStyle.edgeLit) && !root.lightBackdrop
        && (IrisStyle.glassEdgeLight > 0 || IrisStyle.glassEdgeLine > 0)
    readonly property bool flatRim: root.rimShown && !root.glassEdge
        && !(root.glass && !root.lightBackdrop && root.widget.irisOutline === "auto" && !GlobalStates.widgetEditMode)
    readonly property color plateColor: ColorUtils.applyAlpha(root.opaque ? root.widget.irisPlate
        : root.lightBackdrop && !root.paper ? IrisStyle.frost : IrisStyle.surface, root.veil)
    readonly property color knockout: root.opaque ? root.plateColor : root.lightBackdrop && !root.paper ? IrisStyle.frost : IrisStyle.surface

    // In a stack the plate stays and the pages' contents slide over it (DesktopWidgetStacks).
    readonly property bool stacked: root.widget.stacked
    readonly property real slide: root.widget.stackPos
    readonly property bool plated: !root.stacked || root.widget.stackShown

    function dp(value: real): real { return Math.round(value * root.k) }
    function px(value: real): real { return Math.round(value * root.t) }

    // A shadow under glass shows through it: the body darkens toward its middle and its top edge reads as a glow.
    RectangularShadow {
        anchors.fill: parent
        visible: root.opaque && root.plated
        radius: root.radius
        blur: root.dp(28)
        spread: -root.dp(4)
        offset.y: root.dp(8)
        color: root.glass ? IrisStyle.glassShadow : IrisStyle.plateShadow
    }

    Loader {
        anchors.fill: parent
        active: root.glass
        visible: root.plated
        sourceComponent: ClippingRectangle {
            id: glassPane
            // The desktop's own wallpaper layer, parallax included, no second decoder. It is copied again only when
            // the layer or this widget moved: copying it every frame the desktop redraws (music playing, a clock)
            // cost the shell 17 % CPU with Afterglow against 6 % for solid widgets.
            readonly property var host: root.QsWindow?.window ?? null
            readonly property Item desktopLayer: glassPane.host?.wallpaperLayer ?? null
            readonly property int layerRevision: glassPane.host?.wallpaperLayerRevision ?? 0
            readonly property bool moving: settling.running || GlobalStates.widgetEditMode
                || Boolean(glassPane.host?.wallpaperLayerAnimating)
            readonly property point at: {
                void (root.widget.x + root.widget.y + (root.widget.parent?.x ?? 0) + (root.widget.parent?.y ?? 0))
                return glassPane.desktopLayer ? root.mapToItem(glassPane.desktopLayer, 0, 0) : Qt.point(root.widget.x, root.widget.y)
            }
            // Parallax and Afterglow's fade run up to about a second after the bump that announced them.
            Timer { id: settling; interval: 1500 }
            onLayerRevisionChanged: settling.restart()
            onAtChanged: crop.scheduleUpdate()
            onWidthChanged: crop.scheduleUpdate()
            onHeightChanged: crop.scheduleUpdate()
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
                onStatusChanged: crop.scheduleUpdate()
            }

            ShaderEffectSource {
                id: crop
                x: -glassPane.margin
                y: -glassPane.margin
                width: root.width + glassPane.margin * 2
                height: root.height + glassPane.margin * 2
                sourceItem: glassPane.desktopLayer ?? wallpaper
                live: glassPane.moving
                sourceRect: Qt.rect(glassPane.at.x - glassPane.margin, glassPane.at.y - glassPane.margin, crop.width, crop.height)
                textureSize: Qt.size(Math.max(1, Math.round(crop.width / 2)), Math.max(1, Math.round(crop.height / 2)))
                smooth: true
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: IrisStyle.glassBlurAmount
                    blurMax: IrisStyle.glassBlurMax
                    saturation: IrisStyle.widgetGlassSaturation
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.plated
        radius: root.radius
        color: root.plateColor
        border.width: root.flatRim ? 1 : 0
        border.color: root.lightBackdrop ? root.hairline : root.clear || IrisStyle.rim.a === 0 ? IrisStyle.clearRim : IrisStyle.rim
        Behavior on color { ColorAnimation { duration: IrisStyle.revealDuration; easing.type: IrisStyle.feedbackEasing } }
        Behavior on border.width { NumberAnimation { duration: IrisStyle.revealDuration; easing.type: IrisStyle.feedbackEasing } }
    }

    IrisGlassEdge {
        anchors.fill: parent
        visible: root.glassEdge && root.rimShown && root.plated
        radius: root.radius
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        visible: !root.clear && root.light.a > 0
        opacity: (root.glass ? IrisStyle.glassWash : 1) * (1 - Math.min(1, Math.abs(root.slide)))
        radius: Math.max(0, root.radius - 1)
        gradient: Gradient {
            GradientStop { position: 0; color: IrisStyle.skyWash(root.light) }
            GradientStop { position: 1; color: IrisStyle.skyWashFade(root.light) }
        }
    }

    // Pages slide inside the plate's box and are cut at its edge while they move.
    Item {
        id: viewport
        anchors.fill: parent
        clip: root.stacked && root.slide !== 0

        Item {
            id: slider
            width: viewport.width
            height: viewport.height
            // The page travels half its height while it fades, so two pages cross instead of one pushing the other out.
            y: Math.round(root.slide * root.height * 0.5)
            opacity: 1 - Math.pow(Math.min(1, Math.abs(root.slide)), 1.5)

            ShaderEffectSource {
                id: bodyCopy
                anchors.fill: body
                sourceItem: root.textShadow > 0.05 ? body : null
                hideSource: false
                visible: false
            }
            // The shadow comes from a copy behind the body: a layered body would resample its text.
            MultiEffect {
                x: body.x
                y: body.y + 1
                width: body.width
                height: body.height
                visible: root.textShadow > 0.05
                source: bodyCopy
                brightness: root.lightBackdrop ? 1 : -1
                colorization: IrisStyle.glow > 0 && !root.lightBackdrop ? 1 : 0
                colorizationColor: Qt.rgba(IrisStyle.plateShadow.r, IrisStyle.plateShadow.g, IrisStyle.plateShadow.b, 1)
                blurEnabled: true
                blur: 0.5
                autoPaddingEnabled: true
                opacity: (root.lightBackdrop ? IrisStyle.frostShadow : IrisStyle.plateShadow.a) * root.textShadow
            }

            Item {
                id: body
                anchors.fill: parent
                anchors.margins: root.padding
            }
        }
    }

    // Carried over by another widget: this is where it will land.
    Rectangle {
        z: 140
        anchors.fill: parent
        radius: root.radius
        visible: opacity > 0
        opacity: root.widget.stackDropHint ? 1 : 0
        color: IrisStyle.tintFill(root.accent)
        border.width: 2
        border.color: root.accent
        Behavior on opacity { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }

        Rectangle {
            anchors.centerIn: parent
            width: root.dp(44)
            height: width
            radius: IrisStyle.iconRadius(width)
            scale: root.widget.stackDropHint ? 1 : 0.8
            Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
            gradient: Gradient {
                GradientStop { position: 0; color: IrisStyle.tileTop(root.accent) }
                GradientStop { position: 1; color: root.accent }
            }
            MaterialSymbol {
                anchors.centerIn: parent
                text: "stacks"
                fill: 1
                iconSize: root.dp(24)
                color: root.onFill(root.accent)
            }
        }
    }

    Loader {
        active: root.stacked
        z: 150
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: active && root.widget.stackShown
        sourceComponent: IrisStackDots { face: root }
    }

    // Wheel over a stack turns its page, one per gesture: a touchpad's tail is held off until the page has settled.
    property real _wheel: 0
    Timer { id: wheelHold; interval: 360 }
    Timer { id: wheelReset; interval: 260; onTriggered: root._wheel = 0 }
    WheelHandler {
        enabled: root.stacked && root.widget.stackShown
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (wheelHold.running)
                return
            root._wheel += event.angleDelta.y
            wheelReset.restart()
            if (Math.abs(root._wheel) < 120)
                return
            const forward = root._wheel < 0
            root._wheel = 0
            wheelHold.restart()
            DesktopWidgetStacks.step(root.widget.outputName, root.widget.stack.id, forward ? 1 : -1)
        }
    }

    // A stack holds its page while the pointer is on it or the widget is being carried.
    HoverHandler {
        id: stackHover
        enabled: root.stacked
    }
    readonly property bool _holding: root.stacked && root.widget.stackShown && (stackHover.hovered || root.widget.containsPress)
    on_HoldingChanged: if (root.stacked) DesktopWidgetStacks.setHovered(root.widget.stack.id, root._holding)
}
