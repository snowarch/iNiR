import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

TabButton {
    id: root

    property bool toggled: TabBar.tabBar?.currentIndex === TabBar.index
    property string buttonIcon
    property real buttonIconRotation: 0
    property string buttonText
    property bool expanded: false
    property bool showToggledHighlight: true
    readonly property real visualWidth: root.expanded ? root.baseSize + 20 + itemText.implicitWidth : root.baseSize

    property real baseSize: 56
    property real baseHighlightHeight: 32
    property real highlightCollapsedTopMargin: 8
    padding: 0

    // The navigation item’s target area always spans the full width of the
    // nav rail, even if the item container hugs its contents.
    Layout.fillWidth: true
    // implicitWidth: contentItem.implicitWidth
    implicitHeight: baseSize

    background: null
    PointingHandInteraction {}

    // Primary colored bubble tooltip that appears to the right when collapsed
    ToolTip {
        id: hoverBubble
        visible: !root.expanded && root.hovered
        delay: 0
        x: root.width + 4
        y: (root.height - height) / 2
        padding: 0
        background: Rectangle {
            color: Appearance.colors.colPrimary
            radius: Appearance.rounding.full
            implicitWidth: bubbleText.implicitWidth + 24
            implicitHeight: root.baseHighlightHeight
        }
        contentItem: StyledText {
            id: bubbleText
            text: root.buttonText
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Medium
            color: Appearance.colors.colOnPrimary
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    // Real stuff
    contentItem: Item {
        id: buttonContent
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
            right: undefined
        }

        implicitWidth: root.visualWidth
        implicitHeight: root.expanded ? itemIconBackground.implicitHeight : itemIconBackground.implicitHeight + itemText.implicitHeight

        Rectangle {
            id: itemBackground
            anchors.top: itemIconBackground.top
            anchors.left: itemIconBackground.left
            anchors.bottom: itemIconBackground.bottom
            // When collapsed, only show icon area; when expanded, show full width with text
            implicitWidth: root.expanded ? root.visualWidth : root.baseSize
            radius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
            color: Appearance.inirEverywhere
                ? (toggled
                    ? (root.showToggledHighlight
                        ? (root.down ? Appearance.inir.colLayer2Active : root.hovered ? Appearance.inir.colLayer2Hover : Appearance.inir.colLayer2)
                        : "transparent")
                    : (root.down ? Appearance.inir.colLayer2Active : root.hovered ? Appearance.inir.colLayer2Hover : "transparent"))
                : Appearance.auroraEverywhere
                    ? (toggled ?
                        root.showToggledHighlight ?
                            (root.down ? Appearance.aurora.colSubSurfaceActive : root.hovered ? Appearance.aurora.colSubSurface : Appearance.aurora.colElevatedSurface)
                            : "transparent" :
                        (root.down ? Appearance.aurora.colSubSurfaceActive : root.hovered ? Appearance.aurora.colSubSurface : "transparent"))
                    : (toggled ?
                        root.showToggledHighlight ?
                            (root.down ? Appearance.colors.colSecondaryContainerActive : root.hovered ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colSecondaryContainer)
                            : (root.down ? Appearance.colors.colLayer1Active : root.hovered ? Appearance.colors.colLayer1Hover : ColorUtils.transparentize(Appearance.m3colors.m3primary, 0.92)) :
                        (root.down ? Appearance.colors.colLayer1Active : root.hovered ? Appearance.colors.colLayer1Hover : "transparent"))

            states: State {
                name: "expanded"
                when: root.expanded
                AnchorChanges {
                    target: itemBackground
                    anchors.top: buttonContent.top
                    anchors.left: buttonContent.left
                    anchors.bottom: buttonContent.bottom
                }
            }
            transitions: Transition {
                AnchorAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: Appearance.animation.elementMove.duration
                    easing.type: Appearance.animation.elementMove.type
                    easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                }
            }

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }

        Item {
            id: itemIconBackground
            implicitWidth: root.baseSize
            implicitHeight: root.baseHighlightHeight
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            MaterialSymbol {
                id: navRailButtonIcon
                rotation: root.buttonIconRotation
                anchors.centerIn: parent
                iconSize: 24
                fill: toggled ? 1 : 0
                font.weight: (toggled || root.hovered) ? Font.DemiBold : Font.Normal
                text: buttonIcon
                color: toggled
                    ? (root.showToggledHighlight ? Appearance.m3colors.m3onSecondaryContainer : Appearance.m3colors.m3primary)
                    : Appearance.colors.colOnLayer1

                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }
            }
        }

        StyledText {
            id: itemText
            // Only show text when expanded - when collapsed, use PopupToolTip instead
            visible: root.expanded
            opacity: root.expanded ? 1 : 0
            anchors {
                left: itemIconBackground.right
                verticalCenter: itemIconBackground.verticalCenter
            }
            text: buttonText
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                }
            }
        }
    }

}
