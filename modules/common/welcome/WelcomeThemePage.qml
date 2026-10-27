import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Flickable {
    readonly property var root: WelcomeHost.wizard
    id: themeFlickable
    width: root.stepWidth
    contentHeight: themeColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height
    bottomMargin: 24
    topMargin: Math.max(root.compact ? 6 : 10,
        Math.min(root.compact ? 18 : 24,
            Math.round((height - themeColumn.implicitHeight - bottomMargin) / 2)))

    GridLayout {
        id: themeColumn
        width: parent.width
        columns: themeFlickable.width < 760 ? 1 : 2
        columnSpacing: root.compact ? 20 : 28
        rowSpacing: 16

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: themeFlickable.width < 760
                ? themeFlickable.width : (themeFlickable.width - (root.compact ? 20 : 28)) * 0.34
            Layout.alignment: Qt.AlignTop
            spacing: 5

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                MaterialSymbol { text: "auto_awesome"; iconSize: 18; color: root.welcomeAccent }
                WelcomeText {
                    text: Translation.tr("Style")
                    font.family: root.welcomeFontTitle
                    font.pixelSize: root.welcomeFontSection
                    font.weight: Font.Bold
                    color: root.welcomeOnSurface
                }
            }

            WelcomeText {
                Layout.fillWidth: true
                Layout.bottomMargin: 3
                text: Translation.tr("Choose the look for the whole shell.")
                font.pixelSize: root.welcomeFontCaption
                color: root.welcomeSecondaryText
                wrapMode: Text.WordWrap
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 4
                rowSpacing: 2

                Repeater {
                    model: root.stylePresets
                    WelcomeChoiceRow {
                        required property var modelData
                        compactRow: true
                        title: modelData.name
                        symbol: modelData.icon
                        selected: root.effectiveStylePreset === modelData.id
                        onClicked: root.applyStylePreset(modelData.id)
                    }
                }
            }
        }

        PanelSurface {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: themeFlickable.width < 760
                ? themeFlickable.width : (themeFlickable.width - (root.compact ? 20 : 28)) * 0.66
            Layout.alignment: Qt.AlignTop
            implicitHeight: appearanceColumn.implicitHeight + 28
            surfaceDialect: "material"
            elevation: 2
            outlined: false
            radiusOverride: 16

            ColumnLayout {
                id: appearanceColumn
                anchors.fill: parent
                anchors.margins: 14
                spacing: root.compact ? 9 : 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    MaterialCookie {
                        implicitSize: 38
                        sides: 8
                        color: root.welcomeAccentContainer
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: root.currentStylePreset.icon
                            iconSize: 19
                            color: root.welcomeAccent
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        WelcomeText {
                            text: root.effectiveStylePreset === "custom"
                                ? Translation.tr("Custom style") : root.currentStylePreset.name
                            font.family: root.welcomeFontTitle
                            font.pixelSize: Appearance.font.pixelSize.larger
                            font.weight: Font.Bold
                            color: root.welcomeOnSurface
                        }
                        WelcomeText {
                            Layout.fillWidth: true
                            text: root.currentStylePresetDescription
                            font.pixelSize: root.welcomeFontCaption
                            font.weight: Font.Medium
                            color: root.welcomeSecondaryText
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                    Rectangle {
                        visible: root.effectiveStylePreset === "material"
                        implicitWidth: recommendedStyleLabel.implicitWidth + 14
                        implicitHeight: 22
                        radius: 11
                        color: ColorUtils.mix(root.welcomeSurfaceHighest, root.welcomeAccentAlt, 0.62)

                        WelcomeText {
                            id: recommendedStyleLabel
                            anchors.centerIn: parent
                            text: Translation.tr("Recommended")
                            font.pixelSize: root.welcomeFontMeta
                            font.weight: Font.Bold
                            color: ColorUtils.ensureReadable(root.welcomeOnSurface, parent.color, 4.5)
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    LightDarkPreferenceButton { dark: false }
                    LightDarkPreferenceButton { dark: true }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: ColorUtils.applyAlpha(root.welcomeOutline, 0.34)
                }

                ColumnLayout {
                    id: wallpaperGroup
                    Layout.fillWidth: true
                    spacing: 7

                    property var wallpapersList: []
                    readonly property string wallpapersPath: Directories.wallpapersPath
                    readonly property real itemWidth: root.compact ? 156 : 180
                    readonly property real itemHeight: root.compact ? 88 : 100

                    Component.onCompleted: wallpaperScanProc.running = true

                    Process {
                        id: wallpaperScanProc
                        command: ["/bin/sh", "-c", `find '${wallpaperGroup.wallpapersPath}' -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.avif' \\) -printf '%C@\\t%p\\n' 2>/dev/null`]
                        stdout: SplitParser {
                            splitMarker: ""
                            onRead: data => {
                                const lines = data.trim().split("\n").filter(l => l.length > 0)
                                lines.sort((a, b) => parseFloat(b.split("\t")[0]) - parseFloat(a.split("\t")[0]))
                                wallpaperGroup.wallpapersList = lines.map(l => l.split("\t")[1]).filter(p => p && p.length > 0)
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 7
                        MaterialSymbol { text: "wallpaper"; iconSize: 17; color: root.welcomeAccent }
                        WelcomeText {
                            text: Translation.tr("Wallpaper")
                            font.family: root.welcomeFontTitle
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Bold
                            color: root.welcomeOnSurface
                        }
                        Item { Layout.fillWidth: true }
                        WelcomeText {
                            text: Translation.tr("Colors update automatically")
                            color: root.welcomeSecondaryText
                            font.pixelSize: root.welcomeFontMeta
                        }
                    }

            ListView {
                id: wallpaperCarousel
                Layout.fillWidth: true
                Layout.preferredHeight: wallpaperGroup.itemHeight
                visible: wallpaperGroup.wallpapersList.length > 0
                orientation: ListView.Horizontal
                spacing: 7
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: wallpaperGroup.wallpapersList

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                        wallpaperCarousel.contentX = Math.max(0, Math.min(
                            wallpaperCarousel.contentWidth - wallpaperCarousel.width,
                            wallpaperCarousel.contentX - delta
                        ))
                    }
                }

                delegate: Item {
                    id: wpDelegate
                    required property int index
                    required property string modelData
                    readonly property string filePath: modelData
                    readonly property bool isCurrentWallpaper: (Config.options?.background?.wallpaperPath ?? "") === filePath
                    readonly property bool isHovered: wpMouseArea.containsMouse

                    width: wallpaperGroup.itemWidth
                    height: wallpaperGroup.itemHeight

                    PanelSurface {
                        id: wpThumb
                        anchors.fill: parent
                        surfaceDialect: "material"
                                elevation: 1
                        cardStyle: true
                        outlined: wpDelegate.isCurrentWallpaper
                        borderWidthOverride: wpDelegate.isCurrentWallpaper ? 2 : 0
                                radiusOverride: 12
                        clipContent: true

                        Image {
                            anchors.fill: parent
                            anchors.margins: wpDelegate.isCurrentWallpaper ? 3 : 0
                            source: wpDelegate.filePath ? `file://${wpDelegate.filePath}` : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            sourceSize.width: Math.round(wallpaperGroup.itemWidth * 2.25)
                            sourceSize.height: Math.round(wallpaperGroup.itemHeight * 2.25)
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: wpDelegate.isHovered && !wpDelegate.isCurrentWallpaper ? "#36000000" : "transparent"
                        }

                                Rectangle {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                                    anchors.margins: 6
                            visible: wpDelegate.isCurrentWallpaper
                                    width: 24
                                    height: 24
                                    radius: 12
                                    color: root.welcomeAccent
                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "check"
                                        iconSize: 14
                                        color: root.welcomeOnAccent
                                    }
                        }

                        MouseArea {
                            id: wpMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Wallpapers.select(wpDelegate.filePath)
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: wallpaperGroup.itemHeight
                visible: wallpaperGroup.wallpapersList.length === 0
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialSymbol { Layout.alignment: Qt.AlignHCenter; text: "image"; iconSize: 20; color: root.welcomeOnSurfaceVariant }
                    WelcomeText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("No wallpapers found in ~/Pictures/Wallpapers").replace("~/Pictures/Wallpapers", Directories.shortHomePath(Directories.wallpapersPath))
                        color: root.welcomeSecondaryText
                        font.pixelSize: root.welcomeFontMeta
                    }
                }
            }
        }
            }
        }
    }
}
