pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.iris.components
import qs.modules.iris.style

Flickable {
    id: root

    readonly property real d: IrisStyle.density
    readonly property string version: versionFile.text().trim()
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    contentHeight: pageColumn.implicitHeight + 40 * root.d
    ScrollBar.vertical: IrisScrollBar {}

    FileView {
        id: versionFile
        path: Quickshell.shellPath("VERSION")
    }

    ColumnLayout {
        id: pageColumn
        width: Math.min(root.width - 32 * root.d, 640 * root.d)
        x: Math.round((root.width - width) / 2)
        y: Math.round(18 * root.d)
        spacing: 18 * root.d

        ColumnLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: Number.POSITIVE_INFINITY
            Layout.bottomMargin: 6 * root.d
            spacing: 6 * root.d
            IrisMark {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 8 * root.d
                implicitSize: Math.round(76 * root.d)
            }
            IrisText {
                Layout.alignment: Qt.AlignHCenter
                text: "iNiR"
                font.family: IrisStyle.fontTitle
                font.pixelSize: 26 * IrisStyle.typeScale
                font.weight: IrisStyle.weight(Font.Bold)
            }
            IrisText {
                Layout.alignment: Qt.AlignHCenter
                text: root.version.length > 0 ? Translation.tr("Version %1").arg(root.version) : Translation.tr("A shell for Niri")
                color: IrisStyle.muted
                font.pixelSize: IrisStyle.typeLabel
            }
        }

        InfoCard {
            rows: [
                { label: Translation.tr("Family"), value: Translation.tr("iRiS · Island family") },
                { label: Translation.tr("Branch"), value: ShellUpdates.localCommit.length > 0 ? ShellUpdates.currentBranch : "", highlight: ShellUpdates.isNonMainBranch },
                { label: Translation.tr("Commit"), value: ShellUpdates.localCommit },
                { label: Translation.tr("System"), value: SystemInfo.distroName },
                { label: Translation.tr("Compositor"), value: CompositorService.isNiri ? "Niri" : SystemInfo.desktopEnvironment },
                { label: Translation.tr("Computer"), value: SystemInfo.hostname }
            ].filter(row => String(row.value ?? "").length > 0 && row.value !== "Unknown")
        }

        Heading { text: Translation.tr("iNiR") }
        IrisLinkCard {
            tinted: true
            links: [
                { label: Translation.tr("Documentation"), icon: "menu_book", tint: IrisStyle.identity.sky, action: () => Qt.openUrlExternally("https://github.com/snowarch/inir/wiki") },
                { label: Translation.tr("Report an issue"), icon: "bug_report", tint: IrisStyle.identity.red, action: () => Qt.openUrlExternally("https://github.com/snowarch/inir/issues") },
                { label: Translation.tr("Source code"), value: "github.com/snowarch/inir", icon: "code", tint: IrisStyle.identity.lavender, action: () => Qt.openUrlExternally("https://github.com/snowarch/inir") }
            ]
        }

        Heading {
            visible: distroLinks.links.length > 0
            text: SystemInfo.distroName
        }
        IrisLinkCard {
            id: distroLinks
            visible: links.length > 0
            tinted: true
            links: [
                SystemInfo.homeUrl ? { label: Translation.tr("Website"), icon: "language", tint: IrisStyle.identity.blue, action: () => Qt.openUrlExternally(SystemInfo.homeUrl) } : null,
                SystemInfo.documentationUrl ? { label: Translation.tr("Documentation"), icon: "auto_stories", tint: IrisStyle.identity.teal, action: () => Qt.openUrlExternally(SystemInfo.documentationUrl) } : null,
                SystemInfo.supportUrl ? { label: Translation.tr("Help & Support"), icon: "support", tint: IrisStyle.identity.green, action: () => Qt.openUrlExternally(SystemInfo.supportUrl) } : null,
                SystemInfo.bugReportUrl ? { label: Translation.tr("Report a Bug"), icon: "bug_report", tint: IrisStyle.identity.orange, action: () => Qt.openUrlExternally(SystemInfo.bugReportUrl) } : null
            ].filter(link => link !== null)
        }
    }

    component Heading: IrisText {
        Layout.leftMargin: 16 * root.d
        Layout.bottomMargin: -10 * root.d
        color: IrisStyle.muted
        font.family: IrisStyle.fontTitle
        font.pixelSize: IrisStyle.typeMeta
        font.weight: IrisStyle.weight(Font.DemiBold)
    }

    component InfoCard: Rectangle {
        id: card
        property var rows: []
        Layout.fillWidth: true
        implicitHeight: infoColumn.implicitHeight
        radius: IrisStyle.radiusTile
        color: IrisStyle.readingCard
        Column {
            id: infoColumn
            width: parent.width
            Repeater {
                model: card.rows
                Item {
                    id: infoRow
                    required property var modelData
                    required property int index
                    width: parent.width
                    height: Math.round(40 * root.d)
                    IrisText {
                        id: infoLabel
                        anchors.left: parent.left
                        anchors.leftMargin: 16 * root.d
                        anchors.verticalCenter: parent.verticalCenter
                        text: infoRow.modelData.label
                        font.pixelSize: IrisStyle.typeLabel
                    }
                    IrisText {
                        anchors.left: infoLabel.right
                        anchors.leftMargin: 16 * root.d
                        anchors.right: parent.right
                        anchors.rightMargin: 16 * root.d
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        text: infoRow.modelData.value
                        color: infoRow.modelData.highlight ? IrisStyle.secondaryAccent : IrisStyle.muted
                        font.pixelSize: IrisStyle.typeLabel
                        elide: Text.ElideMiddle
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 16 * root.d
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        visible: infoRow.index < card.rows.length - 1
                        color: IrisStyle.hairline
                    }
                }
            }
        }
    }
}
