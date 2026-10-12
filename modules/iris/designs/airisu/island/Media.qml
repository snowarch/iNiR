pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.mediaControls.components
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.bar.island
import "../components"

// AIRISU's Now Playing (the Island's media page, on the engine's player, blocks and cover flight). The record as it sits
// in a Japanese shop: the cover with its 帯 obi, the gofun paper band wrapped round its left edge, the artist set up it
// in sumi and the shop's vermilion stamp at its head; the title beside it in the wide face and the time as the one large
// figure. Transport is a strip of three keys, the live one in the seal.
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
    readonly property color obi: Airisu.gofun
    readonly property color obiInk: Airisu.inkOnGofun
    readonly property string album: String(page.island?.player?.trackAlbum ?? "")

    PlayerBase {
        id: media
        player: page.island?.player ?? null
        positionUpdatesActive: page.current && (page.island?.visualExpanded ?? false)
    }

    onIslandChanged: if (page.island && !page.anime) page.island.pageCover = cover
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

    // The record: cover, obi, title and time.
    Item {
        Layout.row: Math.max(0, page.rowOf("player"))
        Layout.fillWidth: true
        visible: page.rowOf("player") >= 0 && !page.anime
        implicitHeight: cover.height

        IrisArtwork {
            id: cover
            opacity: page.island?.coverFlightItem?.hides(cover) ? 0 : 1
            width: Math.round(page.width * 0.44)
            height: width
            source: MediaArtwork.displaySource
            circular: Config.options?.iris?.player?.roundCover ?? false
            radius: circular ? width / 2 : 0
        }
        // The obi: a paper band over the cover's left edge, the artist set up it, the stamp at its head.
        Rectangle {
            id: band
            width: Math.round(cover.width * 0.17)
            height: cover.height
            color: page.obi
            Rectangle {
                id: hanko
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(10 * page.d)
                width: Math.round(14 * page.d)
                height: width
                color: Airisu.seal
            }
            AText {
                // Rotated about its own centre to read bottom to top, laid in the band under the seal.
                readonly property real room: band.height - hanko.y - hanko.height - Math.round(20 * page.d)
                width: Math.min(implicitWidth, room)
                x: Math.round((band.width - width) / 2)
                y: Math.round(band.height - Math.round(10 * page.d) - room / 2 - height / 2 + (room - width) / 2)
                rotation: -90
                voice: "wide"
                size: IrisStyle.typeLabel
                font.capitalization: Font.AllUppercase
                font.letterSpacing: Math.round(IrisStyle.typeLabel * 0.06)
                text: media.effectiveArtist
                color: page.obiInk
            }
        }
        // A fold's shadow where the band leaves the cover.
        Rectangle {
            x: band.width
            width: Math.max(1, Math.round(page.d))
            height: cover.height
            color: IrisStyle.scrim
            opacity: 0.35
        }

        ColumnLayout {
            x: cover.width + Math.round(20 * page.d)
            width: page.width - x
            height: cover.height
            spacing: Math.round(4 * page.d)
            AText {
                Layout.fillWidth: true
                voice: "wide"
                size: IrisStyle.typeTitleLarge
                text: media.effectiveTitle
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
                color: Airisu.data
                visible: text.length > 0 && text !== media.effectiveTitle
            }
            Item { Layout.fillHeight: true }
            // What is playing, lit: the engine's visualizer in the Settings' style and bar count, in gofun.
            IrisVisualizer {
                Layout.bottomMargin: Math.round(8 * page.d)
                running: media.effectiveIsPlaying && page.current && (page.island?.visualExpanded ?? false)
                visible: media.effectiveIsPlaying
                tint: Airisu.gofun
                barHeight: Math.round(22 * page.d)
            }
            Row {
                visible: media.effectiveLength > 0
                spacing: Math.round(6 * page.d)
                AText {
                    voice: "wide"
                    size: IrisStyle.typeDisplay
                    text: page.island?.clockText(media.effectivePosition) ?? ""
                }
                AText {
                    anchors.baseline: parent.children[0].baseline
                    voice: "wide"
                    size: IrisStyle.typeLabel
                    text: "/ " + (page.island?.clockText(media.effectiveLength) ?? "")
                    color: Airisu.quiet
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
        fillColor: Airisu.gofun
        onSeekRequested: next => media.seek(next * media.effectiveLength)
    }

    // Three keys edge to edge: back, the live one, forward.
    Row {
        id: keys
        Layout.row: Math.max(0, page.rowOf("transport"))
        Layout.fillWidth: true
        visible: page.rowOf("transport") >= 0 && !page.anime
        spacing: Math.round(6 * page.d)
        readonly property real side: Math.round((page.width - 2 * keys.spacing) / 4)
        ASeal {
            kind: "line"
            glyph: "skip_previous"
            width: keys.side
            height: Math.round(40 * page.d)
            opacity: media.effectiveCanGoPrevious ? 1 : 0.4
            Accessible.name: Translation.tr("Previous track")
            onClicked: media.previous()
        }
        ASeal {
            kind: media.effectiveIsPlaying ? "seal" : "gofun"
            glyph: media.effectiveIsPlaying ? "pause" : "play_arrow"
            width: page.width - 2 * keys.side - 2 * keys.spacing
            height: Math.round(40 * page.d)
            Accessible.name: media.effectiveIsPlaying ? Translation.tr("Pause") : Translation.tr("Play")
            onClicked: media.togglePlaying()
        }
        ASeal {
            kind: "line"
            glyph: "skip_next"
            width: keys.side
            height: Math.round(40 * page.d)
            opacity: media.effectiveCanGoNext ? 1 : 0.4
            Accessible.name: Translation.tr("Next track")
            onClicked: media.next()
        }
    }

    ColumnLayout {
        Layout.row: Math.max(0, page.rowOf("players"))
        Layout.fillWidth: true
        visible: page.rowOf("players") >= 0 && page.otherPlayers.length > 0 && !page.anime
        spacing: Math.round(10 * page.d)
        Rectangle { Layout.fillWidth: true; implicitHeight: Airisu.line; color: Airisu.fillet }
        IrisPlayerChips {
            Layout.fillWidth: true
            player: page.island?.player ?? null
            accent: page.obi
        }
    }

    ColumnLayout {
        Layout.row: Math.max(0, page.rowOf("levels"))
        Layout.fillWidth: true
        visible: page.rowOf("levels") >= 0 && page.streams.length > 0 && !page.anime
        spacing: Math.round(8 * page.d)
        Rectangle { Layout.fillWidth: true; implicitHeight: Airisu.line; color: Airisu.fillet }
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
                    color: level.muted ? Airisu.quiet : Airisu.gofun
                }
                IrisScrubber {
                    Layout.fillWidth: true
                    fillColor: level.muted ? Airisu.quiet : Airisu.gofun
                    Binding on value {
                        when: level.live
                        restoreMode: Binding.RestoreNone
                        value: Math.min(1, Math.max(0, ...level.nodes.map(node => Number(node?.audio?.volume) || 0)))
                    }
                    onMoved: next => level.nodes.forEach(node => { if (node?.audio) node.audio.volume = next })
                }
                ASeal {
                    kind: level.muted ? "amber" : "line"
                    glyph: level.muted ? "volume_off" : "volume_up"
                    implicitWidth: Math.round(30 * page.d)
                    implicitHeight: Math.round(26 * page.d)
                    Accessible.name: level.muted ? Translation.tr("Unmute") : Translation.tr("Mute")
                    onClicked: {
                        const mute = !level.muted
                        level.nodes.forEach(node => { if (node?.audio) node.audio.muted = mute })
                    }
                }
            }
        }
    }
}
