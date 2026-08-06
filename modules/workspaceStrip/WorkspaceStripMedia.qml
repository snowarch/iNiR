pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects as GE
import Quickshell.Services.Mpris
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.pill

// "Now playing" media flyout — the music-player analog of the reference.
// Shown when the media thumbnail is selected; reuses MprisController so it
// drives whatever player the rest of the shell tracks.
// Chrome matches WorkspaceStripDetail: Ricelin island card everywhere but zzz —
// filament seek thread, kanji play seal (奏/休) flanked by 前/次 skips.
PanelSurface {
    id: media

    // Ricelin island dialect opt-in (owned by the strip); false = the global
    // style's own PanelSurface card with the stock slider + transport.
    property bool islandChrome: false

    readonly property MprisPlayer player: MprisController.activePlayer
    readonly property bool isPlaying: player?.isPlaying ?? false
    readonly property bool _zzz: Appearance.zzzEverywhere
    readonly property real _progress: (player?.length ?? 0) > 0
        ? Math.max(0, Math.min(1, (player?.position ?? 0) / player.length)) : 0

    elevation: 2
    cardStyle: true
    borderless: islandChrome
    // Aurora stock dialect: frosted wallpaper behind the translucent card.
    wallpaperBackdrop: true
    implicitHeight: column.implicitHeight + 28

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
    }

    // Kanji skip control with icon fallback; hover warms it dim → cream.
    component KanjiSkip: Item {
        id: skip

        property bool can: false
        property string kanjiText: ""
        property string icon: ""
        signal activated()

        anchors.verticalCenter: parent.verticalCenter
        width: 26
        height: 26
        opacity: can ? 1 : 0.4
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: PillMotion.fast }
        }

        Text {
            visible: PillTheme.showGlyphs
            anchors.centerIn: parent
            text: skip.kanjiText
            font.family: PillTheme.fontJp
            font.pixelSize: 15
            color: skipArea.containsMouse ? PillTheme.cream : PillTheme.dim
            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: PillMotion.fast }
            }
        }
        MaterialSymbol {
            visible: !PillTheme.showGlyphs
            anchors.centerIn: parent
            text: skip.icon
            iconSize: 18
            color: skipArea.containsMouse ? PillTheme.cream : PillTheme.dim
        }

        MouseArea {
            id: skipArea
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            enabled: skip.can
            cursorShape: Qt.PointingHandCursor
            onClicked: skip.activated()
        }
    }

    IslandPanel {
        anchors.fill: parent
        visible: media.islandChrome
        z: -1
        glassEnabled: true
        glassScreenX: media.backdropScreenX
        glassScreenY: media.backdropScreenY
        glassScreenWidth: media.backdropScreenWidth
        glassScreenHeight: media.backdropScreenHeight
    }

    // Keep position fresh while playing (MPRIS doesn't push position ticks).
    Timer {
        running: media.visible && media.isPlaying && !seek.pressed && !seekArea.pressed
        interval: 1000
        repeat: true
        onTriggered: media.player?.positionChanged()
    }

    // Swallow clicks on the flyout body so interacting with it never bubbles to
    // the strip's dismiss handler. Controls sit above this and keep working.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: -1
    }

    Column {
        id: column
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 14
            rightMargin: 14
        }
        spacing: 10

        // Compact identity header. Playback state is an actual control rather
        // than a second tracked label competing with the title for width.
        Item {
            width: parent.width
            height: 54

            Item {
                id: artFrame
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }
                width: 54
                height: 54

                Rectangle {
                    id: artBg
                    anchors.fill: parent
                    radius: media._zzz ? Appearance.zzz.controlRadius : Appearance.rounding.small
                    color: Appearance.colors.colLayer2
                }
                Image {
                    id: art
                    anchors.fill: parent
                    source: MediaArtwork.displaySource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    smooth: true
                    mipmap: true
                    sourceSize.width: Math.round(width * 2)
                    sourceSize.height: Math.round(height * 2)
                    visible: status === Image.Ready && source.toString().length > 0
                    layer.enabled: true
                    layer.effect: GE.OpacityMask {
                        maskSource: Rectangle {
                            width: art.width
                            height: art.height
                            radius: artBg.radius
                        }
                    }
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "music_note"
                    iconSize: 24
                    color: Appearance.colors.colOnLayer2
                    visible: !art.visible
                    opacity: 0.7
                }
            }

            RippleButton {
                id: headerPlay
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: media._zzz
                    ? Appearance.zzz.controlRadius : Appearance.rounding.full
                enabled: media.player !== null
                colBackground: media._zzz
                    ? Appearance.zzz.bg3 : Appearance.colors.colLayer2
                colBackgroundHover: media._zzz
                    ? Appearance.zzz.bg4 : Appearance.colors.colLayer2Hover
                colRipple: media._zzz
                    ? Appearance.zzz.accent : Appearance.colors.colPrimary
                downAction: () => media.player?.togglePlaying()

                contentItem: MaterialSymbol {
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    fill: 1
                    text: media.isPlaying ? "pause" : "play_arrow"
                    iconSize: 18
                    color: media._zzz
                        ? Appearance.zzz.accent : Appearance.colors.colPrimary
                }

                StyledToolTip {
                    text: media.isPlaying
                        ? Translation.tr("Pause") : Translation.tr("Play")
                }
            }

            Column {
                anchors {
                    left: artFrame.right
                    right: headerPlay.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: 10
                    rightMargin: 10
                }
                spacing: 1

                StyledText {
                    width: parent.width
                    text: StringUtils.cleanMusicTitle(media.player?.trackTitle ?? "")
                        || Translation.tr("Unknown track")
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    maximumLineCount: 1
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.Bold
                    color: media._zzz
                        ? Appearance.zzz.onColor : Appearance.colors.colOnLayer1
                }
                StyledText {
                    width: parent.width
                    text: media.player?.trackArtist ?? ""
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    maximumLineCount: 1
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }
            }
        }

        // Internal structure by hairline, never outline — island signature.
        Rectangle {
            visible: media.islandChrome
            width: parent.width
            height: 1
            color: PillTheme.hairSoft
        }

        // Seek + times. Non-zzz gets the Ricelin filament: thread track, warm
        // gradient fill and a lit cap at the playhead; zzz keeps the stock slider.
        Column {
            width: parent.width
            spacing: 3

            StyledSlider {
                id: seek
                visible: !media.islandChrome
                width: parent.width
                enabled: media.player?.canSeek ?? false
                value: media._progress
                onMoved: if (media.player)
                    media.player.position = value * (media.player.length ?? 0)
            }

            Item {
                id: filamentSeek
                visible: media.islandChrome
                width: parent.width
                height: 14

                readonly property real frac: seekArea.pressed ? seekArea.dragFrac : media._progress

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    radius: height / 2
                    color: PillTheme.threadBg

                    Item {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: parent.width * filamentSeek.frac

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: PillTheme.vermDim }
                                GradientStop { position: 1.0; color: PillTheme.vermLit }
                            }
                        }
                        Rectangle {
                            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                            width: 2.5
                            radius: width / 2
                            color: PillTheme.flameCore
                        }
                    }
                }

                MouseArea {
                    id: seekArea
                    anchors.fill: parent
                    anchors.margins: -6
                    enabled: media.player?.canSeek ?? false
                    cursorShape: Qt.PointingHandCursor
                    property real dragFrac: 0
                    function fracAt(mx: real): real {
                        return Math.max(0, Math.min(1, (mx - 6) / Math.max(1, filamentSeek.width)))
                    }
                    onPressed: mouse => dragFrac = fracAt(mouse.x)
                    onPositionChanged: mouse => { if (pressed) dragFrac = fracAt(mouse.x) }
                    onReleased: if (media.player)
                        media.player.position = dragFrac * (media.player.length ?? 0)
                }
            }

            Item {
                width: parent.width
                height: elapsed.implicitHeight
                StyledText {
                    id: elapsed
                    anchors.left: parent.left
                    text: StringUtils.friendlyTimeForSeconds(seekArea.pressed
                        ? seekArea.dragFrac * (media.player?.length ?? 0)
                        : (media.player?.position ?? 0))
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.features: { "tnum": 1 }
                    color: Appearance.colors.colSubtext
                }
                StyledText {
                    anchors.right: parent.right
                    text: StringUtils.friendlyTimeForSeconds(media.player?.length ?? 0)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.features: { "tnum": 1 }
                    color: Appearance.colors.colSubtext
                }
            }
        }

        // Ricelin transport: 前 / play seal / 次. The seal is the hanko-style
        // stamp from the pill's media surface — warm gradient that saturates
        // while playing, kanji 奏/休 gated on the glyph switch.
        Row {
            visible: media.islandChrome
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 20

            KanjiSkip {
                kanjiText: "前"
                icon: "skip_previous"
                can: MprisController.canGoPreviousForPlayer(media.player)
                onActivated: MprisController.previousForPlayer(media.player)
            }

            Rectangle {
                id: seal
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 40
                radius: PillMotion.rSmall
                rotation: -1.5

                property real sat: media.isPlaying ? 1 : 0
                Behavior on sat {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: PillMotion.fast; easing.type: PillMotion.easeStandard }
                }

                opacity: (sealArea.enabled ? 1 : 0.4) * (0.75 + 0.25 * sat)
                border.width: 1
                border.color: Qt.alpha(PillTheme.vermLit, 0.4 + 0.3 * sat)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: media.mix(PillTheme.verm, PillTheme.tileBg, 0.55 - 0.27 * seal.sat) }
                    GradientStop { position: 1.0; color: media.mix(PillTheme.vermDeep, PillTheme.tileBg, 0.55 - 0.27 * seal.sat) }
                }

                Text {
                    visible: PillTheme.showGlyphs
                    anchors.centerIn: parent
                    text: media.isPlaying ? PillTheme.glyph("media") : PillTheme.glyph("mediaPaused")
                    color: PillTheme.bright
                    font.family: PillTheme.fontJp
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }
                MaterialSymbol {
                    visible: !PillTheme.showGlyphs
                    anchors.centerIn: parent
                    fill: 1
                    text: media.isPlaying ? "pause" : "play_arrow"
                    iconSize: 20
                    color: PillTheme.bright
                }

                MouseArea {
                    id: sealArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    enabled: media.player !== null
                    cursorShape: Qt.PointingHandCursor
                    onClicked: media.player?.togglePlaying()
                }
            }

            KanjiSkip {
                kanjiText: "次"
                icon: "skip_next"
                can: MprisController.canGoNextForPlayer(media.player)
                onActivated: MprisController.nextForPlayer(media.player)
            }
        }

        // Stock transport (every non-island dialect): round buttons on each
        // global style's own tokens.
        Row {
            visible: !media.islandChrome
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Repeater {
                model: [
                    { icon: "skip_previous", primary: false },
                    { icon: "__playpause", primary: true },
                    { icon: "skip_next", primary: false }
                ]

                RippleButton {
                    required property var modelData
                    readonly property bool isPlay: modelData.icon === "__playpause"
                    readonly property real size: isPlay ? 42 : 34
                    implicitWidth: size
                    implicitHeight: size
                    buttonRadius: isPlay
                        ? (media.isPlaying ? Appearance.rounding.normal : size / 2)
                        : size / 2
                    enabled: isPlay ? (media.player !== null)
                        : (modelData.icon === "skip_next"
                            ? MprisController.canGoNextForPlayer(media.player)
                            : MprisController.canGoPreviousForPlayer(media.player))
                    colBackground: isPlay
                        ? (media._zzz ? Appearance.zzz.accent : Appearance.colors.colPrimary)
                        : (media._zzz ? Appearance.zzz.bg3 : Appearance.colors.colLayer2)
                    colBackgroundHover: isPlay
                        ? (media._zzz ? Appearance.zzz.accent : Appearance.colors.colPrimaryHover)
                        : (media._zzz ? Appearance.zzz.bg4 : Appearance.colors.colLayer2Hover)
                    downAction: () => {
                        if (modelData.icon === "__playpause") media.player?.togglePlaying()
                        else if (modelData.icon === "skip_next") MprisController.nextForPlayer(media.player)
                        else MprisController.previousForPlayer(media.player)
                    }

                    contentItem: MaterialSymbol {
                        horizontalAlignment: Text.AlignHCenter
                        fill: 1
                        iconSize: parent.isPlay ? Appearance.font.pixelSize.huge : Appearance.font.pixelSize.larger
                        text: parent.isPlay
                            ? (media.isPlaying ? "pause" : "play_arrow")
                            : modelData.icon
                        color: parent.isPlay
                            ? (media._zzz ? Appearance.zzz.onSticker : Appearance.colors.colOnPrimary)
                            : (media._zzz ? Appearance.zzz.onColor : Appearance.colors.colOnLayer2)
                    }
                }
            }
        }
    }
}
