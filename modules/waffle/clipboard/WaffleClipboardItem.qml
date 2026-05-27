pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.waffle.looks

WBorderlessButton {
    id: root

    required property string entry
    property bool isSelected: false
    property bool isCopied: false
    property string searchQuery: ""

    signal deleteRequested()

    implicitHeight: contentLayout.implicitHeight + 16

    checked: isSelected

    property bool isImage: Cliphist.entryIsImage(entry)
    property string displayText: {
        let cleaned = StringUtils.cleanCliphistEntry(entry)
        if (isImage) {
            cleaned = cleaned.replace(/^\s*\[\[.*?\]\]\s*/, "")
        }
        return cleaned.trim()
    }

    property string entryType: {
        const raw = entry
        return `#${raw.match(/^[\s]*(\S+)/)?.[1] || ""}`
    }

    contentItem: RowLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12

        // Copied indicator
        Rectangle {
            visible: root.isCopied
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            radius: 10
            color: Looks.colors.accent

            FluentIcon {
                anchors.centerIn: parent
                icon: "chevron-right"
                implicitSize: 12
                color: Looks.colors.accentFg
            }
        }

        // Content column
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            // Type label
            WText {
                visible: root.entryType && root.entryType !== "#"
                text: root.entryType
                color: Looks.colors.subfg
                font.pixelSize: Looks.font.pixelSize.small
            }

            // Main text
            WText {
                Layout.fillWidth: true
                text: root.displayText
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
                font.pixelSize: Looks.font.pixelSize.normal
            }

            // Image preview - don't use Layout.fillWidth, let image determine its own size
            Loader {
                active: root.isImage
                sourceComponent: CliphistImage {
                    entry: root.entry
                    maxWidth: contentLayout.width - 24
                    maxHeight: 80
                    blur: false
                }
            }
        }

        // Action text on hover
        WText {
            visible: root.hovered && !deleteButton.hovered
            text: Translation.tr("Copy")
            color: Looks.colors.accent
            font.pixelSize: Looks.font.pixelSize.normal
        }

        // Delete button
        WBorderlessButton {
            id: deleteButton
            visible: root.hovered || root.isSelected
            implicitWidth: 28
            implicitHeight: 28
            radius: Looks.radius.medium

            onClicked: root.deleteRequested()

            contentItem: FluentIcon {
                anchors.centerIn: parent
                icon: "dismiss"
                implicitSize: 16
                color: deleteButton.hovered ? Looks.colors.danger : Looks.colors.fg
            }

            WToolTip {
                text: Translation.tr("Delete")
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: root.deleteRequested()
    }
}
