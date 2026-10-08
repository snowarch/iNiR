pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root
    visible: false
    width: 0
    height: 0

    property bool hovered: false
    property Item target: root.parent
    property real travel: 3
    property int settleMs: 350
    property bool moved: false
    property bool settled: true
    property point lastScene: Qt.point(NaN, NaN)
    readonly property Flickable scroller: root.findScroller(root.target)
    readonly property bool armed: root.hovered && (!root.scroller || root.moved || root.settled)

    function findScroller(item): Flickable {
        for (let p = item?.parent ?? null; p; p = p.parent)
            if (p instanceof Flickable && (p.contentHeight > p.height || p.contentWidth > p.width)) return p
        return null
    }

    onHoveredChanged: {
        root.moved = false
        root.lastScene = Qt.point(NaN, NaN)
    }

    function scrolled(): void {
        root.settled = false
        root.moved = false
        settleTimer.restart()
    }

    Timer { id: settleTimer; interval: root.settleMs; onTriggered: root.settled = true }
    Connections {
        target: root.scroller
        function onContentYChanged(): void { root.scrolled() }
        function onContentXChanged(): void { root.scrolled() }
    }

    // Content scrolling under a still pointer sends synthetic hover moves at the same scene
    // position; only a pointer that really moved may take the wheel mid-scroll.
    function track(x: real, y: real): void {
        if (!root.target) return
        const scene = root.target.mapToItem(null, x, y)
        if (!isNaN(root.lastScene.x) && root.hovered
            && Math.hypot(scene.x - root.lastScene.x, scene.y - root.lastScene.y) > root.travel)
            root.moved = true
        root.lastScene = scene
    }

    function take(event): bool {
        if (root.armed) return true
        if (root.scroller) root.scrolled()
        event.accepted = false
        return false
    }
}
