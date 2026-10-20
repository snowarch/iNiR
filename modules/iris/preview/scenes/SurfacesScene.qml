pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.services
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview.parts

// One small body per surface, each with its own corners and its own glass or solid, resolved the way the real surface
// resolves them (IrisStyle.surfaceRadius with that surface's usual fallback, IrisStyle.surfaceGlass), over the wallpaper.
PreviewScene {
    id: surfaces
    // Laid tight, so the labels read at the head's size.
    readonly property real naturalWidth: Math.round(460 * surfaces.d)
    readonly property real naturalHeight: Math.round(270 * surfaces.d)
    narrowest: Math.round(360 * surfaces.d)
    lowest: Math.round(200 * surfaces.d)
    readonly property int columns: 4
    readonly property real margin: Math.round(16 * surfaces.d)
    readonly property real gap: Math.round(10 * surfaces.d)
    readonly property real cellWidth: (surfaces.width - 2 * surfaces.margin - (surfaces.columns - 1) * surfaces.gap) / surfaces.columns
    // The caption keeps the bottom strip.
    readonly property real cellHeight: (surfaces.height - surfaces.margin - Math.round(52 * surfaces.d) - 2 * surfaces.gap) / 3
    // The island's open corners and the menus' density change what these tiles resolve: re-read them here.
    readonly property string menusDensity: String(surfaces.opt("iris.appearance.surfaces.menus.density", "compact"))
    readonly property var tiles: [
        { id: "island", label: Translation.tr("Island") },
        { id: "cards", label: Translation.tr("Cards") },
        { id: "controlCenter", label: Translation.tr("Control Center") },
        { id: "panels", label: Translation.tr("Side panels") },
        { id: "spotlight", label: Translation.tr("Spotlight") },
        { id: "orbit", label: Translation.tr("Orbit") },
        { id: "settings", label: Translation.tr("Settings") },
        { id: "menus", label: Translation.tr("Menus") },
        { id: "gallery", label: Translation.tr("Wallpaper gallery") },
        { id: "osd", label: Translation.tr("Volume and song pill") }
    ]

    // The radius each real surface passes as its fallback (see where it calls IrisStyle.surfaceRadius).
    function fallbackRadius(id: string, height: real): real {
        switch (id) {
        case "island": return IrisStyle.openedRadius(IrisStyle.barShape, Math.max(IrisStyle.radius, Math.round(30 * surfaces.d)))
        case "cards": return IrisStyle.radiusSheet
        case "panels": return IrisStyle.radius
        case "menus": return surfaces.menusDensity === "regular" ? IrisStyle.radiusCard : IrisStyle.radiusTile
        case "osd": return IrisStyle.pieceRadius(height)
        default: return IrisStyle.radiusPanel
        }
    }

    // One body: wallpaper frost with the tint over it, or the solid paper, and the shadow a floating body casts.
    component Tile: Item {
        id: tile
        required property PreviewScene scene
        required property string surface
        required property string label
        // What the real surface passes as its corners fallback.
        required property real fallback
        // Re-read when the rows of this surface change.
        readonly property string materialRow: String(tile.scene.opt("iris.appearance.surfaces." + tile.surface + ".material", ""))
        readonly property real radiusRow: Number(tile.scene.opt("iris.appearance.surfaces." + tile.surface + ".radius", 0))
        readonly property string resolved: { tile.materialRow; return IrisStyle.surfaceGlass(tile.surface) }
        readonly property bool glass: tile.resolved === "solid" ? false : tile.resolved === "inherit" ? IrisStyle.glassy : true
        // A body never rounds past its own half height.
        readonly property real radius: {
            tile.radiusRow
            return Math.min(IrisStyle.surfaceRadius(tile.surface, tile.fallback), Math.min(tile.width, tile.height) / 2)
        }
        RectangularShadow {
            anchors.fill: plate
            radius: plate.radius
            offset.y: Math.round(3 * tile.scene.d)
            blur: Math.round(12 * tile.scene.d)
            color: IrisStyle.shadow
        }
        ClippingRectangle {
            id: plate
            anchors.fill: parent
            radius: tile.radius
            color: tile.glass ? "transparent" : IrisStyle.bodySurface
            border.width: !tile.glass && IrisStyle.rim.a > 0 ? 1 : 0
            border.color: IrisStyle.rim
            // Only the picture under this tile, with the blur's reach around it: ten tiles never blur ten scenes.
            ShaderEffectSource {
                id: frostSource
                readonly property real reach: IrisStyle.glassBlurMax
                x: -frostSource.reach; y: -frostSource.reach
                width: tile.width + 2 * frostSource.reach; height: tile.height + 2 * frostSource.reach
                visible: false
                sourceItem: tile.glass ? tile.scene.wallpaperView.textureItem : null
                sourceRect: Qt.rect(tile.x - frostSource.reach, tile.y - frostSource.reach, frostSource.width, frostSource.height)
                live: true
            }
            MultiEffect {
                anchors.fill: frostSource
                visible: tile.glass
                source: frostSource
                blurEnabled: true
                blur: IrisStyle.glassBlurAmount
                blurMax: IrisStyle.glassBlurMax
                saturation: IrisStyle.glassSaturation
            }
            Rectangle { anchors.fill: parent; visible: tile.glass; color: ColorUtils.applyAlpha(IrisStyle.surfaceOpaque, IrisStyle.glassTint) }
            IrisGlassEdge { anchors.fill: parent; visible: (tile.glass || IrisStyle.edgeLit) && shown; radius: plate.radius }
            IrisText {
                anchors.centerIn: parent
                width: parent.width - 2 * Math.round(8 * tile.scene.d)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: tile.label
                font.weight: IrisStyle.weight(Font.DemiBold)
                font.pixelSize: IrisStyle.typeMeta
            }
        }
    }

    Repeater {
        model: surfaces.tiles
        Tile {
            id: cell
            required property var modelData
            required property int index
            // The last row holds two tiles: centred under the others.
            readonly property int row: Math.floor(cell.index / surfaces.columns)
            readonly property int column: cell.index % surfaces.columns
            readonly property real rowShift: cell.row === 2 ? (surfaces.columns - (surfaces.tiles.length - 2 * surfaces.columns)) * (surfaces.cellWidth + surfaces.gap) / 2 : 0
            scene: surfaces
            surface: cell.modelData.id
            label: cell.modelData.label
            fallback: surfaces.fallbackRadius(cell.modelData.id, cell.height)
            x: Math.round(surfaces.margin + cell.column * (surfaces.cellWidth + surfaces.gap) + cell.rowShift)
            y: Math.round(surfaces.margin + cell.row * (surfaces.cellHeight + surfaces.gap))
            width: Math.round(surfaces.cellWidth)
            height: Math.round(surfaces.cellHeight)
        }
    }

    Caption {
        glyph: "dashboard"
        text: Translation.tr("Each surface, its own corners and glass")
    }
}
