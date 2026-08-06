import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects as GE
import QtQuick.Effects
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.services.deferred
import qs.modules.sidebarLeft.innertune

// Literal translation of Player.kt (BottomSheetPlayer) — blurred art background, large
// thumbnail, title/artists, seek slider with time labels, and the control row
// [favorite | shuffle | prev | play/pause(64dp, animated roundness) | next | repeat].
// Portrait by default; when the sidebar is widened (Ctrl+O) it reflows to a two-pane
// landscape (art+controls left, lyrics/queue right). Bound to YtMusic.
Item {
    id: root

    readonly property int hp: 24   // sidebar-tuned (InnerTune phone uses 32)
    // Two-pane landscape once there's room for it (Ctrl+O widens the sidebar to ~750).
    readonly property bool landscape: width >= 620
    readonly property bool liked: {
        const v = YtMusic.currentVideoId;
        return v !== "" && (YtMusic.likedSongs ?? []).some(s => s.videoId === v);
    }
    // Squircle while playing, full circle when paused (radius caps at half the 64dp button).
    readonly property real playPauseRoundness: YtMusic.isPlaying ? 18 : 32
    property bool showLyrics: false
    property bool showQueue: false
    property bool showMore: false
    readonly property bool _expandedView: showLyrics || showQueue
    // Which side content is actually on screen. In landscape the side pane is always present
    // (lyrics by default), so the header buttons just pick between lyrics and queue.
    readonly property bool _showQueuePane: showQueue
    readonly property bool _showLyricsPane: landscape ? !showQueue : showLyrics
    // Drag-to-dismiss state (consumed by the parent's y binding).
    property bool dragging: false
    property real dragY: 0

    signal collapseRequested()
    signal goToAlbumRequested(string browseId)

    // Current queue item (carries albumId etc. that the bare currentVideoId doesn't).
    readonly property var _curItem: (YtMusic.currentIndex >= 0 && YtMusic.currentIndex < (YtMusic.activePlaylist?.length ?? 0))
        ? YtMusic.activePlaylist[YtMusic.currentIndex] : null
    readonly property string _albumId: root._curItem?.albumId ?? ""

    // Load synced lyrics (LrcLib) whenever the player is showing a new track.
    function _loadLyrics() {
        if (YtMusic.currentVideoId)
            InnerTube.loadLyrics(YtMusic.currentVideoId, YtMusic.currentTitle, YtMusic.currentArtist, YtMusic.currentDuration);
    }
    onVisibleChanged: if (visible) _loadLyrics()
    Connections {
        target: YtMusic
        // Defer a tick so currentTitle/artist/duration (set alongside the id) are all fresh.
        function onCurrentVideoIdChanged() { Qt.callLater(root._loadLyrics); }
    }

    // --- Blurred album-art background + scrim (InnerTune player backdrop) ---
    StyledImage {
        id: bgArt
        anchors.fill: parent
        source: ITDimens.highResThumb(YtMusic.currentThumbnail, 0)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }
    GE.FastBlur {
        anchors.fill: parent
        source: bgArt
        radius: 96
        cached: true
    }
    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colLayer0Base
        opacity: 0.82
    }

    // ===== Reusable pieces (used by both portrait and landscape bodies) =====

    // Square album art with a soft elevation shadow; tap flips to lyrics (portrait only).
    component CoverArt: Item {
        id: cover
        StyledRectangularShadow {
            target: coverThumb
            radius: coverThumb.cornerRadius
            blur: 24
            opacity: 0.45
        }
        ITThumbnail {
            id: coverThumb
            anchors.fill: parent
            thumbnailUrl: YtMusic.currentThumbnail
            cornerRadius: Appearance.rounding.large
            highRes: true
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (!root.landscape) root.showLyrics = !root.showLyrics
        }
    }

    // Lyrics / queue, crossfading between the two.
    component SidePanel: Item {
        ITLyrics {
            anchors.fill: parent
            opacity: root._showLyricsPane ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveFast.duration) } }
            lyrics: InnerTube.lyrics
        }
        ITQueue {
            anchors.fill: parent
            opacity: root._showQueuePane ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveFast.duration) } }
        }
    }

    // Title · artist · seek slider · time labels · transport controls.
    component MetaControls: ColumnLayout {
        spacing: 0

        // Title (marquee on overflow).
        ITMarqueeText {
            Layout.fillWidth: true
            Layout.leftMargin: root.hp
            Layout.rightMargin: root.hp
            text: YtMusic.currentTitle
            font.family: Appearance.font.family.title
            font.pixelSize: Appearance.font.pixelSize.title
            font.weight: Font.Bold
            color: Appearance.colors.colOnSurface
        }
        Item { Layout.preferredHeight: 6 }
        // Artists.
        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: root.hp
            Layout.rightMargin: root.hp
            text: YtMusic.currentArtist
            font.pixelSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colSecondary
            maximumLineCount: 1
            elide: Text.ElideRight
        }

        Item { Layout.preferredHeight: 12 }

        // Seek slider.
        StyledSlider {
            id: seekSlider
            Layout.fillWidth: true
            Layout.leftMargin: root.hp
            Layout.rightMargin: root.hp
            from: 0
            to: YtMusic.currentDuration > 0 ? YtMusic.currentDuration : 1
            stopIndicatorValues: []
            value: _dragging ? value : YtMusic.currentPosition
            property bool _dragging: false
            onPressedChanged: {
                if (pressed) _dragging = true;
                else { YtMusic.seek(value); _dragging = false; }
            }
        }
        Item { Layout.preferredHeight: 4 }
        // Time labels.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: root.hp + 4
            Layout.rightMargin: root.hp + 4
            StyledText {
                text: root._fmt(seekSlider._dragging ? seekSlider.value : YtMusic.currentPosition)
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnSurfaceVariant
            }
            Item { Layout.fillWidth: true }
            StyledText {
                text: root._fmt(YtMusic.currentDuration)
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnSurfaceVariant
            }
        }

        Item { Layout.preferredHeight: 12 }

        // Control row — InnerTune's symmetric [favorite · prev · PLAY · next · repeat].
        // (Shuffle lives in the queue header, like InnerTune.)
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: root.hp
            Layout.rightMargin: root.hp
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            // Favorite (dimmer until liked).
            ITIconButton {
                Layout.fillWidth: true
                symbol: "favorite"
                color: root.liked ? Appearance.colors.colError : Appearance.colors.colOnSurfaceVariant
                onClicked: root.liked ? YtMusic.unlikeSong(YtMusic.currentVideoId) : YtMusic.likeSong()
            }
            // Previous.
            ITIconButton {
                Layout.fillWidth: true
                symbol: "skip_previous"
                enabled: YtMusic.canGoPrevious
                onClicked: YtMusic.playPrevious()
            }
            Item { Layout.preferredWidth: 8 }
            // Play / pause (64dp squircle; animated roundness; spinner while buffering).
            Rectangle {
                Layout.preferredWidth: 64
                Layout.preferredHeight: 64
                radius: root.playPauseRoundness
                color: Appearance.colors.colSecondaryContainer
                Behavior on radius {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveFast.duration); easing.type: Easing.Linear }
                }
                // Press / hover state layer.
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Appearance.colors.colOnSurface
                    opacity: playMouse.pressed ? 0.14 : (playMouse.containsMouse ? 0.08 : 0)
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveFast.duration) }
                    }
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: !YtMusic.loading
                    text: YtMusic.isPlaying ? "pause" : "play_arrow"
                    iconSize: 36
                    color: Appearance.colors.colOnSurface
                }
                MaterialSymbol {
                    id: bufferGlyph
                    anchors.centerIn: parent
                    visible: YtMusic.loading
                    text: "progress_activity"
                    iconSize: 30
                    color: Appearance.colors.colOnSurface
                    RotationAnimator on rotation {
                        running: bufferGlyph.visible && Appearance.animationsEnabled
                        loops: Animation.Infinite
                        from: 0; to: 360; duration: 900
                    }
                }
                MouseArea {
                    id: playMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: YtMusic.togglePlaying()
                }
            }
            Item { Layout.preferredWidth: 8 }
            // Next.
            ITIconButton {
                Layout.fillWidth: true
                symbol: "skip_next"
                enabled: YtMusic.canGoNext
                onClicked: YtMusic.playNext()
            }
            // Repeat.
            ITIconButton {
                Layout.fillWidth: true
                symbol: YtMusic.repeatMode === 1 ? "repeat_one" : "repeat"
                color: Appearance.colors.colOnSurfaceVariant
                active: YtMusic.repeatMode > 0
                onClicked: YtMusic.cycleRepeatMode()
            }
        }
    }

    // ===== Top bar (shared): collapse chevron · lyrics · queue · more =====
    // Doubles as the drag handle to swipe the player down.
    RowLayout {
        id: topBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 8
        anchors.leftMargin: 8
        anchors.rightMargin: 8

        DragHandler {
            target: null
            xAxis.enabled: false
            yAxis.enabled: true
            onActiveChanged: {
                if (active) {
                    root.dragging = true;
                } else {
                    if (root.dragY > root.height * 0.25) root.collapseRequested();
                    root.dragging = false;
                    root.dragY = 0;
                }
            }
            onTranslationChanged: if (active) root.dragY = Math.max(0, translation.y)
        }

        RippleButton {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            buttonRadius: Appearance.rounding.full
            colBackground: "transparent"
            releaseAction: () => root.collapseRequested()
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "expand_more"
                iconSize: Appearance.font.pixelSize.huge
                color: Appearance.colors.colOnSurface
            }
        }
        Item { Layout.fillWidth: true }
        // Lyrics toggle.
        RippleButton {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            buttonRadius: Appearance.rounding.full
            colBackground: root._showLyricsPane ? Appearance.colors.colSecondaryContainer : "transparent"
            releaseAction: () => { root.showLyrics = !root.showLyrics; if (root.showLyrics) root.showQueue = false; }
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "lyrics"
                iconSize: Appearance.font.pixelSize.huge
                fill: root._showLyricsPane ? 1 : 0
                color: Appearance.colors.colOnSurface
            }
        }
        // Queue toggle.
        RippleButton {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            buttonRadius: Appearance.rounding.full
            colBackground: root._showQueuePane ? Appearance.colors.colSecondaryContainer : "transparent"
            releaseAction: () => { root.showQueue = !root.showQueue; if (root.showQueue) root.showLyrics = false; }
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "queue_music"
                iconSize: Appearance.font.pixelSize.huge
                fill: root._showQueuePane ? 1 : 0
                color: Appearance.colors.colOnSurface
            }
        }
        // More options (volume, go to album, radio, copy link).
        RippleButton {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            buttonRadius: Appearance.rounding.full
            colBackground: root.showMore ? Appearance.colors.colSecondaryContainer : "transparent"
            releaseAction: () => root.showMore = !root.showMore
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "more_vert"
                iconSize: Appearance.font.pixelSize.huge
                color: Appearance.colors.colOnSurface
            }
        }
    }

    // ===== Portrait body: art OR lyrics/queue stacked, meta+controls below =====
    ColumnLayout {
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        spacing: 0
        visible: !root.landscape

        // Flexible top spacer — only greedy in art mode, so {art · meta · controls} centers as
        // one cohesive block instead of the art floating alone with dead space below it.
        Item { Layout.fillWidth: true; Layout.fillHeight: !root._expandedView }

        // Center: album art (art mode, sized to content) OR full-area lyrics / queue.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: root._expandedView
            Layout.preferredHeight: root._expandedView ? 0 : artBox.height

            CoverArt {
                id: artBox
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                opacity: root._expandedView ? 0 : 1
                visible: opacity > 0
                Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveFast.duration) } }
                // Bound by width AND the vertical room left after header/meta/controls, so a tall
                // narrow sidebar can't push the cover up under the header icons.
                width: Math.min(parent.width - root.hp * 2, 460, Math.max(160, root.height - 300))
                height: width
            }

            SidePanel {
                anchors.fill: parent
                visible: root._expandedView
            }
        }

        Item { Layout.preferredHeight: 22 }

        MetaControls { Layout.fillWidth: true }

        // Flexible bottom spacer — balances the top one so the content block sits centered.
        Item { Layout.fillWidth: true; Layout.fillHeight: !root._expandedView }
    }

    // ===== Landscape body: art+controls on the left, lyrics/queue on the right =====
    RowLayout {
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 16
        visible: root.landscape

        // Left column: art centered with meta + controls beneath it.
        ColumnLayout {
            Layout.preferredWidth: Math.min(root.width * 0.46, 420)
            Layout.fillHeight: true
            spacing: 0

            Item { Layout.fillWidth: true; Layout.fillHeight: true
                CoverArt {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - root.hp, parent.height)
                    height: width
                }
            }
            Item { Layout.preferredHeight: 18 }
            MetaControls { Layout.fillWidth: true }
            Item { Layout.preferredHeight: 4 }
        }

        // Right pane: lyrics / queue, full height.
        SidePanel {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

    // ===== More-options bottom sheet (volume + utilities) =====
    // Dim backdrop — tap to dismiss.
    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colScrim
        opacity: root.showMore ? 0.45 : 0
        visible: opacity > 0
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveFast.duration) }
        }
        MouseArea { anchors.fill: parent; onClicked: root.showMore = false }
    }
    // Sheet grows up from the bottom edge.
    Rectangle {
        id: moreSheet
        anchors.left: parent.left
        anchors.right: parent.right
        height: moreCol.implicitHeight + 20
        y: root.showMore ? (parent.height - height) : parent.height
        topLeftRadius: Appearance.rounding.large
        topRightRadius: Appearance.rounding.large
        color: Appearance.colors.colSurfaceContainerHigh
        Behavior on y {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveEnter.duration)
                easing.type: Appearance.animation.elementMoveEnter.type
                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
            }
        }

        component MoreRow: RippleButton {
            id: moreRowRoot
            Layout.fillWidth: true
            implicitHeight: 42
            buttonRadius: Appearance.rounding.small
            colBackground: "transparent"
            property string rowIcon: ""
            property string rowLabel: ""
            contentItem: RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 16
                MaterialSymbol { text: moreRowRoot.rowIcon; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnSurface }
                StyledText { Layout.fillWidth: true; text: moreRowRoot.rowLabel; font.pixelSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colOnSurface }
            }
        }

        ColumnLayout {
            id: moreCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            spacing: 1

            // Grab handle.
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 6
                implicitWidth: 32; implicitHeight: 4; radius: 2
                color: Appearance.colors.colOutline
            }

            // Volume.
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                spacing: 12
                MaterialSymbol {
                    text: YtMusic.volume <= 0 ? "volume_off" : (YtMusic.volume < 0.5 ? "volume_down" : "volume_up")
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnSurfaceVariant
                }
                StyledSlider {
                    id: volSlider
                    Layout.fillWidth: true
                    from: 0; to: 1
                    // Track YtMusic.volume only when not dragging — otherwise the mpv round-trip
                    // fights the drag and the handle jumps. (Same pattern as the seek slider.)
                    property bool _dragging: false
                    value: volSlider._dragging ? volSlider.value : YtMusic.volume
                    stopIndicatorValues: []
                    onPressedChanged: { if (pressed) _dragging = true; else { YtMusic.setVolume(value); _dragging = false; } }
                    onMoved: YtMusic.setVolume(value)
                }
            }

            MoreRow {
                rowIcon: "album"
                rowLabel: Translation.tr("Go to album")
                visible: root._albumId !== ""
                releaseAction: () => { root.goToAlbumRequested(root._albumId); root.showMore = false; }
            }
            MoreRow {
                rowIcon: "radio"
                rowLabel: Translation.tr("Start radio")
                releaseAction: () => {
                    const base = root._curItem ?? { videoId: YtMusic.currentVideoId, title: YtMusic.currentTitle, artist: YtMusic.currentArtist, thumbnail: YtMusic.currentThumbnail };
                    YtMusic.play(Object.assign({}, base, { enableRelatedQueue: true }));
                    root.showMore = false;
                }
            }
            MoreRow {
                rowIcon: "link"
                rowLabel: Translation.tr("Copy link")
                releaseAction: () => { Quickshell.clipboardText = YtMusic.currentUrl || ("https://music.youtube.com/watch?v=" + YtMusic.currentVideoId); root.showMore = false; }
            }
        }
    }

    function _fmt(seconds) {
        if (!seconds || seconds <= 0) return "0:00";
        const s = Math.floor(seconds);
        const m = Math.floor(s / 60);
        const sec = s % 60;
        return m + ":" + (sec < 10 ? "0" + sec : "" + sec);
    }
}
