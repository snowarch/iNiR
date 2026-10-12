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
    readonly property color obi: Airisu.ink
    readonly property color obiInk: Airisu.reverse
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
                voice: "text"
                size: IrisStyle.typeLabel
                font.weight: Font.Bold
                text: media.effectiveArtist
                color: page.obiInk
            }
        }
        // The fold where the band leaves the cover: a rule, not a shadow.
        Rectangle {
            x: band.width
            width: Airisu.hair
            height: cover.height
            color: Airisu.rule
        }

        ColumnLayout {
            x: cover.width + Math.round(20 * page.d)
            width: page.width - x
            height: cover.height
            spacing: Math.round(4 * page.d)
            AText {
                Layout.fillWidth: true
                voice: "figure"
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
                color: Airisu.inkSecond
                visible: text.length > 0 && text !== media.effectiveTitle
            }
            Item { Layout.fillHeight: true }
            // What is playing, lit: the engine's visualizer in the Settings' style and bar count, in gofun.
            IrisVisualizer {
                Layout.bottomMargin: Math.round(8 * page.d)
                running: media.effectiveIsPlaying && page.current && (page.island?.visualExpanded ?? false)
                visible: media.effectiveIsPlaying
                tint: Airisu.ink
                barHeight: Math.round(22 * page.d)
            }
            Row {
                visible: media.effectiveLength > 0
                spacing: Math.round(6 * page.d)
                AText {
                    id: position
                    voice: "figure"
                    size: IrisStyle.typeDisplay
                    text: page.island?.clockText(media.effectivePosition) ?? ""
                }
                AText {
                    anchors.baseline: position.baseline
                    voice: "figure"
                    size: IrisStyle.typeLabel
                    text: "/ " + (page.island?.clockText(media.effectiveLength) ?? "")
                    color: Airisu.inkThird
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
        onSeekRequested: next => media.seek(next * media.effectiveLength)
    }

    // Transport: back and forward are marks alone; the main key is the seal (SYSTEM.md §7: the player's main action).
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
            width: keys.side
            height: keys.tall
            enabled: media.effectiveCanGoPrevious
            Accessible.name: Translation.tr("Previous track")
            onClicked: media.previous()
            MaterialSymbol { anchors.centerIn: parent; text: "skip_previous"; fill: 1; iconSize: Math.round(22 * page.d); color: previousKey.enabled ? Airisu.ink : Airisu.inkThird }
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
            width: keys.side
            height: keys.tall
            enabled: media.effectiveCanGoNext
            Accessible.name: Translation.tr("Next track")
            onClicked: media.next()
            MaterialSymbol { anchors.centerIn: parent; text: "skip_next"; fill: 1; iconSize: Math.round(22 * page.d); color: nextKey.enabled ? Airisu.ink : Airisu.inkThird }
        }
    }

    ColumnLayout {
        Layout.row: Math.max(0, page.rowOf("players"))
        Layout.fillWidth: true
        visible: page.rowOf("players") >= 0 && page.otherPlayers.length > 0 && !page.anime
        spacing: Math.round(10 * page.d)
        Rectangle { Layout.fillWidth: true; implicitHeight: Airisu.hair; color: Airisu.rule }
        IrisPlayerChips {
            Layout.fillWidth: true
            player: page.island?.player ?? null
            accent: Airisu.ink
        }
    }

    ColumnLayout {
        Layout.row: Math.max(0, page.rowOf("levels"))
        Layout.fillWidth: true
        visible: page.rowOf("levels") >= 0 && page.streams.length > 0 && !page.anime
        spacing: Math.round(8 * page.d)
        Rectangle { Layout.fillWidth: true; implicitHeight: Airisu.hair; color: Airisu.rule }
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
                    color: level.muted ? Airisu.inkThird : Airisu.ink
                }
                // A stream's volume is a setting's range: the graduated rule.
                IrisScrubber {
                    Layout.fillWidth: true
                    knob: true
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
                    implicitWidth: Math.round(30 * page.d)
                    implicitHeight: Math.round(26 * page.d)
                    Accessible.name: level.muted ? Translation.tr("Unmute") : Translation.tr("Mute")
                    onClicked: {
                        const mute = !level.muted
                        level.nodes.forEach(node => { if (node?.audio) node.audio.muted = mute })
                    }
                    MaterialSymbol { anchors.centerIn: parent; text: level.muted ? "volume_off" : "volume_up"; fill: 1; iconSize: Math.round(16 * page.d); color: level.muted ? Airisu.caution : Airisu.inkSecond }
                }
            }
        }
    }
}
