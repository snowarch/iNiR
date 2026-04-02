pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    property string text: ""
    property font font
    property bool extraVisibleCondition: true
    property bool alternativeVisibleCondition: false
    property int delay: 16
    property real horizontalPadding: 10
    property real verticalPadding: 5
    property real horizontalMargin: horizontalPadding
    property real verticalMargin: verticalPadding

    function setContentShown(shown: bool): void {
        if (root.contentItem && root.contentItem.shown !== undefined)
            root.contentItem.shown = shown
    }
    
    function updateAnchor() {
        tooltipLoader.item?.anchor?.updateAnchor();
    }

    readonly property bool parentHoverState: {
        if (!parent)
            return true
        if (parent.buttonHovered !== undefined)
            return parent.buttonHovered
        if (parent.hovered !== undefined)
            return parent.hovered
        return true
    }
    readonly property bool internalVisibleCondition: (extraVisibleCondition && parentHoverState) || alternativeVisibleCondition
    property var anchorEdges: Edges.Top
    property var anchorGravity: anchorEdges

    property Item contentItem: StyledToolTipContent {
        id: contentItem
        anchors.centerIn: parent
        text: root.text
        shown: false
        horizontalPadding: root.horizontalPadding
        verticalPadding: root.verticalPadding
    }

    // Whether we can use PopupWindow (requires QsWindow, i.e. PanelWindow context)
    readonly property bool _canUsePopupWindow: root.QsWindow.window !== null

    Timer {
        id: _showDelayTimer
        interval: root.delay
        onTriggered: root.setContentShown(true)
    }

    // Primary path: PopupWindow for shell overlay contexts (PanelWindow)
    Loader {
        id: tooltipLoader
        anchors.fill: parent
        active: root._canUsePopupWindow && root.visible && root.internalVisibleCondition
        onActiveChanged: {
            if (active) {
                root.setContentShown(false)
                _showDelayTimer.restart()
            } else {
                _showDelayTimer.stop()
                root.setContentShown(false)
            }
        }
        sourceComponent: PopupWindow {
            visible: true
            anchor {
                window: root.QsWindow.window
                item: root.parent
                edges: root.anchorEdges
                gravity: root.anchorGravity
            }
            mask: Region {
                item: null
            }

            color: "transparent"
            implicitWidth: root.contentItem.implicitWidth + root.horizontalMargin * 2
            implicitHeight: root.contentItem.implicitHeight + root.verticalMargin * 2

            data: [root.contentItem]
        }
    }

    // Fallback path: Item-based tooltip for ApplicationWindow contexts
    // Reparents to the Window's contentItem so the tooltip escapes all
    // clipping containers (Flickable, clip:true parents, etc.).
    Loader {
        id: fallbackLoader
        active: !root._canUsePopupWindow && root.visible && root.internalVisibleCondition
        onActiveChanged: {
            if (active) {
                root.setContentShown(false)
                _showDelayTimer.restart()
            } else {
                _showDelayTimer.stop()
                root.setContentShown(false)
            }
        }
        sourceComponent: Item {
            id: fallbackItem
            // Reparent to Window.contentItem to escape clipped containers
            parent: root.Window.window?.contentItem ?? root.parent ?? root
            z: 1000

            readonly property real tooltipW: root.contentItem.implicitWidth + root.horizontalMargin * 2
            readonly property real tooltipH: root.contentItem.implicitHeight + root.verticalMargin * 2

            width: tooltipW
            height: tooltipH

            // Position via x/y computed from the anchor item's geometry
            readonly property Item anchorItem: root.parent
            readonly property point anchorPos: {
                if (!anchorItem || !fallbackItem.parent)
                    return Qt.point(0, 0)
                return anchorItem.mapToItem(fallbackItem.parent, 0, 0)
            }
            readonly property real gap: 4

            x: {
                const edges = root.anchorEdges
                if (edges === Edges.Left)
                    return anchorPos.x - tooltipW - gap
                if (edges === Edges.Right)
                    return anchorPos.x + (anchorItem?.width ?? 0) + gap
                // Top or Bottom: center horizontally
                return anchorPos.x + ((anchorItem?.width ?? 0) - tooltipW) / 2
            }
            y: {
                const edges = root.anchorEdges
                if (edges === Edges.Top)
                    return anchorPos.y - tooltipH - gap
                if (edges === Edges.Bottom)
                    return anchorPos.y + (anchorItem?.height ?? 0) + gap
                // Left or Right: center vertically
                return anchorPos.y + ((anchorItem?.height ?? 0) - tooltipH) / 2
            }

            data: [root.contentItem]
        }
    }
}
