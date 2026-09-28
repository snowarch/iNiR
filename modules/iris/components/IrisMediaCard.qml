pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.mediaControls.components
import qs.modules.iris.style

Item {
    id: root
    property var player: MprisController.activePlayer
    property bool compact: false
    property bool active: visible
    property bool showBackground: true
    property real headerReserve: 0
    property color tint: IrisStyle.text
    readonly property bool hasPlayer: root.player !== null && root.player !== undefined
    // A stream is live when it has no length, cannot seek while playing, or its end keeps running
    // away from a playhead that sits at it. Every sign is re-read, never latched: a browser that
    // sends a track's title before its length, or a seek that republishes metadata, must not leave
    // a normal video reading "Live" for the rest of the track.
    readonly property string trackKey: (root.player?.dbusName ?? "") + "\n" + media.effectiveTitle
    property real seenLength: 0
    property int grewSamples: 0
    property int atEndSamples: 0
    onTrackKeyChanged: { root.seenLength = 0; root.grewSamples = 0; root.atEndSamples = 0 }
    Timer {
        interval: 2000
        repeat: true
        running: root.active && root.hasPlayer && media.effectiveIsPlaying
        onTriggered: {
            const len = media.effectiveLength
            const pos = media.effectivePosition
            const atEdge = len > 0 && pos >= len - 1
            root.atEndSamples = atEdge ? root.atEndSamples + 1 : 0
            const grew = root.seenLength > 0 && len > root.seenLength + 1 && pos >= root.seenLength - 3
            root.grewSamples = grew ? root.grewSamples + 1 : 0
            if (len > 0) root.seenLength = len
        }
    }
    readonly property bool liveStream: root.hasPlayer
        && (media.effectiveLength <= 0
            || (media.effectiveIsPlaying && !media.effectiveCanSeek)
            || root.grewSamples >= 2
            || root.atEndSamples >= 2)
    readonly property bool hasTimeline: root.hasPlayer && !root.liveStream && media.effectiveLength > 0
    implicitHeight: (root.compact ? compactBody.implicitHeight : body.implicitHeight) + 28 * IrisStyle.density
    implicitWidth: 360 * IrisStyle.density
    PlayerBase { id: media; player: root.player; positionUpdatesActive: root.active }

    Item {
        anchors.fill: parent
        visible: root.showBackground
        Rectangle { anchors.fill: parent; radius: IrisStyle.radiusSmall; color: IrisStyle.surfaceHigh }
        Loader {
            anchors.fill: parent
            active: root.active && root.showBackground && (Config.options?.iris?.player?.artworkBackground ?? true)
                && media.displayedArtFilePath.length > 0
            sourceComponent: IrisMediaBackdrop { source: media.displayedArtFilePath; radius: IrisStyle.radiusSmall; strength: 0.5 }
        }
    }
    ColumnLayout {
        id: body
        visible: !root.compact
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14 * IrisStyle.density
        spacing: 12 * IrisStyle.density
        RowLayout {
            Layout.fillWidth: true
            Layout.rightMargin: root.headerReserve
            spacing: 14 * IrisStyle.density
            IrisArtwork {
                source: media.displayedArtFilePath
                circular: Config.options?.iris?.player?.roundCover ?? false
                Layout.preferredWidth: 68 * IrisStyle.density
                Layout.preferredHeight: 68 * IrisStyle.density
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                IrisText { Layout.fillWidth: true; text: root.hasPlayer ? media.effectiveTitle : Translation.tr("Nothing playing"); font.weight: IrisStyle.weight(Font.DemiBold); elide: Text.ElideRight }
                IrisText { Layout.fillWidth: true; text: root.hasPlayer ? media.effectiveArtist : Translation.tr("Your music appears here"); role: IrisText.Meta; elide: Text.ElideRight }
            }
        }
        IrisScrubber {
            id: timeline
            Layout.fillWidth: true
            Layout.bottomMargin: -8 * IrisStyle.density
            visible: root.hasTimeline
            seekable: media.effectiveCanSeek
            fillColor: root.tint
            trackColor: IrisStyle.tintFill(root.tint)
            value: media.effectiveLength > 0 ? Math.min(1, media.effectivePosition / media.effectiveLength) : 0
            onSeekRequested: next => media.seek(next * media.effectiveLength)
        }
        RowLayout {
            Layout.fillWidth: true
            visible: root.hasTimeline
            IrisText {
                text: StringUtils.friendlyTimeForSeconds(media.effectivePosition)
                color: IrisStyle.textTertiary
                font.pixelSize: IrisStyle.typeFootnote
                font.family: IrisStyle.fontNumbers
                font.features: ({ "tnum": 1 })
            }
            Item { Layout.fillWidth: true }
            IrisText {
                text: StringUtils.friendlyTimeForSeconds(media.effectiveLength)
                color: IrisStyle.textTertiary
                font.pixelSize: IrisStyle.typeFootnote
                font.family: IrisStyle.fontNumbers
                font.features: ({ "tnum": 1 })
            }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: root.hasPlayer && root.liveStream
            spacing: 6 * IrisStyle.density
            Rectangle {
                implicitWidth: Math.round(7 * IrisStyle.density)
                implicitHeight: implicitWidth
                radius: width / 2
                color: IrisStyle.danger
                SequentialAnimation on opacity {
                    running: media.effectiveIsPlaying && root.active
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                }
            }
            IrisText {
                text: Translation.tr("Live")
                color: IrisStyle.textSecondary
                font.pixelSize: IrisStyle.typeMeta
                font.weight: IrisStyle.weight(Font.DemiBold)
            }
            Item { Layout.fillWidth: true }
            IrisText {
                visible: media.effectivePosition > 0
                text: StringUtils.friendlyTimeForSeconds(media.effectivePosition)
                color: IrisStyle.textTertiary
                font.pixelSize: IrisStyle.typeFootnote
                font.family: IrisStyle.fontNumbers
                font.features: ({ "tnum": 1 })
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 4 * IrisStyle.density
            Item { Layout.fillWidth: true }
            IrisIconButton { materialIcon: "skip_previous"; Accessible.name: Translation.tr("Previous track"); enabled: media.effectiveCanGoPrevious; onClicked: media.previous() }
            IrisIconButton { materialIcon: media.effectiveIsPlaying ? "pause" : "play_arrow"; Accessible.name: media.effectiveIsPlaying ? Translation.tr("Pause") : Translation.tr("Play"); enabled: root.hasPlayer; onClicked: media.togglePlaying(); iconSize: 28 }
            IrisIconButton { materialIcon: "skip_next"; Accessible.name: Translation.tr("Next track"); enabled: media.effectiveCanGoNext; onClicked: media.next() }
            Item { Layout.fillWidth: true }
        }
    }

    RowLayout {
        id: compactBody
        visible: root.compact
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: 14 * IrisStyle.density
        spacing: 12 * IrisStyle.density
        IrisArtwork {
            source: media.displayedArtFilePath
            circular: Config.options?.iris?.player?.roundCover ?? false
            Layout.preferredWidth: 46 * IrisStyle.density
            Layout.preferredHeight: 46 * IrisStyle.density
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            IrisText { Layout.fillWidth: true; text: root.hasPlayer ? media.effectiveTitle : Translation.tr("Nothing playing"); font.weight: IrisStyle.weight(Font.DemiBold); elide: Text.ElideRight }
            IrisText { Layout.fillWidth: true; text: root.hasPlayer ? media.effectiveArtist : Translation.tr("Your music appears here"); role: IrisText.Meta; elide: Text.ElideRight }
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 5 * IrisStyle.density
                visible: root.hasTimeline
                implicitHeight: Math.max(2, Math.round(3 * IrisStyle.density))
                radius: height / 2
                color: IrisStyle.fill
                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    color: root.tint
                    width: parent.width * (media.effectiveLength > 0 ? Math.min(1, media.effectivePosition / media.effectiveLength) : 0)
                }
            }
        }
        IrisIconButton { materialIcon: "skip_previous"; Accessible.name: Translation.tr("Previous track"); enabled: media.effectiveCanGoPrevious; onClicked: media.previous() }
        IrisIconButton { materialIcon: media.effectiveIsPlaying ? "pause" : "play_arrow"; Accessible.name: media.effectiveIsPlaying ? Translation.tr("Pause") : Translation.tr("Play"); enabled: root.hasPlayer; onClicked: media.togglePlaying(); iconSize: 24 }
        IrisIconButton { materialIcon: "skip_next"; Accessible.name: Translation.tr("Next track"); enabled: media.effectiveCanGoNext; onClicked: media.next() }
    }
}
