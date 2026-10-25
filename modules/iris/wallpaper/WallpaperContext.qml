pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// Where the list stands, as one strip that scrolls sideways: in the library the folder's trail and its subfolders with
// their covers; in favourites the kinds; on the web what to discover and the series airing now.
Flickable {
    id: root

    required property var engine
    property bool trail: true
    readonly property real d: IrisStyle.density
    // Nothing to show takes no room: favourites of one kind have no strip.
    readonly property bool filled: root.engine.source === "library" ? (root.trail && root.engine.crumbs.length > 0) || root.engine.libraryFolders.length > 0
        : root.engine.source === "favorites" ? root.engine.kindsPresent.length > 0
        : root.engine.online && (root.engine.discoveries.length > 0 || root.engine.airing.length > 0)
    readonly property real rowHeight: Math.round((root.engine.source === "library" && root.engine.libraryFolders.length > 0 ? 40 : 30) * root.d)

    implicitHeight: root.rowHeight
    contentWidth: strip.implicitWidth
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.HorizontalFlick
    clip: true
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const delta = event.pixelDelta.x || event.pixelDelta.y || (event.angleDelta.y || event.angleDelta.x) / 2
            root.contentX = Math.max(0, Math.min(Math.max(0, root.contentWidth - root.width), root.contentX - delta))
        }
    }

    Row {
        id: strip
        height: root.height
        spacing: Math.round(6 * root.d)

        // Library: the trail (Home › Pictures › Wallpapers), then the folders inside.
        Repeater {
            model: root.trail && root.engine.source === "library" ? root.engine.crumbs : []
            Row {
                id: crumb
                required property var modelData
                required property int index
                readonly property bool last: crumb.index === root.engine.crumbs.length - 1
                height: strip.height
                spacing: Math.round(2 * root.d)
                MaterialSymbol {
                    visible: crumb.index > 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: "chevron_right"
                    iconSize: Math.round(15 * root.d)
                    color: IrisStyle.muted
                }
                IrisChip {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: crumb.modelData.home ? "home" : crumb.last && root.engine.atWallpapersHome ? "wallpaper" : ""
                    label: crumb.modelData.label
                    labelCap: Math.round((crumb.last ? 200 : 120) * root.d)
                    selected: crumb.last
                    quiet: !crumb.last
                    onClicked: root.engine.openFolder(crumb.modelData.path)
                }
            }
        }
        Rectangle {
            visible: root.trail && root.engine.source === "library" && root.engine.libraryFolders.length > 0
            anchors.verticalCenter: strip.verticalCenter
            width: 1
            height: Math.round(20 * root.d)
            color: IrisStyle.hairline
        }
        Repeater {
            model: root.engine.source === "library" ? root.engine.libraryFolders : []
            MouseArea {
                id: folder
                required property var modelData
                readonly property var info: root.engine.folderInfo[folder.modelData.path] ?? null
                readonly property string cover: String(folder.info?.cover ?? "")
                readonly property real inset: Math.round(5 * root.d)
                anchors.verticalCenter: strip.verticalCenter
                width: folderRow.implicitWidth + folder.inset + Math.round(14 * root.d)
                height: root.rowHeight
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.Button
                Accessible.name: folder.modelData.name
                onClicked: root.engine.openFolder(folder.modelData.path)
                Rectangle {
                    anchors.fill: parent
                    radius: IrisStyle.capsule(height)
                    color: folder.pressed ? IrisStyle.fillActive : folder.containsMouse ? IrisStyle.fillHover : IrisStyle.fillQuiet
                    scale: folder.pressed ? IrisStyle.pressScale(0.97) : 1
                    Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                    Behavior on scale { NumberAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                }
                Row {
                    id: folderRow
                    anchors.left: parent.left
                    anchors.leftMargin: folder.inset
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(8 * root.d)
                    ClippingRectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: folder.height - 2 * folder.inset
                        height: width
                        radius: IrisStyle.capsule(width)
                        color: IrisStyle.fill
                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: folder.cover.length === 0
                            text: "folder"
                            fill: 1
                            iconSize: Math.round(16 * root.d)
                            color: IrisStyle.accent
                        }
                        Loader {
                            anchors.fill: parent
                            active: folder.cover.length > 0
                            sourceComponent: ThumbnailImage {
                                generateThumbnail: true
                                cleanVideoStill: true
                                sourcePath: folder.cover
                                thumbnailSizeName: "normal"
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: Math.round(width * 2)
                                sourceSize.height: Math.round(height * 2)
                                mipmap: true
                            }
                        }
                    }
                    IrisText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: folder.modelData.name
                        width: Math.min(implicitWidth, Math.round(180 * root.d))
                        elide: Text.ElideRight
                        font.pixelSize: IrisStyle.typeLabel
                        font.weight: IrisStyle.weight(Font.Medium)
                    }
                    IrisText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: (folder.info?.count ?? 0) > 0
                        text: String(folder.info?.count ?? "")
                        color: IrisStyle.subtext
                        font.family: IrisStyle.fontNumbers
                        font.features: ({ "tnum": 1 })
                        font.pixelSize: IrisStyle.typeMeta
                        font.weight: IrisStyle.weight(Font.Bold)
                    }
                }
            }
        }

        // The web: what to discover, then the series airing now.
        Repeater {
            model: root.engine.online ? root.engine.discoveries : []
            IrisChip {
                id: tagChip
                required property var modelData
                required property int index
                anchors.verticalCenter: strip.verticalCenter
                label: tagChip.modelData.label
                selected: root.engine.discovery === tagChip.index && root.engine.series === null
                    && root.engine.query.length === 0 && root.engine.pivotLabel.length === 0 && root.engine.colour.length === 0
                quiet: !tagChip.selected
                onClicked: root.engine.pickDiscovery(tagChip.index)
            }
        }
        Rectangle {
            visible: root.engine.online && root.engine.airing.length > 0
            anchors.verticalCenter: strip.verticalCenter
            width: 1
            height: Math.round(20 * root.d)
            color: IrisStyle.hairline
        }
        IrisText {
            visible: root.engine.online && root.engine.airing.length > 0
            anchors.verticalCenter: strip.verticalCenter
            text: Translation.tr("Airing now")
            color: IrisStyle.subtext
            font.pixelSize: IrisStyle.typeMeta
            font.weight: IrisStyle.weight(Font.DemiBold)
        }
        Repeater {
            model: root.engine.online ? root.engine.airing : []
            IrisChip {
                id: seriesChip
                required property var modelData
                anchors.verticalCenter: strip.verticalCenter
                artwork: String(seriesChip.modelData.imageSmall ?? "")
                label: root.engine.seriesLabel(seriesChip.modelData)
                labelCap: Math.round(170 * root.d)
                selected: root.engine.series?.id === seriesChip.modelData.id
                quiet: !seriesChip.selected
                Accessible.name: String(seriesChip.modelData.title ?? "")
                onClicked: root.engine.pickSeries(seriesChip.modelData)
            }
        }

        // Favourites: one chip per kind they hold.
        Repeater {
            model: root.engine.source === "favorites" ? root.engine.kindsPresent : []
            IrisChip {
                id: kindChip
                required property var modelData
                anchors.verticalCenter: strip.verticalCenter
                glyph: kindChip.modelData.glyph
                label: kindChip.modelData.label
                selected: root.engine.kind === kindChip.modelData.id
                quiet: !kindChip.selected
                onClicked: root.engine.kind = kindChip.modelData.id
            }
        }
    }
}
