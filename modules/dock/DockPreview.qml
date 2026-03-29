pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

PopupWindow {
    id: root

    required property bool dockHovered
    property var appEntry
    property string appId: ""
    property Item anchorItem
    property string dockPosition: Config.options?.dock?.position ?? "bottom"
    property string lastCaptureSignature: ""

    readonly property bool isBottom: dockPosition === "bottom"
    readonly property bool isTop: dockPosition === "top"
    readonly property bool isLeft: dockPosition === "left"
    readonly property bool isRight: dockPosition === "right"
    readonly property bool isVertical: isLeft || isRight

    property real visualMargin: 12
    property real ambientShadowWidth: 1

    function close(): void {
        marginBehavior.enabled = false
        root.lastCaptureSignature = ""
        root.visible = false
    }

    function open(): void {
        marginBehavior.enabled = true
        root.visible = true
    }

    function show(appEntry: var, button: Item): void {
        root.appEntry = appEntry
        root.appId = appEntry?.appId ?? ""
        root.lastCaptureSignature = ""
        root.anchorItem = button
        root.anchor.updateAnchor()
        // Capture previews for the windows
        WindowPreviewService.captureForTaskView()
        root.open()
    }

    // Toplevels are already sorted by spatial layout in DockApps.qml
    // (via CompositorService.sortedToplevels)
    readonly property var liveToplevels: root.anchorItem?.toplevels ?? root.appEntry?.toplevels ?? []
    readonly property var previewEntries: {
        const entries = []
        for (const toplevel of root.liveToplevels ?? []) {
            entries.push({
                previewKey: root._windowKey(toplevel),
                toplevel: toplevel,
            })
        }
        return entries
    }

    function _windowId(toplevel: var): int {
        return CompositorService.isNiri
            ? (toplevel?.niriWindowId ?? toplevel?.id ?? -1)
            : (toplevel?.id ?? -1)
    }

    function _windowKey(toplevel: var): string {
        const windowId = root._windowId(toplevel)
        if (windowId > 0)
            return "window:" + windowId
        if (toplevel?.address !== undefined && toplevel?.address !== null && String(toplevel.address).length > 0)
            return "addr:" + toplevel.address
        return "app:" + (toplevel?.appId ?? "") + ":" + (toplevel?.title ?? "")
    }

    function maybeCaptureMissingPreviews(toplevels: list<var>): void {
        let needsCapture = false
        const signatureParts = []

        for (const toplevel of toplevels ?? []) {
            const windowId = root._windowId(toplevel)
            if (windowId <= 0)
                continue
            signatureParts.push(String(windowId))
            if (!WindowPreviewService.hasPreview(windowId))
                needsCapture = true
        }

        const signature = signatureParts.join(",")
        if (!needsCapture) {
            root.lastCaptureSignature = signature
            return
        }

        if (!signature || root.lastCaptureSignature === signature)
            return

        root.lastCaptureSignature = signature
        WindowPreviewService.captureForTaskView()
    }

    function _sortedToplevels(): list<var> {
        return root.liveToplevels ?? [];
    }

    function syncVisibleWindows(): void {
        if (!root.visible)
            return

        const currentLive = root.liveToplevels ?? []
        if (currentLive.length > 0) {
            root.maybeCaptureMissingPreviews(currentLive)
            return
        }

        const currentAppId = root.appId
        if (!currentAppId) {
            root.close()
            return
        }

        const allToplevels = CompositorService.sortedToplevels && CompositorService.sortedToplevels.length
                ? CompositorService.sortedToplevels
                : ToplevelManager.toplevels.values

        const current = allToplevels.filter(
            t => t.appId && t.appId.toLowerCase() === currentAppId
        )

        if (current.length === 0) {
            root.close()
            return
        }

        root.appEntry = Object.assign({}, root.appEntry ?? {}, {
            appId: currentAppId,
            toplevels: current,
        })
        root.maybeCaptureMissingPreviews(current)
    }

    visible: false
    color: "transparent"
    implicitWidth: contentItem.implicitWidth + ambientShadowWidth + (visualMargin * 2)
    implicitHeight: contentItem.implicitHeight + ambientShadowWidth + (visualMargin * 2)

    // Reactively update preview when toplevels change (e.g. window closed)
    Connections {
        target: ToplevelManager.toplevels
        function onValuesChanged() {
            root.syncVisibleWindows()
        }
    }

    Connections {
        target: root.anchorItem
        ignoreUnknownSignals: true
        function onToplevelsChanged() {
            root.syncVisibleWindows()
        }
    }

    anchor {
        adjustment: PopupAdjustment.Slide
        item: root.anchorItem
        gravity: root.isBottom ? Edges.Top : (root.isTop ? Edges.Bottom : (root.isLeft ? Edges.Right : Edges.Left))
        edges: root.isBottom ? Edges.Top : (root.isTop ? Edges.Bottom : (root.isLeft ? Edges.Right : Edges.Left))
    }

    // Close timer - only triggers when mouse leaves BOTH popup AND dock area
    Timer {
        interval: 250
        running: root.visible && !hoverChecker.containsMouse && !root.dockHovered
        onTriggered: root.close()
    }

    MouseArea {
        id: hoverChecker
        anchors.fill: parent
        hoverEnabled: true

        StyledRectangularShadow {
            target: contentItem
        }

        GlassBackground {
            id: contentItem
            property real sourceEdgeMargin: root.visible 
                ? (root.ambientShadowWidth + root.visualMargin) 
                : (root.isVertical ? -root.implicitWidth : -root.implicitHeight)

            Behavior on sourceEdgeMargin {
                id: marginBehavior
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            anchors {
                left: root.isRight ? parent.left : (root.isLeft ? undefined : parent.left)
                right: root.isLeft ? parent.right : (root.isRight ? undefined : parent.right)
                top: root.isBottom ? undefined : (root.isTop ? parent.top : parent.top)
                bottom: root.isTop ? undefined : (root.isBottom ? parent.bottom : parent.bottom)
                margins: root.ambientShadowWidth + root.visualMargin
                bottomMargin: root.isBottom ? sourceEdgeMargin : (root.ambientShadowWidth + root.visualMargin)
                topMargin: root.isTop ? sourceEdgeMargin : (root.ambientShadowWidth + root.visualMargin)
                leftMargin: root.isLeft ? sourceEdgeMargin : (root.ambientShadowWidth + root.visualMargin)
                rightMargin: root.isRight ? sourceEdgeMargin : (root.ambientShadowWidth + root.visualMargin)
            }

            fallbackColor: Appearance.colors.colSurfaceContainer
            inirColor: Appearance.inir?.colLayer2 ?? Appearance.colors.colSurfaceContainer
            auroraTransparency: Appearance.aurora?.popupTransparentize ?? 0.1
            radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                : Appearance.inirEverywhere ? (Appearance.inir?.roundingNormal ?? 12) : Appearance.rounding.normal
            border.width: 1
            border.color: Appearance.angelEverywhere ? Appearance.angel.colBorder
                : Appearance.inirEverywhere 
                ? (Appearance.inir?.colBorder ?? "transparent")
                : Appearance.auroraEverywhere 
                    ? (Appearance.aurora?.colTooltipBorder ?? "transparent")
                    : Appearance.colors.colSurfaceContainerHighest

            layer.enabled: true
            layer.smooth: true
            layer.mipmap: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: contentItem.width
                    height: contentItem.height
                    radius: contentItem.radius
                }
            }

            implicitHeight: Math.min(160, windowsLayout.implicitHeight + 16)
            implicitWidth: windowsLayout.implicitWidth + 16

            RowLayout {
                id: windowsLayout
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Repeater {
                    model: ScriptModel {
                        objectProp: "previewKey"
                        values: root.previewEntries
                    }
                    delegate: DockWindowPreview {
                        required property var modelData
                        toplevel: modelData.toplevel
                        onWindowActivated: {
                            if (!(Config.options?.dock?.keepPreviewOnClick ?? false))
                                root.close()
                        }
                    }
                }
            }
        }
    }
}
