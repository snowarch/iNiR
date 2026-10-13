pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.pieces
import "../components"

// AIRISU's player card (the lock, the media bubble's card, the sidebar): the record as the Island's Now Playing sets it,
// cut down to a card, on a panel of music's lacquer (over a picture, the lock's plate instead, in the media inks).
// The cover wears its obi (帯), music's pigment at full strength round its left edge with the artist up it; beside it
// the title in the wide face, the album under it, and the time leaning at the foot. Under the record the song's run and
// three keys, the main one the accent's. Folded (the sidebar's collapsed card), it is the cover, the artist over the
// title, a thin run and the keys. A round cover is a disc and carries no obi. Nothing playing, it is the card's offer.
Item {
    id: root
    property var host
    readonly property var media: root.host?.playback ?? null
    readonly property bool hasPlayer: root.host?.hasPlayer ?? false
    readonly property bool compact: root.host?.compact ?? false
    readonly property bool overMedia: root.host?.overMedia ?? false
    readonly property real d: Airisu.d

    // The panel and its inks: music's lacquer and the inks cut out of it; over a picture, the media inks.
    readonly property color panel: Airisu.lacquerOf(Airisu.pigment("music"))
    readonly property color under: root.overMedia ? "transparent" : root.panel
    readonly property color ink: root.overMedia ? IrisStyle.onMedia : Airisu.inkOn(root.panel)
    readonly property color inkSecond: root.overMedia ? IrisStyle.onMediaSecondary : Airisu.inkSecondOn(root.panel)
    readonly property color inkThird: root.overMedia ? IrisStyle.onMediaTertiary : Airisu.inkThirdOn(root.panel)
    readonly property color run: root.overMedia ? IrisStyle.onMedia : Airisu.vivid(Airisu.pigment("music"))
    readonly property color obi: root.overMedia ? IrisStyle.onMedia : Airisu.vivid(Airisu.pigment("music"))
    readonly property color obiInk: root.overMedia ? IrisStyle.onTintFor(IrisStyle.onMedia) : Airisu.inkOn(root.obi)

    readonly property string title: root.hasPlayer ? String(root.media?.effectiveTitle ?? "") : Translation.tr("Nothing playing")
    readonly property string artist: root.hasPlayer ? String(root.media?.effectiveArtist ?? "") : ""
    readonly property string album: root.hasPlayer ? String(root.host?.player?.trackAlbum ?? "") : ""
    readonly property real length: Number(root.media?.effectiveLength ?? 0)
    readonly property real position: Number(root.media?.effectivePosition ?? 0)
    readonly property bool playing: root.media?.effectiveIsPlaying ?? false
    readonly property bool failed: !root.hasPlayer && IrisPieces.musicLaunch === "failed" && (root.host?.offersOpen ?? false)
    readonly property bool round: Config.options?.iris?.player?.roundCover ?? false

    readonly property int pad: Airisu.u(4)
    implicitHeight: root.compact ? folded.implicitHeight + 2 * Airisu.u(3) : record.implicitHeight + 2 * root.pad

    function clock(seconds: real): string { return StringUtils.friendlyTimeForSeconds(seconds) }

    ALacquer {
        visible: !root.overMedia
        anchors.fill: parent
        anchors.margins: Airisu.kiss
        cut: Math.max(2, Airisu.chamfer - Airisu.kiss)
        lacquer: root.panel
    }

    // The cover with its obi.
    component Cover: Item {
        id: cover
        property bool obiShown: true
        IrisArtwork {
            id: art
            anchors.fill: parent
            source: root.media?.displayedArtFilePath ?? ""
            appIcon: root.host?.emptyIcon ?? ""
            circular: root.round
            radius: circular ? width / 2 : 0
        }
        Rectangle {
            id: band
            visible: cover.obiShown && !root.round && root.hasPlayer
            width: Math.max(Airisu.u(3), Math.round(cover.width * 0.17))
            height: cover.height
            color: root.obi
            AText {
                // Up the band, bottom to top.
                readonly property real room: band.height - 2 * Math.round(band.width * 0.3)
                width: Math.min(implicitWidth, room)
                x: Math.round((band.width - width) / 2)
                y: Math.round(band.height - Math.round(band.width * 0.3) - room / 2 - height / 2 + (room - width) / 2)
                rotation: -90
                size: Math.max(IrisStyle.typeCaption, Math.round(band.width * 0.62))
                font.weight: Font.Bold
                renderType: Text.CurveRendering
                text: root.artist
                color: root.obiInk
            }
        }
        // An empty slot is sunk into the panel, the offer's mark (the engine's artwork) in it.
        ALacquer {
            anchors.fill: parent
            visible: !root.hasPlayer && (root.host?.emptyIcon ?? "") === ""
            lacquer: Airisu.slot
            moving: false
        }
    }

    // The keys: back and forward quiet keys on the panel, the main key the accent's.
    component Keys: Row {
        id: keys
        property real tall: Airisu.u(9)
        property real side: Airisu.u(9)
        property real main: Airisu.u(9)
        spacing: Airisu.u(1)
        IrisButton {
            id: previousKey
            quiet: true
            skinData: ({ under: root.under.a > 0 ? root.under : Airisu.ground })
            width: keys.side
            height: keys.tall
            enabled: root.media?.effectiveCanGoPrevious ?? false
            Accessible.name: Translation.tr("Previous track")
            onClicked: root.media.previous()
            MaterialSymbol { anchors.centerIn: parent; text: "skip_previous"; fill: 1; iconSize: Math.round(20 * root.d); color: previousKey.enabled ? root.ink : root.inkThird }
        }
        IrisButton {
            id: playKey
            emphasized: true
            width: keys.main
            height: keys.tall
            Accessible.name: root.playing ? Translation.tr("Pause") : Translation.tr("Play")
            onClicked: root.media.togglePlaying()
            MaterialSymbol { anchors.centerIn: parent; text: root.playing ? "pause" : "play_arrow"; fill: 1; iconSize: Math.round(22 * root.d); color: Airisu.inkOnSeal }
        }
        IrisButton {
            id: nextKey
            quiet: true
            skinData: ({ under: root.under.a > 0 ? root.under : Airisu.ground })
            width: keys.side
            height: keys.tall
            enabled: root.media?.effectiveCanGoNext ?? false
            Accessible.name: Translation.tr("Next track")
            onClicked: root.media.next()
            MaterialSymbol { anchors.centerIn: parent; text: "skip_next"; fill: 1; iconSize: Math.round(20 * root.d); color: nextKey.enabled ? root.ink : root.inkThird }
        }
    }

    // ── The record.
    ColumnLayout {
        id: record
        visible: !root.compact
        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        spacing: Airisu.u(3)

        Item {
            Layout.fillWidth: true
            implicitHeight: sleeve.height
            Cover {
                id: sleeve
                width: Airisu.u(24)
                height: width
            }
            ColumnLayout {
                x: sleeve.width + Airisu.u(4)
                width: parent.width - x - (root.host?.headerReserve ?? 0)
                height: sleeve.height
                spacing: Airisu.u(1)
                AText {
                    Layout.fillWidth: true
                    voice: root.hasPlayer ? "figure" : "text"
                    size: root.hasPlayer ? IrisStyle.typeTitle : IrisStyle.typeBody
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    lineHeight: 0.96
                    color: root.ink
                    text: root.title
                }
                AText {
                    Layout.fillWidth: true
                    // The album under the title; with nothing playing, the card's offer (or why it failed).
                    visible: text.length > 0 && text !== root.title
                    size: IrisStyle.typeMeta
                    font.weight: Font.Medium
                    color: root.failed ? (root.overMedia ? IrisStyle.dangerOnMedia : Airisu.caution) : root.inkSecond
                    text: root.hasPlayer ? root.album : (root.host?.emptyDetail ?? "")
                }
                Item { Layout.fillHeight: true }
                // The time, the one figure: where it is, over how long it runs.
                Row {
                    visible: root.host?.hasTimeline ?? false
                    spacing: Airisu.u(1)
                    AText {
                        id: at
                        voice: "figure"
                        size: IrisStyle.typeTitle
                        color: root.ink
                        text: root.clock(root.position)
                    }
                    AText {
                        anchors.baseline: at.baseline
                        voice: "figure"
                        size: IrisStyle.typeMeta
                        font.weight: Font.Bold
                        color: root.inkThird
                        text: "/ " + root.clock(root.length)
                    }
                }
                // A stream has no end to count to: it says so, with its lamp lit while it plays (in ink: the card's
                // seal is its main key).
                Row {
                    visible: root.hasPlayer && (root.host?.liveStream ?? false)
                    spacing: Airisu.u(1.5)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Airisu.u(2)
                        height: width
                        radius: width / 2
                        color: root.playing ? root.ink : "transparent"
                        border.width: root.playing ? 0 : Airisu.hair
                        border.color: root.inkSecond
                    }
                    AText {
                        anchors.verticalCenter: parent.verticalCenter
                        size: IrisStyle.typeMeta
                        font.weight: Font.Bold
                        color: root.ink
                        text: Translation.tr("Live")
                    }
                    AText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.position > 0
                        voice: "figure"
                        size: IrisStyle.typeMeta
                        color: root.inkThird
                        text: root.clock(root.position)
                    }
                }
            }
        }

        IrisScrubber {
            Layout.fillWidth: true
            visible: root.host?.hasTimeline ?? false
            seekable: root.media?.effectiveCanSeek ?? false
            live: root.playing
            fillColor: root.run
            value: root.length > 0 ? Math.min(1, root.position / root.length) : 0
            onSeekRequested: next => root.media.seek(next * root.length)
        }

        Keys {
            Layout.fillWidth: true
            visible: root.hasPlayer
            side: Math.round((record.width - 2 * spacing) / 4)
            main: record.width - 2 * side - 2 * spacing
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: (root.host?.showPlayers ?? true) && chips.players.length > 0
            spacing: Airisu.u(2)
            IrisPlayerChips {
                id: chips
                Layout.fillWidth: true
                player: root.host?.player ?? null
                accent: root.ink
                overMedia: root.overMedia
            }
        }
    }

    // ── Folded: the shelf label.
    RowLayout {
        id: folded
        visible: root.compact
        x: Airisu.u(3)
        width: root.width - 2 * Airisu.u(3)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Airisu.u(3)
        Cover {
            Layout.preferredWidth: Airisu.u(12)
            Layout.preferredHeight: Airisu.u(12)
            obiShown: false
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            AText {
                Layout.fillWidth: true
                visible: text.length > 0
                size: IrisStyle.typeFootnote
                font.weight: Font.Bold
                color: root.inkSecond
                text: root.hasPlayer ? root.artist : (root.host?.emptyDetail ?? "")
            }
            AText {
                Layout.fillWidth: true
                size: IrisStyle.typeBody
                font.weight: Font.Bold
                color: root.ink
                text: root.title
            }
            // The song's run, thin.
            ARun {
                Layout.fillWidth: true
                Layout.topMargin: Airisu.u(1.5)
                visible: root.host?.hasTimeline ?? false
                implicitHeight: Math.max(3, Math.round(4 * root.d))
                value: root.length > 0 ? Math.min(1, root.position / root.length) : 0
                pigment: root.run
                travel: 0
            }
        }
        Keys {
            visible: root.hasPlayer
            tall: Airisu.u(8)
            side: Airisu.u(7)
            main: Airisu.u(8)
        }
    }
}
