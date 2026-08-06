pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.services.deferred
import qs.modules.sidebarLeft.innertune

// Top-level InnerTune surface for the ii sidebar — modeled on the InnerTune Android app:
// a search app-bar, a Home/Search body, a bottom NavigationBar (Home/Songs/Artists/
// Albums/Playlists), the MiniPlayer above it, and a full Player that expands over all.
// Browse data comes from InnerTube (no cookies); playback flows through YtMusic.
Item {
    id: root
    property alias inputField: searchField   // sidebar focus contract

    property string route: "home"
    readonly property bool searchMode: searchField.text.trim().length > 0
    property bool playerExpanded: false
    property string detail: ""        // "" | "album" | "artist" | "account"
    property string searchFilter: "songs"   // songs | albums | artists | playlists
    function _runSearch() {
        if (searchField.text.trim().length > 0) YtMusic.search(searchField.text.trim(), root.searchFilter);
    }

    onVisibleChanged: if (visible) _ensureHome()
    Component.onCompleted: if (visible) _ensureHome()
    // Load home whenever we're open and have nothing yet — don't latch on a failed/empty load, so
    // reopening (or a recovered session) retries instead of getting stuck on the placeholder.
    function _ensureHome() {
        if (!InnerTube.available || InnerTube.homeLoading || InnerTube.homeShelves.length > 0) return;
        InnerTube.loadHome();
    }
    function _ensureRoute() {
        if (root.route === "home") {
            root._ensureHome();
            return;
        }
        if (InnerTube.authenticated)
            InnerTube.loadLibrary(root.route);
    }
    // Hold the sidebar open + yield keyboard while the device-flow login is in progress,
    // so the external browser can receive the code and a stray click doesn't abort login.
    Connections {
        target: InnerTube
        function onLoggingInChanged() { GlobalStates.sidebarLeftHoldOpen = InnerTube.loggingIn; }
    }
    Component.onDestruction: GlobalStates.sidebarLeftHoldOpen = false

    Connections {
        target: InnerTube
        function onAvailableChanged() { if (InnerTube.available && root.visible) root._ensureRoute(); }
        function onAuthenticatedChanged() { if (root.visible) root._ensureRoute(); }
        // Playlists (from Home cards) play directly; albums/artists open a detail screen.
        function onPlaylistPageChanged() {
            const t = InnerTube.playlistPage?.tracks;
            if (t && t.length > 0) YtMusic.playFromPlaylist(t, 0, "playlist");
        }
    }
    function openAlbum(browseId) { InnerTube.loadAlbum(browseId); root.detail = "album"; }
    function openArtist(browseId) { InnerTube.loadArtist(browseId); root.detail = "artist"; }

    // ===== Main column: search bar · body · mini-player · nav bar =====
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // InnerTune-style Material 3 SearchBar (pill): leading search glyph, embedded
        // input with a faded placeholder, trailing clear button (typing) / account avatar.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: ITDimens.appBarHeight
            Layout.leftMargin: 8
            Layout.rightMargin: 8

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 6
                anchors.bottomMargin: 6
                radius: Appearance.rounding.full
                color: Appearance.colors.colSurfaceContainerHigh

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 4
                    spacing: 8

                    MaterialSymbol {
                        text: "search"
                        iconSize: Appearance.font.pixelSize.huge
                        color: Appearance.colors.colOnSurfaceVariant
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        StyledTextInput {
                            id: searchField
                            anchors.fill: parent
                            verticalAlignment: TextInput.AlignVCenter
                            color: Appearance.colors.colOnSurface
                            font.pixelSize: Appearance.font.pixelSize.normal
                            clip: true
                            onAccepted: root._runSearch()
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            visible: searchField.text.length === 0
                            text: Translation.tr("Search songs, albums, artists")
                            color: Appearance.colors.colOnSurfaceVariant
                            font.pixelSize: Appearance.font.pixelSize.normal
                            elide: Text.ElideRight
                        }
                    }

                    ITIconButton {
                        Layout.alignment: Qt.AlignVCenter
                        visible: root.searchMode
                        symbol: "close"
                        color: Appearance.colors.colOnSurfaceVariant
                        onClicked: searchField.text = ""
                    }
                    ITIconButton {
                        Layout.alignment: Qt.AlignVCenter
                        visible: !root.searchMode
                        symbol: "account_circle"
                        color: InnerTube.authenticated ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                        onClicked: root.detail = (root.detail === "account" ? "" : "account")
                    }
                }
            }
        }

        // Search-filter chips (OnlineSearchResult.kt filter row) — visible while searching.
        Flow {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.topMargin: root.searchMode ? 2 : 0
            Layout.bottomMargin: root.searchMode ? 6 : 0
            spacing: 8
            visible: root.searchMode
            Repeater {
                model: [
                    { id: "songs", label: Translation.tr("Songs") },
                    { id: "albums", label: Translation.tr("Albums") },
                    { id: "artists", label: Translation.tr("Artists") },
                    { id: "playlists", label: Translation.tr("Playlists") },
                ]
                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    readonly property bool active: root.searchFilter === modelData.id
                    implicitHeight: 32
                    implicitWidth: chipLabel.implicitWidth + 28
                    radius: Appearance.rounding.full
                    color: chip.active ? Appearance.colors.colSecondaryContainer : "transparent"
                    border.width: chip.active ? 0 : 1
                    border.color: Appearance.colors.colOutline
                    Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveFast.duration) } }
                    StyledText {
                        id: chipLabel
                        anchors.centerIn: parent
                        text: chip.modelData.label
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: chip.active ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurfaceVariant
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.searchFilter = chip.modelData.id; root._runSearch(); }
                    }
                }
            }
        }

        // Body.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            InnerTuneHome {
                anchors.fill: parent
                opacity: (!root.searchMode && root.route === "home" && root.detail === "") ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveFast.duration) } }
                onPlayRequested: (item) => YtMusic.play(Object.assign({}, item, { enableRelatedQueue: true }))
                onAlbumRequested: (browseId) => root.openAlbum(browseId)
                onPlaylistRequested: (playlistId) => InnerTube.loadPlaylist(playlistId)
                onArtistRequested: (browseId) => root.openArtist(browseId)
            }

            // Opaque backing behind detail screens. The account/login screen uses the active
            // global-style ground surface (Appearance.colors.colLayer0) so it matches the rest
            // of the shell instead of the raw Material palette; browse screens keep m3 fidelity.
            Rectangle {
                anchors.fill: parent
                visible: root.detail !== ""
                color: root.detail === "account" ? Appearance.colors.colLayer0 : Appearance.colors.colLayer0Base
            }

            // Album detail.
            ITAlbumScreen {
                anchors.fill: parent
                visible: root.detail === "album"
                album: InnerTube.albumPage
                onBackRequested: root.detail = ""
                onPlayRequested: (index, shuffle) => {
                    const t = InnerTube.albumPage?.tracks ?? [];
                    if (shuffle) YtMusic.shuffleMode = true;
                    if (t.length > 0) YtMusic.playFromPlaylist(t, index, "album");
                }
            }

            // Artist detail.
            ITArtistScreen {
                anchors.fill: parent
                visible: root.detail === "artist"
                artist: InnerTube.artistPage
                onBackRequested: root.detail = ""
                onPlaySong: (index) => {
                    const s = InnerTube.artistPage?.songs ?? [];
                    if (s.length > 0) YtMusic.playFromPlaylist(s, index, "artist");
                }
                onShuffleRequested: {
                    const s = InnerTube.artistPage?.songs ?? [];
                    if (s.length > 0) { YtMusic.shuffleMode = true; YtMusic.playFromPlaylist(s, 0, "artist"); }
                }
                onRadioRequested: {
                    const s = InnerTube.artistPage?.songs ?? [];
                    if (s.length > 0) YtMusic.play(Object.assign({}, s[0], { enableRelatedQueue: true }));
                }
                onAlbumRequested: (browseId) => root.openAlbum(browseId)
            }

            // Account / login.
            ITAccountScreen {
                anchors.fill: parent
                visible: root.detail === "account"
                onBackRequested: root.detail = ""
            }

            ITLibraryScreen {
                anchors.fill: parent
                route: root.route
                items: InnerTube.libraryPages[root.route] ?? []
                loading: InnerTube.libraryLoading
                authenticated: InnerTube.authenticated
                visible: !root.searchMode && root.route !== "home" && root.detail === ""
                onLoginRequested: root.detail = "account"
                onPlayRequested: (index) => YtMusic.playFromPlaylist(InnerTube.libraryPages[root.route] ?? [], index, "library:" + root.route)
                onAlbumRequested: (browseId) => root.openAlbum(browseId)
                onArtistRequested: (browseId) => root.openArtist(browseId)
                onPlaylistRequested: (playlistId) => InnerTube.loadPlaylist(playlistId)
            }

            InnerTuneSearch {
                anchors.fill: parent
                results: YtMusic.searchResults
                opacity: (root.searchMode && root.detail === "") ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveFast.duration) } }
                onPlayRequested: (index) => YtMusic.playFromSearch(index)
                onAlbumRequested: (browseId) => root.openAlbum(browseId)
                onArtistRequested: (browseId) => root.openArtist(browseId)
                onPlaylistRequested: (playlistId) => InnerTube.loadPlaylist(playlistId)
            }

        }

        // Mini player (above nav bar).
        ITMiniPlayer {
            Layout.fillWidth: true
            visible: YtMusic.currentVideoId !== "" && !root.playerExpanded
            onExpandRequested: root.playerExpanded = true
        }

        // Bottom navigation bar.
        ITNavigationBar {
            Layout.fillWidth: true
            currentRoute: root.route
            onSelected: (r) => { root.route = r; root.detail = ""; searchField.text = ""; root._ensureRoute(); }
        }
    }

    // ===== Full player overlay (slides up over everything) =====
    ITPlayer {
        id: player
        width: parent.width
        height: parent.height
        y: dragging ? dragY : (root.playerExpanded ? 0 : parent.height)
        visible: y < parent.height
        onCollapseRequested: root.playerExpanded = false
        onGoToAlbumRequested: (browseId) => { if (browseId) { root.playerExpanded = false; root.openAlbum(browseId); } }
        Behavior on y {
            enabled: Appearance.animationsEnabled && !player.dragging
            NumberAnimation {
                duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveEnter.duration)
                easing.type: Appearance.animation.elementMoveEnter.type
                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
            }
        }
    }
}
