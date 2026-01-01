import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.overlay
import qs.modules.ii.sidebarRight.volumeMixer
import Quickshell.Services.Mpris

StyledOverlayWidget {
    id: root
    minimumWidth: 300
    minimumHeight: 380

    contentItem: OverlayBackground {
        radius: root.contentRadius
        property real padding: 6

        ColumnLayout {
            id: contentColumn
            anchors {
                fill: parent
                margins: parent.padding
            }
            spacing: 8

            SecondaryTabBar {
                id: tabBar

                currentIndex: Persistent.states.overlay.volumeMixer.tabIndex
                onCurrentIndexChanged: {
                    Persistent.states.overlay.volumeMixer.tabIndex = tabBar.currentIndex;
                }

                SecondaryTabButton {
                    buttonIcon: "media_output"
                    buttonText: Translation.tr("Output")
                }
                SecondaryTabButton {
                    buttonIcon: "mic"
                    buttonText: Translation.tr("Input")
                }
                SecondaryTabButton {
                    buttonIcon: "music_note"
                    buttonText: Translation.tr("Music")
                }
            }
            SwipeView {
                id: swipeView
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: Persistent.states.overlay.volumeMixer.tabIndex
                onCurrentIndexChanged: {
                    Persistent.states.overlay.volumeMixer.tabIndex = swipeView.currentIndex;
                }
                clip: true

                PaddedVolumeDialogContent { 
                    isSink: true 
                }
                PaddedVolumeDialogContent { 
                    isSink: false 
                }
                MusicControlContent {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }
    }

    component PaddedVolumeDialogContent: Item {
        id: paddedVolumeDialogContent
        property alias isSink: volDialogContent.isSink
        property real padding: 12
        implicitWidth: volDialogContent.implicitWidth + padding * 2
        implicitHeight: volDialogContent.implicitHeight + padding * 2

        VolumeDialogContent {
            id: volDialogContent
            anchors {
                fill: parent
                margins: paddedVolumeDialogContent.padding
            }
        }
    }

    component MusicControlContent: Item {
        id: musicContent

        readonly property MprisPlayer activePlayer: MprisController.activePlayer
        readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")

        // Datos de carátula (cover art) y progreso para la pestaña Music
        property var artUrl: activePlayer?.trackArtUrl
        property string artDownloadLocation: Directories.coverArt
        property string artFileName: artUrl ? Qt.md5(artUrl) : ""
        property string artFilePath: artUrl && artUrl.length > 0 ? (artDownloadLocation + "/" + artFileName) : ""
        property bool downloaded: false
        property int _downloadRetryCount: 0
        readonly property int _maxRetries: 3
        property string displayedArtFilePath: downloaded && artFilePath.length > 0 ? Qt.resolvedUrl(artFilePath) : ""

        function checkAndDownloadArt() {
            if (!artUrl || artUrl.length === 0) {
                downloaded = false
                _downloadRetryCount = 0
                return
            }
            artExistsChecker.running = true
        }

        function retryDownload() {
            if (_downloadRetryCount < _maxRetries && artUrl) {
                _downloadRetryCount++
                retryTimer.start()
            }
        }

        Timer {
            id: retryTimer
            interval: 1000 * musicContent._downloadRetryCount
            repeat: false
            onTriggered: {
                if (musicContent.artUrl && !musicContent.downloaded) {
                    coverArtDownloader.targetFile = musicContent.artUrl
                    coverArtDownloader.artFilePath = musicContent.artFilePath
                    coverArtDownloader.running = true
                }
            }
        }

        onArtFilePathChanged: {
            _downloadRetryCount = 0
            checkAndDownloadArt()
        }

        onVisibleChanged: {
            if (visible && artFilePath) {
                checkAndDownloadArt()
            }
        }

        Timer {
            running: activePlayer?.playbackState == MprisPlaybackState.Playing
            interval: Config.options?.resources?.updateInterval ?? 3000
            repeat: true
            onTriggered: activePlayer?.positionChanged()
        }

        Process { // Check if cover art exists
            id: artExistsChecker
            command: ["/usr/bin/test", "-f", musicContent.artFilePath]
            onExited: (exitCode, exitStatus) => {
                if (exitCode === 0) {
                    musicContent.downloaded = true
                    musicContent._downloadRetryCount = 0
                } else {
                    musicContent.downloaded = false
                    coverArtDownloader.targetFile = musicContent.artUrl ?? ""
                    coverArtDownloader.artFilePath = musicContent.artFilePath ?? ""
                    coverArtDownloader.running = true
                }
            }
        }

        Process { // Descarga ligera de carátula a caché
            id: coverArtDownloader
            property string targetFile: artUrl ?? ""
            property string artFilePath: musicContent.artFilePath ?? ""
            command: [
                "/usr/bin/bash",
                "-c",
                `if [ -f '${artFilePath}' ]; then exit 0; fi
                mkdir -p '${musicContent.artDownloadLocation}'
                tmp='${artFilePath}.tmp'
                /usr/bin/curl -sSL --connect-timeout 10 --max-time 30 '${targetFile}' -o "$tmp" && \
                [ -s "$tmp" ] && /usr/bin/mv -f "$tmp" '${artFilePath}' || { rm -f "$tmp"; exit 1; }`
            ]
            onExited: (exitCode, exitStatus) => {
                if (exitCode === 0) {
                    musicContent.downloaded = true
                    musicContent._downloadRetryCount = 0
                } else {
                    musicContent.downloaded = false
                    musicContent.retryDownload()
                }
            }
        }

        ColumnLayout {
            anchors {
                fill: parent
                margins: 16
            }
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    id: coverFrame
                    implicitWidth: 96
                    implicitHeight: 96
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer2

                    StyledImage {
                        anchors.fill: parent
                        visible: musicContent.displayedArtFilePath !== ""
                        source: musicContent.displayedArtFilePath
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                        antialiasing: true
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: musicContent.displayedArtFilePath === ""
                        text: "music_note"
                        iconSize: Appearance.font.pixelSize.huge
                        color: Appearance.colors.colOnLayer2
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        Layout.fillWidth: true
                        font.pixelSize: Appearance.font.pixelSize.large
                        elide: Text.ElideRight
                        text: musicContent.cleanedTitle
                    }

                    StyledText {
                        Layout.fillWidth: true
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                        elide: Text.ElideRight
                        text: activePlayer?.trackArtist || ""
                    }

                    StyledText {
                        Layout.fillWidth: true
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        elide: Text.ElideRight
                        text: (activePlayer && activePlayer.length > 0)
                              ? `${StringUtils.friendlyTimeForSeconds(activePlayer.position)} / ${StringUtils.friendlyTimeForSeconds(activePlayer.length)}`
                              : ""
                    }

                    StyledProgressBar {
                        Layout.fillWidth: true
                        wavy: activePlayer?.isPlaying ?? false
                        highlightColor: Appearance.colors.colPrimary
                        trackColor: Appearance.colors.colSecondaryContainer
                        value: (activePlayer && activePlayer.length > 0)
                               ? (activePlayer.position / activePlayer.length)
                               : 0
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12

                RippleButton {
                    enabled: MprisController.canGoPrevious
                    colBackground: Appearance.colors.colLayer3
                    colBackgroundHover: Appearance.colors.colLayer3Hover
                    colRipple: Appearance.colors.colLayer3Active
                    buttonRadius: height / 2
                    implicitHeight: 40
                    implicitWidth: 40
                    onClicked: MprisController.previous()

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "skip_previous"
                        iconSize: 22
                    }
                }

                RippleButton {
                    enabled: MprisController.canTogglePlaying
                    colBackground: Appearance.colors.colLayer3
                    colBackgroundHover: Appearance.colors.colLayer3Hover
                    colRipple: Appearance.colors.colLayer3Active
                    buttonRadius: height / 2
                    implicitHeight: 44
                    implicitWidth: 44
                    onClicked: MprisController.togglePlaying()

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: MprisController.isPlaying ? "pause" : "play_arrow"
                        iconSize: 26
                    }
                }

                RippleButton {
                    enabled: MprisController.canGoNext
                    colBackground: Appearance.colors.colLayer3
                    colBackgroundHover: Appearance.colors.colLayer3Hover
                    colRipple: Appearance.colors.colLayer3Active
                    buttonRadius: height / 2
                    implicitHeight: 40
                    implicitWidth: 40
                    onClicked: MprisController.next()

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "skip_next"
                        iconSize: 22
                    }
                }
            }
        }
    }
}
