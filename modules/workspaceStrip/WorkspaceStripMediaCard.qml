pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects as GE
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.pill

// Compact landscape album-art entry at the head of the rail. The full square
// artwork belongs to the flyout; the rail keeps one stable rhythm throughout.
Item {
    id: card

    property bool selected: false
    property bool shown: false
    property bool isRight: true
    // Ricelin island dialect opt-in (owned by the strip).
    property bool islandChrome: false

    signal activated()

    readonly property var player: MprisController.activePlayer
    readonly property bool isPlaying: player?.isPlaying ?? false
    // Use the shared resolver: it caches a clean square copy of the art (incl.
    // YouTube Music thumbnails) instead of the raw, often tiny, MPRIS trackArtUrl
    // that scaled up blurry.
    readonly property string artUrl: MediaArtwork.displaySource

    readonly property bool _zzz: Appearance.zzzEverywhere
    readonly property real _radius: _zzz ? 0
        : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
        : Appearance.rounding.normal
    readonly property color _ringColor: _zzz
        ? ((isPlaying || selected) ? Appearance.zzz.accent : Appearance.zzz.hairlineStrong)
        : (isPlaying || selected) ? Appearance.colors.colPrimary
        : islandChrome ? PillTheme.border
        : Appearance.colors.colOutlineVariant

    readonly property real _progress: (player?.length ?? 0) > 0
        ? Math.max(0, Math.min(1, (player?.position ?? 0) / player.length)) : 0

    // Coarse position tick so the burn line crawls while the rail is open
    // (MPRIS doesn't push position changes on its own).
    Timer {
        running: card.shown && card.isPlaying
        interval: 2000
        repeat: true
        onTriggered: card.player?.positionChanged()
    }

    z: selected ? 10 : 1
    opacity: selected || isPlaying ? 1 : 0.85

    Behavior on opacity {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
    }

    StyledRectangularShadow {
        target: clipBox
        visible: card.selected && !card._zzz
            && (Appearance.angelEverywhere
                || (!Appearance.inirEverywhere && !Appearance.auroraEverywhere))
    }

    Rectangle {
        anchors.fill: parent
        visible: !card._zzz
        radius: card._radius
        color: card.selected ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2
        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
    }
    ZzzPlate {
        anchors.fill: parent
        visible: card._zzz
        fillColor: Appearance.zzz.bg2
        chamfer: card.selected ? Appearance.zzz.cutCorner : Appearance.zzz.cutCorner * 0.5
        chamferBottomRight: card.isRight && !Appearance.zzz.round
        chamferBottomLeft: !card.isRight && !Appearance.zzz.round
    }

    Item {
        id: clipBox
        anchors.fill: parent
        layer.enabled: card.shown
        layer.effect: GE.OpacityMask {
            maskSource: Item {
                width: clipBox.width
                height: clipBox.height
                visible: false
                Rectangle {
                    anchors.fill: parent
                    visible: !card._zzz
                    radius: card._radius
                    color: "white"
                }
                ZzzPlate {
                    anchors.fill: parent
                    visible: card._zzz
                    fillColor: "white"
                    chamfer: card.selected ? Appearance.zzz.cutCorner : Appearance.zzz.cutCorner * 0.5
                    chamferBottomRight: card.isRight && !Appearance.zzz.round
                    chamferBottomLeft: !card.isRight && !Appearance.zzz.round
                }
            }
        }

        Image {
            id: art
            anchors.fill: parent
            source: card.shown ? card.artUrl : ""
            asynchronous: true
            cache: false
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
            // Decode at the selected card size (×2 for crispness) so the album
            // art isn't upscaled from a thumbnail-sized decode.
            sourceSize.width: Math.round(card.width * 2)
            sourceSize.height: Math.round(card.height * 2)
            // Fade in instead of popping — consistent with workspace card preview.
            readonly property bool ready: status === Image.Ready && source.toString().length > 0
            visible: source.toString().length > 0
            opacity: ready ? 1 : 0
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: "music_note"
            iconSize: Math.round(Math.min(parent.width, parent.height) * 0.4)
            color: Appearance.colors.colOnLayer2
            visible: !art.ready
            opacity: 0.7
        }

        // Bottom scrim — keeps the play pip legible over bright album art.
        Rectangle {
            anchors.fill: parent
            visible: art.ready
            gradient: Gradient {
                GradientStop { position: 0.5; color: "transparent" }
                GradientStop { position: 1; color: ColorUtils.transparentize(Appearance.colors.colScrim, 0.45) }
            }
        }

        // Track-progress filament burning along the bottom edge while playing —
        // the card whispers where the song is without opening the flyout.
        Rectangle {
            visible: card.isPlaying
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: 2.5
            color: card._zzz ? Appearance.zzz.hairlineStrong : PillTheme.threadBg

            Item {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: parent.width * card._progress

                Rectangle {
                    anchors.fill: parent
                    visible: !card.islandChrome
                    color: card._zzz ? Appearance.zzz.accent : Appearance.colors.colPrimary
                }
                Rectangle {
                    anchors.fill: parent
                    visible: card.islandChrome
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: PillTheme.vermDim }
                        GradientStop { position: 1.0; color: PillTheme.vermLit }
                    }
                }
                Rectangle {
                    visible: card.islandChrome
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                    width: 2
                    color: PillTheme.flameCore
                }
            }
        }

        // Top sheen on the selected card — parity with the workspace cards.
        Rectangle {
            visible: card.islandChrome && card.selected
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 1
                leftMargin: card._radius * 0.6
                rightMargin: card._radius * 0.6
            }
            height: 1
            color: PillTheme.sheen
        }

        // Play-state pip so the card reads as media even with art loaded.
        Rectangle {
            anchors {
                left: card.isRight ? parent.left : undefined
                right: card.isRight ? undefined : parent.right
                bottom: parent.bottom
                margins: 6
            }
            width: 22
            height: 22
            radius: card._zzz ? Appearance.zzz.controlRadius : width / 2
            color: card._zzz
                ? (card.isPlaying ? Appearance.zzz.sticker : Appearance.zzz.bg4)
                : (card.isPlaying ? Appearance.colors.colPrimary
                    : ColorUtils.transparentize(Appearance.colors.colLayer3, 0.1))

            MaterialSymbol {
                anchors.centerIn: parent
                text: card.isPlaying ? "equalizer" : "play_arrow"
                fill: 1
                iconSize: 14
                color: card._zzz
                    ? (card.isPlaying ? Appearance.zzz.onSticker : Appearance.zzz.onColor)
                    : (card.isPlaying ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer3)
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: !card._zzz
        color: "transparent"
        radius: card._radius
        border.width: card.isPlaying ? 2 : (card.selected ? 1.5 : 1)
        border.color: card._ringColor
        Behavior on border.color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
    }
    ZzzPlate {
        anchors.fill: parent
        visible: card._zzz
        fillColor: "transparent"
        strokeColor: card._ringColor
        strokeWidth: card.isPlaying ? Appearance.zzz.hairlineThick : Appearance.zzz.hairline
        chamfer: card.selected ? Appearance.zzz.cutCorner : Appearance.zzz.cutCorner * 0.5
        chamferBottomRight: card.isRight && !Appearance.zzz.round
        chamferBottomLeft: !card.isRight && !Appearance.zzz.round
    }

    TapHandler { onTapped: card.activated() }
}
