import QtQuick
import qs.modules.common
import qs.services

// A widget while arranging, under a family that hosts it (DesktopEditStage): the picture of itself it leaves on the shelf,
// landing where it was dropped and growing out of that picture, shrinking into it when taken back. Gone with edit mode.
Item {
    id: root

    required property var widget

    // Its own picture for the shelf, when arranging starts and after it changes size (a grab per second per widget
    // stalled the whole mode); held or carried it keeps the last one. It stays on disk when this goes.
    readonly property bool picturing: DesktopEditStage.hosted(root.widget.outputName) && root.widget.visible
        && root.widget.width > 0 && root.widget.height > 0 && root.widget.configEntryName.length > 0
    property var picture: null
    property int takes: 0
    function takePicture(): void {
        const widget = root.widget
        if (widget._editEngaged || widget.isDragging || widget._isResizing || root.moving || !root.Window.window?.visible)
            return
        const w = Math.round(widget.width)
        const h = Math.round(widget.height)
        widget.grabToImage(result => {
            root.picture = result
            // On disk at once: the shelf reads a file at the size it shows it, sharp; a grab's own url can't be.
            const path = DesktopEditStage.savedPicture(widget.configEntryName)
            DesktopEditStage.setPicture(widget.configEntryName, result.saveToFile(path)
                ? "file://" + path + "?" + (++root.takes) : result.url, w, h)
        }, Qt.size(w, h))
    }
    Timer {
        id: pictureTimer
        interval: 600
        running: root.picturing
        onTriggered: root.takePicture()
    }
    function retake(): void {
        if (root.picturing) pictureTimer.restart()
    }
    Component.onDestruction: {
        if (!root.picture) return
        root.picture.saveToFile(DesktopEditStage.savedPicture(root.widget.configEntryName))
        DesktopEditStage.setPicture(root.widget.configEntryName, "", 0, 0)
    }

    // `shelf` runs 0 (the picture) to 1 (the widget in place).
    property real shelf: 1
    property rect shelfRect: Qt.rect(0, 0, 0, 0)
    readonly property bool moving: grow.running || shrinking.running
    readonly property real k: root.shelfRect.width > 0 && root.widget.width > 0 && root.widget.height > 0
        ? Math.min(root.shelfRect.width / root.widget.width, root.shelfRect.height / root.widget.height) : 1
    readonly property real shrink: 1 + (root.k - 1) * (1 - root.shelf)
    readonly property real dx: root.shelfRect.width > 0
        ? (root.shelfRect.x + (root.shelfRect.width - root.widget.width * root.k) / 2 - root.widget.x) * (1 - root.shelf) : 0
    readonly property real dy: root.shelfRect.width > 0
        ? (root.shelfRect.y + (root.shelfRect.height - root.widget.height * root.k) / 2 - root.widget.y) * (1 - root.shelf) : 0
    // A rect in screen px (the shelf's) seen from the desktop, which is a card while arranging.
    function fromScreen(rect: var): rect {
        const card = DesktopEditStage.cardFor(root.widget.outputName, root.widget.screenWidth, root.widget.screenHeight)
        return Qt.rect((rect.x - card.x) / card.s, (rect.y - card.y) / card.s, rect.width / card.s, rect.height / card.s)
    }

    property var landed: null
    function land(): void {
        const widget = root.widget
        const arrival = DesktopEditStage.arrival(widget.outputName, widget.configEntryName)
        if (!arrival || !widget._geometryReady || arrival === root.landed)
            return
        root.landed = arrival
        // A turn later: dropped from inside the handler of `arrival` it re-read itself (binding loop).
        Qt.callLater(DesktopEditStage.arrived, widget.outputName, widget.configEntryName)
        let spot = null
        if (arrival.at?.exact) {
            spot = { x: widget._clampX(arrival.at.x), y: widget._clampY(arrival.at.y) }
        } else if (arrival.at) {
            spot = widget._planDrop(arrival.at.x - widget.width / 2, arrival.at.y - widget.height / 2)
        } else {
            spot = DesktopArrange.plan(widget.outputName, widget.editInstanceKey, widget.x, widget.y, widget.width, widget.height, widget._stackId)
        }
        const wasX = widget.x
        const wasY = widget.y
        if (spot && (Math.abs(spot.x - widget.x) > 0.5 || Math.abs(spot.y - widget.y) > 0.5)) {
            widget.x = spot.x
            widget.y = spot.y
            widget._setOutputValues({ x: spot.x, y: spot.y, placementStrategy: "free" })
        }
        if (arrival.glide) {
            if (spot && widget.animationsActive) widget.glideFrom(wasX, wasY)
            return
        }
        if (!arrival.from || !widget.animationsActive)
            return
        root.shelfRect = root.fromScreen(arrival.from)
        root.shelf = 0
        grow.restart()
    }
    readonly property var arrival: DesktopEditStage.arrival(root.widget.outputName, root.widget.configEntryName)
    readonly property bool ready: root.widget._geometryReady
    onArrivalChanged: root.land()
    onReadyChanged: root.land()
    Component.onCompleted: root.land()

    readonly property var departure: DesktopEditStage.departure(root.widget.outputName, root.widget.configEntryName)
    onDepartureChanged: {
        if (!root.departure)
            return
        grow.stop()
        root.shelfRect = root.fromScreen(root.departure.to)
        shrinking.restart()
    }
    // Away from the shelf, or back into it from wherever the drop or the grid moved it.
    NumberAnimation {
        id: grow
        target: root
        property: "shelf"
        to: 1
        duration: FamilyStyle.duration(380)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: FamilyStyle.morphCurve
    }
    NumberAnimation {
        id: shrinking
        target: root
        property: "shelf"
        to: 0
        duration: DesktopEditStage.departDuration
        easing.type: Easing.InCubic
    }
}
