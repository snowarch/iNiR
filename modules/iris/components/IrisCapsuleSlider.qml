pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style

Item {
    id: root

    property real value: 0
    property string icon: "volume_up"
    property bool muted: false
    property bool vertical: false
    property color fillColor: IrisStyle.text
    property bool readout: false
    // The level's name, for a Design that sets it in words beside the level (AIRISU's rule).
    property string label: ""
    readonly property bool hovered: pointer.containsMouse
    readonly property bool held: root.dragValue >= 0
    property real cornerCap: IrisStyle.radiusSheet
    signal moved(real value)
    signal iconClicked()
    // A Design may draw the level its own way (AIRISU: the twenty-segment meter); drag, wheel and pocket stay here.
    readonly property bool skinned: meterSkin.active

    property real dragValue: -1
    readonly property real shownValue: Math.max(0, Math.min(1, root.dragValue >= 0 ? root.dragValue : (Number.isFinite(root.value) ? root.value : 0)))
    readonly property real thickness: root.vertical ? root.width : root.height
    readonly property real span: root.vertical ? root.height : root.width
    readonly property real corner: Math.min(root.thickness / 2, root.cornerCap)
    readonly property real pocket: Math.min(root.thickness, Math.round(52 * IrisStyle.density))

    implicitWidth: root.vertical ? Math.round(46 * IrisStyle.density) : 260
    implicitHeight: root.vertical ? 120 : Math.round(44 * IrisStyle.density)
    Accessible.role: Accessible.Slider

    IrisSkin { id: meterSkin; part: "meter" }
    Rectangle {
        id: track
        visible: !root.skinned
        anchors.fill: parent
        radius: root.corner
        color: IrisStyle.fill
        scale: pointer.pressed ? 1.015 : 1
        Behavior on scale { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }

        Readout { ink: IrisStyle.textSecondary }
        // Signal (DESIGN.md S4): the level is a run of dots past the glyph's pocket, filled to the value, the knob a
        // larger dot; muted, the dots go quiet but keep the level.
        IrisDotStrip {
            id: dots
            readonly property real inset: Math.round(14 * IrisStyle.density)
            readonly property real readoutRoom: root.readout && !root.vertical ? Math.round(30 * IrisStyle.density) : 0
            vertical: root.vertical
            x: root.vertical ? 0 : root.pocket
            y: root.vertical ? (root.readout ? Math.round(34 * IrisStyle.density) : dots.inset) : 0
            width: root.vertical ? track.width : track.width - root.pocket - dots.inset - dots.readoutRoom
            height: root.vertical ? track.height - root.pocket - y : track.height
            value: root.shownValue
            stagger: root.dragValue < 0
            dotSize: Math.max(3, Math.round(4 * IrisStyle.density))
            gap: Math.max(3, Math.round(5 * IrisStyle.density))
            knobSize: Math.round((pointer.pressed ? 13 : 11) * IrisStyle.density)
            fillColor: root.muted ? IrisStyle.textTertiary : root.fillColor
        }

        MaterialSymbol {
            x: root.vertical ? (track.width - width) / 2 : (root.pocket - width) / 2
            y: root.vertical ? track.height - root.pocket + (root.pocket - height) / 2 : (track.height - height) / 2
            text: root.icon
            fill: 1
            iconSize: Math.round((root.vertical ? 19 : 20) * IrisStyle.density)
            color: root.muted ? IrisStyle.textTertiary : IrisStyle.text
        }
    }

    onMoved: GlobalStates.quietIrisLevels()
    onIconClicked: GlobalStates.quietIrisLevels()

    MouseArea {
        id: pointer
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        hoverEnabled: true
        function valueAt(mouse): real {
            return Math.max(0, Math.min(1, root.vertical ? 1 - mouse.y / Math.max(1, height) : mouse.x / Math.max(1, width)))
        }
        function inPocket(mouse): bool {
            return root.vertical ? mouse.y > height - root.pocket : mouse.x < root.pocket
        }
        onPressed: mouse => {
            if (inPocket(mouse)) return
            root.dragValue = valueAt(mouse)
            root.moved(root.dragValue)
        }
        onPositionChanged: mouse => {
            wheelIntent.track(mouse.x, mouse.y)
            if (!pressed || root.dragValue < 0) return
            root.dragValue = valueAt(mouse)
            root.moved(root.dragValue)
        }
        onReleased: mouse => {
            if (root.dragValue < 0 && inPocket(mouse)) root.iconClicked()
            root.dragValue = -1
        }
        onCanceled: root.dragValue = -1
        property real wheelAccumulator: 0
        IrisWheelIntent { id: wheelIntent; hovered: pointer.containsMouse }
        onWheel: wheel => {
            if (!wheelIntent.take(wheel)) return
            const delta = (wheel.angleDelta.y || wheel.angleDelta.x) || (wheel.pixelDelta.y || wheel.pixelDelta.x) * 4
            pointer.wheelAccumulator += delta
            const steps = Math.trunc(pointer.wheelAccumulator / 120)
            if (steps === 0) return
            pointer.wheelAccumulator -= steps * 120
            root.moved(Math.max(0, Math.min(1, root.value + steps * 0.05)))
        }
    }

    component Readout: IrisText {
        property color ink: IrisStyle.text
        readonly property real inset: Math.round(14 * IrisStyle.density)
        visible: root.readout
        x: root.vertical ? (track.width - width) / 2 : track.width - width - inset
        y: root.vertical ? inset : (track.height - height) / 2
        text: Math.round(root.shownValue * 100)
        color: ink
        role: IrisText.Value
    }
}
