pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.modules.iris.style

Item {
    id: root

    required property var face
    property var time: new Date()
    property bool seconds: true
    property bool numerals: true
    property bool ticks: true
    property bool disc: false
    property bool daylight: false
    property string caption: ""

    readonly property real r: Math.min(width, height) / 2
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property color ink: root.disc && root.daylight ? IrisStyle.onAccent : root.face.ink
    readonly property color inkQuiet: IrisStyle.tertiaryOf(root.ink)
    readonly property color hand: root.face.highlight
    readonly property real hours: (root.time.getHours() % 12) + root.time.getMinutes() / 60
    readonly property real minutes: root.time.getMinutes() + (root.seconds ? root.time.getSeconds() / 60 : 0)
    readonly property real secondsValue: root.time.getSeconds()

    function point(angle: real, radius: real): point {
        const a = angle * Math.PI / 180
        return Qt.point(root.cx + Math.sin(a) * radius, root.cy - Math.cos(a) * radius)
    }
    function segment(angle: real, from: real, to: real): var {
        return [root.point(angle, from), root.point(angle, to)]
    }
    readonly property var minorTicks: {
        const list = []
        for (let i = 0; i < 60; ++i)
            if (i % 5 !== 0)
                list.push(root.segment(i * 6, root.r * 0.9, root.r * 0.96))
        return list
    }
    readonly property var majorTicks: {
        const list = []
        for (let i = 0; i < 12; ++i)
            list.push(root.segment(i * 30, root.r * (root.numerals ? 0.86 : 0.8), root.r * 0.96))
        return list
    }

    Rectangle {
        visible: root.disc
        anchors.centerIn: parent
        width: root.r * 2
        height: width
        radius: width / 2
        color: root.daylight ? IrisStyle.text : root.face.fill
    }

    Shape {
        anchors.fill: parent
        visible: root.ticks
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.inkQuiet
            strokeWidth: Math.max(1, root.r * 0.014)
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            PathMultiline { paths: root.r > 40 ? root.minorTicks : [] }
        }
        ShapePath {
            strokeColor: IrisStyle.secondaryOf(root.ink)
            strokeWidth: Math.max(1.2, root.r * 0.026)
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            PathMultiline { paths: root.majorTicks }
        }
    }

    Repeater {
        model: root.numerals ? 12 : 0
        Text {
            required property int index
            readonly property int hour: index === 0 ? 12 : index
            readonly property point at: root.point(index * 30, root.r * 0.68)
            x: Math.round(at.x - width / 2)
            y: Math.round(at.y - height / 2)
            text: hour
            color: index % 3 === 0 ? root.ink : IrisStyle.secondaryOf(root.ink)
            font.family: root.face.fontNumbers
            font.pixelSize: Math.max(8, Math.round(root.r * 0.2))
            font.weight: IrisStyle.weight(Font.DemiBold)
            font.features: ({ "tnum": 1 })
            renderType: Text.NativeRendering
        }
    }

    Text {
        visible: root.caption.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.cy + root.r * 0.3)
        text: root.caption
        color: IrisStyle.secondaryOf(root.ink)
        font.family: root.face.fontMain
        font.pixelSize: Math.max(8, Math.round(root.r * 0.16))
        font.weight: IrisStyle.weight(Font.DemiBold)
        renderType: Text.NativeRendering
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.ink
            strokeWidth: Math.max(1, root.r * 0.03)
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            PathMultiline {
                paths: [root.segment(root.hours * 30, 0, root.r * 0.16),
                    root.segment(root.minutes * 6, 0, root.r * 0.16)]
            }
        }
        ShapePath {
            strokeColor: root.ink
            strokeWidth: Math.max(2.4, root.r * 0.085)
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            startX: root.point(root.hours * 30, root.r * 0.16).x
            startY: root.point(root.hours * 30, root.r * 0.16).y
            PathLine {
                x: root.point(root.hours * 30, root.r * 0.52).x
                y: root.point(root.hours * 30, root.r * 0.52).y
            }
        }
        ShapePath {
            strokeColor: root.ink
            strokeWidth: Math.max(2, root.r * 0.065)
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            startX: root.point(root.minutes * 6, root.r * 0.16).x
            startY: root.point(root.minutes * 6, root.r * 0.16).y
            PathLine {
                x: root.point(root.minutes * 6, root.r * 0.8).x
                y: root.point(root.minutes * 6, root.r * 0.8).y
            }
        }
        ShapePath {
            strokeColor: root.seconds ? root.hand : "transparent"
            strokeWidth: Math.max(1, root.r * 0.022)
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            startX: root.point(root.secondsValue * 6 + 180, root.r * 0.16).x
            startY: root.point(root.secondsValue * 6 + 180, root.r * 0.16).y
            PathLine {
                x: root.point(root.secondsValue * 6, root.r * 0.86).x
                y: root.point(root.secondsValue * 6, root.r * 0.86).y
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.max(4, root.r * 0.1)
        height: width
        radius: width / 2
        color: root.seconds ? root.hand : root.ink
        Rectangle {
            anchors.centerIn: parent
            width: Math.max(1.5, parent.width * 0.4)
            height: width
            radius: width / 2
            color: root.disc && root.daylight ? IrisStyle.text : root.face.knockout
        }
    }
}
