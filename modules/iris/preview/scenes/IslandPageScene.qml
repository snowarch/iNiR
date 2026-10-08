pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.field as Field
import qs.modules.iris.bar.island as IslandParts
import qs.modules.iris.preview.parts

PreviewScene {
    id: pageRoot
    readonly property string mode: pageRoot.group === "Player page" ? "media" : pageRoot.group === "Pages" ? "pages" : "desktop"
    readonly property real pageW: Math.max(360, Math.min(600, Number(pageRoot.opt("iris.bar.pageWidth", 440)))) * pageRoot.d
    readonly property bool banner: String(pageRoot.opt("iris.bar.desktopBanner", "wallpaper")) === "wallpaper"
    readonly property string plate: {
        const value = String(pageRoot.opt("iris.bar.navFrame", "auto"))
        const global = String(pageRoot.opt("iris.appearance.controlPlate", "none"))
        return ["none", "veil", "glass", "solid"].includes(value) ? value : ["veil", "glass", "solid"].includes(global) ? global : "none"
    }
    function part(key: string, fallback: int): real { return Math.max(0, Math.min(100, Number(pageRoot.opt("iris.bar." + key, fallback)))) / 100 }
    readonly property real bannerTop: pageRoot.part("desktopBannerTop", 100)
    readonly property real bannerFade: pageRoot.part("desktopBannerFade", 100)
    readonly property real bannerVeil: pageRoot.part("desktopBannerVeil", 100)
    readonly property real bannerBlur: pageRoot.part("desktopBannerBlur", 0)
    readonly property bool grouped: String(pageRoot.opt("iris.bar.blockStyle", "plain")) === "grouped"
    readonly property var desktopBlocks: Array.from(pageRoot.opt("iris.bar.desktopBlocks", ["profile", "context", "forecast", "agenda", "modules"]))
    readonly property var mediaBlocks: Array.from(pageRoot.opt("iris.bar.mediaBlocks", ["player", "timeline", "transport", "players", "levels"]))
    readonly property var navKinds: ["media", "activity", "desktop", "tray", "tools", "focus", "today", "controls", "settings"]
    readonly property var navEntries: {
        const chosen = Array.from(pageRoot.opt("iris.bar.navItems", pageRoot.navKinds)).filter(kind => pageRoot.navKinds.includes(kind))
        const glyphs = { media: "music_note", activity: "bolt", desktop: "space_dashboard", tray: "apps", tools: "timer",
            focus: "left_panel_open", today: "right_panel_open", controls: "tune", settings: "settings" }
        const pageKinds = ["media", "activity", "desktop", "tray", "tools"]
        const out = []
        let pages = true
        for (const kind of (chosen.length > 0 ? chosen : pageRoot.navKinds)) {
            const page = pageKinds.includes(kind)
            if (pages && !page && out.length > 0) out.push({ kind: "|" })
            if (!page) pages = false
            out.push({ kind: kind, page: page, glyph: glyphs[kind] })
        }
        return out
    }
    readonly property int pageCount: pageRoot.navEntries.filter(entry => entry.page).length
    readonly property int actionCount: pageRoot.navEntries.filter(entry => entry.kind !== "|" && !entry.page).length
    readonly property string current: pageRoot.mode === "media" ? "media" : "desktop"
    readonly property var player: MprisController.activePlayer
    readonly property var hours: Array.from(Weather.data?.hourly ?? []).slice(0, 6)
    readonly property bool weatherReady: Weather.enabled && !String(Weather.data?.temp ?? "--").startsWith("--")
    readonly property var lastWindow: {
        const stamp = w => (w.focus_timestamp?.secs ?? 0) * 1e9 + (w.focus_timestamp?.nanos ?? 0)
        return (NiriService.windows ?? []).slice().sort((a, b) => stamp(b) - stamp(a))[0] ?? null
    }
    readonly property real naturalWidth: pageRoot.pageW + Math.round(160 * pageRoot.d)
    readonly property real naturalHeight: pageRoot.bodyY + pageRoot.bodyHeight + Math.round(56 * pageRoot.d)
    readonly property bool cropBottom: true
    readonly property bool notch: Boolean(pageRoot.opt("iris.bar.notch", true))
    readonly property real corner: IrisStyle.openedRadius(IrisStyle.barShape, Math.max(IrisStyle.radius, 30 * pageRoot.d))
    readonly property real topInset: pageRoot.notch ? Math.ceil(pageRoot.corner) : 0
    readonly property real padding: Math.round(20 * pageRoot.d)
    readonly property real navBand: previewNav.height + Math.round(14 * pageRoot.d)
    readonly property real bodyX: Math.round((width - pageRoot.pageW) / 2)
    readonly property real bodyY: pageRoot.notch ? 0 : IrisFrame.band + Math.round(Number(pageRoot.opt("iris.bar.margin", 8)) * pageRoot.d)
    readonly property real bodyHeight: pageColumn.y + pageColumn.implicitHeight + pageRoot.padding

    Field.IrisField {
        anchors.fill: parent
        framed: false
        shapes: {
            const f = IrisStyle.fuseDeep, deep = Math.max(8, f * 2)
            const out = []
            if (pageRoot.notch || IrisFrame.framed)
                out.push({ x: -2 * f, y: -deep, width: width + 4 * f, height: deep + (IrisFrame.framed ? IrisFrame.band : 0), radius: 0, fuse: f, id: "edge", paints: true })
            out.push({ x: pageRoot.bodyX, y: pageRoot.bodyY, width: pageRoot.pageW, height: pageRoot.bodyHeight, radius: pageRoot.corner,
                fuse: pageRoot.notch ? IrisStyle.fuseEdge : IrisStyle.fuse, id: "island", joins: pageRoot.notch ? "edge" : "", paints: true })
            return out
        }
    }

    ClippingRectangle {
        id: islandBody
        x: pageRoot.bodyX
        y: pageRoot.bodyY - pageRoot.topInset
        width: pageRoot.pageW
        height: pageRoot.bodyHeight + pageRoot.topInset
        radius: pageRoot.corner
        color: "transparent"

        Item {
            id: bodyContent
            y: pageRoot.topInset
            width: parent.width
            height: pageRoot.bodyHeight

            Item {
                id: previewHeader
                visible: pageRoot.mode !== "media" && pageRoot.banner
                width: parent.width
                height: pageColumn.y + previewHero.height + Math.round(12 * pageRoot.d)
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: previewFade
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                    blurEnabled: pageRoot.bannerBlur > 0
                    blur: pageRoot.bannerBlur
                    blurMax: 48
                }
                IrisImage {
                    anchors.fill: parent
                    source: pageRoot.wallpaper
                }
                IrisHeaderScrim {
                    id: previewScrim
                    anchors.fill: parent
                    hangs: true
                    solidTop: pageRoot.topInset + pageRoot.padding + pageRoot.navBand * 0.5
                    navBand: pageRoot.navBand
                    topJoin: pageRoot.notch
                    joinDepth: pageRoot.topInset + Math.round(pageRoot.corner * 0.62) + 4 * pageRoot.d
                    unit: pageRoot.d
                    meltTop: pageRoot.bannerTop
                    meltFade: pageRoot.bannerFade
                    meltVeil: pageRoot.bannerVeil
                }
            }
            IrisHeaderFade {
                id: previewFade
                scrim: previewScrim
                width: previewHeader.width
                height: previewHeader.height
            }

            IrisControlPlate {
                id: previewNav
                x: Math.round((bodyContent.width - width) / 2)
                y: pageRoot.topInset + pageRoot.padding
                material: pageRoot.plate
                Row {
                    spacing: Math.round(4 * pageRoot.d)
                    Repeater {
                        model: pageRoot.navEntries
                        Item {
                            id: navEntry
                            required property var modelData
                            readonly property bool divider: navEntry.modelData.kind === "|"
                            readonly property bool selected: navEntry.modelData.kind === pageRoot.current
                            width: navEntry.divider ? Math.round(9 * pageRoot.d) : Math.round(36 * pageRoot.d)
                            height: Math.round(30 * pageRoot.d)
                            Rectangle {
                                visible: navEntry.divider
                                anchors.centerIn: parent
                                width: 1; height: Math.round(14 * pageRoot.d)
                                color: IrisStyle.fill
                            }
                            Rectangle {
                                visible: !navEntry.divider
                                anchors.fill: parent
                                radius: previewNav.controlRadius
                                color: navEntry.selected ? IrisStyle.tintFill(IrisStyle.accent) : pageRoot.mode === "pages" && navEntry.modelData.page ? IrisStyle.fillQuiet : "transparent"
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: navEntry.modelData.glyph ?? ""
                                    fill: navEntry.selected ? 1 : 0
                                    iconSize: Math.round(18 * pageRoot.d)
                                    color: navEntry.selected ? IrisStyle.accent : IrisStyle.textSecondary
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                id: pageColumn
                x: pageRoot.padding
                y: previewNav.y + pageRoot.navBand
                width: parent.width - 2 * x
                spacing: Math.round(14 * pageRoot.d)

                Item {
                    id: previewHero
                    visible: pageRoot.mode !== "media"
                    Layout.fillWidth: true
                    implicitHeight: pageRoot.banner
                        ? Math.max(Math.round(112 * pageRoot.d), heroRow.implicitHeight + Math.round(26 * pageRoot.d))
                        : heroRow.implicitHeight

                    IrisControlPlate {
                        id: previewTools
                        visible: pageRoot.mode === "desktop"
                        anchors.right: parent.right
                        anchors.rightMargin: -previewTools.inset
                        anchors.top: parent.top
                        anchors.topMargin: -Math.round(6 * pageRoot.d) - previewTools.inset
                        material: pageRoot.plate
                        controlHeight: Math.round(32 * pageRoot.d)
                        Row {
                            spacing: previewTools.framed ? Math.round(2 * pageRoot.d) : Math.round(6 * pageRoot.d)
                            Repeater {
                                model: pageRoot.banner ? ["edit", "wallpaper"] : ["edit"]
                                Rectangle {
                                    required property string modelData
                                    width: Math.round(32 * pageRoot.d)
                                    height: width
                                    radius: previewTools.framed ? previewTools.controlRadius : height / 2
                                    color: previewTools.framed ? "transparent" : pageRoot.banner ? IrisStyle.veil : IrisStyle.fillQuiet
                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: parent.modelData
                                        iconSize: Math.round(17 * pageRoot.d)
                                        color: pageRoot.banner ? IrisStyle.onMedia : IrisStyle.text
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        id: heroRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        spacing: Math.round(12 * pageRoot.d)
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignBottom
                            spacing: -Math.round(2 * pageRoot.d)
                            IrisText {
                                textFormat: Text.StyledText
                                text: "<font color='" + (pageRoot.banner ? IrisStyle.textStrong : IrisStyle.secondaryAccent) + "'><b>"
                                    + Translation.locale.toString(DateTime.clock.date, "dddd") + "</b></font> "
                                    + Translation.locale.toString(DateTime.clock.date, "d MMMM")
                                color: pageRoot.banner ? IrisStyle.textStrong : IrisStyle.textSecondary
                                font.pixelSize: IrisStyle.typeLabel
                                font.weight: IrisStyle.weight(Font.Medium)
                            }
                            IrisClock { pixelSize: 46 * IrisStyle.typeScale }
                        }
                        ColumnLayout {
                            visible: pageRoot.weatherReady
                            Layout.alignment: Qt.AlignBottom
                            spacing: 0
                            RowLayout {
                                Layout.alignment: Qt.AlignRight
                                spacing: Math.round(6 * pageRoot.d)
                                MaterialSymbol { text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"; fill: 1; iconSize: Math.round(22 * pageRoot.d); color: IrisStyle.text }
                                IslandParts.Metric {
                                    readonly property string raw: String(Weather.data?.temp ?? "")
                                    value: raw.replace(/°?[CF]$/, "")
                                    unit: raw.length > value.length ? raw.slice(value.length) : ""
                                    pixelSize: 26 * IrisStyle.typeScale
                                    weight: Font.DemiBold
                                }
                            }
                            IrisText {
                                Layout.alignment: Qt.AlignRight
                                Layout.maximumWidth: Math.round(150 * pageRoot.d)
                                text: String(Weather.data?.description ?? "")
                                color: pageRoot.banner ? IrisStyle.textStrong : IrisStyle.textSecondary
                                font.pixelSize: IrisStyle.typeMeta
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                Repeater {
                    model: pageRoot.mode === "desktop" ? pageRoot.desktopBlocks : []
                    Loader {
                        id: desktopBlock
                        required property string modelData
                        Layout.fillWidth: true
                        sourceComponent: desktopBlock.modelData === "forecast" || desktopBlock.modelData === "vitals" ? stripBlock : rowBlock
                        Component {
                            id: rowBlock
                            BlockRow {
                                glyph: ({ profile: "account_circle", context: "select_window", agenda: "event_upcoming", modules: "widgets" })[desktopBlock.modelData] ?? "circle"
                                title: ({ profile: SystemInfo.displayName || SystemInfo.username || Translation.tr("You"),
                                    context: pageRoot.lastWindow?.title || Translation.tr("Current app"),
                                    agenda: Translation.tr("Up next"), modules: Translation.tr("Modules") })[desktopBlock.modelData] ?? ""
                                detail: ({ profile: Translation.tr("Up %1").arg(DateTime.uptime), context: AppSearch.lookupDesktopEntry(pageRoot.lastWindow?.app_id ?? "")?.name || Translation.tr("Workspace"),
                                    agenda: Translation.tr("This week is clear"), modules: Translation.tr("Your desktop widgets") })[desktopBlock.modelData] ?? ""
                            }
                        }
                        Component {
                            id: stripBlock
                            Rectangle {
                                implicitHeight: stripRow.implicitHeight + (pageRoot.grouped ? Math.round(20 * pageRoot.d) : 0)
                                radius: IrisStyle.radiusTile
                                color: pageRoot.grouped ? IrisStyle.fillQuiet : "transparent"
                                RowLayout {
                                    id: stripRow
                                    anchors.centerIn: parent
                                    width: parent.width - (pageRoot.grouped ? Math.round(20 * pageRoot.d) : 0)
                                    spacing: 0
                                    Repeater {
                                        model: desktopBlock.modelData === "forecast"
                                            ? (pageRoot.hours.length > 0 ? pageRoot.hours : [{}, {}, {}, {}, {}, {}])
                                            : [{ glyph: "memory", value: Math.round(ResourceUsage.cpuUsage * 100) + "%" },
                                                { glyph: "memory_alt", value: Math.round(ResourceUsage.memoryUsedPercentage * 100) + "%" },
                                                { glyph: "device_thermostat", value: ResourceUsage.maxTemp + "°" },
                                                { glyph: "hard_drive", value: Math.round(ResourceUsage.diskUsedPercentage * 100) + "%" }]
                                        ColumnLayout {
                                            id: stripCell
                                            required property var modelData
                                            required property int index
                                            Layout.fillWidth: true
                                            Layout.preferredWidth: 1
                                            spacing: Math.round(4 * pageRoot.d)
                                            IrisText {
                                                visible: desktopBlock.modelData === "forecast"
                                                Layout.alignment: Qt.AlignHCenter
                                                text: stripCell.index === 0 ? Translation.tr("Now") : String(stripCell.modelData.label ?? "").slice(0, 2)
                                                color: IrisStyle.muted
                                                font.pixelSize: IrisStyle.typeMeta
                                            }
                                            MaterialSymbol {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: desktopBlock.modelData === "forecast" ? (Icons.getWeatherIcon(stripCell.modelData.code, stripCell.modelData.isNight) ?? "cloud") : stripCell.modelData.glyph
                                                fill: 1
                                                iconSize: Math.round(17 * pageRoot.d)
                                                color: desktopBlock.modelData === "forecast" ? IrisStyle.skyLight(text) : IrisStyle.subtext
                                            }
                                            IrisText {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: desktopBlock.modelData === "forecast" ? String(stripCell.modelData.temp ?? "—") : stripCell.modelData.value
                                                font.family: IrisStyle.fontNumbers
                                                font.pixelSize: IrisStyle.typeLabel
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Repeater {
                    model: pageRoot.mode === "media" ? pageRoot.mediaBlocks : []
                    Loader {
                        id: mediaBlock
                        required property string modelData
                        Layout.fillWidth: true
                        sourceComponent: ({ player: playerBlock, timeline: timelineBlock, transport: transportBlock, players: playersBlock, levels: levelsBlock })[mediaBlock.modelData] ?? null
                        Component {
                            id: playerBlock
                            RowLayout {
                                spacing: Math.round(14 * pageRoot.d)
                                ClippingRectangle {
                                    implicitWidth: Math.round(56 * pageRoot.d); implicitHeight: implicitWidth
                                    radius: IrisStyle.radiusTile
                                    color: IrisStyle.fill
                                    IrisImage { anchors.fill: parent; source: String(MprisController.artUrlOf(pageRoot.player) ?? "") }
                                    MaterialSymbol { anchors.centerIn: parent; visible: String(MprisController.artUrlOf(pageRoot.player) ?? "").length === 0; text: "music_note"; fill: 1; iconSize: Math.round(26 * pageRoot.d); color: IrisStyle.subtext }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Math.round(2 * pageRoot.d)
                                    IrisText { Layout.fillWidth: true; text: MprisController.titleOf(pageRoot.player) || Translation.tr("Song title"); font.weight: IrisStyle.weight(Font.DemiBold); font.pixelSize: IrisStyle.typeHeadline; elide: Text.ElideRight }
                                    IrisText { Layout.fillWidth: true; text: MprisController.artistOf(pageRoot.player) || Translation.tr("Artist"); color: IrisStyle.subtext; elide: Text.ElideRight }
                                }
                            }
                        }
                        Component { id: timelineBlock; Level { value: 0.34; tint: IrisStyle.text } }
                        Component {
                            id: transportBlock
                            Item {
                                implicitHeight: Math.round(30 * pageRoot.d)
                                Row {
                                    anchors.centerIn: parent
                                    spacing: Math.round(34 * pageRoot.d)
                                    Repeater {
                                        model: ["fast_rewind", pageRoot.player?.isPlaying ? "pause" : "play_arrow", "fast_forward"]
                                        MaterialSymbol { required property string modelData; text: modelData; fill: 1; iconSize: Math.round(26 * pageRoot.d); color: IrisStyle.text }
                                    }
                                }
                            }
                        }
                        Component {
                            id: playersBlock
                            BlockRow { glyph: "queue_music"; title: Translation.tr("Other players"); detail: Translation.tr("%1 playing").arg(Math.max(1, (MprisController.players ?? []).length)) }
                        }
                        Component {
                            id: levelsBlock
                            ColumnLayout {
                                spacing: Math.round(10 * pageRoot.d)
                                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: IrisStyle.hairline }
                                Repeater {
                                    model: [0.66, 0.9]
                                    RowLayout {
                                        id: levelRow
                                        required property real modelData
                                        required property int index
                                        spacing: Math.round(12 * pageRoot.d)
                                        MaterialSymbol { text: levelRow.index === 0 ? "music_note" : "public"; fill: 1; iconSize: Math.round(17 * pageRoot.d); color: IrisStyle.subtext }
                                        IrisText { Layout.preferredWidth: Math.round(110 * pageRoot.d); text: levelRow.index === 0 ? Translation.tr("Player") : Translation.tr("Browser"); elide: Text.ElideRight }
                                        Level { value: levelRow.modelData; tint: IrisStyle.text }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Caption {
        glyph: pageRoot.mode === "media" ? "music_note" : pageRoot.mode === "pages" ? "view_carousel" : "space_dashboard"
        text: pageRoot.mode === "pages"
            ? Translation.tr("%1 px · %2 pages, %3 shortcuts").arg(Math.round(pageRoot.pageW / pageRoot.d)).arg(pageRoot.pageCount).arg(pageRoot.actionCount)
            : pageRoot.mode === "media"
                ? (pageRoot.mediaBlocks.length > 0 ? Translation.tr("%1 blocks, in your order").arg(pageRoot.mediaBlocks.length) : Translation.tr("No blocks: the page is empty"))
                : (pageRoot.banner ? Translation.tr("Wallpaper header") : Translation.tr("Plain header")) + " · "
                    + (pageRoot.grouped ? Translation.tr("grouped strips") : Translation.tr("plain rows")) + " · "
                    + Translation.tr("%1 blocks").arg(pageRoot.desktopBlocks.length)
    }
}
