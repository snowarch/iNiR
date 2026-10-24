pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.shared.mediaControls.components
import qs.modules.iris.style
import qs.modules.iris.components

IrisWidgetFace {
    id: root

    readonly property var player: MprisController.activePlayer
    // What a Design's face (`widgetNowPlaying`) reads: the engine's playback, positions and lyrics stay here.
    readonly property alias playback: media
    designFace: IrisDesign.skin("widgetNowPlaying")
    readonly property bool hasPlayer: root.player !== null && root.player !== undefined
    readonly property bool playing: root.hasPlayer && media.effectiveIsPlaying
    readonly property bool restsWhenPaused: Boolean(root.widget.irisOption("rest", true))
    readonly property bool resting: !root.hasPlayer || (root.restsWhenPaused && !root.playing && restDelay.elapsed)
    readonly property string art: root.hasPlayer ? media.displayedArtFilePath : ""
    readonly property color artLight: IrisStyle.vividHighlight(media.colorQuantizer?.colors?.[0] ?? root.accent, root.accent)
    readonly property real progress: media.effectiveLength > 0 ? Math.min(1, media.effectivePosition / media.effectiveLength) : 0
    readonly property bool lyricsWanted: root.large && root.live && root.hasPlayer
        && Boolean(root.widget.irisOption("lyrics", true))
    readonly property bool lyricsReady: root.lyricsWanted && LyricsService.status === "ok" && LyricsService.lyricsLines.length > 0
    // Large without lyrics wears the cover whole: beside the title it left a 180 px hole where the lines go.
    readonly property bool coverLarge: root.large && !root.resting && !root.lyricsReady && root.art.length > 0
    readonly property string source: {
        const identity = String(root.player?.identity || String(root.player?.desktopEntry ?? "").split(".").pop() || "")
        return identity.length > 0 ? identity.charAt(0).toUpperCase() + identity.slice(1) : Translation.tr("Music")
    }

    light: root.small || root.art.length === 0 ? "transparent"
        : root.artLight
    padding: (root.small && root.art.length > 0 && !root.resting) || root.coverLarge ? 0 : root.edgePad

    onLyricsWantedChanged: root.lyricsWanted ? LyricsService.subscribe(root) : LyricsService.unsubscribe(root)
    Component.onDestruction: if (root.lyricsWanted) LyricsService.unsubscribe(root)

    Timer {
        id: restDelay
        property bool elapsed: false
        interval: 30000
        running: root.hasPlayer && !root.playing
        onRunningChanged: if (running) elapsed = false
        onTriggered: elapsed = true
    }

    PlayerBase {
        id: media
        player: root.player
        positionUpdatesActive: root.moving && root.playing && !root.small
    }

    component Transport: RowLayout {
        id: transport
        property real disc: root.dp(34)
        property bool overMedia: false
        spacing: root.dp(6)
        FaceAction {
            face: root
            implicitWidth: transport.disc
            tint: transport.overMedia ? IrisStyle.onMedia : root.ink
            color: transport.overMedia ? IrisStyle.onMediaFill : root.fill
            glyph: "skip_previous"
            name: Translation.tr("Previous")
            enabled: media.effectiveCanGoPrevious
            opacity: enabled ? 1 : 0.4
            onActivated: media.previous()
        }
        FaceAction {
            face: root
            implicitWidth: Math.round(transport.disc * 1.2)
            glyph: root.playing ? "pause" : "play_arrow"
            name: root.playing ? Translation.tr("Pause") : Translation.tr("Play")
            tint: root.playing ? root.onFill(root.accent) : transport.overMedia ? IrisStyle.onMedia : root.ink
            color: root.playing ? root.accent : transport.overMedia ? IrisStyle.onMediaFill : root.fill
            onActivated: media.togglePlaying()
        }
        FaceAction {
            face: root
            implicitWidth: transport.disc
            tint: transport.overMedia ? IrisStyle.onMedia : root.ink
            color: transport.overMedia ? IrisStyle.onMediaFill : root.fill
            glyph: "skip_next"
            name: Translation.tr("Next")
            enabled: media.effectiveCanGoNext
            opacity: enabled ? 1 : 0.4
            onActivated: media.next()
        }
    }

    component Progress: Rectangle {
        id: progressBar
        property bool overMedia: false
        implicitHeight: root.dp(4)
        radius: IrisStyle.capsule(height)
        color: progressBar.overMedia ? IrisStyle.onMediaFill : root.fill
        Rectangle {
            width: parent.width * root.progress
            height: parent.height
            radius: IrisStyle.capsule(height)
            color: progressBar.overMedia ? IrisStyle.onMedia : root.ink
        }
    }

    // The keys sit on the timeline's centre, the times pinned to its ends: fillers between two times of
    // different widths pushed the transport off by half their difference. Where the times would touch the keys
    // (a medium face's column) they take their own line under the timeline, as Apple's player does.
    component KeysRow: Item {
        id: keysRow
        property bool overMedia: false
        property real disc: root.dp(36)
        readonly property bool timed: media.effectiveLength > 0
        readonly property bool beside: keysRow.width >= keys.implicitWidth
            + 2 * (Math.max(elapsed.implicitWidth, total.implicitWidth) + root.dp(12))
        readonly property real timesH: keysRow.timed && !keysRow.beside ? Math.ceil(elapsed.implicitHeight) + root.dp(2) : 0
        implicitHeight: keysRow.timesH + keys.implicitHeight
        FaceText {
            id: elapsed
            face: root
            visible: keysRow.timed
            y: keysRow.beside ? Math.round(keys.y + (keys.height - height) / 2) : 0
            text: StringUtils.friendlyTimeForSeconds(media.effectivePosition)
            color: keysRow.overMedia ? IrisStyle.onMediaSecondary : root.inkTertiary
            font.family: root.fontNumbers
            font.features: ({ "tnum": 1 })
            size: 11
        }
        Transport {
            id: keys
            x: Math.round((keysRow.width - width) / 2)
            y: keysRow.timesH
            disc: keysRow.disc
            overMedia: keysRow.overMedia
        }
        FaceText {
            id: total
            face: root
            visible: keysRow.timed
            x: keysRow.width - width
            y: elapsed.y
            text: StringUtils.friendlyTimeForSeconds(media.effectiveLength)
            color: keysRow.overMedia ? IrisStyle.onMediaSecondary : root.inkTertiary
            font.family: root.fontNumbers
            font.features: ({ "tnum": 1 })
            size: 11
        }
    }

    // What plays is kept (state dir), so at rest the face shows the song that played last, as Apple's shows what you
    // played, instead of a record on an empty platter (7517f1c6): a picture of a record told nothing a glyph didn't.
    readonly property string playedKey: root.playing && media.effectiveTitle.length > 0
        ? [media.effectiveTitle, media.effectiveArtist, root.art, root.source].join("\u0001") : ""
    onPlayedKeyChanged: if (root.playedKey.length > 0) root.remember()
    onPlayingChanged: if (!root.playing && Persistent.states.lastPlayed.title === media.effectiveTitle) Persistent.states.lastPlayed.at = Date.now()
    function remember(): void {
        const last = Persistent.states.lastPlayed
        last.title = media.effectiveTitle
        last.artist = media.effectiveArtist
        last.source = root.source
        last.art = root.art
        last.at = Date.now()
    }
    function ago(at: real): string {
        const minutes = Math.round((DateTime.clock.date.getTime() - at) / 60000)
        return minutes < 1 ? Translation.tr("Now") : minutes < 60 ? Translation.tr("%1 min ago").arg(minutes)
            : minutes < 1440 ? Translation.tr("%1 h ago").arg(Math.round(minutes / 60))
            : Translation.tr("%1 days ago").arg(Math.round(minutes / 1440))
    }

    component Cover: Item {
        IrisArtwork {
            anchors.fill: parent
            visible: rest.cover
            source: rest.coverArt
            circular: false
            radius: Math.max(root.dp(6), Math.round(width * 0.14))
        }
        Rectangle {
            anchors.fill: parent
            visible: !rest.cover
            radius: Math.max(root.dp(6), Math.round(width * 0.14))
            color: IrisStyle.tintFill(root.inked(IrisStyle.identity.pink))
            MaterialSymbol {
                anchors.centerIn: parent
                text: "music_note"
                fill: 1
                iconSize: Math.round(parent.width * 0.42)
                color: root.inked(IrisStyle.identity.pink)
            }
        }
    }

    Item {
        id: rest
        anchors.fill: parent
        visible: root.resting
        readonly property bool paused: root.hasPlayer
        readonly property var last: Persistent.states.lastPlayed
        readonly property bool remembered: !rest.paused && String(rest.last.title ?? "").length > 0
        readonly property bool known: rest.paused || rest.remembered
        readonly property string coverArt: rest.paused ? root.art : rest.remembered ? String(rest.last.art ?? "") : ""
        readonly property bool cover: rest.coverArt.length > 0
        readonly property string title: rest.paused ? (media.effectiveTitle || root.source) : String(rest.last.title ?? "")
        // the artist only: with none, the source already heads the face ("Mozilla firefox" said twice)
        readonly property string detail: rest.paused ? media.effectiveArtist : String(rest.last.artist ?? "")
        readonly property string head: rest.paused ? root.source : rest.remembered ? Translation.tr("Last played") : Translation.tr("Music")
        readonly property string when: rest.remembered ? [String(rest.last.source ?? ""), root.ago(rest.last.at)].filter(part => part.length > 0).join(" · ") : ""

        // Nothing ever played here: the family's empty state, under the head on a large face.
        FaceHeader {
            id: restBlankHead
            face: root
            visible: !rest.known && root.large
            width: parent.width
            glyph: "music_note"
            text: Translation.tr("Music")
            tint: root.inked(IrisStyle.identity.pink)
        }
        FaceBlank {
            visible: !rest.known
            face: root
            width: parent.width
            y: root.large ? restBlankHead.height + root.dp(24) : Math.round((parent.height - height) / 2)
            glyph: "music_note"
            glyphFill: true
            tint: root.inked(IrisStyle.identity.pink)
            title: Translation.tr("Not playing")
            detail: Translation.tr("Play something and it shows here")
        }

        // Small: the cover, its song under it.
        Item {
            anchors.fill: parent
            visible: rest.known && root.small
            Cover {
                id: restSmallCover
                width: Math.min(parent.width, parent.height - restSmallTitle.height - root.dp(8))
                height: width
                x: Math.round((parent.width - width) / 2)
            }
            FaceText {
                id: restSmallTitle
                face: root
                y: parent.height - height
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: rest.title
                color: rest.paused ? root.ink : root.inkSecondary
                size: 12.5
                weight: Font.DemiBold
            }
        }

        // Medium: the cover and what it is, the play key when something waits.
        Item {
            anchors.fill: parent
            visible: rest.known && root.medium
            Cover {
                id: restMediumCover
                width: parent.height
                height: width
            }
            Column {
                x: restMediumCover.width + root.dp(14)
                width: parent.width - x
                height: parent.height
                FaceHeader {
                    face: root
                    width: parent.width
                    glyph: "music_note"
                    text: rest.head
                    tint: root.inked(IrisStyle.identity.pink)
                }
            }
            Column {
                id: restMediumSong
                x: restMediumCover.width + root.dp(14)
                y: parent.height - height
                width: parent.width - x
                FaceText {
                    face: root
                    width: parent.width
                    text: rest.title
                    size: 15
                    weight: Font.DemiBold
                }
                FaceText {
                    face: root
                    visible: text.length > 0
                    width: parent.width
                    text: rest.detail
                    color: root.inkSecondary
                    size: 12.5
                }
                FaceText {
                    face: root
                    visible: rest.when.length > 0
                    width: parent.width
                    text: rest.when
                    color: root.inkTertiary
                    size: 11.5
                }
                Item { visible: rest.paused; width: 1; height: root.dp(8) }
                Transport {
                    visible: rest.paused
                    anchors.horizontalCenter: parent.horizontalCenter
                    disc: root.dp(30)
                }
            }
        }

        // Large: the cover leads, the song under it.
        Item {
            anchors.fill: parent
            visible: rest.known && root.large
            FaceHeader {
                id: restLargeHead
                face: root
                width: parent.width
                glyph: "music_note"
                text: rest.head
                tint: root.inked(IrisStyle.identity.pink)
            }
            Cover {
                y: restLargeHead.height + root.dp(10)
                width: Math.min(parent.width, restLargeSong.y - y - root.dp(14))
                height: width
                x: Math.round((parent.width - width) / 2)
            }
            Column {
                id: restLargeSong
                y: parent.height - height
                width: parent.width
                spacing: root.dp(1)
                FaceText {
                    face: root
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: rest.title
                    size: 15
                    weight: Font.DemiBold
                }
                FaceText {
                    face: root
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: text.length > 0
                    text: [rest.detail, rest.when].filter(part => part.length > 0).join(" · ")
                    color: root.inkSecondary
                    size: 12.5
                }
                Item { visible: rest.paused; width: 1; height: root.dp(6) }
                Transport {
                    visible: rest.paused
                    anchors.horizontalCenter: parent.horizontalCenter
                    disc: root.dp(32)
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: !root.resting && root.small

        ClippingRectangle {
            anchors.fill: parent
            visible: root.art.length > 0
            radius: root.radius
            color: "transparent"
            IrisImage {
                anchors.fill: parent
                source: root.art
            }
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height * 0.62
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: IrisStyle.veilStrong }
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.art.length > 0 ? root.dp(14) : 0
            spacing: root.dp(1)
            IrisArtwork {
                visible: root.art.length === 0
                circular: false
                radius: root.innerRadius
                Layout.preferredWidth: root.dp(56)
                Layout.preferredHeight: root.dp(56)
            }
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.fillHeight: false
                Layout.fillWidth: true
                spacing: root.dp(8)
                ColumnLayout {
                    Layout.fillHeight: false
                    Layout.fillWidth: true
                    spacing: 0
                    FaceText {
                        face: root
                        Layout.fillWidth: true
                        text: media.effectiveTitle
                        color: IrisStyle.onMedia
                        size: 13
                        weight: Font.DemiBold
                    }
                    FaceText {
                        face: root
                        Layout.fillWidth: true
                        text: media.effectiveArtist
                        color: IrisStyle.onMediaSecondary
                        size: 11.5
                    }
                }
                FaceAction {
                    face: root
                    implicitWidth: root.dp(34)
                    glyph: root.playing ? "pause" : "play_arrow"
                    name: root.playing ? Translation.tr("Pause") : Translation.tr("Play")
                    tint: IrisStyle.onMedia
                    color: IrisStyle.onMediaFill
                    onActivated: media.togglePlaying()
                }
            }
        }
    }

    // Medium: the cover is the play key (it settles back while paused), the song, and the lane with its times at
    // the ends and the keys on its centre.
    RowLayout {
        anchors.fill: parent
        visible: !root.resting && root.medium
        spacing: root.dp(14)

        Item {
            Layout.preferredWidth: root.height - root.padding * 2
            Layout.preferredHeight: Layout.preferredWidth
            IrisArtwork {
                id: mediumCover
                anchors.fill: parent
                source: root.art
                circular: false
                radius: root.innerRadius
                scale: coverTap.pressed ? 0.9 : root.playing ? 1 : 0.94
                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { id: coverTap; onTapped: media.togglePlaying() }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.dp(2)

            FaceText {
                face: root
                Layout.fillWidth: true
                text: root.source
                color: root.inkTertiary
                size: 11
                weight: Font.DemiBold
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                text: media.effectiveTitle
                size: 15
                weight: Font.DemiBold
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                text: media.effectiveArtist
                color: root.inkSecondary
                size: 12.5
            }
            Item { Layout.fillHeight: true }
            Progress {
                Layout.fillWidth: true
                visible: media.effectiveLength > 0
            }
            KeysRow {
                Layout.fillWidth: true
                Layout.topMargin: root.dp(4)
                disc: root.dp(30)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        visible: !root.resting && root.large && !root.coverLarge
        spacing: root.dp(12)

        RowLayout {
            Layout.fillHeight: false
            Layout.fillWidth: true
            spacing: root.dp(14)
            IrisArtwork {
                source: root.art
                circular: false
                radius: root.innerRadius
                Layout.preferredWidth: root.dp(root.lyricsReady ? 112 : 148)
                Layout.preferredHeight: Layout.preferredWidth
            }
            ColumnLayout {
                Layout.fillHeight: false
                Layout.fillWidth: true
                spacing: root.dp(2)
                FaceText {
                    face: root
                    Layout.fillWidth: true
                    text: root.source
                    color: root.inkTertiary
                    size: 11
                    weight: Font.DemiBold
                }
                FaceText {
                    face: root
                    Layout.fillWidth: true
                    text: IrisFaceData.unwidowed(media.effectiveTitle)
                    size: 17
                    weight: Font.DemiBold
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                }
                FaceText {
                    face: root
                    Layout.fillWidth: true
                    text: media.effectiveArtist
                    color: root.inkSecondary
                    size: 13
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.dp(4)

            Item { Layout.fillHeight: true }
            FaceText {
                face: root
                Layout.fillWidth: true
                visible: root.lyricsReady
                text: LyricsService.slots[2] ?? ""
                color: root.inkTertiary
                size: 12.5
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                text: IrisFaceData.unwidowed(LyricsService.slots[3] || "♪")
                visible: root.lyricsReady
                size: 16
                weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                visible: root.lyricsReady
                text: LyricsService.slots[4] ?? ""
                color: root.inkTertiary
                size: 12.5
            }
            Item { Layout.fillHeight: true }
        }

        Progress {
            Layout.fillWidth: true
            visible: media.effectiveLength > 0
        }
        KeysRow {
            Layout.fillWidth: true
        }
    }

    Item {
        anchors.fill: parent
        visible: root.coverLarge

        ClippingRectangle {
            anchors.fill: parent
            radius: root.radius
            color: "transparent"
            IrisImage {
                anchors.fill: parent
                source: root.art
            }
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height * 0.6
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: IrisStyle.veilStrong }
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.edgePad
            spacing: root.dp(2)

            Item { Layout.fillHeight: true }
            FaceText {
                face: root
                Layout.fillWidth: true
                text: root.source
                color: IrisStyle.onMediaSecondary
                size: 11
                weight: Font.DemiBold
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                text: IrisFaceData.unwidowed(media.effectiveTitle)
                color: IrisStyle.onMedia
                size: 19
                weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                text: media.effectiveArtist
                color: IrisStyle.onMediaSecondary
                size: 13
            }
            Progress {
                Layout.fillWidth: true
                Layout.topMargin: root.dp(12)
                overMedia: true
                visible: media.effectiveLength > 0
            }
            KeysRow {
                Layout.fillWidth: true
                Layout.topMargin: root.dp(8)
                overMedia: true
            }
        }
    }
}
