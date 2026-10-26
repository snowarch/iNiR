pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.shared.background.widgets
import qs.modules.shared.background.widgets.instrument
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview.parts
import qs.modules.iris.widgets

PreviewScene {
    id: widgetsRoot
    subject: Qt.rect(widgetsRoot.plateX, widgetsRoot.plateY, widgetsRoot.wide + widgetsRoot.gap + widgetsRoot.unit, widgetsRoot.unit)
    readonly property real naturalWidth: Math.round(620 * widgetsRoot.d)
    readonly property real naturalHeight: Math.round(260 * widgetsRoot.d)
    narrowest: Math.round(480 * widgetsRoot.d)
    lowest: Math.round(190 * widgetsRoot.d)
    readonly property bool on: widgetsRoot.opt("iris.modules.desktopWidgets", true)
    readonly property string design: DesktopWidgetDesign.current
    readonly property bool iris: widgetsRoot.design === "iris"
    readonly property bool instrument: widgetsRoot.design === "instrument"
    readonly property bool bare: widgetsRoot.instrument || widgetsRoot.design === "readout"
    readonly property string material: String(widgetsRoot.opt("iris.widgets.material", "glass"))
    readonly property bool glass: widgetsRoot.iris && widgetsRoot.material === "glass"
    readonly property bool clear: widgetsRoot.bare || (widgetsRoot.iris && widgetsRoot.material === "clear")
    readonly property color ink: String(widgetsRoot.opt("iris.widgets.tint", "wallpaper")) === "wallpaper" ? IrisStyle.wallpaperLight : IrisStyle.accent
    readonly property int weight: ({ light: Font.Light, regular: Font.Medium, bold: Font.Bold })[String(widgetsRoot.opt("iris.widgets.weight", "regular"))] ?? Font.Medium
    readonly property real strength: Math.max(0.2, Math.min(1, Number(widgetsRoot.opt("iris.widgets.opacity", 100)) / 100))
    readonly property string outline: String(widgetsRoot.opt("iris.widgets.outline", "auto"))
    readonly property bool rimShown: !widgetsRoot.bare && widgetsRoot.iris && (widgetsRoot.outline === "always"
        || (widgetsRoot.outline === "auto" && (!widgetsRoot.clear || Boolean(widgetsRoot.opt("iris.widgets.rim", false)))))
    readonly property bool edgeLit: widgetsRoot.rimShown && (widgetsRoot.glass || IrisStyle.edgeLit) && (IrisStyle.glassEdgeLight > 0 || IrisStyle.glassEdgeLine > 0)
    readonly property real plateRadius: Math.round(Math.max(0, Math.min(40, Number(widgetsRoot.opt("iris.widgets.radius", 22)))) * widgetsRoot.d)
    readonly property real unit: Math.round(170 * widgetsRoot.d)
    readonly property real wide: Math.round(250 * widgetsRoot.d)
    readonly property real gap: Math.round(16 * widgetsRoot.d)
    readonly property real plateX: Math.round((widgetsRoot.width - widgetsRoot.wide - widgetsRoot.gap - widgetsRoot.unit) / 2)
    readonly property real plateY: Math.round((widgetsRoot.height - widgetsRoot.unit) / 2)
    readonly property color plateColor: widgetsRoot.bare ? "transparent" : !widgetsRoot.iris ? Appearance.colors.colLayer2 : widgetsRoot.glass || widgetsRoot.clear
        ? ColorUtils.applyAlpha(IrisStyle.surface, widgetsRoot.clear ? 0
            : IrisStyle.legibleVeil(widgetsRoot.material, 0, 0, 1)
                * (Boolean(widgetsRoot.opt("iris.widgets.legibleAlways", false)) ? 1 : widgetsRoot.strength))
        : ColorUtils.applyAlpha(widgetsRoot.material === "tinted"
            ? ColorUtils.mix(IrisStyle.surface, Appearance.colors.colPrimary, 0.82) : IrisStyle.surface, widgetsRoot.strength)

    ShaderEffectSource {
        id: widgetsWall
        anchors.fill: parent
        visible: false
        sourceItem: widgetsRoot.glass ? widgetsRoot.wallpaperView.textureItem : null
        live: true
    }
    Repeater {
        model: widgetsRoot.on && widgetsRoot.glass ? [
            Qt.rect(widgetsRoot.plateX, widgetsRoot.plateY, widgetsRoot.wide, widgetsRoot.unit),
            Qt.rect(widgetsRoot.plateX + widgetsRoot.wide + widgetsRoot.gap, widgetsRoot.plateY, widgetsRoot.unit, widgetsRoot.unit)
        ] : []
        ClippingRectangle {
            id: frost
            required property rect modelData
            x: frost.modelData.x
            y: frost.modelData.y
            width: frost.modelData.width
            height: frost.modelData.height
            radius: widgetsRoot.plateRadius
            color: "transparent"
            MultiEffect {
                x: -frost.x
                y: -frost.y
                width: widgetsRoot.width
                height: widgetsRoot.height
                source: widgetsWall
                autoPaddingEnabled: false
                blurEnabled: true
                blur: IrisStyle.glassBlurAmount
                blurMax: IrisStyle.glassBlurMax
                saturation: IrisStyle.glassSaturation
            }
        }
    }

    Rectangle {
        visible: widgetsRoot.on && !widgetsRoot.printed
        x: widgetsRoot.plateX
        y: widgetsRoot.plateY
        width: widgetsRoot.wide
        height: widgetsRoot.unit
        radius: widgetsRoot.plateRadius
        color: widgetsRoot.plateColor
        border.width: widgetsRoot.rimShown && !widgetsRoot.edgeLit ? 1 : 0
        border.color: widgetsRoot.clear || IrisStyle.rim.a === 0 ? IrisStyle.clearRim : IrisStyle.rim
        IrisGlassEdge { anchors.fill: parent; visible: widgetsRoot.edgeLit; radius: parent.radius }
        InstrumentRing {
            anchors.fill: parent
            anchors.margins: Math.round(4 * widgetsRoot.d)
            visible: widgetsRoot.instrument
            fraction: DateTime.clock.date.getMinutes() / 60
            ink: IrisStyle.onMedia
            accent: widgetsRoot.ink
            accentSoft: IrisStyle.secondaryAccent
            showArc: false
            showComet: false
            animated: false
        }
        // The Day as the iRiS face draws it: the next sunrise or sunset leading, the day as the sun's path.
        ColumnLayout {
            visible: !widgetsRoot.instrument
            anchors.fill: parent
            anchors.margins: Math.round(18 * widgetsRoot.d)
            spacing: Math.round(2 * widgetsRoot.d)
            FaceHeader {
                face: widgetsRoot.face
                Layout.fillWidth: true
                glyph: widgetsRoot.daytime ? "light_mode" : "bedtime"
                text: IrisFaceData.capitalized(Translation.locale.toString(DateTime.clock.date, "dddd d"))
                tint: widgetsRoot.face.warm
            }
            Row {
                spacing: Math.round(6 * widgetsRoot.d)
                FaceFigure { id: sunFigure; face: widgetsRoot.face; text: widgetsRoot.sunParts.main; size: 34 }
                FaceText {
                    face: widgetsRoot.face
                    visible: widgetsRoot.sunParts.suffix.length > 0
                    anchors.baseline: sunFigure.baseline
                    text: widgetsRoot.sunParts.suffix
                    color: widgetsRoot.face.inkSecondary
                    size: 15
                    weight: Font.DemiBold
                }
                FaceText {
                    face: widgetsRoot.face
                    anchors.baseline: sunFigure.baseline
                    text: widgetsRoot.daytime ? Translation.tr("Sunset") : Translation.tr("Sunrise")
                    color: widgetsRoot.face.inkSecondary
                    size: 13
                }
            }
            FaceArea {
                face: widgetsRoot.face
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: Math.round(6 * widgetsRoot.d)
                curve: t => widgetsRoot.sunAt(t)
                from: widgetsRoot.sunrise
                to: widgetsRoot.sunset
                upTo: Math.max(widgetsRoot.sunrise, Math.min(widgetsRoot.sunset, widgetsRoot.nowAt))
                rest: true
                tint: widgetsRoot.face.warm
            }
        }
    }
    Rectangle {
        visible: widgetsRoot.on && !widgetsRoot.printed
        x: widgetsRoot.plateX + widgetsRoot.wide + widgetsRoot.gap
        y: widgetsRoot.plateY
        width: widgetsRoot.unit
        height: widgetsRoot.unit
        radius: widgetsRoot.plateRadius
        color: widgetsRoot.plateColor
        border.width: widgetsRoot.rimShown && !widgetsRoot.edgeLit ? 1 : 0
        border.color: widgetsRoot.clear || IrisStyle.rim.a === 0 ? IrisStyle.clearRim : IrisStyle.rim
        IrisGlassEdge { anchors.fill: parent; visible: widgetsRoot.edgeLit; radius: parent.radius }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Math.round(18 * widgetsRoot.d)
            spacing: 0
            FaceText { face: widgetsRoot.face; Layout.fillWidth: true; text: String(Weather.visibleCity ?? "").split(",")[0] || Translation.tr("Weather"); size: 13.5; weight: Font.DemiBold }
            FaceFigure { face: widgetsRoot.face; text: String(Weather.data?.temp ?? "18°").replace(/°[CF]$/, "°"); size: 40 }
            Item { Layout.fillHeight: true }
            MaterialSymbol { text: widgetsRoot.sky; fill: 1; iconSize: Math.round(18 * widgetsRoot.d); color: IrisStyle.skyLight(widgetsRoot.sky) }
            FaceText { face: widgetsRoot.face; Layout.fillWidth: true; text: IrisFaceData.capitalized(String(Weather.data?.description ?? "")); size: 12.5; weight: Font.DemiBold }
        }
    }
    // What the face parts read, as a widget face would hand it to them, in this scene's options.
    readonly property var face: ({
        small: false, medium: true, large: false, nothing: false, moving: false,
        dp: v => Math.round(v * widgetsRoot.d), px: v => Math.round(v * widgetsRoot.d * IrisStyle.typeScale),
        ink: IrisStyle.text, inkSecondary: IrisStyle.subtext, inkTertiary: IrisStyle.textTertiary,
        hairline: IrisStyle.hairline, fillActive: IrisStyle.fillActive, accent: widgetsRoot.ink, highlight: widgetsRoot.ink,
        warm: IrisStyle.secondaryAccent, figureWeight: widgetsRoot.weight,
        fontMain: IrisStyle.fontMain, fontNumbers: IrisStyle.fontNumbers, fontLabel: IrisStyle.fontLabel })
    readonly property string sky: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
    readonly property real nowAt: (DateTime.clock.date.getHours() * 60 + DateTime.clock.date.getMinutes()) / 1440
    readonly property real sunriseAt: Weather._timeToMinutes(Weather.data?.sunrise) / 1440
    readonly property real sunsetAt: Weather._timeToMinutes(Weather.data?.sunset) / 1440
    readonly property bool sunKnown: widgetsRoot.sunriseAt >= 0 && widgetsRoot.sunsetAt > widgetsRoot.sunriseAt
    readonly property real sunrise: widgetsRoot.sunKnown ? widgetsRoot.sunriseAt : 6 / 24
    readonly property real sunset: widgetsRoot.sunKnown ? widgetsRoot.sunsetAt : 19 / 24
    readonly property bool daytime: widgetsRoot.nowAt >= widgetsRoot.sunrise && widgetsRoot.nowAt < widgetsRoot.sunset
    readonly property var sunParts: IrisFaceData.timeParts(widgetsRoot.sunKnown
        ? String(widgetsRoot.daytime ? Weather.data?.sunset : Weather.data?.sunrise) : (widgetsRoot.daytime ? "7:00 PM" : "6:00 AM"))
    // The sun's height over the day: a cosine around noon, from the horizon at sunrise to it at sunset.
    function sunAt(t: real): real {
        const noon = (widgetsRoot.sunrise + widgetsRoot.sunset) / 2
        const c = Math.cos(Math.PI * (widgetsRoot.sunset - widgetsRoot.sunrise))
        return Math.max(0, (Math.cos(2 * Math.PI * (t - noon)) - c) / Math.max(0.01, 1 - c))
    }
    // A Design that prints the clock and the weather shows its own prints here, on stand-in faces fed by the live clock
    // and forecast (the widgets themselves are not instantiated).
    readonly property bool printed: widgetsRoot.iris && IrisDesign.has("widgetClock") && IrisDesign.has("widgetWeather")
    readonly property var standIn: ({
        small: true, medium: false, large: false,
        dp: v => Math.round(v * widgetsRoot.d), px: v => Math.round(v * widgetsRoot.d * IrisStyle.typeScale),
        clear: widgetsRoot.clear, material: widgetsRoot.material, accent: IrisStyle.accent, accent2: IrisStyle.secondaryAccent,
        opaque: !widgetsRoot.glass && !widgetsRoot.clear, strength: widgetsRoot.strength, veil: 0, plated: !widgetsRoot.clear,
        moving: false, ink: IrisStyle.onMedia, inkSecondary: IrisStyle.onMediaSecondary, inkTertiary: IrisStyle.onMediaTertiary,
        analog: false, seconds: false, now: DateTime.clock.date,
        timeText: Translation.locale.toString(DateTime.clock.date, "hh:mm"),
        weekday: Translation.locale.toString(DateTime.clock.date, "dddd"),
        longDate: Translation.locale.toString(DateTime.clock.date, "d MMMM"),
        ready: true, city: String(Weather.visibleCity ?? "").split(",")[0], condition: String(Weather.data?.description ?? ""),
        glyph: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud", range: "", hours: [], days: [],
        weekLow: 0, weekHigh: 1, degrees: v => String(v ?? ""),
        widget: ({ temperatureText: String(Weather.data?.temp ?? "18°") }) })
    Loader {
        active: widgetsRoot.on && widgetsRoot.printed
        x: widgetsRoot.plateX
        y: widgetsRoot.plateY
        width: widgetsRoot.wide
        height: widgetsRoot.unit
        source: IrisDesign.skin("widgetClock")
        onLoaded: item.face = Qt.binding(() => widgetsRoot.standIn)
    }
    Loader {
        active: widgetsRoot.on && widgetsRoot.printed
        x: widgetsRoot.plateX + widgetsRoot.wide + widgetsRoot.gap
        y: widgetsRoot.plateY
        width: widgetsRoot.unit
        height: widgetsRoot.unit
        source: IrisDesign.skin("widgetWeather")
        onLoaded: item.face = Qt.binding(() => widgetsRoot.standIn)
    }
    OffState { visible: !widgetsRoot.on; text: Translation.tr("Desktop widgets off") }
    Caption {
        glyph: widgetsRoot.bare ? "avg_pace" : widgetsRoot.glass ? "blur_on" : widgetsRoot.clear ? "select" : "square"
        text: !widgetsRoot.on ? ""
            : widgetsRoot.instrument ? Translation.tr("Dials, scales and ruled lists")
            : widgetsRoot.design === "readout" ? Translation.tr("Quiet figures and open lists")
            : !widgetsRoot.iris ? Translation.tr("Each widget keeps its Material design")
            : widgetsRoot.glass && Boolean(widgetsRoot.opt("iris.widgets.brightWallpapers", false)) ? Translation.tr("Frosted wallpaper · turns to frost over a bright wallpaper")
            : widgetsRoot.glass ? Translation.tr("Frosted wallpaper · darker only where the wallpaper is bright")
            : widgetsRoot.clear ? Translation.tr("Bare wallpaper · a veil only where text needs it")
            : widgetsRoot.material === "tinted" ? Translation.tr("Black material with a trace of the wallpaper hue")
            : Translation.tr("The Island's black material")
    }
}
