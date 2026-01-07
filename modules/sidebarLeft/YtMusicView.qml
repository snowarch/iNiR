pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models
import qs.services
import qs.modules.sidebarLeft.widgets

Item {
    id: root

    readonly property bool isAvailable: YtMusic.available
    readonly property bool hasResults: YtMusic.searchResults.length > 0
    readonly property bool hasQueue: YtMusic.queue.length > 0
    readonly property bool isPlaying: YtMusic.isPlaying
    readonly property bool hasTrack: YtMusic.currentVideoId !== ""

    property string currentView: "search"

    function openAddToPlaylist(item) { 
        addToPlaylistPopup.targetItem = item
        addToPlaylistPopup.open() 
    }

    readonly property color colText: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer0
    readonly property color colTextSecondary: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
    readonly property color colPrimary: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
    readonly property color colSurface: Appearance.inirEverywhere ? Appearance.inir.colLayer1 : Appearance.auroraEverywhere ? "transparent" : Appearance.colors.colLayer1
    readonly property color colSurfaceHover: Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface : Appearance.colors.colLayer1Hover
    readonly property color colLayer2: Appearance.inirEverywhere ? Appearance.inir.colLayer2 : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface : Appearance.colors.colLayer2
    readonly property color colLayer2Hover: Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover : Appearance.colors.colLayer2Hover
    readonly property color colBorder: Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"
    readonly property int borderWidth: Appearance.inirEverywhere ? 1 : 0
    readonly property real radiusSmall: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
    readonly property real radiusNormal: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: !root.isAvailable
            visible: active
            sourceComponent: ColumnLayout {
                spacing: 16
                Item { Layout.fillHeight: true }
                MaterialSymbol { 
                    Layout.alignment: Qt.AlignHCenter
                    text: "music_off"
                    iconSize: 56
                    color: root.colTextSecondary 
                }
                StyledText { 
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("yt-dlp not found")
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.Medium
                    color: root.colText 
                }
                StyledText { 
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    Layout.margins: 20
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: Translation.tr("Install yt-dlp and mpv to use YT Music")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: root.colTextSecondary 
                }
                RippleButton {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 160
                    implicitHeight: 42
                    buttonRadius: root.radiusNormal
                    colBackground: root.colPrimary
                    onClicked: Qt.openUrlExternally("https://github.com/yt-dlp/yt-dlp#installation")
                    contentItem: StyledText { 
                        anchors.centerIn: parent
                        text: Translation.tr("Install Guide")
                        color: Appearance.colors.colOnPrimary
                        font.weight: Font.Medium 
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: root.isAvailable
            visible: active
            
            sourceComponent: ColumnLayout {
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 20
                    color: root.colLayer2
                    border.width: root.borderWidth
                    border.color: root.colBorder

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 2

                        Repeater {
                            model: [
                                { id: "search", icon: "search", label: Translation.tr("Search") },
                                { id: "playlists", icon: "library_music", label: Translation.tr("Library") },
                                { id: "queue", icon: "queue_music", label: root.hasQueue ? `${YtMusic.queue.length}` : "" },
                                { id: "account", icon: YtMusic.googleConnected ? "account_circle" : "person_off", label: "" }
                            ]

                            RippleButton {
                                required property var modelData
                                Layout.fillWidth: modelData.id === "search" || modelData.id === "playlists"
                                Layout.preferredWidth: modelData.id === "queue" || modelData.id === "account" ? 40 : -1
                                implicitHeight: 32
                                buttonRadius: 16
                                colBackground: root.currentView === modelData.id ? root.colPrimary : "transparent"
                                colBackgroundHover: root.currentView === modelData.id ? root.colPrimary : root.colLayer2Hover
                                onClicked: root.currentView = modelData.id

                                contentItem: RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    MaterialSymbol {
                                        text: modelData.icon
                                        iconSize: 18
                                        color: root.currentView === modelData.id ? Appearance.colors.colOnPrimary : root.colTextSecondary
                                    }
                                    StyledText {
                                        text: modelData.label
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        font.weight: root.currentView === modelData.id ? Font.Medium : Font.Normal
                                        color: root.currentView === modelData.id ? Appearance.colors.colOnPrimary : root.colText
                                        visible: text !== ""
                                    }
                                }
                            }
                        }
                    }
                }

                YtMusicPlayerCard {
                    Layout.fillWidth: true
                    visible: root.hasTrack
                }

                Loader {
                    Layout.fillWidth: true
                    active: YtMusic.error !== ""
                    visible: active
                    sourceComponent: Rectangle {
                        implicitHeight: 36
                        radius: root.radiusSmall
                        color: Appearance.colors.colErrorContainer
                        RowLayout {
                            anchors.centerIn: parent
                            width: parent.width - 16
                            spacing: 8
                            MaterialSymbol { text: "error"; iconSize: 18; color: Appearance.colors.colOnErrorContainer }
                            StyledText { 
                                Layout.fillWidth: true
                                text: YtMusic.error
                                color: Appearance.colors.colOnErrorContainer
                                font.pixelSize: Appearance.font.pixelSize.small
                                elide: Text.ElideRight 
                            }
                            RippleButton { 
                                implicitWidth: 24
                                implicitHeight: 24
                                buttonRadius: 12
                                colBackground: "transparent"
                                onClicked: YtMusic.error = ""
                                contentItem: MaterialSymbol { 
                                    anchors.centerIn: parent
                                    text: "close"
                                    iconSize: 16
                                    color: Appearance.colors.colOnErrorContainer 
                                } 
                            }
                        }
                    }
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: ["search", "playlists", "queue", "account"].indexOf(root.currentView)

                    SearchView {}
                    LibraryView {}
                    QueueView {}
                    AccountView {}
                }
            }
        }
    }

    Popup {
        id: addToPlaylistPopup
        anchors.centerIn: parent
        width: 220
        height: Math.min(300, Math.max(120, YtMusic.playlists.length * 40 + 80))
        padding: 12
        modal: true
        dim: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        property var targetItem: null

        background: Rectangle { 
            color: Appearance.inirEverywhere ? Appearance.inir.colLayer2
                 : Appearance.auroraEverywhere ? Appearance.colors.colLayer1Base
                 : Appearance.colors.colLayer1
            radius: root.radiusNormal
            border.width: root.borderWidth
            border.color: root.colBorder 
        }
        
        contentItem: ColumnLayout {
            spacing: 8
            StyledText { 
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("Add to Playlist")
                font.weight: Font.Medium
                color: root.colText 
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: YtMusic.playlists
                spacing: 2
                delegate: RippleButton {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    implicitHeight: 36
                    buttonRadius: root.radiusSmall
                    colBackground: "transparent"
                    colBackgroundHover: root.colLayer2Hover
                    onClicked: { 
                        if (addToPlaylistPopup.targetItem) { 
                            YtMusic.addToPlaylist(index, addToPlaylistPopup.targetItem)
                            addToPlaylistPopup.close() 
                        } 
                    }
                    contentItem: StyledText { 
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.name ?? ""
                        color: root.colText
                        elide: Text.ElideRight 
                    }
                }
            }
            
            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 32
                buttonRadius: root.radiusSmall
                colBackground: root.colLayer2
                colBackgroundHover: root.colLayer2Hover
                onClicked: { 
                    addToPlaylistPopup.close()
                    createPlaylistPopup.open() 
                }
                contentItem: RowLayout { 
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialSymbol { text: "add"; iconSize: 18; color: root.colPrimary }
                    StyledText { text: Translation.tr("New Playlist"); color: root.colPrimary } 
                }
            }
        }
    }

    Popup {
        id: createPlaylistPopup
        anchors.centerIn: parent
        width: 280
        height: 120
        modal: true
        dim: true
        background: Rectangle { 
            color: Appearance.inirEverywhere ? Appearance.inir.colLayer2
                 : Appearance.auroraEverywhere ? Appearance.colors.colLayer1Base
                 : Appearance.colors.colLayer1
            radius: root.radiusNormal
            border.width: root.borderWidth
            border.color: root.colBorder 
        }
        contentItem: ColumnLayout {
            spacing: 12
            StyledText { 
                text: Translation.tr("New Playlist")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Medium
                color: root.colText 
            }
            TextField { 
                id: newPlaylistName
                Layout.fillWidth: true
                placeholderText: Translation.tr("Playlist name")
                color: root.colText
                placeholderTextColor: root.colTextSecondary
                background: Rectangle { color: root.colLayer2; radius: root.radiusSmall }
                onAccepted: createBtn.clicked() 
            }
            RowLayout { 
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                RippleButton { 
                    id: createBtn
                    implicitWidth: 80
                    implicitHeight: 32
                    buttonRadius: root.radiusSmall
                    colBackground: root.colPrimary
                    onClicked: { 
                        if (newPlaylistName.text.trim()) { 
                            YtMusic.createPlaylist(newPlaylistName.text)
                            newPlaylistName.text = ""
                            createPlaylistPopup.close() 
                        } 
                    }
                    contentItem: StyledText { 
                        anchors.centerIn: parent
                        text: Translation.tr("Create")
                        color: Appearance.colors.colOnPrimary 
                    }
                }
            }
        }
    }


    component SearchView: ColumnLayout {
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 42
            radius: Appearance.inirEverywhere ? root.radiusSmall : Appearance.rounding.full
            color: root.colLayer2
            border.width: root.borderWidth
            border.color: root.colBorder

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 10
                spacing: 10
                
                MaterialSymbol { 
                    text: YtMusic.searching ? "hourglass_empty" : "search"
                    iconSize: 20
                    color: root.colTextSecondary
                    RotationAnimation on rotation { 
                        from: 0; to: 360; duration: 1000
                        loops: Animation.Infinite
                        running: YtMusic.searching 
                    }
                }
                
                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Search YouTube Music...")
                    color: root.colText
                    placeholderTextColor: root.colTextSecondary
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.family: Appearance.font.family.main
                    background: Item {}
                    selectByMouse: true
                    onAccepted: { if (text.trim()) YtMusic.search(text) }
                    Keys.onEscapePressed: { text = ""; focus = false }
                }
                
                RippleButton {
                    implicitWidth: 28
                    implicitHeight: 28
                    visible: searchField.text.length > 0
                    buttonRadius: 14
                    colBackground: "transparent"
                    colBackgroundHover: root.colLayer2Hover
                    onClicked: { searchField.text = ""; searchField.forceActiveFocus() }
                    contentItem: MaterialSymbol { 
                        anchors.centerIn: parent
                        text: "close"
                        iconSize: 18
                        color: root.colTextSecondary 
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width
                spacing: 12
                visible: !root.hasResults && !YtMusic.searching && YtMusic.recentSearches.length === 0
                
                MaterialSymbol { 
                    Layout.alignment: Qt.AlignHCenter
                    text: "library_music"
                    iconSize: 56
                    color: root.colTextSecondary
                    opacity: 0.5 
                }
                StyledText { 
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("Search for music")
                    font.pixelSize: Appearance.font.pixelSize.large
                    color: root.colTextSecondary 
                }
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 6
                visible: !root.hasResults && !YtMusic.searching && YtMusic.recentSearches.length > 0
                
                RowLayout {
                    Layout.fillWidth: true
                    StyledText { 
                        text: Translation.tr("Recent")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: root.colTextSecondary 
                    }
                    Item { Layout.fillWidth: true }
                    RippleButton { 
                        implicitWidth: 24
                        implicitHeight: 24
                        buttonRadius: 12
                        colBackground: "transparent"
                        colBackgroundHover: root.colLayer2Hover
                        onClicked: YtMusic.clearRecentSearches()
                        contentItem: MaterialSymbol { 
                            anchors.centerIn: parent
                            text: "delete_sweep"
                            iconSize: 16
                            color: root.colTextSecondary 
                        }
                        StyledToolTip { text: Translation.tr("Clear") }
                    }
                }
                
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: YtMusic.recentSearches
                    spacing: 2
                    delegate: RippleButton {
                        required property string modelData
                        width: ListView.view.width
                        implicitHeight: 36
                        buttonRadius: root.radiusSmall
                        colBackground: "transparent"
                        colBackgroundHover: root.colSurfaceHover
                        onClicked: { searchField.text = modelData; YtMusic.search(modelData) }
                        contentItem: RowLayout { 
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8
                            MaterialSymbol { text: "history"; iconSize: 18; color: root.colTextSecondary }
                            StyledText { Layout.fillWidth: true; text: modelData; color: root.colText; elide: Text.ElideRight }
                        }
                    }
                }
            }

            ListView {
                anchors.fill: parent
                visible: root.hasResults || YtMusic.searching
                clip: true
                model: YtMusic.searchResults
                spacing: 4
                
                header: Column {
                    width: parent.width
                    spacing: 8
                    
                    // Artist header card - shows when artist info is available
                    Rectangle {
                        width: parent.width
                        height: YtMusic.currentArtistInfo ? 56 : 0
                        visible: YtMusic.currentArtistInfo !== null
                        radius: root.radiusSmall
                        color: Appearance.inirEverywhere ? Appearance.inir.colLayer2
                             : Appearance.auroraEverywhere ? Appearance.colors.colLayer1Base
                             : root.colLayer2
                        border.width: root.borderWidth
                        border.color: root.colBorder
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 10
                            
                            // Artist avatar
                            Rectangle {
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
                                radius: 20
                                color: root.colSurfaceHover
                                
                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    source: YtMusic.currentArtistInfo?.thumbnail ?? ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    visible: source !== ""
                                    layer.enabled: true
                                    layer.effect: GE.OpacityMask {
                                        maskSource: Rectangle { width: 38; height: 38; radius: 19 }
                                    }
                                }
                                
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    visible: !YtMusic.currentArtistInfo?.thumbnail
                                    text: "person"
                                    iconSize: 24
                                    color: root.colTextSecondary
                                }
                            }
                            
                            // Artist name
                            StyledText {
                                Layout.fillWidth: true
                                text: YtMusic.currentArtistInfo?.name ?? ""
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Medium
                                color: root.colText
                                elide: Text.ElideRight
                            }
                            
                            // Play all from this artist
                            RippleButton {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                buttonRadius: 16
                                colBackground: root.colPrimary
                                visible: root.hasResults
                                onClicked: {
                                    // Play first result
                                    if (YtMusic.searchResults.length > 0) {
                                        YtMusic.playFromSearch(0)
                                    }
                                }
                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "play_arrow"
                                    iconSize: 20
                                    fill: 1
                                    color: Appearance.colors.colOnPrimary
                                }
                                StyledToolTip { text: Translation.tr("Play") }
                            }
                        }
                    }
                    
                    // Searching indicator
                    Loader { 
                        width: parent.width
                        active: YtMusic.searching
                        height: active ? 40 : 0
                        sourceComponent: RowLayout { 
                            spacing: 8
                            Item { Layout.fillWidth: true }
                            BusyIndicator { implicitWidth: 24; implicitHeight: 24; running: true }
                            StyledText { text: Translation.tr("Searching..."); color: root.colTextSecondary }
                            Item { Layout.fillWidth: true } 
                        }
                    }
                }
                
                delegate: YtMusicTrackItem {
                    required property var modelData
                    required property int index
                    width: ListView.view?.width ?? 200
                    track: modelData
                    showAddToPlaylist: true
                    onPlayRequested: YtMusic.playFromSearch(index)
                    onAddToPlaylistRequested: root.openAddToPlaylist(modelData)
                }
            }
        }
    }

    component LibraryView: ColumnLayout {
        spacing: 8
        property int expandedPlaylist: -1
        property bool showLiked: false

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            
            RippleButton {
                visible: expandedPlaylist >= 0 || showLiked
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: 16
                colBackground: "transparent"
                colBackgroundHover: root.colLayer2Hover
                onClicked: { expandedPlaylist = -1; showLiked = false }
                contentItem: MaterialSymbol { anchors.centerIn: parent; text: "arrow_back"; iconSize: 20; color: root.colText }
            }
            
            StyledText { 
                text: showLiked ? Translation.tr("Liked Songs") 
                    : expandedPlaylist >= 0 ? (YtMusic.playlists[expandedPlaylist]?.name ?? "") 
                    : Translation.tr("Library")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Medium
                color: root.colText
            }
            
            Item { Layout.fillWidth: true }
            
            RippleButton {
                visible: (expandedPlaylist >= 0 && (YtMusic.playlists[expandedPlaylist]?.items?.length ?? 0) > 0) || (showLiked && YtMusic.likedSongs.length > 0)
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: 16
                colBackground: root.colPrimary
                onClicked: showLiked ? _playLiked(false) : YtMusic.playPlaylist(expandedPlaylist, false)
                contentItem: MaterialSymbol { anchors.centerIn: parent; text: "play_arrow"; iconSize: 20; color: Appearance.colors.colOnPrimary }
                StyledToolTip { text: Translation.tr("Play all") }
            }
            
            RippleButton {
                visible: (expandedPlaylist >= 0 && (YtMusic.playlists[expandedPlaylist]?.items?.length ?? 0) > 1) || (showLiked && YtMusic.likedSongs.length > 1)
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: 16
                colBackground: "transparent"
                colBackgroundHover: root.colLayer2Hover
                onClicked: showLiked ? _playLiked(true) : YtMusic.playPlaylist(expandedPlaylist, true)
                contentItem: MaterialSymbol { anchors.centerIn: parent; text: "shuffle"; iconSize: 20; color: root.colTextSecondary }
                StyledToolTip { text: Translation.tr("Shuffle") }
            }
            
            RippleButton {
                visible: expandedPlaylist < 0 && !showLiked
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: 16
                colBackground: root.colPrimary
                onClicked: createPlaylistPopup.open()
                contentItem: MaterialSymbol { anchors.centerIn: parent; text: "add"; iconSize: 20; color: Appearance.colors.colOnPrimary }
                StyledToolTip { text: Translation.tr("New playlist") }
            }
        }

        function _playLiked(shuffle) {
            let items = [...YtMusic.likedSongs]
            if (items.length === 0) return
            if (shuffle) { 
                for (let i = items.length - 1; i > 0; i--) { 
                    const j = Math.floor(Math.random() * (i + 1))
                    const temp = items[i]
                    items[i] = items[j]
                    items[j] = temp
                } 
            }
            YtMusic.queue = items.slice(1)
            YtMusic.play(items[0])
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: expandedPlaylist < 0 && !showLiked
            clip: true
            spacing: 4
            model: ListModel {
                id: libraryModel
                Component.onCompleted: _rebuild()
                function _rebuild() {
                    clear()
                    append({ type: "liked", name: Translation.tr("Liked Songs"), count: YtMusic.likedSongs.length, icon: "favorite", idx: -1 })
                    for (let i = 0; i < YtMusic.playlists.length; i++) {
                        append({ type: "playlist", name: YtMusic.playlists[i].name, count: YtMusic.playlists[i].items?.length ?? 0, icon: "queue_music", idx: i })
                    }
                }
            }
            Connections { 
                target: YtMusic
                function onPlaylistsChanged() { libraryModel._rebuild() }
                function onLikedSongsChanged() { libraryModel._rebuild() } 
            }
            delegate: RippleButton {
                required property var model
                width: ListView.view.width
                implicitHeight: 56
                buttonRadius: root.radiusSmall
                colBackground: "transparent"
                colBackgroundHover: root.colSurfaceHover
                onClicked: model.type === "liked" ? (showLiked = true) : (expandedPlaylist = model.idx)
                contentItem: RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 10
                    Rectangle { 
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: root.radiusSmall
                        color: root.colLayer2
                        MaterialSymbol { 
                            anchors.centerIn: parent
                            text: model.icon
                            iconSize: 22
                            color: model.type === "liked" ? Appearance.colors.colError : root.colPrimary 
                        }
                    }
                    ColumnLayout { 
                        Layout.fillWidth: true
                        spacing: 2
                        StyledText { 
                            Layout.fillWidth: true
                            text: model.name
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Medium
                            color: root.colText
                            elide: Text.ElideRight 
                        }
                        StyledText { 
                            text: Translation.tr("%1 songs").arg(model.count)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: root.colTextSecondary 
                        }
                    }
                    MaterialSymbol { text: "chevron_right"; iconSize: 20; color: root.colTextSecondary }
                }
            }
            
            ColumnLayout {
                anchors.centerIn: parent
                visible: YtMusic.playlists.length === 0 && YtMusic.likedSongs.length === 0
                spacing: 12
                MaterialSymbol { Layout.alignment: Qt.AlignHCenter; text: "playlist_add"; iconSize: 48; color: root.colTextSecondary; opacity: 0.5 }
                StyledText { Layout.alignment: Qt.AlignHCenter; text: Translation.tr("No playlists yet"); color: root.colTextSecondary }
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: expandedPlaylist >= 0
            clip: true
            spacing: 4
            model: expandedPlaylist >= 0 ? (YtMusic.playlists[expandedPlaylist]?.items ?? []) : []
            delegate: YtMusicTrackItem {
                required property var modelData
                required property int index
                width: ListView.view?.width ?? 200
                track: modelData
                trackIndex: index
                showIndex: true
                showRemoveButton: true
                showAddToQueue: false
                onPlayRequested: YtMusic.play(modelData)
                onRemoveRequested: YtMusic.removeFromPlaylist(expandedPlaylist, index)
            }
            ColumnLayout {
                anchors.centerIn: parent
                visible: expandedPlaylist >= 0 && (YtMusic.playlists[expandedPlaylist]?.items?.length ?? 0) === 0
                spacing: 12
                MaterialSymbol { Layout.alignment: Qt.AlignHCenter; text: "music_off"; iconSize: 48; color: root.colTextSecondary; opacity: 0.5 }
                StyledText { Layout.alignment: Qt.AlignHCenter; text: Translation.tr("Playlist is empty"); color: root.colTextSecondary }
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: showLiked
            clip: true
            spacing: 4
            model: YtMusic.likedSongs
            delegate: YtMusicTrackItem {
                required property var modelData
                required property int index
                width: ListView.view?.width ?? 200
                track: modelData
                showAddToPlaylist: true
                onPlayRequested: YtMusic.play(modelData)
                onAddToPlaylistRequested: root.openAddToPlaylist(modelData)
            }
            ColumnLayout {
                anchors.centerIn: parent
                visible: YtMusic.likedSongs.length === 0
                spacing: 12
                MaterialSymbol { Layout.alignment: Qt.AlignHCenter; text: "favorite"; iconSize: 48; color: root.colTextSecondary; opacity: 0.5 }
                StyledText { 
                    Layout.alignment: Qt.AlignHCenter
                    text: YtMusic.googleConnected ? Translation.tr("No liked songs") : Translation.tr("Sign in to see liked songs")
                    color: root.colTextSecondary 
                }
                RippleButton {
                    Layout.alignment: Qt.AlignHCenter
                    visible: YtMusic.googleConnected
                    implicitWidth: 120
                    implicitHeight: 36
                    buttonRadius: 18
                    colBackground: root.colPrimary
                    onClicked: YtMusic.fetchLikedSongs()
                    contentItem: StyledText { anchors.centerIn: parent; text: Translation.tr("Sync Now"); color: Appearance.colors.colOnPrimary }
                }
            }
        }

        RippleButton {
            Layout.fillWidth: true
            visible: expandedPlaylist >= 0
            implicitHeight: 36
            buttonRadius: root.radiusSmall
            colBackground: "transparent"
            colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colError, 0.85)
            onClicked: { YtMusic.deletePlaylist(expandedPlaylist); expandedPlaylist = -1 }
            contentItem: RowLayout { 
                anchors.centerIn: parent
                spacing: 8
                MaterialSymbol { text: "delete"; iconSize: 18; color: Appearance.colors.colError }
                StyledText { text: Translation.tr("Delete playlist"); color: Appearance.colors.colError } 
            }
        }
    }


    component QueueView: ColumnLayout {
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            
            StyledText { 
                text: Translation.tr("Queue")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Medium
                color: root.colText 
            }
            StyledText { 
                text: `(${YtMusic.queue.length})`
                font.pixelSize: Appearance.font.pixelSize.small
                color: root.colTextSecondary
                visible: root.hasQueue 
            }
            Item { Layout.fillWidth: true }
            
            RippleButton { 
                implicitWidth: 28
                implicitHeight: 28
                buttonRadius: 14
                colBackground: YtMusic.shuffleMode ? root.colPrimary : "transparent"
                colBackgroundHover: YtMusic.shuffleMode ? root.colPrimary : root.colLayer2Hover
                onClicked: YtMusic.toggleShuffle()
                contentItem: MaterialSymbol { 
                    anchors.centerIn: parent
                    text: "shuffle"
                    iconSize: 18
                    color: YtMusic.shuffleMode ? Appearance.colors.colOnPrimary : root.colTextSecondary 
                }
                StyledToolTip { text: YtMusic.shuffleMode ? Translation.tr("Shuffle On") : Translation.tr("Shuffle Off") }
            }
            
            RippleButton { 
                implicitWidth: 28
                implicitHeight: 28
                buttonRadius: 14
                colBackground: YtMusic.repeatMode > 0 ? root.colPrimary : "transparent"
                colBackgroundHover: YtMusic.repeatMode > 0 ? root.colPrimary : root.colLayer2Hover
                onClicked: YtMusic.cycleRepeatMode()
                contentItem: MaterialSymbol { 
                    anchors.centerIn: parent
                    text: YtMusic.repeatMode === 1 ? "repeat_one" : "repeat"
                    iconSize: 18
                    color: YtMusic.repeatMode > 0 ? Appearance.colors.colOnPrimary : root.colTextSecondary 
                }
                StyledToolTip { 
                    text: YtMusic.repeatMode === 0 ? Translation.tr("Repeat Off") 
                        : YtMusic.repeatMode === 1 ? Translation.tr("Repeat One") 
                        : Translation.tr("Repeat All") 
                }
            }
            
            RippleButton { 
                visible: root.hasQueue
                implicitWidth: 80
                implicitHeight: 28
                buttonRadius: root.radiusSmall
                colBackground: root.colPrimary
                onClicked: YtMusic.playQueue()
                contentItem: StyledText { 
                    anchors.centerIn: parent
                    text: Translation.tr("Play")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnPrimary 
                }
            }
            
            RippleButton { 
                visible: root.hasQueue
                implicitWidth: 28
                implicitHeight: 28
                buttonRadius: 14
                colBackground: "transparent"
                colBackgroundHover: root.colLayer2Hover
                onClicked: YtMusic.clearQueue()
                contentItem: MaterialSymbol { 
                    anchors.centerIn: parent
                    text: "delete_sweep"
                    iconSize: 18
                    color: root.colTextSecondary 
                }
                StyledToolTip { text: Translation.tr("Clear") }
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: YtMusic.queue
            spacing: 4
            delegate: YtMusicTrackItem {
                required property var modelData
                required property int index
                width: ListView.view?.width ?? 200
                track: modelData
                trackIndex: index
                showIndex: true
                showRemoveButton: true
                showAddToQueue: false
                onPlayRequested: { 
                    YtMusic.queue = YtMusic.queue.slice(index)
                    YtMusic.playQueue() 
                }
                onRemoveRequested: YtMusic.removeFromQueue(index)
            }
            ColumnLayout { 
                anchors.centerIn: parent
                visible: !root.hasQueue
                spacing: 12
                MaterialSymbol { Layout.alignment: Qt.AlignHCenter; text: "queue_music"; iconSize: 48; color: root.colTextSecondary; opacity: 0.5 }
                StyledText { Layout.alignment: Qt.AlignHCenter; text: Translation.tr("Queue is empty"); color: root.colTextSecondary }
            }
        }
    }

    component AccountView: ColumnLayout {
        spacing: 12

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 90
            radius: root.radiusNormal
            color: YtMusic.googleConnected ? root.colPrimary : root.colLayer2
            border.width: YtMusic.googleConnected ? 0 : root.borderWidth
            border.color: root.colBorder

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16
                
                Rectangle {
                    Layout.preferredWidth: 56
                    Layout.preferredHeight: 56
                    radius: 28
                    color: YtMusic.googleConnected 
                        ? ColorUtils.transparentize(Appearance.colors.colOnPrimary, 0.85) 
                        : ColorUtils.transparentize(root.colTextSecondary, 0.9)
                    
                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        source: YtMusic.userAvatar || ""
                        visible: YtMusic.googleConnected && YtMusic.userAvatar !== ""
                        fillMode: Image.PreserveAspectCrop
                        layer.enabled: true
                        layer.effect: GE.OpacityMask { 
                            maskSource: Rectangle { width: 52; height: 52; radius: 26 } 
                        }
                    }
                    
                    MaterialSymbol { 
                        anchors.centerIn: parent
                        visible: !YtMusic.googleConnected || YtMusic.userAvatar === ""
                        text: YtMusic.googleConnected ? "account_circle" : "person_off"
                        iconSize: 28
                        color: YtMusic.googleConnected ? Appearance.colors.colOnPrimary : root.colTextSecondary 
                    }
                }
                
                ColumnLayout { 
                    Layout.fillWidth: true
                    spacing: 2
                    StyledText { 
                        text: YtMusic.googleConnected ? (YtMusic.userName || Translation.tr("User")) : Translation.tr("Not Connected")
                        font.pixelSize: Appearance.font.pixelSize.large
                        font.weight: Font.Bold
                        color: YtMusic.googleConnected ? Appearance.colors.colOnPrimary : root.colText 
                    }
                    StyledText { 
                        text: YtMusic.googleConnected ? Translation.tr("Library Synced") : Translation.tr("Sign in to sync")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: YtMusic.googleConnected 
                            ? ColorUtils.transparentize(Appearance.colors.colOnPrimary, 0.3) 
                            : root.colTextSecondary 
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            
            RippleButton {
                visible: !YtMusic.googleConnected
                implicitWidth: 140
                implicitHeight: 36
                buttonRadius: 18
                colBackground: root.colPrimary
                onClicked: YtMusic.quickConnect()
                contentItem: RowLayout { 
                    anchors.centerIn: parent
                    spacing: 8
                    MaterialSymbol { text: "bolt"; iconSize: 18; color: Appearance.colors.colOnPrimary }
                    StyledText { text: Translation.tr("Quick Connect"); color: Appearance.colors.colOnPrimary; font.weight: Font.Medium } 
                }
            }
            
            RippleButton {
                visible: YtMusic.googleConnected
                implicitWidth: 120
                implicitHeight: 36
                buttonRadius: 18
                colBackground: ColorUtils.transparentize(root.colText, 0.9)
                colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colError, 0.8)
                onClicked: YtMusic.disconnectGoogle()
                contentItem: RowLayout { 
                    anchors.centerIn: parent
                    spacing: 8
                    MaterialSymbol { 
                        text: "logout"
                        iconSize: 18
                        color: parent.parent.buttonHovered ? Appearance.colors.colError : root.colText 
                    }
                    StyledText { 
                        text: Translation.tr("Disconnect")
                        color: parent.parent.buttonHovered ? Appearance.colors.colError : root.colText
                        font.weight: Font.Medium 
                    } 
                }
            }
        }

        Loader {
            Layout.fillWidth: true
            active: !YtMusic.googleConnected
            visible: active
            sourceComponent: ColumnLayout {
                spacing: 0
                
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    buttonRadius: root.radiusSmall
                    colBackground: "transparent"
                    colBackgroundHover: root.colLayer2Hover
                    onClicked: advancedLoader.active = !advancedLoader.active
                    contentItem: RowLayout { 
                        anchors.fill: parent
                        anchors.margins: 10
                        MaterialSymbol { text: "settings"; iconSize: 18; color: root.colTextSecondary }
                        StyledText { Layout.fillWidth: true; text: Translation.tr("Advanced Options"); color: root.colText }
                        MaterialSymbol { text: advancedLoader.active ? "expand_less" : "expand_more"; iconSize: 18; color: root.colTextSecondary }
                    }
                }
                
                Loader {
                    id: advancedLoader
                    Layout.fillWidth: true
                    active: false
                    visible: active
                    sourceComponent: ColumnLayout {
                        spacing: 12
                        
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: infoCol.implicitHeight + 20
                            radius: root.radiusSmall
                            color: ColorUtils.transparentize(root.colPrimary, 0.95)
                            border.width: 1
                            border.color: ColorUtils.transparentize(root.colPrimary, 0.8)
                            
                            ColumnLayout { 
                                id: infoCol
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8
                                
                                StyledText { 
                                    Layout.fillWidth: true
                                    text: Translation.tr("Log in to YouTube Music in your browser, then use Quick Connect.")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: root.colText
                                    wrapMode: Text.WordWrap 
                                }
                                
                                RippleButton { 
                                    implicitWidth: 160
                                    implicitHeight: 32
                                    buttonRadius: 16
                                    colBackground: root.colLayer2
                                    onClicked: YtMusic.openYtMusicInBrowser()
                                    contentItem: RowLayout { 
                                        anchors.centerIn: parent
                                        spacing: 6
                                        MaterialSymbol { text: "open_in_new"; iconSize: 16; color: root.colPrimary }
                                        StyledText { text: Translation.tr("Open YouTube Music"); color: root.colPrimary; font.pixelSize: Appearance.font.pixelSize.smaller } 
                                    }
                                }
                            }
                        }
                        
                        StyledText { text: Translation.tr("Manual Selection"); font.weight: Font.DemiBold; color: root.colText }
                        
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            rowSpacing: 8
                            columnSpacing: 8
                            visible: YtMusic.detectedBrowsers.length > 0
                            
                            Repeater {
                                model: YtMusic.detectedBrowsers
                                delegate: RippleButton {
                                    required property string modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 40
                                    buttonRadius: root.radiusSmall
                                    colBackground: root.colLayer2
                                    colBackgroundHover: root.colSurfaceHover
                                    onClicked: YtMusic.connectGoogle(modelData)
                                    contentItem: RowLayout { 
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 8
                                        StyledText { text: YtMusic.browserInfo[modelData]?.icon ?? "🌐"; font.pixelSize: 16 }
                                        StyledText { text: YtMusic.browserInfo[modelData]?.name ?? modelData; color: root.colText; Layout.fillWidth: true }
                                    }
                                }
                            }
                        }
                        
                        StyledText { text: Translation.tr("Custom Cookies File"); font.weight: Font.DemiBold; color: root.colText }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 40
                            radius: root.radiusSmall
                            color: root.colLayer2
                            border.width: 1
                            border.color: cookiesField.activeFocus ? root.colPrimary : root.colBorder
                            
                            RowLayout { 
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8
                                MaterialSymbol { text: "description"; iconSize: 18; color: root.colTextSecondary }
                                TextField { 
                                    id: cookiesField
                                    Layout.fillWidth: true
                                    placeholderText: "/path/to/cookies.txt"
                                    text: YtMusic.customCookiesPath
                                    color: root.colText
                                    placeholderTextColor: root.colTextSecondary
                                    background: Item {}
                                    onAccepted: if (text) YtMusic.setCustomCookiesPath(text) 
                                }
                            }
                        }
                    }
                }
            }
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: YtMusic.googleConnected
            visible: active
            sourceComponent: ColumnLayout {
                spacing: 8
                
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    StyledText { text: Translation.tr("YouTube Music Playlists"); font.weight: Font.Bold; color: root.colText }
                    Item { Layout.fillWidth: true }
                    
                    RippleButton { 
                        implicitWidth: 32
                        implicitHeight: 32
                        buttonRadius: 16
                        colBackground: "transparent"
                        colBackgroundHover: root.colLayer2Hover
                        onClicked: YtMusic.fetchLikedSongs()
                        contentItem: MaterialSymbol { anchors.centerIn: parent; text: "favorite"; iconSize: 18; color: root.colTextSecondary }
                        StyledToolTip { text: Translation.tr("Sync Liked Songs") }
                    }
                    
                    RippleButton { 
                        implicitWidth: 32
                        implicitHeight: 32
                        buttonRadius: 16
                        colBackground: "transparent"
                        colBackgroundHover: root.colLayer2Hover
                        onClicked: YtMusic.fetchYtMusicPlaylists()
                        contentItem: MaterialSymbol { 
                            anchors.centerIn: parent
                            text: YtMusic.searching ? "sync" : "refresh"
                            iconSize: 18
                            color: root.colTextSecondary
                            RotationAnimation on rotation { 
                                from: 0; to: 360; duration: 1000
                                loops: Animation.Infinite
                                running: YtMusic.searching 
                            }
                        }
                        StyledToolTip { text: Translation.tr("Refresh") }
                    }
                }
                
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: YtMusic.ytMusicPlaylists
                    spacing: 4
                    delegate: RippleButton {
                        required property var modelData
                        width: ListView.view.width
                        implicitHeight: 56
                        buttonRadius: root.radiusSmall
                        colBackground: "transparent"
                        colBackgroundHover: root.colSurfaceHover
                        onClicked: YtMusic.importYtMusicPlaylist(modelData.url, modelData.title)
                        contentItem: RowLayout { 
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 12
                            Rectangle { 
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
                                radius: root.radiusSmall
                                color: root.colLayer2
                                MaterialSymbol { anchors.centerIn: parent; text: "queue_music"; iconSize: 20; color: root.colPrimary } 
                            }
                            ColumnLayout { 
                                Layout.fillWidth: true
                                spacing: 2
                                StyledText { 
                                    text: modelData.title ?? ""
                                    font.weight: Font.Medium
                                    color: root.colText
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true 
                                }
                                StyledText { 
                                    text: Translation.tr("%1 tracks").arg(modelData.count ?? "?")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: root.colTextSecondary 
                                }
                            }
                            MaterialSymbol { text: "download"; iconSize: 20; color: root.colTextSecondary }
                        }
                    }
                }
            }
        }
        
        Item { Layout.fillHeight: true }
    }
}
