import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

MouseArea {
    id: root
    required property var fileModelData
    property bool isDirectory: fileModelData.fileIsDir
    property bool useThumbnail: Images.isValidImageByName(fileModelData.fileName)
    property bool isSelected: false
    property bool isHovered: false

    property color colBackground: isHovered ? Appearance.colors.colPrimary 
        : isSelected ? Appearance.colors.colSecondaryContainer 
        : ColorUtils.transparentize(Appearance.colors.colPrimaryContainer)
    property color colText: isHovered ? Appearance.colors.colOnPrimary 
        : isSelected ? Appearance.colors.colOnSecondaryContainer 
        : Appearance.colors.colOnLayer1

    signal activated()

    hoverEnabled: true
    onClicked: root.activated()

    Rectangle {
        id: background
        anchors.fill: parent
        anchors.margins: 3
        radius: Appearance.rounding.small
        color: root.colBackground
        border.width: root.isSelected ? 2 : 0
        border.color: Appearance.colors.colPrimary
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
        Behavior on border.width {
            NumberAnimation { duration: 150 }
        }

        Item {
            id: imageContainer
            anchors.fill: parent
            anchors.margins: 4

            // Shadow for thumbnail
            Loader {
                active: thumbnailLoader.active && thumbnailLoader.item && thumbnailLoader.item.status === Image.Ready
                anchors.fill: thumbnailLoader
                sourceComponent: StyledRectangularShadow {
                    target: thumbnailLoader
                    anchors.fill: undefined
                    radius: Appearance.rounding.small
                }
            }

            // Thumbnail image
            Loader {
                id: thumbnailLoader
                anchors.fill: parent
                active: root.useThumbnail
                sourceComponent: ThumbnailImage {
                    id: thumbnailImage
                    generateThumbnail: false
                    sourcePath: fileModelData.filePath
                    cache: true
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    clip: true
                    sourceSize.width: 256  // Use standard thumbnail size
                    sourceSize.height: 256

                    Connections {
                        target: Wallpapers
                        function onThumbnailGenerated(directory) {
                            if (FileUtils.parentDirectory(thumbnailImage.sourcePath) !== directory) return;
                            thumbnailImage.source = "";
                            thumbnailImage.source = thumbnailImage.thumbnailPath;
                        }
                        function onThumbnailGeneratedFile(filePath) {
                            if (Qt.resolvedUrl(thumbnailImage.sourcePath) !== Qt.resolvedUrl(filePath)) return;
                            thumbnailImage.source = "";
                            thumbnailImage.source = thumbnailImage.thumbnailPath;
                        }
                    }

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: imageContainer.width
                            height: imageContainer.height
                            radius: Appearance.rounding.small
                        }
                    }
                }
            }

            // Directory icon
            Loader {
                id: iconLoader
                active: !root.useThumbnail
                anchors.fill: parent
                sourceComponent: DirectoryIcon {
                    fileModelData: root.fileModelData
                    sourceSize.width: imageContainer.width
                    sourceSize.height: imageContainer.height
                }
            }

            // Selection indicator
            MaterialSymbol {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 2
                visible: root.isSelected && !root.isDirectory
                text: "check_circle"
                iconSize: 18
                color: Appearance.colors.colPrimary
                fill: 1
                scale: root.isSelected ? 1 : 0
                Behavior on scale {
                    NumberAnimation { duration: 200; easing.type: Easing.OutBack }
                }
            }
        }
    }
}
