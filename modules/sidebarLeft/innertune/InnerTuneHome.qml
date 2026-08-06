import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.services.deferred
import qs.modules.sidebarLeft.innertune

// Translation of HomeScreen.kt — a vertical scroll of shelves. Each shelf is a
// NavigationTitle followed by a horizontally-scrolling row of cards, sourced from
// InnerTube.homeShelves (no cookies). Quick-picks song-grid needs account data and
// arrives in a later phase; the shelf rows are the dominant Home visual.
StyledFlickable {
    id: root
    contentHeight: column.implicitHeight
    clip: true

    // Two-column quick-picks once the sidebar is widened (Ctrl+O); single column + peek otherwise.
    readonly property bool wide: width >= 620

    signal playRequested(var item)
    signal albumRequested(string browseId)
    signal playlistRequested(string playlistId)
    signal artistRequested(string browseId)

    function _open(item) {
        switch (item.type) {
            case "song": root.playRequested(item); break;
            case "album": root.albumRequested(item.browseId); break;
            case "artist": root.artistRequested(item.browseId); break;
            default: root.playlistRequested(item.playlistId || item.browseId);
        }
    }

    ColumnLayout {
        id: column
        width: root.width
        spacing: 0

        // Breathing room under the search bar / filter chips.
        Item { Layout.fillWidth: true; Layout.preferredHeight: 8 }

        // Loading / empty placeholder.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: ITDimens.homePlaceholderHeight
            visible: InnerTube.homeLoading || (InnerTube.homeShelves.length === 0)
            MaterialLoadingIndicator {
                anchors.centerIn: parent
                visible: InnerTube.homeLoading
            }
            ColumnLayout {
                id: homePlaceholder
                anchors.centerIn: parent
                spacing: 8
                visible: !InnerTube.homeLoading && InnerTube.homeShelves.length === 0
                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: InnerTube.available ? "refresh" : "extension_off"
                    iconSize: 40
                    color: Appearance.colors.colOnSurfaceVariant
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: InnerTube.available ? Translation.tr("Tap to load home") : Translation.tr("Install python-ytmusicapi")
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }
            // Tap-to-retry covers the placeholder (kept out of the layout to avoid anchor conflicts).
            MouseArea {
                anchors.fill: parent
                visible: homePlaceholder.visible
                enabled: InnerTube.available
                cursorShape: Qt.PointingHandCursor
                onClicked: InnerTube.loadHome()
            }
        }

        Repeater {
            model: InnerTube.homeShelves
            delegate: ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                Layout.bottomMargin: ITDimens.shelfSpacing
                spacing: 0

                ITNavigationTitle {
                    Layout.fillWidth: true
                    title: modelData.title ?? ""
                }

                // Song shelves render as InnerTune's 4-row horizontal song grid (Quick picks);
                // playlist/album/artist shelves render as a horizontal card row.
                readonly property bool songShelf: (modelData.items ?? []).length > 0
                    && (modelData.items[0].type === "song")

                // --- Quick-picks-style 4-row song grid ---
                StyledFlickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: ITDimens.listItemHeight * 4
                    visible: songShelf
                    contentWidth: songGrid.implicitWidth
                    contentHeight: height
                    flickableDirection: Flickable.HorizontalFlick
                    clip: true
                    Grid {
                        id: songGrid
                        rows: 4
                        flow: Grid.TopToBottom
                        leftPadding: ITDimens.shelfEdgePadding
                        rightPadding: ITDimens.shelfEdgePadding
                        Repeater {
                            model: songShelf ? (modelData.items ?? []) : []
                            delegate: ITSongListItem {
                                required property var modelData
                                // Wide: two clean columns fill the row. Narrow: ~1 card + a peek.
                                width: root.wide
                                    ? Math.floor((root.width - ITDimens.shelfEdgePadding * 2) / 2)
                                    : Math.min(ITDimens.quickPicksColumnMax, Math.round(root.width * 0.82))
                                height: ITDimens.listItemHeight
                                song: modelData
                                isActive: modelData.videoId === YtMusic.currentVideoId
                                isPlaying: isActive && YtMusic.isPlaying
                                onClicked: root.playRequested(modelData)
                            }
                        }
                    }
                }

                // --- Card row (playlists/albums/artists) ---
                StyledFlickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: ITDimens.gridThumbnailHeight + 24 + 56
                    visible: !songShelf
                    contentWidth: shelfRow.implicitWidth
                    contentHeight: height
                    flickableDirection: Flickable.HorizontalFlick
                    clip: true

                    Row {
                        id: shelfRow
                        height: parent.height
                        leftPadding: ITDimens.shelfEdgePadding
                        rightPadding: ITDimens.shelfEdgePadding
                        Repeater {
                            model: songShelf ? [] : (modelData.items ?? [])
                            delegate: ITGridItem {
                                required property var modelData
                                title: modelData.title ?? ""
                                subtitle: modelData.subtitle ?? modelData.artist ?? ""
                                thumbnailUrl: modelData.thumbnail ?? ""
                                circle: modelData.type === "artist"
                                isActive: modelData.videoId !== undefined && modelData.videoId === YtMusic.currentVideoId
                                isPlaying: isActive && YtMusic.isPlaying
                                onClicked: root._open(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
