pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.background
import qs.modules.iris.field as Field
import qs.modules.iris.preview.parts

// Texture is what the material is drawn as, so this shows three real bodies (the Island, a card and a panel) in one
// IrisField pass: Afterglow's key light, chrome bevel, bloom past the silhouette and signal, or Light leak's lit rims,
// spill and grain, come from the same shader the shell uses, and every row of the group moves them. The field takes this
// box as its output, so a leak's whole shape lands on it, and with the frame on the box's edge is the frame, the Island
// welded to it as on the desktop (Frame, and the shoulders, read here). Under Light leak the card is a desktop widget's
// plate (Widgets), and dragging anywhere in the box moves the light (Across, Up and down), the desktop following the
// drag. "Grade the wallpaper" and "Expose the wallpaper" put the real filter over the preview's own decoded wallpaper (no
// second decode): dust, bokeh, the film edge and the Polaroid develop show there. Solid leaves both plain, so the
// difference is the point.
PreviewScene {
    id: tex
    // Laid tight, so the bodies and the glow between them read at the head's size.
    readonly property real naturalWidth: Math.round(420 * tex.d)
    readonly property real naturalHeight: Math.round(210 * tex.d)
    readonly property bool lit: IrisStyle.afterglow
    readonly property string gradeLabel: Translation.tr(({ dusk: "Dusk", cyber: "Cyber", fog: "Fog", wallpaper: "Wallpaper" })[IrisStyle.afterglowGrade] ?? "Dusk")
    readonly property string leakLabel: Translation.tr(({ prism: "Prism", ember: "Ember", orchid: "Orchid", polaroid: "Polaroid", accent: "Accent", wallpaper: "Wallpaper" })[IrisStyle.leakGrade] ?? "Prism")
        + " · " + Translation.tr(({ lens: "Lens", burn: "Burn", orbs: "Orbs", beam: "Beam" })[IrisStyle.leakShapeName] ?? "Lens")

    readonly property real side: Math.round(20 * tex.d)
    readonly property real gap: Math.round(16 * tex.d)
    readonly property real bodyHeight: Math.round(92 * tex.d)
    readonly property bool framed: IrisFrame.framed
    readonly property real band: tex.framed ? IrisFrame.band : 0
    // Framed, the Island hangs from the band as it does on the desktop: its top (and its round top corners) runs up past
    // the box, so only the shoulders where it meets the band show.
    readonly property var island: ({ x: Math.round((tex.width - 150 * tex.d) / 2), y: tex.framed ? -IrisFrame.islandBand : Math.round(14 * tex.d),
        width: Math.round(150 * tex.d), height: IrisFrame.islandBand + (tex.framed ? IrisFrame.islandBand + tex.band : 0) })
    readonly property real rowY: tex.island.y + tex.island.height + tex.gap
    readonly property bool widgetCard: IrisStyle.leak
    readonly property var card: ({ x: tex.side, y: tex.rowY, width: Math.round(204 * tex.d), height: tex.bodyHeight })
    readonly property var panel: ({ x: tex.card.x + tex.card.width + tex.gap, y: tex.rowY, width: tex.width - 2 * tex.side - tex.card.width - tex.gap, height: tex.bodyHeight })

    // The grade or the exposure over the wallpaper, exactly as the desktop and the lock lay it. The filter hides its
    // source, which is this preview's wallpaper, so the filtered copy stands in for it only while it is on.
    Loader {
        anchors.fill: parent
        active: IrisStyle.afterglowWallpaper || IrisStyle.leakWallpaper
        sourceComponent: IrisStyle.leak ? leakFilter : afterglowFilter
    }
    Component {
        id: afterglowFilter
        IrisAfterglowWallpaper {
            source: tex.wallpaperView
            live: false
        }
    }
    Component {
        id: leakFilter
        IrisLeakWallpaper {
            source: tex.wallpaperView
            live: false
        }
    }

    Field.IrisField {
        anchors.fill: parent
        framed: tex.framed
        shapes: [
            { id: "island", x: tex.island.x, y: tex.island.y, width: tex.island.width, height: tex.island.height,
                radius: IrisFrame.islandBand / 2, fuse: IrisStyle.fuse, paints: true, joins: "frame" },
            { id: "panel", x: tex.panel.x, y: tex.panel.y, width: tex.panel.width, height: tex.panel.height,
                radius: IrisStyle.radiusPlate, fuse: IrisStyle.fuse, paints: true }
        ].concat(tex.widgetCard ? [] : [{ id: "card", x: tex.card.x, y: tex.card.y, width: tex.card.width, height: tex.card.height,
                radius: IrisStyle.radiusPlate, fuse: IrisStyle.fuse, paints: true }])
    }

    // Under Light leak the card is a desktop widget: its own plate of the same film, as Widgets sets it.
    Loader {
        x: tex.card.x
        y: tex.card.y
        width: tex.card.width
        height: tex.card.height
        active: tex.widgetCard
        sourceComponent: Field.IrisLeakPlate {
            at: Qt.point(tex.card.x, tex.card.y)
            output: Qt.size(tex.width, tex.height)
            radius: IrisStyle.radiusPlate
            strength: IrisStyle.leakWidgets
        }
    }

    IrisClock {
        x: tex.island.x + Math.round((tex.island.width - width) / 2)
        y: tex.island.y + tex.island.height - IrisFrame.islandBand + Math.round((IrisFrame.islandBand - height) / 2)
        pixelSize: IrisStyle.typeHeadline
        separatorColor: IrisStyle.secondaryAccent
    }

    Column {
        id: cardContent
        readonly property int pad: IrisStyle.concentricPad(IrisStyle.radiusPlate, 14 * tex.d)
        x: tex.card.x + cardContent.pad
        y: tex.card.y + Math.round((tex.card.height - height) / 2)
        width: tex.card.width - 2 * cardContent.pad
        spacing: Math.round(12 * tex.d)
        Row {
            spacing: Math.round(10 * tex.d)
            Rectangle {
                width: Math.round(36 * tex.d); height: width
                radius: IrisStyle.iconRadius(width); color: IrisStyle.fill
                MaterialSymbol { anchors.centerIn: parent; text: "music_note"; fill: 1; iconSize: Math.round(18 * tex.d); color: IrisStyle.textSecondary }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                IrisText { text: Translation.tr("Now playing"); font.weight: IrisStyle.weight(Font.DemiBold); font.pixelSize: IrisStyle.typeLabel }
                IrisText { text: Translation.tr("Artist"); color: IrisStyle.muted; font.pixelSize: IrisStyle.typeMeta }
            }
        }
        Rectangle {
            width: parent.width; height: Math.max(2, Math.round(4 * tex.d)); radius: height / 2
            color: IrisStyle.fill
            Rectangle { width: parent.width * 0.42; height: parent.height; radius: parent.radius; color: IrisStyle.accent }
        }
    }

    Grid {
        id: panelContent
        readonly property int pad: IrisStyle.concentricPad(IrisStyle.radiusPlate, 14 * tex.d)
        readonly property real cell: Math.floor((tex.panel.width - 2 * panelContent.pad - panelContent.spacing) / 2)
        x: tex.panel.x + panelContent.pad
        y: tex.panel.y + Math.round((tex.panel.height - height) / 2)
        columns: 2
        spacing: Math.round(8 * tex.d)
        Repeater {
            model: ["wifi", "bluetooth", "dark_mode", "do_not_disturb_on"]
            Rectangle {
                id: tile
                required property int index
                required property string modelData
                width: panelContent.cell
                height: Math.round(34 * tex.d)
                radius: IrisStyle.radiusTile
                color: tile.index === 0 ? IrisStyle.tintFill(IrisStyle.accent) : IrisStyle.fill
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: tile.modelData; fill: 1; iconSize: Math.round(18 * tex.d)
                    color: tile.index === 0 ? IrisStyle.accent : IrisStyle.textSecondary
                }
            }
        }
    }

    // Drag the light: it follows the pointer while held (the desktop with it), and the place is written once on release.
    readonly property point leakBase: Qt.point(IrisStyle.leakSources[0].at[0], IrisStyle.leakSources[0].at[1])
    DragHandler {
        id: lightDrag
        target: null
        enabled: IrisStyle.leak
        function held(): point {
            const at = lightDrag.centroid.position
            const clamp = v => Math.max(-0.5, Math.min(0.5, v))
            return Qt.point(clamp(at.x / Math.max(1, tex.width) - tex.leakBase.x), clamp(at.y / Math.max(1, tex.height) - tex.leakBase.y))
        }
        onCentroidChanged: if (lightDrag.active) IrisStyle.leakHeld = lightDrag.held()
        onActiveChanged: {
            if (lightDrag.active) {
                IrisStyle.leakHeld = lightDrag.held()
                return
            }
            const at = IrisStyle.leakHeld
            if (at)
                Config.setNestedValues({ "iris.appearance.leak.x": Math.round(at.x * 100), "iris.appearance.leak.y": Math.round(at.y * 100) })
            IrisStyle.leakHeld = null
        }
        onCanceled: IrisStyle.leakHeld = null
    }
    HoverHandler {
        id: lightHover
        enabled: IrisStyle.leak
    }
    // Where the light sits, shown while the pointer is over the box: a ring to take hold of.
    Rectangle {
        readonly property real size: Math.round(18 * tex.d)
        visible: IrisStyle.leak && (lightHover.hovered || lightDrag.active)
        x: Math.round(Math.max(0, Math.min(tex.width, (tex.leakBase.x + IrisStyle.leakOffsetX) * tex.width)) - size / 2)
        y: Math.round(Math.max(0, Math.min(tex.height, (tex.leakBase.y + IrisStyle.leakOffsetY) * tex.height)) - size / 2)
        width: size
        height: size
        radius: size / 2
        color: "transparent"
        border.width: Math.max(2, Math.round(2 * tex.d))
        border.color: IrisStyle.onMedia
        Rectangle {
            anchors.centerIn: parent
            width: Math.round(parent.width / 3)
            height: width
            radius: width / 2
            color: IrisStyle.onMedia
        }
    }

    Caption {
        glyph: tex.lit ? "flare" : IrisStyle.leak ? "camera_roll" : "crop_square"
        text: tex.lit ? Translation.tr("Afterglow") + " · " + tex.gradeLabel
            : IrisStyle.leak ? Translation.tr("Light leak") + " · " + tex.leakLabel : Translation.tr("Solid")
    }
}
