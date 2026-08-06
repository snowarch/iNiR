import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.mediaControls.components
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var track: MprisController.activeTrack
    property bool isPlaying: MprisController.isPlaying
    readonly property string effectiveTitle: StringUtils.cleanMusicTitle(
        MprisController.isYtMusicActive ? YtMusic.currentTitle : (track?.title ?? ""))
    readonly property string effectiveArtist: MprisController.isYtMusicActive ? YtMusic.currentArtist : (track?.artist ?? "")
    readonly property string effectiveRawArtUrl: MprisController.isYtMusicActive
        ? YtMusic.currentThumbnail : (track?.artUrl ?? "")
    readonly property bool metadataCoherent: root.isCoherentTitle(root.effectiveTitle)
    readonly property real screenWidth: root.QsWindow?.window?.screen?.width ?? 1920
    readonly property real screenHeight: root.QsWindow?.window?.screen?.height ?? 1080
    readonly property bool compactMode: root.screenWidth <= 1440 || root.screenHeight <= 800
    readonly property bool narrowMode: root.screenWidth <= 960 || root.screenHeight <= 600
    readonly property real cardWidth: Math.round(Math.min(
        root.screenWidth - Appearance.sizes.spacingLarge * 2,
        root.narrowMode ? 260 : root.compactMode ? 284 : 300))
    readonly property real cardHeight: root.narrowMode ? 64 : root.compactMode ? 70 : 76
    readonly property real contentMargin: root.narrowMode
        ? Appearance.sizes.spacingSmall * 0.75 : Appearance.sizes.spacingSmall
    readonly property real artworkSize: root.cardHeight - root.contentMargin * 2
    readonly property real controlButtonSize: root.narrowMode ? 24 : root.compactMode ? 26 : 28
    readonly property real playButtonSize: root.narrowMode ? 28 : root.compactMode ? 30 : 32
    readonly property bool motionEnabled: !(Config.options?.performance?.reduceAnimations ?? false)
    readonly property int metadataEnterDuration: Appearance.animationsEnabled
        ? Appearance.animation.elementMoveFast.duration : 220
    readonly property string artworkTransitionKey: MediaArtwork.displaySource
    property int transitionDirection: 1
    property string displayedTitle: ""
    property string displayedArtist: ""
    property string _pendingTitle: ""
    property string _pendingArtist: ""
    property string displayedRawArtUrl: ""
    property real metadataOpacity: 1
    property real metadataOffset: 0
    property string actionFeedbackAction: ""
    property real actionFeedbackOpacity: 0
    property real actionFeedbackScale: 0.82
    property real actionFeedbackOffset: 0
    readonly property int actionFeedbackDirection:
        root.actionFeedbackAction === "next" ? 1
        : root.actionFeedbackAction === "previous" ? -1 : 0
    readonly property string actionFeedbackIcon:
        root.actionFeedbackAction === "next" ? "skip_next"
        : root.actionFeedbackAction === "previous" ? "skip_previous"
        : root.actionFeedbackAction === "pause" ? "pause" : "play_arrow"

    implicitWidth: mediaCard.implicitWidth + 2 * Appearance.sizes.elevationMargin
    implicitHeight: mediaCard.implicitHeight + 2 * Appearance.sizes.elevationMargin
    clip: false

    function isCoherentTitle(title: string): bool {
        const normalized = String(title ?? "").trim().toLocaleLowerCase()
        const translatedUnknown = Translation.tr("Unknown Title").trim().toLocaleLowerCase()
        return normalized.length > 0
            && !normalized.startsWith("unknown title")
            && normalized !== translatedUnknown
    }

    function stageMetadata(): void {
        if (!root.isCoherentTitle(root.effectiveTitle))
            return
        root._pendingTitle = root.effectiveTitle
        root._pendingArtist = root.effectiveArtist === Translation.tr("Unknown Artist")
            ? "" : root.effectiveArtist
        const expectsDifferentArt = root.effectiveRawArtUrl.length > 0
            && root.effectiveRawArtUrl !== root.displayedRawArtUrl
        metadataFallbackTimer.interval = expectsDifferentArt ? 1500 : 360
        metadataFallbackTimer.restart()
    }

    function commitPendingMetadata(): void {
        if (!root._pendingTitle.length
                || (root._pendingTitle === root.displayedTitle
                    && root._pendingArtist === root.displayedArtist))
            return
        metadataFallbackTimer.stop()
        if (!root.motionEnabled) {
            root.displayedTitle = root._pendingTitle
            root.displayedArtist = root._pendingArtist
            root.metadataOpacity = 1
            root.metadataOffset = 0
            return
        }
        metadataTransition.restart()
    }

    function showActionFeedback(action: string): void {
        const normalized = String(action ?? "")
        if (!["play", "pause", "next", "previous"].includes(normalized))
            return

        actionFeedbackAnimation.stop()
        actionFeedbackStaticTimer.stop()
        root.actionFeedbackAction = normalized
        root.actionFeedbackOpacity = root.motionEnabled ? 0 : 1
        root.actionFeedbackScale = root.motionEnabled ? 0.82 : 1
        root.actionFeedbackOffset = root.motionEnabled
            ? root.actionFeedbackDirection * 8 : 0

        if (root.motionEnabled)
            actionFeedbackAnimation.restart()
        else
            actionFeedbackStaticTimer.restart()
    }

    function invokeMediaAction(action: string): void {
        if (action === "previous") {
            MprisController.previous()
            GlobalStates.showMediaAction("previous")
            return
        }
        if (action === "next") {
            MprisController.next()
            GlobalStates.showMediaAction("next")
            return
        }
        const wasPlaying = root.isPlaying
        MprisController.togglePlaying()
        GlobalStates.showMediaAction(wasPlaying ? "pause" : "play")
    }

    onEffectiveTitleChanged: root.stageMetadata()
    onEffectiveArtistChanged: root.stageMetadata()

    Component.onCompleted: {
        if (GlobalStates.osdMediaAction === "previous")
            root.transitionDirection = -1
        root.displayedTitle = root.isCoherentTitle(root.effectiveTitle)
            ? root.effectiveTitle : ""
        root.displayedArtist = root.effectiveArtist === Translation.tr("Unknown Artist")
            ? "" : root.effectiveArtist
        root.displayedRawArtUrl = root.effectiveRawArtUrl
        Qt.callLater(() => root.showActionFeedback(GlobalStates.osdMediaAction))
    }

    Connections {
        target: GlobalStates
        function onOsdMediaActionTriggered(action: string): void {
            if (action === "previous")
                root.transitionDirection = -1
            else if (action === "next")
                root.transitionDirection = 1
            root.showActionFeedback(action)
        }
    }

    Connections {
        target: MprisController
        function onTrackChanged(reverse: bool): void {
            root.transitionDirection = reverse ? -1 : 1
            root.stageMetadata()
        }
    }

    Timer {
        id: metadataFallbackTimer
        interval: 360
        repeat: false
        onTriggered: root.commitPendingMetadata()
    }

    SequentialAnimation {
        id: metadataTransition
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "metadataOpacity"
                to: 0
                duration: root.motionEnabled ? 70 : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.standardAccel
            }
            NumberAnimation {
                target: root
                property: "metadataOffset"
                to: -root.transitionDirection * 3
                duration: root.motionEnabled ? 70 : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.standardAccel
            }
        }
        ScriptAction {
            script: {
                root.displayedTitle = root._pendingTitle
                root.displayedArtist = root._pendingArtist
                root.metadataOffset = root.transitionDirection * 6
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "metadataOpacity"
                from: 0
                to: 1
                duration: root.metadataEnterDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.standardDecel
            }
            NumberAnimation {
                target: root
                property: "metadataOffset"
                from: root.transitionDirection * 6
                to: 0
                duration: root.metadataEnterDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.standardDecel
            }
        }
    }

    SequentialAnimation {
        id: actionFeedbackAnimation

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "actionFeedbackOpacity"
                from: 0
                to: 1
                duration: 90
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.standardDecel
            }
            NumberAnimation {
                target: root
                property: "actionFeedbackScale"
                from: 0.82
                to: 1
                duration: 110
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.standardDecel
            }
            NumberAnimation {
                target: root
                property: "actionFeedbackOffset"
                from: root.actionFeedbackDirection * 8
                to: 0
                duration: 110
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.standardDecel
            }
        }
        PauseAnimation { duration: 150 }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "actionFeedbackOpacity"
                from: 1
                to: 0
                duration: 120
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.standardAccel
            }
            NumberAnimation {
                target: root
                property: "actionFeedbackScale"
                from: 1
                to: 0.92
                duration: 120
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.standardAccel
            }
            NumberAnimation {
                target: root
                property: "actionFeedbackOffset"
                from: 0
                to: -root.actionFeedbackDirection * 5
                duration: 120
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.standardAccel
            }
        }
    }

    Timer {
        id: actionFeedbackStaticTimer
        interval: 300
        repeat: false
        onTriggered: root.actionFeedbackOpacity = 0
    }

    StyledRectangularShadow {
        target: mediaCard
    }

    GlassBackground {
        id: mediaCard
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }
        readonly property point screenPosition: mediaCard.mapToItem(null, 0, 0)
        screenX: screenPosition.x
        screenY: screenPosition.y
        screenWidth: root.QsWindow?.window?.screen?.width ?? root.cardWidth
        screenHeight: root.QsWindow?.window?.screen?.height ?? implicitHeight
        radius: Appearance.zzzEverywhere ? Appearance.zzz.panelRadius
            : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
            : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
            : Appearance.rounding.normal
        fallbackColor: Appearance.colors.colLayer0
        inirColor: Appearance.inir.colLayer1
        auroraTransparency: Appearance.aurora.popupTransparentize
        border.width: Appearance.zzzEverywhere ? Appearance.zzz.borderThick
            : auroraEverywhere || inirEverywhere ? 1 : 0
        border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
            : inirEverywhere ? Appearance.inir.colBorder
            : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipBorder : Appearance.colors.colLayer0Border
        implicitWidth: root.cardWidth
        implicitHeight: root.cardHeight

        RowLayout {
            id: contentRow
            anchors {
                fill: parent
                margins: root.contentMargin
            }
            spacing: Appearance.sizes.spacingSmall

            // Album art — fills height, stays square (BarMediaPlayerItem pattern)
            Rectangle {
                id: artworkFrame
                Layout.preferredWidth: root.artworkSize
                Layout.preferredHeight: root.artworkSize
                Layout.alignment: Qt.AlignVCenter
                radius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
                    : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                    : Appearance.inirEverywhere ? Appearance.inir.roundingSmall
                    : Appearance.rounding.small
                color: Appearance.colors.colLayer1
                clip: true

                PlayerArtwork {
                    id: albumArt
                    anchors.fill: parent
                    artSource: MediaArtwork.displaySource
                    downloaded: MediaArtwork.ready && artSource.length > 0
                    artRadius: artworkFrame.radius
                    iconColor: Appearance.colors.colSubtext
                    iconSize: root.narrowMode
                        ? Appearance.font.pixelSize.large
                        : Appearance.font.pixelSize.huge
                    slideDirection: root.transitionDirection
                    transitionKey: root.artworkTransitionKey
                    animateChanges: root.motionEnabled
                    onTransitionStarted: {
                        root.displayedRawArtUrl = root.effectiveRawArtUrl
                        root.stageMetadata()
                        root.commitPendingMetadata()
                    }
                }

                Rectangle {
                    id: actionFeedbackBadge
                    anchors.centerIn: parent
                    width: Math.min(root.artworkSize * 0.64, 32)
                    height: width
                    radius: Appearance.rounding.full
                    color: ColorUtils.applyAlpha(Appearance.colors.colPrimaryContainer, 0.94)
                    border.width: 1
                    border.color: ColorUtils.applyAlpha(Appearance.colors.colOnPrimaryContainer, 0.22)
                    opacity: root.actionFeedbackOpacity
                    visible: opacity > 0.001
                    z: 4
                    transform: [
                        Translate { x: root.actionFeedbackOffset },
                        Scale {
                            origin.x: actionFeedbackBadge.width / 2
                            origin.y: actionFeedbackBadge.height / 2
                            xScale: root.actionFeedbackScale
                            yScale: root.actionFeedbackScale
                        }
                    ]

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: root.actionFeedbackIcon
                        iconSize: Math.round(actionFeedbackBadge.width * 0.62)
                        fill: 1
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                }
            }

            // Track info + controls
            ColumnLayout {
                id: infoColumn
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                spacing: 1
                opacity: root.metadataOpacity
                transform: Translate { x: root.metadataOffset }

                StyledText {
                    Layout.fillWidth: true
                    text: root.displayedTitle || Translation.tr("No media playing")
                    font.pixelSize: root.narrowMode
                        ? Appearance.font.pixelSize.small
                        : Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.displayedArtist
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    visible: text.length > 0
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: mediaControls.implicitWidth + Appearance.sizes.spacingSmall
                implicitHeight: mediaControls.implicitHeight + Appearance.sizes.spacingSmall * 0.5
                radius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
                    : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                    : Appearance.inirEverywhere ? Appearance.inir.roundingSmall
                    : Appearance.rounding.full
                color: Appearance.zzzEverywhere ? Appearance.zzz.paperAlt
                    : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                    : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                    : Appearance.colors.colLayer1
                border.width: Appearance.inirEverywhere || Appearance.angelEverywhere ? 1 : 0
                border.color: Appearance.angelEverywhere
                    ? Appearance.angel.colCardBorder : Appearance.inir.colBorder

                PlayerControls {
                    id: mediaControls
                    anchors.centerIn: parent
                    isPlaying: root.isPlaying
                    buttonSize: root.controlButtonSize
                    playButtonSize: root.playButtonSize
                    iconSize: root.narrowMode ? 15 : 16
                    playIconSize: root.narrowMode ? 17 : 18
                    showLabels: false
                    canGoPrevious: MprisController.canGoPrevious
                    canGoNext: MprisController.canGoNext
                    playButtonColor: Appearance.zzzEverywhere
                        ? Appearance.zzz.sticker : Appearance.colors.colPrimaryContainer
                    playIconColor: Appearance.zzzEverywhere
                        ? Appearance.zzz.onSticker : Appearance.colors.colOnPrimaryContainer
                    onPreviousClicked: root.invokeMediaAction("previous")
                    onPlayPauseClicked: root.invokeMediaAction("playPause")
                    onNextClicked: root.invokeMediaAction("next")
                }
            }
        }
    }
}
