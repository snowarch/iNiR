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
        if (root._content && root._content.shown !== undefined)
            root._content.shown = shown
    }
    
    function updateAnchor() {
        if (root._canUsePopupWindow) shownLoader.item?.anchor?.updateAnchor();
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
    readonly property bool hasContent: root.text.trim().length > 0
    readonly property bool internalVisibleCondition: root.enabled && root.hasContent
        && ((extraVisibleCondition && parentHoverState) || alternativeVisibleCondition)
    property var anchorEdges: Edges.Top
    property var anchorGravity: anchorEdges

    // The tooltip body is built when the tooltip shows, not with its owner: the shell
    // declares ~800 tooltips and almost none are ever hovered. A prebuilt Item still
    // works through contentItem (it then lives as long as its owner).
    property Item contentItem: null
    property Component contentComponent: Component {
        StyledToolTipContent {
            anchors.centerIn: parent
            text: root.text
            shown: false
            position: root.anchorEdges === Edges.Top ? "top"
                    : root.anchorEdges === Edges.Left ? "left"
                    : root.anchorEdges === Edges.Right ? "right"
                    : "bottom"
            horizontalPadding: root.horizontalPadding
            verticalPadding: root.verticalPadding
        }
    }
    readonly property Item _content: root.contentItem ?? contentLoader.item

    Loader {
        id: contentLoader
        active: root.contentItem === null && shownLoader.active
        sourceComponent: root.contentComponent
    }

    // Whether we can use PopupWindow (requires QsWindow, i.e. PanelWindow context)
    readonly property bool _canUsePopupWindow: root.QsWindow.window !== null

    // One Loader for the shown tooltip, its path picked by the window it lives in; the show delay lives in what it
    // loads. Two Loaders and a Timer per tooltip, for the ~800 the shell declares, were mostly never used.
    Loader {
        id: shownLoader
        active: root.visible && root.internalVisibleCondition
        onActiveChanged: root.setContentShown(false)
        sourceComponent: root._canUsePopupWindow ? popupTooltip : itemTooltip
    }

    // Primary path: PopupWindow for shell overlay contexts (PanelWindow)
    Component {
        id: popupTooltip
        PopupWindow {
            visible: true
            // A property, not a child: `data` below is bound and would drop it.
            readonly property Timer showDelay: Timer {
                interval: root.delay
                running: true
                onTriggered: root.setContentShown(true)
            }
            readonly property real _gap: 4
            anchor {
                window: root.QsWindow.window
                item: root.parent
                rect.x: (root.anchorEdges === Edges.Left) ? -_gap : 0
                rect.y: (root.anchorEdges === Edges.Top) ? -_gap : 0
                rect.width: (root.parent?.width ?? 0) + ((root.anchorEdges === Edges.Left || root.anchorEdges === Edges.Right) ? _gap : 0)
                rect.height: (root.parent?.height ?? 0) + ((root.anchorEdges === Edges.Top || root.anchorEdges === Edges.Bottom) ? _gap : 0)
                edges: root.anchorEdges
                gravity: root.anchorGravity
            }
            mask: Region {
                item: null
            }

            color: "transparent"
            implicitWidth: (root._content?.implicitWidth ?? 0) + root.horizontalMargin * 2
            implicitHeight: (root._content?.implicitHeight ?? 0) + root.verticalMargin * 2

            data: root._content ? [root._content] : []
        }
    }

    // Fallback path: Item-based tooltip for ApplicationWindow contexts
    // Reparents to the Window's contentItem so the tooltip escapes all
    // clipping containers (Flickable, clip:true parents, etc.).
    Component {
        id: itemTooltip
        Item {
            id: fallbackItem
            // Reparent to Window.contentItem to escape clipped containers
            parent: root.Window.window?.contentItem ?? root.parent ?? root
            z: 1000

            readonly property real tooltipW: (root._content?.implicitWidth ?? 0) + root.horizontalMargin * 2
            readonly property real tooltipH: (root._content?.implicitHeight ?? 0) + root.verticalMargin * 2

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
            readonly property real viewportMargin: 6
            readonly property real preferredX: {
                const edges = root.anchorEdges
                if (edges === Edges.Left)
                    return anchorPos.x - tooltipW - gap
                if (edges === Edges.Right)
                    return anchorPos.x + (anchorItem?.width ?? 0) + gap
                return anchorPos.x + ((anchorItem?.width ?? 0) - tooltipW) / 2
            }
            readonly property real preferredY: {
                const edges = root.anchorEdges
                if (edges === Edges.Top)
                    return anchorPos.y - tooltipH - gap
                if (edges === Edges.Bottom)
                    return anchorPos.y + (anchorItem?.height ?? 0) + gap
                return anchorPos.y + ((anchorItem?.height ?? 0) - tooltipH) / 2
            }

            x: Math.max(viewportMargin, Math.min(preferredX,
                Math.max(viewportMargin, (parent?.width ?? tooltipW) - tooltipW - viewportMargin)))
            y: Math.max(viewportMargin, Math.min(preferredY,
                Math.max(viewportMargin, (parent?.height ?? tooltipH) - tooltipH - viewportMargin)))

            // A property, not a child: `data` below is bound and would drop it.
            readonly property Timer showDelay: Timer {
                interval: root.delay
                running: true
                onTriggered: root.setContentShown(true)
            }
            data: root._content ? [root._content] : []
        }
    }
}
