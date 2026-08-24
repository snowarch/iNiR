pragma ComponentBehavior: Bound
import qs.modules.barM3
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell
import Quickshell.Wayland

LazyLoader {
    id: root

    property Item hoverTarget
    property bool hoverActivates: true
    property bool closeOnOutsideClick: false
    property bool popupHovered: false
    property int hoverOpenDelay: 400
    default property Item contentItem
    property real popupBackgroundMargin: 0

    signal requestClose()

    readonly property bool targetHovered: hoverTarget
        && (hoverTarget.containsMouse ?? hoverTarget.buttonHovered ?? false)

    // The popup stays up while the pointer is over the bar item OR over the popup
    // itself, with a grace period for the masked gap between them. Keying `active`
    // on the bar item alone made every popup close the moment you moved towards it.
    readonly property bool hoverWanted: root.hoverActivates
        && (root.targetHovered || root.popupHovered)
    property bool _hoverHold: false

    onHoverWantedChanged: {
        if (root.hoverWanted) {
            root.hoverCloseTimer.stop()
            if (!root._hoverHold)
                root.hoverOpenTimer.restart()
        } else {
            root.hoverOpenTimer.stop()
            root.hoverCloseTimer.restart()
        }
    }

    property Timer hoverOpenTimer: Timer {
        interval: root.hoverOpenDelay
        repeat: false
        onTriggered: {
            if (root.hoverWanted)
                root._hoverHold = true
        }
    }

    // A property, not an inline child: the default property here is
    // `contentItem`, so a bare Timer never gets assigned and its id never exists.
    property Timer hoverCloseTimer: Timer {
        interval: 220
        repeat: false
        onTriggered: root._hoverHold = false
    }

    active: root._hoverHold

    onActiveChanged: {
        if (!root.active)
            root.popupHovered = false
    }

    readonly property bool barVertical: Config.options?.bar?.vertical ?? false
    readonly property string barEdge: {
        if (!root.barVertical)
            return (Config.options?.bar?.bottom ?? false) ? "bottom" : "top"
        return (Config.options?.bar?.bottom ?? false) ? "right" : "left"
    }
    readonly property real m3OuterGap: (Config.options?.bar?.m3?.cornerStyle ?? 0) === 3
        ? (Config.options?.bar?.m3?.gapsOut ?? 0)
        : 0
    readonly property real barThickness: root.barVertical
        ? Appearance.sizes.verticalBarWidth + root.m3OuterGap
        : Appearance.sizes.barHeight + root.m3OuterGap

    PanelWindow {
        id: clickOutsideBackdrop
        visible: root.active && root.closeOnOutsideClick
        color: Qt.rgba(0, 0, 0, 1 / 255)
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:m3-popup-catcher"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: root.requestClose()
        }
    }

    component: PanelWindow {
        id: popupWindow

        property Item innerContent: root.contentItem

        color: "transparent"
        anchors.left: root.barEdge !== "right"
        anchors.right: root.barEdge === "right"
        anchors.top: root.barEdge !== "bottom"
        anchors.bottom: root.barEdge === "bottom"

        implicitWidth: popupBackground.implicitWidth
            + Appearance.sizes.elevationMargin * 2
            + root.popupBackgroundMargin
        implicitHeight: popupBackground.implicitHeight
            + Appearance.sizes.elevationMargin * 2
            + root.popupBackgroundMargin

        readonly property real centerOffsetX: {
            const base = root.QsWindow?.mapFromItem(
                root.hoverTarget,
                ((root.hoverTarget?.width ?? 0) - popupBackground.implicitWidth) / 2,
                0
            ).x ?? Appearance.sizes.elevationMargin
            const margin = Appearance.sizes.elevationMargin
            const maxLeft = Math.max(margin,
                (popupWindow.screen?.width ?? popupBackground.implicitWidth)
                - popupBackground.implicitWidth - margin)
            return Math.max(margin, Math.min(base, maxLeft))
        }

        readonly property real centerOffsetY: {
            const base = root.QsWindow?.mapFromItem(
                root.hoverTarget,
                0,
                ((root.hoverTarget?.height ?? 0) - popupBackground.implicitHeight) / 2
            ).y ?? Appearance.sizes.elevationMargin
            const margin = Appearance.sizes.elevationMargin
            const maxTop = Math.max(margin,
                (popupWindow.screen?.height ?? popupBackground.implicitHeight)
                - popupBackground.implicitHeight - margin)
            return Math.max(margin, Math.min(base, maxTop))
        }

        mask: Region { item: popupBackground }
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        margins {
            left: {
                if (root.barEdge === "right") return 0
                if (root.barEdge === "left") return root.barThickness
                return popupWindow.centerOffsetX
            }
            top: {
                if (root.barEdge === "bottom") return 0
                if (root.barEdge === "top") return root.barThickness
                return popupWindow.centerOffsetY
            }
            right: root.barEdge === "right" ? root.barThickness : 0
            bottom: root.barEdge === "bottom" ? root.barThickness : 0
        }

        WlrLayershell.namespace: "quickshell:m3-popup"
        WlrLayershell.layer: WlrLayer.Overlay

        HoverHandler {
            onHoveredChanged: root.popupHovered = hovered
        }

        StyledRectangularShadow {
            target: popupBackground
        }

        Rectangle {
            id: popupBackground
            readonly property real margin: 10
            property bool shown: false

            anchors {
                fill: parent
                leftMargin: Appearance.sizes.elevationMargin
                    + root.popupBackgroundMargin * (!popupWindow.anchors.left)
                rightMargin: Appearance.sizes.elevationMargin
                    + root.popupBackgroundMargin * (!popupWindow.anchors.right)
                topMargin: Appearance.sizes.elevationMargin
                    + root.popupBackgroundMargin * (!popupWindow.anchors.top)
                bottomMargin: Appearance.sizes.elevationMargin
                    + root.popupBackgroundMargin * (!popupWindow.anchors.bottom)
            }

            implicitWidth: (popupWindow.innerContent?.implicitWidth ?? 0) + margin * 2
            implicitHeight: (popupWindow.innerContent?.implicitHeight ?? 0) + margin * 2

            color: M3Palette.surfaceContainer
            radius: Appearance.rounding.normal + 4
            border.width: 1
            border.color: M3Palette.outlineVariant
            opacity: shown ? 1 : 0
            scale: shown ? 1 : 0.94
            transformOrigin: root.barEdge === "bottom" ? Item.Bottom
                : root.barEdge === "left" ? Item.Left
                : root.barEdge === "right" ? Item.Right
                : Item.Top

            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
            Behavior on scale {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }

            Component.onCompleted: {
                if (popupWindow.innerContent) {
                    popupWindow.innerContent.parent = popupBackground
                    popupWindow.innerContent.anchors.centerIn = popupBackground
                }
                shown = true
            }
        }
    }
}
