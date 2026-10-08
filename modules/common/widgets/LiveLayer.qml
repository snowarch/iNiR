pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

// Continuous motion inside a full-output window (the iRiS chassis, the desktop background) costs the whole
// screen: Qt presents every frame with plain eglSwapBuffers, which damages the entire window, and Niri
// recomposes all of it (the same spinner cost niri ~8 % in a 48 px layer and ~19 % in a full-output one). A
// LiveLayer draws its content in place while the host moves, fades or covers it, and, once the host is still
// around it, in a small layer surface of its own over the same pixels, so only that box is damaged per frame.
//
// `content` is a Component whose root has `property bool drawing`: the instance that shows gets true, the other
// false, and a content that is not drawing must stop its own motion (cava, timers, Behaviors) or it keeps the
// host redrawing for nothing.
//
// A host window opts in by declaring `liveCalm` (nothing of it may cover, move or restack what sits still in it),
// `liveLayer` (its own layer, so the surface stacks right above it) and `liveEpoch` (bumped when its surface is
// recreated). In any other window (Settings, previews, the lock) the content simply draws in place.
Item {
    id: root

    property Component content: null
    // The owner's gates: `live` while the content actually moves (music playing), `allowed` for anything the host
    // does not know (rarely needed).
    property bool live: false
    property bool allowed: true
    readonly property var host: root.QsWindow.window ?? null
    readonly property bool hostCalm: root.host?.liveCalm === true
    readonly property int hostEpoch: root.host?.liveEpoch ?? 0
    readonly property int surfaceLayer: root.host?.liveLayer ?? WlrLayer.Top
    // Pixels past the item the content may draw into (a glow, an overshoot).
    property int pad: 0
    // How long the host must leave the item where it is before it moves out.
    property int settleMs: 220

    readonly property bool detached: root.away && root.windowReady
    property bool away: false
    // Where the surface sits: set only when the content moves out, so a host that moves the item never
    // reconfigures the surface per frame. The content moves out once the surface has drawn there.
    property rect placedRect: Qt.rect(0, 0, 0, 0)
    readonly property string placedKey: root.placedRect.x + "," + root.placedRect.y + "," + root.placedRect.width + "," + root.placedRect.height
    readonly property bool windowReady: (windowLoader.item?.drawnKey ?? "") === root.placedKey
    readonly property var hostWindow: root.Window.window
    readonly property var screen: root.QsWindow.window?.screen ?? null

    // Where the item sits on the output, whole-pixel origin and fraction, and whether it is drawn 1:1 and opaque.
    property rect restRect: Qt.rect(0, 0, 0, 0)
    function sceneRect(): rect {
        const a = root.mapToItem(null, 0, 0), b = root.mapToItem(null, root.width, root.height)
        return Qt.rect(a.x, a.y, b.x - a.x, b.y - a.y)
    }
    // How the host composites the item, if a plain surface can reproduce it: the product of every ancestor's
    // opacity (carried to the surface, the same math), or −1 when an ancestor runs an effect or a mask
    // (`layer.enabled`), or clips the item where it would show (a rounded ClippingRectangle included).
    property real composedOpacity: 1
    function composition(): real {
        const r = root.sceneRect()
        let opacity = 1
        for (let item = root; item; item = item.parent) {
            if (!item.visible) return -1
            opacity *= item.opacity
            if (item !== root && item.layer && item.layer.enabled) return -1
            const rounded = item !== root && item.contentInsideBorder !== undefined
            if (item !== root && (item.clip || rounded)) {
                const a = item.mapToItem(null, 0, 0), inset = rounded ? Number(item.radius ?? 0) : 0
                if (r.x < a.x + inset - 0.5 || r.y < a.y + inset - 0.5 || r.x + r.width > a.x + item.width - inset + 0.5
                    || r.y + r.height > a.y + item.height - inset + 0.5) return -1
            }
        }
        return opacity
    }
    // The composed opacity if the item may move out now, else −1.
    function eligible(): real {
        if (!root.live || !root.allowed || !root.hostCalm || root.content === null || root.width <= 0 || root.height <= 0)
            return -1
        const opacity = root.composition()
        return opacity <= 0.001 ? -1 : opacity
    }
    // Every host frame is a chance something moved it: a changed rect, scale, opacity or gate brings it home at
    // once, in that same frame; an unchanged one starts (or keeps) the settle before it moves out again.
    // A fade is motion too: a changed opacity brings it home, as a changed rect does.
    function evaluate(): void {
        const opacity = root.eligible()
        if (opacity < 0) { root.away = false; settle.stop(); return }
        const r = root.sceneRect()
        const same = Math.abs(opacity - root.composedOpacity) < 0.001
            && Math.abs(r.x - root.restRect.x) < 0.01 && Math.abs(r.y - root.restRect.y) < 0.01
            && Math.abs(r.width - root.width) < 0.01 && Math.abs(r.height - root.height) < 0.01
            && Math.abs(root.restRect.width - root.width) < 0.01 && Math.abs(root.restRect.height - root.height) < 0.01
        if (!same) {
            root.away = false
            root.restRect = r
            root.composedOpacity = opacity
            settle.restart()
        } else if (!root.away && !settle.running) settle.restart()
    }
    Timer {
        id: settle
        interval: root.settleMs
        onTriggered: {
            const opacity = root.eligible()
            if (opacity < 0) return
            const r = root.sceneRect()
            if (Math.abs(opacity - root.composedOpacity) < 0.001 && Math.abs(r.x - root.restRect.x) < 0.01 && Math.abs(r.y - root.restRect.y) < 0.01
                && Math.abs(r.width - root.width) < 0.01 && Math.abs(r.height - root.height) < 0.01) {
                root.placedRect = r
                root.away = true
                windowLoader.item?.redraw()
            } else { root.restRect = r; root.composedOpacity = opacity; settle.restart() }
        }
    }
    Connections {
        target: root.hostWindow
        function onAfterAnimating(): void { root.evaluate() }
    }
    onLiveChanged: root.evaluate()
    onAllowedChanged: root.evaluate()
    onHostCalmChanged: root.evaluate()
    onVisibleChanged: root.evaluate()
    onWidthChanged: root.evaluate()
    onHeightChanged: root.evaluate()
    Component.onCompleted: root.evaluate()

    // In place: always built (it keeps its state for an instant return), drawing only while home.
    Loader {
        id: home
        anchors.fill: parent
        sourceComponent: root.content
        opacity: root.detached ? 0 : 1
    }
    Binding { target: home.item; property: "drawing"; value: !root.detached; when: home.item !== null }

    // The layer surface is kept mapped while the content can move out, so it never remaps (and restacks) mid-way;
    // it is rebuilt after the host's surface is, to land above it again.
    property bool rebuilding: false
    onHostEpochChanged: { root.away = false; root.rebuilding = true; rebuild.restart() }
    Timer { id: rebuild; interval: 0; onTriggered: root.rebuilding = false }
    LazyLoader {
        id: windowLoader
        // Only for content that shows: a hidden one (a recording mark while nothing records) keeps no surface.
        active: root.live && root.allowed && root.hostCalm && root.visible && root.content !== null && root.screen !== null && !root.rebuilding
        PanelWindow {
            id: surface
            // The placement the surface last put on screen; the content moves out once it matches.
            property string drawnKey: ""
            function redraw(): void {
                const quick = surface.contentItem?.Window.window
                if (quick) quick.update()
            }
            screen: root.screen
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            mask: Region {}
            WlrLayershell.namespace: "quickshell:inir-live"
            WlrLayershell.layer: root.surfaceLayer
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors { left: true; top: true }
            readonly property int originX: Math.max(0, Math.floor(root.placedRect.x) - root.pad)
            readonly property int originY: Math.max(0, Math.floor(root.placedRect.y) - root.pad)
            margins { left: surface.originX; top: surface.originY }
            implicitWidth: Math.max(1, Math.ceil(root.placedRect.x + root.placedRect.width) + root.pad - surface.originX)
            implicitHeight: Math.max(1, Math.ceil(root.placedRect.y + root.placedRect.height) + root.pad - surface.originY)
            Loader {
                id: away
                x: root.placedRect.x - surface.originX
                y: root.placedRect.y - surface.originY
                width: root.width
                height: root.height
                sourceComponent: root.content
                opacity: root.detached ? root.composedOpacity : 0
            }
            Binding { target: away.item; property: "drawing"; value: root.detached; when: away.item !== null }
            Connections {
                target: surface.contentItem?.Window.window ?? null
                function onFrameSwapped(): void { if (surface.drawnKey !== root.placedKey) surface.drawnKey = root.placedKey }
            }
        }
    }
}
