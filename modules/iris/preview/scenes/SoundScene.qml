pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.preview.parts

// Sound & Feedback: the volume pill as it shows (its style, its edge, its figure) while the volume climbs. Ear
// protection climbs in short steps and stops at the limit, marked on the level with a shield.
PreviewScene {
    id: soundRoot
    readonly property real naturalWidth: Math.round(560 * soundRoot.d)
    readonly property real naturalHeight: Math.round(290 * soundRoot.d)
    narrowest: Math.round(360 * soundRoot.d)
    lowest: Math.round(220 * soundRoot.d)
    subject: Qt.rect(pill.x, pill.y, pill.width, pill.height)
    readonly property bool shown: soundRoot.opt("iris.modules.osd", true) !== false
    readonly property string style: String(soundRoot.opt("iris.osd.style", "capsule"))
    readonly property bool figure: soundRoot.opt("iris.osd.figure", true) === true
    readonly property bool atTop: String(soundRoot.opt("iris.osd.position", "bottom")) === "top"
    readonly property bool guard: soundRoot.opt("audio.protection.enable", true) === true
    readonly property real limit: Math.min(1, Number(soundRoot.opt("audio.protection.maxAllowed", 100)) / 100)
    readonly property real jump: Math.max(0.02, Number(soundRoot.opt("audio.protection.maxAllowedIncrease", 10)) / 100)
    readonly property real cap: soundRoot.guard ? Math.min(0.92, soundRoot.limit) : 0.92
    property real t: 1
    Loop on t { running: soundRoot.playing; rest: 1500 }
    // Guarded, the level climbs in steps no bigger than the largest jump.
    readonly property real level: {
        const raw = 0.15 + (soundRoot.cap - 0.15) * soundRoot.t
        return soundRoot.guard ? Math.min(soundRoot.cap, 0.15 + Math.floor((raw - 0.15) / soundRoot.jump + 0.999) * soundRoot.jump) : raw
    }
    readonly property bool held: soundRoot.guard && soundRoot.limit < 0.92 && soundRoot.t > 0.98

    IslandPill { anchors.horizontalCenter: parent.horizontalCenter; y: IrisFrame.band }
    // Capsule: the pill fills like a slider. Bar: a slim line inside it. Minimal: a ring round the icon.
    Rectangle {
        id: pill
        readonly property bool minimal: soundRoot.style === "minimal"
        readonly property bool bar: soundRoot.style === "bar"
        anchors.horizontalCenter: parent.horizontalCenter
        y: soundRoot.atTop ? Math.round(64 * soundRoot.d) : soundRoot.height - height - Math.round(58 * soundRoot.d)
        Behavior on y { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
        width: pill.minimal ? height + (soundRoot.figure ? Math.round(44 * soundRoot.d) : 0) : Math.round(300 * soundRoot.d)
        height: Math.round(48 * soundRoot.d)
        radius: height / 2
        clip: true
        color: IrisStyle.bodySurface
        border.width: IrisStyle.rim.a === 0 ? 0 : 1
        border.color: IrisStyle.rim
        opacity: soundRoot.shown ? 1 : 0.3
        Rectangle {
            visible: !pill.minimal && !pill.bar
            width: pill.width * soundRoot.level
            height: pill.height
            radius: pill.radius
            color: soundRoot.held ? Qt.rgba(IrisStyle.accent.r, IrisStyle.accent.g, IrisStyle.accent.b, 0.4) : Qt.rgba(IrisStyle.text.r, IrisStyle.text.g, IrisStyle.text.b, 0.2)
        }
        Canvas {
            id: ring
            visible: pill.minimal
            x: Math.round(6 * soundRoot.d)
            anchors.verticalCenter: parent.verticalCenter
            width: pill.height - Math.round(12 * soundRoot.d)
            height: width
            readonly property real value: soundRoot.level
            readonly property color ink: soundRoot.held ? IrisStyle.accent : IrisStyle.text
            readonly property color track: IrisStyle.fill
            onValueChanged: requestPaint()
            onInkChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const r = width / 2 - 2
                ctx.lineWidth = Math.max(2, 3 * soundRoot.d)
                ctx.strokeStyle = ring.track
                ctx.beginPath(); ctx.arc(width / 2, height / 2, r, 0, 2 * Math.PI); ctx.stroke()
                ctx.strokeStyle = ring.ink
                ctx.lineCap = "round"
                ctx.beginPath(); ctx.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * ring.value); ctx.stroke()
            }
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: pill.minimal ? Math.round(6 * soundRoot.d) : Math.round(16 * soundRoot.d)
            anchors.rightMargin: Math.round(16 * soundRoot.d)
            spacing: Math.round(10 * soundRoot.d)
            MaterialSymbol {
                Layout.preferredWidth: pill.minimal ? ring.width : implicitWidth
                horizontalAlignment: Text.AlignHCenter
                text: soundRoot.held ? "shield" : "volume_up"
                fill: 1
                iconSize: Math.round(20 * soundRoot.d)
                color: soundRoot.held ? IrisStyle.accent : IrisStyle.text
            }
            Item {
                visible: pill.bar
                Layout.fillWidth: true
                implicitHeight: Math.round(6 * soundRoot.d)
                Rectangle { anchors.fill: parent; radius: height / 2; color: IrisStyle.fill }
                Rectangle {
                    width: parent.width * soundRoot.level
                    height: parent.height
                    radius: height / 2
                    color: soundRoot.held ? IrisStyle.accent : IrisStyle.text
                }
            }
            Item { visible: !pill.bar && !pill.minimal; Layout.fillWidth: true }
            IrisText {
                visible: soundRoot.figure
                text: Math.round(soundRoot.level * 100)
                font.family: IrisStyle.fontNumbers
                font.weight: IrisStyle.figureWeight
                font.features: { "tnum": 1 }
                Layout.preferredWidth: Math.round(30 * soundRoot.d)
                horizontalAlignment: Text.AlignRight
            }
        }
        // The limit, where protection stops it.
        Rectangle {
            visible: soundRoot.guard && soundRoot.limit < 0.92 && !pill.minimal
            x: pill.bar ? Math.round(52 * soundRoot.d) + (pill.width - Math.round(110 * soundRoot.d)) * soundRoot.limit : pill.width * soundRoot.limit - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(2, Math.round(2 * soundRoot.d))
            height: pill.height - Math.round(16 * soundRoot.d)
            radius: width / 2
            color: IrisStyle.accent
        }
    }
    Caption {
        glyph: soundRoot.guard ? "hearing" : "volume_up"
        text: [soundRoot.shown ? (soundRoot.style === "bar" ? Translation.tr("Bar") : soundRoot.style === "minimal" ? Translation.tr("Minimal") : Translation.tr("Capsule"))
                + " " + (soundRoot.atTop ? Translation.tr("at the top") : Translation.tr("at the bottom")) : Translation.tr("No volume pill"),
            soundRoot.guard ? Translation.tr("ear protection on") : ""].filter(part => part.length > 0).join(" · ")
    }
}
