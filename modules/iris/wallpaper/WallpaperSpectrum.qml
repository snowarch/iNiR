pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.services
import qs.modules.common.functions
import qs.modules.iris.style
import qs.modules.iris.components

// One run of Wallhaven's colours as a strip of paint: each blends into the next, a press picks the nearest, and the
// chosen one rides on the strip as a knob that takes the paint under it while it slides.
Item {
    id: root

    required property var engine
    required property var stops
    property string name: ""
    readonly property real d: IrisStyle.density
    readonly property real pitch: Math.round(18 * root.d)
    readonly property real knob: Math.round(20 * root.d)
    readonly property int count: root.stops.length
    readonly property int chosen: root.stops.indexOf(root.engine.colour)
    readonly property int hovered: area.containsMouse ? root.indexAt(area.mouseX) : -1

    implicitWidth: root.count * root.pitch + root.knob
    implicitHeight: Math.round(32 * root.d)
    Accessible.role: Accessible.List
    Accessible.name: root.name

    function indexAt(x: real): int { return Math.max(0, Math.min(root.count - 1, Math.floor((x - root.knob / 2) / root.pitch))) }
    function centre(i: int): real { return root.knob / 2 + (i + 0.5) * root.pitch }
    function paint(i: int): color { return Qt.color("#" + root.stops[Math.max(0, Math.min(root.count - 1, i))]) }
    // The colour of the strip at x, so the knob carries the paint it passes over.
    function paintAt(x: real): color {
        const t = Math.max(0, Math.min(root.count - 1, (x - root.knob / 2) / root.pitch - 0.5))
        const i = Math.floor(t)
        return ColorUtils.mix(root.paint(i + 1), root.paint(i), t - i)
    }

    ClippingRectangle {
        id: strip
        x: root.knob / 2
        anchors.verticalCenter: parent.verticalCenter
        width: root.count * root.pitch
        height: Math.round(12 * root.d)
        radius: height / 2
        color: "transparent"
        Row {
            Repeater {
                model: root.count
                Rectangle {
                    id: segment
                    required property int index
                    width: root.pitch
                    height: strip.height
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: ColorUtils.mix(root.paint(segment.index), root.paint(segment.index - 1), 0.5) }
                        GradientStop { position: 0.5; color: root.paint(segment.index) }
                        GradientStop { position: 1; color: ColorUtils.mix(root.paint(segment.index), root.paint(segment.index + 1), 0.5) }
                    }
                }
            }
        }
    }
    // Black and white ends would melt into a dark or light body without an edge.
    Rectangle {
        anchors.fill: strip
        radius: strip.radius
        color: "transparent"
        border.width: 1
        border.color: IrisStyle.hairline
    }

    // Where a press would land.
    Rectangle {
        visible: root.hovered >= 0 && root.hovered !== root.chosen
        width: Math.round(root.knob * 0.7)
        height: width
        radius: width / 2
        x: root.centre(root.hovered) - width / 2
        y: (root.height - height) / 2
        color: root.paint(root.hovered)
        border.width: Math.max(1, Math.round(1.5 * root.d))
        border.color: IrisStyle.onMediaSecondary
    }

    IrisSpring {
        id: slide
        surface: "gallery"
        intent: "move"
        animate: IrisStyle.motionEnabled
    }
    // A pick in this strip slides there; one that arrives from another strip (or from nothing) lands in place.
    property bool shown: false
    onChosenChanged: {
        if (root.chosen < 0) { root.shown = false; return }
        slide.to = root.centre(root.chosen)
        if (!root.shown) slide.jump()
        root.shown = true
    }
    Component.onCompleted: if (root.chosen >= 0) { slide.to = root.centre(root.chosen); slide.jump(); root.shown = true }

    RectangularShadow {
        anchors.fill: dot
        visible: dot.visible
        radius: dot.radius
        blur: 8 * root.d
        offset: Qt.vector2d(0, 2 * root.d)
        color: IrisStyle.shadow
        scale: dot.scale
    }
    Rectangle {
        id: dot
        visible: root.shown
        width: root.knob
        height: root.knob
        radius: width / 2
        x: slide.value - width / 2
        y: (root.height - height) / 2
        color: root.paintAt(slide.value)
        border.width: Math.round(2 * root.d)
        border.color: IrisStyle.onMedia
        scale: area.pressed ? IrisStyle.pressScale(0.9) : 1
        Behavior on scale { NumberAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.engine.setColour(root.stops[root.indexAt(mouse.x)])
    }
}
