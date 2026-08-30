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
    PopupToolTip {
        id: hoverBubble
        delay: 0
        extraVisibleCondition: !root.expanded
        anchorEdges: Edges.Right
        contentItem: Item {
            id: bubbleContent
            property bool shown: false
            implicitWidth: bubbleBackground.implicitWidth
            implicitHeight: bubbleBackground.implicitHeight
            opacity: shown ? 1 : 0
            scale: shown ? 1 : 0.92

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

            Rectangle {
                id: bubbleBackground
                color: Appearance.regaliaEverywhere ? "transparent"
                    : Appearance.zzzEverywhere ? Appearance.zzz.accent : Appearance.colors.colPrimary
                radius: Appearance.regaliaEverywhere ? Appearance.regalia.controlRadius
                    : Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.rounding.full
                border.width: 0
                border.color: "transparent"
                // Organic morph on style/shape switch (organic-transitions)
                Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
                Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                implicitWidth: bubbleText.implicitWidth + 24
                implicitHeight: root.baseHighlightHeight

                RegaliaControlFace {
                    anchors.fill: parent
                    visible: Appearance.regaliaEverywhere
                    fillColor: Appearance.regalia.primaryPlate
                    radius: bubbleBackground.radius
                    selected: true
                }

                StyledText {
                    id: bubbleText
                    anchors.centerIn: parent
                    text: root.buttonText
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.regaliaEverywhere ? Appearance.regalia.primaryPlateInk
                        : Appearance.zzzEverywhere ? Appearance.zzz.onSticker : Appearance.colors.colOnPrimary
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
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
            radius: Appearance.regaliaEverywhere ? Appearance.regalia.roundSmall
                : Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
                : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
            // Organic morph on style/shape switch (organic-transitions)
            Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
            // Regalia turns navigation into compact semantic tiles. Other styles
            // keep the shell-wide bgless doctrine.
            color: "transparent"

            RegaliaControlFace {
                anchors.fill: parent
                visible: Appearance.regaliaEverywhere
                fillColor: root.toggled ? Appearance.regalia.primaryPlate : Appearance.regalia.controlPlate
                radius: itemBackground.radius
                hovered: root.hovered
                pressed: root.down
                selected: root.toggled
                focused: root.visualFocus
            }

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
                enabled: Appearance.animationsEnabled
                animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
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
                animateFill: true
                font.weight: (toggled || root.hovered) ? Font.DemiBold : Font.Normal
                text: buttonIcon
                // Bgless: active icon carries the accent itself (no plate behind).
                color: Appearance.regaliaEverywhere
                    ? (toggled ? Appearance.regalia.hardwarePrimary
                        : root.hovered ? Appearance.regalia.hardwarePrimary
                        : Appearance.regalia.onMuted)
                    : Appearance.zzzEverywhere
                    ? (toggled ? Appearance.zzz.accent : (root.hovered ? Appearance.zzz.ink : Appearance.zzz.inkMuted))
                    : Appearance.angelEverywhere
                    ? (toggled ? Appearance.angel.colPrimary : (root.hovered ? Appearance.angel.colText : Appearance.angel.colTextSecondary))
                    : Appearance.inirEverywhere
                    ? (toggled ? Appearance.inir.colPrimary : (root.hovered ? Appearance.inir.colText : Appearance.inir.colTextSecondary))
                    : (toggled ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1)

                // Bgless press feedback: the glyph dips on press so a click reads
                // as registered without any plate behind it.
                scale: root.down && !Appearance.regaliaEverywhere ? 0.82 : 1
                Behavior on scale {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.clickBounce.duration; easing.type: Appearance.animation.clickBounce.type; easing.bezierCurve: Appearance.animation.clickBounce.bezierCurve }
                }

                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
            }
        }

        StyledText {
            id: itemText
            // Only show text when expanded - when collapsed, use PopupToolTip instead
            visible: opacity > 0
            opacity: root.expanded ? 1 : 0
            width: root.expanded ? implicitWidth : 0
            clip: true
            anchors {
                left: itemIconBackground.right
                verticalCenter: itemIconBackground.verticalCenter
            }
            text: buttonText
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.regaliaEverywhere
                ? (root.toggled ? Appearance.regalia.primaryPlateInk : Appearance.regalia.onMuted)
                : Appearance.zzzEverywhere ? Appearance.zzz.ink : Appearance.colors.colOnLayer1
            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                }
            }
            Behavior on width {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementResize.duration
                    easing.type: Appearance.animation.elementResize.type
                    easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                }
            }
        }
    }

}
