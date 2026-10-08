pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.modules.common
import qs.modules.background.widgets
import qs.modules.iris.frame
import qs.modules.iris.style
import qs.modules.iris.components

// The desktop widgets toolbar while arranging them. It lives in the chassis so the field draws its
// body joined to the frame on the edge opposite the Island, the way the Edit bar does.
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
    Shortcut { sequence: "Ctrl+F"; enabled: root.holdsKeyboard && !toolbar.searching; onActivated: toolbar.openSearch() }
    Shortcut {
        sequence: "Escape"
        enabled: root.holdsKeyboard
        onActivated: {
            if (toolbar.searching) toolbar.escapeSearch()
            else if (root.selecting) GlobalStates.clearDesktopWidgetSelection()
            else GlobalStates.setWidgetEditMode(false)
        }
    }
    readonly property bool nudging: root.holdsKeyboard && root.selecting && !toolbar.searching
    Shortcut { sequence: "Left"; enabled: root.nudging; onActivated: GlobalStates.desktopWidgetNudge(-1, 0) }
    Shortcut { sequence: "Right"; enabled: root.nudging; onActivated: GlobalStates.desktopWidgetNudge(1, 0) }
    Shortcut { sequence: "Up"; enabled: root.nudging; onActivated: GlobalStates.desktopWidgetNudge(0, -1) }
    Shortcut { sequence: "Down"; enabled: root.nudging; onActivated: GlobalStates.desktopWidgetNudge(0, 1) }
    Shortcut { sequence: "Shift+Left"; enabled: root.nudging; onActivated: GlobalStates.desktopWidgetNudge(-10, 0) }
    Shortcut { sequence: "Shift+Right"; enabled: root.nudging; onActivated: GlobalStates.desktopWidgetNudge(10, 0) }
    Shortcut { sequence: "Shift+Up"; enabled: root.nudging; onActivated: GlobalStates.desktopWidgetNudge(0, -10) }
    Shortcut { sequence: "Shift+Down"; enabled: root.nudging; onActivated: GlobalStates.desktopWidgetNudge(0, 10) }

    readonly property real bodyWidth: toolbar.bodyWidth
    readonly property real bodyHeight: toolbar.bodyHeight
    readonly property real bodyRadius: toolbar.bodyRadius
    readonly property real restY: root.bottomEdge ? root.height - IrisFrame.band - root.bodyHeight : IrisFrame.band
    readonly property real hiddenY: root.bottomEdge ? root.height + Math.round(8 * root.d) : -root.bodyHeight - Math.round(8 * root.d)
    readonly property real bodyX: Math.round((root.width - root.bodyWidth) / 2)
    readonly property real bodyY: Math.round(root.hiddenY + (root.restY - root.hiddenY) * Math.min(1, root.presentation))

    readonly property var hitRect: root.shown
        ? Qt.rect(root.bodyX, root.bodyY, root.bodyWidth, root.bodyHeight) : Qt.rect(0, 0, 0, 0)
    readonly property var fieldShapes: root.shown ? [{
        x: root.bodyX, y: root.bodyY, width: root.bodyWidth, height: root.bodyHeight,
        radius: root.bodyRadius, fuse: IrisStyle.fuse, paints: true,
        id: "widgetbar", joins: IrisFrame.framed ? "frame" : ""
    }] : []

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

    DesktopEditToolbar {
        id: toolbar
        bodyless: true
        visible: root.shown
        enabled: root.present
        opacity: Math.min(1, root.presentation * 1.6)
        availableWidth: Math.max(0, root.width - 2 * IrisFrame.band - Math.round(48 * root.d))
        availableHeight: root.height
        outputName: root.outputName
        attachedTopEdge: !root.bottomEdge
        libraryOpen: GlobalStates.desktopWidgetManagerOutput === root.outputName
        x: root.bodyX - toolbar.fillet
        y: root.bodyY
        onLibraryRequested: GlobalStates.desktopWidgetManagerToggleRequested(root.outputName)
        onEdgeSettingsRequested: GlobalStates.openSettingsPage(14, "Organic edge")
        onSettingsRequested: GlobalStates.openSettingsPage(14)
        onDoneRequested: GlobalStates.setWidgetEditMode(false)
    }
}
