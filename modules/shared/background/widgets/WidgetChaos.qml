import QtQuick
import qs.services

// What a widget does when the mascot hits it (MascotChaos). The fling is a visual transform, so the position machinery
// is never touched mid-flight; on landing it persists (one config write, free placement only) or springs back home.
Item {
    id: root

    required property var widget
    property real dx: 0
    property real dy: 0
    property real angle: 0
    property real _flingX: 0
    property real _flingY: 0
    property real _flingRise: 120
    property real _flingSpin: 0
    property bool _persist: false
    property bool _wreck: false

    // Where the widget is, so the romp knows where to aim.
    readonly property bool watching: root.widget.visible
    Timer {
        id: report
        interval: 250
        onTriggered: MascotChaos.report(root.widget.editInstanceKey, root.widget.x, root.widget.y, root.widget.width,
            root.widget.height, root.widget.outputName, root.widget.configEntryName)
    }
    onWatchingChanged: {
        if (root.watching) report.restart()
        else MascotChaos.unreport(root.widget.editInstanceKey)
    }
    Component.onCompleted: if (root.watching) report.restart()
    Component.onDestruction: MascotChaos.unreport(root.widget.editInstanceKey)
    Connections {
        target: root.widget
        enabled: root.watching
        function onXChanged() { report.restart() }
        function onYChanged() { report.restart() }
        function onWidthChanged() { report.restart() }
        function onHeightChanged() { report.restart() }
    }

    SequentialAnimation {
        id: fling
        ParallelAnimation {
            NumberAnimation { target: root; property: "dx"; to: root._flingX; duration: 700; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "angle"; to: root._flingSpin; duration: 700; easing.type: Easing.OutCubic }
            SequentialAnimation {
                NumberAnimation { target: root; property: "dy"; to: -root._flingRise; duration: 260; easing.type: Easing.OutQuad }
                NumberAnimation { target: root; property: "dy"; to: root._flingY; duration: 440; easing.type: Easing.InQuad }
                NumberAnimation { target: root; property: "dy"; to: root._flingY - 14; duration: 120; easing.type: Easing.OutQuad }
                NumberAnimation { target: root; property: "dy"; to: root._flingY; duration: 140; easing.type: Easing.InQuad }
            }
        }
        onStopped: root._settle()
    }
    ParallelAnimation {
        id: goHome
        NumberAnimation { target: root; property: "dx"; to: 0; duration: 550; easing.type: Easing.OutBack }
        NumberAnimation { target: root; property: "dy"; to: 0; duration: 550; easing.type: Easing.OutBack }
        NumberAnimation { target: root; property: "angle"; to: 0; duration: 550; easing.type: Easing.OutBack }
    }
    NumberAnimation { id: straighten; target: root; property: "angle"; to: 0; duration: 300; easing.type: Easing.OutQuad }

    function _settle(): void {
        // A wreck stays face-down on the floor until tidy() picks it back up.
        if (root._wreck) return
        if (!root._persist) {
            goHome.restart()
            return
        }
        const widget = root.widget
        const nx = widget._clampX(widget.x + root.dx)
        const ny = widget._clampY(widget.y + root.dy)
        root.dx = 0
        root.dy = 0
        widget._setOutputValues({ x: Math.round(nx), y: Math.round(ny) })
        widget.syncFreePositionFromConfig()
        straighten.restart()
    }

    Connections {
        target: MascotChaos
        function onImpact(widgetKey, vx, vy, mode) {
            const widget = root.widget
            if (!MascotChaos.enabled || widgetKey !== widget.editInstanceKey) return
            if (MascotChaos.suppressed || !widget.visible || widget.locked) return
            fling.stop()
            goHome.stop()
            root._wreck = MascotChaos.allowRearrange && (mode === "wreck" || mode === "vanish")
            root._persist = MascotChaos.allowRearrange && mode === "persist" && widget.placementStrategy === "free"
            if (root._persist) MascotChaos.rememberOriginal(widget.editInstanceKey, widget.x, widget.y)
            root._flingX = vx
            if (mode === "vanish" && root._wreck) {
                // stolen: carried clean off the screen edge until tidy
                root._flingX = vx >= 0 ? widget.scaledScreenWidth - widget.x + widget.width : -(widget.x + widget.width * 2)
                root._flingY = 0
                root._flingRise = 30
                root._flingSpin = 0
            } else if (root._wreck) {
                // knocked out: drop to the floor and lie there, badly
                root._flingY = Math.max(0, widget.scaledScreenHeight - widget.y - widget.height - 8)
                root._flingRise = 40 + Math.random() * 40
                root._flingSpin = (vx >= 0 ? 1 : -1) * (60 + Math.random() * 30)
            } else {
                root._flingY = root._persist ? vy : 0
                root._flingRise = 90 + Math.random() * 70
                root._flingSpin = (vx >= 0 ? 1 : -1) * (8 + Math.random() * 14)
            }
            fling.restart()
        }
        function onTidied() {
            root._persist = false
            root._wreck = false
            fling.stop()
            goHome.stop()
            root._wreck = false
            // ease everything back upright instead of teleporting
            goHome.restart()
        }
    }
}
