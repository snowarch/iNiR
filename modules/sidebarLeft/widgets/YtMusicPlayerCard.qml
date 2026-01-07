pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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

/**
 * YtMusic Now Playing Card - Compact player with visualizer and adaptive colors.
 */
Item {
    id: root
    implicitHeight: hasTrack ? card.implicitHeight + Appearance.sizes.elevationMargin : 0
    visible: hasTrack

    readonly property bool hasTrack: YtMusic.currentVideoId !== ""
    readonly property bool isPlaying: YtMusic.isPlaying
    
    property list<real> visualizerPoints: []

    // Adaptive colors from thumbnail
    ColorQuantizer {
        id: colorQuantizer
        source: YtMusic.currentThumbnail
        depth: 0
        rescaleSize: 1
    }

    property color artColor: ColorUtils.mix(
        colorQuantizer?.colors[0] ?? Appearance.colors.colPrimary,
        Appearance.colors.colPrimaryContainer, 0.7
    )
    property QtObject blendedColors: AdaptedMaterialScheme { color: root.artColor }

    // Style tokens
    readonly property color colText: Appearance.inirEverywhere ? Appearance.inir.colText 
        : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
    readonly property color colTextSecondary: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary 
        : (blendedColors?.colSubtext ?? Appearance.colors.colSubtext)
    readonly property color colPrimary: Appearance.inirEverywhere ? Appearance.inir.colPrimary 
        : (blendedColors?.colPrimary ?? Appearance.colors.colPrimary)
    readonly property color colBg: Appearance.inirEverywhere ? Appearance.inir.colLayer1 
        : Appearance.auroraEverywhere ? ColorUtils.transparentize(blendedColors?.colLayer0 ?? Appearance.colors.colLayer0, 0.7)
        : (blendedColors?.colLayer0 ?? Appearance.colors.colLayer0)
    readonly property color colLayer2: Appearance.inirEverywhere ? Appearance.inir.colLayer2 
        : (blendedColors?.colLayer1 ?? Appearance.colors.colLayer1)
    readonly property real radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
    readonly property real radiusSmall: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small

    // Cava visualizer
    Process {
        id: cavaProc
        running: root.visible && root.isPlaying && GlobalStates.sidebarLeftOpen
        onRunningChanged: { if (!running) root.visualizerPoints = [] }
        command: ["cava", "-p", `${FileUtils.trimFileProtocol(Directories.scriptPath)}/cava/raw_output_config.txt`]
        stdout: SplitParser {
            onRead: data => {
                root.visualizerPoints = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p))
            }
        }
    }

    StyledRectangularShadow { target: card; visible: !Appearance.inirEverywhere && !Appearance.auroraEverywhere }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: parent.width - Appearance.sizes.elevationMargin
        implicitHeight: 140
        radius: root.radius
        color: root.colBg
        border.width: Appearance.inirEverywhere ? 1 : 0
        border.color: Appearance.inir.colBorder
        clip: true

        layer.enabled: true
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle { width: card.width; height: card.height; radius: card.radius }
        }

        // Background art blur
        Image {
            anchors.fill: parent
            source: YtMusic.currentThumbnail
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: Appearance.inirEverywhere ? 0.15 : (Appearance.auroraEverywhere ? 0.25 : 0.5)
            visible: YtMusic.currentThumbnail !== ""
            layer.enabled: Appearance.effectsEnabled
            layer.effect: MultiEffect { blurEnabled: true; blur: 0.2; blurMax: 16; saturation: 0.2 }
        }

        // Gradient overlay for Material
        Rectangle {
            anchors.fill: parent
            visible: !Appearance.inirEverywhere && !Appearance.auroraEverywhere
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.4; color: ColorUtils.transparentize(root.colBg, 0.3) }
                GradientStop { position: 1.0; color: ColorUtils.transparentize(root.colBg, 0.15) }
            }
        }

        // Visualizer
        WaveVisualizer {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 25
            live: root.isPlaying
            points: root.visualizerPoints
            maxVisualizerValue: 1000
            smoothing: 2
            color: ColorUtils.transparentize(root.colPrimary, 0.6)
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 12

            // Cover art
            Rectangle {
                Layout.preferredWidth: 100
                Layout.preferredHeight: 100
                radius: root.radiusSmall
                color: root.colLayer2
                clip: true

                layer.enabled: true
                layer.effect: GE.OpacityMask {
                    maskSource: Rectangle { width: 100; height: 100; radius: root.radiusSmall }
                }

                Image {
                    anchors.fill: parent
                    source: YtMusic.currentThumbnail
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: !YtMusic.currentThumbnail
                    text: "music_note"
                    iconSize: 32
                    color: root.colTextSecondary
                }

                // Loading overlay
                Rectangle {
                    anchors.fill: parent
                    color: ColorUtils.transparentize("black", 0.5)
                    visible: YtMusic.loading

                    BusyIndicator { anchors.centerIn: parent; running: true; implicitWidth: 24; implicitHeight: 24 }
                }

                // Now Playing indicator
                Rectangle {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 6
                    width: 24
                    height: 16
                    radius: 4
                    color: ColorUtils.transparentize("black", 0.4)
                    visible: root.isPlaying && !YtMusic.loading

                    Row {
                        anchors.centerIn: parent
                        spacing: 2
                        Repeater {
                            model: 3
                            Rectangle {
                                required property int index
                                width: 3
                                height: 4 + Math.random() * 6
                                radius: 1
                                color: root.colPrimary
                                
                                SequentialAnimation on height {
                                    running: root.isPlaying
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 4 + index * 2; duration: 200 + index * 100; easing.type: Easing.InOutQuad }
                                    NumberAnimation { to: 10 - index; duration: 300 + index * 50; easing.type: Easing.InOutQuad }
                                }
                            }
                        }
                    }
                }
            }

            // Info & controls
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                spacing: 4

                // Title
                StyledText {
                    Layout.fillWidth: true
                    text: YtMusic.currentTitle || "—"
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: root.colText
                    elide: Text.ElideRight
                    animateChange: true
                    animationDistanceX: 6
                }

                // Artist
                StyledText {
                    Layout.fillWidth: true
                    text: YtMusic.currentArtist || ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.colTextSecondary
                    elide: Text.ElideRight
                    visible: text !== ""
                }

                Item { Layout.fillHeight: true }

                // Progress
                StyledSlider {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 14
                    configuration: StyledSlider.Configuration.Wavy
                    wavy: root.isPlaying
                    animateWave: root.isPlaying
                    highlightColor: root.colPrimary
                    trackColor: root.colLayer2
                    handleColor: root.colPrimary
                    value: YtMusic.currentDuration > 0 ? YtMusic.currentPosition / YtMusic.currentDuration : 0
                    onMoved: YtMusic.seek(value * YtMusic.currentDuration)
                    scrollable: true
                }

                // Time + controls
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: StringUtils.friendlyTimeForSeconds(YtMusic.currentPosition)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.numbers
                        color: root.colText
                        Layout.preferredWidth: 28
                    }

                    Item { Layout.fillWidth: true; Layout.minimumWidth: 0 }

                    // Shuffle
                    RippleButton {
                        implicitWidth: 24; implicitHeight: 24
                        buttonRadius: 12
                        colBackground: YtMusic.shuffleMode ? root.colPrimary : "transparent"
                        colBackgroundHover: YtMusic.shuffleMode ? root.colPrimary : root.colLayer2
                        onClicked: YtMusic.toggleShuffle()
                        contentItem: MaterialSymbol { anchors.centerIn: parent; text: "shuffle"; iconSize: 14; color: YtMusic.shuffleMode ? Appearance.colors.colOnPrimary : root.colTextSecondary }
                        StyledToolTip { text: YtMusic.shuffleMode ? Translation.tr("Shuffle On") : Translation.tr("Shuffle Off") }
                    }

                    // Previous
                    RippleButton {
                        implicitWidth: 28; implicitHeight: 28
                        buttonRadius: 14
                        colBackground: "transparent"
                        colBackgroundHover: root.colLayer2
                        onClicked: YtMusic.playPrevious()
                        contentItem: MaterialSymbol { anchors.centerIn: parent; text: "skip_previous"; iconSize: 18; fill: 1; color: root.colText }
                    }

                    // Play/Pause
                    RippleButton {
                        implicitWidth: 36; implicitHeight: 36
                        buttonRadius: root.isPlaying ? root.radiusSmall : 18
                        colBackground: "transparent"
                        colBackgroundHover: root.colLayer2
                        onClicked: YtMusic.togglePlaying()
                        Behavior on buttonRadius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: 150 } }
                        contentItem: MaterialSymbol { 
                            anchors.centerIn: parent
                            text: root.isPlaying ? "pause" : "play_arrow"
                            iconSize: 22; fill: 1
                            color: root.colPrimary
                        }
                    }

                    // Next
                    RippleButton {
                        implicitWidth: 28; implicitHeight: 28
                        buttonRadius: 14
                        colBackground: "transparent"
                        colBackgroundHover: root.colLayer2
                        onClicked: YtMusic.playNext()
                        contentItem: MaterialSymbol { anchors.centerIn: parent; text: "skip_next"; iconSize: 18; fill: 1; color: root.colText }
                    }

                    // Repeat
                    RippleButton {
                        implicitWidth: 24; implicitHeight: 24
                        buttonRadius: 12
                        colBackground: YtMusic.repeatMode > 0 ? root.colPrimary : "transparent"
                        colBackgroundHover: YtMusic.repeatMode > 0 ? root.colPrimary : root.colLayer2
                        onClicked: YtMusic.cycleRepeatMode()
                        contentItem: MaterialSymbol { 
                            anchors.centerIn: parent
                            text: YtMusic.repeatMode === 1 ? "repeat_one" : "repeat"
                            iconSize: 14
                            color: YtMusic.repeatMode > 0 ? Appearance.colors.colOnPrimary : root.colTextSecondary
                        }
                        StyledToolTip { text: YtMusic.repeatMode === 0 ? Translation.tr("Repeat Off") : YtMusic.repeatMode === 1 ? Translation.tr("Repeat One") : Translation.tr("Repeat All") }
                    }

                    // Volume
                    RippleButton {
                        id: volumeBtn
                        implicitWidth: 24; implicitHeight: 24
                        buttonRadius: 12
                        colBackground: "transparent"
                        colBackgroundHover: root.colLayer2
                        property real previousVolume: 1.0
                        onClicked: {
                            if (YtMusic.volume > 0) {
                                previousVolume = YtMusic.volume
                                YtMusic.setVolume(0)
                            } else {
                                YtMusic.setVolume(previousVolume)
                            }
                        }
                        contentItem: Item {
                            MaterialSymbol { 
                                anchors.centerIn: parent
                                text: YtMusic.volume <= 0 ? "volume_off" : YtMusic.volume < 0.5 ? "volume_down" : "volume_up"
                                iconSize: 14
                                color: YtMusic.volume <= 0 ? root.colTextSecondary : root.colText
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                onWheel: event => {
                                    const delta = event.angleDelta.y > 0 ? 0.05 : -0.05
                                    YtMusic.setVolume(Math.max(0, Math.min(1, YtMusic.volume + delta)))
                                }
                            }
                        }
                        StyledToolTip { text: Translation.tr("Volume") + ": " + Math.round(YtMusic.volume * 100) + "%" }
                    }

                    // Like
                    RippleButton {
                        readonly property bool isLiked: YtMusic.likedSongs.some(s => s.videoId === YtMusic.currentVideoId)
                        implicitWidth: 24; implicitHeight: 24
                        buttonRadius: 12
                        colBackground: "transparent"
                        colBackgroundHover: root.colLayer2
                        onClicked: isLiked ? YtMusic.unlikeSong(YtMusic.currentVideoId) : YtMusic.likeSong()
                        contentItem: MaterialSymbol { 
                            anchors.centerIn: parent
                            text: parent.isLiked ? "favorite" : "favorite_border"
                            iconSize: 14
                            fill: parent.isLiked ? 1 : 0
                            color: parent.isLiked ? Appearance.colors.colError : root.colTextSecondary
                        }
                        StyledToolTip { text: parent.isLiked ? Translation.tr("Remove from Liked") : Translation.tr("Add to Liked") }
                    }

                    Item { Layout.fillWidth: true; Layout.minimumWidth: 0 }

                    StyledText {
                        text: StringUtils.friendlyTimeForSeconds(YtMusic.currentDuration)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.numbers
                        color: root.colText
                        Layout.preferredWidth: 28
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }
}
