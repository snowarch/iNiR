pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    signal dismissed()
    signal editRequested()

    readonly property bool isHovered: backgroundMa.containsMouse

    Timer {
        id: dismissTimer
        interval: 8000
        repeat: false
        running: !isHovered
        onTriggered: root.dismissed()
    }

    onIsHoveredChanged: {
        if (isHovered) dismissTimer.stop()
        else dismissTimer.restart()
    }

    property alias contentBackground: contentBackground

    property real popupWidth: 300
    property real horizontalPadding: 20
    property real verticalPadding: 20

    implicitWidth: popupWidth + 2 * Appearance.sizes.elevationMargin
    implicitHeight: contentLayout.implicitHeight + verticalPadding * 2 + 2 * Appearance.sizes.elevationMargin

    NumberAnimation on opacity { from: 0; to: 1; duration: 350; easing.type: Easing.OutCubic }
    NumberAnimation on scale { from: 0.85; to: 1; duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.2 }

    transformOrigin: Item.TopRight

    StyledRectangularShadow { target: contentBackground }

    Rectangle {
        id: contentBackground
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }
        radius: Appearance.rounding.large
        color: Config.options.appearance.transparency.popups ? Appearance.colors.colLayer0 : Appearance.m3colors.m3surfaceContainer
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        ColumnLayout {
            id: contentLayout
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: root.horizontalPadding
                topMargin: root.verticalPadding
                bottomMargin: root.verticalPadding
            }
            spacing: 16

            RowLayout {
                spacing: 12
                MaterialSymbol {
                    text: "movie_edit"
                    iconSize: 32
                    color: Appearance.colors.colPrimary
                }
                ColumnLayout {
                    spacing: 2
                    StyledText {
                        text: Translation.tr("Recording Finished")
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnSurface
                    }
                    StyledText {
                        text: Translation.tr("Do you want to edit it?")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: Appearance.rounding.full
                color: editMa.containsMouse ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colPrimaryContainer
                
                scale: editMa.pressed ? 0.95 : (editMa.containsMouse ? 1.02 : 1.0)
                Behavior on scale { NumberAnimation { duration: 150 } }
                Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    MaterialSymbol {
                        text: "edit"
                        iconSize: 20
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                    StyledText {
                        text: Translation.tr("Edit Video")
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                }

                MouseArea {
                    id: editMa
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.editRequested()
                }
            }
        }
    }

    MouseArea {
        id: backgroundMa
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        onClicked: root.dismissed()
    }
}
