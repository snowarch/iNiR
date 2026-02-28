pragma ComponentBehavior: Bound
// CompactMediaPlayer.qml
// Enhanced media player widget for the compact sidebar Controls section
// Shows current track with album art, playback controls, and progress
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

    // PlayerBase for shared logic and dominant color extraction
    PlayerBase {
        id: playerBase
        player: MprisController.activePlayer
    }

    // Blended colors from dominant album art color
    property QtObject blendedColors: AdaptedMaterialScheme {
        color: playerBase.artDominantColor
    }

    // Style tokens (5-style support)
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
            blendedColors?.colLayer0 ?? Appearance.aurora.colSubSurface, 0.7
          )
        : Appearance.colors.colLayer1
    readonly property color colBorder: angelStyle ? Appearance.angel.colCardBorder
        : inirStyle ? Appearance.inir.colBorder : Appearance.colors.colLayer0Border
    readonly property int borderWidth: angelStyle ? Appearance.angel.cardBorderWidth
        : inirStyle ? 1 : (auroraStyle ? 0 : 1)
    readonly property real radius: angelStyle ? Appearance.angel.roundingNormal
        : inirStyle ? Appearance.inir.roundingNormal : Appearance.rounding.normal
    readonly property color colPrimary: angelStyle ? Appearance.angel.colPrimary
        : inirStyle ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
    
    // Dynamic accent from album art
    readonly property color accentColor: playerBase.downloaded && !inirStyle && !angelStyle
        ? (blendedColors?.colPrimary ?? colPrimary)
        : colPrimary

    StyledRectangularShadow {
        target: playerCard
        visible: !inirStyle && !auroraStyle
    }

    Rectangle {
        id: playerCard
        anchors.fill: parent
        implicitHeight: contentColumn.implicitHeight + 16
        radius: root.radius
        color: root.colCard
        border.width: root.borderWidth
        border.color: root.colBorder
        clip: true

        layer.enabled: true
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle { width: playerCard.width; height: playerCard.height; radius: playerCard.radius }
        }

        // Blurred album art background (same pattern as OverviewDashboard)
        Image {
            anchors.fill: parent
            source: playerBase.displayedArtFilePath
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: playerBase.displayedArtFilePath !== ""
            opacity: root.inirStyle ? 0.12 : (root.auroraStyle ? 0.22 : 0.35)
            layer.enabled: Appearance.effectsEnabled
            layer.effect: MultiEffect { blurEnabled: true; blur: 0.35; blurMax: 32; saturation: 0.2 }
        }

        // Gradient overlay for depth and text readability
        Rectangle {
            anchors.fill: parent
            visible: playerBase.downloaded
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { 
                    position: 0.7
                    color: ColorUtils.transparentize(root.colCard, 0.3)
                }
                GradientStop { 
                    position: 1.0
                    color: ColorUtils.transparentize(root.colCard, 0.1)
                }
            }
        }

        ColumnLayout {
            id: contentColumn
            anchors {
                fill: parent
                margins: 10
            }
            spacing: 8

            // Player switcher header (when multiple players)
            RowLayout {
                Layout.fillWidth: true
                visible: (MprisController.displayPlayers?.length ?? 0) > 1
                spacing: 6

                MaterialSymbol {
                    text: playerBase.effectiveIdentity ?? "music_note"
                    iconSize: 14
                    color: root.colTextSecondary
                }

                StyledText {
                    Layout.fillWidth: true
                    text: MprisController.activePlayer?.identity ?? ""
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: root.colTextSecondary
                    elide: Text.ElideRight
                }

                RippleButton {
                    implicitWidth: 20
                    implicitHeight: 20
                    buttonRadius: 10
                    colBackground: "transparent"
                    colBackgroundHover: root.angelStyle ? Appearance.angel.colGlassCardHover
                        : root.inirStyle ? Appearance.inir.colLayer2Hover
                        : Appearance.colors.colLayer1Hover
                    onClicked: {
                        playerSwitcherMenu.anchorItem = this
                        playerSwitcherMenu.active = true
                    }

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "swap_horiz"
                        iconSize: 14
                        color: root.colTextSecondary
                    }

                    StyledToolTip {
                        text: Translation.tr("Switch player")
                    }
                }
            }

            // Main content: Album art + Track info
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Enhanced album art with PlayerArtwork component
                Item {
                    Layout.preferredWidth: 72
                    Layout.preferredHeight: 72

                    PlayerArtwork {
                        id: artwork
                        anchors.fill: parent
                        artSource: playerBase.displayedArtFilePath
                        downloaded: playerBase.downloaded
                        artRadius: root.angelStyle ? Appearance.angel.roundingSmall
                            : root.inirStyle ? Appearance.inir.roundingSmall
                            : Appearance.rounding.small
                        iconSize: 28
                        enableBlurTransition: true

                        // Scale animation on hover
                        scale: artMA.containsMouse ? 1.05 : 1.0
                        Behavior on scale {
                            NumberAnimation {
                                duration: Appearance.animation.elementMoveFast.duration
                                easing.type: Easing.OutCubic
                            }
                        }

                        // Play/Pause overlay on hover
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.artRadius
                            color: "transparent"
                            opacity: artMA.containsMouse ? 1 : 0
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }

                            // Subtle dark scrim for icon readability
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: Qt.rgba(0, 0, 0, 0.35)
                            }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: MprisController.isPlaying ? "pause" : "play_arrow"
                                iconSize: 32
                                fill: 0
                                color: "white"
                            }
                        }

                        MouseArea {
                            id: artMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: MprisController.togglePlaying()
                        }
                    }
                }

                // Track info with enhanced layout
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    PlayerInfo {
                        Layout.fillWidth: true
                        title: playerBase.effectiveTitle
                        artist: playerBase.effectiveArtist
                        titleSize: Appearance.font.pixelSize.normal
                        artistSize: Appearance.font.pixelSize.small
                        titleColor: root.colText
                        artistColor: root.accentColor
                        animateTitle: true
                    }

                    // Time display with accent color
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        visible: MprisController.activePlayer?.length > 0

                        StyledText {
                            text: formatTime(MprisController.activePlayer?.position ?? 0)
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.family: Appearance.font.family.numbers
                            color: root.accentColor
                            font.weight: Font.Medium
                        }

                        StyledText {
                            text: "/"
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: root.colTextSecondary
                            opacity: 0.5
                        }

                        StyledText {
                            text: formatTime(MprisController.activePlayer?.length ?? 0)
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.family: Appearance.font.family.numbers
                            color: root.colTextSecondary
                        }

                        Item { Layout.fillWidth: true }

                        // Open full player button
                        RippleButton {
                            implicitWidth: 22
                            implicitHeight: 22
                            buttonRadius: 11
                            colBackground: "transparent"
                            colBackgroundHover: root.angelStyle ? Appearance.angel.colGlassCardHover
                                : root.inirStyle ? Appearance.inir.colLayer2Hover
                                : Appearance.colors.colLayer1Hover
                            onClicked: GlobalStates.mediaControlsOpen = true

                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "open_in_full"
                                iconSize: 14
                                color: root.colTextSecondary
                            }

                            StyledToolTip {
                                text: Translation.tr("Open full player")
                            }
                        }
                    }
                }
            }

            // Progress bar with dynamic accent color
            PlayerProgress {
                Layout.fillWidth: true
                implicitHeight: 18
                position: MprisController.activePlayer?.position ?? 0
                length: MprisController.activePlayer?.length ?? 0
                canSeek: MprisController.activePlayer?.canSeek ?? false
                isPlaying: MprisController.isPlaying
                highlightColor: root.accentColor
                trackColor: root.angelStyle ? Appearance.angel.colBorderSubtle
                    : root.inirStyle ? ColorUtils.transparentize(Appearance.inir.colBorder, 0.5)
                    : Appearance.colors.colLayer2
                enableWavy: true
                onSeekRequested: (seconds) => {
                    const player = MprisController.activePlayer
                    if (player && player.length > 0) player.position = seconds
                }
            }

            // Control buttons row with enhanced styling
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 6

                // Left spacer (fixed width to match right side)
                Item {
                    Layout.preferredWidth: MprisController.shuffleSupported ? 36 : 0
                    Layout.preferredHeight: 36

                    // Shuffle
                    MediaControlBtn {
                        anchors.fill: parent
                        visible: MprisController.shuffleSupported
                        icon: "shuffle"
                        toggled: MprisController.hasShuffle
                        onClicked: MprisController.setShuffle(!MprisController.hasShuffle)
                        tooltipText: Translation.tr("Shuffle")
                    }
                }

                Item { Layout.fillWidth: true }

                // Previous
                MediaControlBtn {
                    visible: MprisController.canGoPrevious
                    icon: "skip_previous"
                    onClicked: MprisController.previous()
                    tooltipText: Translation.tr("Previous")
                }

                // Play/Pause (larger, highlighted)
                MediaControlBtn {
                    visible: MprisController.canTogglePlaying
                    icon: MprisController.isPlaying ? "pause" : "play_arrow"
                    highlighted: true
                    large: true
                    onClicked: MprisController.togglePlaying()
                    tooltipText: MprisController.isPlaying ? Translation.tr("Pause") : Translation.tr("Play")
                }

                // Next
                MediaControlBtn {
                    visible: MprisController.canGoNext
                    icon: "skip_next"
                    onClicked: MprisController.next()
                    tooltipText: Translation.tr("Next")
                }

                Item { Layout.fillWidth: true }

                // Right spacer (fixed width to match left side)
                Item {
                    Layout.preferredWidth: MprisController.loopSupported ? 36 : 0
                    Layout.preferredHeight: 36

                    // Loop
                    MediaControlBtn {
                        anchors.fill: parent
                        visible: MprisController.loopSupported
                        icon: MprisController.loopState === 2 ? "repeat_one" : "repeat"
                        toggled: MprisController.loopState !== 0
                        onClicked: {
                            const next = (MprisController.loopState + 1) % 3
                            MprisController.setLoopState(next)
                        }
                        tooltipText: Translation.tr("Loop")
                    }
                }
            }
        }

        // Angel partial border
        AngelPartialBorder {
            targetRadius: playerCard.radius
            visible: root.angelStyle
        }
    }

    // Player switcher context menu (styled)
    ContextMenu {
        id: playerSwitcherMenu
        
        model: (MprisController.displayPlayers ?? []).map((player, index) => ({
            type: "item",
            text: player?.identity ?? "",
            iconName: "",
            checkable: true,
            checked: MprisController.activePlayer === player,
            onTriggered: () => {
                if (player) MprisController.activePlayer = player
            }
        }))
    }

    function formatTime(seconds) {
        if (!seconds || seconds <= 0) return "0:00"
        const mins = Math.floor(seconds / 60)
        const secs = Math.floor(seconds % 60)
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }

    // Media control button component with enhanced styling
    component MediaControlBtn: Item {
        id: mcBtn
        required property string icon
        property string tooltipText: ""
        property bool highlighted: false
        property bool toggled: false
        property bool large: false
        
        signal clicked()
        
        implicitWidth: large ? 52 : 36
        implicitHeight: large ? 52 : 36
        
        Rectangle {
            anchors.fill: parent
            radius: root.angelStyle ? Appearance.angel.roundingSmall
                : root.inirStyle ? Appearance.inir.roundingSmall : width / 2
            
            color: {
                if (mcBtnMA.containsPress)
                    return root.angelStyle ? Appearance.angel.colGlassCardActive
                        : root.inirStyle ? Appearance.inir.colLayer2Active
                        : ColorUtils.transparentize(root.accentColor, 0.2)
                if (mcBtnMA.containsMouse)
                    return root.angelStyle ? Appearance.angel.colGlassCardHover
                        : root.inirStyle ? Appearance.inir.colLayer2Hover
                        : ColorUtils.transparentize(root.accentColor, 0.3)
                if (mcBtn.highlighted)
                    return root.accentColor
                if (mcBtn.toggled)
                    return root.angelStyle ? ColorUtils.transparentize(root.accentColor, 0.7)
                        : root.inirStyle ? Appearance.inir.colSecondaryContainer
                        : ColorUtils.transparentize(root.accentColor, 0.85)
                return "transparent"
            }
            
            Behavior on color { 
                ColorAnimation { 
                    duration: Appearance.animation.elementMoveFast.duration 
                } 
            }
            
            
            MaterialSymbol {
                anchors.centerIn: parent
                text: mcBtn.icon
                iconSize: mcBtn.large ? 28 : 20
                fill: mcBtn.highlighted || mcBtn.toggled ? 1 : 0
                color: mcBtn.highlighted
                    ? "white"
                    : mcBtn.toggled
                    ? root.accentColor
                    : root.colTextSecondary
                
                Behavior on color {
                    ColorAnimation { 
                        duration: Appearance.animation.elementMoveFast.duration 
                    }
                }
            }
            
            scale: mcBtnMA.containsPress ? 0.88 : 1.0
            
            Behavior on scale {
                NumberAnimation { 
                    duration: 150
                    easing.type: Easing.OutCubic 
                }
            }
            
            MouseArea {
                id: mcBtnMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: mcBtn.clicked()
            }
            
            StyledToolTip {
                visible: mcBtnMA.containsMouse && mcBtn.tooltipText !== ""
                text: mcBtn.tooltipText
            }
        }
    }
}
