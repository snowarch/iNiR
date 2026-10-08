pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.control
import qs.modules.iris.preview.parts

PreviewScene {
    id: ccRoot
    readonly property bool on: ccRoot.opt("iris.modules.controlCenter", true)
    readonly property bool fromIsland: String(ccRoot.opt("iris.controlCenter.opens", "island")) === "island"
    readonly property bool round: String(ccRoot.opt("iris.controlCenter.controls", "tiles")) === "round"
    readonly property real plateWidth: Math.max(320, Math.min(540, Number(ccRoot.opt("iris.controlCenter.width", 360)))) * ccRoot.d
    readonly property int columns: { ccRoot.rev; return IrisControlOptions.columns }
    readonly property var ids: { ccRoot.rev; return IrisControlOptions.gridModules }
    readonly property bool listed: { ccRoot.rev; return IrisControlOptions.modules.includes("notifications") }
    readonly property var packed: {
        ccRoot.rev
        const shapes = ({})
        for (const id of ccRoot.ids) shapes[id] = IrisControlOptions.shapeOf(id)
        return IrisControlOptions.pack(ccRoot.ids, shapes, ccRoot.columns)
    }
    readonly property real naturalWidth: ccRoot.plateWidth + Math.round(120 * ccRoot.d)
    readonly property real naturalHeight: ccPlate.y + ccPlate.height + Math.round(24 * ccRoot.d)
    readonly property bool cropBottom: true
    IslandPill {
        id: ccIsland
        anchors.horizontalCenter: parent.horizontalCenter
        y: IrisFrame.band
        opacity: ccRoot.fromIsland ? 0 : 1
    }
    Plate {
        id: ccPlate
        surface: "controlCenter"
        fallbackRadius: IrisStyle.radiusPanel
        opacity: ccRoot.on ? 1 : 0.35
        anchors.horizontalCenter: parent.horizontalCenter
        y: ccRoot.fromIsland ? IrisFrame.band : ccIsland.y + ccIsland.height + IrisFrame.bodyAir
        width: ccRoot.plateWidth
        height: ccColumn.implicitHeight + Math.round(28 * ccRoot.d)
        ColumnLayout {
            id: ccColumn
            x: Math.round(14 * ccRoot.d); y: Math.round(14 * ccRoot.d)
            width: parent.width - 2 * x
            spacing: Math.round(10 * ccRoot.d)
            IrisText { text: Translation.tr("Control Center"); font.weight: IrisStyle.weight(Font.DemiBold); font.pixelSize: IrisStyle.typeHeadline }
            Item {
                id: ccGrid
                readonly property real gap: Math.round(8 * ccRoot.d)
                readonly property real cell: (width - (ccRoot.columns - 1) * gap) / ccRoot.columns
                readonly property real unit: Math.round((ccRoot.opt("iris.controlCenter.labels", false) ? 70 : 64) * ccRoot.d)
                Layout.fillWidth: true
                implicitHeight: ccRoot.packed.rows * unit + Math.max(0, ccRoot.packed.rows - 1) * gap
                Repeater {
                    model: ccRoot.ids
                    Rectangle {
                        id: block
                        required property string modelData
                        required property int index
                        readonly property var spot: ccRoot.packed.placed[block.modelData]
                        readonly property string kind: IrisControlOptions.kindOf(block.modelData)
                        readonly property bool wide: !["media", "level", "levels", "platter"].includes(block.kind) && block.spot.w > 1
                        readonly property bool grouped: block.kind === "levels" || block.kind === "platter"
                        readonly property bool upright: block.spot.h > block.spot.w
                        x: Math.round(block.spot.col * (ccGrid.cell + ccGrid.gap))
                        y: Math.round(block.spot.row * (ccGrid.unit + ccGrid.gap))
                        width: Math.round(block.spot.w * ccGrid.cell + (block.spot.w - 1) * ccGrid.gap)
                        height: Math.round(block.spot.h * ccGrid.unit + (block.spot.h - 1) * ccGrid.gap)
                        radius: block.kind === "platter" || block.kind === "media" ? IrisStyle.radiusPlate
                            : !ccRoot.round ? IrisStyle.radiusTile : Math.min(width, height) / 2
                        color: block.kind === "levels" ? "transparent"
                            : block.index === 0 && block.kind === "toggle" && !block.wide ? IrisStyle.accent : IrisStyle.fillQuiet
                        clip: true
                        Grid {
                            visible: block.kind === "platter"
                            anchors.centerIn: parent
                            columns: block.spot.w > 2 ? 4 : 2
                            spacing: Math.round(10 * ccRoot.d)
                            Repeater {
                                model: IrisControlOptions.platterIds
                                Rectangle {
                                    required property string modelData
                                    required property int index
                                    width: Math.round(38 * ccRoot.d)
                                    height: width
                                    radius: width / 2
                                    color: index === 0 ? IrisStyle.accent : IrisStyle.fill
                                    MaterialSymbol { anchors.centerIn: parent; text: IrisControlOptions.glyphOf(parent.modelData); iconSize: Math.round(17 * ccRoot.d); color: parent.index === 0 ? IrisStyle.inkOnAccent : IrisStyle.text }
                                }
                            }
                        }
                        Row {
                            visible: block.kind === "levels"
                            anchors.centerIn: parent
                            spacing: Math.round(10 * ccRoot.d)
                            Repeater {
                                model: IrisControlOptions.levelIds
                                Rectangle {
                                    required property string modelData
                                    width: Math.round(Math.min(46 * ccRoot.d, (block.width - 20 * ccRoot.d) / 3))
                                    height: block.height
                                    radius: width / 2
                                    color: IrisStyle.fill
                                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: parent.height * 0.6; radius: parent.radius; color: IrisStyle.fillStrong }
                                    MaterialSymbol { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: Math.round(10 * ccRoot.d); text: IrisControlOptions.glyphOf(parent.modelData); iconSize: Math.round(15 * ccRoot.d); color: IrisStyle.surface }
                                }
                            }
                        }
                        Rectangle {
                            visible: block.kind === "level"
                            y: block.upright ? parent.height * 0.4 : 0
                            width: block.upright ? parent.width : parent.width * 0.6
                            height: block.upright ? parent.height * 0.6 : parent.height
                            radius: parent.radius
                            color: IrisStyle.fillStrong
                        }
                        MaterialSymbol {
                            visible: !block.wide && !block.grouped && block.kind !== "media"
                            x: block.kind === "level" && !block.upright ? Math.round(14 * ccRoot.d) : Math.round((parent.width - width) / 2)
                            y: block.kind === "level" && block.upright ? parent.height - height - Math.round(14 * ccRoot.d) : Math.round((parent.height - height) / 2)
                            text: IrisControlOptions.glyphOf(block.modelData)
                            iconSize: Math.round(18 * ccRoot.d)
                            color: block.kind === "level" ? IrisStyle.surface : block.index === 0 ? IrisStyle.inkOnAccent : IrisStyle.text
                        }
                        RowLayout {
                            visible: block.wide || block.kind === "media"
                            anchors.fill: parent
                            anchors.margins: Math.round(10 * ccRoot.d)
                            spacing: Math.round(8 * ccRoot.d)
                            Rectangle {
                                Layout.alignment: block.kind === "media" && block.spot.h > 1 && !(block.spot.w > 2) ? Qt.AlignTop : Qt.AlignVCenter
                                implicitWidth: Math.round(30 * ccRoot.d)
                                implicitHeight: implicitWidth
                                radius: width / 2
                                color: block.kind === "media" ? IrisStyle.fillActive : IrisStyle.accent
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: block.kind === "media" ? "music_note" : IrisControlOptions.glyphOf(block.modelData)
                                    iconSize: Math.round(16 * ccRoot.d)
                                    color: block.kind === "media" ? IrisStyle.subtext : IrisStyle.inkOnAccent
                                }
                            }
                            IrisText {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: block.kind === "media" ? (MprisController.titleOf(MprisController.activePlayer) || Translation.tr("Not playing"))
                                    : Translation.tr(IrisControlOptions.labelOf(block.modelData))
                                font.weight: IrisStyle.weight(Font.DemiBold)
                                font.pixelSize: IrisStyle.typeMeta
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                visible: ccRoot.listed
                implicitHeight: Math.round(52 * ccRoot.d)
                radius: IrisStyle.radiusPlate
                color: IrisStyle.fillQuiet
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Math.round(12 * ccRoot.d)
                    MaterialSymbol { text: "notifications"; iconSize: Math.round(17 * ccRoot.d); color: IrisStyle.subtext }
                    IrisText { Layout.fillWidth: true; text: Translation.tr("You're all caught up"); color: IrisStyle.subtext }
                }
            }
        }
    }
    OffState { visible: !ccRoot.on; text: Translation.tr("Control Center off") }
    Caption {
        glyph: ccRoot.fromIsland ? "pill" : "web_asset"
        text: (ccRoot.fromIsland ? Translation.tr("Becomes the Island's controls page") : Translation.tr("Hangs from the Island as a panel")) + " · " + (ccRoot.round ? Translation.tr("round") : Translation.tr("tiles"))
    }
}
