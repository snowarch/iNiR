import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * Compact iNiR shell update indicator for the bar.
 * Shows when a new version is available in the git repo.
 */
MouseArea {
    id: root

    visible: ShellUpdates.showUpdate
    implicitWidth: visible ? pill.width : 0
    implicitHeight: Appearance.sizes.barHeight

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    readonly property color accentColor: Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? (Appearance.inir?.colAccent ?? Appearance.m3colors.m3primary)
        : Appearance.auroraEverywhere ? (Appearance.aurora?.colAccent ?? Appearance.m3colors.m3primary)
        : Appearance.m3colors.m3primary

    onClicked: (mouse) => {
        if (mouse.button === Qt.RightButton) {
            ShellUpdates.dismiss()
        } else {
            ShellUpdates.openOverlay()
        }
    }

    // Background pill
    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: contentRow.implicitWidth + 16
        height: contentRow.implicitHeight + 8
        radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall : height / 2
        scale: root.pressed ? 0.93 : (root.containsMouse ? 1.03 : 1.0)
        color: {
            if (root.pressed) {
                if (Appearance.angelEverywhere) return Appearance.angel.colGlassCardActive
                if (Appearance.inirEverywhere) return Appearance.inir.colLayer2Active
                if (Appearance.auroraEverywhere) return Appearance.aurora.colSubSurfaceActive
                return Appearance.colors.colLayer1Active
            }
            if (root.containsMouse) {
                if (Appearance.angelEverywhere) return Appearance.angel.colGlassCardHover
                if (Appearance.inirEverywhere) return Appearance.inir.colLayer1Hover
                if (Appearance.auroraEverywhere) return Appearance.aurora.colSubSurface
                return Appearance.colors.colLayer1Hover
            }
            if (Appearance.angelEverywhere) return ColorUtils.transparentize(Appearance.angel.colPrimary, 0.85)
            if (Appearance.inirEverywhere) return ColorUtils.transparentize(Appearance.inir?.colAccent ?? Appearance.m3colors.m3primary, 0.85)
            if (Appearance.auroraEverywhere) return ColorUtils.transparentize(Appearance.aurora?.colAccent ?? Appearance.m3colors.m3primary, 0.85)
            return ColorUtils.transparentize(Appearance.m3colors.m3primary, 0.88)
        }

        border.width: (Appearance.angelEverywhere || Appearance.inirEverywhere) ? 1 : 0
        border.color: Appearance.angelEverywhere ? Appearance.angel.colBorder
            : Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
        Behavior on scale {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: pill
        spacing: 5

        MaterialSymbol {
            id: updateIcon
            text: "upgrade"
            iconSize: Appearance.font.pixelSize.normal
            color: root.accentColor
            Layout.alignment: Qt.AlignVCenter

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: root.containsMouse
                NumberAnimation { to: 0.5; duration: 800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
            }
        }

        StyledText {
            text: ShellUpdates.commitsBehind > 0
                ? ShellUpdates.commitsBehind.toString()
                : "!"
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: root.accentColor
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // Hover popup — follows BatteryPopup / ResourcesPopup pattern
    StyledPopup {
        id: updatePopup
        hoverTarget: root

        ColumnLayout {
            spacing: 6

            // Header row — icon + title
            Row {
                spacing: 5

                MaterialSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    fill: 0
                    font.weight: Font.Medium
                    text: "deployed_code_update"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnSurfaceVariant
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Translation.tr("iNiR Update")
                    font {
                        weight: Font.Medium
                        pixelSize: Appearance.font.pixelSize.normal
                    }
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }

            // Commits behind
            RowLayout {
                spacing: 5
                Layout.fillWidth: true

                MaterialSymbol {
                    text: "download"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnSurfaceVariant
                }
                StyledText {
                    text: Translation.tr("Behind:")
                    color: Appearance.colors.colOnSurfaceVariant
                }
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: ShellUpdates.commitsBehind > 0
                        ? (ShellUpdates.commitsBehind + " " + Translation.tr("commit(s)"))
                        : Translation.tr("Update available")
                    color: ShellUpdates.commitsBehind > 10
                        ? (Appearance.m3colors?.m3error ?? Appearance.colors.colOnSurfaceVariant)
                        : Appearance.colors.colOnSurfaceVariant
                    font.weight: Font.Medium
                }
            }

            // Version row
            RowLayout {
                visible: ShellUpdates.localVersion.length > 0 && ShellUpdates.remoteVersion.length > 0 && ShellUpdates.remoteVersion !== ShellUpdates.localVersion
                spacing: 5
                Layout.fillWidth: true

                MaterialSymbol {
                    text: "tag"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnSurfaceVariant
                }
                StyledText {
                    text: Translation.tr("Version:")
                    color: Appearance.colors.colOnSurfaceVariant
                }
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: "v" + ShellUpdates.localVersion + "  →  v" + ShellUpdates.remoteVersion
                    font {
                        family: Appearance.font.family.monospace
                        weight: Font.Medium
                    }
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }

            // Commit comparison row
            RowLayout {
                spacing: 5
                Layout.fillWidth: true

                MaterialSymbol {
                    text: "commit"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnSurfaceVariant
                }
                StyledText {
                    text: Translation.tr("Commit:")
                    color: Appearance.colors.colOnSurfaceVariant
                }
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: (ShellUpdates.localCommit || "\u2014") +
                        (ShellUpdates.remoteCommit.length > 0 ? ("  →  " + ShellUpdates.remoteCommit) : "")
                    font {
                        family: Appearance.font.family.monospace
                        weight: Font.Medium
                    }
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }

            // Branch row
            RowLayout {
                visible: ShellUpdates.currentBranch.length > 0
                spacing: 5
                Layout.fillWidth: true

                MaterialSymbol {
                    text: "account_tree"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnSurfaceVariant
                }
                StyledText {
                    text: Translation.tr("Branch:")
                    color: Appearance.colors.colOnSurfaceVariant
                }
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: ShellUpdates.currentBranch
                    font.family: Appearance.font.family.monospace
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }

            // Error display
            RowLayout {
                spacing: 5
                visible: ShellUpdates.lastError.length > 0
                Layout.fillWidth: true
                Layout.maximumWidth: 280

                MaterialSymbol {
                    text: "error"
                    color: Appearance.m3colors?.m3error ?? Appearance.colors.colOnSurfaceVariant
                    iconSize: Appearance.font.pixelSize.large
                }
                StyledText {
                    Layout.fillWidth: true
                    text: ShellUpdates.lastError
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.m3colors?.m3error ?? Appearance.colors.colOnSurfaceVariant
                    wrapMode: Text.WordWrap
                }
            }

            // Separator
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.topMargin: 2
                Layout.bottomMargin: 2
                color: Appearance.angelEverywhere ? Appearance.angel.colBorderSubtle
                    : Appearance.inirEverywhere ? (Appearance.inir?.colBorder ?? Appearance.colors.colLayer0Border)
                    : Appearance.colors.colLayer0Border
                opacity: 0.5
            }

            // Hint
            StyledText {
                text: Translation.tr("Click for details · Right-click to dismiss")
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colOnSurfaceVariant
                opacity: 0.6
            }
        }
    }
}
