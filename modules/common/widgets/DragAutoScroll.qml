import QtQuick

// A drag held near the edge of a scrolling page or list scrolls it, faster the closer it gets. What is carried stays
// under the pointer while the content moves (or, with keepCarried off, the surface moves it on `scrolled`).
// Ticks only while a drag is live.
Item {
    id: root

    property bool active: false
    property Item carried: null
    property Item flickable: null   // unset: the nearest Flickable up the parents
    property real edge: 56
    property real maxStep: 18       // px per tick at the very edge
    property bool keepCarried: true
    signal scrolled(real dy)

    width: 0
    height: 0

    function _scroller(): Item {
        if (root.flickable) return root.flickable
        for (let p = root.parent; p; p = p.parent)
            if (p.contentY !== undefined && p.flickableDirection !== undefined) return p
        return null
    }

    function _inside(item, ancestor): bool {
        for (let p = item?.parent; p; p = p.parent)
            if (p === ancestor) return true
        return false
    }

    Timer {
        interval: 16
        repeat: true
        running: root.active && root.carried !== null
        onTriggered: {
            const f = root._scroller()
            const c = root.carried
            if (!f || !c || f.contentHeight <= f.height) return
            const y = c.mapToItem(f, c.width / 2, c.height / 2).y
            const near = y < root.edge ? y - root.edge : y > f.height - root.edge ? y - (f.height - root.edge) : 0
            if (near === 0) return
            const depth = Math.min(1, Math.abs(near) / root.edge)
            const before = f.contentY
            const top = f.originY
            const bottom = f.originY + f.contentHeight - f.height
            f.contentY = Math.max(top, Math.min(bottom, before + Math.sign(near) * root.maxStep * depth * depth))
            const moved = f.contentY - before
            if (moved === 0) return
            if (root.keepCarried) {
                if (root._inside(c, f.contentItem)) {
                    c.y += moved
                } else {
                    // The content slid under it: a nudge there and back tells the DropAreas
                    c.y += 0.5
                    c.y -= 0.5
                }
            }
            root.scrolled(moved)
        }
    }
}
