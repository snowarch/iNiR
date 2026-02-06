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
 * Follows TimerIndicator pattern for global style support.
 */
MouseArea {
    id: root

    visible: ShellUpdates.showUpdate
    implicitWidth: visible ? pill.width : 0
    implicitHeight: Appearance.sizes.barHeight

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    readonly property color accentColor: Appearance.inirEverywhere ? (Appearance.inir?.colAccent ?? Appearance.m3colors.m3primary)
        : Appearance.auroraEverywhere ? (Appearance.aurora?.colAccent ?? Appearance.m3colors.m3primary)
        : Appearance.m3colors.m3primary

    readonly property color textColor: {
        if (Appearance.inirEverywhere) return Appearance.inir?.colText ?? Appearance.colors.colOnLayer1
        if (Appearance.auroraEverywhere) return Appearance.aurora?.colText ?? Appearance.colors.colOnLayer1
        return Appearance.colors.colOnLayer1
    }

    onClicked: (mouse) => {
        if (mouse.button === Qt.RightButton) {
            ShellUpdates.dismiss()
        } else {
            ShellUpdates.performUpdate()
        }
    }

    // Background pill (follows TimerIndicator pattern)
    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: contentRow.implicitWidth + 12
        height: contentRow.implicitHeight + 8
        radius: height / 2
        scale: root.pressed ? 0.95 : 1.0
        color: {
            if (root.pressed) {
                if (Appearance.inirEverywhere) return Appearance.inir.colLayer2Active
                if (Appearance.auroraEverywhere) return Appearance.aurora.colSubSurfaceActive
                return Appearance.colors.colLayer1Active
            }
            if (root.containsMouse) {
                if (Appearance.inirEverywhere) return Appearance.inir.colLayer1Hover
                if (Appearance.auroraEverywhere) return Appearance.aurora.colSubSurface
                return Appearance.colors.colLayer1Hover
            }
            if (Appearance.inirEverywhere) return ColorUtils.transparentize(Appearance.inir?.colAccent ?? Appearance.m3colors.m3primary, 0.85)
            if (Appearance.auroraEverywhere) return ColorUtils.transparentize(Appearance.aurora?.colAccent ?? Appearance.m3colors.m3primary, 0.85)
            return Appearance.colors.colPrimaryContainer
        }

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
        Behavior on scale {
            NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
        }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: pill
        spacing: 4

        MaterialSymbol {
            text: "system_update_alt"
            iconSize: Appearance.font.pixelSize.normal
            color: root.accentColor
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            text: ShellUpdates.commitsBehind > 0
                ? ShellUpdates.commitsBehind.toString()
                : "!"
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: root.textColor
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // Hover popup (follows BatteryPopup / ResourcesPopup pattern)
    StyledPopup {
        id: updatePopup
        hoverTarget: root

        component InfoRow: RowLayout {
            id: infoRow
            required property string icon
            required property string label
            required property string value
            property color valueColor: Appearance.colors.colOnSurfaceVariant
            spacing: 4

            MaterialSymbol {
                text: infoRow.icon
                color: Appearance.colors.colOnSurfaceVariant
                iconSize: Appearance.font.pixelSize.large
            }
            StyledText {
                text: infoRow.label
                color: Appearance.colors.colOnSurfaceVariant
            }
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                color: infoRow.valueColor
                text: infoRow.value
            }
        }

        ColumnLayout {
            spacing: 4

            // Header
            Row {
                spacing: 5

                MaterialSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    fill: 0
                    font.weight: Font.Medium
                    text: "system_update_alt"
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

            // Version info rows
            InfoRow {
                icon: "tag"
                label: Translation.tr("Current:")
                value: ShellUpdates.localCommit || "\u2014"
            }
            InfoRow {
                icon: "upgrade"
                label: Translation.tr("Available:")
                value: ShellUpdates.remoteCommit || "\u2014"
                valueColor: Appearance.m3colors.m3primary
            }
            InfoRow {
                icon: "commit"
                label: Translation.tr("Behind:")
                value: ShellUpdates.commitsBehind.toString()
                valueColor: ShellUpdates.commitsBehind > 10
                    ? Appearance.m3colors.m3error
                    : Appearance.m3colors.m3primary
            }

            // Latest commit message
            RowLayout {
                spacing: 4
                visible: ShellUpdates.latestMessage.length > 0
                Layout.maximumWidth: 260

                MaterialSymbol {
                    text: "notes"
                    color: Appearance.colors.colOnSurfaceVariant
                    iconSize: Appearance.font.pixelSize.large
                }
                StyledText {
                    Layout.fillWidth: true
                    text: ShellUpdates.latestMessage
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colOnSurfaceVariant
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    wrapMode: Text.NoWrap
                }
            }

            // Error
            RowLayout {
                spacing: 4
                visible: ShellUpdates.lastError.length > 0
                Layout.maximumWidth: 260

                MaterialSymbol {
                    text: "error"
                    color: Appearance.m3colors.m3error
                    iconSize: Appearance.font.pixelSize.large
                }
                StyledText {
                    Layout.fillWidth: true
                    text: ShellUpdates.lastError
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.m3colors.m3error
                    wrapMode: Text.WordWrap
                }
            }

            // Hint
            StyledText {
                text: Translation.tr("Click to update \u2022 Right-click to dismiss")
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colOnSurfaceVariant
                opacity: 0.6
            }
        }
    }
}
