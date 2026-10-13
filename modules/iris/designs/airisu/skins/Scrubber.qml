import QtQuick
import qs.modules.common.functions
import qs.modules.iris.style
import "../components"

// AIRISU's scrubber: a setting's range (the host has a knob) is the graduated rule; a position in time is a run (ARun),
// thin, thickening while it can be taken. The run is the colour the caller gives it (an artwork's tint, a muted
// stream's grey) or the accent's lacquer; paused, it sinks halfway into the stock. The host keeps the drag, keys and wheel.
Item {
    id: root
    property Item host
    readonly property bool knob: root.host?.knob ?? false
    readonly property bool live: root.host?.live ?? true
    readonly property bool engaged: root.host?.engaged ?? false
    readonly property color given: root.host?.fillColor ?? IrisStyle.fillStrong
    readonly property color pigment: Qt.colorEqual(root.given, IrisStyle.fillStrong) ? Airisu.seal : root.given
    readonly property color track: root.host?.trackColor ?? IrisStyle.fill

    // A setting's range is read against a scale: the graduated rule, as the row slider is.
    ARuler {
        visible: root.knob
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: Math.round(16 * Airisu.d)
        value: root.host?.shownValue ?? 0
        hovered: root.engaged
        held: root.host?.dragging ?? false
        available: root.host?.enabled ?? true
        keyed: root.host?.keyed ?? root.host?.activeFocus ?? false
    }
    ARun {
        visible: !root.knob
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: Math.round((root.engaged ? 8 : 5) * Airisu.d)
        value: root.host?.shownValue ?? 0
        hovered: root.engaged
        held: root.host?.dragging ?? false
        available: root.host?.enabled ?? true
        pigment: root.live || root.knob ? root.pigment : ColorUtils.mix(root.pigment, Airisu.ground, 0.55) // iris-literal: a paused run
        slot: Qt.colorEqual(root.track, IrisStyle.fill) ? "transparent" : root.track
    }
}
