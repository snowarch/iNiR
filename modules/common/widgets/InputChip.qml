pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

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
        implicitWidth: chipContent.implicitWidth + 20
        implicitHeight: 30
        radius: height / 2
        color: closeArea.containsMouse
            ? Appearance.colors.colErrorContainer
            : bodyArea.containsMouse
                ? Appearance.colors.colSecondaryContainerHover
                : Appearance.colors.colSecondaryContainer
        border.width: 1
        border.color: closeArea.containsMouse
            ? Appearance.colors.colError
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

        RowLayout {
            id: chipContent
            anchors.centerIn: parent
            spacing: 4

            // Optional leading icon
            MaterialSymbol {
                visible: root.chipIcon.length > 0
                text: root.chipIcon
                iconSize: 16
                color: closeArea.containsMouse
                    ? Appearance.colors.colOnErrorContainer
                    : Appearance.colors.colOnSecondaryContainer
            }

            StyledText {
                text: root.text
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.family: root.monospace ? Appearance.font.family.monospace : Appearance.font.family.main
                color: closeArea.containsMouse
                    ? Appearance.colors.colOnErrorContainer
                    : Appearance.colors.colOnSecondaryContainer
            }

            // Close icon
            Item {
                visible: root.removable
                implicitWidth: 16
                implicitHeight: 16

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: 14
                    color: closeArea.containsMouse
                        ? Appearance.colors.colOnErrorContainer
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
            anchors.rightMargin: root.removable ? 24 : 0
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activated()
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
