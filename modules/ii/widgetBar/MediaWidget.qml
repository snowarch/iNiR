pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models
import qs.services

Rectangle {
    id: root
    
    readonly property MprisPlayer player: MprisController.activePlayer
    readonly property bool hasPlayer: player && player.trackTitle
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: player?.trackArtUrl ? Qt.md5(player.trackArtUrl) : ""
    property string artFilePath: artFileName ? `${artDownloadLocation}/${artFileName}` : ""
    property bool downloaded: false
    property int _downloadRetryCount: 0
    readonly property int _maxRetries: 3
    property string displayedArtFilePath: downloaded ? Qt.resolvedUrl(artFilePath) : ""
    
    color: "transparent"
    implicitHeight: hasPlayer ? contentColumn.implicitHeight : placeholderHeight
    property real placeholderHeight: 80

    function checkAndDownloadArt() {
        if (!player?.trackArtUrl) {
            downloaded = false
            _downloadRetryCount = 0
            return
        }
        artExistsChecker.running = true
    }

    function retryDownload() {
        if (_downloadRetryCount < _maxRetries && player?.trackArtUrl) {
            _downloadRetryCount++
            retryTimer.start()
        }
    }

    Timer {
        id: retryTimer
        interval: 1000 * root._downloadRetryCount
        repeat: false
        onTriggered: {
            if (root.player?.trackArtUrl && !root.downloaded) {
                coverArtDownloader.targetFile = root.player.trackArtUrl
                coverArtDownloader.artFilePath = root.artFilePath
                coverArtDownloader.running = true
            }
        }
    }
    
    // Download cover art
    onArtFilePathChanged: {
        _downloadRetryCount = 0
        checkAndDownloadArt()
    }

    // Re-check cover art when becoming visible
    onVisibleChanged: {
        if (visible && hasPlayer && artFilePath) {
            checkAndDownloadArt()
        }
    }
    
    Process {
        id: artExistsChecker
        command: ["/usr/bin/test", "-f", root.artFilePath]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.downloaded = true
                root._downloadRetryCount = 0
            } else {
                root.downloaded = false
                coverArtDownloader.targetFile = root.player?.trackArtUrl ?? ""
                coverArtDownloader.artFilePath = root.artFilePath
                coverArtDownloader.running = true
            }
        }
    }
    
    Process {
        id: coverArtDownloader
        property string targetFile
        property string artFilePath
        command: ["/usr/bin/bash", "-c", `
            if [ -f '${artFilePath}' ]; then exit 0; fi
            mkdir -p '${root.artDownloadLocation}'
            tmp='${artFilePath}.tmp'
            /usr/bin/curl -sSL --connect-timeout 10 --max-time 30 '${targetFile}' -o "$tmp" && \
            [ -s "$tmp" ] && /usr/bin/mv -f "$tmp" '${artFilePath}' || { rm -f "$tmp"; exit 1; }
        `]
        onExited: (exitCode) => {
            if (exitCode === 0) {
                root.downloaded = true
                root._downloadRetryCount = 0
            } else {
                root.downloaded = false
                root.retryDownload()
            }
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
        Appearance.colors.colPrimaryContainer, 0.8
    )
    
    property QtObject blendedColors: AdaptedMaterialScheme { color: root.artDominantColor }
    
    // Inir colors
    readonly property color jiraColText: Appearance.inir.colText
    readonly property color jiraColTextSecondary: Appearance.inir.colTextSecondary
    readonly property color jiraColPrimary: Appearance.inir.colPrimary
    readonly property color jiraColLayer1: Appearance.inir.colLayer1
    readonly property color jiraColLayer2: Appearance.inir.colLayer2
    
    // No player placeholder
    Rectangle {
        anchors.fill: parent
        visible: !root.hasPlayer
        color: Appearance.inirEverywhere ? Appearance.inir.colLayer1
             : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface 
             : Appearance.colors.colLayer1
        border.width: Appearance.inirEverywhere ? 1 : 0
        border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"
        radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
        
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 4
            
            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: "music_note"
                iconSize: 24
                color: Appearance.colors.colSubtext
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("No media playing")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }
    }
    
    // Player content
    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        visible: root.hasPlayer
        spacing: 0
        
        // Cover art with overlay
        Rectangle {
            id: artContainer
            Layout.fillWidth: true
            Layout.preferredHeight: width * 0.6
            radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
            color: Appearance.inirEverywhere ? root.jiraColLayer1 : blendedColors.colLayer0
            clip: true
            
            Image {
                id: coverArt
                anchors.fill: parent
                source: root.displayedArtFilePath
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: Appearance.inirEverywhere ? 0.3 : 1
                
                layer.enabled: Appearance.effectsEnabled
                layer.effect: GE.OpacityMask {
                    maskSource: Rectangle {
                        width: artContainer.width
                        height: artContainer.height
                        radius: artContainer.radius
                    }
                }
            }
            
            // Gradient overlay for text readability - only for Material
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                visible: !Appearance.inirEverywhere
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: "transparent" }
                    GradientStop { position: 1.0; color: ColorUtils.transparentize(blendedColors.colLayer0, 0.2) }
                }
            }
            
            // Track info overlay
            ColumnLayout {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    margins: 10
                }
                spacing: 2
                
                StyledText {
                    Layout.fillWidth: true
                    text: StringUtils.cleanMusicTitle(root.player?.trackTitle) || "Untitled"
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: Appearance.inirEverywhere ? root.jiraColText : blendedColors.colOnLayer0
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.player?.trackArtist || ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.inirEverywhere ? root.jiraColTextSecondary : blendedColors.colSubtext
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }
        }
        
        // Controls
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: controlsRow.implicitHeight + 16
            color: Appearance.inirEverywhere ? root.jiraColLayer1 : blendedColors.colLayer1
            radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
            border.width: Appearance.inirEverywhere ? 1 : 0
            border.color: Appearance.inir.colBorder
            Layout.topMargin: Appearance.inirEverywhere ? 4 : -Appearance.rounding.normal
            
            ColumnLayout {
                anchors {
                    fill: parent
                    margins: 8
                    topMargin: Appearance.inirEverywhere ? 8 : (Appearance.rounding.normal + 4)
                }
                spacing: 4
                
                // Progress bar
                StyledProgressBar {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 4
                    value: root.player?.length > 0 ? root.player.position / root.player.length : 0
                    highlightColor: Appearance.inirEverywhere ? root.jiraColPrimary : blendedColors.colPrimary
                    trackColor: Appearance.inirEverywhere ? root.jiraColLayer2 : blendedColors.colSecondaryContainer
                }
                
                // Time
                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        text: StringUtils.friendlyTimeForSeconds(root.player?.position ?? 0)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.inirEverywhere ? root.jiraColTextSecondary : blendedColors.colSubtext
                    }
                    Item { Layout.fillWidth: true }
                    StyledText {
                        text: StringUtils.friendlyTimeForSeconds(root.player?.length ?? 0)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.inirEverywhere ? root.jiraColTextSecondary : blendedColors.colSubtext
                    }
                }
                
                // Control buttons
                RowLayout {
                    id: controlsRow
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8
                    
                    RippleButton {
                        implicitWidth: 32
                        implicitHeight: 32
                        buttonRadius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover : blendedColors.colSecondaryContainerHover
                        colRipple: Appearance.inirEverywhere ? Appearance.inir.colLayer2Active : blendedColors.colSecondaryContainerActive
                        downAction: () => root.player?.previous()
                        contentItem: MaterialSymbol {
                            text: "skip_previous"
                            iconSize: 20
                            fill: 1
                            color: Appearance.inirEverywhere ? root.jiraColText : blendedColors.colOnLayer1
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                    
                    RippleButton {
                        implicitWidth: 44
                        implicitHeight: 44
                        buttonRadius: Appearance.inirEverywhere 
                            ? Appearance.inir.roundingSmall 
                            : (root.player?.isPlaying ? Appearance.rounding.small : 22)
                        colBackground: Appearance.inirEverywhere ? "transparent" : blendedColors.colPrimary
                        colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover : blendedColors.colPrimaryHover
                        colRipple: Appearance.inirEverywhere ? Appearance.inir.colLayer2Active : blendedColors.colPrimaryActive
                        downAction: () => root.player?.togglePlaying()
                        contentItem: MaterialSymbol {
                            text: root.player?.isPlaying ? "pause" : "play_arrow"
                            iconSize: 24
                            fill: 1
                            color: Appearance.inirEverywhere ? root.jiraColPrimary : blendedColors.colOnPrimary
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                    
                    RippleButton {
                        implicitWidth: 32
                        implicitHeight: 32
                        buttonRadius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover : blendedColors.colSecondaryContainerHover
                        colRipple: Appearance.inirEverywhere ? Appearance.inir.colLayer2Active : blendedColors.colSecondaryContainerActive
                        downAction: () => root.player?.next()
                        contentItem: MaterialSymbol {
                            text: "skip_next"
                            iconSize: 20
                            fill: 1
                            color: Appearance.inirEverywhere ? root.jiraColText : blendedColors.colOnLayer1
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }
    
    // Position update timer
    Timer {
        running: root.player?.playbackState === MprisPlaybackState.Playing
        interval: 1000
        repeat: true
        onTriggered: root.player?.positionChanged()
    }
}
