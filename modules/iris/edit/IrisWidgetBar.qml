pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.modules.common
import qs.services
import qs.modules.iris.frame
import qs.modules.iris.style
import qs.modules.iris.components

// The shelf while arranging the desktop. It lives in the chassis so the field draws its body joined to the frame on the
// edge opposite the Island, and it grows out of that edge the way a drawer opens; its content rises with it.
Item {
    id: root

    property var screenData: null
    readonly property real d: IrisStyle.density
    readonly property string outputName: root.screenData?.name ?? ""
    readonly property bool bottomEdge: String(Config.options?.iris?.bar?.position ?? "top") !== "bottom"
    readonly property bool present: GlobalStates.widgetEditMode
    readonly property real presentation: presentSpring.value
    readonly property bool shown: root.presentation > 0.001
    // Arranging widgets on this screen: the chassis owns the keyboard, because the desktop layer under the windows
    // never gets it without a click (Niri gives Bottom-layer surfaces on-demand focus only). Ctrl+F finds a widget,
    // the arrows move the selected one, Escape steps out: search, then selection, then the mode.
    // A Place opened from here (Settings, Spotlight, the Control Center) has its own keys.
    readonly property bool holdsKeyboard: root.present && (GlobalStates.focusedScreen?.name ?? root.outputName) === root.outputName
        && !GlobalStates.searchOpen && !GlobalStates.settingsOverlayOpen && !GlobalStates.controlPanelOpen
    readonly property bool selecting: GlobalStates.selectedDesktopWidget.length > 0
    Shortcut { sequence: "Ctrl+F"; enabled: root.holdsKeyboard && !shelf.searching; onActivated: shelf.openSearch() }
    Shortcut {
        sequence: "Escape"
        enabled: root.holdsKeyboard
        onActivated: {
            if (shelf.searching) shelf.escapeSearch()
            else if (root.selecting) GlobalStates.clearDesktopWidgetSelection()
            else GlobalStates.setWidgetEditMode(false)
        }
    }
    Shortcut { sequences: [StandardKey.Undo]; enabled: root.holdsKeyboard && !shelf.searching; onActivated: DesktopEditHistory.undo() }
    Shortcut { sequences: [StandardKey.Redo, "Ctrl+Y"]; enabled: root.holdsKeyboard && !shelf.searching; onActivated: DesktopEditHistory.redo() }
    readonly property bool nudging: root.holdsKeyboard && root.selecting && !shelf.searching
    Shortcut { sequence: "Left"; enabled: root.nudging; onActivated: GlobalStates.desktopWidgetNudge(-1, 0) }
    Shortcut { sequence: "Right"; enabled: root.nudging; onActivated: GlobalStates.desktopWidgetNudge(1, 0) }
    Shortcut { sequence: "Up"; enabled: root.nudging; onActivated: GlobalStates.desktopWidgetNudge(0, -1) }
    Shortcut { sequence: "Down"; enabled: root.nudging; onActivated: GlobalStates.desktopWidgetNudge(0, 1) }
    Shortcut { sequence: "Shift+Left"; enabled: root.nudging; onActivated: GlobalStates.desktopWidgetNudge(-10, 0) }
    Shortcut { sequence: "Shift+Right"; enabled: root.nudging; onActivated: GlobalStates.desktopWidgetNudge(10, 0) }
    Shortcut { sequence: "Shift+Up"; enabled: root.nudging; onActivated: GlobalStates.desktopWidgetNudge(0, -10) }
    Shortcut { sequence: "Shift+Down"; enabled: root.nudging; onActivated: GlobalStates.desktopWidgetNudge(0, 10) }

    readonly property real fullHeight: shelf.fullHeight
    readonly property real bodyWidth: Math.max(Math.round(480 * root.d), Math.min(Math.round(1640 * root.d),
        root.width - 2 * IrisFrame.band - Math.round(128 * root.d)))
    readonly property real bodyHeight: Math.round(root.fullHeight * Math.max(0, Math.min(1, root.presentation)))
    readonly property real bodyRadius: Math.min(IrisStyle.radius, root.bodyHeight / 2)
    readonly property real bodyX: Math.round((root.width - root.bodyWidth) / 2)
    readonly property real bodyY: root.bottomEdge ? root.height - IrisFrame.band - root.bodyHeight : IrisFrame.band

    readonly property var hitRect: root.shown
        ? Qt.rect(root.bodyX, root.bodyY, root.bodyWidth, root.bodyHeight) : Qt.rect(0, 0, 0, 0)
    readonly property var fieldShapes: root.shown ? [{
        x: root.bodyX, y: root.bodyY, width: root.bodyWidth, height: root.bodyHeight,
        radius: root.bodyRadius, fuse: IrisStyle.fuse, paints: true,
        id: "widgetbar", joins: IrisFrame.framed ? "frame" : ""
    }] : []

    // The desktop recedes into a card between the Island and this bar while arranging, and the windows of the
    // workspace step aside on an empty one (DesktopEditStage).
    readonly property real islandRoom: IrisFrame.band + IrisFrame.islandVisualDepth
    readonly property real barRoom: IrisFrame.band + root.fullHeight
    readonly property var stageNow: [root.outputName, Math.max(0, Math.min(1.2, root.presentation)),
        root.bottomEdge ? root.islandRoom : root.barRoom, root.bottomEdge ? root.barRoom : root.islandRoom]
    onStageNowChanged: DesktopEditStage.setStage(root.stageNow[0], root.stageNow[1], root.stageNow[2], root.stageNow[3])
    // The windows come back once the card has grown back into the desktop, not over a shrunk one.
    readonly property bool parks: root.present && (GlobalStates.focusedScreen?.name ?? root.outputName) === root.outputName
    onParksChanged: if (root.parks) DesktopEditStage.park(root.outputName)
    readonly property bool settledHome: !root.present && root.presentation < 0.04
    onSettledHomeChanged: if (root.settledHome) DesktopEditStage.unpark()
    Component.onDestruction: {
        DesktopEditStage.setStage(root.outputName, 0, 0, 0)
        if (!root.present) DesktopEditStage.unpark()
    }

    IrisSpring {
        id: presentSpring
        surface: "panels"
        to: root.entered && root.present ? 1 : 0
        intent: "auto"
        minimum: 0
    }
    // Made on demand when the mode starts, the spring would begin at its target and the bar would just be
    // there, its blur ahead of its body. It starts hidden and is sent in on the next turn.
    property bool entered: false
    Timer { id: enterTimer; interval: 0; onTriggered: root.entered = true }
    Component.onCompleted: enterTimer.start()

    // The shelf's pictures are each widget's own, under the look worn now: another scheme or Design shows its glyph
    // until the widget has been seen in it.
    readonly property string look: (IrisStyle.light ? "light" : "dark") + "-" + IrisDesign.current
    onLookChanged: if (root.present) DesktopEditStage.look = root.look
    onPresentChanged: if (root.present) root.prepare()
    function prepare(): void {
        DesktopEditStage.look = root.look
        Quickshell.execDetached(["mkdir", "-p", DesktopEditStage.pictureDir])
    }

    Item {
        id: drawer
        x: root.bodyX
        y: root.bodyY
        width: root.bodyWidth
        height: root.bodyHeight
        clip: true
        visible: root.shown
        IrisWidgetShelf {
            id: shelf
            outputName: root.outputName
            ghostLayer: root
            bodyRadius: IrisStyle.radius
            width: drawer.width
            height: shelf.fullHeight
            // The content rides the edge that grows, so it rises out of the frame instead of being uncovered.
            y: root.bottomEdge ? 0 : drawer.height - shelf.fullHeight
            enabled: root.present
            opacity: IrisStyle.contentAt(root.presentation)
        }
    }
}
