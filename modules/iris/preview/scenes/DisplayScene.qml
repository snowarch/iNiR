pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview.parts

// The screen as it is: its warmth when Night Light is on (deeper as the warmth drops), when it comes on by itself, and
// what Niri drives it at.
PreviewScene {
    id: displayRoot
    readonly property bool night: displayRoot.opt("light.night.enabled", false) === true
    readonly property bool scheduled: displayRoot.opt("light.night.automatic", false) === true
    readonly property string from: String(displayRoot.opt("light.night.from", "19:00"))
    readonly property string until: String(displayRoot.opt("light.night.to", "06:30"))
    readonly property real kelvin: Number(displayRoot.opt("light.night.colorTemperature", 5000))
    readonly property bool soften: displayRoot.opt("light.antiFlashbang.enable", false) === true
    readonly property var screen: GlobalStates.focusedScreen
    readonly property string mode: displayRoot.screen ? `${displayRoot.screen.width} × ${displayRoot.screen.height}` : ""
    readonly property string rate: String(displayRoot.niri("display", "rate", ""))
    readonly property real naturalWidth: Math.round(620 * displayRoot.d)
    readonly property real naturalHeight: Math.round(300 * displayRoot.d)
    narrowest: Math.round(400 * displayRoot.d)
    lowest: Math.round(220 * displayRoot.d)

    // Night Light: the wallpaper under a warm wash, as strong as the warmth asked for.
    Rectangle {
        anchors.fill: parent
        color: IrisStyle.identity.orange
        opacity: displayRoot.night ? Math.max(0.08, Math.min(0.42, (6500 - displayRoot.kelvin) / 9000)) : 0
        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(260); easing.type: IrisStyle.feedbackEasing } }
    }

    Plate {
        id: modePlate
        surface: "cards"
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Math.round(18 * displayRoot.d)
        width: modeRow.implicitWidth + Math.round(28 * displayRoot.d)
        height: Math.round(44 * displayRoot.d)
        radius: IrisStyle.capsule(height)
        RowLayout {
            id: modeRow
            anchors.centerIn: parent
            spacing: Math.round(8 * displayRoot.d)
            MaterialSymbol { text: "desktop_windows"; iconSize: Math.round(18 * displayRoot.d); color: IrisStyle.subtext }
            IrisText { text: displayRoot.mode; font.family: IrisStyle.fontNumbers; font.features: ({ "tnum": 1 }); font.weight: IrisStyle.weight(Font.DemiBold) }
            IrisText { visible: displayRoot.rate.length > 0; text: displayRoot.rate; color: IrisStyle.subtext }
        }
    }

    Plate {
        surface: "cards"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: nightRow.implicitWidth + Math.round(36 * displayRoot.d)
        height: Math.round(64 * displayRoot.d)
        radius: IrisStyle.radiusPlate
        own: IrisStyle.identity.orange
        RowLayout {
            id: nightRow
            anchors.centerIn: parent
            spacing: Math.round(12 * displayRoot.d)
            IrisSquircle {
                implicitWidth: Math.round(36 * displayRoot.d)
                implicitHeight: implicitWidth
                tint: displayRoot.night ? IrisStyle.identity.orange : IrisStyle.identity.gray
                glyph: displayRoot.night ? "nightlight" : "light_mode"
            }
            ColumnLayout {
                spacing: Math.round(2 * displayRoot.d)
                IrisText {
                    text: Translation.tr("Night Light")
                    font.pixelSize: IrisStyle.typeHeadline
                    font.weight: IrisStyle.weight(Font.DemiBold)
                }
                IrisText {
                    text: displayRoot.scheduled ? `${displayRoot.from} – ${displayRoot.until}` : displayRoot.night ? `${Math.round(displayRoot.kelvin)} K` : Translation.tr("Off")
                    color: IrisStyle.subtext
                    font.family: IrisStyle.fontNumbers
                    font.features: ({ "tnum": 1 })
                }
            }
            IrisSwitch { on: displayRoot.night; enabled: false; name: Translation.tr("Night Light") }
        }
    }

    Caption {
        glyph: displayRoot.night ? "nightlight" : "brightness_6"
        text: [displayRoot.night ? Translation.tr("Night Light") + " " + Math.round(displayRoot.kelvin) + " K" : "",
            displayRoot.soften ? Translation.tr("Soften bright flashes") : "", displayRoot.mode].filter(part => part.length > 0).join(" · ")
    }
}
