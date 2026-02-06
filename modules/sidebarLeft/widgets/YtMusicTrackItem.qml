pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

/**
 * Reusable track list item for YtMusic views.
 * Optimized for ListView performance - no heavy ripple effects.
 */
Rectangle {
    id: root

    required property var track
    property int trackIndex: -1
    property bool showIndex: false
    property bool showDuration: true
    property bool showRemoveButton: false
    property bool showAddToPlaylist: false
    property bool showAddToQueue: true

    readonly property bool isCurrentTrack: track?.videoId === YtMusic.currentVideoId
    readonly property bool hovered: mouseArea.containsMouse

    signal playRequested()
    signal removeRequested()
    signal addToPlaylistRequested()

    implicitHeight: 60
    radius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
    color: root.isCurrentTrack
        ? (Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainer
            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
            : Appearance.colors.colPrimaryContainer)
        : root.hovered
            ? (Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
                : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                : Appearance.colors.colLayer1Hover)
            : "transparent"

    Behavior on color {
        enabled: Appearance.animationsEnabled
        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.playRequested()
    }

    RowLayout {
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
                id: thumbImage
                anchors.fill: parent
                source: root.track?.thumbnail ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: 96
                sourceSize.height: 96
            }

            MaterialSymbol {
                anchors.centerIn: parent
                visible: thumbImage.status !== Image.Ready
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
                color: ColorUtils.transparentize("black", 0.2)
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

        // Action buttons - only show on hover for cleaner look
        Row {
            spacing: 2
            visible: root.hovered || root.isCurrentTrack

            // Add to playlist
            IconButton {
                visible: root.showAddToPlaylist
                icon: "playlist_add"
                tooltip: Translation.tr("Add to playlist")
                onClicked: root.addToPlaylistRequested()
            }

            // Add to queue
            IconButton {
                visible: root.showAddToQueue
                icon: "queue_music"
                tooltip: Translation.tr("Add to queue")
                onClicked: YtMusic.addToQueue(root.track)
            }

            // Remove
            IconButton {
                visible: root.showRemoveButton
                icon: "close"
                tooltip: Translation.tr("Remove")
                onClicked: root.removeRequested()
            }
        }
    }

    // Lightweight icon button without ripple
    component IconButton: Rectangle {
        property string icon
        property string tooltip
        property alias hovered: iconMouse.containsMouse
        signal clicked()

        width: 28; height: 28
        radius: 14
        color: hovered
            ? (Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover : Appearance.colors.colLayer2Hover)
            : "transparent"

        MaterialSymbol {
            anchors.centerIn: parent
            text: parent.icon
            iconSize: 18
            color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
        }

        MouseArea {
            id: iconMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }

        StyledToolTip { text: parent.tooltip }
    }
}
