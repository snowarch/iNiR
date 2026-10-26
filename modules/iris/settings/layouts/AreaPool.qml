pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.iris.style

// The area a layout shows, one page at a time like Classic: the next page incubates in slices the runtime spreads
// across frames, the one on screen stays until it is Ready, the two trade places in one move and the old one goes.
// Keeping every area seen (and prewarming the neighbours) held 3-6x Classic's objects, and each of them re-read the
// config on every write: the three layouts felt slow next to Classic (2026-10-24).
Item {
    id: pool

    // The area asked for, and the page file for an id (the layout's own page).
    property string current: ""
    property var urlFor: id => ""
    // What a page gets at creation, besides its `area`.
    property var propsFor: id => ({})
    // Pages kept built besides the one on screen.
    property int keep: 0
    // Pages are hidden while a search or a shared page fills the layout.
    property bool hidden: false
    // Settings stands (its open has finished): a page asked for now builds in the click's frame, as Classic's first
    // block does; built in slices it showed 0.2-0.7 s later in a nest. During the open it builds in slices, and one
    // still building when the open ends is finished at once (Loader completes an incubation when it turns synchronous).
    property bool settled: true
    // Motion of a turn: the areas in their order, and how far a page arriving travels from the side it lies on.
    property var order: []
    property real distance: 0
    property int duration: IrisStyle.morphDuration

    // On screen: the last area whose page stood ready; `leaving` fades under it during a turn.
    property string shown: ""
    property string leaving: ""
    readonly property Item shownItem: pool.itemFor(pool.shown)
    readonly property bool turning: turn.running || prep.running
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
    // A page is ready once it is whole (every group built), or after a beat at most: a turn to a page still filling in
    // showed it streaming its groups in on screen.
    function ready(id: string): bool {
        const item = pool.itemFor(id)
        return item !== null && (item.whole !== false || pool.forced === id)
    }
    property string forced: ""
    Timer { id: wholeLimit; interval: 450; onTriggered: { pool.forced = pool.current; pool.settle() } }
    function hold(id: string): void {
        if (id.length === 0 || String(pool.urlFor(id)).length === 0) return
        const next = Object.assign({}, pool.used)
        next[id] = ++pool.clock
        pool.used = next
        if (!pool.resident.includes(id)) pool.resident = pool.resident.concat([id])
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
        prep.stop()
        turn.stop()
        const left = pool.itemFor(pool.leaving)
        if (left) left.opacity = 1
        const here = pool.itemFor(pool.shown)
        if (here) { here.opacity = 1; here.shift = 0 }
        pool.leaving = ""
        // Never in this frame: settle runs inside a delegate's creation, and trimming there rewrote the model the
        // Repeater was building (a binding loop on `values`).
        Qt.callLater(pool.trim)
    }
    function settle(): void {
        if (pool.current.length === 0 || pool.current === pool.shown || !pool.ready(pool.current)) return
        pool.endTurn()
        const from = pool.shown
        const moves = from.length > 0 && IrisStyle.motionEnabled && !pool.hidden
        pool.leaving = moves ? from : ""
        pool.shown = pool.current
        const arriving = pool.itemFor(pool.shown)
        if (moves) {
            arriving.opacity = 0
            arriving.shift = (pool.order.indexOf(pool.shown) < pool.order.indexOf(from) ? -1 : 1) * pool.distance
            inFade.target = arriving
            inMove.target = arriving
            outFade.target = pool.itemFor(from)
            prep.arm()
        }
        pool.arrived(pool.shown)
        // The page left goes once the turn ends, so the turn's frame destroys nothing.
        if (!pool.turning) Qt.callLater(pool.trim)
    }
    onCurrentChanged: {
        pool.forced = ""
        wholeLimit.restart()
        pool.hold(pool.current)
        pool.settle()
    }

    // The turn starts once the new page has been drawn (SekaiPop's phone does the same before each move): started in
    // its build frame, the move's clock ran through the build and the first draw, and it showed up part-way done.
    FrameAnimation {
        id: prep
        property int drawn: 0
        property real since: 0
        function arm(): void { prep.drawn = 0; prep.since = Date.now(); prep.start() }
        onTriggered: {
            if (++prep.drawn < 2 && Date.now() - prep.since < 80) return
            prep.stop()
            turn.start()
        }
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
                || page.area === pool.shown)
            anchors.fill: parent
            // Sync only once the component compiled: going sync mid-compile makes Qt reload it without the props (no `area`).
            readonly property bool poolSettled: pool.settled
            onPoolSettledChanged: page.syncOnceCompiled()
            onProgressChanged: page.syncOnceCompiled()
            function syncOnceCompiled(): void {
                if (pool.settled && page.progress >= 1 && page.asynchronous) page.asynchronous = false
            }
            visible: page.onScreen && page.status === Loader.Ready
            enabled: page.area === pool.shown && !pool.turning
            z: page.area === pool.shown ? 1 : 0
            // Only the pages moving are drawn as one texture each, and only while they move.
            layer.enabled: pool.turning && page.visible
            layer.smooth: true
            Component.onCompleted: {
                page.asynchronous = !pool.settled
                page.setSource(pool.urlFor(page.area), Object.assign({ area: page.area }, pool.propsFor(page.area)))
            }
            onStatusChanged: if (page.status === Loader.Ready && page.area === pool.current) pool.settle()
            Connections {
                target: page.item
                ignoreUnknownSignals: true
                function onWholeChanged(): void { if (page.area === pool.current) pool.settle() }
            }
        }
    }
}
