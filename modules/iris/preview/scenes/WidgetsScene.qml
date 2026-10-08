pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.background.widgets
import qs.modules.background.widgets.instrument
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview.parts

PreviewScene {
    id: widgetsRoot
    readonly property real naturalWidth: Math.round(620 * widgetsRoot.d)
    readonly property real naturalHeight: Math.round(260 * widgetsRoot.d)
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
        ? ColorUtils.applyAlpha(IrisStyle.surface, widgetsRoot.clear && !Boolean(widgetsRoot.opt("iris.widgets.legibleAlways", false)) ? 0
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
        visible: widgetsRoot.on
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
        ColumnLayout {
            anchors.left: parent.left; anchors.bottom: parent.bottom
            anchors.margins: Math.round(18 * widgetsRoot.d)
            anchors.bottomMargin: widgetsRoot.instrument ? Math.round(44 * widgetsRoot.d) : Math.round(18 * widgetsRoot.d)
            anchors.leftMargin: widgetsRoot.instrument ? Math.round(60 * widgetsRoot.d) : Math.round(18 * widgetsRoot.d)
            spacing: 0
            IrisText { text: Translation.locale.toString(DateTime.clock.date, "dddd"); color: widgetsRoot.ink; font.weight: widgetsRoot.weight; font.pixelSize: IrisStyle.typeHeadline }
            IrisText {
                text: Translation.locale.toString(DateTime.clock.date, "hh:mm")
                font.family: IrisStyle.fontNumbers
                font.weight: widgetsRoot.weight
                font.pixelSize: (widgetsRoot.instrument ? 36 : 52) * IrisStyle.typeScale
                style: widgetsRoot.clear ? Text.Raised : Text.Normal
                styleColor: IrisStyle.plateShadow
            }
        }
    }
    Rectangle {
        visible: widgetsRoot.on
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
            spacing: Math.round(2 * widgetsRoot.d)
            MaterialSymbol { text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"; fill: 1; iconSize: Math.round(30 * widgetsRoot.d); color: widgetsRoot.ink }
            Item { Layout.fillHeight: true }
            IrisText { text: String(Weather.data?.temp ?? "18°"); font.family: IrisStyle.fontNumbers; font.weight: widgetsRoot.weight; font.pixelSize: 34 * IrisStyle.typeScale }
            IrisText { text: Weather.data?.city ?? Translation.tr("Weather"); color: IrisStyle.subtext; elide: Text.ElideRight; Layout.fillWidth: true }
        }
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
