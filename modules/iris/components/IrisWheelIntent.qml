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
    // Inside a scrolling page the wheel belongs to the page until the pointer really moves over the control: a pointer
    // left still on a slider after a scroll no longer takes the next turn of the wheel once the page settles
    // (2026-10-15, the maintainer: "el scroll de los sliders está roto").
    readonly property bool armed: root.hovered && (!root.scroller || root.moved)

    function findScroller(item): Flickable {
        for (let p = item?.parent ?? null; p; p = p.parent)
            if (p instanceof Flickable && (p.contentHeight > p.height || p.contentWidth > p.width)) return p
        return null
    }

    onHoveredChanged: {
        root.moved = false
        root.lastScene = Qt.point(NaN, NaN)
    }

    function scrolled(): void { root.moved = false }
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
