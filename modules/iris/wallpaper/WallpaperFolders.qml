pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

ColumnLayout {
    id: root

    required property var picker
    readonly property real d: IrisStyle.density

    spacing: Math.round(8 * root.d)

    component Strip: Flickable {
        id: strip
        default property alias items: stripRow.data
        property real rowHeight: Math.round(30 * root.d)
        Layout.fillWidth: true
        implicitHeight: strip.rowHeight
        contentWidth: stripRow.implicitWidth
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const delta = event.pixelDelta.x || event.pixelDelta.y || (event.angleDelta.y || event.angleDelta.x) / 2
                strip.contentX = Math.max(0, Math.min(Math.max(0, strip.contentWidth - strip.width), strip.contentX - delta))
            }
        }
        Row {
            id: stripRow
            height: strip.rowHeight
            spacing: Math.round(6 * root.d)
        }
    }

    Strip {
        rowHeight: Math.round((root.picker.libraryFolders.length > 0 ? 44 : 30) * root.d)
        Repeater {
            model: root.picker.places
            IrisChip {
                id: place
                required property var modelData
                y: Math.round(((parent?.height ?? height) - height) / 2)
                glyph: place.modelData.glyph
                label: place.modelData.label
                selected: root.picker.folderPath === place.modelData.path
                onClicked: root.picker.openFolder(place.modelData.path)
            }
        }
        Rectangle {
            visible: root.picker.libraryFolders.length > 0 && root.picker.places.length > 0
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: Math.round(20 * root.d)
            color: IrisStyle.hairline
        }
        Repeater {
            model: root.picker.libraryFolders
            MouseArea {
                id: folder
                required property var modelData
                readonly property var info: root.picker.folderInfo[folder.modelData.path] ?? null
                readonly property string cover: String(folder.info?.cover ?? "")
                readonly property real inset: Math.round(6 * root.d)
                width: folderRow.implicitWidth + folder.inset + Math.round(14 * root.d)
                height: Math.round(44 * root.d)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.Button
                Accessible.name: folder.modelData.name
                onClicked: root.picker.openFolder(folder.modelData.path)
                Rectangle {
                    anchors.fill: parent
                    radius: IrisStyle.radiusTile
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
                    spacing: Math.round(9 * root.d)
                    ClippingRectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: folder.height - 2 * folder.inset
                        height: width
                        radius: Math.max(IrisStyle.radiusMicro, IrisStyle.radiusTile - folder.inset)
                        color: IrisStyle.fill
                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: folder.cover.length === 0
                            text: "folder"
                            fill: 1
                            iconSize: Math.round(17 * root.d)
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
                                mipmap: true
                                sourceSize.height: Math.round(height * 2)
                            }
                        }
                    }
                    IrisText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: folder.modelData.name
                        width: Math.min(implicitWidth, Math.round(200 * root.d))
                        elide: Text.ElideRight
                        font.pixelSize: IrisStyle.typeLabel
                        font.weight: IrisStyle.weight(Font.Medium)
                    }
                    IrisText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: (folder.info?.count ?? 0) > 0
                        text: String(folder.info?.count ?? "")
                        color: IrisStyle.secondaryAccent
                        font.family: IrisStyle.fontNumbers
                        font.features: ({ "tnum": 1 })
                        font.pixelSize: IrisStyle.typeMeta
                        font.weight: IrisStyle.weight(Font.Bold)
                    }
                }
            }
        }
    }
}
