pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions
import qs.modules.regionSelector
import qs.modules.waffle.looks
import qs.services

// Windows 11 style options toolbar for region selector
WPane {
    id: root

    property var action
    property var selectionMode
    signal dismiss()

    radius: Looks.radius.large
    
    // Check selection mode by comparing numeric values
    readonly property bool isRectMode: {
        const mode = root.selectionMode
        const rectMode = RegionSelection.SelectionMode.RectCorners
        return mode === rectMode || mode === 0
    }

    contentItem: Item {
        implicitWidth: rowLayout.implicitWidth + 12
        implicitHeight: rowLayout.implicitHeight + 8
        
        RowLayout {
            id: rowLayout
            anchors.centerIn: parent
            spacing: 4

            // Action indicator
            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignVCenter
                radius: Looks.radius.medium
                color: Looks.colors.accent

                FluentIcon {
                    anchors.centerIn: parent
                    implicitSize: 16
                    monochrome: true
                    color: Looks.colors.accentFg
                    icon: {
                        switch (root.action) {
                            case RegionSelection.SnipAction.Copy:
                            case RegionSelection.SnipAction.Edit:
                                return "screenshot";
                            case RegionSelection.SnipAction.Search:
                                return "globe-search";
                            case RegionSelection.SnipAction.CharRecognition:
                                return "cut";
                            case RegionSelection.SnipAction.Record:
                            case RegionSelection.SnipAction.RecordWithSound:
                                return "record";
                            default:
                                return "screenshot";
                        }
                    }
                }
            }

            // Separator
            WPanelSeparator {
                Layout.preferredHeight: 20
                Layout.alignment: Qt.AlignVCenter
            }

            // Selection mode: Rectangle
            WBorderlessButton {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                
                colBackground: root.isRectMode ? Looks.colors.accent : "transparent"
                colBackgroundHover: root.isRectMode ? Looks.colors.accentHover : Looks.colors.bg1Hover
                colBackgroundActive: root.isRectMode ? Looks.colors.accentActive : Looks.colors.bg1Active
                
                onClicked: root.selectionMode = RegionSelection.SelectionMode.RectCorners

                FluentIcon {
                    anchors.centerIn: parent
                    implicitSize: 16
                    monochrome: true
                    color: root.isRectMode ? Looks.colors.accentFg : Looks.colors.fg
                    icon: "screenshot"
                }

                WToolTip {
                    text: Translation.tr("Rectangle")
                    visible: parent.hovered
                }
            }

            // Selection mode: Freeform
            WBorderlessButton {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                
                colBackground: !root.isRectMode ? Looks.colors.accent : "transparent"
                colBackgroundHover: !root.isRectMode ? Looks.colors.accentHover : Looks.colors.bg1Hover
                colBackgroundActive: !root.isRectMode ? Looks.colors.accentActive : Looks.colors.bg1Active
                
                onClicked: root.selectionMode = RegionSelection.SelectionMode.Circle

                FluentIcon {
                    anchors.centerIn: parent
                    implicitSize: 16
                    monochrome: true
                    color: !root.isRectMode ? Looks.colors.accentFg : Looks.colors.fg
                    icon: "wand"
                }

                WToolTip {
                    text: Translation.tr("Freeform")
                    visible: parent.hovered
                }
            }

            // Separator
            WPanelSeparator {
                Layout.preferredHeight: 20
                Layout.alignment: Qt.AlignVCenter
            }

            // Close button
            WBorderlessButton {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                onClicked: root.dismiss()

                FluentIcon {
                    anchors.centerIn: parent
                    implicitSize: 16
                    monochrome: true
                    color: Looks.colors.fg
                    icon: "dismiss"
                }

                WToolTip {
                    text: Translation.tr("Close")
                    visible: parent.hovered
                }
            }
        }
    }
}
