pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview.parts

// Display: the screen itself. Night Light warms it as much as it is set to (on a schedule it follows the sun down
// the arc); a bright window that flashes open is toned down when bright flashes are softened.
PreviewScene {
    id: displayRoot
    readonly property real naturalWidth: Math.round(560 * displayRoot.d)
    readonly property real naturalHeight: Math.round(300 * displayRoot.d)
    narrowest: Math.round(360 * displayRoot.d)
    lowest: Math.round(220 * displayRoot.d)
    subject: Qt.rect(flash.x, flash.y, flash.width, flash.height)
    readonly property bool night: displayRoot.opt("light.night.enabled", false) === true
    readonly property bool scheduled: displayRoot.opt("light.night.automatic", true) === true
    readonly property real kelvin: Number(displayRoot.opt("light.night.colorTemperature", 5000))
    readonly property bool soften: displayRoot.opt("light.antiFlashbang.enable", false) === true
    // 6500 K is plain daylight; 2500 K the warmest it goes.
    readonly property real warmth: Math.max(0, Math.min(1, (6500 - displayRoot.kelvin) / 4000))
    property real t: 1
    Loop on t { running: displayRoot.playing; rest: 1800 }
    readonly property real dusk: displayRoot.scheduled ? displayRoot.t : 1
    readonly property real tint: (displayRoot.night || displayRoot.scheduled) ? displayRoot.warmth * displayRoot.dusk : 0

    // A bright window opening: soft or blinding.
    Rectangle {
        id: flash
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(30 * displayRoot.d)
        width: Math.round(displayRoot.width * 0.46)
        height: Math.round(displayRoot.height * 0.42)
        radius: IrisStyle.radiusPlate
        color: displayRoot.soften ? IrisStyle.surfaceHighestOpaque : IrisStyle.onMedia
        opacity: 0.35 + 0.65 * displayRoot.t
        Behavior on color { ColorAnimation { duration: IrisStyle.duration(260); easing.type: IrisStyle.feedbackEasing } }
        Column {
            x: Math.round(18 * displayRoot.d); y: Math.round(18 * displayRoot.d)
            spacing: Math.round(10 * displayRoot.d)
            Repeater {
                model: [0.7, 0.5, 0.62]
                Rectangle {
                    required property real modelData
                    width: flash.width * modelData
                    height: Math.round(7 * displayRoot.d)
                    radius: height / 2
                    color: displayRoot.soften ? IrisStyle.fill : IrisStyle.surfaceHighOpaque
                    opacity: displayRoot.soften ? 1 : 0.18
                }
            }
        }
    }
    // The warm layer over the whole screen.
    Rectangle {
        anchors.fill: parent
        color: IrisStyle.identity.orange
        opacity: 0.38 * displayRoot.tint
    }
    // The day's arc: the sun goes down to the moon, the warmth follows it.
    Item {
        id: arc
        visible: displayRoot.scheduled
        anchors.horizontalCenter: parent.horizontalCenter
        y: flash.y + flash.height + Math.round(26 * displayRoot.d)
        width: Math.round(displayRoot.width * 0.5)
        height: Math.round(54 * displayRoot.d)
        Canvas {
            anchors.fill: parent
            readonly property color ink: IrisStyle.onMediaSecondary
            onInkChanged: requestPaint()
            onWidthChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = ink
                ctx.lineWidth = 1.5
                ctx.setLineDash([3, 4])
                ctx.beginPath()
                ctx.moveTo(8, height - 6)
                ctx.quadraticCurveTo(width / 2, -height * 0.6, width - 8, height - 6)
                ctx.stroke()
            }
        }
        MaterialSymbol {
            readonly property real p: displayRoot.t
            x: (arc.width - 16) * p - width / 2 + 8
            y: (arc.height - 6) - 4 * (arc.height * 0.8) * p * (1 - p) * 0.55 * 2 - height / 2
            text: p > 0.6 ? "dark_mode" : "light_mode"
            fill: 1
            iconSize: Math.round(20 * displayRoot.d)
            color: p > 0.6 ? IrisStyle.onMedia : IrisStyle.identity.yellow
        }
    }
    Caption {
        glyph: displayRoot.night || displayRoot.scheduled ? "nights_stay" : "light_mode"
        text: [displayRoot.scheduled ? Translation.tr("Night Light at sunset") : displayRoot.night ? Translation.tr("Night Light on") : Translation.tr("Night Light off"),
            displayRoot.soften ? Translation.tr("bright flashes softened") : ""].filter(part => part.length > 0).join(" · ")
    }
}
