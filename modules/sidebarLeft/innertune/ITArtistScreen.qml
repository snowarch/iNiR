import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.sidebarLeft.innertune

// Translation of artist/ArtistScreen.kt — large art header with the artist name, Shuffle
// + Radio buttons, then Songs (list) and Albums/Singles (horizontal card rows).
StyledFlickable {
    id: root
    property var artist: ({})        // InnerTube.artistPage shape
    readonly property var songs: artist?.songs ?? []
    readonly property var albums: artist?.albums ?? []
    readonly property var singles: artist?.singles ?? []
    contentHeight: column.implicitHeight
    clip: true

    signal backRequested()
    signal playSong(int index)
    signal shuffleRequested()
    signal radioRequested()
    signal albumRequested(string browseId)

    ColumnLayout {
        id: column
        width: root.width
        spacing: 0

        // Art header with name overlay + scrim.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(root.width * 0.62)

            StyledImage {
                id: hero
                anchors.fill: parent
                source: root.artist?.thumbnail ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            // Bottom gradient scrim for legibility.
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.4; color: "transparent" }
                    GradientStop { position: 1.0; color: Appearance.colors.colLayer0Base }
                }
            }
            ITIconButton {
                x: 8; y: 8
                symbol: "arrow_back"
                color: "white"
                onClicked: root.backRequested()
            }
            StyledText {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 16
                text: root.artist?.name ?? ""
                font.family: Appearance.font.family.expressive
                font.pixelSize: Appearance.font.pixelSize.hugeass
                font.weight: Font.Bold
                color: Appearance.colors.colOnSurface
                maximumLineCount: 2
                elide: Text.ElideRight
                wrapMode: Text.Wrap
            }
        }

        // Shuffle + Radio.
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 12
            spacing: 12
            ITButton {
                Layout.fillWidth: true
                kind: "filled"
                icon: "shuffle"
                label: Translation.tr("Shuffle")
                onClicked: root.shuffleRequested()
            }
            ITButton {
                Layout.fillWidth: true
                kind: "outlined"
                icon: "radio"
                label: Translation.tr("Radio")
                onClicked: root.radioRequested()
            }
        }

        // Songs.
        ITNavigationTitle {
            Layout.fillWidth: true
            visible: root.songs.length > 0
            title: Translation.tr("Songs")
        }
        Repeater {
            model: root.songs
            delegate: ITSongListItem {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                implicitWidth: column.width
                song: modelData
                isActive: modelData.videoId === YtMusic.currentVideoId
                isPlaying: isActive && YtMusic.isPlaying
                onClicked: root.playSong(index)
            }
        }

        // Albums + Singles (horizontal card rows).
        Repeater {
            model: [
                { title: Translation.tr("Albums"), items: root.albums },
                { title: Translation.tr("Singles"), items: root.singles }
            ]
            delegate: ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 0
                visible: modelData.items.length > 0

                ITNavigationTitle { Layout.fillWidth: true; title: modelData.title }

                StyledFlickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: ITDimens.gridThumbnailHeight + 24 + 56
                    contentWidth: cardRow.implicitWidth
                    contentHeight: height
                    flickableDirection: Flickable.HorizontalFlick
                    clip: true
                    Row {
                        id: cardRow
                        height: parent.height
                        leftPadding: 6
                        rightPadding: 6
                        Repeater {
                            model: modelData.items
                            delegate: ITGridItem {
                                required property var modelData
                                title: modelData.title ?? ""
                                subtitle: modelData.subtitle ?? ""
                                thumbnailUrl: modelData.thumbnail ?? ""
                                onClicked: root.albumRequested(modelData.browseId)
                            }
                        }
                    }
                }
            }
        }

        Item { Layout.preferredHeight: 16 }
    }
}
