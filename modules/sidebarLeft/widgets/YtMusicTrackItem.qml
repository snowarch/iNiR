pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

/**
 * Reusable track list item for YtMusic views.
 */
RippleButton {
    id: root
    
    required property var track
    property int trackIndex: -1
    property bool showIndex: false
    property bool showDuration: true
    property bool showRemoveButton: false
    property bool showAddToPlaylist: false
    property bool showAddToQueue: true
    
    readonly property bool isCurrentTrack: track?.videoId === YtMusic.currentVideoId
    
    signal playRequested()
    signal removeRequested()
    signal addToPlaylistRequested()
    
    implicitHeight: 60
    buttonRadius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
    colBackground: isCurrentTrack 
        ? (Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainer 
            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
            : Appearance.colors.colPrimaryContainer)
        : "transparent"
    colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer1Hover
    
    onClicked: root.playRequested()

    contentItem: RowLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 8

        // Index or playing indicator
        Item {
            visible: root.showIndex && root.trackIndex >= 0
            Layout.preferredWidth: visible ? 24 : 0
            Layout.preferredHeight: 24
            
            StyledText {
                anchors.centerIn: parent
                visible: !root.isCurrentTrack
                text: (root.trackIndex + 1).toString()
                font.pixelSize: Appearance.font.pixelSize.small
                font.family: Appearance.font.family.numbers
                color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
            }
            
            MaterialSymbol {
                anchors.centerIn: parent
                visible: root.isCurrentTrack
                text: YtMusic.isPlaying ? "equalizer" : "pause"
                iconSize: 18
                color: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
            }
        }

        // Thumbnail
        Rectangle {
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48
            radius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
            color: Appearance.inirEverywhere ? Appearance.inir.colLayer2
                : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                : Appearance.colors.colLayer2
            clip: true

            Image {
                anchors.fill: parent
                source: root.track?.thumbnail ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            MaterialSymbol {
                anchors.centerIn: parent
                visible: parent.children[0].status !== Image.Ready
                text: "music_note"
                iconSize: 20
                color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
            }

            // Duration badge
            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 2
                width: durText.implicitWidth + 6
                height: 14
                radius: 3
                color: "#CC000000"
                visible: root.showDuration && (root.track?.duration ?? 0) > 0

                StyledText {
                    id: durText
                    anchors.centerIn: parent
                    text: StringUtils.friendlyTimeForSeconds(root.track?.duration ?? 0)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.family: Appearance.font.family.numbers
                    color: "white"
                }
            }
        }

        // Info
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: root.track?.title ?? ""
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: root.isCurrentTrack ? Font.Bold : Font.Medium
                color: root.isCurrentTrack 
                    ? (Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                    : (Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer0)
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.track?.artist ?? ""
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
                elide: Text.ElideRight
                visible: text !== ""
            }
        }

        // Add to playlist
        RippleButton {
            visible: root.showAddToPlaylist
            implicitWidth: 28; implicitHeight: 28
            buttonRadius: 14
            colBackground: "transparent"
            colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover : Appearance.colors.colLayer2Hover
            onClicked: root.addToPlaylistRequested()
            contentItem: MaterialSymbol { anchors.centerIn: parent; text: "playlist_add"; iconSize: 18; color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext }
            StyledToolTip { text: Translation.tr("Add to playlist") }
        }

        // Add to queue
        RippleButton {
            visible: root.showAddToQueue
            implicitWidth: 28; implicitHeight: 28
            buttonRadius: 14
            colBackground: "transparent"
            colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover : Appearance.colors.colLayer2Hover
            onClicked: YtMusic.addToQueue(root.track)
            contentItem: MaterialSymbol { anchors.centerIn: parent; text: "queue_music"; iconSize: 18; color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext }
            StyledToolTip { text: Translation.tr("Add to queue") }
        }

        // Remove
        RippleButton {
            visible: root.showRemoveButton
            implicitWidth: 28; implicitHeight: 28
            buttonRadius: 14
            colBackground: "transparent"
            colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover : Appearance.colors.colLayer2Hover
            onClicked: root.removeRequested()
            contentItem: MaterialSymbol { anchors.centerIn: parent; text: "close"; iconSize: 18; color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext }
            StyledToolTip { text: Translation.tr("Remove") }
        }
    }
}
