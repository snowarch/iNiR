pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// What the web says about a wallpaper, each piece a way on: its colours and tags search for more like it, the uploader
// for their uploads, Similar for Wallhaven's own neighbours; then its page and where it was first posted. A file of
// the library offers its folder.
ColumnLayout {
    id: root

    required property var engine
    property var entry: root.engine.selected
    // In a side column every piece gets its own head; in a band they run as rows.
    property bool column: false
    readonly property real d: IrisStyle.density
    readonly property var details: root.entry?.provider === "wallhaven" ? (Wallhaven.wallpaperDetails[root.entry?.id] ?? null) : null
    readonly property var tags: root.details ? root.details.tags.map(tag => tag.name)
        : Array.from(root.entry?.tags ?? []).filter(tag => !/^(tagme|highres|absurdres|wallpaper)$/.test(tag))
    readonly property string uploader: root.details?.uploader ?? String(root.entry?.author ?? "")
    readonly property string origin: String(root.details?.origin || root.entry?.origin || "")
    readonly property bool web: root.entry?.web === true || String(root.entry?.page ?? "").length > 0

    spacing: Math.round((root.column ? 16 : 10) * root.d)

    component Head: IrisText {
        visible: root.column
        color: IrisStyle.subtext
        font.pixelSize: IrisStyle.typeMeta
        font.weight: IrisStyle.weight(Font.DemiBold)
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: (root.entry?.colors ?? []).length > 0
        spacing: Math.round(8 * root.d)
        Head { text: Translation.tr("Colours") }
        Row {
            spacing: Math.round(6 * root.d)
            Repeater {
                model: root.entry?.colors ?? []
                MouseArea {
                    id: colourKey
                    required property string modelData
                    width: Math.round(26 * root.d)
                    height: width
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.Button
                    Accessible.name: Translation.tr("More in %1").arg(colourKey.modelData)
                    onClicked: root.engine.setColour(colourKey.modelData)
                    Rectangle {
                        anchors.centerIn: parent
                        width: colourKey.containsMouse ? parent.width : Math.round(22 * root.d)
                        height: width
                        radius: IrisStyle.capsule(width)
                        color: colourKey.modelData
                        border.width: 1
                        border.color: IrisStyle.hairlineStrong
                        Behavior on width { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                    }
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.tags.length > 0
        spacing: Math.round(8 * root.d)
        Head { text: Translation.tr("Tags") }
        Flow {
            Layout.fillWidth: true
            spacing: Math.round(6 * root.d)
            Repeater {
                model: root.tags.slice(0, root.column ? 24 : 12)
                IrisChip {
                    id: tagChip
                    required property string modelData
                    label: "#" + tagChip.modelData.replace(/_/g, " ")
                    labelCap: Math.round(160 * root.d)
                    quiet: true
                    implicitHeight: Math.round(28 * root.d)
                    enabled: root.engine.online
                    onClicked: root.engine.searchTag(tagChip.modelData)
                }
            }
        }
    }
    IrisText {
        visible: root.entry?.provider === "wallhaven" && root.details === null && root.entry?.web === true
        text: Translation.tr("Reading its page…")
        color: IrisStyle.muted
        font.pixelSize: IrisStyle.typeMeta
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.uploader.length > 0
        spacing: Math.round(8 * root.d)
        Head { text: Translation.tr("Uploaded by") }
        IrisChip {
            glyph: "person"
            label: root.uploader
            quiet: true
            implicitHeight: Math.round(28 * root.d)
            enabled: root.entry?.provider === "wallhaven"
            onClicked: root.engine.searchUploader(root.uploader)
        }
    }

    Flow {
        Layout.fillWidth: true
        spacing: Math.round(6 * root.d)
        IrisChip {
            visible: root.entry?.provider === "wallhaven" && root.entry?.web === true
            glyph: "auto_awesome"
            label: Translation.tr("Similar")
            onClicked: root.engine.similar(root.entry)
        }
        IrisChip {
            visible: root.web && String(root.entry?.page ?? "").length > 0
            glyph: "open_in_new"
            label: Translation.tr("Open %1").arg(root.engine.providerName(root.entry?.provider ?? ""))
            quiet: true
            onClicked: root.engine.openPage(root.entry)
        }
        IrisChip {
            visible: root.origin.length > 0 && root.origin !== String(root.entry?.page ?? "")
            glyph: "link"
            label: Translation.tr("Original post")
            quiet: true
            onClicked: Qt.openUrlExternally(root.origin)
        }
        IrisChip {
            visible: !root.web && String(root.entry?.path ?? "").length > 0
            glyph: "folder_open"
            label: Translation.tr("Show in folder")
            quiet: true
            onClicked: root.engine.openPage(root.entry)
        }
    }
}
