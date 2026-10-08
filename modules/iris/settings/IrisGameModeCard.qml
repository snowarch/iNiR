pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.components
import qs.modules.iris.style

Rectangle {
    id: card

    readonly property real d: IrisStyle.density
    readonly property bool on: GameMode.active
    readonly property var held: {
        Config.revision
        const game = Config.options?.gameMode ?? {}
        return [
            game.disableAnimations ?? true ? Translation.tr("animations") : "",
            game.disableEffects ?? true ? Translation.tr("blur") : "",
            game.suppressNotifications ?? true ? Translation.tr("banners") : "",
            game.disableNiriAnimations ?? true ? Translation.tr("Niri's motion") : "",
            game.disableVisualizers ?? true ? Translation.tr("visualizers") : ""
        ].filter(part => part.length > 0)
    }
    readonly property string state: GameMode.manuallyActivated ? Translation.tr("On until you turn it off")
        : GameMode.autoActivated ? Translation.tr("On while a window is fullscreen")
        : (Config.options?.gameMode?.autoDetect ?? true) ? Translation.tr("Off; it turns on by itself for fullscreen apps")
        : Translation.tr("Off")

    Layout.fillWidth: true
    implicitHeight: Math.round(96 * card.d)
    radius: IrisStyle.radiusTile
    color: card.on ? IrisStyle.tintFill(IrisStyle.identity.green) : IrisStyle.readingCard
    Behavior on color { ColorAnimation { duration: IrisStyle.duration(220); easing.type: IrisStyle.feedbackEasing } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 18 * card.d
        anchors.rightMargin: 18 * card.d
        spacing: 16 * card.d

        IrisSquircle {
            implicitWidth: Math.round(52 * card.d)
            implicitHeight: implicitWidth
            tint: card.on ? IrisStyle.identity.green : IrisStyle.identity.purple
            glyph: "sports_esports"
            glyphShare: 0.6
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3 * card.d
            IrisText {
                Layout.fillWidth: true
                text: Translation.tr("Game mode")
                font.family: IrisStyle.fontTitle
                font.pixelSize: IrisStyle.typeTitle
                font.weight: IrisStyle.weight(Font.DemiBold)
            }
            IrisText {
                Layout.fillWidth: true
                text: card.state
                color: IrisStyle.subtext
                font.pixelSize: IrisStyle.typeLabel
                elide: Text.ElideRight
            }
            IrisText {
                Layout.fillWidth: true
                visible: card.held.length > 0
                text: (card.on ? Translation.tr("Holding back %1") : Translation.tr("Holds back %1")).arg(card.held.join(", "))
                color: IrisStyle.muted
                font.pixelSize: IrisStyle.typeMeta
                elide: Text.ElideRight
            }
        }
        IrisButton {
            text: GameMode.manuallyActivated ? Translation.tr("Turn off") : GameMode.autoActivated ? Translation.tr("Keep it on") : Translation.tr("Turn on")
            emphasized: !GameMode.manuallyActivated
            quiet: GameMode.manuallyActivated
            buttonRadius: height / 2
            onClicked: GameMode.manuallyActivated ? GameMode.deactivate() : GameMode.activate()
        }
    }
}
