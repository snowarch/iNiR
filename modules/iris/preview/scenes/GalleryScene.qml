pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview.parts

// The picker in the layout it opens in: the Reel's fan, the Mosaic's front and its five waiting, or the Browser's
// places, grid and inspector. The person's own wallpapers fill it and step by one while the scene plays.
PreviewScene {
    id: galleryRoot
    subject: Qt.rect(galleryPlate.x, galleryPlate.y, galleryPlate.width, galleryPlate.height)
    readonly property bool live: galleryRoot.opt("iris.wallpaper.livePreview", true)
    readonly property string layout: {
        const wanted = String(galleryRoot.opt("iris.wallpaper.layout", "reel"))
        return wanted === "wall" ? "browser" : ["reel", "mosaic", "browser"].includes(wanted) ? wanted : "reel"
    }
    readonly property var paths: {
        // The picker's listing holds its folders too; a folder is never a picture.
        const list = Array.from(Wallpapers.wallpapers ?? [])
            .filter(path => Wallpapers.extensions.includes(String(path).split(".").pop().toLowerCase()))
            .slice(0, 12)
        return list.length > 0 ? list : [galleryRoot.wallpaper]
    }
    readonly property var stills: galleryRoot.paths.map(path => Wallpapers.stillUrlFor(path) || galleryRoot.wallpaper)
    function still(k: int): string {
        const n = galleryRoot.stills.length
        return galleryRoot.stills[((galleryRoot.focusIndex + k) % n + n) % n] ?? ""
    }

    readonly property real u: galleryRoot.d
    readonly property real plateWidth: Math.round(900 * galleryRoot.u)
    readonly property real pad: Math.round(18 * galleryRoot.u)
    readonly property real gap: Math.round(10 * galleryRoot.u)
    readonly property real headHeight: Math.round(26 * galleryRoot.u)
    readonly property real stageTop: galleryRoot.pad + galleryRoot.headHeight + Math.round(14 * galleryRoot.u)
    readonly property real inner: galleryRoot.plateWidth - 2 * galleryRoot.pad

    // Every card as {k, x, y, w, h}: k is how far it stands from the chosen one.
    readonly property var cards: {
        const top = galleryRoot.stageTop
        if (galleryRoot.layout === "mosaic") {
            const heroH = Math.round((0.52083 * galleryRoot.inner - 0.25 * galleryRoot.gap) / 1.83333)
            const heroW = Math.round(heroH * 1.6)
            const sideX = galleryRoot.pad + heroW + galleryRoot.gap
            const side = galleryRoot.inner - heroW - galleryRoot.gap
            const medW = (side - galleryRoot.gap) / 2, smallW = (side - 2 * galleryRoot.gap) / 3
            const out = [{ k: 0, x: galleryRoot.pad, y: top, w: heroW, h: heroH }]
            for (let i = 0; i < 2; i++) out.push({ k: 1 + i, x: sideX + i * (medW + galleryRoot.gap), y: top, w: medW, h: medW / 1.6 })
            for (let i = 0; i < 3; i++) out.push({ k: 3 + i, x: sideX + i * (smallW + galleryRoot.gap), y: top + medW / 1.6 + galleryRoot.gap, w: smallW, h: smallW / 1.6 })
            return out
        }
        if (galleryRoot.layout === "browser") {
            const sideW = Math.round(150 * galleryRoot.u), inspectorW = Math.round(210 * galleryRoot.u)
            const gridX = galleryRoot.pad + sideW + galleryRoot.gap
            const gridW = galleryRoot.inner - sideW - inspectorW - 2 * galleryRoot.gap
            const cellW = (gridW - 3 * galleryRoot.gap) / 4, cellH = Math.round(cellW * 0.66)
            const out = []
            for (let i = 0; i < 12; i++)
                out.push({ k: i - 1, x: gridX + (i % 4) * (cellW + galleryRoot.gap), y: top + Math.floor(i / 4) * (cellH + galleryRoot.gap), w: cellW, h: cellH, ring: i === 1 })
            out.push({ k: 0, x: galleryRoot.plateWidth - galleryRoot.pad - inspectorW, y: top, w: inspectorW, h: Math.round(inspectorW / 1.6) })
            return out
        }
        // Reel: the chosen one in front, the rest tucked a quarter behind the one before, either side.
        const frontH = Math.round(220 * galleryRoot.u), frontW = Math.round(frontH * 1.6)
        const cx = galleryRoot.plateWidth / 2, cy = top + frontH / 2
        const out = [{ k: 0, x: cx - frontW / 2, y: top, w: frontW, h: frontH }]
        const sizes = [0.6, 0.4, 0.27]
        let right = cx + frontW / 2, left = cx - frontW / 2
        for (let i = 0; i < sizes.length; i++) {
            const w = frontW * sizes[i], h = frontH * sizes[i]
            out.push({ k: i + 1, x: right - 0.24 * w, y: cy - h / 2, w: w, h: h })
            out.push({ k: -(i + 1), x: left - 0.76 * w, y: cy - h / 2, w: w, h: h })
            right += 0.76 * w
            left -= 0.76 * w
        }
        return out
    }
    readonly property real stageBottom: galleryRoot.cards.reduce((low, card) => Math.max(low, card.y + card.h), 0)
    readonly property real naturalWidth: galleryRoot.plateWidth + Math.round(80 * galleryRoot.u)
    readonly property real naturalHeight: galleryPlate.height + Math.round(110 * galleryRoot.u)

    property int focusIndex: 0
    Timer {
        running: galleryRoot.playing
        interval: 1600
        repeat: true
        onTriggered: galleryRoot.focusIndex = (galleryRoot.focusIndex + 1) % Math.max(1, galleryRoot.stills.length)
    }
    IrisImage {
        anchors.fill: parent
        visible: galleryRoot.live
        source: galleryRoot.still(0)
    }
    Plate {
        id: galleryPlate
        surface: "gallery"
        own: IrisStyle.wallpaperLight
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(26 * galleryRoot.u)
        width: galleryRoot.plateWidth
        height: galleryRoot.stageBottom + Math.round(58 * galleryRoot.u)
        clip: true

        // The head: where it reads from, the search, the layout switch.
        Row {
            x: galleryRoot.pad; y: galleryRoot.pad
            spacing: Math.round(4 * galleryRoot.u)
            Repeater {
                model: [Translation.tr("Library"), Translation.tr("Favourites"), "Wallhaven"]
                Rectangle {
                    id: sourcePill
                    required property string modelData
                    required property int index
                    width: sourceLabel.implicitWidth + Math.round(20 * galleryRoot.u)
                    height: galleryRoot.headHeight
                    radius: height / 2
                    color: sourcePill.index === 0 ? IrisStyle.fillActive : "transparent"
                    IrisText {
                        id: sourceLabel
                        anchors.centerIn: parent
                        text: sourcePill.modelData
                        color: sourcePill.index === 0 ? IrisStyle.text : IrisStyle.subtext
                        font.pixelSize: IrisStyle.typeMeta
                        font.weight: IrisStyle.weight(Font.Medium)
                    }
                }
            }
        }
        Rectangle {
            x: galleryRoot.plateWidth - galleryRoot.pad - width - Math.round(90 * galleryRoot.u)
            y: galleryRoot.pad
            width: Math.round(220 * galleryRoot.u)
            height: galleryRoot.headHeight
            radius: height / 2
            color: IrisStyle.fillQuiet
            IrisText {
                anchors.verticalCenter: parent.verticalCenter
                x: Math.round(12 * galleryRoot.u)
                text: Translation.tr("Search")
                color: IrisStyle.muted
                font.pixelSize: IrisStyle.typeMeta
            }
        }
        Row {
            x: galleryRoot.plateWidth - galleryRoot.pad - width
            y: galleryRoot.pad
            spacing: Math.round(2 * galleryRoot.u)
            Repeater {
                model: ["view_carousel", "dashboard", "grid_view"]
                Rectangle {
                    id: layoutKey
                    required property string modelData
                    required property int index
                    width: galleryRoot.headHeight
                    height: galleryRoot.headHeight
                    radius: height / 2
                    color: ["reel", "mosaic", "browser"][layoutKey.index] === galleryRoot.layout ? IrisStyle.fillActive : "transparent"
                    MaterialSymbol { anchors.centerIn: parent; text: layoutKey.modelData; iconSize: Math.round(15 * galleryRoot.u); color: IrisStyle.subtext }
                }
            }
        }

        // The Browser's places down the left.
        Column {
            visible: galleryRoot.layout === "browser"
            x: galleryRoot.pad; y: galleryRoot.stageTop
            spacing: Math.round(10 * galleryRoot.u)
            Repeater {
                model: [Translation.tr("Wallpapers"), Translation.tr("Favourites"), "Wallhaven", Translation.tr("Live")]
                IrisText {
                    required property string modelData
                    required property int index
                    text: modelData
                    color: index === 0 ? IrisStyle.text : IrisStyle.subtext
                    font.pixelSize: IrisStyle.typeMeta
                    font.weight: IrisStyle.weight(index === 0 ? Font.DemiBold : Font.Normal)
                }
            }
        }

        Repeater {
            model: galleryRoot.cards
            ClippingRectangle {
                id: shot
                required property var modelData
                x: Math.round(shot.modelData.x); y: Math.round(shot.modelData.y)
                z: 100 - Math.abs(shot.modelData.k)
                width: Math.round(shot.modelData.w); height: Math.round(shot.modelData.h)
                radius: IrisStyle.concentric(IrisStyle.radiusPanel, galleryRoot.pad, IrisStyle.radiusTile) * Math.min(1, shot.width / (300 * galleryRoot.u) + 0.4)
                color: IrisStyle.fill
                border.width: shot.modelData.ring === true ? 2 : 0
                border.color: IrisStyle.accent
                IrisImage { anchors.fill: parent; source: galleryRoot.still(shot.modelData.k) }
            }
        }

        // What is chosen, under the stage: its name and the one action.
        IrisText {
            x: galleryRoot.layout === "browser" ? galleryRoot.plateWidth - galleryRoot.pad - Math.round(210 * galleryRoot.u) : galleryRoot.pad
            y: galleryRoot.layout === "browser" ? galleryRoot.stageTop + Math.round(210 / 1.6 * galleryRoot.u) + galleryRoot.gap
                : galleryRoot.stageBottom + Math.round(16 * galleryRoot.u)
            width: Math.round(200 * galleryRoot.u)
            elide: Text.ElideRight
            text: String(galleryRoot.paths[galleryRoot.focusIndex % galleryRoot.paths.length] ?? "").split("/").pop()
            font.family: IrisStyle.fontTitle
            font.pixelSize: IrisStyle.typeBody
            font.weight: IrisStyle.weight(Font.DemiBold)
        }
        Rectangle {
            x: galleryRoot.plateWidth - galleryRoot.pad - width
            y: galleryRoot.stageBottom + Math.round(14 * galleryRoot.u)
            visible: galleryRoot.layout !== "browser"
            width: applyLabel.implicitWidth + Math.round(24 * galleryRoot.u)
            height: Math.round(26 * galleryRoot.u)
            radius: height / 2
            color: IrisStyle.accent
            IrisText {
                id: applyLabel
                anchors.centerIn: parent
                text: Translation.tr("Apply")
                color: IrisStyle.inkOnAccent
                font.pixelSize: IrisStyle.typeMeta
                font.weight: IrisStyle.weight(Font.DemiBold)
            }
        }
    }
    Caption {
        anchors.bottom: undefined
        anchors.top: parent.top
        glyph: galleryRoot.live ? "preview" : "preview_off"
        text: galleryRoot.live ? Translation.tr("The desktop previews the chosen wallpaper") : Translation.tr("Wallpapers apply only when chosen")
    }
}
