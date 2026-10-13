import QtQuick
import QtQuick.Shapes
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import "../components"

// AIRISU's day widget: the day as a rule (定規) of twenty-four hours. A tick for every hour and a long one every six with
// its hour in the data face; the hours gone are printed in ink, the ones left in the third ink; a die-cut pointer in the
// seal stands over now (the only shu on it), and sunrise and sunset are hollow rings on the rule, the system's one curve.
// The part of the day gone is the hero figure, leaning, with what is left under it. The engine's face keeps the data.
Item {
    id: root
    property var face
    readonly property var widget: root.face?.widget ?? null
    readonly property bool small: root.face?.small ?? true
    function dp(v: real): real { return root.face ? root.face.dp(v) : Math.round(v) }
    function px(v: real): real { return root.face ? root.face.px(v) : Math.round(v) }
    readonly property int pad: root.dp(14)
    readonly property real fraction: Math.max(0, Math.min(1, Number(root.face?.fraction ?? 0)))

    AStock {
        id: stock
        anchors.fill: parent
        face: root.face
        subject: "time"
    }
    Row {
        x: root.pad
        y: root.pad
        spacing: root.dp(4)
        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            text: (root.widget?.isDaytime ?? true) ? "light_mode" : "bedtime"
            iconSize: root.px(14)
            fill: 1
            color: stock.inkSecond
        }
        AText {
            anchors.verticalCenter: parent.verticalCenter
            voice: "mono"
            size: IrisStyle.typeCaption
            color: stock.inkSecond
            text: Translation.locale.toString(DateTime.clock.date, "dddd")
        }
    }
    Row {
        x: root.pad
        y: root.pad + root.dp(20)
        spacing: root.dp(2)
        AText {
            id: figure
            voice: "figure"
            lean: Airisu.lean
            size: root.px(root.small ? 48 : 56)
            color: stock.ink
            text: root.face?.percent ?? 0
        }
        AText {
            anchors.baseline: figure.baseline
            voice: "data"
            size: IrisStyle.typeLabel
            color: stock.inkSecond
            text: "%"
        }
    }
    AText {
        x: root.pad
        y: figure.parent.y + figure.height + root.dp(2)
        width: root.width - 2 * root.pad
        voice: "data"
        size: IrisStyle.typeCaption
        color: stock.inkSecond
        text: root.face?.remaining ?? ""
    }

    // The rule.
    Item {
        id: rule
        x: root.pad
        width: root.width - 2 * root.pad
        height: root.dp(30)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.pad
        readonly property real foot: rule.height - root.dp(10)
        function at(share: real): real { return Math.round(share * (rule.width - 1)) + 0.5 }
        function ticks(gone: bool): var {
            const out = []
            for (let h = 0; h <= 24; ++h) {
                const x = rule.at(h / 24)
                if ((h / 24 <= root.fraction) !== gone) continue
                out.push([Qt.point(x, rule.foot), Qt.point(x, rule.foot - (h % 6 === 0 ? root.dp(9) : root.dp(4)))])
            }
            return out
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.GeometryRenderer
            ShapePath {
                strokeColor: stock.ink; strokeWidth: Airisu.hair; fillColor: "transparent"; capStyle: ShapePath.FlatCap
                PathMultiline { paths: rule.ticks(true) }
            }
            ShapePath {
                strokeColor: stock.inkThird; strokeWidth: Airisu.hair; fillColor: "transparent"; capStyle: ShapePath.FlatCap
                PathMultiline { paths: rule.ticks(false) }
            }
            ShapePath {
                strokeColor: stock.inkThird; strokeWidth: Airisu.hair; fillColor: "transparent"
                startX: 0; startY: rule.foot + 0.5
                PathLine { x: rule.width; y: rule.foot + 0.5 }
            }
        }
        // Sunrise and sunset.
        Repeater {
            model: [Number(root.face?.sunrise ?? 0.25), Number(root.face?.sunset ?? 0.79)]
            Rectangle {
                required property real modelData
                width: root.dp(7)
                height: width
                radius: width / 2
                x: rule.at(modelData) - width / 2
                y: rule.foot - root.dp(4) - height - root.dp(2)
                color: "transparent"
                border.width: Airisu.hair
                border.color: stock.ink
            }
        }
        // Now.
        Shape {
            id: pointer
            readonly property real w: root.dp(10)
            readonly property real h: root.dp(7)
            x: rule.at(root.fraction) - w / 2
            y: rule.foot - root.dp(9) - h - root.dp(2)
            width: w
            height: h
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: Airisu.seal; strokeColor: "transparent"; strokeWidth: 0
                PathPolyline { path: [Qt.point(0, 0), Qt.point(pointer.w, 0), Qt.point(pointer.w / 2, pointer.h), Qt.point(0, 0)] }
            }
        }
        Repeater {
            model: [0, 6, 12, 18, 24]
            AText {
                required property int modelData
                x: Math.max(0, Math.min(rule.width - width, rule.at(modelData / 24) - width / 2))
                y: rule.foot + root.dp(2)
                voice: "data"
                size: IrisStyle.typeCaption
                color: stock.inkThird
                text: modelData
            }
        }
    }
}
