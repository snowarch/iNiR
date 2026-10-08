pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style

Flow {
    id: root
    property var player: MprisController.activePlayer
    readonly property var players: (MprisController.displayPlayers ?? []).filter(p => p && p !== root.player)
    property color accent: IrisStyle.accent
    property bool overMedia: false
    visible: root.players.length > 0
    spacing: 6 * IrisStyle.density

    Repeater {
        model: root.players
        IrisButton {
            id: chip
            required property var modelData
            implicitHeight: Math.round(32 * IrisStyle.density)
            implicitWidth: chipRow.implicitWidth + Math.round(20 * IrisStyle.density)
            buttonRadius: height / 2
            buttonRadiusPressed: height / 2
            colBackground: root.overMedia ? IrisStyle.onMediaFill : IrisStyle.fillQuiet
            colBackgroundHover: root.overMedia ? IrisStyle.onMediaFillHover : IrisStyle.fillHover
            Accessible.name: Translation.tr("Control %1").arg(chip.modelData?.identity ?? "")
            onClicked: MprisController.setActivePlayer(chip.modelData)
            RowLayout {
                id: chipRow
                anchors.centerIn: parent
                spacing: 6 * IrisStyle.density
                IrisArtwork {
                    circular: true
                    Layout.preferredWidth: Math.round(20 * IrisStyle.density)
                    Layout.preferredHeight: Layout.preferredWidth
                    source: String(MprisController.artUrlOf(chip.modelData) ?? "")
                }
                IrisText {
                    text: String(MprisController.titleOf(chip.modelData) || chip.modelData?.identity || "")
                    color: root.overMedia ? IrisStyle.onMedia : IrisStyle.text
                    font.pixelSize: IrisStyle.typeMeta
                    font.weight: IrisStyle.weight(Font.Medium)
                    elide: Text.ElideRight
                    Layout.maximumWidth: Math.round(150 * IrisStyle.density)
                }
                MaterialSymbol {
                    fill: 1
                    text: chip.modelData?.isPlaying ? "graphic_eq" : "pause"
                    iconSize: 14 * IrisStyle.density
                    color: chip.modelData?.isPlaying ? root.accent : (root.overMedia ? IrisStyle.onMediaTertiary : IrisStyle.muted)
                }
            }
        }
    }
}
