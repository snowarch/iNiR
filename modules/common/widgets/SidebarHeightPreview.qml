pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

ColumnLayout {
    id: root

    Layout.fillWidth: true
    spacing: 8

    readonly property bool leftFit: Config.options?.sidebar?.collapseWidgetsTab ?? false
    readonly property bool rightFit: Config.options?.sidebar?.collapseEmptyNotifications ?? false
    readonly property real leftRatio: leftFit ? SidebarGeometry.leftFitPreferredRatio : 1
    readonly property real rightRatio: rightFit ? SidebarGeometry.rightFitExpandedPreferredRatio : 1

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 150
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer2
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant

        Item {
            id: monitorPreview
            anchors.centerIn: parent
            width: Math.min(parent.width - 32, 360)
            height: 108

            Rectangle {
                id: screenFrame
                anchors.fill: parent
                radius: Appearance.rounding.verysmall
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: Appearance.colors.colOutlineVariant

                Rectangle {
                    id: leftPreview
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 7
                    width: 42
                    height: Math.max(22, (parent.height - 14) * root.leftRatio)
                    radius: Appearance.rounding.verysmall
                    color: Appearance.colors.colPrimaryContainer
                    border.width: 1
                    border.color: Appearance.colors.colPrimary

                    Behavior on height {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.elementResize.duration
                            easing.type: Appearance.animation.elementResize.type
                            easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                        }
                    }
                }

                Rectangle {
                    id: rightPreview
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 7
                    width: 42
                    height: Math.max(22, (parent.height - 14) * root.rightRatio)
                    radius: Appearance.rounding.verysmall
                    color: Appearance.colors.colSecondaryContainer
                    border.width: 1
                    border.color: Appearance.colors.colSecondary

                    Behavior on height {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.elementResize.duration
                            easing.type: Appearance.animation.elementResize.type
                            easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: Math.max(1, parent.height
                            * SidebarGeometry.rightFitCollapsedPreferredRatio
                            / SidebarGeometry.rightFitExpandedPreferredRatio)
                        radius: parent.radius
                        color: "transparent"
                        border.width: root.rightFit ? 1 : 0
                        border.color: Appearance.colors.colOutlineVariant
                        opacity: root.rightFit ? 0.65 : 0
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Left sidebar") + " · "
                + (root.leftFit
                    ? Translation.tr("Fit") + " " + Math.round(SidebarGeometry.leftFitPreferredRatio * 100) + "%"
                    : Translation.tr("Full"))
            color: Appearance.colors.colOnLayer1
            font.pixelSize: Appearance.font.pixelSize.smaller
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: Translation.tr("Right sidebar") + " · "
                + (root.rightFit
                    ? Translation.tr("Fit") + " " + Math.round(SidebarGeometry.rightFitExpandedPreferredRatio * 100) + "% / "
                        + Translation.tr("Compact") + " " + Math.round(SidebarGeometry.rightFitCollapsedPreferredRatio * 100) + "%"
                    : Translation.tr("Full"))
            color: Appearance.colors.colOnLayer1
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
    }
}
