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
    property bool isPin: false
    property string pinnedText: ""
    // A history entry can itself already be pinned. Without this it showed the
    // "pin" icon like any other row and pinning it again was the only thing the
    // button could do.
    readonly property string pinnedAs: root.isPin ? root.pinnedText : Cliphist.pinnedTextFor(root.entry)
    readonly property bool isPinned: root.pinnedAs.length > 0
    property bool isSelected: false
    property bool isCopied: false
    property string searchQuery: ""

    signal deleteRequested()
    signal pinToggleRequested()

    implicitHeight: contentLayout.implicitHeight + 16

    checked: isSelected

    property bool isImage: !isPin && Cliphist.entryIsImage(entry)
    property string displayText: {
        if (root.isPin) return Cliphist.pinPreview(root.pinnedText)
        let cleaned = StringUtils.cleanCliphistEntry(entry)
        if (isImage) {
            cleaned = cleaned.replace(/^\s*\[\[.*?\]\]\s*/, "")
        }
        const unwrapped = StringUtils.cliphistMarkupPreview(cleaned)
        if (unwrapped !== cleaned)
            cleaned = unwrapped.length > 0 ? unwrapped : Translation.tr("Rich text")
        return cleaned.trim()
    }

    property string entryType: {
        if (root.isPin) return Translation.tr("Pinned")
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
            visible: root.hovered && !deleteButton.hovered && !pinButton.hovered
            text: Translation.tr("Copy")
            color: Looks.colors.accent
            font.pixelSize: Looks.font.pixelSize.normal
        }

        // Pin button
        WBorderlessButton {
            id: pinButton
            visible: (root.hovered || root.isSelected) && (root.isPinned || Cliphist.isPinnable(root.entry))
            implicitWidth: 28
            implicitHeight: 28
            radius: Looks.radius.medium

            onClicked: root.pinToggleRequested()

            contentItem: FluentIcon {
                anchors.centerIn: parent
                icon: root.isPinned ? "pin-off" : "pin"
                implicitSize: 16
                color: pinButton.hovered ? Looks.colors.accent : Looks.colors.fg
            }

            WToolTip {
                text: root.isPinned ? Translation.tr("Unpin") : Translation.tr("Pin")
            }
        }

        // Delete button
        WBorderlessButton {
            id: deleteButton
            visible: root.hovered || root.isSelected
            implicitWidth: 28
            implicitHeight: 28
            radius: Looks.radius.medium

            onClicked: root.isPin ? root.pinToggleRequested() : root.deleteRequested()

            contentItem: FluentIcon {
                anchors.centerIn: parent
                icon: "dismiss"
                implicitSize: 16
                color: deleteButton.hovered ? Looks.colors.danger : Looks.colors.fg
            }

            WToolTip {
                text: root.isPin ? Translation.tr("Unpin") : Translation.tr("Delete")
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: root.isPin ? root.pinToggleRequested() : root.deleteRequested()
    }
}
