pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.settings
import "../components"

// AIRISU's Settings: a lacquered catalogue (冊子, SYSTEM.md §4 › Place). The areas are its thumb index (ツメ): a fore-edge of
// deep lacquer down the right of the body, every area a tab printed on it and the open one the seal, standing out of the
// edge into the page. A page is a spread: on the left its name set large with what it holds as ruby over it, the plate of
// the group being read (the engine's scene) and the page's contents; on the right the rows. A running head carries the
// way back and the search, the foot the folio and what can be done to the page. The engine keeps the model, the search,
// the history and every row; this lays them out and holds the engine's own items in its slots.
Item {
    id: root
    property Item host
    readonly property real d: Number(root.host?.d ?? 1)
    function u(n: real): int { return Math.round(n * 4 * root.d) }

    // What the engine fills, and the room it reads to lay its rows.
    readonly property alias searchSlot: searchSlot
    readonly property alias stageSlot: stageSlot
    readonly property alias rowsSlot: rowsSlot
    readonly property real pageWidth: page.width
    // As tall as the index needs to print every tab at its full height: the engine sizes the body from it.
    readonly property real need: root.sections.length * root.u(6.5) + edge.breaks * root.u(3) + 2 * root.u(6)
    readonly property real stageWidth: left.width
    readonly property real aspect: {
        const screen = GlobalStates.focusedScreen
        return screen ? screen.height / Math.max(1, screen.width) : 0.5625
    }
    readonly property real stageHeight: Math.max(0, Math.min(Math.round(left.width * root.aspect), left.plateRoom))

    readonly property var sections: root.host?.sections ?? []
    readonly property string section: String(root.host?.section ?? "")
    readonly property bool searching: root.host?.searching ?? false
    readonly property int pageIndex: root.sections.findIndex(entry => entry.id === root.section)
    readonly property var currentSection: root.host?.currentSection ?? ({})
    readonly property bool sharedPage: Number(root.host?.advancedPage ?? -1) >= 0
    readonly property int hits: (root.host?.matches?.length ?? 0) + (root.host?.pageMatches?.length ?? 0)

    // A page arrives as a detent: the spread is set again where it stands, never slid in. Opening is the Place's own
    // arrival, so a page asked for while the body is still settling is not set a second time.
    readonly property bool settled: Number(root.host?.frame?.presentation ?? 0) >= 1
    Connections {
        target: root.host
        function onSectionChanged(): void { if (root.settled) turn.restart() }
        function onAdvancedPageChanged(): void { if (root.settled) turn.restart() }
    }
    NumberAnimation { id: turn; target: spread; property: "opacity"; from: 0.25; to: 1; duration: Airisu.snap; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve }

    // The floors keep their order in every scheme and material, as the boards' plates do (sumi, gofun, a step between):
    // the cover (the index) deepest, the ground of the page over it, the sheet of rows on top. By day the ground is the
    // paper itself between the sumi cover and the whiter sheet; at night it is lifted a step off the black lacquer of the
    // cover (on one black the index had no edge but its type). Over glass the ground is read on a plate of that colour as
    // thick as the larger of two needs: Lume's (its type holds its contrast over what is behind) and the floors' (it
    // stays under the sheet: over a bright wallpaper at night bare glass rose above the sheet and the sheet read as a
    // hole). The plate covers the whole ground left of the index, inside the glass's lit edge.
    readonly property color floor: IrisStyle.light ? Airisu.solid(IrisStyle.surfaceOpaque)
        : ColorUtils.mix(Airisu.sheet, Airisu.solid(IrisStyle.surfaceOpaque), 0.4) // iris-literal: the night ground, two fifths of the way to the sheet
    readonly property real floorPlate: {
        if (!IrisStyle.glassy) return 1
        const screen = Lume.screenNamed(IrisStyle.placeOutput)
        const sample = screen ? Lume.read(IrisStyle.placeOutput, screen.width * 0.2, screen.height * 0.12,
            screen.width * 0.6, screen.height * 0.76) : null
        // Gamma levels: the brighter part of the backdrop under the glass's tint, the ground, the sheet.
        const gamma = c => Math.pow(ColorUtils.relativeLuminance(c), 1 / 2.2)
        const level = sample ? Math.min(1, sample.level + sample.spread * 0.5) : 0.72
        const ground = gamma(root.floor), sheet = gamma(Airisu.sheet)
        const glass = level * (1 - IrisStyle.glassTint) + gamma(IrisStyle.surfaceOpaque) * IrisStyle.glassTint
        const most = ground + (sheet - ground) * 0.45 // iris-literal: the ground stands under the sheet by half their step
        return glass <= most || glass - ground < 0.001 ? 0 : Math.min(1, (glass - most) / (glass - ground))
    }
    // The glass's lit edge: a band this wide shows all round the window, the index's side too (the cover stood flush
    // and cut the band off on three sides of it).
    readonly property real lip: IrisStyle.glassy ? 2 * Airisu.hair : 0
    ALacquer {
        visible: IrisStyle.glassy || !IrisStyle.light
        x: root.lip
        y: root.lip
        width: edge.x - root.lip
        height: root.height - 2 * root.lip
        lacquer: ColorUtils.applyAlpha(root.floor, Math.max(IrisStyle.placePlate, root.floorPlate))
        cut: IrisStyle.nestedCut(Airisu.chamfer, root.lip)
        cutTopRight: false
    }

    // ── The fore-edge: every area as a tab of the index, in the engine's clusters; the footer's areas stand at its foot.
    ALacquer {
        id: edge
        readonly property int footerCluster: Number(root.host?.footerCluster ?? 99)
        readonly property var main: root.sections.filter(entry => entry.cluster < edge.footerCluster)
        readonly property var foot: root.sections.filter(entry => entry.cluster >= edge.footerCluster)
        readonly property int breaks: new Set(edge.main.map(entry => entry.cluster)).size - 1 + (edge.foot.length > 0 ? 1 : 0)
        readonly property real tab: Math.max(root.u(6), Math.min(root.u(8),
            Math.floor((edge.height - 2 * root.u(6) - edge.breaks * root.u(3)) / Math.max(1, root.sections.length))))
        // The fore-edge is the cover the pages are bound in, a step under the body; the open tab is the cover's reverse.
        readonly property color stock: Airisu.cover
        readonly property color open: Airisu.seal
        readonly property color ink: Airisu.inkOn(edge.stock)
        // The seal set as type on the cover: the cover is sumi by day, where the seal solved for paper sinks into it.
        readonly property color mark: ColorUtils.contrastRatio(Airisu.sealText, Airisu.solid(edge.stock))
            >= ColorUtils.contrastRatio(Airisu.sealOnMedia, Airisu.solid(edge.stock)) ? Airisu.sealText : Airisu.sealOnMedia
        // A rule between the index's clusters, one tone of the cover's ink.
        readonly property color rule: ColorUtils.mix(edge.ink, Airisu.solid(edge.stock), 0.16) // iris-literal: a hairline on the cover
        // As wide as the longest area's name needs at rest (a long locale stops at the cap and elides): the open tab
        // stands out of the edge by its own step and fits its larger name to what that leaves.
        readonly property real names: Math.max(0, ...root.sections.map(entry => tabFont.advanceWidth(Translation.tr(String(entry.title ?? "")))))
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: root.lip
        width: Math.max(root.u(44), Math.min(root.u(58), Math.ceil(edge.names) + root.u(11) + root.u(4)))
        FontMetrics {
            id: tabFont
            font.family: Airisu.textFace
            font.pixelSize: IrisStyle.typeLabel
            font.weight: Font.Medium
        }
        lacquer: edge.stock
        cut: IrisStyle.nestedCut(Airisu.chamfer, root.lip)
        // Cut only where the body is: its upper-right corner. Its foot stands inside the body's square edge.
        cutBottomLeft: false

        // The index scrolls inside the edge when the screen is too short for every tab at its smallest: it ends above the
        // foot's tabs (they ran into each other at 1280x800) and brings the open tab into view.
        Flickable {
            id: mainTabs
            y: root.u(6)
            width: parent.width
            height: Math.max(0, footTabs.y - y - root.u(3))
            contentHeight: mainColumn.implicitHeight
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            layer.enabled: tabsEdge.active
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: tabsEdge.mask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }
            // The tabs past either end fade off instead of being cut mid-letter (IrisScrollEdge, the fade alone: a
            // blurred band inside the masked list would be masked away with it).
            IrisScrollEdge {
                id: tabsEdge
                parent: mainTabs
                flick: mainTabs
                anchors.fill: parent
                blurs: false
                reach: root.u(5)
            }
            Column {
                id: mainColumn
                width: parent.width
                Repeater {
                    model: edge.main
                    IndexTab { list: edge.main }
                }
            }
            function follow(): void {
                const tab = mainColumn.children.find(child => child.chosen === true)
                if (!tab) return
                const end = Math.max(0, mainTabs.contentHeight - mainTabs.height)
                if (tab.y < mainTabs.contentY) mainTabs.contentY = Math.max(0, tab.y - tab.height)
                else if (tab.y + tab.height > mainTabs.contentY + mainTabs.height)
                    mainTabs.contentY = Math.min(end, tab.y + 2 * tab.height - mainTabs.height)
            }
            Timer { id: tabFollow; interval: 0; onTriggered: mainTabs.follow() }
            onHeightChanged: tabFollow.restart()
            Connections {
                target: root.host
                function onSectionChanged(): void { tabFollow.restart() }
            }
            Component.onCompleted: tabFollow.restart()
        }
        Column {
            id: footTabs
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.u(6)
            width: parent.width
            Repeater {
                model: edge.foot
                IndexTab { list: [] }
            }
        }
    }

    // ── The page.
    Item {
        id: page
        anchors.left: parent.left
        anchors.right: edge.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.u(7)
        anchors.rightMargin: root.u(7)
        anchors.topMargin: root.u(5)
        anchors.bottomMargin: root.u(4)

        // The running head (柱): the way back and forth, the search; the window and the way out at its end.
        Item {
            id: head
            width: parent.width
            height: root.u(9)
            GlyphKey {
                id: back
                glyph: "chevron_left"
                name: Translation.tr("Back")
                available: (root.host?.backStack?.length ?? 0) > 0
                onClicked: root.host.goBack()
            }
            GlyphKey {
                id: forward
                x: back.width + root.u(1)
                glyph: "chevron_right"
                name: Translation.tr("Forward")
                available: (root.host?.forwardStack?.length ?? 0) > 0
                onClicked: root.host.goForward()
            }
            Item {
                id: searchSlot
                x: forward.x + forward.width + root.u(3)
                // The column's measure, never the plate's width: the head stays put from page to page.
                width: left.measure - x
                height: parent.height
            }
            GlyphKey {
                id: host
                anchors.right: close.left
                anchors.rightMargin: root.u(1)
                glyph: root.host?.windowed ? "layers" : "web_asset"
                name: root.host?.windowed ? Translation.tr("Open over the desktop") : Translation.tr("Open as a window")
                onClicked: root.host.switchHost()
            }
            GlyphKey {
                id: close
                anchors.right: parent.right
                glyph: "close"
                name: Translation.tr("Close settings")
                onClicked: root.host.close()
            }
        }
        Rectangle {
            id: headRule
            anchors.top: head.bottom
            anchors.topMargin: root.u(3)
            width: parent.width
            height: Airisu.hair
            color: Airisu.rule
        }

        Item {
            id: spread
            anchors.top: headRule.bottom
            anchors.bottom: footRule.top
            anchors.topMargin: root.u(6)
            anchors.bottomMargin: root.u(3)
            width: parent.width

            // The left of the spread: the page's name with its ruby, the plate of what is being read, the contents.
            Item {
                id: left
                // The column's measure; the name is always set to it, so the plate can widen without rewrapping the name.
                readonly property real measure: Math.round(Math.max(root.u(62), Math.min(root.u(84), page.width * 0.31)))
                // What the plate may take: the column's height less the name, the caption and the contents. A short page
                // gives its air to the plate (wider, so the picture keeps the screen's proportions) instead of leaving
                // the foot of the column bare; a long one keeps the plate at a third of the spread.
                readonly property real plateRoom: Math.max(Math.round(spread.height * 0.36),
                    spread.height - nameBlock.height - contentsColumn.implicitHeight - caption.implicitHeight - root.u(6 + 2 + 5 + 4))
                width: plate.shown ? Math.round(Math.max(left.measure, Math.min(page.width * 0.42, left.plateRoom / root.aspect))) : left.measure
                height: parent.height

                Column {
                    id: nameBlock
                    width: left.measure
                    spacing: root.u(1)
                    AText {
                        width: parent.width
                        visible: text.length > 0
                        voice: "ruby"
                        color: Airisu.sealText
                        text: root.searching ? "“" + String(root.host?.query ?? "") + "”"
                            : root.sharedPage ? Translation.tr(String(root.currentSection.title ?? ""))
                            : Translation.tr(String(root.currentSection.subtitle ?? ""))
                    }
                    AText {
                        id: name
                        // The largest step of AIRISU's heads, down to the display size where one word of the name would not fit.
                        readonly property int most: Math.round(IrisStyle.typeDisplay * 1.5)
                        width: parent.width
                        voice: "figure"
                        size: Math.max(IrisStyle.typeDisplay, Math.min(name.most, Math.floor(name.most * width / Math.max(1, longest.advanceWidth))))
                        lineHeight: 0.96
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        text: root.searching ? (root.hits > 0 ? Translation.tr("%1 results").arg(root.hits) : Translation.tr("No results"))
                            : root.sharedPage ? String(root.host?.titleText ?? "")
                            : Translation.tr(String(root.currentSection.title ?? ""))
                        TextMetrics {
                            id: longest
                            font.family: name.font.family
                            font.weight: name.font.weight
                            font.pixelSize: name.most
                            font.letterSpacing: -Math.round(name.most * 0.03)
                            text: name.text.split(/\s+/).reduce((a, b) => b.length > a.length ? b : a, "")
                        }
                    }
                    AText {
                        width: parent.width
                        topPadding: root.u(1)
                        visible: text.length > 0 && !root.searching && !root.sharedPage
                        size: IrisStyle.typeLabel
                        font.weight: Font.Normal
                        color: Airisu.inkSecond
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        text: Translation.tr(String(root.currentSection.tip ?? ""))
                    }
                }

                // The plate (図版): the engine's scene of the group being read, its name under it.
                Item {
                    id: plate
                    readonly property bool shown: root.host?.stageInColumn ?? false
                    anchors.top: nameBlock.bottom
                    anchors.topMargin: plate.shown ? root.u(6) : 0
                    width: parent.width
                    height: plate.shown ? stageSlot.height + caption.height + root.u(2) : 0
                    visible: plate.shown
                    // Tipped in: the print stands off the cover on its offset shadow, cut by the body's die.
                    ALacquer {
                        x: Airisu.offset
                        y: Airisu.offset
                        width: stageSlot.width
                        height: stageSlot.height
                        lacquer: Airisu.shade
                        cut: Airisu.chamfer
                    }
                    // The picture is cut by the body's die itself (a mask, not corners painted in the body's colour, which
                    // showed as patches over glass); the preview's own frame stays off under a chamfered field.
                    Item {
                        id: stageSlot
                        width: parent.width
                        height: root.stageHeight
                        layer.enabled: plate.shown && width > 0
                        layer.smooth: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: stageDie
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1
                        }
                    }
                    ADie {
                        id: stageDie
                        visible: false
                        width: stageSlot.width
                        height: stageSlot.height
                        kind: "chamfer"
                        cut: Airisu.chamfer
                        fill: "white"
                        layer.enabled: true
                    }
                    AText {
                        id: caption
                        anchors.top: stageSlot.bottom
                        anchors.topMargin: root.u(2)
                        width: parent.width
                        voice: "ruby"
                        text: String(root.host?.heroCaption ?? "")
                    }
                }

                // The contents (目次): the page's groups and the links at its foot, numbered as the index is.
                Flickable {
                    id: contents
                    anchors.top: plate.bottom
                    anchors.topMargin: root.u(5)
                    anchors.bottom: parent.bottom
                    width: parent.width
                    clip: true
                    contentHeight: contentsColumn.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    layer.enabled: contentsEdge.active
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: contentsEdge.mask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1
                    }
                    // So do the contents' entries.
                    IrisScrollEdge {
                        id: contentsEdge
                        parent: contents
                        flick: contents
                        anchors.fill: parent
                        blurs: false
                        reach: root.u(5)
                    }
                    Column {
                        id: contentsColumn
                        width: parent.width
                        Repeater {
                            model: ScriptModel { objectProp: "key"; values: root.searching ? [] : (root.host?.navEntries ?? []) }
                            ContentsEntry {}
                        }
                    }
                }
            }

            // The right of the spread: the rows, or a shared page, with what waits for an answer over them.
            Item {
                id: right
                anchors.left: left.right
                anchors.leftMargin: root.u(8)
                anchors.right: parent.right
                height: parent.height
                // The page being read: a sheet laid on the lacquer cover, standing off it on its offset shadow, as long as
                // its rows (a short page is a short sheet, never a slab with its lower half bare).
                readonly property real sheetHeight: Number(root.host?.rowsExtent ?? -1) < 0 ? right.height
                    : Math.min(right.height, rowsSlot.y + Number(root.host.rowsExtent) + root.u(5))
                ALacquer {
                    x: Airisu.offset
                    y: Airisu.offset
                    width: parent.width
                    height: right.sheetHeight
                    lacquer: Airisu.shade
                    cut: Airisu.chamfer
                }
                ALacquer {
                    width: parent.width
                    height: right.sheetHeight
                    lacquer: Airisu.sheet
                    cut: Airisu.chamfer
                }
                ALacquer {
                    id: notice
                    readonly property bool shown: IrisNiri.pending !== null
                    visible: notice.shown
                    width: parent.width
                    height: notice.shown ? root.u(12) + root.u(1) : 0
                    // A change that goes back by itself: the page's lacquer under a band of yamabuki that is drawn
                    // back as its seconds go.
                    lacquer: Airisu.lacquerOf(Airisu.pigment("system"))
                    coat: Airisu.tape
                    head: true
                    band: root.u(1)
                    share: Math.max(0, Math.min(1, IrisNiri.secondsLeft / IrisNiri.revertAfter))
                    travel: Airisu.detent
                    AText {
                        anchors.left: parent.left
                        anchors.leftMargin: root.u(4)
                        anchors.right: keep.left
                        anchors.rightMargin: root.u(3)
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: Math.round(root.u(1) / 2)
                        size: IrisStyle.typeLabel
                        color: Airisu.inkOn(notice.lacquer)
                        text: Translation.tr("Keep this display setting? It goes back in %1 s.").arg(IrisNiri.secondsLeft)
                    }
                    WordKey {
                        id: revert
                        anchors.right: keep.left
                        anchors.rightMargin: root.u(1)
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: Math.round(root.u(1) / 2)
                        label: Translation.tr("Revert")
                        onClicked: IrisNiri.revertDisplay()
                    }
                    WordKey {
                        id: keep
                        anchors.right: parent.right
                        anchors.rightMargin: root.u(2)
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: Math.round(root.u(1) / 2)
                        label: Translation.tr("Keep")
                        sealed: true
                        onClicked: IrisNiri.keepDisplay()
                    }
                }
                Item {
                    id: rowsSlot
                    anchors.top: notice.bottom
                    anchors.topMargin: root.u(5)
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: root.u(2)
                    anchors.left: parent.left
                    anchors.leftMargin: root.u(6)
                    anchors.right: parent.right
                    anchors.rightMargin: root.u(6)
                }
            }
        }

        // The foot: what can be done to the page; a page with nothing to do gives the foot to its spread.
        readonly property bool footed: (root.host?.pageActions?.length ?? 0) > 0
        Rectangle {
            id: footRule
            anchors.bottom: foot.top
            anchors.bottomMargin: page.footed ? root.u(3) : 0
            width: parent.width
            height: page.footed ? Airisu.hair : 0
            visible: page.footed
            color: Airisu.rule
        }
        Item {
            id: foot
            anchors.bottom: parent.bottom
            width: parent.width
            height: page.footed ? root.u(8) : 0
            visible: page.footed
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.u(1)
                Repeater {
                    model: root.host?.pageActions ?? []
                    WordKey {
                        required property var modelData
                        glyph: String(modelData.glyph ?? "")
                        label: String(modelData.label ?? "")
                        onClicked: modelData.clicked()
                    }
                }
            }
        }
    }

    // A tab of the index: the area's glyph and name printed on the fore-edge; the open one is the seal, cut as a tab and
    // standing out of the edge into the page. A search dims the areas it finds nothing in and counts what it finds.
    component IndexTab: MouseArea {
        id: tab
        required property var modelData
        required property int index
        property var list: []
        readonly property bool clusterStart: tab.list.length > 0 && tab.index > 0 && tab.list[tab.index - 1]?.cluster !== tab.modelData.cluster
        readonly property bool chosen: !root.searching && root.section === tab.modelData.id
        readonly property int found: root.searching ? (root.host?.matches ?? []).filter(spec => spec.section === tab.modelData.id).length : 0
        readonly property bool dimmed: root.searching && tab.found === 0
        readonly property real line: edge.tab
        width: edge.width
        height: tab.line + (tab.clusterStart ? root.u(3) : 0)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: Translation.tr(tab.modelData.title)
        onClicked: root.host.selectSection(tab.modelData.id)

        Rectangle {
            visible: tab.clusterStart
            x: root.u(4)
            y: Math.round(root.u(3) / 2)
            width: parent.width - root.u(8)
            height: Airisu.hair
            color: edge.rule
        }
        AKey {
            visible: !tab.chosen
            anchors.bottom: parent.bottom
            x: root.u(2)
            width: parent.width - root.u(2)
            height: tab.line
            lacquer: "transparent"
            under: edge.stock
            hovered: tab.containsMouse
            pressed: tab.pressed
        }
        Loader {
            active: tab.chosen
            anchors.bottom: parent.bottom
            x: -root.u(3)
            width: parent.width + root.u(3)
            height: tab.line
            sourceComponent: chosenTab
        }
        Component {
            id: chosenTab
            ALacquer {
                lacquer: edge.open
                cut: Airisu.cutFor(tab.line)
                cutTopRight: false
                cutTopLeft: true
                cutBottomLeft: true
            }
        }
        MaterialSymbol {
            anchors.verticalCenter: parent.bottom
            anchors.verticalCenterOffset: -tab.line / 2
            x: root.u(4)
            text: String(tab.modelData.icon ?? "settings")
            fill: tab.chosen ? 1 : 0
            iconSize: Math.round(16 * root.d)
            color: tab.chosen ? Airisu.inkOnSeal : tab.dimmed ? Airisu.inkThirdOn(edge.stock) : edge.mark
        }
        AText {
            anchors.bottom: parent.bottom
            height: tab.line
            x: root.u(11)
            width: parent.width - x - (tab.found > 0 ? root.u(9) : root.u(3))
            verticalAlignment: Text.AlignVCenter
            voice: tab.chosen ? "figure" : "text"
            size: tab.chosen ? IrisStyle.typeHeadline : IrisStyle.typeLabel
            fontSizeMode: tab.chosen ? Text.HorizontalFit : Text.FixedSize
            minimumPixelSize: IrisStyle.typeLabel
            font.weight: tab.chosen ? Font.ExtraBold : Font.Medium
            color: tab.chosen ? Airisu.inkOnSeal : tab.dimmed ? Airisu.inkThirdOn(edge.stock) : edge.ink
            text: Translation.tr(tab.modelData.title)
        }
        AText {
            visible: tab.found > 0
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.rightMargin: root.u(4)
            height: tab.line
            verticalAlignment: Text.AlignVCenter
            voice: "data"
            size: IrisStyle.typeFootnote
            color: edge.ink
            text: String(tab.found)
        }
    }

    // A line of the contents: a group, General's welcome, or a link; captions name the engine's blocks, air parts them.
    // The group being read is set large in the figure voice with its glyph filled in the seal's ink, as its head is in the
    // rows.
    component ContentsEntry: MouseArea {
        id: entry
        required property var modelData
        readonly property string type: String(entry.modelData.type ?? "")
        readonly property bool row: entry.type === "group" || entry.type === "you" || entry.type === "link"
        readonly property bool chosen: root.host?.navSelected(entry.modelData) ?? false
        readonly property bool modified: entry.type === "group" && entry.modelData.rows !== undefined && (root.host?.modifiedIn(entry.modelData) ?? false)
        readonly property bool leaves: entry.type === "link" && !(root.host?.navHoldsPage(entry.modelData) ?? false)
        readonly property color stock: Airisu.ground
        width: parent ? parent.width : 0
        height: entry.type === "caption" ? root.u(8) : entry.type === "gap" ? root.u(3) : root.u(7)
        enabled: entry.row
        hoverEnabled: entry.row
        cursorShape: entry.row ? Qt.PointingHandCursor : Qt.ArrowCursor
        Accessible.role: entry.row ? Accessible.Button : Accessible.StaticText
        Accessible.name: label.text
        onClicked: root.host.openNav(entry.modelData)
        onChosenChanged: if (entry.chosen) contentsFollow.restart()

        Timer {
            id: contentsFollow
            interval: 0
            onTriggered: {
                const top = entry.y - root.u(7), bottom = entry.y + entry.height + root.u(7)
                const end = Math.max(0, contents.contentHeight - contents.height)
                if (top < contents.contentY) contents.contentY = Math.max(0, top)
                else if (bottom > contents.contentY + contents.height) contents.contentY = Math.min(end, bottom - contents.height)
            }
        }
        AText {
            visible: entry.type === "caption"
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.u(1.5)
            width: parent.width
            size: IrisStyle.typeFootnote
            font.weight: Font.Bold
            color: Airisu.inkSecond
            text: String(entry.modelData.text ?? "")
        }
        // The row's rung under the pointer, built only while the pointer is on it: forty empty shapes in the index cost
        // their first sync on every opening of Settings.
        Loader {
            anchors.fill: parent
            active: entry.row && !entry.chosen && (entry.containsMouse || entry.pressed)
            sourceComponent: ALacquer {
                lacquer: "transparent"
                coat: entry.pressed ? Airisu.underPlate(entry.stock) : Airisu.step(entry.stock, Airisu.hoverStep)
                share: 1
                travel: 0
                cut: Airisu.cutFor(height)
            }
        }
        MaterialSymbol {
            visible: entry.row && entry.type !== "you"
            x: root.u(2)
            anchors.verticalCenter: parent.verticalCenter
            text: root.host?.navGlyph(entry.modelData) ?? ""
            fill: entry.chosen ? 1 : 0
            iconSize: Math.round(16 * root.d)
            color: Airisu.sealText
        }
        MaterialSymbol {
            visible: entry.type === "you"
            x: root.u(2)
            anchors.verticalCenter: parent.verticalCenter
            text: "person"
            fill: entry.chosen ? 1 : 0
            iconSize: Math.round(15 * root.d)
            color: entry.chosen ? Airisu.inkOn(entry.stock) : Airisu.inkSecond
        }
        AText {
            id: label
            visible: entry.row
            x: root.u(9)
            // The name keeps what it needs; the answer takes the rest of the line and elides.
            width: Math.min(implicitWidth, parent.width - x - trail.width - root.u(3) - (answer.text.length > 0 ? root.u(16) : 0))
            anchors.verticalCenter: parent.verticalCenter
            voice: entry.chosen ? "figure" : "text"
            size: entry.chosen ? IrisStyle.typeTitle : IrisStyle.typeLabel
            font.weight: entry.chosen ? Font.ExtraBold : Font.Medium
            color: Airisu.ink
            text: entry.type === "you" ? (SystemInfo.displayName || SystemInfo.username)
                : String(entry.modelData.label ?? entry.modelData.title ?? "")
        }
        // What the group answers (its first value), as a catalogue's contents set the page beside each title.
        AText {
            id: answer
            visible: entry.row && text.length > 0
            anchors.left: label.right
            anchors.leftMargin: root.u(3)
            anchors.right: trail.left
            anchors.rightMargin: trail.width > 0 ? root.u(2) : 0
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            size: IrisStyle.typeFootnote
            font.weight: Font.Medium
            color: entry.chosen ? Airisu.ink : Airisu.inkSecond
            text: entry.type === "you" ? "" : (root.host?.navDetail(entry.modelData) ?? "")
        }
        Item {
            id: trail
            anchors.right: parent.right
            anchors.rightMargin: root.u(2)
            anchors.verticalCenter: parent.verticalCenter
            width: entry.leaves ? Math.round(15 * root.d) : entry.modified ? root.u(1.5) : 0
            height: Math.round(15 * root.d)
            // A group you changed: a square of its ink, never a second seal.
            Rectangle {
                visible: entry.modified && !entry.leaves
                anchors.centerIn: parent
                width: root.u(1.5)
                height: width
                color: entry.chosen ? Airisu.inkOn(entry.stock) : Airisu.inkSecond
            }
            MaterialSymbol {
                visible: entry.leaves
                anchors.centerIn: parent
                text: entry.modelData.page ? "chevron_right" : "arrow_outward"
                iconSize: Math.round(15 * root.d)
                color: entry.containsMouse ? Airisu.ink : Airisu.inkThird
            }
        }
    }

    // A key that is only its glyph (the head's way back and forth, the window, the way out).
    component GlyphKey: MouseArea {
        id: gk
        property string glyph
        property string name
        property bool available: true
        width: root.u(9)
        height: root.u(9)
        enabled: gk.available
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: gk.name
        AKey {
            id: gkKey
            anchors.fill: parent
            lacquer: "transparent"
            under: Airisu.ground
            available: gk.available
            hovered: gk.containsMouse
            pressed: gk.pressed
        }
        MaterialSymbol {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: gkKey.shift
            anchors.verticalCenterOffset: gkKey.shift
            text: gk.glyph
            iconSize: Math.round(18 * root.d)
            color: gk.available ? Airisu.ink : Airisu.inkThird
        }
    }

    // A key of words (the foot's actions, a notice's answers): quiet on the body, or the seal when it signs.
    component WordKey: MouseArea {
        id: wk
        property string glyph: ""
        property string label
        property bool sealed: false
        readonly property color stock: wk.sealed ? Airisu.seal : Airisu.ground
        width: words.implicitWidth + root.u(6)
        height: root.u(8)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: wk.label
        AKey {
            id: wkKey
            anchors.fill: parent
            lacquer: wk.sealed ? Airisu.seal : "transparent"
            under: Airisu.ground
            hovered: wk.containsMouse
            pressed: wk.pressed
        }
        Row {
            id: words
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: wkKey.shift
            anchors.verticalCenterOffset: wkKey.shift
            spacing: root.u(1.5)
            MaterialSymbol {
                visible: wk.glyph.length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: wk.glyph
                iconSize: Math.round(16 * root.d)
                color: Airisu.inkOn(wk.stock)
            }
            AText {
                anchors.verticalCenter: parent.verticalCenter
                size: IrisStyle.typeLabel
                font.weight: Font.DemiBold
                color: Airisu.inkOn(wk.stock)
                text: wk.label
            }
        }
    }
}
