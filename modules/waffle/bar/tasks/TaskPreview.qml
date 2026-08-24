import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks
import Quickshell

PopupWindow {
    id: root

    ///////////////////// Properties ////////////////////
    required property bool tasksHovered
    property var appEntry
    property Item anchorItem
    property bool contentResident: false

    //////////////////// Functions ////////////////////
    function close() {
        marginBehavior.enabled = false;
        root.visible = false;
        releaseTimer.restart()
    }

    function open() {
        releaseTimer.stop()
        root.contentResident = true
        marginBehavior.enabled = true;
        root.visible = true;
        // Capture previews for windows in this app entry
        captureAppPreviews();
    }

    function show(appEntry: var, button: Item) {
        root.appEntry = appEntry;
        root.anchorItem = button;
        root.anchor.updateAnchor();
        root.open();
    }

    // Capture previews for windows in the current app entry
    function captureAppPreviews(): void {
        if (!CompositorService.isNiri) return

        const windowIds = [];
        for (const tl of root.appEntry?.toplevels ?? []) {
            const id = tl?.niriWindowId
                ?? NiriService.findNiriWindow(tl)?.niriWindow?.id
                ?? -1
            if (id > 0)
                windowIds.push(id)
        }
        
        if (windowIds.length > 0) {
            WindowPreviewService.initialize();
            // captureForTaskView will capture windows that need it
            WindowPreviewService.captureForTaskView();
        }
    }

    ///////////////////// Internals /////////////////////
    readonly property bool bottom: Config.options?.waffles?.bar?.bottom ?? false
    property real visualMargin: Looks.dp(12)
    property real ambientShadowWidth: 1

    visible: false
    color: "transparent"
    implicitWidth: contentItem.implicitWidth + (ambientShadowWidth * 2) + (visualMargin * 2)
    implicitHeight: contentItem.implicitHeight + (ambientShadowWidth * 2) + (visualMargin * 2)
    mask: Region {
        item: contentItem
    }
    anchor {
        adjustment: PopupAdjustment.Slide
        item: root.anchorItem
        gravity: bottom ? Edges.Top : Edges.Bottom
        edges: bottom ? Edges.Top : Edges.Bottom
    }

    Timer {
        interval: 250
        running: root.visible && !hoverChecker.containsMouse && !root.tasksHovered
        onTriggered: {
            root.close();
        }
    }

    readonly property bool _anyPanelOpen: GlobalStates.searchOpen
        || GlobalStates.waffleActionCenterOpen
        || GlobalStates.waffleNotificationCenterOpen
        || GlobalStates.waffleWidgetsOpen
        || GlobalStates.waffleAltSwitcherOpen
        || GlobalStates.waffleClipboardOpen
        || GlobalStates.waffleTaskViewOpen
    on_AnyPanelOpenChanged: if (_anyPanelOpen && root.visible) root.close()

    Timer {
        id: releaseTimer
        interval: 250
        onTriggered: {
            root.contentResident = false
            root.appEntry = null
        }
    }

    // Content
    MouseArea {
        id: hoverChecker
        anchors.fill: parent
        hoverEnabled: true

        // Shadow
        WAmbientShadow {
            target: contentItem
        }

        Rectangle {
            id: contentItem
            property real sourceEdgeMargin: root.visible ? (root.ambientShadowWidth + root.visualMargin) : -root.implicitHeight
            Behavior on sourceEdgeMargin {
                id: marginBehavior
                animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.panel : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate }
            }
            anchors {
                left: parent.left
                right: parent.right
                top: root.bottom ? undefined : parent.top
                bottom: root.bottom ? parent.bottom : undefined
                margins: root.ambientShadowWidth + root.visualMargin
                // Opening anim
                bottomMargin: root.bottom ? sourceEdgeMargin : (root.ambientShadowWidth + root.visualMargin)
                topMargin: root.bottom ? (root.ambientShadowWidth + root.visualMargin) : sourceEdgeMargin
            }
            color: Looks.colors.popupSurface
            radius: Looks.radius.large

            layer.enabled: root.contentResident && Looks.effectsEnabled
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: contentItem.width
                    height: contentItem.height
                    radius: contentItem.radius
                }
            }

            implicitHeight: Math.min(Looks.dp(158), previewBranch.item?.implicitHeight ?? 0)
            implicitWidth: previewBranch.item?.implicitWidth ?? 0

            // Avoid resident screencopy captures while hidden.
            Loader {
                id: previewBranch
                anchors.fill: parent
                active: root.contentResident
                sourceComponent: classicWindows
            }
        }
    }

    Component {
        id: classicWindows

        RowLayout {
            Repeater {
                model: ScriptModel {
                    values: root.appEntry?.toplevels ?? []
                }
                delegate: WindowPreview {
                    required property var modelData
                    toplevel: modelData
                }
            }
        }
    }

}
