pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.shared.mediaControls.components
import qs.modules.iris.style
import qs.modules.iris.components

IrisWidgetFace {
    id: root

    readonly property var player: MprisController.activePlayer
    // What a Design's face (`widgetNowPlaying`) reads: the engine's playback, positions and lyrics stay here.
    readonly property alias playback: media
    designFace: IrisDesign.skin("widgetNowPlaying")
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
    // Large without lyrics wears the cover whole: beside the title it left a 180 px hole where the lines go.
    readonly property bool coverLarge: root.large && !root.resting && !root.lyricsReady && root.art.length > 0
    readonly property string source: {
        const identity = String(root.player?.identity || String(root.player?.desktopEntry ?? "").split(".").pop() || "")
        return identity.length > 0 ? identity.charAt(0).toUpperCase() + identity.slice(1) : Translation.tr("Music")
    }

    light: root.small || root.art.length === 0 ? "transparent"
        : root.artLight
    padding: (root.small && root.art.length > 0 && !root.resting) || root.coverLarge ? 0 : root.edgePad

    onLyricsWantedChanged: root.lyricsWanted ? LyricsService.subscribe(root) : LyricsService.unsubscribe(root)
    Component.onDestruction: if (root.lyricsWanted) LyricsService.unsubscribe(root)

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
        positionUpdatesActive: root.moving && root.playing && !root.small
    }

    component Transport: RowLayout {
        id: transport
        property real disc: root.dp(34)
        property bool overMedia: false
        spacing: root.dp(6)
        FaceAction {
            face: root
            implicitWidth: transport.disc
            tint: transport.overMedia ? IrisStyle.onMedia : root.ink
            color: transport.overMedia ? IrisStyle.onMediaFill : root.fill
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
            tint: root.playing ? root.onFill(root.accent) : transport.overMedia ? IrisStyle.onMedia : root.ink
            color: root.playing ? root.accent : transport.overMedia ? IrisStyle.onMediaFill : root.fill
            onActivated: media.togglePlaying()
        }
        FaceAction {
            face: root
            implicitWidth: transport.disc
            tint: transport.overMedia ? IrisStyle.onMedia : root.ink
            color: transport.overMedia ? IrisStyle.onMediaFill : root.fill
            glyph: "skip_next"
            name: Translation.tr("Next")
            enabled: media.effectiveCanGoNext
            opacity: enabled ? 1 : 0.4
            onActivated: media.next()
        }
    }

    component Progress: Rectangle {
        id: progressBar
        property bool overMedia: false
        implicitHeight: root.dp(4)
        radius: IrisStyle.capsule(height)
        color: progressBar.overMedia ? IrisStyle.onMediaFill : root.fill
        Rectangle {
            width: parent.width * root.progress
            height: parent.height
            radius: IrisStyle.capsule(height)
            color: progressBar.overMedia ? IrisStyle.onMedia : root.ink
        }
    }

    // The keys sit on the timeline's centre, the times pinned to its ends: fillers between two times of
    // different widths pushed the transport off by half their difference.
    component KeysRow: Item {
        id: keysRow
        property bool overMedia: false
        property real disc: root.dp(36)
        implicitHeight: keys.implicitHeight
        FaceText {
            face: root
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            visible: media.effectiveLength > 0
            text: StringUtils.friendlyTimeForSeconds(media.effectivePosition)
            color: keysRow.overMedia ? IrisStyle.onMediaSecondary : root.inkTertiary
            font.family: root.fontNumbers
            font.features: ({ "tnum": 1 })
            size: 11
        }
        Transport {
            id: keys
            anchors.centerIn: parent
            disc: keysRow.disc
            overMedia: keysRow.overMedia
        }
        FaceText {
            face: root
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: media.effectiveLength > 0
            text: StringUtils.friendlyTimeForSeconds(media.effectiveLength)
            color: keysRow.overMedia ? IrisStyle.onMediaSecondary : root.inkTertiary
            font.family: root.fontNumbers
            font.features: ({ "tnum": 1 })
            size: 11
        }
    }

    // At rest the face still says what it is: a record waiting on the platter when nothing plays, the paused cover with
    // its song and a play key when something waits. A lone app tile told nothing and filled a large face with air.
    component Record: Item {
        id: record
        property bool spins: false
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: IrisStyle.light && root.paper ? "#1b1b1d" : "#0d0d0f" // iris-literal: vinyl stays black in every scheme
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.07) // iris-literal: a record's grooves and sheen are the vinyl's, not the theme's
        }
        Repeater {
            model: [0.86, 0.74, 0.62]
            delegate: Rectangle {
                required property real modelData
                anchors.centerIn: parent
                width: Math.round(record.width * modelData)
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.05 + (0.86 - modelData) * 0.12) // iris-literal: a record's grooves and sheen are the vinyl's, not the theme's
            }
        }
        // the light that lies across a record
        Rectangle {
            anchors.centerIn: parent
            width: Math.round(record.width * 0.94)
            height: Math.max(1, Math.round(record.width * 0.06))
            rotation: -38
            radius: height / 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.3; color: Qt.rgba(1, 1, 1, 0.07) } // iris-literal: a record's grooves and sheen are the vinyl's, not the theme's
                GradientStop { position: 0.42; color: "transparent" }
                GradientStop { position: 0.58; color: "transparent" }
                GradientStop { position: 0.7; color: Qt.rgba(1, 1, 1, 0.07) } // iris-literal: a record's grooves and sheen are the vinyl's, not the theme's
                GradientStop { position: 1; color: "transparent" }
            }
        }
        Rectangle {
            id: label
            anchors.centerIn: parent
            width: Math.round(record.width * 0.38)
            height: width
            radius: width / 2
            color: root.nothing ? root.signal : root.inked(IrisStyle.identity.pink)
            MaterialSymbol {
                anchors.centerIn: parent
                text: "music_note"
                fill: 1
                iconSize: Math.round(label.width * 0.46)
                color: IrisStyle.onTintFor(label.color)
            }
        }
        Rectangle {
            anchors.centerIn: parent
            width: Math.max(3, Math.round(record.width * 0.035))
            height: width
            radius: width / 2
            color: "#0d0d0f" // iris-literal: the spindle hole
        }
    }

    component RestArt: Item {
        id: art
        Record {
            anchors.fill: parent
            visible: !rest.cover
        }
        IrisArtwork {
            anchors.fill: parent
            visible: rest.cover
            source: root.art
            circular: false
            radius: Math.max(root.dp(6), Math.round(width * 0.14))
        }
    }

    Item {
        id: rest
        anchors.fill: parent
        visible: root.resting
        readonly property bool paused: root.hasPlayer
        readonly property bool cover: rest.paused && root.art.length > 0
        readonly property string title: rest.paused ? (media.effectiveTitle || root.source) : Translation.tr("Not playing")
        readonly property string detail: rest.paused ? (media.effectiveArtist || root.source)
            : Translation.tr("Play something and it shows here")

        // Small: the art alone, its name under it.
        ColumnLayout {
            anchors.fill: parent
            visible: root.small
            spacing: root.dp(8)
            RestArt {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: true
                Layout.preferredWidth: height
                Layout.maximumWidth: rest.width
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: rest.title
                color: rest.paused ? root.ink : root.inkSecondary
                size: 12.5
                weight: Font.DemiBold
            }
        }

        // Medium: the art and what it is, the play key when something waits.
        RowLayout {
            anchors.fill: parent
            visible: root.medium
            spacing: root.dp(14)
            RestArt {
                Layout.fillHeight: true
                Layout.preferredWidth: height
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: root.dp(2)
                FaceHeader {
                    face: root
                    Layout.fillWidth: true
                    glyph: "music_note"
                    text: rest.paused ? root.source : Translation.tr("Music")
                    tint: root.inked(IrisStyle.identity.pink)
                }
                Item { Layout.fillHeight: true }
                FaceText {
                    face: root
                    Layout.fillWidth: true
                    text: rest.title
                    size: 15
                    weight: Font.DemiBold
                }
                FaceText {
                    face: root
                    Layout.fillWidth: true
                    text: rest.detail
                    color: root.inkSecondary
                    size: 12.5
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                }
                Transport {
                    visible: rest.paused
                    Layout.topMargin: root.dp(6)
                    disc: root.dp(30)
                }
            }
        }

        // Large: the art leads, the song under it.
        ColumnLayout {
            anchors.fill: parent
            visible: root.large
            spacing: root.dp(6)
            FaceHeader {
                face: root
                Layout.fillWidth: true
                glyph: "music_note"
                text: rest.paused ? root.source : Translation.tr("Music")
                tint: root.inked(IrisStyle.identity.pink)
            }
            RestArt {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: root.dp(4)
                Layout.fillHeight: true
                Layout.preferredWidth: height
                Layout.maximumWidth: rest.width
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                Layout.topMargin: root.dp(6)
                horizontalAlignment: Text.AlignHCenter
                text: rest.title
                size: 15
                weight: Font.DemiBold
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: rest.detail
                color: root.inkSecondary
                size: 12.5
            }
            Transport {
                visible: rest.paused
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: root.dp(4)
                disc: root.dp(32)
            }
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

    // Medium, as SekaiPop's media card: the plate washed in the cover's colour, the cover as a key (raised while it
    // plays, pressed flush when paused; click it to play or pause), the song with a chip that says what it is doing,
    // and the lane with its times at the ends and the keys on its centre.
    Rectangle {
        visible: !root.resting && root.medium && root.art.length > 0
        anchors.fill: parent
        anchors.margins: -root.padding
        radius: root.radius
        opacity: 0.5
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.alpha(root.artLight, 0.42) }
            GradientStop { position: 0.75; color: Qt.alpha(root.artLight, 0) }
        }
    }
    RowLayout {
        anchors.fill: parent
        visible: !root.resting && root.medium
        spacing: root.dp(14)

        Item {
            Layout.preferredWidth: root.height - root.padding * 2
            Layout.preferredHeight: Layout.preferredWidth
            IrisArtwork {
                id: mediumCover
                anchors.fill: parent
                source: root.art
                circular: false
                radius: root.innerRadius
                scale: coverTap.pressed ? 0.9 : root.playing ? 1 : 0.94
                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            }
            Rectangle {
                anchors.centerIn: parent
                visible: !root.playing
                width: root.dp(38)
                height: width
                radius: width / 2
                color: Qt.alpha(IrisStyle.scrim, 0.55)
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "play_arrow"
                    fill: 1
                    iconSize: root.px(24)
                    color: IrisStyle.onMedia
                }
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { id: coverTap; onTapped: media.togglePlaying() }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.dp(2)

            RowLayout {
                Layout.fillWidth: true
                spacing: root.dp(6)
                FaceText {
                    face: root
                    Layout.fillWidth: true
                    text: root.source
                    color: root.inkTertiary
                    size: 11
                    weight: Font.DemiBold
                }
                Rectangle {
                    implicitWidth: stateText.implicitWidth + root.dp(12)
                    implicitHeight: root.dp(18)
                    radius: height / 2
                    color: root.playing ? Qt.alpha(root.artLight, 0.3) : root.fillQuiet
                    Behavior on color { ColorAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                    FaceText {
                        id: stateText
                        face: root
                        anchors.centerIn: parent
                        text: root.playing ? Translation.tr("Playing") : Translation.tr("Paused")
                        size: 10
                        weight: Font.DemiBold
                        color: root.playing ? root.ink : root.inkSecondary
                    }
                }
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
            KeysRow {
                Layout.fillWidth: true
                Layout.topMargin: root.dp(4)
                disc: root.dp(30)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        visible: !root.resting && root.large && !root.coverLarge
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
        KeysRow {
            Layout.fillWidth: true
        }
    }

    Item {
        anchors.fill: parent
        visible: root.coverLarge

        ClippingRectangle {
            anchors.fill: parent
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
                height: parent.height * 0.6
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: IrisStyle.veilStrong }
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.edgePad
            spacing: root.dp(2)

            Item { Layout.fillHeight: true }
            FaceText {
                face: root
                Layout.fillWidth: true
                text: root.source
                color: IrisStyle.onMediaSecondary
                size: 11
                weight: Font.DemiBold
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                text: media.effectiveTitle
                color: IrisStyle.onMedia
                size: 19
                weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                text: media.effectiveArtist
                color: IrisStyle.onMediaSecondary
                size: 13
            }
            Progress {
                Layout.fillWidth: true
                Layout.topMargin: root.dp(12)
                overMedia: true
                visible: media.effectiveLength > 0
            }
            KeysRow {
                Layout.fillWidth: true
                Layout.topMargin: root.dp(8)
                overMedia: true
            }
        }
    }
}
