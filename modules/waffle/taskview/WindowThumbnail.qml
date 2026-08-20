pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.modules.waffle.bar

Item {
    id: root

    required property var windowData
    required property int workspaceSlot
    required property int indexInWorkspace
    required property int totalInWorkspace
    required property real thumbnailWidth
    required property real thumbnailHeight
    required property real workspaceSpacing
    required property bool isCurrentWorkspace
    required property real screenWidth

    property real proportion: 1.0
    property real proportionOffset: 0.0
    property real tileWidth: 0
    property int previewTotalInWorkspace: totalInWorkspace
    property bool isBeingDragged: false
    property bool isKeyboardFocused: false
    property string searchQuery: ""

    // Track focus state - compare with currently focused window
    property int _focusedWindowId: {
        const wins = NiriService.windows ?? []
        const focused = wins.find(w => w.is_focused)
        return focused?.id ?? -1
    }
    readonly property bool isFocused: windowData?.id === _focusedWindowId

    readonly property bool isMaximized: tileWidth > 0 && tileWidth >= (screenWidth - 60)

    function highlightText(text: string): string {
        if (!searchQuery || searchQuery.length === 0) return text
        const query = searchQuery.toLowerCase()
        const lowerText = text.toLowerCase()
        const idx = lowerText.indexOf(query)
        if (idx === -1) return text
        const before = text.substring(0, idx)
        const match = text.substring(idx, idx + query.length)
        const after = text.substring(idx + query.length)
        return before + "<span style='background-color:" + Looks.colors.accent + ";color:" + Looks.colors.fg + "'>" + match + "</span>" + after
    }

    signal dragStarted(int workspaceIdx, int windowId)
    signal dragEnded()
    signal niriAction(string action, int windowId)
    signal focusRequested(int workspaceSlot)  // Request to center this workspace

    // Layout calculations - uniform padding for centered content
    readonly property real padding: 12  // Same padding all around
    readonly property real gap: 8
    readonly property int effectiveTotal: isBeingDragged ? totalInWorkspace : previewTotalInWorkspace
    readonly property real totalGaps: gap * Math.max(0, effectiveTotal - 1)
    readonly property real availableWidth: thumbnailWidth - padding * 2 - totalGaps
    readonly property real cellWidth: availableWidth * proportion
    readonly property real cellHeight: thumbnailHeight - padding * 2
    readonly property real titleBarHeight: 26

    readonly property real wsOffsetX: workspaceSlot * (thumbnailWidth + workspaceSpacing)
    readonly property real baseX: wsOffsetX + padding + (availableWidth * proportionOffset) + (gap * indexInWorkspace)
    readonly property real baseY: padding

    x: baseX
    y: baseY
    width: cellWidth
    height: cellHeight

    Drag.keys: ["windowId"]
    Drag.mimeData: ({ "windowId": (windowData?.id ?? 0).toString() })
    z: Drag.active ? 1000 : 0

    property bool hovered: false
    property bool closeHovered: false

    // Entry animation - respects GameMode
    opacity: 0
    scale: 0.9

    Component.onCompleted: {
        if (Looks.transition.enabled) {
            windowEntryAnim.start()
        } else {
            opacity = 1
            scale = 1
        }
    }

    SequentialAnimation {
        id: windowEntryAnim
        PauseAnimation { duration: Looks.transition.staggerDelay(root.workspaceSlot * 3 + root.indexInWorkspace, 30) }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "opacity"
                to: 1
                duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate
            }
            NumberAnimation {
                target: root
                property: "scale"
                to: 1
                duration: Looks.transition.enabled ? Looks.transition.duration.panel : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Looks.transition.easing.bezierCurve.spring
            }
        }
    }

    Behavior on x {
        enabled: !root.Drag.active
        NumberAnimation {
            duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Looks.transition.easing.bezierCurve.standard
        }
    }
    Behavior on y {
        enabled: !root.Drag.active
        NumberAnimation {
            duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Looks.transition.easing.bezierCurve.standard
        }
    }
    Behavior on width {
        enabled: !root.Drag.active
        NumberAnimation {
            duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Looks.transition.easing.bezierCurve.standard
        }
    }
    Behavior on height {
        enabled: !root.Drag.active
        NumberAnimation {
            duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Looks.transition.easing.bezierCurve.standard
        }
    }

    Item {
        id: windowContainer
        anchors.fill: parent
        opacity: root.isFocused || root.hovered ? 1.0 : 0.7

        Behavior on opacity {
            NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0 }
        }

        WRectangularShadow {
            target: windowRect
            visible: Looks.effectsEnabled
                && (root.hovered || root.isFocused || root.Drag.active)
        }

        // Content container (title bar + preview)
        Rectangle {
            id: windowRect
            anchors.fill: parent
            radius: Looks.radius.medium
            color: Looks.colors.bg1Base
            clip: true

            // Title bar
            Item {
                id: titleBar
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: root.titleBarHeight
                z: 1

                Rectangle {
                    anchors.fill: parent
                    color: ColorUtils.transparentize(Looks.colors.bg0Opaque, 0.2)
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 28
                    spacing: 6

                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        source: Quickshell.iconPath(root.windowData?.app_id ?? "", "application-x-executable")
                        implicitWidth: 16
                        implicitHeight: 16
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 28
                        text: root.highlightText(root.windowData?.title ?? "")
                        textFormat: Text.StyledText
                        font.pixelSize: Looks.font.pixelSize.small
                        font.family: Looks.font.family.ui
                        color: Looks.colors.fg
                        elide: Text.ElideRight
                    }
                }
            }

            // Preview area - shows icon first, preview fades in when ready
            Item {
                id: previewArea
                anchors.top: titleBar.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                readonly property int windowId: root.windowData?.id ?? 0
                property string previewUrl: ""

                // Loading shimmer effect
                Rectangle {
                    id: shimmerBg
                    anchors.fill: parent
                    color: Looks.colors.bg2Base
                    visible: windowPreview.status !== Image.Ready

                    Rectangle {
                        id: shimmer
                        width: parent.width * 0.4
                        height: parent.height
                        x: -width
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.5; color: ColorUtils.transparentize(Looks.colors.fg, 0.92) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }

                        SequentialAnimation on x {
                            running: shimmerBg.visible && Looks.transition.enabled
                            loops: Animation.Infinite
                            NumberAnimation {
                                from: -shimmer.width
                                to: shimmerBg.width
                                duration: 1200
                                easing.type: Easing.InOutQuad
                            }
                            PauseAnimation { duration: 400 }
                        }
                    }
                }

                // Always visible icon - shown until preview loads
                IconImage {
                    id: fallbackIcon
                    anchors.centerIn: parent
                    source: Quickshell.iconPath(root.windowData?.app_id ?? "", "application-x-executable")
                    implicitWidth: Math.min(64, parent.width * 0.5)
                    implicitHeight: implicitWidth
                    opacity: windowPreview.status === Image.Ready ? 0 : 0.8

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                // Preview image - fill container
                Image {
                    id: windowPreview
                    source: previewArea.previewUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    mipmap: true
                    anchors.fill: parent
                    anchors.margins: 2
                    opacity: status === Image.Ready ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                // Listen for preview updates
                Connections {
                    target: WindowPreviewService
                    function onPreviewUpdated(updatedId: int): void {
                        if (updatedId === previewArea.windowId) {
                            const url = WindowPreviewService.getPreviewUrl(updatedId)
                            previewArea.previewUrl = url
                        }
                    }
                    function onCaptureComplete(): void {
                        // Refresh URL in case cache changed
                        const url = WindowPreviewService.getPreviewUrl(previewArea.windowId)
                        if (url) {
                            previewArea.previewUrl = url
                        }
                    }
                }

                // Also watch for previewCache changes directly
                Connections {
                    target: WindowPreviewService
                    function onPreviewCacheChanged(): void {
                        if (!previewArea.previewUrl) {
                            const url = WindowPreviewService.getPreviewUrl(previewArea.windowId)
                            if (url) previewArea.previewUrl = url
                        }
                    }
                }

                // Check if preview already exists on load
                Component.onCompleted: {
                    // Delay slightly to ensure service is ready
                    Qt.callLater(() => {
                        const url = WindowPreviewService.getPreviewUrl(windowId)
                        if (url) {
                            previewUrl = url
                        }
                    })
                }
            }
        }

        // Border overlay - on top of everything including title bar
        Rectangle {
            id: borderOverlay
            anchors.fill: parent
            radius: Looks.radius.medium
            color: "transparent"
            // Only show focus highlight if this window is focused AND in the currently selected workspace
            readonly property bool showFocusHighlight: root.isFocused && root.isCurrentWorkspace
            border.width: root.Drag.active || showFocusHighlight || root.isKeyboardFocused || root.hovered ? 2 : 1
            border.color: root.Drag.active || showFocusHighlight || root.isKeyboardFocused ? Looks.colors.accent :
                          root.hovered ? ColorUtils.transparentize(Looks.colors.accent, 0.5) : Looks.colors.bg2Border
            z: 10

            Behavior on border.color {
                ColorAnimation {
                    duration: Looks.transition.enabled ? Looks.transition.duration.fast : 0
                    easing.type: Easing.OutQuad
                }
            }

            // Drag/click area
            MouseArea {
                id: dragArea
                anchors.fill: parent
                hoverEnabled: true
                drag.target: root
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                property real pressX: 0
                property real pressY: 0
                property bool wasDragging: false

                onEntered: root.hovered = true
                onExited: if (!root.closeHovered) root.hovered = false

                onPressed: mouse => {
                    if (mouse.x > parent.width - 20 && mouse.y < 20) {
                        mouse.accepted = false
                        return
                    }

                    // Middle-click to close window
                    if (mouse.button === Qt.MiddleButton) {
                        NiriService.closeWindow(root.windowData?.id)
                        return
                    }

                    // Right-click opens context menu (no drag)
                    if (mouse.button === Qt.RightButton) {
                        // Close any other open menu first
                        if (GlobalStates.activeTaskViewMenu && GlobalStates.activeTaskViewMenu !== contextMenu) {
                            GlobalStates.activeTaskViewMenu.active = false
                        }
                        GlobalStates.activeTaskViewMenu = contextMenu
                        contextMenu.active = true
                        mouse.accepted = true
                        return
                    }

                    // Only left button starts drag
                    pressX = mouse.x
                    pressY = mouse.y
                    wasDragging = false
                    root.isBeingDragged = true
                    const ws = NiriService.workspaces?.[root.windowData?.workspace_id]
                    root.dragStarted(ws?.idx ?? -1, root.windowData?.id ?? -1)
                    root.Drag.active = true
                    root.Drag.source = root
                    root.Drag.hotSpot.x = mouse.x
                    root.Drag.hotSpot.y = mouse.y
                }

                onPositionChanged: mouse => {
                    // Only track drag for left button
                    if (root.Drag.active && mouse.buttons & Qt.LeftButton) {
                        const dx = Math.abs(mouse.x - pressX)
                        const dy = Math.abs(mouse.y - pressY)
                        if (dx > 10 || dy > 10) wasDragging = true
                    }
                }

                onReleased: mouse => {
                    if (mouse.button === Qt.RightButton) return

                    const wasActualDrag = wasDragging

                    root.Drag.active = false
                    root.isBeingDragged = false
                    root.dragEnded()
                    root.x = Qt.binding(() => root.baseX)
                    root.y = Qt.binding(() => root.baseY)

                    // Left click without drag = focus window and center on its workspace
                    if (mouse.button === Qt.LeftButton && !wasActualDrag) {
                        root.focusRequested(root.workspaceSlot)
                        NiriService.focusWindow(root.windowData?.id)
                        if (Config.options?.waffles?.taskView?.closeOnSelect) {
                            GlobalStates.waffleTaskViewOpen = false
                        }
                    }
                }

                onDoubleClicked: mouse => {
                    if (mouse.button === Qt.LeftButton) {
                        NiriService.focusWindow(root.windowData?.id)
                        GlobalStates.waffleTaskViewOpen = false
                    }
                }
            }

            // Tooltip with app name
            WToolTip {
                visible: root.hovered && !root.Drag.active && !root.closeHovered
                text: (root.windowData?.app_id ?? "Unknown") + (root.isMaximized ? " (Maximized)" : "")
            }

            // Close button in titleBar corner
            Rectangle {
                id: closeBtn
                anchors.right: parent.right
                anchors.top: parent.top
                width: root.titleBarHeight
                height: root.titleBarHeight
                radius: 0
                topRightRadius: Looks.radius.medium
                color: closeBtnArea.containsMouse ? Looks.colors.danger : "transparent"
                visible: root.hovered && !root.Drag.active
                z: 20

                Behavior on color {
                    animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                }

                WText {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: 10
                    color: closeBtnArea.containsMouse ? "white" : Looks.colors.fg
                }

                MouseArea {
                    id: closeBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: { root.hovered = true; root.closeHovered = true }
                    onExited: root.closeHovered = false
                    onClicked: NiriService.closeWindow(root.windowData?.id)
                }
            }

        }

        // Context menu - waffle style, positioned below thumbnail
        BarMenu {
            id: contextMenu
            anchorItem: windowContainer
            popupBelow: true
            closeOnFocusLost: false
            closeOnHoverLost: true
            anchorHovered: root.hovered

            onActiveChanged: {
                if (!active && GlobalStates.activeTaskViewMenu === contextMenu) {
                    GlobalStates.activeTaskViewMenu = null
                }
            }

            model: [
                {
                    iconName: "open",
                    text: Translation.tr("Switch to Window"),
                    action: () => {
                        contextMenu.active = false
                        NiriService.focusWindow(root.windowData?.id)
                        GlobalStates.waffleTaskViewOpen = false
                    }
                },
                { type: "separator" },
                {
                    iconName: "dismiss",
                    text: Translation.tr("Close Window"),
                    action: () => {
                        contextMenu.active = false
                        NiriService.closeWindow(root.windowData?.id)
                    }
                }
            ]
        }
    }
}
