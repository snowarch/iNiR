pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * Material 3 Input Chip — a compact tag with optional icon, label, and removable close button.
 * See https://m3.material.io/components/chips/overview#input-chip
 *
 * Properties:
 *   text: string — chip label text
 *   chipIcon: string — optional material symbol shown before the label
 *   removable: bool — whether the close button is shown (default true)
 *   monospace: bool — use monospace font for the label (default false)
 *
 * Signals:
 *   activated() — emitted when the chip body is clicked
 *   removed() — emitted when the close button is clicked
 */
Item {
    id: root
    property string text
    property string chipIcon: ""
    property bool removable: true
    property bool monospace: false

    signal activated()
    signal removed()

    implicitWidth: chipBackground.implicitWidth
    implicitHeight: chipBackground.implicitHeight

    Rectangle {
        id: chipBackground
        implicitWidth: chipContent.implicitWidth
            + (Appearance.regaliaEverywhere ? Appearance.regalia.controlPaddingHorizontal * 2 : 20)
        implicitHeight: Appearance.regaliaEverywhere ? Appearance.regalia.compactControlHeight : 30
        radius: Appearance.regaliaEverywhere ? Appearance.regalia.controlRadius
            : Appearance.zzzEverywhere ? Appearance.zzz.pillRadius : height / 2
        // ZZZ: a tag is a neutral data tile with a hairline, not a bright
        // secondary block (colSecondaryContainer → zzz.secondary signal).
        color: Appearance.regaliaEverywhere ? "transparent"
            : closeArea.containsMouse ? Appearance.colors.colErrorContainer
            : Appearance.zzzEverywhere
                ? (bodyArea.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2)
                : bodyArea.containsMouse
                    ? Appearance.colors.colSecondaryContainerHover
                    : Appearance.colors.colSecondaryContainer
        border.width: Appearance.regaliaEverywhere ? 0 : 1

        RegaliaControlFace {
            anchors.fill: parent
            visible: Appearance.regaliaEverywhere
            fillColor: closeArea.containsMouse ? Appearance.regalia.signalPlate : Appearance.regalia.controlPlate
            radius: chipBackground.radius
            hovered: bodyArea.containsMouse || closeArea.containsMouse
            pressed: bodyArea.pressed || closeArea.pressed
        }
        border.color: closeArea.containsMouse
            ? Appearance.colors.colError
            : Appearance.regaliaEverywhere ? "transparent"
            : Appearance.zzzEverywhere
                ? (bodyArea.containsMouse ? Appearance.zzz.hairlineStrong : Appearance.zzz.hairline)
                : bodyArea.containsMouse
                    ? Qt.rgba(Appearance.colors.colOnSecondaryContainer.r, Appearance.colors.colOnSecondaryContainer.g, Appearance.colors.colOnSecondaryContainer.b, 0.2)
                    : "transparent"

        Behavior on color {
            enabled: Appearance.animationsEnabled
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
        Behavior on border.color {
            enabled: Appearance.animationsEnabled
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
        Behavior on radius {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
        }
        Behavior on implicitWidth {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
        }

        RowLayout {
            id: chipContent
            anchors.centerIn: parent
            spacing: (root.chipIcon.length > 0 || root.removable)
                ? (Appearance.regaliaEverywhere ? Appearance.regalia.controlGap : 4) : 0

            Behavior on spacing {
                enabled: Appearance.animationsEnabled
                animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
            }

            // Optional leading icon
            Item {
                implicitWidth: root.chipIcon.length > 0 ? leadingIcon.implicitWidth : 0
                implicitHeight: leadingIcon.implicitHeight
                opacity: root.chipIcon.length > 0 ? 1 : 0
                visible: opacity > 0
                clip: true

                Behavior on implicitWidth {
                    enabled: Appearance.animationsEnabled
                    animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
                }
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }

                MaterialSymbol {
                    id: leadingIcon
                    anchors.centerIn: parent
                    text: root.chipIcon
                    iconSize: 16
                    color: closeArea.containsMouse
                        ? Appearance.colors.colOnErrorContainer
                        : Appearance.regaliaEverywhere ? Appearance.regalia.onColor
                        : Appearance.zzzEverywhere ? Appearance.zzz.ink : Appearance.colors.colOnSecondaryContainer
                }
            }

            StyledText {
                text: root.text
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.family: root.monospace ? Appearance.font.family.monospace : Appearance.font.family.main
                color: closeArea.containsMouse
                    ? Appearance.colors.colOnErrorContainer
                    : Appearance.regaliaEverywhere ? Appearance.regalia.onColor
                    : Appearance.zzzEverywhere ? Appearance.zzz.ink : Appearance.colors.colOnSecondaryContainer
            }

            // Close icon
            Item {
                visible: opacity > 0
                opacity: root.removable ? 1 : 0
                implicitWidth: root.removable ? 16 : 0
                implicitHeight: 16
                clip: true

                Behavior on implicitWidth {
                    enabled: Appearance.animationsEnabled
                    animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
                }
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: 14
                    color: closeArea.containsMouse
                        ? Appearance.colors.colOnErrorContainer
                        : Appearance.regaliaEverywhere ? Appearance.regalia.onMuted
                        : Appearance.colors.colOnSecondaryContainer
                    opacity: closeArea.containsMouse ? 1 : (bodyArea.containsMouse ? 0.7 : 0.4)

                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                    }
                }
            }
        }

        // Body click area (everything except the close icon)
        MouseArea {
            id: bodyArea
            anchors.fill: parent
            anchors.rightMargin: root.removable
                ? (Appearance.regaliaEverywhere ? 16 + Appearance.regalia.controlGap : 24) : 0
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activated()

            Behavior on anchors.rightMargin {
                enabled: Appearance.animationsEnabled
                animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
            }
        }

        // Close button click area
        MouseArea {
            id: closeArea
            visible: root.removable
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 24
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.removed()
        }
    }
}
