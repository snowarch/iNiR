pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview
import qs.modules.iris.settings

// One area as Deck's hero card, built once and kept by Deck's AreaPool: its Dot title and line over its stage, then its
// groups, the first two open and the rest folded under their heads (their rows are built when they open).
Item {
    id: page
    required property string area
    property Item host
    property real shift: 0
    transform: Translate { y: page.shift }
    // Room the card's keys take at its top corner, and under the rows for the key bar.
    readonly property real reserve: Number(page.host?.scene?.heroReserve ?? 0)
    readonly property real footRoom: Number(page.host?.scene?.heroFoot ?? 0)

    readonly property real d: Number(page.host?.d ?? IrisStyle.settingsDensity)
    function u(n: real): int { return Math.round(n * page.d) }
    readonly property bool windowed: Boolean(page.host?.windowed ?? true)
    readonly property var entry: IrisOptions.sectionById(page.area) ?? ({})
    readonly property bool live: page.visible && page.area === String(page.host?.section ?? "")
    // An area that lands on one of iRiS's own pages (System on the Hub, when there is room) holds that page under its
    // head: its card is the page you get. A card of rows swapped for the Hub on landing read as the page jumping.
    readonly property int heldPage: Number(page.host?.landingPage?.(page.area, -1) ?? -1)
    readonly property bool whole: page.heldPage >= 0 ? held.status === Loader.Ready : rows.whole
    readonly property Item flick: page.heldPage >= 0 ? held.item : rowsFlick
    readonly property Item rowsRoot: page.heldPage >= 0 ? held.item : rows

    ClippingRectangle {
        id: hero
        width: page.width
        height: Math.round(Math.min(page.u(300), page.height * 0.36))
        radius: IrisStyle.fieldChamfer ? 0 : page.u(page.windowed ? 14 : 18)
        color: IrisStyle.readingCard
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; onWheel: wheel => page.host?.scene?.wheel?.(wheel) }
        DotTitle {
            id: dotTitle
            x: page.u(22)
            y: page.u(20)
            text: Translation.tr(String(page.entry.title ?? ""))
            size: page.u(page.windowed ? 34 : 40)
            fit: hero.width - x - page.reserve
        }
        IrisText {
            id: heroLine
            x: dotTitle.x
            anchors.top: dotTitle.bottom
            anchors.topMargin: page.u(8)
            width: hero.width - 2 * x
            elide: Text.ElideRight
            text: Translation.tr(String(page.entry.subtitle ?? ""))
            color: IrisStyle.muted
            font.pixelSize: IrisStyle.typeMeta
        }
        IrisGroupPreview {
            id: stage
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: stageLine.top
            anchors.top: heroLine.bottom
            anchors.margins: page.u(12)
            anchors.bottomMargin: page.u(8)
            radius: IrisStyle.fieldChamfer ? 0 : Math.max(IrisStyle.radiusRow, hero.radius - page.u(12))
            visible: stage.available
            standIn: true
            captionOutside: true
            playing: page.live
            section: page.area === "general" ? "" : page.area
            niriValue: (section, key) => IrisNiri.value(IrisOptions.settings.find(spec => spec.niri === section && spec.key === key) ?? { niri: section, key: key })
            niriRevision: IrisNiri.revision
        }
        // Home's stage is the welcome, not General's scene.
        Loader {
            active: page.area === "general"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.top: heroLine.bottom
            anchors.margins: page.u(12)
            sourceComponent: IrisWallpaperCard {
                stageHeight: parent?.height ?? 0
                stripShown: false
                screen: page.QsWindow.window?.screen ?? GlobalStates.focusedScreen
            }
        }
        // What the stage shows now, under it instead of on it.
        IrisText {
            id: stageLine
            x: page.u(16)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: page.u(10)
            width: hero.width - 2 * x
            height: stage.caption.length > 0 ? implicitHeight : 0
            elide: Text.ElideRight
            text: stage.caption
            color: IrisStyle.muted
            font.pixelSize: IrisStyle.typeMeta
        }
    }

    Loader {
        id: held
        y: hero.height + page.u(10)
        width: page.width
        height: page.height - y - page.footRoom
        active: page.heldPage >= 0
        source: page.heldPage >= 0 ? String(page.host?.pages?.[page.heldPage]?.component ?? "") : ""
    }

    Flickable {
        id: rowsFlick
        visible: page.heldPage < 0
        x: -page.u(4)
        y: hero.height + page.u(10)
        width: page.width + page.u(8)
        height: page.height - y - page.footRoom
        contentHeight: rows.implicitHeight + page.u(12)
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: IrisScrollBar {}
        AreaRows {
            id: rows
            width: rowsFlick.width
            section: page.area
            host: page.host
            voice: "deck"
            live: page.live
            folds: true
            onReveal: row => page.reveal(row)
        }
    }

    function showGroup(wanted: string): void {
        const lower = wanted.toLowerCase()
        const target = rows.targets().find(entry => entry.key === wanted || entry.key.toLowerCase() === lower)
        if (!target) return
        if (!(rows.opened[target.key] ?? false) && target.item.shut) rows.toggleGroup(target.key)
        page.glideTo(target.item.mapToItem(rowsFlick.contentItem, 0, 0).y - page.u(8))
    }
    function reveal(row: Item): void { page.glideTo(row.mapToItem(rowsFlick.contentItem, 0, 0).y - rowsFlick.height * 0.3) }
    function glideTo(y: real): void {
        glider.to = Math.max(0, Math.min(Math.max(0, rowsFlick.contentHeight - rowsFlick.height), y))
        glider.restart()
    }
    NumberAnimation { id: glider; target: rowsFlick; property: "contentY"; duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
}
