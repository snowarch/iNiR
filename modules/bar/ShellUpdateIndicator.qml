import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Compact iNiR shell update indicator for the bar.
 * Shows when a new version is available in the git repo.
 * Hover to see update details popup.
 */
MouseArea {
    id: root

    visible: ShellUpdates.showUpdate
    implicitWidth: visible ? updateRow.implicitWidth + 12 : 0
    implicitHeight: Appearance.sizes.barHeight

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: (mouse) => {
        if (mouse.button === Qt.RightButton) {
            ShellUpdates.dismiss()
        } else {
            ShellUpdates.performUpdate()
        }
    }

    Rectangle {
        id: bg
        anchors.centerIn: parent
        width: updateRow.implicitWidth + 10
        height: parent.height - 8
        radius: Appearance.rounding.small
        color: root.containsMouse
            ? Appearance.colors.colPrimaryContainer
            : Appearance.m3colors.m3primaryContainer
        opacity: root.containsMouse ? 1.0 : 0.7

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    RowLayout {
        id: updateRow
        anchors.centerIn: parent
        spacing: 4

        MaterialSymbol {
            text: "system_update_alt"
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.m3colors.m3onPrimaryContainer
        }

        StyledText {
            text: ShellUpdates.commitsBehind > 0
                ? ShellUpdates.commitsBehind.toString()
                : "!"
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: Appearance.m3colors.m3onPrimaryContainer
        }
    }

    // Hover popup with update details
    StyledPopup {
        id: updatePopup
        hoverTarget: root

        ColumnLayout {
            spacing: 6

            // Header
            RowLayout {
                spacing: 8

                MaterialSymbol {
                    text: "system_update_alt"
                    iconSize: 20
                    color: Appearance.m3colors.m3primary
                }

                StyledText {
                    text: Translation.tr("iNiR Update Available")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }

            // Version info
            ColumnLayout {
                spacing: 2

                RowLayout {
                    StyledText {
                        text: Translation.tr("Current:")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                    }
                    Item { Layout.fillWidth: true }
                    StyledText {
                        text: ShellUpdates.localCommit || "—"
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.monospace
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }

                RowLayout {
                    StyledText {
                        text: Translation.tr("Available:")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                    }
                    Item { Layout.fillWidth: true }
                    StyledText {
                        text: ShellUpdates.remoteCommit || "—"
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.monospace
                        font.weight: Font.DemiBold
                        color: Appearance.m3colors.m3primary
                    }
                }

                RowLayout {
                    StyledText {
                        text: Translation.tr("Commits behind:")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                    }
                    Item { Layout.fillWidth: true }
                    StyledText {
                        text: ShellUpdates.commitsBehind.toString()
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: Font.Bold
                        color: ShellUpdates.commitsBehind > 10
                            ? Appearance.m3colors.m3error
                            : Appearance.m3colors.m3primary
                    }
                }
            }

            // Latest commit message
            StyledText {
                Layout.fillWidth: true
                Layout.maximumWidth: 240
                visible: ShellUpdates.latestMessage.length > 0
                text: ShellUpdates.latestMessage
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.family: Appearance.font.family.monospace
                color: Appearance.colors.colSubtext
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.WordWrap
            }

            // Error message
            StyledText {
                Layout.fillWidth: true
                Layout.maximumWidth: 240
                visible: ShellUpdates.lastError.length > 0
                text: ShellUpdates.lastError
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.m3colors.m3error
                wrapMode: Text.WordWrap
            }

            // Hint
            StyledText {
                Layout.fillWidth: true
                Layout.maximumWidth: 240
                text: Translation.tr("Click to update • Right-click to dismiss")
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colSubtext
                opacity: 0.6
            }
        }
    }
}
