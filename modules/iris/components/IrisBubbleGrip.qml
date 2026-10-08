pragma ComponentBehavior: Bound

import QtQuick
import qs

MouseArea {
    id: root

    property string slot: ""
    property string kind: ""
    property string screenName: ""
    property real screenOffsetY: 0
    property bool holdLifts: true
    property int holdDelay: 320
    property int pullDirection: 0
    property bool pullAcross: false
    property real pullDistance: 0
    readonly property bool lifting: root.lifted
    property bool slideEnabled: false
    property real slideDistance: 8
    property bool sliding: false
    signal tapped()
    signal slid(real along)
    signal slideEnded(bool committed)

    property bool lifted: false
    property point pressScene: Qt.point(0, 0)
    property point lastScene: Qt.point(0, 0)
    property point grabOffset: Qt.point(0, 0)

    acceptedButtons: Qt.LeftButton
    preventStealing: true
    cursorShape: root.lifted ? Qt.ClosedHandCursor : Qt.PointingHandCursor

    function toScreen(x: real, y: real): point {
        const p = root.mapToItem(null, x, y)
        return Qt.point(p.x, p.y + root.screenOffsetY)
    }
    function publish(released: bool): void {
        GlobalStates.irisBubbleDrag = {
            slot: root.slot,
            kind: root.kind,
            screen: root.screenName,
            x: root.lastScene.x - root.grabOffset.x,
            y: root.lastScene.y - root.grabOffset.y,
            size: root.width,
            released: released
        }
    }
    function lift(): void {
        if (root.lifted || !root.pressed || root.slot.length === 0) return
        root.lifted = true
        root.publish(false)
    }

    Timer { id: hold; interval: root.holdDelay; running: false; onTriggered: root.lift() }
    readonly property real liftDistance: root.pullDistance > 0 ? root.pullDistance : 10 * (root.width / 40)

    onPressed: mouse => {
        root.lifted = false
        root.pressScene = root.toScreen(mouse.x, mouse.y)
        root.lastScene = root.pressScene
        const centre = root.toScreen(root.width / 2, root.height / 2)
        root.grabOffset = Qt.point(root.pressScene.x - centre.x, root.pressScene.y - centre.y)
        if (root.holdLifts) hold.restart()
    }
    onPositionChanged: mouse => {
        if (!root.pressed) return
        root.lastScene = root.toScreen(mouse.x, mouse.y)
        if (!root.lifted) {
            const dx = root.lastScene.x - root.pressScene.x
            const dy = root.lastScene.y - root.pressScene.y
            const pulled = root.pullDirection === 0 ? Math.hypot(dx, dy) : root.pullDirection * (root.pullAcross ? dx : dy)
            if (pulled > root.liftDistance) {
                if (root.sliding) { root.sliding = false; root.slideEnded(false) }
                root.lift()
                return
            }
            const along = root.pullAcross ? dy : dx
            if (!root.sliding && root.slideEnabled && root.pullDirection !== 0
                && Math.abs(along) > root.slideDistance && Math.abs(along) > Math.abs(root.pullAcross ? dx : dy)) {
                hold.stop()
                root.sliding = true
            }
            if (root.sliding) root.slid(along)
            return
        }
        root.pending = true
    }
    // A 1000 Hz mouse sends a dozen moves per frame; the stage reflows once per frame, not per move.
    property bool pending: false
    FrameAnimation {
        running: root.lifted
        onTriggered: if (root.pending) { root.pending = false; root.publish(false) }
    }
    onReleased: {
        hold.stop()
        if (root.sliding) {
            root.sliding = false
            root.slideEnded(true)
        } else if (root.lifted) {
            root.lifted = false
            root.pending = false
            root.publish(true)
        } else {
            root.tapped()
        }
    }
    onCanceled: {
        hold.stop()
        if (root.sliding) {
            root.sliding = false
            root.slideEnded(true)
        }
        if (root.lifted) {
            root.lifted = false
            root.pending = false
            root.publish(true)
        }
    }
}
