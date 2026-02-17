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

    function close(): void {
        marginBehavior.enabled = false
        root.visible = false
    }

    function open(): void {
        marginBehavior.enabled = true
        root.visible = true
    }

    function show(appEntry: var, button: Item): void {
        root.appEntry = appEntry
        root.anchorItem = button
        root.anchor.updateAnchor()
        // Capture previews for the windows
        WindowPreviewService.captureForTaskView()
        root.open()
    }

    visible: false
    color: "transparent"
    implicitWidth: contentItem.implicitWidth + ambientShadowWidth + (visualMargin * 2)
    implicitHeight: contentItem.implicitHeight + ambientShadowWidth + (visualMargin * 2)

    // Reactively update preview when toplevels change (e.g. window closed)
    Connections {
        target: ToplevelManager.toplevels
        function onValuesChanged() {
            if (!root.visible || !root.appEntry) return
            const appId = root.appEntry.appId
            if (!appId) return
            const current = ToplevelManager.toplevels.values.filter(
                t => t.appId && t.appId.toLowerCase() === appId
            )
            if (current.length === 0) {
                root.close()
            } else {
                root.appEntry = Object.assign({}, root.appEntry, { toplevels: current })
            }
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
                        values: root.appEntry?.toplevels ?? []
                    }
                    delegate: DockWindowPreview {
                        required property var modelData
                        toplevel: modelData
                    }
                }
            }
        }
    }
}
