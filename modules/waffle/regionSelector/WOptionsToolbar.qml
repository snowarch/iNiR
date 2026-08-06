pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions
import qs.modules.regionSelector
import qs.modules.waffle.looks
import qs.services

// Windows 11 style options toolbar for region selector — unified snip controls.
WPane {
    id: root

    property var action
    property var selectionMode
    signal dismiss()
    signal fullscreenRequested()
    signal colorPickerRequested()

    radius: Looks.radius.large

    // Check selection mode by comparing numeric values
    readonly property bool isRectMode: {
        const mode = root.selectionMode
        const rectMode = RegionSelection.SelectionMode.RectCorners
        return mode === rectMode || mode === 0
    }

    // Persist only explicit toolbar choices; Record never becomes the
    // remembered default (parity with the ii OptionsToolbar).
    function persistSnipChoice() {
        if (!(Config.options?.regionSelector?.rememberSnipChoice ?? true)) return;
        const isRecord = root.action === RegionSelection.SnipAction.Record
            || root.action === RegionSelection.SnipAction.RecordWithSound;
        const updates = { "regionSelector.lastMode": root.selectionMode };
        if (!isRecord) updates["regionSelector.lastAction"] = root.action;
        Config.setNestedValues(updates);
    }

    // Region actions selectable in-overlay
    readonly property var actionList: [
        { "action": RegionSelection.SnipAction.Copy,            "icon": "screenshot",   "name": Translation.tr("Screenshot") },
        { "action": RegionSelection.SnipAction.Edit,            "icon": "cut",          "name": Translation.tr("Edit") },
        { "action": RegionSelection.SnipAction.CharRecognition, "icon": "text-font",    "name": Translation.tr("Recognize text") },
        { "action": RegionSelection.SnipAction.Search,          "icon": "globe-search", "name": Translation.tr("Visual search") },
        { "action": RegionSelection.SnipAction.Record,          "icon": "record",       "name": Translation.tr("Record") }
    ]

    contentItem: Item {
        implicitWidth: rowLayout.implicitWidth + 12
        implicitHeight: rowLayout.implicitHeight + 8

        RowLayout {
            id: rowLayout
            anchors.centerIn: parent
            spacing: 4

            // Action selector
            Repeater {
                model: root.actionList
                delegate: WBorderlessButton {
                    id: actionButton
                    required property var modelData
                    readonly property bool selected: root.action === modelData.action
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32

                    colBackground: selected ? Looks.colors.accent : "transparent"
                    colBackgroundHover: selected ? Looks.colors.accentHover : Looks.colors.bg1Hover
                    colBackgroundActive: selected ? Looks.colors.accentActive : Looks.colors.bg1Active

                    onClicked: {
                        root.action = modelData.action
                        root.persistSnipChoice()
                    }

                    FluentIcon {
                        anchors.centerIn: parent
                        implicitSize: 16
                        monochrome: true
                        color: actionButton.selected ? Looks.colors.accentFg : Looks.colors.fg
                        icon: actionButton.modelData.icon
                    }

                    WToolTip {
                        text: actionButton.modelData.name
                        visible: parent.hovered
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

                onClicked: {
                    root.selectionMode = RegionSelection.SelectionMode.RectCorners
                    root.persistSnipChoice()
                }

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

                onClicked: {
                    root.selectionMode = RegionSelection.SelectionMode.Circle
                    root.persistSnipChoice()
                }

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

            // Instant: fullscreen capture
            WBorderlessButton {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                onClicked: root.fullscreenRequested()

                FluentIcon {
                    anchors.centerIn: parent
                    implicitSize: 16
                    monochrome: true
                    color: Looks.colors.fg
                    icon: "desktop"
                }

                WToolTip {
                    text: Translation.tr("Capture fullscreen")
                    visible: parent.hovered
                }
            }

            // Instant: color picker
            WBorderlessButton {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                onClicked: root.colorPickerRequested()

                FluentIcon {
                    anchors.centerIn: parent
                    implicitSize: 16
                    monochrome: true
                    color: Looks.colors.fg
                    icon: "eyedropper"
                }

                WToolTip {
                    text: Translation.tr("Color picker")
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
