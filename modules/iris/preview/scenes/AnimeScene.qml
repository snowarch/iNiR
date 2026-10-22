pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview.parts

// Anime: the two bubbles' cards, Airing with as many shows as it lists and Continue with its episode playing on;
// the colour layer washes the screen in its palette as strong as it is set.
PreviewScene {
    id: animeRoot
    readonly property real naturalWidth: Math.round(600 * animeRoot.d)
    readonly property real naturalHeight: Math.round(300 * animeRoot.d)
    narrowest: Math.round(420 * animeRoot.d)
    lowest: Math.round(240 * animeRoot.d)
    subject: Qt.rect(airing.x, airing.y, continueCard.x + continueCard.width - airing.x, airing.height)
    readonly property bool airingOn: animeRoot.opt("iris.bubbles.extras.anime.enable", false) === true
    readonly property bool continueOn: animeRoot.opt("iris.bubbles.extras.watching.enable", false) === true
    readonly property int shows: Math.max(1, Math.min(5, Number(animeRoot.opt("iris.anime.shows", 5))))
    readonly property bool wash: animeRoot.opt("iris.appearance.anime.enabled", false) === true
    readonly property string palette: String(animeRoot.opt("iris.appearance.anime.palette", "sakura"))
    readonly property real strength: Number(animeRoot.opt("iris.appearance.anime.strength", 60)) / 100
    readonly property var hues: ({
        "sakura": [IrisStyle.identity.pink, IrisStyle.identity.lavender],
        "neo-tokyo": [IrisStyle.identity.sky, IrisStyle.identity.pink],
        "unit-01": [IrisStyle.identity.purple, IrisStyle.identity.green],
        "magical-girl": [IrisStyle.identity.pink, IrisStyle.identity.yellow],
        "spirit-forest": [IrisStyle.identity.green, IrisStyle.identity.teal]
    })[animeRoot.palette] ?? [IrisStyle.identity.pink, IrisStyle.identity.lavender]
    property real t: 1
    Loop on t { running: animeRoot.playing; rest: 1600 }

    Rectangle {
        anchors.fill: parent
        opacity: animeRoot.wash ? 0.3 + 0.35 * animeRoot.strength : 0
        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(300); easing.type: IrisStyle.feedbackEasing } }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: animeRoot.hues[0] }
            GradientStop { position: 1; color: animeRoot.hues[1] }
        }
    }
    Plate {
        id: airing
        surface: "cards"
        x: Math.round(animeRoot.width * 0.07)
        y: Math.round(24 * animeRoot.d)
        width: Math.round(animeRoot.width * 0.44)
        height: Math.round(animeRoot.height * 0.7)
        radius: IrisStyle.radiusPlate
        opacity: animeRoot.airingOn ? 1 : 0.4
        Column {
            x: Math.round(14 * animeRoot.d); y: Math.round(12 * animeRoot.d)
            width: parent.width - 2 * x
            spacing: Math.round(8 * animeRoot.d)
            RowLayout {
                width: parent.width
                MaterialSymbol { text: "live_tv"; fill: 1; iconSize: Math.round(16 * animeRoot.d); color: IrisStyle.identity.purple }
                IrisText { Layout.fillWidth: true; text: Translation.tr("Airing"); font.weight: Font.DemiBold }
            }
            Repeater {
                model: animeRoot.shows
                RowLayout {
                    id: show
                    required property int index
                    width: parent?.width ?? 0
                    spacing: Math.round(8 * animeRoot.d)
                    opacity: 1 - show.index * 0.12
                    Rectangle { implicitWidth: Math.round(22 * animeRoot.d); implicitHeight: Math.round(28 * animeRoot.d); radius: Math.round(5 * animeRoot.d); color: [animeRoot.hues[0], animeRoot.hues[1], IrisStyle.identity.sky, IrisStyle.identity.orange, IrisStyle.identity.teal][show.index] }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Math.round(4 * animeRoot.d)
                        Rectangle { Layout.fillWidth: true; Layout.rightMargin: Math.round((show.index % 3) * 18 * animeRoot.d); implicitHeight: Math.round(6 * animeRoot.d); radius: height / 2; color: IrisStyle.fillStrong }
                        Rectangle { implicitWidth: Math.round(44 * animeRoot.d); implicitHeight: Math.round(5 * animeRoot.d); radius: height / 2; color: IrisStyle.fill }
                    }
                }
            }
        }
    }
    Plate {
        id: continueCard
        surface: "cards"
        x: airing.x + airing.width + Math.round(16 * animeRoot.d)
        y: airing.y
        width: Math.round(animeRoot.width * 0.36)
        height: Math.round(animeRoot.height * 0.5)
        radius: IrisStyle.radiusPlate
        opacity: animeRoot.continueOn ? 1 : 0.4
        Rectangle {
            x: Math.round(10 * animeRoot.d); y: x
            width: parent.width - 2 * x
            height: parent.height * 0.56
            radius: IrisStyle.radiusPlate - x
            gradient: Gradient {
                GradientStop { position: 0; color: animeRoot.hues[0] }
                GradientStop { position: 1; color: animeRoot.hues[1] }
            }
            MaterialSymbol { anchors.centerIn: parent; text: "play_circle"; fill: 1; iconSize: Math.round(30 * animeRoot.d); color: IrisStyle.onMedia }
        }
        Column {
            x: Math.round(14 * animeRoot.d)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(12 * animeRoot.d)
            width: parent.width - 2 * x
            spacing: Math.round(8 * animeRoot.d)
            IrisText { text: Translation.tr("Continue"); font.weight: Font.DemiBold; font.pixelSize: IrisStyle.typeMeta }
            Rectangle {
                width: parent.width
                height: Math.round(4 * animeRoot.d)
                radius: height / 2
                color: IrisStyle.fill
                Rectangle { width: parent.width * (0.25 + 0.5 * animeRoot.t); height: parent.height; radius: height / 2; color: IrisStyle.accent }
            }
        }
    }
    Caption {
        glyph: "live_tv"
        text: [animeRoot.airingOn ? Translation.tr("Airing on") : Translation.tr("Airing off"), animeRoot.continueOn ? Translation.tr("Continue on") : Translation.tr("Continue off"),
            animeRoot.wash ? Translation.tr("colour layer on") : ""].filter(part => part.length > 0).join(" · ")
    }
}
