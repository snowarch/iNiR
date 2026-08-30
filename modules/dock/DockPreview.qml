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
    property Item anchorItem
    property string dockPosition: Config.options?.dock?.position ?? "bottom"

    readonly property bool isBottom: dockPosition === "bottom"
    readonly property bool isTop: dockPosition === "top"
    readonly property bool isLeft: dockPosition === "left"
    readonly property bool isRight: dockPosition === "right"
    readonly property bool isVertical: isLeft || isRight

    property real visualMargin: 12
    property real ambientShadowWidth: 1

    ///////////////////// Functions ////////////////////

    function close(): void {
        marginBehavior.enabled = false
        root.visible = false
    }

    onAnchorItemChanged: {
        if (root.visible && !root.anchorItem)
            root.close()
    }

    function open(): void {
        marginBehavior.enabled = true
        root.visible = true
    }

    function show(appEntry: var, button: Item): void {
        root.appEntry = appEntry
        root.anchorItem = button
        root.anchor.updateAnchor()
        WindowPreviewService.captureForTaskView()
        root.open()
    }

    ///////////////////// Model ////////////////////

    readonly property var liveToplevels: root.anchorItem?.toplevels ?? root.appEntry?.toplevels ?? []

    // Wrap toplevels with a stable key so ScriptModel preserves delegates
    // across model rebuilds (prevents delegate recreation → icon flash).
    readonly property var previewEntries: {
        const tls = root.liveToplevels
        const out = []
        for (let i = 0; i < tls.length; i++) {
            const t = tls[i]
            if (!t) continue
            out.push({ toplevel: t, previewKey: _windowKey(t) })
        }
        return out
    }

    function _windowKey(toplevel): string {
        if (!toplevel) return ""
        if (CompositorService.isNiri && toplevel.niriWindowId)
            return "niri:" + toplevel.niriWindowId
        if (toplevel.address)
            return "addr:" + toplevel.address
        return "id:" + (toplevel.appId ?? "") + ":" + (toplevel.title ?? "")
    }

    // Auto-close when the last window is gone.
    // Also watch anchorItem.toplevels directly because the JS optional-chain
    // in `liveToplevels` breaks QML's binding tracking.
    onLiveToplevelsChanged: {
        if (root.visible && (liveToplevels?.length ?? 0) === 0)
            root.close()
    }
    Connections {
        target: root.anchorItem
        enabled: root.visible
        function onToplevelsChanged() {
            if ((root.anchorItem?.toplevels?.length ?? 0) === 0)
                root.close()
        }
    }

    ///////////////////// Internals ////////////////////

    visible: false
    color: "transparent"
    implicitWidth: contentItem.implicitWidth + ambientShadowWidth + (visualMargin * 2)
    implicitHeight: contentItem.implicitHeight + ambientShadowWidth + (visualMargin * 2)
    mask: Region {
        item: contentItem
    }

    // Brief immunity after closing a window from within the preview,
    // so the popup survives the resize that moves the cursor outside.
    property bool _closeGrace: false
    Timer {
        id: graceTimer
        interval: 500
        onTriggered: root._closeGrace = false
    }

    anchor {
        adjustment: PopupAdjustment.Slide
        item: root.anchorItem
        gravity: root.isBottom ? Edges.Top : (root.isTop ? Edges.Bottom : (root.isLeft ? Edges.Right : Edges.Left))
        edges: root.isBottom ? Edges.Top : (root.isTop ? Edges.Bottom : (root.isLeft ? Edges.Right : Edges.Left))
    }

    // Close when mouse leaves both popup and dock
    Timer {
        interval: 250
        running: root.visible && !hoverChecker.containsMouse && !root.dockHovered && !root._closeGrace
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
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
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

            fallbackColor: Appearance.regaliaEverywhere ? "transparent"
                : Appearance.zzzEverywhere ? Appearance.zzz.bg1 : Appearance.colors.colSurfaceContainer
            inirColor: Appearance.inir?.colLayer2 ?? Appearance.colors.colSurfaceContainer
            auroraTransparency: Appearance.aurora?.popupTransparentize ?? 0.1
            radius: Appearance.regaliaEverywhere ? Appearance.regalia.roundLarge
                : Appearance.zzzEverywhere ? Appearance.zzz.panelRadius
                : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                : Appearance.inirEverywhere ? (Appearance.inir?.roundingNormal ?? 12) : Appearance.rounding.normal
            Behavior on radius {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
            border.width: Appearance.regaliaEverywhere ? 0 : 1
            border.color: Appearance.regaliaEverywhere ? "transparent"
                : Appearance.zzzEverywhere ? Appearance.zzz.borderColor
                : Appearance.angelEverywhere ? Appearance.angel.colBorder
                : Appearance.inirEverywhere
                ? (Appearance.inir?.colBorder ?? "transparent")
                : Appearance.auroraEverywhere
                    ? (Appearance.aurora?.colTooltipBorder ?? "transparent")
                    : Appearance.colors.colSurfaceContainerHighest
            Behavior on border.color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }

            RegaliaPlate {
                anchors.fill: parent
                visible: Appearance.regaliaEverywhere
                fillColor: Appearance.regalia.bg2
                radius: contentItem.radius
                inset: Appearance.regalia.surfaceInset
                elevated: true
                glassEnabled: true
            }

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
                        values: root.previewEntries
                        objectProp: "previewKey"
                    }
                    delegate: DockWindowPreview {
                        required property var modelData
                        toplevel: modelData?.toplevel ?? null
                        onWindowActivated: {
                            if (!(Config.options?.dock?.keepPreviewOnClick ?? false))
                                root.close()
                        }
                        onWindowCloseClicked: {
                            root._closeGrace = true
                            graceTimer.restart()
                        }
                    }
                }
            }
        }
    }
}
