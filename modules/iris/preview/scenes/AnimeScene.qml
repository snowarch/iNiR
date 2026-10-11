pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview.parts

// What the anime section shapes: the Airing card with as many episodes as you asked for, and an episode playing on with
// its subtitles at the size and height set below.
PreviewScene {
    id: animeRoot
    readonly property bool airing: animeRoot.opt("iris.bubbles.extras.anime.enable", false) === true
    readonly property bool watching: animeRoot.opt("iris.bubbles.extras.watching.enable", false) === true
    readonly property int shows: Math.max(1, Math.min(8, Number(animeRoot.opt("iris.anime.shows", 5))))
    readonly property real subtitleScale: Math.max(0.5, Math.min(2, Number(animeRoot.opt("iris.anime.subtitleScale", 100)) / 100))
    readonly property real subtitleHeight: Math.max(0.5, Math.min(1, Number(animeRoot.opt("iris.anime.subtitlePosition", 100)) / 100))
    readonly property var hues: [IrisStyle.identity.pink, IrisStyle.identity.purple, IrisStyle.identity.blue, IrisStyle.identity.teal,
        IrisStyle.identity.orange, IrisStyle.identity.indigo, IrisStyle.identity.red, IrisStyle.identity.green]
    readonly property real naturalWidth: Math.round(640 * animeRoot.d)
    readonly property real naturalHeight: Math.round(320 * animeRoot.d)

    Plate {
        id: airingCard
        surface: "cards"
        own: IrisStyle.identity.purple
        x: Math.round(24 * animeRoot.d)
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(parent.width * 0.44)
        height: airingColumn.implicitHeight + Math.round(24 * animeRoot.d)
        radius: IrisStyle.radiusPlate
        ColumnLayout {
            id: airingColumn
            // Off, the card keeps its body and says so; only what it would list steps back.
            opacity: animeRoot.airing ? 1 : 0.4
            x: Math.round(12 * animeRoot.d)
            y: Math.round(12 * animeRoot.d)
            width: parent.width - 2 * x
            spacing: Math.round(8 * animeRoot.d)
            Repeater {
                model: Math.min(animeRoot.shows, 4)
                RowLayout {
                    id: episode
                    required property int index
                    Layout.fillWidth: true
                    spacing: Math.round(10 * animeRoot.d)
                    Rectangle {
                        implicitWidth: Math.round(30 * animeRoot.d)
                        implicitHeight: Math.round(40 * animeRoot.d)
                        radius: IrisStyle.radiusChip
                        gradient: Gradient {
                            GradientStop { position: 0; color: IrisStyle.tileTop(animeRoot.hues[episode.index % animeRoot.hues.length]) }
                            GradientStop { position: 1; color: animeRoot.hues[episode.index % animeRoot.hues.length] }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Math.round(6 * animeRoot.d)
                        Rectangle { Layout.fillWidth: true; Layout.rightMargin: Math.round((8 + 14 * (episode.index % 3)) * animeRoot.d); implicitHeight: Math.round(8 * animeRoot.d); radius: height / 2; color: IrisStyle.text; opacity: 0.85 }
                        Rectangle { Layout.fillWidth: true; Layout.rightMargin: Math.round(48 * animeRoot.d); implicitHeight: Math.round(6 * animeRoot.d); radius: height / 2; color: IrisStyle.textTertiary }
                    }
                    IrisText {
                        text: (episode.index + 1) * 2 + " h"
                        color: IrisStyle.secondaryAccent
                        font.family: IrisStyle.fontNumbers
                        font.features: ({ "tnum": 1 })
                        font.weight: IrisStyle.weight(Font.DemiBold)
                    }
                }
            }
            IrisText {
                visible: animeRoot.shows > 4
                text: "+" + (animeRoot.shows - 4)
                color: IrisStyle.subtext
                font.pixelSize: IrisStyle.typeMeta
            }
        }
        OffState { visible: !animeRoot.airing; text: Translation.tr("Off") }
    }

    // An episode playing: a dark frame with its subtitles where and how large you set them.
    ClippingRectangle {
        id: player
        anchors.right: parent.right
        anchors.rightMargin: Math.round(24 * animeRoot.d)
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(parent.width * 0.42)
        height: Math.round(width * 9 / 16)
        radius: IrisStyle.radiusTile
        color: IrisStyle.veilHeavy
        IrisImage { anchors.fill: parent; source: animeRoot.wallpaper; opacity: animeRoot.watching ? 0.55 : 0.25 }
        IrisText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(player.height * animeRoot.subtitleHeight - height - 6 * animeRoot.d)
            text: Translation.tr("Continue")
            color: IrisStyle.onMedia
            style: Text.Outline
            styleColor: IrisStyle.veilHeavy
            font.pixelSize: Math.round(IrisStyle.typeLabel * animeRoot.subtitleScale)
            font.weight: IrisStyle.weight(Font.DemiBold)
        }
        OffState { visible: !animeRoot.watching; text: Translation.tr("Off") }
    }

    Caption {
        glyph: "live_tv"
        text: [Translation.tr("Episodes in the card") + " " + animeRoot.shows, Translation.tr("Subtitle size") + " " + Math.round(animeRoot.subtitleScale * 100) + "%"].join(" · ")
    }
}
