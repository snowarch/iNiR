pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.frame
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.settings
import qs.modules.iris.pieces

// One theme as your own desktop would wear it: its frame, Island, a sheet and the Dock, plus the pieces
// you placed, where you placed them. Tapping it applies the theme; undo takes it back.
MouseArea {
    id: card

    required property var theme
    property var screen: GlobalStates.focusedScreen
    readonly property real d: IrisStyle.density
    readonly property var look: IrisThemes.swatch(card.theme)
    readonly property bool current: IrisThemes.activeId === card.theme.id
    readonly property bool mine: Boolean(card.theme.user)
    readonly property color body: card.look.glass ? Qt.alpha(card.look.surface, Math.max(0.42, card.look.tint)) : card.look.surface
    readonly property color line: Qt.alpha(IrisStyle.text, Math.min(0.4, 0.14 * card.look.lines))
    readonly property real s: card.look.shape
    readonly property string islandEdge: IrisFrame.islandEdge
    readonly property string dockEdge: IrisFrame.edges.includes(card.look.dockPosition) && card.look.dockPosition !== card.islandEdge
        ? card.look.dockPosition : IrisFrame.opposite(card.islandEdge)
    readonly property var extras: {
        Config.revision
        const all = Config.options?.iris?.bubbles?.extras ?? ({})
        return Object.keys(all).filter(id => all[id]?.enable && IrisPieces.available(id))
            .map(id => ({ id: id, place: String(all[id].place ?? "island"), fx: Number(all[id].fx ?? 0.5), fy: Number(all[id].fy ?? 0.5) }))
    }
    function sideways(edge: string): bool { return edge === "left" || edge === "right" }
    function piece(size: real): real {
        const scale = Math.max(0.6, card.s)
        return Math.min(size / 2, card.look.pieceShape === "square" ? size * 0.22 * scale
            : card.look.pieceShape === "squircle" ? size * 0.34 * scale : size / 2)
    }

    signal shareRequested()

    implicitHeight: scene.height + caption.implicitHeight + Math.round(10 * card.d)
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    Accessible.role: Accessible.Button
    Accessible.name: card.theme.name
    onClicked: IrisEditHistory.applyTheme(card.theme)

    ClippingRectangle {
        id: scene
        width: parent.width
        height: Math.round(width * 0.58)
        radius: IrisStyle.radiusTile
        color: IrisStyle.surfaceOpaque
        border.width: card.current ? 2 : 1
        border.color: card.current ? IrisStyle.accent : card.containsMouse ? IrisStyle.borderStrong : IrisStyle.border
        scale: card.pressed ? IrisStyle.pressScale(0.98) : 1
        Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }

        IrisImage {
            anchors.fill: parent
            source: WallpaperListener.wallpaperUrlForScreen(card.screen)
            opacity: 0.85
        }

        readonly property real band: card.look.framed ? Math.round(4 * card.d) : 0
        Rectangle {
            anchors.fill: parent
            visible: card.look.framed
            color: "transparent"
            border.width: scene.band
            border.color: card.body
            radius: IrisStyle.radiusTile
        }

        Rectangle {
            id: island
            readonly property bool vertical: card.sideways(card.islandEdge)
            readonly property bool menubar: card.look.layout === "menubar" && !island.vertical
            readonly property bool full: card.look.layout === "full" || card.look.layout === "menubar"
            readonly property real thick: Math.round((island.menubar ? 9 : 13) * card.d)
            readonly property real span: island.vertical ? parent.height : parent.width
            readonly property real length: island.full ? island.span - 2 * scene.band : Math.round(island.span * (island.vertical ? 0.5 : 0.36))
            readonly property real along: card.look.layout === "left" ? scene.band + Math.round(8 * card.d)
                : card.look.layout === "right" ? island.span - island.length - scene.band - Math.round(8 * card.d)
                : island.full ? scene.band : (island.span - island.length) / 2
            readonly property real inset: card.look.notch ? scene.band : scene.band + Math.round(4 * card.d)
            readonly property real across: card.islandEdge === "bottom" ? parent.height - island.thick - island.inset
                : card.islandEdge === "right" ? parent.width - island.thick - island.inset : island.inset
            readonly property bool flat: island.full || card.look.notch
            width: island.vertical ? island.thick : island.length
            height: island.vertical ? island.length : island.thick
            x: island.vertical ? island.across : island.along
            y: island.vertical ? island.along : island.across
            radius: island.full ? 0 : card.look.notch ? island.thick / 2 : card.piece(island.thick)
            topLeftRadius: island.flat && (card.islandEdge === "top" || card.islandEdge === "left") ? 0 : radius
            topRightRadius: island.flat && (card.islandEdge === "top" || card.islandEdge === "right") ? 0 : radius
            bottomLeftRadius: island.flat && (card.islandEdge === "bottom" || card.islandEdge === "left") ? 0 : radius
            bottomRightRadius: island.flat && (card.islandEdge === "bottom" || card.islandEdge === "right") ? 0 : radius
            color: island.menubar && card.look.clearStrip ? "transparent" : card.body
            border.width: card.look.rim && !card.look.notch ? 1 : 0
            border.color: card.line
            Grid {
                visible: !island.menubar
                anchors.centerIn: parent
                columns: island.vertical ? 1 : 3
                horizontalItemAlignment: Grid.AlignHCenter
                Text { text: "07"; color: IrisStyle.text; font.family: card.look.numbersFont; font.weight: card.look.figureWeight; font.pixelSize: Math.round(8 * card.d) }
                Text {
                    text: island.vertical ? "··" : ":"
                    lineHeight: island.vertical ? 0.5 : 1
                    color: card.look.clockAccent === "plain" ? IrisStyle.text : card.look.clockAccent === "accent" ? card.look.accent : card.look.highlight
                    font.family: card.look.numbersFont; font.weight: card.look.figureWeight; font.pixelSize: Math.round(8 * card.d)
                }
                Text { text: "08"; color: IrisStyle.text; font.family: card.look.numbersFont; font.weight: card.look.figureWeight; font.pixelSize: Math.round(8 * card.d) }
            }
        }

        Rectangle {
            visible: island.menubar
            readonly property real depth: Math.round(13 * card.d)
            width: Math.round(parent.width * 0.26)
            height: depth
            x: Math.round((parent.width - width) / 2)
            y: card.islandEdge === "bottom" ? island.y + island.height - depth : island.y
            radius: depth / 2
            topLeftRadius: card.islandEdge === "top" ? 0 : radius
            topRightRadius: card.islandEdge === "top" ? 0 : radius
            bottomLeftRadius: card.islandEdge === "bottom" ? 0 : radius
            bottomRightRadius: card.islandEdge === "bottom" ? 0 : radius
            color: card.body
            Text {
                anchors.centerIn: parent
                text: "07:08"
                color: IrisStyle.text
                font.family: card.look.numbersFont
                font.weight: card.look.figureWeight
                font.pixelSize: Math.round(8 * card.d)
            }
        }

        // Your pieces, in their zones. A zone the Island's corner takes starts beside it, as on screen.
        Repeater {
            model: card.extras
            Rectangle {
                id: mark
                required property var modelData
                required property int index
                readonly property real size: Math.round(9 * card.d)
                readonly property real pad: scene.band + Math.round(5 * card.d)
                readonly property var sameZone: card.extras.filter(entry => entry.place === mark.modelData.place)
                readonly property int order: mark.sameZone.findIndex(entry => entry.id === mark.modelData.id)
                readonly property real step: mark.size + Math.round(2 * card.d)
                readonly property string zone: mark.modelData.place
                readonly property bool onIslandRow: !island.vertical && ((card.islandEdge === "top" && mark.zone.startsWith("top"))
                    || (card.islandEdge === "bottom" && mark.zone.startsWith("bottom")))
                readonly property real rowY: mark.zone.startsWith("top") ? (mark.onIslandRow ? island.y + (island.height - mark.size) / 2 : mark.pad)
                    : mark.zone.startsWith("bottom") ? (mark.onIslandRow ? island.y + (island.height - mark.size) / 2 : scene.height - mark.pad - mark.size)
                    : (scene.height - mark.size) / 2
                readonly property real leftStart: mark.onIslandRow && !island.full && island.x < scene.width * 0.3 ? island.x + island.width + mark.step : mark.pad
                readonly property real rightStart: mark.onIslandRow && !island.full && island.x + island.width > scene.width * 0.7 ? island.x - mark.step : scene.width - mark.pad - mark.size
                visible: mark.zone !== "island" && !(island.full && mark.onIslandRow)
                width: mark.size
                height: mark.size
                radius: card.piece(mark.size)
                color: card.body
                border.width: card.look.rim ? 1 : 0
                border.color: card.line
                x: mark.zone.startsWith("edge:") || mark.zone === "free" ? Math.round(mark.modelData.fx * (scene.width - mark.size))
                    : mark.zone.endsWith("left") ? mark.leftStart + mark.order * mark.step
                    : mark.zone.endsWith("right") ? mark.rightStart - mark.order * mark.step
                    : (scene.width - mark.size) / 2
                y: mark.zone.startsWith("edge:top") ? mark.pad
                    : mark.zone.startsWith("edge:bottom") ? scene.height - mark.pad - mark.size
                    : mark.zone.startsWith("edge:") || mark.zone === "free" ? Math.round(mark.modelData.fy * (scene.height - mark.size))
                    : (mark.zone === "left" || mark.zone === "right") ? mark.rowY + (mark.order - (mark.sameZone.length - 1) / 2) * mark.step
                    : mark.rowY
                Rectangle { anchors.centerIn: parent; width: Math.round(3 * card.d); height: width; radius: width / 2; color: mark.index % 2 === 0 ? card.look.accent : card.look.highlight }
            }
        }

        Rectangle {
            id: sheet
            width: Math.round(parent.width * 0.44)
            height: Math.round(parent.height * 0.42)
            x: card.islandEdge === "right" || card.dockEdge === "right" ? scene.band + Math.round(22 * card.d)
                : parent.width - width - scene.band - Math.round(8 * card.d)
            y: card.islandEdge === "top" ? island.y + island.height + Math.round(10 * card.d)
                : card.islandEdge === "bottom" ? island.y - height - Math.round(10 * card.d)
                : Math.round(parent.height * 0.18)
            radius: Math.round(9 * Math.min(1.3, card.s) * card.d)
            color: card.body
            border.width: card.look.rim ? 1 : 0
            border.color: card.line
            Column {
                anchors.fill: parent
                anchors.margins: Math.round(7 * card.d)
                spacing: Math.round(4 * card.d)
                Text {
                    text: "Aa"
                    color: IrisStyle.text
                    font.family: card.look.titleFont
                    font.weight: IrisStyle.weight(Font.DemiBold)
                    font.pixelSize: Math.round(11 * card.d)
                }
                Rectangle { width: parent.width * 0.8; height: Math.round(4 * card.d); radius: height / 2; color: Qt.alpha(IrisStyle.text, 0.3) }
                Row {
                    spacing: Math.round(4 * card.d)
                    Rectangle { width: Math.round(18 * card.d); height: Math.round(8 * card.d); radius: card.piece(height); color: card.look.accent }
                    Rectangle { width: Math.round(8 * card.d); height: Math.round(8 * card.d); radius: card.piece(height); color: card.look.highlight }
                }
            }
        }

        Rectangle {
            id: dockMini
            readonly property bool vertical: card.sideways(card.dockEdge)
            readonly property real thick: Math.round(11 * card.d)
            readonly property real length: Math.round((dockMini.vertical ? parent.height * 0.6 : parent.width * 0.34))
            readonly property real inset: scene.band + (card.look.dockNotch ? 0 : Math.round(4 * card.d))
            width: dockMini.vertical ? dockMini.thick : dockMini.length
            height: dockMini.vertical ? dockMini.length : dockMini.thick
            x: card.dockEdge === "left" ? dockMini.inset : card.dockEdge === "right" ? parent.width - width - dockMini.inset : (parent.width - width) / 2
            y: card.dockEdge === "top" ? dockMini.inset : card.dockEdge === "bottom" ? parent.height - height - dockMini.inset : (parent.height - height) / 2
            radius: card.look.dockNotch ? dockMini.thick / 2 : card.piece(dockMini.thick)
            topLeftRadius: card.look.dockNotch && (card.dockEdge === "top" || card.dockEdge === "left") ? 0 : radius
            topRightRadius: card.look.dockNotch && (card.dockEdge === "top" || card.dockEdge === "right") ? 0 : radius
            bottomLeftRadius: card.look.dockNotch && (card.dockEdge === "bottom" || card.dockEdge === "left") ? 0 : radius
            bottomRightRadius: card.look.dockNotch && (card.dockEdge === "bottom" || card.dockEdge === "right") ? 0 : radius
            color: card.body
            Grid {
                anchors.centerIn: parent
                columns: dockMini.vertical ? 1 : 5
                spacing: Math.round(3 * card.d)
                Repeater {
                    model: 5
                    Rectangle {
                        required property int index
                        width: Math.round(6 * card.d); height: width
                        radius: Math.round(width * 0.26 * Math.min(1.2, card.s))
                        color: index === 1 ? card.look.accent : index === 3 ? card.look.highlight : Qt.alpha(IrisStyle.text, 0.45)
                    }
                }
            }
        }

        Rectangle {
            visible: card.current
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: Math.round(7 * card.d) + scene.band
            width: Math.round(18 * card.d)
            height: width
            radius: width / 2
            color: IrisStyle.accent
            MaterialSymbol { anchors.centerIn: parent; text: "check"; iconSize: Math.round(13 * card.d); color: IrisStyle.onAccent }
        }

        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Math.round(5 * card.d) + scene.band
            spacing: Math.round(2 * card.d)
            visible: card.containsMouse
            IrisIconButton { materialIcon: "ios_share"; Accessible.name: Translation.tr("Copy to share"); onClicked: card.shareRequested() }
            IrisIconButton { visible: card.mine; materialIcon: "delete"; Accessible.name: Translation.tr("Delete"); onClicked: IrisThemes.remove(card.theme.id) }
        }
    }

    ColumnLayout {
        id: caption
        anchors.top: scene.bottom
        anchors.topMargin: Math.round(6 * card.d)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Math.round(2 * card.d)
        spacing: 0
        IrisText {
            Layout.fillWidth: true
            text: card.theme.name
            font.family: card.look.titleFont
            font.pixelSize: IrisStyle.typeLabel
            font.weight: IrisStyle.weight(Font.DemiBold)
            elide: Text.ElideRight
        }
        IrisText {
            Layout.fillWidth: true
            text: card.mine ? (card.theme.description || (card.theme.author ? Translation.tr("by %1").arg(card.theme.author) : ""))
                : Translation.tr(card.theme.description)
            color: IrisStyle.textSecondary
            font.pixelSize: IrisStyle.typeFootnote
            maximumLineCount: 2
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
        }
    }
}
