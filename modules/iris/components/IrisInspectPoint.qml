import QtQuick
import qs

// Mod+Alt+click (a Niri bind: a layer surface never hears Alt while an app holds the keyboard) asks the shell what
// is under the pointer; only the surface the pointer is on answers, with the piece there.
Item {
    id: root
    anchors.fill: parent
    // Over everything in its window, so it hears the pointer wherever a piece takes it.
    z: 100000
    // (x, y) in this item → { id, x, y, width, height } in screen space, or null.
    property var resolve: null
    // The desktop answers last, when nothing on it did.
    property bool fallback: false
    function inspect(hit: var): void {
        const id = String(hit.id)
        GlobalStates.irisInspectClaimed = GlobalStates.irisInspectRequest
        GlobalStates.irisEditSelection = ""
        if (id === "island" || id === "dock") GlobalStates.irisEditTarget = id
        else if (id.startsWith("piece:")) GlobalStates.irisEditSelection = id.slice(6).replace(/^extra-/, "extra:")
        else if (id.startsWith("satellite:")) GlobalStates.irisEditSelection = id.slice(10)
        else GlobalStates.irisEditTarget = id + "@" + [hit.x, hit.y, hit.width, hit.height].map(Math.round).join(",")
        GlobalStates.irisEdit = true
    }
    function answer(): void {
        if (!hover.hovered || GlobalStates.irisInspectClaimed === GlobalStates.irisInspectRequest) return
        const hit = root.resolve ? root.resolve(hover.point.position.x, hover.point.position.y) : null
        if (hit) root.inspect(hit)
    }
    HoverHandler { id: hover }
    Timer { id: late; interval: 60; onTriggered: root.answer() }
    Connections {
        target: GlobalStates
        function onIrisInspectRequestChanged(): void { if (root.fallback) late.restart(); else root.answer() }
    }
}
