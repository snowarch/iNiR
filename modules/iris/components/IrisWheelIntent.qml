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
    property bool moved: false
    property point lastScene: Qt.point(NaN, NaN)
    readonly property Flickable scroller: root.findScroller(root.target)
    // The wheel latches to where its gesture began, as AppKit's scrolling does: while the page is moving (and for a
    // beat after it stops) the wheel keeps scrolling it, even as a control slides under a still pointer; a pointer at
    // rest on a control over a page at rest turns the control, and a pointer that really moves onto one takes it at
    // once. Requiring the move every time (141f2666) left a slider pointed at and turned scrolling the page instead.
    property int latchMs: 260
    property bool latched: false
    readonly property bool armed: root.hovered && (!root.scroller || root.moved || !root.latched)

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
        root.moved = false
        root.latched = true
        latch.restart()
    }
    Timer { id: latch; interval: root.latchMs; onTriggered: root.latched = false }
    property real lastExtent: -1
    Connections {
        target: root.scroller
        function onContentYChanged(): void {
            // Rows folding or arriving move the page without anyone scrolling it: that never latches the wheel (DI82).
            const extent = root.scroller.contentHeight
            if (extent !== root.lastExtent) { root.lastExtent = extent; return }
            root.scrolled()
        }
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
        event.accepted = false
        return false
    }
}
