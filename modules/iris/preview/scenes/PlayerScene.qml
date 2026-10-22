pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Widgets
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview.parts

PreviewScene {
    id: playerRoot
    subject: Qt.rect(playerCard.x, playerCard.y, playerCard.width, playerCard.height)
    readonly property var player: MprisController.activePlayer
    readonly property string art: String(MprisController.artUrlOf(playerRoot.player) ?? "")
    readonly property string cover: playerRoot.art.length > 0 ? playerRoot.art : playerRoot.wallpaper
    readonly property bool roundCover: playerRoot.opt("iris.player.roundCover", false)
    readonly property bool artBackground: playerRoot.opt("iris.player.artworkBackground", true)
    readonly property bool opensIsland: String(playerRoot.opt("iris.player.bubbleOpens", "card")) === "island"
    readonly property bool pinned: playerRoot.opt("iris.player.cardPinned", false)
    readonly property real naturalWidth: Math.round(560 * playerRoot.d)
    readonly property real naturalHeight: Math.round(290 * playerRoot.d)
    narrowest: Math.round(420 * playerRoot.d)
    lowest: Math.round(220 * playerRoot.d)
    // A Design that draws the player card shows its own here, on a stand-in of the record that plays (its keys do nothing).
    readonly property string cardUrl: IrisDesign.skin("mediaCard")
    readonly property var standIn: ({
        playback: ({ effectiveTitle: MprisController.titleOf(playerRoot.player) || Translation.tr("Song title"),
            effectiveArtist: MprisController.artistOf(playerRoot.player) || Translation.tr("Artist"),
            effectiveIsPlaying: MprisController.isPlaying, effectiveLength: MprisController.lengthOf(playerRoot.player) || 240,
            effectivePosition: MprisController.positionOf(playerRoot.player) || 92, effectiveCanSeek: false,
            effectiveCanGoNext: true, effectiveCanGoPrevious: true, displayedArtFilePath: String(playerRoot.cover ?? ""),
            togglePlaying: () => {}, next: () => {}, previous: () => {}, seek: () => {} }),
        player: playerRoot.player, hasPlayer: true, liveStream: false, hasTimeline: true, compact: false, overMedia: false,
        showPlayers: false, headerReserve: 0, emptyDetail: "", emptyIcon: "", offersOpen: false })
    Loader {
        id: designCard
        anchors.centerIn: parent
        width: Math.round(380 * playerRoot.d)
        active: playerRoot.cardUrl.length > 0
        source: playerRoot.cardUrl
        onLoaded: item.host = Qt.binding(() => playerRoot.standIn)
    }
    ClippingRectangle {
        id: playerCard
        visible: !designCard.item
        anchors.centerIn: parent
        width: Math.round(380 * playerRoot.d)
        height: Math.round(210 * playerRoot.d)
        radius: playerRoot.opensIsland ? IrisStyle.radius : IrisStyle.radiusSheet
        color: IrisStyle.bodySurface
        border.width: IrisStyle.rim.a > 0 ? 1 : 0
        border.color: IrisStyle.rim
        // A ClippingRectangle's children sit in its content item, which has no radius: name the card.
        IrisGlassEdge { anchors.fill: parent; z: 10; visible: IrisStyle.edgeLit && shown; radius: playerCard.radius }
        Image {
            id: artSource
            anchors.fill: parent
            anchors.margins: -40
            source: playerRoot.cover
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 240
            visible: false
        }
        MultiEffect {
            anchors.fill: artSource
            source: artSource
            visible: playerRoot.artBackground
            blurEnabled: true; blur: 1; blurMax: 48
            brightness: -0.25
        }
        Rectangle { anchors.fill: parent; visible: playerRoot.artBackground; color: IrisStyle.mediaScrim }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Math.round(18 * playerRoot.d)
            spacing: Math.round(10 * playerRoot.d)
            RowLayout {
                spacing: Math.round(14 * playerRoot.d)
                ClippingRectangle {
                    implicitWidth: Math.round(84 * playerRoot.d); implicitHeight: implicitWidth
                    radius: playerRoot.roundCover ? width / 2 : IrisStyle.radiusTile
                    Behavior on radius { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                    IrisImage { anchors.fill: parent; source: playerRoot.cover }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(2 * playerRoot.d)
                    IrisText { Layout.fillWidth: true; text: MprisController.titleOf(playerRoot.player) || Translation.tr("Song title"); color: playerRoot.artBackground ? IrisStyle.onMedia : IrisStyle.text; font.weight: IrisStyle.weight(Font.DemiBold); font.pixelSize: IrisStyle.typeHeadline; elide: Text.ElideRight }
                    IrisText { Layout.fillWidth: true; text: MprisController.artistOf(playerRoot.player) || Translation.tr("Artist"); color: playerRoot.artBackground ? IrisStyle.onMediaSecondary : IrisStyle.subtext; elide: Text.ElideRight }
                }
                MaterialSymbol { visible: playerRoot.pinned; Layout.alignment: Qt.AlignTop; text: "keep"; fill: 1; iconSize: Math.round(18 * playerRoot.d); color: playerRoot.artBackground ? IrisStyle.onMedia : IrisStyle.accent }
            }
            Item { Layout.fillHeight: true }
            Level { value: 0.38; tint: playerRoot.artBackground ? IrisStyle.onMedia : IrisStyle.text; color: playerRoot.artBackground ? IrisStyle.onMediaFill : IrisStyle.fill }
            IrisControlPlate {
                id: previewTransport
                Layout.alignment: Qt.AlignHCenter
                controlHeight: Math.round(32 * playerRoot.d)
                Row {
                    spacing: previewTransport.framed ? Math.round(4 * playerRoot.d) : Math.round(26 * playerRoot.d)
                    Repeater {
                        model: ["skip_previous", "pause", "skip_next"]
                        Item {
                            required property string modelData
                            width: Math.round(32 * playerRoot.d); height: width
                            MaterialSymbol { anchors.centerIn: parent; text: parent.modelData; fill: 1; iconSize: Math.round(24 * playerRoot.d); color: playerRoot.artBackground ? IrisStyle.onMedia : IrisStyle.text }
                        }
                    }
                }
            }
        }
    }
    Caption {
        glyph: playerRoot.opensIsland ? "pill" : "web_asset"
        text: (playerRoot.opensIsland ? Translation.tr("The media bubble opens the Island") : Translation.tr("The media bubble opens a card"))
            + (playerRoot.pinned ? " · " + Translation.tr("kept open") : "")
    }
}
