pragma ComponentBehavior: Bound
// CompactMediaPlayer.qml
// Redesigned media player for compact sidebar Controls section
// Hero art background + filled accent transport + glow ring
// Compatible with all 5 global styles: material, cards, aurora, inir, angel

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

    visible: MprisController.activePlayer !== null
    implicitHeight: visible ? playerCard.implicitHeight : 0

    // ── Core media state ──────────────────────────────────────────
    PlayerBase {
        id: playerBase
        player: MprisController.activePlayer
    }

    property QtObject blendedColors: AdaptedMaterialScheme {
        color: playerBase.artDominantColor
    }

    // ── Style tokens (5-style) ────────────────────────────────────
    readonly property bool angelStyle: Appearance.angelEverywhere
    readonly property bool inirStyle: Appearance.inirEverywhere
    readonly property bool auroraStyle: Appearance.auroraEverywhere

    readonly property color colText: angelStyle ? Appearance.angel.colText
        : inirStyle ? Appearance.inir.colText : Appearance.colors.colOnLayer1
    readonly property color colTextSecondary: angelStyle ? Appearance.angel.colTextSecondary
        : inirStyle ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
    readonly property color colCard: angelStyle ? Appearance.angel.colGlassCard
        : inirStyle ? Appearance.inir.colLayer1
        : auroraStyle ? ColorUtils.transparentize(
            blendedColors?.colLayer0 ?? Appearance.aurora.colSubSurface, 0.7)
        : Appearance.colors.colLayer1
    readonly property color colBorder: angelStyle ? Appearance.angel.colCardBorder
        : inirStyle ? Appearance.inir.colBorder : Appearance.colors.colLayer0Border
    readonly property real cardRadius: angelStyle ? Appearance.angel.roundingNormal
        : inirStyle ? Appearance.inir.roundingNormal : Appearance.rounding.normal
    readonly property color colPrimary: angelStyle ? Appearance.angel.colPrimary
        : inirStyle ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
    readonly property color colOnPrimary: angelStyle ? Appearance.angel.colOnPrimary
        : inirStyle ? Appearance.inir.colOnPrimary : Appearance.colors.colOnPrimary
    readonly property color colAuxHover: angelStyle ? Appearance.angel.colGlassCardHover
        : inirStyle ? Appearance.inir.colLayer2Hover
        : ColorUtils.transparentize(root.colText, 0.82)
    readonly property color colAuxActive: angelStyle ? Appearance.angel.colGlassCardActive
        : inirStyle ? Appearance.inir.colLayer2Active
        : ColorUtils.transparentize(root.colText, 0.72)

    // Dynamic accent from album art
    readonly property color accentColor: playerBase.downloaded && !inirStyle && !angelStyle
        ? (blendedColors?.colPrimary ?? colPrimary) : colPrimary
    readonly property color onAccentColor: playerBase.downloaded && !inirStyle && !angelStyle
        ? (blendedColors?.colOnPrimary ?? colOnPrimary) : colOnPrimary

    // Art background opacity per style
    readonly property real artBgOpacity: inirStyle ? 0.16
        : angelStyle ? 0.24 : auroraStyle ? 0.28 : 0.38

    // ── Player card ───────────────────────────────────────────────
    Rectangle {
        id: playerCard
        anchors.fill: parent
        implicitHeight: playerLayout.implicitHeight
        radius: root.cardRadius
        color: root.colCard

        border.width: root.angelStyle ? Appearance.angel.cardBorderWidth
            : root.inirStyle ? 1
            : (playerBase.downloaded ? 1 : 0)
        border.color: root.angelStyle ? ColorUtils.transparentize(root.colBorder, 0.22)
            : root.inirStyle ? root.colBorder
            : (playerBase.downloaded
                ? ColorUtils.transparentize(root.accentColor, 0.72)
                : "transparent")
        clip: true

        layer.enabled: true
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: playerCard.width; height: playerCard.height; radius: playerCard.radius
            }
        }

        // ── Blurred art background (full card tint) ──
        Image {
            id: cardBgArt
            anchors.fill: parent
            source: playerBase.displayedArtFilePath
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: playerBase.displayedArtFilePath !== ""
            opacity: root.artBgOpacity

            layer.enabled: Appearance.effectsEnabled
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 0.4
                blurMax: 48
                saturation: 0.3
            }
        }

        ColumnLayout {
            id: playerLayout
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0

            // ═══ HERO SECTION ═══
            Item {
                id: heroSection
                Layout.fillWidth: true
                Layout.preferredHeight: contentRow.implicitHeight + 20

                // Bottom gradient for depth
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: parent.height * 0.6
                    visible: playerBase.downloaded
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: ColorUtils.transparentize(root.colCard, 0.35) }
                    }
                }

                RowLayout {
                    id: contentRow
                    anchors {
                        left: parent.left; right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 10; rightMargin: 10
                    }
                    spacing: 10

                    // ── Album art thumbnail with glow ring ──
                    Item {
                        id: artContainer
                        Layout.preferredWidth: 56
                        Layout.preferredHeight: 56

                        // Accent glow ring (visible when playing + art available)
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -2
                            radius: artwork.artRadius + 2
                            color: "transparent"
                            border.width: 2
                            border.color: ColorUtils.transparentize(root.accentColor, 0.65)
                            visible: playerBase.downloaded && playerBase.effectiveIsPlaying

                            Behavior on border.color {
                                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                            }
                        }

                        PlayerArtwork {
                            id: artwork
                            anchors.fill: parent
                            artSource: playerBase.displayedArtFilePath
                            downloaded: playerBase.downloaded
                            artRadius: root.angelStyle ? Appearance.angel.roundingSmall
                                : root.inirStyle ? Appearance.inir.roundingSmall
                                : Appearance.rounding.small
                            iconSize: 22
                            enableBlurTransition: true
                        }

                        // Hover play/pause overlay
                        Rectangle {
                            anchors.fill: parent
                            radius: artwork.artRadius
                            color: Qt.rgba(0, 0, 0, artOverlayMA.containsPress ? 0.45 : 0.32)
                            opacity: artOverlayMA.containsMouse ? 1 : 0
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: 120 } }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: playerBase.effectiveIsPlaying ? "pause" : "play_arrow"
                                iconSize: 24
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

                        scale: artOverlayMA.containsMouse ? 1.04 : 1.0
                        Behavior on scale {
                            NumberAnimation {
                                duration: Appearance.animation.elementMoveFast.duration
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    // ── Track info ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        // Player identity — tap to switch (multi-player only)
                        Item {
                            Layout.fillWidth: true
                            visible: (MprisController.displayPlayers?.length ?? 0) > 1
                            implicitHeight: identityRow.implicitHeight

                            RowLayout {
                                id: identityRow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                spacing: 3

                                MaterialSymbol {
                                    text: _playerIcon()
                                    iconSize: 11
                                    color: root.accentColor
                                    opacity: 0.75
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: MprisController.activePlayer?.identity ?? ""
                                    font.pixelSize: Appearance.font.pixelSize.smallest - 1
                                    font.weight: Font.Bold
                                    font.letterSpacing: 0.5
                                    color: root.accentColor
                                    opacity: 0.75
                                    elide: Text.ElideRight
                                }

                                MaterialSymbol {
                                    text: "swap_horiz"
                                    iconSize: 12
                                    color: root.colTextSecondary
                                    opacity: 0.5
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    playerSwitcherMenu.anchorItem = parent
                                    playerSwitcherMenu.active = true
                                }
                            }
                        }

                        PlayerInfo {
                            Layout.fillWidth: true
                            title: playerBase.effectiveTitle
                            artist: playerBase.effectiveArtist
                            titleSize: Appearance.font.pixelSize.normal
                            artistSize: Appearance.font.pixelSize.smaller
                            titleColor: root.colText
                            artistColor: root.colTextSecondary
                            animateTitle: true
                        }

                        // Time + expand button
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            visible: playerBase.effectiveLength > 0

                            StyledText {
                                text: _formatTime(playerBase.effectivePosition)
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.family: Appearance.font.family.numbers
                                color: root.accentColor
                                font.weight: Font.Medium
                            }

                            StyledText {
                                text: "·"
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: root.colTextSecondary
                                opacity: 0.5
                            }

                            StyledText {
                                text: _formatTime(playerBase.effectiveLength)
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.family: Appearance.font.family.numbers
                                color: root.colTextSecondary
                            }

                            Item { Layout.fillWidth: true }

                            RippleButton {
                                implicitWidth: 24
                                implicitHeight: 24
                                buttonRadius: 12
                                colBackground: "transparent"
                                colBackgroundHover: root.colAuxHover
                                onClicked: GlobalStates.mediaControlsOpen = true
                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "open_in_full"
                                    iconSize: 14
                                    color: root.colTextSecondary
                                }
                                StyledToolTip { text: Translation.tr("Open full player") }
                            }
                        }
                    }
                }
            }

            // ═══ PROGRESS BAR ═══
            PlayerProgress {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                Layout.topMargin: 2
                implicitHeight: 14
                position: playerBase.effectivePosition
                length: playerBase.effectiveLength
                canSeek: playerBase.effectiveCanSeek
                isPlaying: playerBase.effectiveIsPlaying
                highlightColor: root.accentColor
                trackColor: root.angelStyle ? Appearance.angel.colBorderSubtle
                    : root.inirStyle ? ColorUtils.transparentize(Appearance.inir.colBorder, 0.5)
                    : root.auroraStyle ? ColorUtils.transparentize(
                        root.blendedColors?.colLayer1 ?? Appearance.colors.colLayer2, 0.6)
                    : Appearance.colors.colLayer2
                enableWavy: true
                onSeekRequested: (seconds) => playerBase.seek(seconds)
            }

            // ═══ TRANSPORT CONTROLS ═══
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.topMargin: 4
                Layout.bottomMargin: 8
                spacing: 2

                TransportBtn {
                    visible: MprisController.shuffleSupported
                    icon: "shuffle"
                    toggled: MprisController.hasShuffle
                    onClicked: MprisController.setShuffle(!MprisController.hasShuffle)
                    tooltipText: Translation.tr("Shuffle")
                    small: true
                }

                Item { Layout.fillWidth: true }

                TransportBtn {
                    icon: "skip_previous"
                    iconFill: true
                    onClicked: playerBase.previous()
                    tooltipText: Translation.tr("Previous")
                }

                // ── Play/Pause — filled accent pill ──
                Item {
                    implicitWidth: 46
                    implicitHeight: 36

                    Rectangle {
                        anchors.fill: parent
                        radius: root.angelStyle ? Appearance.angel.roundingSmall
                            : root.inirStyle ? Appearance.inir.roundingSmall
                            : height / 2

                        color: {
                            if (playMA.containsPress) return root.accentColor
                            if (playMA.containsMouse)
                                return ColorUtils.transparentize(root.accentColor, 0.08)
                            return ColorUtils.transparentize(root.accentColor, 0.18)
                        }

                        Behavior on color {
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                        }

                        scale: playMA.containsPress ? 0.92 : 1.0
                        Behavior on scale {
                            NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: playerBase.effectiveIsPlaying ? "pause" : "play_arrow"
                            iconSize: 24
                            fill: 1
                            color: root.onAccentColor

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
                }

                TransportBtn {
                    icon: "skip_next"
                    iconFill: true
                    onClicked: playerBase.next()
                    tooltipText: Translation.tr("Next")
                }

                Item { Layout.fillWidth: true }

                TransportBtn {
                    visible: MprisController.loopSupported
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

        AngelPartialBorder {
            targetRadius: playerCard.radius
            visible: root.angelStyle
        }
    }

    // ── Player switcher menu ──────────────────────────────────────
    ContextMenu {
        id: playerSwitcherMenu

        model: (MprisController.displayPlayers ?? []).map((player, index) => ({
            type: "item",
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

    function _playerIcon(): string {
        const player = MprisController.activePlayer
        if (!player) return "music_note"
        const name = (player.dbusName ?? "").toLowerCase()
        const identity = (player.identity ?? "").toLowerCase()
        if (name.includes("firefox") || identity.includes("firefox")) return "open_in_browser"
        if (name.includes("chrom") || identity.includes("chrom")) return "open_in_browser"
        if (name.includes("brave") || identity.includes("brave")) return "open_in_browser"
        if (name.includes("vivaldi") || identity.includes("vivaldi")) return "open_in_browser"
        if (name.includes("opera") || identity.includes("opera")) return "open_in_browser"
        if (name.includes("plasma-browser") || identity.includes("plasma-browser"))
            return "open_in_browser"
        if (name.includes("spotify") || identity.includes("spotify")) return "library_music"
        if (name.includes("mpv") || identity.includes("mpv")) return "smart_display"
        if (name.includes("vlc") || identity.includes("vlc")) return "smart_display"
        return "music_note"
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

        implicitWidth: small ? 30 : 34
        implicitHeight: small ? 30 : 34

        Rectangle {
            anchors.fill: parent
            radius: root.angelStyle ? Appearance.angel.roundingSmall
                : root.inirStyle ? Appearance.inir.roundingSmall
                : Appearance.rounding.full

            color: {
                if (tBtnMA.containsPress) return root.colAuxActive
                if (tBtnMA.containsMouse) return root.colAuxHover
                if (tBtn.toggled)
                    return root.angelStyle
                        ? ColorUtils.transparentize(root.accentColor, 0.64)
                        : root.inirStyle ? Appearance.inir.colSecondaryContainer
                        : ColorUtils.transparentize(root.accentColor, 0.78)
                return "transparent"
            }

            Behavior on color {
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: tBtn.icon
                iconSize: tBtn.small ? 18 : 22
                fill: tBtn.iconFill || tBtn.toggled ? 1 : 0
                color: tBtn.toggled
                    ? (root.inirStyle ? Appearance.inir.colOnSecondaryContainer
                        : root.accentColor)
                    : root.colText

                Behavior on color {
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                }
            }

            scale: tBtnMA.containsPress ? 0.88 : 1.0
            Behavior on scale {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }

            MouseArea {
                id: tBtnMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tBtn.clicked()
            }

            StyledToolTip {
                visible: tBtnMA.containsMouse && tBtn.tooltipText !== ""
                text: tBtn.tooltipText
            }
        }
    }
}
