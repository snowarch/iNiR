pragma ComponentBehavior: Bound
import qs.modules.barM3
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import qs.modules.common.models
import qs
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

Item {
    id: root

    property bool vertical: false
    property bool isMaterial: Config.options.bar.m3.cornerStyle === 3
    readonly property MprisPlayer activePlayer: {
        const preferred = Config.options.bar.m3.media.preferredPlayer.trim().toLowerCase()
        if (preferred.length === 0) return MprisController.activePlayer
        const _ = MprisController.players.length
        for (const p of MprisController.players) {
            if ((p.identity ?? "").toLowerCase().includes(preferred) ||
                (p.desktopEntry ?? "").toLowerCase().includes(preferred))
                return p
        }
        return MprisController.activePlayer
    }

    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(root.trackTitle) || Translation.tr("No media")

    readonly property string artUrl: activePlayer?.trackArtUrl ?? ""
    readonly property string trackTitle: activePlayer?.trackTitle ?? ""
    readonly property string trackArtist: activePlayer?.trackArtist ?? ""
    readonly property string artworkTransitionKey: `${activePlayer?.dbusName ?? ""}\u001f${activePlayer?.uniqueId ?? 0}\u001f${root.artUrl}`
    property bool   isPlaying:   activePlayer?.isPlaying   ?? false
    property bool   hasTrack:    trackTitle.length > 0
    readonly property bool shouldShow: (Config.options?.bar?.m3?.media?.alwaysVisible ?? false) || root.hasTrack
    readonly property color mediaContainer: M3Palette.pillContainer("media")
    readonly property color mediaInk: M3Palette.pillInk("media")
    readonly property color playContainer: root.isPlaying
        ? M3Palette.primary : M3Palette.surfaceContainerLow
    readonly property color playInk: ColorUtils.ensureReadable(
        root.isPlaying ? M3Palette.primaryForeground : M3Palette.surfaceForeground,
        root.playContainer, 4.5)
    readonly property color playHover: ColorUtils.mix(
        root.playContainer, root.playInk, 0.90)
    readonly property color playActive: ColorUtils.mix(
        root.playContainer, root.playInk, 0.78)
    readonly property color transparentHover: ColorUtils.applyAlpha(root.mediaInk, 0.12)
    readonly property color transparentActive: ColorUtils.applyAlpha(root.mediaInk, 0.22)

    visible: root.shouldShow

    readonly property bool   artDownloaded:       artworkResolver.ready
    readonly property string displayedArtFilePath: artworkResolver.ready ? artworkResolver.displaySource : ""

    MediaArtworkResolver {
        id: artworkResolver
        sourceUrl: root.artUrl
        title:     root.trackTitle
        artist:    root.trackArtist
    }

    Layout.fillHeight: true
    implicitWidth: !root.shouldShow ? 0 : vertical
        ? Appearance.sizes.verticalBarWidth
        : Math.max(
            Config.options.bar.m3.media.minWidth,
            Math.min(
                (isMaterial ? materialRow.implicitWidth : rowLayout.implicitWidth + 8),
                Config.options.bar.m3.media.maxWidth
            )
        )
    implicitHeight: vertical ? (isMaterial ? 32 : mediaCircProg.implicitHeight) : Appearance.sizes.barHeight

    Timer {
        running: activePlayer?.playbackState == MprisPlaybackState.Playing
        interval: Config.options.resources.updateInterval
        repeat: true
        onTriggered: activePlayer.positionChanged()
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton | Qt.RightButton | Qt.LeftButton
        hoverEnabled: !Config.options.bar.m3.tooltips.clickToShow
        onPressed: (event) => {
            if (event.button === Qt.MiddleButton)      activePlayer?.togglePlaying()
            else if (event.button === Qt.BackButton)   activePlayer?.previous()
            else if (event.button === Qt.ForwardButton || event.button === Qt.RightButton) activePlayer?.next()
            else if (event.button === Qt.LeftButton)   GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen
        }
    }

    // Vertical default
    Loader {
        id: mediaCircProg
        active: root.vertical && !root.isMaterial
        visible: active
        anchors.centerIn: parent
        sourceComponent: ClippedFilledCircularProgress {
            implicitSize: 20
            lineWidth: Appearance.rounding.unsharpen
            value: root.activePlayer?.position / root.activePlayer?.length
            colPrimary: Appearance.colors.colOnLayer1
            enableAnimation: false
            Item {
                anchors.centerIn: parent
                width: 20
                height: 20
                MaterialSymbol {
                    anchors.centerIn: parent
                    fill: 1
                    text: root.activePlayer?.isPlaying ? "pause" : "music_note"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer1
                }
            }
        }
    }

    // Vertical Material
    Rectangle {
        visible: root.vertical && root.isMaterial
        anchors.centerIn: parent
        color: root.mediaContainer
        radius: Appearance.rounding.full
        implicitWidth: 32
        implicitHeight: 32

        MaterialSymbol {
            anchors.centerIn: parent
            fill: 1
            text: root.activePlayer?.isPlaying ? "pause" : "music_note"
            iconSize: Appearance.font.pixelSize.normal
            color: root.mediaInk
        }
    }

    // Horizontal default
    Loader {
        id: rowLayout
        active: !root.vertical && !root.isMaterial
        visible: active
        anchors.fill: parent
        sourceComponent: RowLayout {
            spacing: 4
            ClippedFilledCircularProgress {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 3
                implicitSize: 20
                lineWidth: Appearance.rounding.unsharpen
                value: root.activePlayer?.position / root.activePlayer?.length
                colPrimary: Appearance.colors.colOnLayer1
                enableAnimation: false
                Item {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    MaterialSymbol {
                        anchors.centerIn: parent
                        fill: 1
                        text: root.activePlayer?.isPlaying ? "pause" : "music_note"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer1
                    }
                }
            }
            StyledText {
                visible: Config.options.bar.m3.verbose
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                Layout.rightMargin: 0
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                color: Appearance.colors.colOnLayer1
                text: Config.options.bar.m3.media.onlyTitle ? root.cleanedTitle : `${root.cleanedTitle}${root.activePlayer?.trackArtist ? ' • ' + root.activePlayer.trackArtist : ''}`
            }
        }
    }

    // Horizontal Material
    Loader {
        id: materialRow
        active: !root.vertical && root.isMaterial
        visible: active
        anchors.centerIn: parent
        sourceComponent: RowLayout {
            id: innerRow
            anchors.centerIn: parent
            spacing: 6

            // No player
            Loader {
                active: !root.hasTrack
                visible: active
                Layout.alignment: Qt.AlignVCenter
                sourceComponent: RowLayout {
                    spacing: 6

                    // Avatar
                    Rectangle {
                        id: avatarRect
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: Appearance.rounding.full
                        color: M3Palette.primaryContainer
                        Layout.alignment: Qt.AlignVCenter

                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: avatarRect.width
                                height: avatarRect.height
                                radius: avatarRect.radius
                            }
                        }

                        Image {
                            id: avatarImage
                            anchors.fill: parent
                            // Upstream hardcoded ~/.face. iNiR already resolves
                            // the avatar across AccountsService and the two
                            // ricer paths, so use its primary source.
                            source: Directories.userAvatarSourcePrimary
                            sourceSize.width: avatarRect.width * 2
                            sourceSize.height: avatarRect.height * 2
                            fillMode: Image.PreserveAspectCrop
                            onStatusChanged: {
                                if (status === Image.Error)
                                    visible = false
                            }
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "account_circle"
                            iconSize: Appearance.font.pixelSize.normal
                            color: M3Palette.primaryContainerForeground
                            visible: avatarImage.status === Image.Error || avatarImage.status === Image.Null
                        }
                    }

                    ColumnLayout {
                        spacing: -3
                        Layout.alignment: Qt.AlignVCenter
                        Layout.topMargin: 2

                        StyledText {
                            text: SystemInfo.username
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: root.mediaInk
                            elide: Text.ElideRight
                            Layout.maximumWidth: 120
                        }

                        StyledText {
                            id: distroLabel
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: root.mediaInk
                            opacity: 0.7
                            elide: Text.ElideRight
                            Layout.rightMargin: 8
                            Layout.maximumWidth: 120
                            text: SystemInfo.distroName
                        }
                    }
                }
            }

            // Player
            Loader {
                active: root.hasTrack
                visible: active
                Layout.alignment: Qt.AlignVCenter
                sourceComponent: RowLayout {
                    spacing: 6

                    // Art
                    Rectangle {
                        id: artRect
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: Appearance.rounding.full
                        color: root.mediaContainer
                        Layout.alignment: Qt.AlignVCenter

                        MediaCrossSlideImage {
                            anchors.fill: parent
                            source: root.displayedArtFilePath
                            transitionKey: root.artworkTransitionKey
                            downloaded: root.artDownloaded
                            artRadius: artRect.radius
                            placeholderColor: root.mediaContainer
                            iconColor: root.mediaInk
                            iconSize: Appearance.font.pixelSize.normal
                        }
                    }

                    // Title + Artist
                    ColumnLayout {
                        spacing: -4
                        Layout.alignment: Qt.AlignVCenter
                        Layout.topMargin: 2

                        StyledText {
                            id: artistText
                            visible: !(Config.options?.bar?.m3?.media?.onlyTitle ?? false)
                                && root.trackArtist.length > 0
                            text: root.trackArtist
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: root.mediaInk
                            elide: Text.ElideRight
                            Layout.maximumWidth: 120
                            animateChange: true
                        }
                        StyledText {
                            id: titleText
                            readonly property bool titleOnly: Config.options?.bar?.m3?.media?.onlyTitle ?? false
                            Layout.topMargin: 0
                            text: StringUtils.cleanMusicTitle(root.trackTitle) || Translation.tr("No media")
                            font.pixelSize: titleOnly
                                ? Appearance.font.pixelSize.small
                                : Appearance.font.pixelSize.smallie
                            font.weight: titleOnly ? Font.Medium : Font.Normal
                            color: titleOnly
                                ? root.mediaInk
                                : ColorUtils.readableSubtext(root.mediaInk,
                                    root.mediaContainer, 0.72)
                            elide: Text.ElideRight
                            Layout.maximumWidth: 120
                            animateChange: true
                        }
                    }

                    // Play/Pause
                    RippleButton {
                        implicitWidth: 40
                        implicitHeight: 23
                        buttonRadius: root.isPlaying ? Appearance.rounding.normal : 13
                        colBackground: root.playContainer
                        colBackgroundHover: root.playHover
                        colRipple: root.playActive
                        downAction: () => root.activePlayer?.togglePlaying()
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            horizontalAlignment: Text.AlignHCenter
                            text: root.isPlaying ? "pause" : "play_arrow"
                            iconSize: Appearance.font.pixelSize.large
                            fill: 1
                            color: root.playInk
                        }
                    }

                    // Next
                    RippleButton {
                        implicitWidth: 26
                        implicitHeight: 26
                        Layout.leftMargin: -4
                        buttonRadius: 13
                        colBackground: "transparent"
                        colBackgroundHover: root.transparentHover
                        colRipple: root.transparentActive
                        downAction: () => root.activePlayer?.next()
                        altAction: () => root.activePlayer?.previous()
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            horizontalAlignment: Text.AlignHCenter
                            text: "skip_next"
                            iconSize: Appearance.font.pixelSize.large
                            fill: 1
                            color: root.mediaInk
                        }
                    }
                }
            }
        }
    }
}
