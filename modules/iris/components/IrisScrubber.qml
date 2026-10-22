pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common.functions
import qs.modules.iris.style

Item {
    id: root

    property real value: 0
    property bool seekable: true
    property color fillColor: IrisStyle.text
    property color trackColor: IrisStyle.fill
    signal seekRequested(real value)
    signal moved(real value)
    property bool knob: false
    // Whether what it scrubs is running now (a playing track): a Design may mark the head with it.
    property bool live: true
    property real stepSize: 0.05
    property string voice: ""
    // What a voiced skin prints the value from (Folio's ruler, Console's dots): the row's own numbers.
    property var range: null
    activeFocusOnTab: root.seekable

    property real dragValue: -1
    readonly property bool dragging: pointer.pressed
    readonly property bool engaged: root.seekable && (pointer.containsMouse || pointer.pressed || root.activeFocus)
    readonly property real shownValue: Math.max(0, Math.min(1, root.dragValue >= 0 ? root.dragValue : root.value))

    implicitWidth: 200
    implicitHeight: Math.round(14 * IrisStyle.density)

    Accessible.role: Accessible.Slider
    Keys.onPressed: event => {
        if (!root.seekable) return
        let next = root.shownValue
        if (event.key === Qt.Key_Right || event.key === Qt.Key_Up) next += root.stepSize
        else if (event.key === Qt.Key_Left || event.key === Qt.Key_Down) next -= root.stepSize
        else if (event.key === Qt.Key_Home) next = 0
        else if (event.key === Qt.Key_End) next = 1
        else return
        next = Math.max(0, Math.min(1, next))
        root.moved(next)
        root.seekRequested(next)
        event.accepted = true
    }

    // The active Design may draw it (AIRISU: a meter for a level, a light trail for time); input stays here.
    IrisSkin { id: skin; part: "scrubber"; host: root; voice: root.voice }
    // Signal (DESIGN.md S4): a row of dots, filled up to the value, with a larger dot for the knob. The value may sit
    // beside it in the Label voice; clicked, it turns into a field to type the number.
    property bool showValue: false
    readonly property bool valueShown: root.showValue && root.range !== null && !skin.active
    readonly property real valueRoom: root.valueShown ? Math.ceil(valueLabel.implicitWidth) + Math.round(12 * IrisStyle.density) : 0
    IrisDotStrip {
        id: track
        visible: !skin.active
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - root.valueRoom
        height: Math.max(dotSize, knobSize)
        value: root.shownValue
        stagger: !root.dragging
        dotSize: Math.max(3, Math.round(4 * IrisStyle.density))
        gap: Math.max(3, Math.round(5 * IrisStyle.density))
        knobSize: root.seekable && (root.knob || root.engaged) ? Math.round((root.dragging ? 13 : 11) * IrisStyle.density) : 0
        fillColor: root.fillColor
        // A track colour given as a faint film still has to read as dots.
        emptyColor: Qt.rgba(root.trackColor.r, root.trackColor.g, root.trackColor.b, Math.max(0.2, root.trackColor.a))
    }
    IrisLabel {
        id: valueLabel
        visible: root.valueShown && !typing.visible
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: String(root.range?.text ?? "")
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.IBeamCursor
            onClicked: { typing.text = String(root.range?.value ?? ""); typing.visible = true; typing.forceActiveFocus(); typing.selectAll() }
        }
    }
    TextInput {
        id: typing
        visible: false
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(valueLabel.implicitWidth, Math.round(40 * IrisStyle.density))
        horizontalAlignment: TextInput.AlignRight
        color: IrisStyle.text
        selectionColor: IrisStyle.accentContainer
        selectedTextColor: IrisStyle.inkOnAccentContainer
        font.family: IrisStyle.fontLabel
        font.pixelSize: IrisStyle.typeLabelMono
        validator: DoubleValidator {}
        Keys.onEscapePressed: typing.visible = false
        onActiveFocusChanged: if (!activeFocus) typing.visible = false
        onAccepted: {
            const min = Number(root.range?.min ?? 0), max = Number(root.range?.max ?? 1)
            const typed = Number(typing.text.replace(",", "."))
            typing.visible = false
            if (!Number.isFinite(typed) || max <= min) return
            const next = Math.max(0, Math.min(1, (typed - min) / (max - min)))
            root.moved(next)
            root.seekRequested(next)
        }
    }

    MouseArea {
        id: pointer
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: track.width
        anchors.topMargin: -4
        anchors.bottomMargin: -4
        enabled: root.seekable
        hoverEnabled: true
        cursorShape: root.seekable ? Qt.PointingHandCursor : Qt.ArrowCursor
        function valueAt(px: real): real { return Math.max(0, Math.min(1, (px - track.start) / Math.max(1, track.lane))) }
        onPressed: mouse => { root.forceActiveFocus(); root.dragValue = valueAt(mouse.x); root.moved(root.dragValue) }
        onPositionChanged: mouse => { wheelIntent.track(mouse.x, mouse.y); if (pressed) { root.dragValue = valueAt(mouse.x); root.moved(root.dragValue) } }
        onReleased: {
            if (root.dragValue >= 0) root.seekRequested(root.dragValue)
            root.dragValue = -1
        }
        onCanceled: {
            if (root.dragValue >= 0) root.seekRequested(root.dragValue)
            root.dragValue = -1
        }
        preventStealing: true
        property real wheelAccumulator: 0
        IrisWheelIntent { id: wheelIntent; hovered: pointer.containsMouse }
        onWheel: wheel => {
            if (!wheelIntent.take(wheel)) return
            const delta = (wheel.angleDelta.y || wheel.angleDelta.x) || (wheel.pixelDelta.y || wheel.pixelDelta.x) * 4
            pointer.wheelAccumulator += delta
            const steps = Math.trunc(pointer.wheelAccumulator / 120)
            if (steps === 0) return
            pointer.wheelAccumulator -= steps * 120
            const next = Math.max(0, Math.min(1, root.shownValue + steps * root.stepSize))
            root.moved(next)
            root.seekRequested(next)
        }
    }
}
