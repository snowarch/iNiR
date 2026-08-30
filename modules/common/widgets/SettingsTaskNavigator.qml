pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common

ColumnLayout {
    id: root

    property string icon: "tune"
    property string title: ""
    property string description: ""
    property string summary: ""
    // The page header already shows name/description; the intro card is only
    // worth drawing on pages that need the extra onboarding copy.
    property bool showIntro: true
    property string currentValue: ""
    property var options: []

    signal selected(string value)

    Layout.fillWidth: true
    spacing: 12

    Rectangle {
        visible: root.showIntro && (root.title.length > 0 || root.description.length > 0)
        Layout.fillWidth: true
        implicitHeight: visible ? introColumn.implicitHeight + (root.title.length > 0 ? 24 : 20) : 0
        radius: Appearance.rounding.normal
        color: Appearance.colors.colPrimaryContainer

        // Full variant (icon + title + description) for pages that onboard;
        // compact variant (centered description + summary) when the page header
        // already carries the name and icon.
        ColumnLayout {
            id: introColumn
            anchors.fill: parent
            anchors.margins: root.title.length > 0 ? 12 : 10
            spacing: root.title.length > 0 ? 9 : 4

            RowLayout {
                Layout.fillWidth: true
                visible: root.title.length > 0
                spacing: 10

                MaterialCookie {
                    implicitSize: 40
                    sides: 9
                    color: Appearance.colors.colPrimary
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: root.icon
                        iconSize: 19
                        color: Appearance.colors.colOnPrimary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    StyledText {
                        Layout.fillWidth: true
                        text: root.title
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnPrimaryContainer
                        wrapMode: Text.WordWrap
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: root.description.length > 0
                        text: root.description
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.82
                        wrapMode: Text.WordWrap
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.title.length === 0 && root.description.length > 0
                text: root.description
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: Appearance.colors.colOnPrimaryContainer
                opacity: 0.92
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.summary.length > 0
                text: root.summary
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.weight: Font.Medium
                color: Appearance.colors.colOnPrimaryContainer
                opacity: 0.7
                horizontalAlignment: root.title.length > 0 ? Text.AlignLeft : Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }

    ConfigSelectionArray {
        Layout.fillWidth: true
        currentValue: root.currentValue
        options: root.options
        onSelected: value => root.selected(value)
    }
}
