import QtQuick

// An edge that reveals something (an autohidden bar, a dock): it opens once the pointer rests there, never on a pass
// at speed, and closes after a grace so a slip off the edge doesn't drop it. Timers run only around a crossing.
QtObject {
    id: root

    // The pointer is on the edge or on what it revealed.
    property bool hovered: false
    property int dwell: 110
    property int grace: 420
    property bool revealed: false

    property real _lastX: NaN
    property real _lastY: NaN

    // The pointer's moves on the edge: one still travelling starts the rest over.
    function moved(x: real, y: real): void {
        if (!root.revealed && Math.hypot(x - root._lastX, y - root._lastY) > 4) root._show.restart()
        root._lastX = x
        root._lastY = y
    }

    onHoveredChanged: {
        if (root.hovered) {
            root._hide.stop()
            if (!root.revealed) root._show.restart()
        } else {
            root._show.stop()
            root._lastX = NaN
            if (root.revealed) root._hide.restart()
        }
    }

    readonly property Timer _show: Timer { interval: root.dwell; onTriggered: root.revealed = root.hovered }
    readonly property Timer _hide: Timer { interval: root.grace; onTriggered: root.revealed = root.hovered }
}
