pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.shared.mediaControls.components
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.bar.island
import "../components"

// AIRISU's Now Playing (the Island's media page, on the engine's player, blocks and cover flight). The page is laid in
// the record's own lacquer when Settings lays the record under it (ArtBackdrop), and everything on it is cut out of that
// lacquer's inks: the record with its obi in the record's colour at full strength and the artist set up it, the title in
// the wide face, the time as the one large figure, the run of the song in the record's colour. Transport
// is three keys, the main one the accent's.
GridLayout {
    id: page
    property Item island: null
    readonly property real d: Airisu.d
    readonly property bool current: page.island?.effectivePage === "media"
    columns: 1
    rowSpacing: Math.round(16 * page.d)
    columnSpacing: 0

    readonly property var blocks: {
        const configured = Config.options?.iris?.bar?.mediaBlocks
        return Array.isArray(configured) ? configured : ["player", "timeline", "transport", "players", "levels"]
    }
    function rowOf(kind: string): int { return page.blocks.indexOf(kind) }
    readonly property var otherPlayers: (MprisController.displayPlayers ?? []).filter(p => p && p !== page.island?.player)
    readonly property var streams: {
        const groups = []
        for (const node of (Audio.outputAppNodes ?? [])) {
            if (!node?.audio) continue
            const name = Audio.appNodeDisplayName(node)
            const group = groups.find(g => g.name === name)
            if (group) group.nodes.push(node)
            else groups.push({ name: name, nodes: [node] })
        }
        return groups
    }
    // The lacquer the page is on and its inks.
    readonly property color pigment: Airisu.recordPigment(page.island?.artTint ?? IrisStyle.text)
    readonly property color panel: page.island?.artBehind ? Airisu.lacquerOf(page.pigment) : Airisu.ground
    readonly property color ink: page.island?.artBehind ? Airisu.inkOn(page.panel) : Airisu.ink
    readonly property color inkSecond: page.island?.artBehind ? Airisu.inkSecondOn(page.panel) : Airisu.inkSecond
    readonly property color inkThird: page.island?.artBehind ? Airisu.inkThirdOn(page.panel) : Airisu.inkThird
    readonly property color run: Airisu.vivid(page.pigment)
    readonly property string album: String(page.island?.player?.trackAlbum ?? "")

    PlayerBase {
        id: media
        player: page.island?.player ?? null
        positionUpdatesActive: page.current && (page.island?.visualExpanded ?? false)
    }

    onIslandChanged: if (page.island && !page.anime) page.island.pageCover = record.cover
    // An anime episode is the engine's page: its subtitle, sync and skip controls belong to that player alone.
    readonly property bool anime: AnimeWatch.ownsPlayer(page.island?.player ?? null)
    Loader {
        Layout.row: 0
        Layout.fillWidth: true
        Layout.preferredHeight: item?.implicitHeight ?? 0
        active: page.anime && page.island !== null
        visible: active
        sourceComponent: IslandMediaPage { width: page.width; island: page.island }
    }

    // The record: cover and obi, title and time.
    Item {
        Layout.row: Math.max(0, page.rowOf("player"))
        Layout.fillWidth: true
        visible: page.rowOf("player") >= 0 && !page.anime
        implicitHeight: record.height

        ARecord {
            id: record
            opacity: page.island?.coverFlightItem?.hides(record.cover) ? 0 : 1
            width: Math.round(page.width * 0.44)
            source: MediaArtwork.displaySource
            artist: media.effectiveArtist
            circular: Config.options?.iris?.player?.roundCover ?? false
            obi: page.run
            tone: page.inkThird
        }

        ColumnLayout {
            x: record.width + Math.round(20 * page.d)
            width: page.width - x
            height: record.height
            spacing: Math.round(4 * page.d)
            AText {
                Layout.fillWidth: true
                voice: "figure"
                size: IrisStyle.typeTitleLarge
                text: media.effectiveTitle
                color: page.ink
                wrapMode: Text.Wrap
                maximumLineCount: 3
                lineHeight: 0.96
            }
            AText {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(4 * page.d)
                size: IrisStyle.typeLabel
                font.weight: Font.Medium
                text: page.album
                color: page.inkSecond
                visible: text.length > 0 && text !== media.effectiveTitle
            }
            Item { Layout.fillHeight: true }
            // What is playing, lit: the engine's visualizer in the Settings' style and bar count, in the record's colour.
            IrisVisualizer {
                Layout.bottomMargin: Math.round(8 * page.d)
                running: media.effectiveIsPlaying && page.current && (page.island?.visualExpanded ?? false)
                visible: media.effectiveIsPlaying
                tint: page.run
                barHeight: Math.round(22 * page.d)
            }
            // A player that has not said how long the song is (a stream, a browser's first seconds) still has the time
            // it has played: the figure stays, only the total waits.
            Row {
                visible: media.effectiveLength > 0 || media.effectivePosition > 0
                spacing: Math.round(6 * page.d)
                AText {
                    id: position
                    voice: "figure"
                    lean: Airisu.lean
                    size: IrisStyle.typeDisplay
                    color: page.ink
                    text: page.island?.clockText(media.effectivePosition) ?? ""
                }
                AText {
                    visible: media.effectiveLength > 0
                    anchors.baseline: position.baseline
                    voice: "figure"
                    size: IrisStyle.typeLabel
                    text: "/ " + (page.island?.clockText(media.effectiveLength) ?? "")
                    color: page.inkSecond
                }
            }
        }
    }

    IrisScrubber {
        Layout.row: Math.max(0, page.rowOf("timeline"))
        Layout.fillWidth: true
        visible: page.rowOf("timeline") >= 0 && media.effectiveLength > 0 && !page.anime
        seekable: media.effectiveCanSeek
        value: media.effectiveLength > 0 ? media.effectivePosition / media.effectiveLength : 0
        live: media.effectiveIsPlaying
        fillColor: page.run
        onSeekRequested: next => media.seek(next * media.effectiveLength)
    }

    // Transport: back and forward are quiet keys on the page's lacquer; the main key is the accent's.
    Row {
        id: keys
        Layout.row: Math.max(0, page.rowOf("transport"))
        Layout.fillWidth: true
        visible: page.rowOf("transport") >= 0 && !page.anime
        spacing: Airisu.u(2)
        readonly property real side: Math.round((page.width - 2 * keys.spacing) / 4)
        readonly property real tall: Math.round(40 * page.d)
        IrisButton {
            id: previousKey
            quiet: true
            skinData: ({ under: page.panel })
            width: keys.side
            height: keys.tall
            enabled: media.effectiveCanGoPrevious
            Accessible.name: Translation.tr("Previous track")
            onClicked: media.previous()
            MaterialSymbol { anchors.centerIn: parent; text: "skip_previous"; fill: 1; iconSize: Math.round(22 * page.d); color: previousKey.enabled ? page.ink : page.inkThird }
        }
        IrisButton {
            id: playKey
            emphasized: true
            width: page.width - 2 * keys.side - 2 * keys.spacing
            height: keys.tall
            Accessible.name: media.effectiveIsPlaying ? Translation.tr("Pause") : Translation.tr("Play")
            onClicked: media.togglePlaying()
            MaterialSymbol { anchors.centerIn: parent; text: media.effectiveIsPlaying ? "pause" : "play_arrow"; fill: 1; iconSize: Math.round(24 * page.d); color: Airisu.inkOnSeal }
        }
        IrisButton {
            id: nextKey
            quiet: true
            skinData: ({ under: page.panel })
            width: keys.side
            height: keys.tall
            enabled: media.effectiveCanGoNext
            Accessible.name: Translation.tr("Next track")
            onClicked: media.next()
            MaterialSymbol { anchors.centerIn: parent; text: "skip_next"; fill: 1; iconSize: Math.round(22 * page.d); color: nextKey.enabled ? page.ink : page.inkThird }
        }
    }

    ColumnLayout {
        Layout.row: Math.max(0, page.rowOf("players"))
        Layout.fillWidth: true
        visible: page.rowOf("players") >= 0 && page.otherPlayers.length > 0 && !page.anime
        spacing: Math.round(10 * page.d)
        IrisPlayerChips {
            Layout.fillWidth: true
            player: page.island?.player ?? null
            accent: page.ink
        }
    }

    ColumnLayout {
        Layout.row: Math.max(0, page.rowOf("levels"))
        Layout.fillWidth: true
        visible: page.rowOf("levels") >= 0 && page.streams.length > 0 && !page.anime
        spacing: Math.round(8 * page.d)
        Repeater {
            model: page.streams.slice(0, 4)
            RowLayout {
                id: level
                required property var modelData
                readonly property var nodes: Array.from(level.modelData?.nodes ?? [])
                readonly property bool muted: level.nodes.every(node => node?.audio?.muted)
                property bool live: true
                Component.onDestruction: level.live = false
                Layout.fillWidth: true
                spacing: Math.round(10 * page.d)
                AText {
                    Layout.preferredWidth: Math.round(110 * page.d)
                    size: IrisStyle.typeMeta
                    text: level.nodes.length > 1 ? level.modelData.name + " · " + level.nodes.length : level.modelData.name
                    color: level.muted ? page.inkThird : page.ink
                }
                // A stream's volume is a setting's range: a run in the record's colour.
                IrisScrubber {
                    Layout.fillWidth: true
                    knob: true
                    fillColor: level.muted ? page.inkThird : page.run
                    Binding on value {
                        when: level.live
                        restoreMode: Binding.RestoreNone
                        value: Math.min(1, Math.max(0, ...level.nodes.map(node => Number(node?.audio?.volume) || 0)))
                    }
                    onMoved: next => level.nodes.forEach(node => { if (node?.audio) node.audio.volume = next })
                }
                IrisButton {
                    quiet: true
                    danger: level.muted
                    skinData: ({ under: page.panel })
                    implicitWidth: Math.round(30 * page.d)
                    implicitHeight: Math.round(26 * page.d)
                    Accessible.name: level.muted ? Translation.tr("Unmute") : Translation.tr("Mute")
                    onClicked: {
                        const mute = !level.muted
                        level.nodes.forEach(node => { if (node?.audio) node.audio.muted = mute })
                    }
                    MaterialSymbol { anchors.centerIn: parent; text: level.muted ? "volume_off" : "volume_up"; fill: 1; iconSize: Math.round(16 * page.d); color: level.muted ? Airisu.caution : page.inkSecond }
                }
            }
        }
    }
}
