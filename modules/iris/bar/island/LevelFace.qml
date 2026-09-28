pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.iris.style
import qs.modules.iris.components

Item {
    id: face

    property string glyph: ""
    property real value: 0
    property bool muted: false
    property string style: "bar"
    property bool showValue: true
    property real glyphSize: 18 * IrisStyle.density
    property real figureSize: 14 * IrisStyle.typeScale
    property color barFill: IrisStyle.fillStrong

    readonly property real d: IrisStyle.density
    readonly property color ink: face.muted ? IrisStyle.subtext : IrisStyle.text
    readonly property real target: face.muted ? 0 : Math.max(0, Math.min(1, face.value))
    property real level: face.target
    Behavior on level { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }

    readonly property real figureWidth: face.showValue ? Math.round(face.figureSize * 2.75) : 0
    readonly property real gap: Math.round(11 * face.d)
    readonly property real capsuleHeight: Math.round(Math.min(Math.max(face.height, face.glyphSize), face.glyphSize * 1.5))
    readonly property real ringSize: Math.round(face.glyphSize * 1.55)

    implicitHeight: Math.round(face.glyphSize * 1.55)
    implicitWidth: face.style === "minimal" ? face.ringSize + (face.showValue ? Math.round(8 * face.d) + face.figureWidth : 0)
        : face.style === "capsule" ? Math.round(214 * face.d) + (face.showValue ? face.gap + face.figureWidth : 0)
        : Math.round(face.glyphSize * 1.15) + face.gap + 200 + (face.showValue ? face.gap + face.figureWidth : 0)

    component Figure: Item {
        width: face.figureWidth
        height: face.height
        visible: face.showValue
        Metric {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            value: Math.round(face.value * 100)
            unit: "%"
            pixelSize: face.figureSize
            weight: Font.Bold
            color: face.ink
        }
    }

    Item {
        id: bar
        anchors.fill: parent
        visible: face.style === "bar"
        Glyph {
            id: barGlyph
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(face.glyphSize * 1.15)
            horizontalAlignment: Text.AlignHCenter
            text: face.glyph
            iconSize: face.glyphSize
            color: face.ink
        }
        IrisScrubber {
            anchors.left: barGlyph.right
            anchors.leftMargin: face.gap
            anchors.right: barFigure.visible ? barFigure.left : parent.right
            anchors.rightMargin: barFigure.visible ? face.gap : 0
            anchors.verticalCenter: parent.verticalCenter
            seekable: false
            value: face.level
            fillColor: face.barFill
        }
        Figure { id: barFigure; anchors.right: parent.right }
    }

    Item {
        id: capsule
        visible: face.style === "capsule"
        anchors.left: parent.left
        anchors.right: capsuleFigure.visible ? capsuleFigure.left : parent.right
        anchors.rightMargin: capsuleFigure.visible ? face.gap : 0
        anchors.verticalCenter: parent.verticalCenter
        height: face.capsuleHeight
        readonly property real fillWidth: face.level <= 0 ? 0
            : Math.max(capsule.height, Math.round(capsule.width * face.level))
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: IrisStyle.fill
        }
        Rectangle {
            width: capsule.fillWidth
            height: capsule.height
            radius: height / 2
            color: IrisStyle.text
            visible: width > 0
        }
        Glyph {
            x: Math.round((capsule.height - width) / 2)
            anchors.verticalCenter: parent.verticalCenter
            text: face.glyph
            iconSize: Math.round(face.glyphSize * 0.86)
            color: face.ink
        }
        Item {
            width: capsule.fillWidth
            height: capsule.height
            clip: true
            Glyph {
                x: Math.round((capsule.height - width) / 2)
                anchors.verticalCenter: parent.verticalCenter
                text: face.glyph
                iconSize: Math.round(face.glyphSize * 0.86)
                color: IrisStyle.onTintFor(IrisStyle.text)
            }
        }
    }
    Figure { id: capsuleFigure; visible: face.style === "capsule" && face.showValue; anchors.right: parent.right }

    Item {
        id: minimal
        anchors.fill: parent
        visible: face.style === "minimal"
        Item {
            id: ringHost
            width: face.ringSize
            height: face.ringSize
            anchors.verticalCenter: parent.verticalCenter
            ProgressRing {
                anchors.fill: parent
                progress: face.level
                tint: face.ink
            }
            Glyph {
                anchors.centerIn: parent
                text: face.glyph
                iconSize: Math.round(face.glyphSize * 0.78)
                color: face.ink
            }
        }
        Figure { anchors.right: parent.right; visible: face.showValue }
    }
}
