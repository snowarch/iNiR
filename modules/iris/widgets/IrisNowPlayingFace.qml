pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.mediaControls.components
import qs.modules.iris.style
import qs.modules.iris.components

IrisWidgetFace {
    id: root

    readonly property var player: MprisController.activePlayer
    readonly property bool hasPlayer: root.player !== null && root.player !== undefined
    readonly property bool playing: root.hasPlayer && media.effectiveIsPlaying
    readonly property bool restsWhenPaused: Boolean(root.widget.irisOption("rest", true))
    readonly property bool resting: !root.hasPlayer || (root.restsWhenPaused && !root.playing && restDelay.elapsed)
    readonly property string art: root.hasPlayer ? media.displayedArtFilePath : ""
    readonly property color artLight: IrisStyle.vividHighlight(media.colorQuantizer?.colors?.[0] ?? root.accent, root.accent)
    readonly property real progress: media.effectiveLength > 0 ? Math.min(1, media.effectivePosition / media.effectiveLength) : 0
    readonly property bool lyricsWanted: root.large && root.live && root.hasPlayer
        && Boolean(root.widget.irisOption("lyrics", true))
    readonly property bool lyricsReady: root.lyricsWanted && LyricsService.status === "ok" && LyricsService.lyricsLines.length > 0
    readonly property string source: {
        const identity = String(root.player?.identity || String(root.player?.desktopEntry ?? "").split(".").pop() || "")
        return identity.length > 0 ? identity.charAt(0).toUpperCase() + identity.slice(1) : Translation.tr("Music")
    }

    light: root.small || root.art.length === 0 ? (root.resting && !root.small ? IrisStyle.identity.pink : "transparent")
        : root.artLight
    padding: root.small && root.art.length > 0 ? 0 : root.dp(16)

    onLyricsWantedChanged: root.lyricsWanted ? LyricsService.subscribe() : LyricsService.unsubscribe()
    Component.onDestruction: if (root.lyricsWanted) LyricsService.unsubscribe()

    Timer {
        id: restDelay
        property bool elapsed: false
        interval: 30000
        running: root.hasPlayer && !root.playing
        onRunningChanged: if (running) elapsed = false
        onTriggered: elapsed = true
    }

    PlayerBase {
        id: media
        player: root.player
        positionUpdatesActive: root.live && root.playing && !root.small
    }

    component Transport: RowLayout {
        id: transport
        property real disc: root.dp(34)
        spacing: root.dp(6)
        FaceAction {
            face: root
            implicitWidth: transport.disc
            glyph: "skip_previous"
            name: Translation.tr("Previous")
            enabled: media.effectiveCanGoPrevious
            opacity: enabled ? 1 : 0.4
            onActivated: media.previous()
        }
        FaceAction {
            face: root
            implicitWidth: Math.round(transport.disc * 1.2)
            glyph: root.playing ? "pause" : "play_arrow"
            name: root.playing ? Translation.tr("Pause") : Translation.tr("Play")
            tint: root.playing ? root.onFill(root.accent) : root.ink
            color: root.playing ? root.accent : root.fill
            onActivated: media.togglePlaying()
        }
        FaceAction {
            face: root
            implicitWidth: transport.disc
            glyph: "skip_next"
            name: Translation.tr("Next")
            enabled: media.effectiveCanGoNext
            opacity: enabled ? 1 : 0.4
            onActivated: media.next()
        }
    }

    component Progress: Rectangle {
        implicitHeight: root.dp(4)
        radius: height / 2
        color: root.fill
        Rectangle {
            width: parent.width * root.progress
            height: parent.height
            radius: height / 2
            color: root.ink
        }
    }

    Item {
        id: rest
        anchors.fill: parent
        visible: root.resting
        readonly property real size: Math.round(Math.min(root.contentWidth, root.height - root.padding * 2)
            * (root.large ? 0.42 : root.medium ? 0.72 : 0.6))
        readonly property bool paused: root.hasPlayer
        readonly property bool cover: rest.paused && root.art.length > 0

        Item {
            id: restMark
            anchors.centerIn: parent
            width: rest.size
            height: rest.size
            scale: resume.pressed ? IrisStyle.pressScale(0.94) : 1
            Behavior on scale { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }

            Rectangle {
                id: tile
                anchors.fill: parent
                visible: !rest.cover
                radius: IrisStyle.iconRadius(width)
                readonly property color base: IrisStyle.identity.pink
                gradient: Gradient {
                    GradientStop { position: 0; color: IrisStyle.tileTop(tile.base) }
                    GradientStop { position: 1; color: tile.base }
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: rest.paused ? "pause" : "music_note"
                    fill: 1
                    iconSize: Math.round(parent.width * 0.56)
                    color: IrisStyle.onTint
                }
            }
            IrisArtwork {
                anchors.fill: parent
                visible: rest.cover
                source: root.art
                circular: false
                radius: IrisStyle.iconRadius(width)
            }
            Rectangle {
                anchors.fill: parent
                visible: rest.cover
                radius: IrisStyle.iconRadius(width)
                color: IrisStyle.veil
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "pause"
                    fill: 1
                    iconSize: Math.round(parent.width * 0.42)
                    color: IrisStyle.onMedia
                }
            }
        }
        MouseArea {
            id: resume
            anchors.fill: restMark
            enabled: rest.paused
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: media.togglePlaying()
        }
    }

    Item {
        anchors.fill: parent
        visible: !root.resting && root.small

        ClippingRectangle {
            anchors.fill: parent
            visible: root.art.length > 0
            radius: root.radius
            color: "transparent"
            IrisImage {
                anchors.fill: parent
                source: root.art
            }
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height * 0.62
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: IrisStyle.veilStrong }
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.art.length > 0 ? root.dp(14) : 0
            spacing: root.dp(1)
            IrisArtwork {
                visible: root.art.length === 0
                circular: false
                radius: root.innerRadius
                Layout.preferredWidth: root.dp(56)
                Layout.preferredHeight: root.dp(56)
            }
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.fillWidth: true
                spacing: root.dp(8)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    FaceText {
                        face: root
                        Layout.fillWidth: true
                        text: media.effectiveTitle
                        color: IrisStyle.onMedia
                        size: 13
                        weight: Font.DemiBold
                    }
                    FaceText {
                        face: root
                        Layout.fillWidth: true
                        text: media.effectiveArtist
                        color: IrisStyle.onMediaSecondary
                        size: 11.5
                    }
                }
                FaceAction {
                    face: root
                    implicitWidth: root.dp(34)
                    glyph: root.playing ? "pause" : "play_arrow"
                    name: root.playing ? Translation.tr("Pause") : Translation.tr("Play")
                    tint: IrisStyle.onMedia
                    color: IrisStyle.onMediaFill
                    onActivated: media.togglePlaying()
                }
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        visible: !root.resting && root.medium
        spacing: root.dp(14)

        IrisArtwork {
            source: root.art
            circular: false
            radius: root.innerRadius
            Layout.preferredWidth: root.height - root.padding * 2
            Layout.preferredHeight: Layout.preferredWidth
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.dp(2)

            FaceText {
                face: root
                Layout.fillWidth: true
                text: root.source
                color: root.inkTertiary
                size: 11
                weight: Font.DemiBold
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                text: media.effectiveTitle
                size: 15
                weight: Font.DemiBold
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                text: media.effectiveArtist
                color: root.inkSecondary
                size: 12.5
            }
            Item { Layout.fillHeight: true }
            Progress {
                Layout.fillWidth: true
                visible: media.effectiveLength > 0
            }
            Transport {
                Layout.topMargin: root.dp(6)
                disc: root.dp(32)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        visible: !root.resting && root.large
        spacing: root.dp(12)

        RowLayout {
            Layout.fillWidth: true
            spacing: root.dp(14)
            IrisArtwork {
                source: root.art
                circular: false
                radius: root.innerRadius
                Layout.preferredWidth: root.dp(root.lyricsReady ? 112 : 148)
                Layout.preferredHeight: Layout.preferredWidth
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: root.dp(2)
                FaceText {
                    face: root
                    Layout.fillWidth: true
                    text: root.source
                    color: root.inkTertiary
                    size: 11
                    weight: Font.DemiBold
                }
                FaceText {
                    face: root
                    Layout.fillWidth: true
                    text: media.effectiveTitle
                    size: 17
                    weight: Font.DemiBold
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                }
                FaceText {
                    face: root
                    Layout.fillWidth: true
                    text: media.effectiveArtist
                    color: root.inkSecondary
                    size: 13
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.dp(4)

            Item { Layout.fillHeight: true }
            FaceText {
                face: root
                Layout.fillWidth: true
                visible: root.lyricsWanted && LyricsService.status === "offline"
                text: Translation.tr("Lyrics need an internet connection")
                color: root.inkTertiary
                size: 12.5
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                visible: root.lyricsReady
                text: LyricsService.slots[2] ?? ""
                color: root.inkTertiary
                size: 12.5
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                text: LyricsService.slots[3] || "♪"
                visible: root.lyricsReady
                size: 16
                weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                visible: root.lyricsReady
                text: LyricsService.slots[4] ?? ""
                color: root.inkTertiary
                size: 12.5
            }
            Item { Layout.fillHeight: true }
        }

        Progress {
            Layout.fillWidth: true
            visible: media.effectiveLength > 0
        }
        RowLayout {
            Layout.fillWidth: true
            FaceText {
                face: root
                text: StringUtils.friendlyTimeForSeconds(media.effectivePosition)
                color: root.inkTertiary
                font.family: root.fontNumbers
                font.features: ({ "tnum": 1 })
                size: 11
            }
            Item { Layout.fillWidth: true }
            Transport { disc: root.dp(36) }
            Item { Layout.fillWidth: true }
            FaceText {
                face: root
                text: StringUtils.friendlyTimeForSeconds(media.effectiveLength)
                color: root.inkTertiary
                font.family: root.fontNumbers
                font.features: ({ "tnum": 1 })
                size: 11
            }
        }
    }
}
