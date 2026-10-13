pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import "../components"

// AIRISU's music widget: a card of music's lacquer whose second coat is the song, so the whole card is the timeline. The
// record wears its obi with the artist up it, the title is set in the figures' face beside it and the time is the one
// large figure; the three keys under it, the main one lacquered in the accent. Small, the card is the
// record alone with its key; large, the synced lyrics are the sleeve's notes, the line being sung set large.
// At rest (nothing playing, or paused long enough when Settings says so) it is the empty slot in the rack.
// Everything it reads and does is the engine's face (`face`: sizes, options, playback, lyrics, Lume's ink).
Item {
    id: root
    property var face
    readonly property var media: root.face?.playback ?? null
    readonly property real s: root.face?.widget?.scaleFactor ?? 1
    function dp(v: real): real { return root.face ? root.face.dp(v) : Math.round(v) }
    function type(token: real): int { return Math.round(token * root.s) }
    function clock(seconds: real): string {
        const t = Math.max(0, Math.floor(seconds))
        const h = Math.floor(t / 3600), m = Math.floor(t % 3600 / 60), sec = t % 60
        const ss = sec < 10 ? "0" + sec : String(sec)
        return h > 0 ? h + ":" + (m < 10 ? "0" + m : m) + ":" + ss : m + ":" + ss
    }

    readonly property bool small: root.face?.small ?? false
    readonly property bool large: root.face?.large ?? false
    readonly property bool resting: root.face?.resting ?? true
    readonly property bool hasPlayer: root.face?.hasPlayer ?? false
    readonly property bool playing: root.face?.playing ?? false
    readonly property real length: Number(root.media?.effectiveLength ?? 0)
    readonly property real position: Number(root.media?.effectivePosition ?? 0)
    readonly property string album: String(root.face?.player?.trackAlbum ?? "")
    readonly property string art: root.face?.art ?? ""
    // The inks are the lacquer's (or Lume's on the bare wall, for a transparent widget).
    readonly property color ink: stock.ink
    readonly property color inkSecond: stock.inkSecond
    readonly property color inkThird: stock.inkThird
    readonly property int pad: root.dp(14)

    // The card: music's lacquer, and the song's run as its second coat, the 45° edge crossing the whole
    // card as the song plays: the card is the timeline. It steps once a second; nothing animates for it.
    AStock {
        id: stock
        anchors.fill: parent
        face: root.face
        subject: "music"
        share: !root.resting && root.length > 0 ? Math.min(1, root.position / root.length) : 0
    }

    // The keys: back and forward are marks alone, the main key is the seal.
    component Keys: Row {
        id: keys
        property real tall: root.dp(34)
        spacing: Airisu.u(2) * root.s
        readonly property real side: Math.round((keys.width - 2 * keys.spacing) / 4)
        IrisButton {
            id: previousKey
            quiet: true
            width: keys.side
            height: keys.tall
            enabled: root.media?.effectiveCanGoPrevious ?? false
            Accessible.name: Translation.tr("Previous track")
            onClicked: root.media.previous()
            MaterialSymbol { anchors.centerIn: parent; text: "skip_previous"; fill: 1; iconSize: root.dp(20); color: previousKey.enabled ? root.ink : root.inkThird }
        }
        IrisButton {
            emphasized: true
            width: keys.width - 2 * keys.side - 2 * keys.spacing
            height: keys.tall
            Accessible.name: root.playing ? Translation.tr("Pause") : Translation.tr("Play")
            onClicked: root.media.togglePlaying()
            MaterialSymbol { anchors.centerIn: parent; text: root.playing ? "pause" : "play_arrow"; fill: 1; iconSize: root.dp(22); color: Airisu.inkOnSeal }
        }
        IrisButton {
            id: nextKey
            quiet: true
            width: keys.side
            height: keys.tall
            enabled: root.media?.effectiveCanGoNext ?? false
            Accessible.name: Translation.tr("Next track")
            onClicked: root.media.next()
            MaterialSymbol { anchors.centerIn: parent; text: "skip_next"; fill: 1; iconSize: root.dp(20); color: nextKey.enabled ? root.ink : root.inkThird }
        }
    }
    // The time: where the needle is as the one large figure, the length beside it in the third ink.
    component Time: Row {
        visible: root.length > 0
        spacing: root.dp(6)
        AText {
            id: here
            voice: "figure"
            size: root.type(root.large ? IrisStyle.typeDisplay : IrisStyle.typeTitleLarge)
            text: root.clock(root.position)
            color: root.ink
        }
        AText {
            anchors.baseline: here.baseline
            voice: "figure"
            size: root.type(IrisStyle.typeMeta)
            text: "/ " + root.clock(root.length)
            color: root.inkThird
        }
    }

    // At rest: the slot in the rack, the cover in it when a record is paused there; the seal resumes it.
    Item {
        anchors.fill: parent
        visible: root.resting
        readonly property real side: Math.round(Math.min(root.width, root.height) * (root.small ? 0.56 : 0.6))
        ARecord {
            id: slot
            width: parent.side
            height: width
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -Math.round(caption.height / 2)
            source: root.art
            artist: root.hasPlayer ? String(root.media?.effectiveArtist ?? "") : ""
            empty: !root.hasPlayer || root.art.length === 0
        }
        AText {
            id: caption
            anchors.top: slot.bottom
            anchors.topMargin: root.dp(8)
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, root.width - 2 * root.pad)
            size: root.type(IrisStyle.typeMeta)
            font.weight: Font.Bold
            text: root.hasPlayer ? String(root.media?.effectiveTitle ?? "") : Translation.tr("Nothing playing")
            color: root.hasPlayer ? root.ink : root.inkThird
        }
        IrisButton {
            visible: root.hasPlayer
            emphasized: true
            anchors.right: slot.right
            anchors.bottom: slot.bottom
            width: Math.round(slot.width * 0.32)
            height: width
            Accessible.name: Translation.tr("Play")
            onClicked: root.media.togglePlaying()
            MaterialSymbol { anchors.centerIn: parent; text: "play_arrow"; fill: 1; iconSize: Math.round(parent.width * 0.55); color: Airisu.inkOnSeal }
        }
    }

    // Small: the record alone, the card its sleeve, the live key the seal on its corner.
    Item {
        anchors.fill: parent
        anchors.margins: root.pad
        visible: !root.resting && root.small
        ARecord {
            id: single
            anchors.fill: parent
            source: root.art
            artist: String(root.media?.effectiveArtist ?? "")
            empty: root.art.length === 0
        }
        IrisButton {
            emphasized: true
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: Math.round(single.width * 0.3)
            height: width
            Accessible.name: root.playing ? Translation.tr("Pause") : Translation.tr("Play")
            onClicked: root.media.togglePlaying()
            MaterialSymbol { anchors.centerIn: parent; text: root.playing ? "pause" : "play_arrow"; fill: 1; iconSize: Math.round(parent.width * 0.5); color: Airisu.inkOnSeal }
        }
    }

    // Medium and large: the Island's page, cut to the card.
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.pad
        visible: !root.resting && !root.small
        spacing: root.dp(root.large ? 14 : 10)

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: !root.large
            spacing: root.dp(16)
            ARecord {
                id: record
                Layout.preferredWidth: root.large ? Math.round((root.width - 2 * root.pad) * 0.44)
                    : root.height - 2 * root.pad
                Layout.preferredHeight: Layout.preferredWidth
                Layout.alignment: Qt.AlignTop
                source: root.art
                artist: String(root.media?.effectiveArtist ?? "")
                empty: root.art.length === 0
                tone: stock.inkThird
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: record.Layout.preferredHeight
                Layout.alignment: Qt.AlignTop
                spacing: root.dp(3)
                AText {
                    Layout.fillWidth: true
                    voice: "figure"
                    size: root.type(root.large ? IrisStyle.typeTitleLarge : IrisStyle.typeTitle)
                    text: String(root.media?.effectiveTitle ?? "")
                    color: root.ink
                    wrapMode: Text.Wrap
                    maximumLineCount: root.large ? 3 : 2
                    lineHeight: 0.96
                }
                AText {
                    Layout.fillWidth: true
                    size: root.type(IrisStyle.typeMeta)
                    font.weight: Font.Medium
                    text: root.album
                    color: root.inkSecond
                    visible: text.length > 0 && text !== String(root.media?.effectiveTitle ?? "")
                }
                Item { Layout.fillHeight: true }
                Time { visible: root.length > 0 }
                Keys {
                    visible: !root.large
                    Layout.fillWidth: true
                    tall: root.dp(30)
                }
            }
        }

        // The sleeve's notes: the line being sung in the wide face, the one before struck through the third ink,
        // the next in the second. Offline, iRiS's own words say why there are none.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.large
            spacing: root.dp(4)
            Item { Layout.fillHeight: true }
            AText {
                Layout.fillWidth: true
                visible: (root.face?.lyricsWanted ?? false) && LyricsService.status === "offline"
                size: root.type(IrisStyle.typeMeta)
                text: Translation.tr("Lyrics need an internet connection")
                color: root.inkThird
            }
            AText {
                Layout.fillWidth: true
                visible: root.face?.lyricsReady ?? false
                size: root.type(IrisStyle.typeMeta)
                text: LyricsService.slots[2] ?? ""
                color: root.inkThird
            }
            AText {
                Layout.fillWidth: true
                visible: root.face?.lyricsReady ?? false
                voice: "figure"
                size: root.type(IrisStyle.typeTitle)
                text: LyricsService.slots[3] || "♪"
                color: root.ink
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }
            AText {
                Layout.fillWidth: true
                visible: root.face?.lyricsReady ?? false
                size: root.type(IrisStyle.typeMeta)
                text: LyricsService.slots[4] ?? ""
                color: root.inkSecond
            }
            Item { Layout.fillHeight: true }
        }

        IrisScrubber {
            Layout.fillWidth: true
            visible: root.large && root.length > 0
            seekable: root.media?.effectiveCanSeek ?? false
            value: root.length > 0 ? root.position / root.length : 0
            live: root.playing
            onSeekRequested: next => root.media.seek(next * root.length)
        }
        Keys {
            visible: root.large
            Layout.fillWidth: true
            tall: root.dp(38)
        }
    }
}
