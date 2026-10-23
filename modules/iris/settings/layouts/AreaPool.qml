pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.iris.style

// The areas a layout shows, one page each, kept built (Material's SettingsPageHost way): a page incubates in the
// background in slices the runtime spreads across frames, the one on screen stays until the next is Ready, then the
// two trade places in one move. Pages seen lately stay resident, so going back is only showing them; at rest the
// layout prewarms the ones you are likely to open next. Nothing is rebuilt when an area turns.
Item {
    id: pool

    // The area asked for, and the page file for an id (the layout's own page, Home for "home").
    property string current: ""
    property var urlFor: id => ""
    // What a page gets at creation, besides its `area`.
    property var propsFor: id => ({})
    // Pages kept built besides the one on screen.
    property int keep: 4
    // Pages are hidden while a search or a shared page fills the layout.
    property bool hidden: false
    // Motion of a turn: the areas in their order, and how far a page arriving travels from the side it lies on.
    property var order: []
    property real distance: 0
    property int duration: IrisStyle.morphDuration
    // Whether the page left fades under the one arriving. Deck's hero travels with its card, so the page it leaves
    // would stand in the wrong card: there it goes at once and the card's own face holds the place.
    property bool crossing: true
    // Whether the page on screen stays while the one asked for builds. Deck's hero is already the new card by then,
    // so it shows nothing of another area: the card's face stands there until its page is ready.
    property bool keepsShown: true

    // On screen: the last area whose page stood ready; `leaving` fades under it during a turn.
    property string shown: ""
    property string leaving: ""
    readonly property Item shownItem: pool.itemFor(pool.shown)
    readonly property bool turning: turn.running
    property var resident: []
    property var used: ({})
    property int clock: 0
    signal arrived(string id)

    function slot(id: string): Loader {
        for (let i = 0; i < pages.count; i++) {
            const loader = pages.itemAt(i)
            if (loader && loader.area === id) return loader
        }
        return null
    }
    function itemFor(id: string): Item {
        const loader = pool.slot(id)
        return loader && loader.status === Loader.Ready ? loader.item : null
    }
    function ready(id: string): bool { return pool.itemFor(id) !== null }
    function hold(id: string): void {
        if (id.length === 0 || String(pool.urlFor(id)).length === 0) return
        const next = Object.assign({}, pool.used)
        next[id] = ++pool.clock
        pool.used = next
        if (!pool.resident.includes(id)) pool.resident = pool.resident.concat([id])
    }
    // Built in the background and kept, never shown: the layout asks for these once it rests.
    function prewarm(ids: var): void {
        for (const id of ids) if (!pool.resident.includes(id)) pool.hold(id)
        pool.trim()
    }
    function trim(): void {
        const extra = pool.resident.length - (pool.keep + 1)
        if (extra <= 0) return
        const spare = pool.resident.filter(id => id !== pool.shown && id !== pool.current && id !== pool.leaving)
            .sort((a, b) => (pool.used[a] ?? 0) - (pool.used[b] ?? 0)).slice(0, extra)
        if (spare.length > 0) pool.resident = pool.resident.filter(id => !spare.includes(id))
    }
    // Ends a turn where it would have landed (a click mid-move): nothing stays faded or shifted.
    function endTurn(): void {
        turn.stop()
        const left = pool.itemFor(pool.leaving)
        if (left) left.opacity = 1
        const here = pool.itemFor(pool.shown)
        if (here) { here.opacity = 1; here.shift = 0 }
        pool.leaving = ""
    }
    function settle(): void {
        if (pool.current.length === 0 || pool.current === pool.shown || !pool.ready(pool.current)) return
        pool.endTurn()
        const from = pool.shown
        const moves = from.length > 0 && IrisStyle.motionEnabled && !pool.hidden
        pool.leaving = moves && pool.crossing ? from : ""
        pool.shown = pool.current
        const arriving = pool.itemFor(pool.shown)
        if (moves) {
            arriving.opacity = 0
            arriving.shift = (pool.order.indexOf(pool.shown) < pool.order.indexOf(from) ? -1 : 1) * pool.distance
            inFade.target = arriving
            inMove.target = arriving
            outFade.target = pool.crossing ? pool.itemFor(from) : null
            turn.start()
        }
        pool.arrived(pool.shown)
        pool.trim()
    }
    onCurrentChanged: {
        pool.hold(pool.current)
        pool.settle()
    }

    ParallelAnimation {
        id: turn
        NumberAnimation { id: inFade; property: "opacity"; to: 1; duration: pool.duration * 0.6; easing.type: Easing.OutCubic }
        NumberAnimation { id: inMove; property: "shift"; to: 0; duration: pool.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
        NumberAnimation { id: outFade; property: "opacity"; to: 0; duration: pool.duration * 0.35; easing.type: Easing.OutCubic }
        // Qt emits finished only when a run reaches its end, never on stop().
        onFinished: pool.endTurn()
    }

    Repeater {
        id: pages
        // Keyed by id: a page joining or leaving the pool never touches the others.
        model: ScriptModel { values: pool.resident }
        Loader {
            id: page
            required property string modelData
            readonly property string area: page.modelData
            readonly property bool onScreen: !pool.hidden && (page.area === pool.leaving
                || page.area === pool.shown && (pool.keepsShown || pool.shown === pool.current))
            anchors.fill: parent
            asynchronous: true
            visible: page.onScreen && page.status === Loader.Ready
            enabled: page.area === pool.shown && !turn.running
            z: page.area === pool.shown ? 1 : 0
            // Only the pages moving are drawn as one texture each, and only while they move.
            layer.enabled: turn.running && page.visible
            layer.smooth: true
            Component.onCompleted: page.setSource(pool.urlFor(page.area), Object.assign({ area: page.area }, pool.propsFor(page.area)))
            onStatusChanged: if (page.status === Loader.Ready && page.area === pool.current) pool.settle()
        }
    }
}
