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

// Window preview popup for bar-embedded taskbar.
// Supports all 4 bar positions: top, bottom, left, right.
PopupWindow {
    id: root

    required property bool dockHovered
    // "top", "bottom", "left", "right"
    property string barPosition: "top"
    property var appEntry
    property Item anchorItem

    readonly property bool isVertical: barPosition === "left" || barPosition === "right"

    property real visualMargin: 12
    property real ambientShadowWidth: 1

    function close(): void {
        marginBehavior.enabled = false
        root.visible = false
    }

    onAnchorItemChanged: {
        if (root.visible && !root.anchorItem)
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

    function _sortedToplevels(): list<var> {
        return root.appEntry?.toplevels ?? [];
    }

    visible: false
    color: "transparent"
    implicitWidth: contentItem.implicitWidth + ambientShadowWidth + (visualMargin * 2)
    implicitHeight: contentItem.implicitHeight + ambientShadowWidth + (visualMargin * 2)

    Connections {
        target: ToplevelManager.toplevels
        function onValuesChanged() {
            if (!root.visible || !root.appEntry) return
            const appId = root.appEntry.appId
            if (!appId) return
            const allToplevels = CompositorService.sortedToplevels && CompositorService.sortedToplevels.length
                    ? CompositorService.sortedToplevels
                    : ToplevelManager.toplevels.values;
            const current = allToplevels.filter(t => {
                const id = AppSearch.resolveWindowIdentity(t)
                return id && id.toLowerCase() === appId
            })
            if (current.length === 0) {
                root.close()
            } else {
                root.appEntry = Object.assign({}, root.appEntry, { toplevels: current })
            }
        }
    }

    // Anchor popup to appear on the OPPOSITE side of where the bar is
    anchor {
        adjustment: PopupAdjustment.Slide
        item: root.anchorItem
        gravity: root.barPosition === "top" ? Edges.Bottom
               : root.barPosition === "bottom" ? Edges.Top
               : root.barPosition === "left" ? Edges.Right
               : Edges.Left
        edges: root.barPosition === "top" ? Edges.Bottom
             : root.barPosition === "bottom" ? Edges.Top
             : root.barPosition === "left" ? Edges.Right
             : Edges.Left
    }

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
                enabled: Appearance.animationsEnabled
                id: marginBehavior
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }

            anchors {
                // For horizontal bar (top/bottom): fill width, slide from top or bottom
                left: root.isVertical ? undefined : parent.left
                right: root.isVertical ? (root.barPosition === "left" ? parent.right : undefined) : parent.right
                top: root.isVertical ? parent.top : (root.barPosition === "bottom" ? undefined : parent.top)
                bottom: root.isVertical ? parent.bottom : (root.barPosition === "top" ? undefined : parent.bottom)
                margins: root.ambientShadowWidth + root.visualMargin
                // The sliding edge gets the animated margin
                topMargin: root.barPosition === "top" ? sourceEdgeMargin : (root.ambientShadowWidth + root.visualMargin)
                bottomMargin: root.barPosition === "bottom" ? sourceEdgeMargin : (root.ambientShadowWidth + root.visualMargin)
                leftMargin: root.barPosition === "left" ? sourceEdgeMargin : (root.ambientShadowWidth + root.visualMargin)
                rightMargin: root.barPosition === "right" ? sourceEdgeMargin : (root.ambientShadowWidth + root.visualMargin)
            }

            fallbackColor: Appearance.colors.colSurfaceContainer
            inirColor: Appearance.inir?.colLayer2 ?? Appearance.colors.colSurfaceContainer
            auroraTransparency: Appearance.aurora?.popupTransparentize ?? 0.1
            radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                : Appearance.inirEverywhere ? (Appearance.inir?.roundingNormal ?? 12)
                : Appearance.rounding.normal
            border.width: 1
            border.color: Appearance.angelEverywhere ? Appearance.angel.colBorder
                : Appearance.inirEverywhere ? (Appearance.inir?.colBorder ?? "transparent")
                : Appearance.auroraEverywhere ? (Appearance.aurora?.colTooltipBorder ?? "transparent")
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

            implicitHeight: root.isVertical
                ? (windowsLayout.implicitHeight + 16)
                : Math.min(160, windowsLayout.implicitHeight + 16)
            implicitWidth: root.isVertical
                ? Math.min(200, windowsLayout.implicitWidth + 16)
                : (windowsLayout.implicitWidth + 16)

            // Horizontal bar: previews side by side. Vertical bar: previews stacked.
            GridLayout {
                id: windowsLayout
                anchors.fill: parent
                anchors.margins: 8
                rowSpacing: 8
                columnSpacing: 8
                columns: root.isVertical ? 1 : -1
                rows: root.isVertical ? -1 : 1

                Repeater {
                    model: ScriptModel {
                        values: root._sortedToplevels()
                    }
                    delegate: BarTaskbarWindowPreview {
                        required property var modelData
                        toplevel: modelData
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
