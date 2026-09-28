pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models
import qs.services
import "root:"

Item {
    id: root
    implicitHeight: hasPlayer ? card.implicitHeight + Appearance.sizes.elevationMargin : 0
    visible: hasPlayer

    property MprisPlayer player: MprisController.activePlayer
    readonly property bool isYtMusicPlayer: MprisController.isYtMusicActive
    readonly property bool hasPlayer: (player && player.trackTitle) || (isYtMusicPlayer && YtMusic.currentVideoId)
    
    readonly property string effectiveTitle: isYtMusicPlayer ? YtMusic.currentTitle : (player?.trackTitle ?? "")
    readonly property string effectiveArtist: isYtMusicPlayer ? YtMusic.currentArtist : (player?.trackArtist ?? "")
    readonly property string effectiveArtUrl: isYtMusicPlayer ? YtMusic.currentThumbnail : (player?.trackArtUrl ?? "")
    readonly property real effectivePosition: isYtMusicPlayer ? YtMusic.currentPosition : MprisController.positionOf(player)
    readonly property real effectiveLength: isYtMusicPlayer ? YtMusic.currentDuration : MprisController.lengthOf(player)
    readonly property bool effectiveIsPlaying: isYtMusicPlayer ? YtMusic.isPlaying : (player?.isPlaying ?? false)
    readonly property bool effectiveCanSeek: isYtMusicPlayer ? YtMusic.canSeek : (player?.canSeek ?? false)
    
    property string artDownloadLocation: Directories.coverArt
    readonly property bool downloaded: MediaArtwork.ready
    property string displayedArtFilePath: MediaArtwork.displaySource
    // Track-change slide direction (+1 next, -1 previous) drives the cross-slide
    property int slideDirection: 1

    // Cava visualizer - using shared CavaProcess component
    CavaProcess {
        id: cavaProcess
        active: root.visible && root.hasPlayer && GlobalStates.sidebarLeftOpen && Appearance.effectsEnabled
    }

    property list<real> visualizerPoints: cavaProcess.points

    function checkAndDownloadArt() {
        MediaArtwork.refresh()
    }

    function seekTo(seconds) {
        if (root.effectiveLength <= 0) return
        const bounded = Math.max(0, Math.min(root.effectiveLength, seconds))
        if (root.isYtMusicPlayer) {
            YtMusic.seek(bounded)
        } else if (root.player) {
            MprisController.seek(root.player, bounded)
        }
    }
    
    // Re-check cover art when becoming visible
    onVisibleChanged: {
        if (visible && hasPlayer) {
            checkAndDownloadArt()
        }
    }

    ColorQuantizer {
        id: colorQuantizer
        source: root.displayedArtFilePath
        depth: 0
        rescaleSize: 1
    }

    property color artDominantColor: ColorUtils.mix(
        colorQuantizer?.colors[0] ?? Appearance.colors.colPrimary,
        Appearance.colors.colPrimaryContainer, 0.7
    )

    property QtObject blendedColors: AdaptedMaterialScheme { color: root.artDominantColor }
    readonly property QtObject effectiveColors: Appearance.editorialEverywhere && Appearance.colors
        ? Appearance.colors : root.blendedColors
    
    // Inir uses fixed colors instead of adaptive
    readonly property color jiraColText: Appearance.inir.colText
    readonly property color jiraColTextSecondary: Appearance.inir.colTextSecondary
    readonly property color jiraColPrimary: Appearance.inir.colPrimary
    readonly property color jiraColLayer1: Appearance.inir.colLayer1
    readonly property color jiraColLayer2: Appearance.inir.colLayer2
    readonly property color mediaAccent: Appearance.editorialEverywhere ? Appearance.editorial.accent
        : Appearance.regaliaEverywhere ? Appearance.regalia.hardwarePrimary
        : Appearance.zzzEverywhere ? Appearance.zzz.accent
        : Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? root.jiraColPrimary
        : Appearance.cookieEverywhere ? Appearance.colors.colPrimary
        : Appearance.colors.colPrimary
    readonly property color mediaSecondaryAccent: Appearance.editorialEverywhere ? Appearance.colors.colSecondary
        : Appearance.regaliaEverywhere ? Appearance.regalia.hardwareSecondary
        : Appearance.zzzEverywhere ? Appearance.zzz.secondary
        : Appearance.angelEverywhere ? Appearance.angel.colSecondary
        : Appearance.inirEverywhere ? Appearance.inir.colSecondary
        : Appearance.cookieEverywhere ? Appearance.colors.colSecondary
        : Appearance.colors.colSecondary
    readonly property color mediaTertiaryAccent: Appearance.regaliaEverywhere ? Appearance.regalia.hardwareTertiary
        : Appearance.colors.colTertiary
    readonly property color mediaText: Appearance.editorialEverywhere ? Appearance.editorial.ink
        : Appearance.regaliaEverywhere ? Appearance.regalia.onColor
        : Appearance.cookieEverywhere ? Appearance.cookie.onColor
        : Appearance.zzzEverywhere ? Appearance.zzz.ink
        : Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? root.jiraColText
        : (effectiveColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
    readonly property color mediaMetadata: Appearance.editorialEverywhere ? Appearance.editorial.muted
        : Appearance.regaliaEverywhere ? Appearance.regalia.onMuted
        : Appearance.cookieEverywhere ? Appearance.cookie.inkMuted
        : Appearance.zzzEverywhere ? Appearance.zzz.inkMuted
        : Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : Appearance.inirEverywhere ? root.jiraColTextSecondary
        : root.mediaSecondaryAccent

    StyledRectangularShadow { target: card }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: parent.width - Appearance.sizes.elevationMargin
        implicitHeight: Appearance.editorialEverywhere ? Math.max(130, 142 * Appearance.fontSizeScale) : 130
        radius: Appearance.zzzEverywhere ? Appearance.zzz.cardRadius
            : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
            : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
            : Appearance.rounding.normal
        color: Appearance.zzzEverywhere ? "transparent"
             : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
             : Appearance.inirEverywhere ? Appearance.inir.colLayer1
             : Appearance.auroraEverywhere ? ColorUtils.transparentize(effectiveColors?.colLayer0 ?? Appearance.colors.colLayer0, 0.7)
             : (effectiveColors?.colLayer0 ?? Appearance.colors.colLayer0)
        border.width: Appearance.zzzEverywhere ? 0 : (Appearance.angelEverywhere ? 0 : (Appearance.inirEverywhere ? 1 : 0))
        border.color: Appearance.zzzEverywhere ? "transparent"
            : Appearance.angelEverywhere ? "transparent"
            : Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"
        clip: true
        Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
        Behavior on border.width { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
        Behavior on border.color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }

        AngelPartialBorder { targetRadius: card.radius; coverage: 0.5 }

        layer.enabled: true
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle { width: card.width; height: card.height; radius: card.radius }
        }

        // Cover art background - subtle for inir, more transparent for aurora
        Image {
            id: bgArt
            anchors.fill: parent
            source: root.displayedArtFilePath
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            opacity: Appearance.angelEverywhere ? 0.2 : (Appearance.inirEverywhere ? 0.15 : (Appearance.auroraEverywhere ? 0.25 : 0.5))
            visible: !Appearance.editorialEverywhere && root.displayedArtFilePath !== ""

            layer.enabled: Appearance.effectsEnabled
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: Appearance.inirEverywhere ? 0.3 : 0.15
                blurMax: 16
                saturation: Appearance.inirEverywhere ? 0.1 : 0.3
            }
        }

        // Dark overlay for controls visibility - only for Material
        Rectangle {
            anchors.fill: parent
            visible: !Appearance.editorialEverywhere && !Appearance.inirEverywhere && !Appearance.auroraEverywhere
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.35; color: ColorUtils.transparentize(effectiveColors?.colLayer0 ?? Appearance.colors.colLayer0, 0.3) }
                GradientStop { position: 1.0; color: ColorUtils.transparentize(effectiveColors?.colLayer0 ?? Appearance.colors.colLayer0, 0.15) }
            }
        }

        // Visualizer at bottom
        WaveVisualizer {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 30
            live: root.effectiveIsPlaying
            points: root.visualizerPoints
            maxVisualizerValue: 1000
            smoothing: 2
            color: ColorUtils.transparentize(
                Appearance.angelEverywhere ? Appearance.angel.colPrimary
                : Appearance.inirEverywhere ? root.jiraColPrimary : (effectiveColors?.colPrimary ?? Appearance.colors.colPrimary),
                0.6
            )
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Appearance.editorialEverywhere ? Math.round(12 * Appearance.editorial.spacing) : 10
            spacing: 10

            // Cover art thumbnail — direction-aware cross-slide
            MediaCrossSlideImage {
                id: coverArtContainer
                Layout.preferredWidth: 110
                Layout.preferredHeight: 110
                artRadius: Appearance.zzzEverywhere ? Appearance.zzz.roundNormal
                    : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                    : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
                source: root.displayedArtFilePath
                downloaded: root.downloaded
                slideDirection: root.slideDirection
                placeholderColor: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                    : Appearance.inirEverywhere ? root.jiraColLayer2
                    : (effectiveColors?.colLayer1 ?? Appearance.colors.colLayer1)
                iconColor: root.mediaMetadata
                iconSize: 32
            }

            // Info & controls column
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 2

                // Title
                StyledText {
                    Layout.fillWidth: true
                    text: StringUtils.cleanMusicTitle(root.effectiveTitle) || "—"
                    font.family: (Appearance.editorialEverywhere || Appearance.zzzEverywhere)
                        ? Appearance.font.family.title : Appearance.font.family.main
                    font.pixelSize: Appearance.editorialEverywhere ? Appearance.font.pixelSize.large * Appearance.editorial.titleScale : Appearance.font.pixelSize.normal
                    font.weight: Appearance.editorialEverywhere ? Appearance.editorial.titleWeight : Font.DemiBold
                    font.letterSpacing: Appearance.editorialEverywhere ? Appearance.editorial.titleTracking : 0
                    color: root.mediaText
                    elide: Text.ElideRight
                    animateChange: true
                    animationDistanceX: root.slideDirection * 8
                    animationDistanceY: 0
                }

                // Artist
                StyledText {
                    Layout.fillWidth: true
                    text: root.effectiveArtist || ""
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Medium
                    color: root.mediaSecondaryAccent
                    elide: Text.ElideRight
                    visible: text !== ""
                    animateChange: true
                    animationDistanceX: root.slideDirection * 8
                    animationDistanceY: 0
                }

                Item { Layout.fillHeight: true }

                // Progress bar
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 16

                    StyledSlider {
                        id: seekSlider
                        anchors.fill: parent
                        configuration: StyledSlider.Configuration.Wavy
                        stopIndicatorValues: []
                        wavy: !Appearance.editorialEverywhere && root.effectiveIsPlaying
                        animateWave: !Appearance.editorialEverywhere && root.effectiveIsPlaying
                        highlightColor: root.mediaAccent
                        trackColor: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                            : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                            : Appearance.auroraEverywhere ? Appearance.colInactiveControlSurface
                            : (effectiveColors?.colSecondaryContainer ?? Appearance.colors.colSecondaryContainer)
                        handleColor: root.mediaAccent
                        property bool draggingSeek: false
                        property bool awaitingSeek: false
                        property real requestedValue: 0
                        readonly property real sourceValue: root.effectiveLength > 0
                            ? Math.max(0, Math.min(1, root.effectivePosition / root.effectiveLength)) : 0
                        value: (draggingSeek || awaitingSeek) ? requestedValue : sourceValue
                        onPressedChanged: {
                            if (!root.effectiveCanSeek) return
                            if (pressed) {
                                requestedValue = value
                                draggingSeek = true
                                awaitingSeek = false
                                seekSyncTimeout.stop()
                                return
                            }
                            if (!draggingSeek) return
                            requestedValue = value
                            draggingSeek = false
                            awaitingSeek = true
                            root.seekTo(requestedValue * root.effectiveLength)
                            seekSyncTimeout.restart()
                        }
                        onMoved: {
                            if (!root.effectiveCanSeek) return
                            requestedValue = value
                            awaitingSeek = true
                            root.seekTo(requestedValue * root.effectiveLength)
                            seekSyncTimeout.restart()
                        }
                        scrollable: root.effectiveCanSeek

                        Connections {
                            target: root
                            function onEffectivePositionChanged() {
                                if (!seekSlider.awaitingSeek || seekSlider.draggingSeek || root.effectiveLength <= 0)
                                    return
                                const target = seekSlider.requestedValue * root.effectiveLength
                                if (Math.abs(root.effectivePosition - target) <= 1.25) {
                                    seekSlider.awaitingSeek = false
                                    seekSyncTimeout.stop()
                                }
                            }
                        }

                        Timer {
                            id: seekSyncTimeout
                            interval: 1600
                            repeat: false
                            onTriggered: seekSlider.awaitingSeek = false
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        visible: !root.effectiveCanSeek
                        acceptedButtons: Qt.AllButtons
                        preventStealing: true
                        cursorShape: Qt.ArrowCursor
                        onWheel: event => event.accepted = true
                    }
                }

                // Time + controls row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        text: StringUtils.friendlyTimeForSeconds(root.effectivePosition)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.numbers
                        font.weight: Font.Medium
                        color: root.mediaTertiaryAccent
                    }

                    Item { Layout.fillWidth: true }

                    // Controls
                    RippleButton {
                        implicitWidth: 32
                        implicitHeight: 32
                        enabled: MprisController.canGoPrevious
                        buttonRadius: Appearance.editorialEverywhere ? Appearance.rounding.small : Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                            : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colLayer1Hover
                        colRipple: Appearance.colLayer1Active
                        onClicked: {
                            root.slideDirection = -1
                            MprisController.previous()
                        }

                        contentItem: Item {
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "skip_previous"
                                iconSize: 22
                                fill: 1
                                color: root.mediaSecondaryAccent
                            }
                        }

                        StyledToolTip { text: Translation.tr("Previous") }
                    }

                    RippleButton {
                        id: playPauseButton
                        implicitWidth: 40
                        implicitHeight: 40
                        buttonRadius: Appearance.editorialEverywhere ? Appearance.rounding.small : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                            : Appearance.inirEverywhere 
                            ? Appearance.inir.roundingSmall 
                            : (root.effectiveIsPlaying ? Appearance.rounding.normal : Appearance.rounding.full)
                        colBackground: Appearance.zzzEverywhere
                            ? (root.effectiveIsPlaying ? Appearance.zzz.sticker : Appearance.colors.colLayer1)
                            : Appearance.angelEverywhere
                            ? "transparent"
                            : Appearance.inirEverywhere
                            ? "transparent"
                            : Appearance.auroraEverywhere
                                ? "transparent"
                                : (root.effectiveIsPlaying 
                                    ? (effectiveColors?.colPrimary ?? Appearance.colors.colPrimary)
                                    : (effectiveColors?.colSecondaryContainer ?? Appearance.colors.colSecondaryContainer))
                        colBackgroundHover: Appearance.zzzEverywhere
                            ? (root.effectiveIsPlaying ? Appearance.colors.colPrimaryHover : Appearance.colLayer1Hover)
                            : Appearance.angelEverywhere
                            ? Appearance.angel.colGlassCardHover
                            : Appearance.inirEverywhere
                            ? Appearance.inir.colLayer2Hover
                            : Appearance.auroraEverywhere
                                ? ColorUtils.transparentize(effectiveColors?.colLayer1 ?? Appearance.colors.colLayer1, 0.5)
                                : (root.effectiveIsPlaying 
                                    ? (effectiveColors?.colPrimaryHover ?? Appearance.colors.colPrimaryHover)
                                    : (effectiveColors?.colSecondaryContainerHover ?? Appearance.colors.colSecondaryContainerHover))
                        colRipple: Appearance.zzzEverywhere
                            ? (root.effectiveIsPlaying ? Appearance.colors.colPrimaryActive : Appearance.colLayer1Active)
                            : Appearance.angelEverywhere
                            ? Appearance.angel.colGlassCardActive
                            : Appearance.inirEverywhere
                            ? Appearance.inir.colLayer2Active
                            : Appearance.auroraEverywhere
                                ? (effectiveColors?.colLayer1Active ?? Appearance.colLayer1Active)
                                : (root.effectiveIsPlaying 
                                    ? (effectiveColors?.colPrimaryActive ?? Appearance.colors.colPrimaryActive)
                                    : (effectiveColors?.colSecondaryContainerActive ?? Appearance.colors.colSecondaryContainerActive))
                        onClicked: MprisController.togglePlaying()

                        Behavior on buttonRadius {
                            enabled: Appearance.animationsEnabled && !Appearance.inirEverywhere
                            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                        }

                        contentItem: Item {
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: root.effectiveIsPlaying ? "pause" : "play_arrow"
                                iconSize: 24
                                fill: 1
                                color: Appearance.zzzEverywhere
                                    ? (root.effectiveIsPlaying ? Appearance.zzz.onSticker : Appearance.colors.colOnLayer1)
                                    : Appearance.angelEverywhere
                                    ? Appearance.angel.colPrimary
                                    : Appearance.inirEverywhere
                                    ? root.jiraColPrimary
                                    : Appearance.auroraEverywhere
                                        ? root.mediaAccent
                                        : (root.effectiveIsPlaying 
                                            ? (effectiveColors?.colOnPrimary ?? Appearance.colors.colOnPrimary)
                                            : (effectiveColors?.colOnSecondaryContainer ?? Appearance.colors.colOnSecondaryContainer))

                                Behavior on color {
                                    enabled: Appearance.animationsEnabled
                                    animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                }
                            }
                        }

                        StyledToolTip { text: root.effectiveIsPlaying ? Translation.tr("Pause") : Translation.tr("Play") }
                    }

                    RippleButton {
                        implicitWidth: 32
                        implicitHeight: 32
                        enabled: MprisController.canGoNext
                        buttonRadius: Appearance.editorialEverywhere ? Appearance.rounding.small : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                            : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colLayer1Hover
                        colRipple: Appearance.colLayer1Active
                        onClicked: {
                            root.slideDirection = 1
                            MprisController.next()
                        }

                        contentItem: Item {
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "skip_next"
                                iconSize: 22
                                fill: 1
                                color: root.mediaSecondaryAccent
                            }
                        }

                        StyledToolTip { text: Translation.tr("Next") }
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        text: StringUtils.friendlyTimeForSeconds(root.effectiveLength)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.numbers
                        font.weight: Font.Medium
                        color: root.mediaMetadata
                    }
                }
            }
        }
    }

    Timer {
        running: root.effectiveIsPlaying && GlobalStates.sidebarLeftOpen
        interval: 1000
        repeat: true
        onTriggered: {
            if (!root.isYtMusicPlayer && root.player) {
                root.player.positionChanged()
            }
        }
    }
}
