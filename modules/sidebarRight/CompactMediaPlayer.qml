pragma ComponentBehavior: Bound
// CompactMediaPlayer.qml
// Redesigned media player for compact sidebar Controls section
// Dense Spotify-style media card with a distinct treatment for every style.

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models
import qs.modules.mediaControls.components
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE

Item {
    id: root

    visible: implicitHeight > 0
    implicitHeight: (MprisController.activePlayer !== null) ? playerCard.implicitHeight : 0

    Behavior on implicitHeight {
        enabled: Appearance.animationsEnabled
        animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
    }

    // ── Core media state ──────────────────────────────────────────
    PlayerBase {
        id: playerBase
        player: MprisController.activePlayer
        positionUpdatesActive: root.visible && GlobalStates.sidebarRightOpen
    }

    property QtObject blendedColors: AdaptedMaterialScheme {
        color: playerBase.artDominantColor
    }

    // ── Style tokens ──────────────────────────────────────────────
    readonly property bool angelStyle: Appearance.angelEverywhere
    readonly property bool inirStyle: Appearance.inirEverywhere
    readonly property bool auroraStyle: Appearance.auroraEverywhere
    readonly property bool zzzStyle: Appearance.zzzEverywhere
    readonly property bool cookieStyle: Appearance.cookieEverywhere
    readonly property bool compactNarrow: width > 0 && width < 300

    readonly property color colText: zzzStyle ? Appearance.zzz.ink
        : cookieStyle ? Appearance.cookie.onColor
        : angelStyle ? Appearance.angel.colText
        : inirStyle ? Appearance.inir.colText
        : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
    readonly property color colTextSecondary: zzzStyle ? Appearance.zzz.inkMuted
        : cookieStyle ? Appearance.cookie.inkMuted
        : angelStyle ? Appearance.angel.colTextSecondary
        : inirStyle ? Appearance.inir.colTextSecondary
        : (blendedColors?.colSubtext ?? Appearance.colors.colSubtext)
    readonly property color colCard: (zzzStyle || cookieStyle) ? "transparent"
        : angelStyle ? Appearance.angel.colGlassCard
        : inirStyle ? Appearance.inir.colLayer1
        : auroraStyle ? ColorUtils.transparentize(
            blendedColors?.colLayer0 ?? Appearance.aurora.colSubSurface, 0.7)
        : (blendedColors?.colLayer0 ?? Appearance.colors.colLayer0)
    readonly property color colBorder: zzzStyle ? Appearance.zzz.hairlineStrong
        : cookieStyle ? Appearance.cookie.hairline
        : angelStyle ? Appearance.angel.colCardBorder
        : inirStyle ? Appearance.inir.colBorder
        : auroraStyle ? Appearance.aurora.colTooltipBorder
        : ColorUtils.transparentize(
            blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0, 0.88)
    readonly property real cardRadius: zzzStyle ? Appearance.zzz.cardRadius
        : cookieStyle ? Appearance.cookie.roundNormal
        : angelStyle ? Appearance.angel.roundingNormal
        : inirStyle ? Appearance.inir.roundingNormal : Appearance.rounding.normal
    readonly property color colPrimary: zzzStyle ? Appearance.zzz.accent
        : cookieStyle ? Appearance.cookie.primaryFace
        : angelStyle ? Appearance.angel.colPrimary
        : inirStyle ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
    readonly property color colOnPrimary: zzzStyle ? Appearance.zzz.onSticker
        : cookieStyle ? Appearance.cookie.onFace
        : angelStyle ? Appearance.angel.colOnPrimary
        : inirStyle ? Appearance.inir.colOnPrimary : Appearance.colors.colOnPrimary
    readonly property color colAuxHover: zzzStyle ? Appearance.zzz.chrome
        : cookieStyle ? Appearance.cookie.bg3
        : angelStyle ? Appearance.angel.colGlassCardHover
        : inirStyle ? Appearance.inir.colLayer2Hover
        : ColorUtils.transparentize(
            blendedColors?.colLayer1 ?? Appearance.colors.colLayer1, 0.5)
    readonly property color colAuxActive: zzzStyle ? Appearance.zzz.sticker
        : cookieStyle ? Appearance.cookie.bg4
        : angelStyle ? Appearance.angel.colGlassCardActive
        : inirStyle ? Appearance.inir.colLayer2Active
        : (blendedColors?.colLayer1Active ?? Appearance.colors.colLayer1Active)

    // Album colors belong to Material and Aurora. Identity-heavy styles keep
    // their own accent ramp so artwork cannot recolor the entire control set.
    readonly property bool useAlbumAccent: playerBase.downloaded
        && !zzzStyle && !cookieStyle && !inirStyle && !angelStyle
    readonly property color accentColor: useAlbumAccent
        ? (blendedColors?.colPrimary ?? colPrimary) : colPrimary
    readonly property color onAccentColor: useAlbumAccent
        ? (blendedColors?.colOnPrimary ?? colOnPrimary) : colOnPrimary

    readonly property real artBgOpacity: zzzStyle ? 0.20
        : cookieStyle ? 0.10
        : inirStyle ? 0.14
        : angelStyle ? 0.20
        : auroraStyle ? 0.28 : 0.48
    readonly property real artworkSize: compactNarrow ? 72 : (cookieStyle ? 84 : 82)
    readonly property real contentGap: compactNarrow ? 8 : 10
    readonly property real contentPadding: zzzStyle ? 12 : 10

    // ── Player card ───────────────────────────────────────────────
    StyledRectangularShadow {
        target: playerCard
        visible: root.angelStyle || (Appearance.effectsEnabled
            && (root.cookieStyle
                || (!root.zzzStyle && !root.auroraStyle && !root.inirStyle)))
    }

    ZzzPlate {
        anchors.fill: playerCard
        visible: root.zzzStyle
        fillColor: Appearance.zzz.bg1
        strokeColor: Appearance.zzz.hairlineStrong
        strokeWidth: Appearance.zzz.hairlineThick
        chamfer: Appearance.zzz.cutCorner
        radius: root.cardRadius
    }

    CookieFace {
        anchors.fill: playerCard
        visible: root.cookieStyle
        role: "card"
        color: Appearance.cookie.bg2
        radius: root.cardRadius
        strokeColor: Appearance.cookie.hairline
        strokeWidth: 1
    }

    Rectangle {
        id: playerCard
        anchors.fill: parent
        implicitHeight: Math.max(
            playerLayout.implicitHeight + root.contentPadding * 2,
            root.artworkSize + root.contentPadding * 2
        )
        radius: root.cardRadius
        color: root.colCard
        Behavior on radius {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        border.width: (root.zzzStyle || root.cookieStyle) ? 0
            : root.angelStyle ? Appearance.angel.cardBorderWidth
            : (root.inirStyle || root.auroraStyle) ? 1 : 0
        border.color: root.angelStyle
            ? ColorUtils.transparentize(root.colBorder, 0.22)
            : root.colBorder
        Behavior on border.width {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on border.color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        clip: true

        layer.enabled: !root.zzzStyle
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: playerCard.width; height: playerCard.height; radius: playerCard.radius
            }
        }

        // ── Blurred art background (full card tint) ──
        Image {
            id: cardBgArt
            anchors.fill: parent
            source: root.artBgOpacity > 0 ? playerBase.displayedArtFilePath : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            sourceSize.width: Math.max(1, playerCard.width)
            sourceSize.height: Math.max(1, playerCard.height)
            opacity: playerBase.displayedArtFilePath !== "" ? root.artBgOpacity : 0
            visible: opacity > 0
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }

            layer.enabled: Appearance.effectsEnabled && visible
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: root.zzzStyle ? 0.15 : (root.auroraStyle ? 0.32 : 0.24)
                blurMax: 32
                saturation: root.zzzStyle ? 0.14 : (root.auroraStyle ? 0.32 : 0.42)
            }
        }

        // Material follows the same cover-derived wash as the full players:
        // visible art on the left, progressively stronger semantic surface
        // behind metadata and controls on the right.
        Rectangle {
            anchors.fill: parent
            visible: root.useAlbumAccent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0
                    color: ColorUtils.transparentize(root.colCard, 0.74)
                }
                GradientStop {
                    position: 0.42
                    color: ColorUtils.transparentize(root.colCard, 0.36)
                }
                GradientStop {
                    position: 1.0
                    color: ColorUtils.transparentize(root.colCard, 0.06)
                }
            }
        }

        // ZZZ keeps its wallpaper-owned signal colors, but the artwork still
        // contributes context as a restrained image wash, like PlayerControl.
        Rectangle {
            anchors.fill: parent
            visible: root.zzzStyle && playerBase.downloaded
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0
                    color: ColorUtils.transparentize(Appearance.zzz.bg1, 0.78)
                }
                GradientStop {
                    position: 0.42
                    color: ColorUtils.transparentize(Appearance.zzz.bg1, 0.46)
                }
                GradientStop {
                    position: 1.0
                    color: ColorUtils.transparentize(Appearance.zzz.bg1, 0.08)
                }
            }
        }

        Rectangle {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                leftMargin: root.contentPadding
                rightMargin: root.contentPadding + (root.zzzStyle ? Appearance.zzz.cutCorner : 0)
            }
            height: root.zzzStyle ? 2 : (root.angelStyle ? Appearance.angel.insetGlowHeight : 1)
            visible: opacity > 0
            opacity: root.zzzStyle || root.angelStyle ? 1 : 0
            color: root.zzzStyle ? Appearance.zzz.accent
                : root.angelStyle ? Appearance.angel.colInsetGlow
                : "transparent"
            Behavior on height {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
        }

        // Full-height cover anchor, matching the compact/full player family.
        Item {
            id: artContainer
            anchors.left: parent.left
            anchors.leftMargin: root.contentPadding
            anchors.verticalCenter: parent.verticalCenter
            width: root.artworkSize
            height: root.artworkSize

            Rectangle {
                anchors.fill: parent
                anchors.margins: -1
                radius: artwork.artRadius + 1
                color: "transparent"
                border.width: 1
                border.color: playerBase.downloaded && playerBase.effectiveIsPlaying
                    ? ColorUtils.transparentize(root.accentColor, 0.34)
                    : root.colBorder
                Behavior on border.color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                }
            }

            PlayerArtwork {
                id: artwork
                anchors.fill: parent
                artSource: playerBase.displayedArtFilePath
                downloaded: playerBase.downloaded
                artRadius: root.zzzStyle ? Appearance.zzz.roundSmall
                    : root.cookieStyle ? Appearance.cookie.roundSmall
                    : root.angelStyle ? Appearance.angel.roundingSmall
                    : root.inirStyle ? Appearance.inir.roundingSmall
                    : Appearance.rounding.small
                iconSize: 28
                enableBlurTransition: true
            }

            Rectangle {
                anchors.fill: parent
                radius: artwork.artRadius
                color: Qt.rgba(0, 0, 0, artOverlayMA.containsPress ? 0.46 : 0.30)
                opacity: artOverlayMA.containsMouse ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: playerBase.effectiveIsPlaying ? "pause" : "play_arrow"
                    iconSize: 28
                    fill: 1
                    color: "white"
                }
            }

            MouseArea {
                id: artOverlayMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: playerBase.togglePlaying()
            }

            Rectangle {
                id: playerBadge
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: -2
                width: 20
                height: 20
                radius: root.zzzStyle ? Appearance.zzz.controlRadius
                    : root.cookieStyle ? Appearance.cookie.controlRadius
                    : height / 2
                visible: (MprisController.displayPlayers?.length ?? 0) > 1
                color: root.zzzStyle ? Appearance.zzz.chrome
                    : root.cookieStyle ? Appearance.cookie.bg3
                    : root.colCard
                border.width: 1
                border.color: root.colBorder

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "swap_horiz"
                    iconSize: 12
                    color: root.accentColor
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        playerSwitcherMenu.anchorItem = artContainer
                        playerSwitcherMenu.active = true
                    }
                }
            }

            scale: artOverlayMA.containsMouse ? 1.02 : 1.0
            Behavior on scale {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Easing.OutCubic
                }
            }
        }

        ColumnLayout {
            id: playerLayout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.contentPadding + root.artworkSize + root.contentGap
            anchors.rightMargin: root.contentPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            // ═══ TRACK + SEEK ═══
            Item {
                id: heroSection
                Layout.fillWidth: true
                Layout.preferredHeight: contentRow.implicitHeight

                RowLayout {
                    id: contentRow
                    anchors {
                        left: parent.left; right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 0

                    // ── Track info ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        // The text block is the discoverable route to the full
                        // player; the compact card keeps its own chrome minimal.
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: playerInfo.implicitHeight

                            PlayerInfo {
                                id: playerInfo
                                anchors.left: parent.left
                                anchors.right: parent.right
                                title: playerBase.effectiveTitle
                                artist: playerBase.effectiveArtist
                                titleSize: root.compactNarrow
                                    ? Appearance.font.pixelSize.small
                                    : Appearance.font.pixelSize.normal
                                artistSize: Appearance.font.pixelSize.smaller
                                titleWeight: Font.DemiBold
                                titleColor: root.colText
                                artistColor: root.colTextSecondary
                                animateTitle: true
                            }

                            MouseArea {
                                id: playerInfoMA
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: GlobalStates.mediaControlsOpen = true
                            }

                            MaterialSymbol {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                text: "open_in_full"
                                iconSize: 12
                                color: root.colTextSecondary
                                opacity: playerInfoMA.containsMouse ? 0.72 : 0
                                Behavior on opacity {
                                    enabled: Appearance.animationsEnabled
                                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                                }
                            }
                        }

                        Revealer {
                            vertical: true
                            reveal: playerBase.effectiveLength > 0
                            Layout.fillWidth: true

                            RowLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                spacing: 6

                                StyledText {
                                    text: _formatTime(playerBase.effectivePosition)
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.family: Appearance.font.family.numbers
                                font.weight: Font.Medium
                                color: root.colTextSecondary
                                }

                                PlayerProgress {
                                    Layout.fillWidth: true
                                    implicitHeight: 12
                                    position: playerBase.effectivePosition
                                    length: playerBase.effectiveLength
                                    canSeek: playerBase.effectiveCanSeek
                                    isPlaying: playerBase.effectiveIsPlaying
                                    highlightColor: root.accentColor
                                    trackColor: root.zzzStyle ? Appearance.zzz.metricTrack
                                        : root.cookieStyle ? Appearance.cookie.bg4
                                        : root.angelStyle ? Appearance.angel.colBorderSubtle
                                        : root.inirStyle ? Appearance.inir.colLayer2
                                        : (root.blendedColors?.colSecondaryContainer
                                            ?? Appearance.colors.colSecondaryContainer)
                                    enableWavy: true
                                    onSeekRequested: (seconds) => playerBase.seek(seconds)
                                }

                                StyledText {
                                    text: _formatTime(playerBase.effectiveLength)
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    font.family: Appearance.font.family.numbers
                                    color: root.colTextSecondary
                                }
                            }
                        }
                    }
                }
            }

            // ═══ TRANSPORT CONTROLS ═══
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                spacing: root.cookieStyle ? 6 : 4

                Revealer {
                    reveal: MprisController.shuffleSupported
                    TransportBtn {
                        icon: "shuffle"
                        toggled: MprisController.hasShuffle
                        onClicked: MprisController.setShuffle(!MprisController.hasShuffle)
                        tooltipText: Translation.tr("Shuffle")
                        small: true
                    }
                }

                TransportBtn {
                    icon: "skip_previous"
                    enabled: playerBase.effectiveCanGoPrevious
                    iconFill: true
                    onClicked: playerBase.previous()
                    tooltipText: Translation.tr("Previous")
                    small: true
                }

                // ── Play/Pause — focal control in each style's own dialect ──
                Item {
                    id: playButton
                    implicitWidth: root.cookieStyle ? 44 : (root.zzzStyle ? 40 : 42)
                    implicitHeight: root.cookieStyle ? 36 : (root.zzzStyle ? 32 : 34)
                    readonly property color faceColor: {
                        if (root.zzzStyle) {
                            if (playMA.containsPress) return Appearance.zzz.sticker
                            if (playMA.containsMouse) return Appearance.zzz.paperAlt
                            return playerBase.effectiveIsPlaying
                                ? Appearance.zzz.sticker : Appearance.zzz.chrome
                        }
                        if (root.cookieStyle) {
                            if (playMA.containsPress) return Appearance.cookie.bg4
                            return Appearance.cookie.primaryFace
                        }
                        if (root.angelStyle) {
                            if (playMA.containsPress) return Appearance.angel.colGlassCardActive
                            if (playMA.containsMouse) return Appearance.angel.colGlassCardHover
                            return "transparent"
                        }
                        if (root.inirStyle) {
                            if (playMA.containsPress) return Appearance.inir.colLayer2Active
                            if (playMA.containsMouse) return Appearance.inir.colLayer2Hover
                            return "transparent"
                        }
                        if (root.auroraStyle) {
                            if (playMA.containsPress)
                                return root.blendedColors?.colLayer1Active ?? root.colAuxActive
                            if (playMA.containsMouse) return root.colAuxHover
                            return "transparent"
                        }
                        if (playerBase.effectiveIsPlaying) {
                            if (playMA.containsPress)
                                return root.blendedColors?.colPrimaryActive ?? root.accentColor
                            if (playMA.containsMouse)
                                return root.blendedColors?.colPrimaryHover ?? root.accentColor
                            return root.accentColor
                        }
                        if (playMA.containsPress)
                            return root.blendedColors?.colSecondaryContainerActive ?? root.colAuxActive
                        if (playMA.containsMouse)
                            return root.blendedColors?.colSecondaryContainerHover ?? root.colAuxHover
                        return root.blendedColors?.colSecondaryContainer
                            ?? Appearance.colors.colSecondaryContainer
                    }
                    readonly property color glyphColor: root.zzzStyle
                        ? ((playerBase.effectiveIsPlaying || playMA.containsPress)
                            ? Appearance.zzz.onSticker : Appearance.zzz.ink)
                        : root.cookieStyle ? Appearance.cookie.onFace
                        : root.angelStyle ? Appearance.angel.colPrimary
                        : root.inirStyle ? Appearance.inir.colPrimary
                        : root.auroraStyle ? root.colText
                        : playerBase.effectiveIsPlaying ? root.onAccentColor
                        : (root.blendedColors?.colOnSecondaryContainer
                            ?? Appearance.colors.colOnSecondaryContainer)

                    scale: playMA.containsPress ? 0.90 : 1.0
                    Behavior on scale {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic }
                    }

                    ZzzPlate {
                        anchors.fill: parent
                        visible: root.zzzStyle
                        fillColor: playButton.faceColor
                        strokeColor: Appearance.zzz.hairlineStrong
                        strokeWidth: Appearance.zzz.hairlineThick
                        chamfer: playMA.containsMouse
                            ? Appearance.zzz.cutCorner * 1.25 : Appearance.zzz.cutCorner
                    }

                    CookieFace {
                        anchors.fill: parent
                        visible: root.cookieStyle
                        role: "control"
                        selected: playerBase.effectiveIsPlaying
                        color: playButton.faceColor
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: !root.zzzStyle && !root.cookieStyle
                        radius: root.angelStyle ? Appearance.angel.roundingSmall
                            : root.inirStyle ? Appearance.inir.roundingSmall
                            : height / 2
                        color: playButton.faceColor
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                        }
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: playerBase.effectiveIsPlaying ? "pause" : "play_arrow"
                        iconSize: 22
                        fill: 1
                        color: playButton.glyphColor
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                        }
                    }

                    MouseArea {
                        id: playMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: playerBase.togglePlaying()
                    }

                    StyledToolTip {
                        visible: playMA.containsMouse
                        text: playerBase.effectiveIsPlaying
                            ? Translation.tr("Pause") : Translation.tr("Play")
                    }
                }

                TransportBtn {
                    icon: "skip_next"
                    enabled: playerBase.effectiveCanGoNext
                    iconFill: true
                    onClicked: playerBase.next()
                    tooltipText: Translation.tr("Next")
                    small: true
                }

                Revealer {
                    reveal: MprisController.loopSupported
                    TransportBtn {
                        icon: MprisController.loopState === 2 ? "repeat_one" : "repeat"
                        toggled: MprisController.loopState !== 0
                        onClicked: {
                            const next = (MprisController.loopState + 1) % 3
                            MprisController.setLoopState(next)
                        }
                        tooltipText: Translation.tr("Loop")
                        small: true
                    }
                }
            }
        }

        AngelPartialBorder {
            targetRadius: playerCard.radius
            visible: root.angelStyle
        }
    }

    // ── Player switcher menu ──────────────────────────────────────
    ContextMenu {
        id: playerSwitcherMenu

        model: (MprisController.displayPlayers ?? []).map((player, index) => ({
            text: player?.identity ?? "",
            iconName: "",
            checkable: true,
            checked: MprisController.activePlayer === player,
            action: () => {
                if (player) MprisController.setActivePlayer(player)
            }
        }))
    }

    // ── Helpers ───────────────────────────────────────────────────
    function _formatTime(seconds: real): string {
        if (!seconds || seconds <= 0) return "0:00"
        const mins = Math.floor(seconds / 60)
        const secs = Math.floor(seconds % 60)
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }

    // ── Transport button component ────────────────────────────────
    component TransportBtn: Item {
        id: tBtn
        required property string icon
        property string tooltipText: ""
        property bool toggled: false
        property bool small: false
        property bool iconFill: false

        signal clicked()

        enabled: true
        implicitWidth: small ? (root.cookieStyle ? 32 : 30)
            : (root.cookieStyle ? 36 : 34)
        implicitHeight: implicitWidth
        readonly property color faceColor: {
            if (tBtnMA.containsPress) return root.colAuxActive
            if (tBtnMA.containsMouse) return root.colAuxHover
            if (tBtn.toggled) {
                if (root.zzzStyle) return Appearance.zzz.sticker
                if (root.cookieStyle) return Appearance.cookie.primaryFace
                if (root.angelStyle)
                    return ColorUtils.transparentize(root.accentColor, 0.64)
                if (root.inirStyle) return Appearance.inir.colSecondaryContainer
                return ColorUtils.transparentize(root.accentColor, 0.78)
            }
            return root.cookieStyle ? Appearance.cookie.bg2 : "transparent"
        }
        readonly property color glyphColor: root.zzzStyle
            && (tBtn.toggled || tBtnMA.containsPress)
            ? Appearance.zzz.onSticker
            : tBtn.toggled
                ? (root.cookieStyle ? Appearance.cookie.onFace
                    : root.inirStyle ? Appearance.inir.colOnSecondaryContainer
                    : root.accentColor)
                : (tBtn.enabled ? root.colText : root.colTextSecondary)

        Behavior on implicitWidth {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        scale: tBtnMA.containsPress ? 0.90 : 1.0
        Behavior on scale {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic }
        }

        ZzzPlate {
            anchors.fill: parent
            visible: root.zzzStyle
            fillColor: tBtn.faceColor
            strokeColor: tBtn.toggled
                ? Appearance.zzz.accent : Appearance.zzz.hairline
            strokeWidth: Appearance.zzz.hairlineThick
            chamfer: tBtnMA.containsMouse
                ? Appearance.zzz.cutCorner : Appearance.zzz.cutCorner * 0.6
        }

        CookieFace {
            anchors.fill: parent
            visible: root.cookieStyle
            role: "control"
            selected: tBtn.toggled
            color: tBtn.faceColor
        }

        Rectangle {
            anchors.fill: parent
            visible: !root.zzzStyle && !root.cookieStyle
            radius: root.angelStyle ? Appearance.angel.roundingSmall
                : root.inirStyle ? Appearance.inir.roundingSmall
                : Appearance.rounding.full
            color: tBtn.faceColor
            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: tBtn.icon
            iconSize: tBtn.small ? 18 : 22
            fill: tBtn.iconFill || tBtn.toggled ? 1 : 0
            animateFill: true
            color: tBtn.glyphColor
            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }
        }

        MouseArea {
            id: tBtnMA
            anchors.fill: parent
            enabled: tBtn.enabled
            hoverEnabled: true
            cursorShape: tBtn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: tBtn.clicked()
        }

        StyledToolTip {
            visible: tBtnMA.containsMouse && tBtn.tooltipText !== ""
            text: tBtn.tooltipText
        }
    }
}
