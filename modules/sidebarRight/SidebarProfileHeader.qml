pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Profile-card header for the right sidebar's system section.
 *
 * The host supplies the resolved surface dialect and screen so the card never
 * mixes a global worldview with a panel-local one, and the wallpaper always
 * matches the monitor where the sidebar is open. Static images remain loaded
 * as the immediate fallback; GIF/video playback is resident only while the
 * sidebar is visible.
 */
Item {
    id: root

    property bool editMode: false
    property bool sectionEditMode: false
    property bool androidToggles: false
    property bool reloadEnabled: true
    property bool settingsEnabled: true
    property bool panelVisible: false
    property bool panelCardStyle: false
    property var panelScreen: null

    property string surfaceDialect: Appearance.surfaceDialectFor("")
    property real panelRadius: 0
    property real panelInset: 0
    property bool atPanelTop: false

    signal editModeRequested()
    signal sectionEditModeRequested()
    signal reloadRequested()
    signal settingsRequested()

    readonly property string _dialect: root.surfaceDialect.length > 0
        ? root.surfaceDialect : Appearance.surfaceDialectFor("")
    readonly property bool _zzz: root._dialect === "zzz"
    readonly property bool _angel: root._dialect === "angel"
    readonly property bool _regalia: root._dialect === "regalia"
    readonly property bool _inir: root._dialect === "inir"
    readonly property bool _aurora: root._dialect === "aurora" || root._angel
    readonly property bool _cookie: root._dialect === "cookie"
    readonly property bool _island: root._dialect === "island"

    readonly property color _colText: root._zzz ? Appearance.zzz.ink
        : root._angel ? Appearance.angel.colText
        : root._inir ? Appearance.inir.colText
        : root._aurora ? Appearance.colors.colOnSurface
        : Appearance.colors.colOnLayer1
    readonly property color _colSubtext: root._zzz ? Appearance.zzz.inkMuted
        : root._angel ? Appearance.angel.colTextSecondary
        : root._inir ? Appearance.inir.colTextSecondary
        : Appearance.colors.colSubtext
    readonly property color _colAccent: root._zzz ? Appearance.zzz.accent
        : root._angel ? Appearance.angel.colPrimary
        : root._inir ? Appearance.inir.colPrimary
        : Appearance.colors.colPrimary
    readonly property color _colBannerBase: root._zzz ? Appearance.zzz.tile
        : root._angel ? Qt.alpha(Appearance.angel.colGlassCard, 1)
        : root._inir ? Qt.alpha(Appearance.inir.colLayer1, 1)
        : root._island ? Qt.alpha(Appearance.colors.colLayer1, 1)
        : Qt.alpha(Appearance.colors.colLayer0Base, 1)
    readonly property color _avatarPlate: root._zzz ? Appearance.zzz.chrome
        : root._angel ? Qt.alpha(Appearance.angel.colGlassCard, 1)
        : root._inir ? Qt.alpha(Appearance.inir.colLayer1, 1)
        : root._island ? Appearance.colors.colLayer1
        : Qt.alpha(Appearance.colors.colLayer1, 1)

    readonly property var _bannerModes: ["wallpaper", "custom", "solid", "none"]
    readonly property string _bannerMode: {
        const raw = Config.options?.sidebar?.right?.headerBanner ?? "wallpaper"
        if (raw === "gradient") return "solid"
        return root._bannerModes.includes(raw) ? raw : "wallpaper"
    }
    readonly property string _customRaw: (Config.options?.sidebar?.right?.headerBannerPath ?? "").trim()
    readonly property string _customSource: root._customRaw.length === 0 ? ""
        : (root._customRaw.startsWith("file://") ? root._customRaw : "file://" + root._customRaw)

    readonly property string _wallpaperPath: {
        const _multiMonitor = WallpaperListener.multiMonitorEnabled
        const _perMonitor = WallpaperListener.effectivePerMonitor
        if (_multiMonitor && root.panelScreen) {
            const monitorName = WallpaperListener.getMonitorName(root.panelScreen)
            const monitorData = _perMonitor[monitorName]
            if (monitorData?.path) return monitorData.path
        }
        return Wallpapers.effectiveWallpaperPath ?? ""
    }
    readonly property string _bannerMediaPath: root._bannerMode === "custom"
        ? root._customRaw
        : root._bannerMode === "wallpaper" ? root._wallpaperPath : ""
    readonly property string _bannerStaticSource: root._bannerMode === "custom"
        ? root._customSource
        : root._bannerMode === "wallpaper"
            ? WallpaperListener.wallpaperUrlForScreen(root.panelScreen)
            : ""
    readonly property bool _bannerIsVideo: WallpaperListener.isVideoPath(root._bannerMediaPath)
    readonly property bool _bannerIsGif: WallpaperListener.isGifPath(root._bannerMediaPath)
    readonly property bool _bannerAllowed: root._bannerMode !== "none"
    readonly property bool _livePlaybackAllowed: root.panelVisible
        && (Config.options?.background?.enableAnimation ?? true)
        && !GlobalStates.screenLocked
        && !Appearance._gameModeActive
        && !Wallpapers.batteryPauseActive

    readonly property real _contentPadding: 12
    readonly property real _bannerInset: root._zzz || root._cookie ? 6
        : root._island ? 4
        : root._regalia ? Appearance.regalia.surfaceInset : 0
    readonly property real _bannerHeight: root._bannerAllowed
        ? Math.max(80, Math.min(94, root.width * 0.22)) : 0
    readonly property real _avatarSize: Math.max(50, Math.min(56, root.width * 0.14))
    readonly property real _avatarOverlap: root._bannerAllowed ? root._avatarSize * 0.4 : 0
    readonly property real _footerHeight: root._bannerAllowed
        ? Math.max(46, root._avatarSize - root._avatarOverlap + 12)
        : root._avatarSize + root._contentPadding * 2
    readonly property real _avatarTop: root._bannerAllowed
        ? root._bannerHeight - root._avatarOverlap : root._contentPadding

    // The profile header is a hero card, not another dense sidebar tile. Give
    // each dialect its established large-card silhouette, while keeping a
    // concentric minimum where the card nests into the panel's top corner.
    readonly property real _profileRadius: root._zzz ? Appearance.zzz.cardRadius
        : root._cookie ? Appearance.rounding.normal
        : root._island ? (Config.options?.appearance?.island?.radius ?? 18)
        : root._angel ? Appearance.angel.roundingLarge
        : root._inir ? Appearance.inir.roundingLarge
        : Appearance.rounding.large
    readonly property real _panelConcentricRadius: (root.atPanelTop && root.panelRadius > root.panelInset)
        ? Appearance.concentricRadius(root.panelRadius, root.panelInset) : 0
    readonly property real _cardRadius: Math.max(root._profileRadius, root._panelConcentricRadius)
    readonly property real _bannerRadius: root._zzz ? Appearance.zzz.controlRadius
        : Appearance.concentricRadius(root._cardRadius, root._bannerInset)

    readonly property string _displayName: SystemInfo.displayName || SystemInfo.username || "user"
    readonly property string _accountIdentity: {
        const user = SystemInfo.username || "user"
        const distro = (SystemInfo.distroId ?? "").trim()
        return (distro.length > 0 && distro !== "unknown") ? `${user}@${distro}` : user
    }

    implicitHeight: card.implicitHeight
    Behavior on implicitHeight {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    PanelSurface {
        id: card
        anchors.fill: parent
        elevation: 1
        cardStyle: root.panelCardStyle
        outlined: false
        surfaceDialect: root._dialect
        islandSkin: root._island
        radiusOverride: root._cardRadius
        implicitHeight: root._bannerHeight + root._footerHeight

        Loader {
            id: bannerLoader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: root._bannerInset
            anchors.leftMargin: root._bannerInset
            anchors.rightMargin: root._bannerInset
            height: Math.max(0, root._bannerHeight
                - root._bannerInset * (root._regalia ? 2 : 1))
            active: root._bannerAllowed
            visible: active
            sourceComponent: bannerComponent
        }

        Component {
            id: bannerComponent

            ClippingRectangle {
                anchors.fill: parent
                radius: root._bannerRadius
                color: root._colBannerBase

                Image {
                    id: bannerImage
                    anchors.fill: parent
                    source: (root._bannerIsGif
                        || (root._bannerIsVideo && root._bannerMode === "custom"))
                        ? "" : root._bannerStaticSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                    sourceSize.width: Math.max(640, Math.round(width * 2))
                    sourceSize.height: Math.max(240, Math.round(height * 2))
                    opacity: status === Image.Ready ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                }

                Loader {
                    anchors.fill: parent
                    active: root._bannerIsGif && root.panelVisible
                    visible: active
                    sourceComponent: AnimatedImage {
                        anchors.fill: parent
                        source: root._bannerMediaPath
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        playing: root._livePlaybackAllowed
                        opacity: status === AnimatedImage.Ready ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation {
                                duration: Appearance.animation.elementMoveFast.duration
                                easing.type: Appearance.animation.elementMoveFast.type
                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                            }
                        }
                    }
                }

                Loader {
                    anchors.fill: parent
                    active: root._bannerIsVideo && root._livePlaybackAllowed
                    visible: active
                    sourceComponent: VideoCrossfader {
                        anchors.fill: parent
                        source: root._bannerMediaPath
                        shouldPlay: root._livePlaybackAllowed
                        enableTransitions: false
                        opacity: hasFrame ? 1 : 0
                        Behavior on opacity {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation {
                                duration: Appearance.animation.elementMoveFast.duration
                                easing.type: Appearance.animation.elementMoveFast.type
                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Math.min(parent.height * 0.42, 42)
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.alpha(root._colBannerBase, 0) }
                        GradientStop { position: 1; color: Qt.alpha(root._colBannerBase, 0.38) }
                    }
                }
            }
        }

        Item {
            id: footerRail
            anchors.left: parent.left
            anchors.right: parent.right
            y: root._bannerHeight
            height: root._footerHeight
        }

        Item {
            id: avatarContainer
            width: root._avatarSize
            height: root._avatarSize
            anchors.left: parent.left
            anchors.leftMargin: root._contentPadding
            y: root._avatarTop

            CookieFace {
                anchors.fill: parent
                visible: root._cookie
                role: "badge"
                selected: true
                color: Appearance.colors.colPrimaryContainer
            }

            Rectangle {
                anchors.fill: parent
                visible: !root._cookie
                radius: root._zzz ? Appearance.zzz.controlRadius : width / 2
                color: root._avatarPlate
                border.width: 2
                border.color: root._colAccent
            }

            ClippingRectangle {
                anchors.centerIn: parent
                width: root._avatarSize - 6
                height: root._avatarSize - 6
                radius: root._zzz ? Appearance.zzz.controlRadius : width / 2
                color: "transparent"

                Image {
                    id: avatarImg
                    anchors.fill: parent
                    source: avatarResolver.resolvedSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                    sourceSize.width: 96
                    sourceSize.height: 96
                    opacity: status === Image.Ready ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                }

                QtObject {
                    id: avatarResolver
                    property int avatarIndex: 0
                    readonly property string resolvedSource: Directories.avatarSourceAt(avatarIndex)
                    readonly property string primaryWatch: Directories.userAvatarSourcePrimary
                    onPrimaryWatchChanged: avatarIndex = 0
                    readonly property int imgStatus: avatarImg.status
                    onImgStatusChanged: {
                        if (imgStatus !== Image.Error) return
                        const nextIdx = avatarIndex + 1
                        if (nextIdx < Directories.userAvatarPaths.length)
                            avatarIndex = nextIdx
                    }
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: avatarImg.status !== Image.Ready
                    text: "person"
                    iconSize: 22
                    color: root._colAccent
                }
            }
        }

        ColumnLayout {
            id: identityColumn
            spacing: 1
            anchors.left: avatarContainer.right
            anchors.leftMargin: 10
            anchors.right: actionRow.left
            anchors.rightMargin: 8
            anchors.verticalCenter: footerRail.verticalCenter

            StyledText {
                Layout.fillWidth: true
                text: root._displayName
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: root._colText
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 5

                CustomIcon {
                    Layout.preferredWidth: 14
                    Layout.preferredHeight: 14
                    source: SystemInfo.distroIcon
                    colorize: true
                    color: root._colSubtext
                }

                StyledText {
                    Layout.fillWidth: true
                    text: `${root._accountIdentity} · ${Translation.tr("Up %1").arg(DateTime.uptime)}`
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root._colSubtext
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }
            }
        }

        RowLayout {
            id: actionRow
            spacing: 2
            anchors.right: parent.right
            anchors.rightMargin: root._contentPadding - 2
            anchors.verticalCenter: footerRail.verticalCenter

            HeaderButton {
                visible: root.androidToggles
                dialect: root._dialect
                buttonIcon: "edit"
                toggled: root.editMode
                tooltipText: Translation.tr("Edit quick toggles")
                onClicked: root.editModeRequested()
            }

            HeaderButton {
                dialect: root._dialect
                buttonIcon: "settings"
                enabled: root.settingsEnabled
                opacity: enabled ? 1 : 0.5
                tooltipText: Translation.tr("Settings")
                onClicked: root.settingsRequested()
            }

            HeaderButton {
                dialect: root._dialect
                buttonIcon: "power_settings_new"
                iconColor: root._zzz ? Appearance.zzz.accent : Appearance.colors.colError
                tooltipText: Translation.tr("Session")
                onClicked: GlobalStates.sessionOpen = true
            }

            HeaderButton {
                id: overflowButton
                dialect: root._dialect
                buttonIcon: "more_horiz"
                toggled: overflowMenu.active
                tooltipText: Translation.tr("More")
                onClicked: overflowMenu.active = !overflowMenu.active
            }
        }

        ContextMenu {
            id: overflowMenu
            anchorItem: overflowButton
            popupAbove: false
            model: [
                {
                    text: Translation.tr("Reload Quickshell"),
                    iconName: "restart_alt",
                    monochromeIcon: true,
                    enabled: root.reloadEnabled,
                    action: () => root.reloadRequested()
                },
                { type: "separator" },
                {
                    text: root.sectionEditMode
                        ? Translation.tr("Done reordering")
                        : Translation.tr("Reorder sections"),
                    iconName: "swap_vert",
                    monochromeIcon: true,
                    action: () => root.sectionEditModeRequested()
                },
                {
                    text: Translation.tr("Compact layout"),
                    iconName: "view_sidebar",
                    monochromeIcon: true,
                    action: () => Config.setNestedValue("sidebar.layout", "compact")
                }
            ]
        }
    }

    component HeaderButton: RippleButton {
        id: headerButton

        property string dialect: Appearance.surfaceDialectFor("")
        property string buttonIcon
        property string tooltipText
        readonly property bool _zzz: headerButton.dialect === "zzz"
        readonly property bool _angel: headerButton.dialect === "angel"
        readonly property bool _inir: headerButton.dialect === "inir"
        readonly property bool _aurora: headerButton.dialect === "aurora" || headerButton._angel
        property color iconColor: headerButton.toggled
            ? (headerButton._zzz ? Appearance.zzz.accent
                : headerButton._angel ? Appearance.angel.colOnPrimary
                : headerButton._inir ? Appearance.inir.colOnPrimaryContainer
                : Appearance.colors.colOnPrimaryContainer)
            : (headerButton._zzz ? Appearance.zzz.ink
                : headerButton._angel ? Appearance.angel.colText
                : headerButton._inir ? Appearance.inir.colText
                : headerButton._aurora ? Appearance.colors.colOnSurface
                : Appearance.colors.colOnLayer1)

        implicitWidth: 34
        implicitHeight: 34
        buttonRadius: headerButton._zzz ? Appearance.zzz.controlRadius
            : headerButton._angel ? Appearance.angel.roundingSmall
            : headerButton._inir ? Appearance.inir.roundingSmall
            : Appearance.rounding.full
        colBackground: "transparent"
        colBackgroundHover: headerButton._zzz ? Appearance.zzz.chrome
            : headerButton._angel ? Appearance.angel.colGlassCardHover
            : headerButton._inir ? Appearance.inir.colLayer2Hover
            : headerButton._aurora ? Appearance.aurora.colSubSurfaceHover
            : Appearance.colors.colLayer2Hover
        colBackgroundToggled: headerButton._zzz ? Appearance.zzz.chrome
            : headerButton._angel ? Appearance.angel.colPrimary
            : headerButton._inir ? Appearance.inir.colPrimaryContainer
            : Appearance.colors.colPrimaryContainer

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            text: headerButton.buttonIcon
            iconSize: 19
            fill: headerButton.toggled ? 1 : 0
            animateFill: true
            color: headerButton.iconColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
        }

        StyledToolTip {
            position: "left"
            text: headerButton.tooltipText
        }
    }
}
