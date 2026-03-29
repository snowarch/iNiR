import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property var focusedScreen: {
        if (CompositorService.isNiri && typeof NiriService !== "undefined" && NiriService.currentOutput) {
            const name = NiriService.currentOutput;
            const matchNiri = Quickshell.screens.find(s => s && s.name === name);
            if (matchNiri)
                return matchNiri;
        }
        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
            const name = Hyprland.focusedMonitor.name;
            const matchHypr = Quickshell.screens.find(s => s && s.name === name);
            if (matchHypr)
                return matchHypr;
        }
        return GlobalStates.primaryScreen;
    }
    readonly property bool packageManagerRunning: SessionWarnings.packageManagerRunning
    readonly property bool downloadRunning: SessionWarnings.downloadRunning

    component DescriptionLabel: Rectangle {
        id: descriptionLabel
        property string text
        property color textColor: Appearance.colors.colOnTooltip
        color: Appearance.colors.colTooltip
        clip: true
        radius: Appearance.rounding.normal
        implicitHeight: descriptionLabelText.implicitHeight + 10 * 2
        implicitWidth: descriptionLabelText.implicitWidth + 15 * 2

        Behavior on implicitWidth {
            animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
        }

        StyledText {
            id: descriptionLabelText
            anchors.centerIn: parent
            color: descriptionLabel.textColor
            text: descriptionLabel.text
        }
    }

    Loader {
        id: sessionLoader
        active: true

        property bool _sessionClosing: false

        Connections {
            target: GlobalStates
            function onSessionOpenChanged() {
                if (GlobalStates.sessionOpen) {
                    _sessionCloseTimer.stop()
                    sessionLoader._sessionClosing = false
                    SessionWarnings.refresh()
                } else {
                    sessionLoader._sessionClosing = true
                    _sessionCloseTimer.restart()
                }
            }
        }

        Timer {
            id: _sessionCloseTimer
            interval: 250
            onTriggered: sessionLoader._sessionClosing = false
        }
        Connections {
            target: GlobalStates
            function onScreenLockedChanged() {
                if (GlobalStates.screenLocked) {
                    GlobalStates.sessionOpen = false;
                }
            }
        }

        sourceComponent: PanelWindow { // Session menu
            id: sessionRoot
            visible: GlobalStates.sessionOpen || sessionLoader._sessionClosing
            property string subtitle
            
            function hide() {
                GlobalStates.sessionOpen = false;
            }

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:session"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            readonly property string _monitorName: root.focusedScreen?.name ?? ""
            readonly property real _screenScale: root.focusedScreen?.scale ?? 1
            readonly property string _wallpaperSource: Wallpapers.currentThemingWallpaperPath(_monitorName)
            readonly property string _wallpaperPath: {
                const path = FileUtils.trimFileProtocol(String(_wallpaperSource ?? ""));
                if (!path) return "";
                const isVideo = WallpaperListener.isVideoPath(path);
                const isGif = WallpaperListener.isGifPath(path);
                if (isVideo || isGif) {
                    const thumbnail = Wallpapers.getExpectedThumbnailPath(path, "x-large");
                    return thumbnail || path;
                }
                return path;
            }

            function ensureWallpaperThumbnail(): void {
                const path = FileUtils.trimFileProtocol(String(sessionRoot._wallpaperSource ?? ""))
                if (!path) return
                if (WallpaperListener.isVideoPath(path) || WallpaperListener.isGifPath(path))
                    Wallpapers.ensureThumbnailForPath(path, "x-large")
            }

            Component.onCompleted: ensureWallpaperThumbnail()

            Connections {
                target: Wallpapers
                function onChanged() {
                    sessionRoot.ensureWallpaperThumbnail()
                }
            }
            
            // Background wallpaper with blur (like lock screen)
            Image {
                id: backgroundWallpaper
                anchors.fill: parent
                source: sessionRoot._wallpaperPath
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                smooth: true
                mipmap: true
                sourceSize.width: Math.round((root.focusedScreen?.width ?? 1920) * sessionRoot._screenScale)
                sourceSize.height: Math.round((root.focusedScreen?.height ?? 1080) * sessionRoot._screenScale)
                
                readonly property real blurRadius: 64
                readonly property real blurZoom: 1.1
                
                layer.enabled: true
                layer.effect: FastBlur {
                    radius: backgroundWallpaper.blurRadius
                }
                
                transform: Scale {
                    origin.x: backgroundWallpaper.width / 2
                    origin.y: backgroundWallpaper.height / 2
                    xScale: backgroundWallpaper.blurZoom
                    yScale: backgroundWallpaper.blurZoom
                }
            }
            
            // Dim overlay for better readability
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.4)
            }

            implicitWidth: root.focusedScreen?.width ?? 0
            implicitHeight: root.focusedScreen?.height ?? 0

            MouseArea {
                id: sessionMouseArea
                anchors.fill: parent
                onClicked: {
                    sessionRoot.hide()
                }
            }

            ColumnLayout { // Content column
                id: contentColumn
                anchors.centerIn: parent
                spacing: 15

                // Subtle open animation for the session dialog
                transformOrigin: Item.Center
                scale: GlobalStates.sessionOpen ? 1.0 : 0.97
                opacity: GlobalStates.sessionOpen ? 1.0 : 0.0
                Behavior on scale {
                    animation: NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration; easing.type: Appearance.animation.elementMoveEnter.type; easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve }
                }
                Behavior on opacity {
                    animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        sessionRoot.hide();
                    }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 0
                    StyledText { // Title
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        font {
                            family: Appearance.font.family.title
                            pixelSize: Appearance.font.pixelSize.title
                            variableAxes: Appearance.font.variableAxes.title
                        }
                        text: Translation.tr("Session")
                    }

                    StyledText { // Small instruction
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: Appearance.font.pixelSize.normal
                        text: Translation.tr("Arrow keys to navigate, Enter to select\nEsc or click anywhere to cancel")
                    }
                }

                GridLayout {
                    columns: 4
                    columnSpacing: 15
                    rowSpacing: 15

                    SessionActionButton {
                        id: sessionLock
                        focus: sessionRoot.visible
                        buttonIcon: "lock"
                        buttonText: Translation.tr("Lock")
                        onClicked:  { Session.lock(); sessionRoot.hide() }
                        onFocusChanged: { if (focus) sessionRoot.subtitle = buttonText }
                        KeyNavigation.right: sessionSleep
                        KeyNavigation.down: sessionHibernate
                    }
                    SessionActionButton {
                        id: sessionSleep
                        buttonIcon: "dark_mode"
                        buttonText: Translation.tr("Sleep")
                        onClicked:  { 
                            Session.suspend();
                            sessionRoot.hide();
                        }
                        onFocusChanged: { if (focus) sessionRoot.subtitle = buttonText }
                        KeyNavigation.left: sessionLock
                        KeyNavigation.right: sessionLogout
                        KeyNavigation.down: sessionShutdown
                    }
                    SessionActionButton {
                        id: sessionLogout
                        buttonIcon: "logout"
                        buttonText: Translation.tr("Logout")
                        onClicked: { Session.logout(); sessionRoot.hide() }
                        onFocusChanged: { if (focus) sessionRoot.subtitle = buttonText }
                        KeyNavigation.left: sessionSleep
                        KeyNavigation.right: sessionTaskManager
                        KeyNavigation.down: sessionReboot
                    }
                    SessionActionButton {
                        id: sessionTaskManager
                        buttonIcon: "browse_activity"
                        buttonText: Translation.tr("Task Manager")
                        onClicked:  { Session.launchTaskManager(); sessionRoot.hide() }
                        onFocusChanged: { if (focus) sessionRoot.subtitle = buttonText }
                        KeyNavigation.left: sessionLogout
                        KeyNavigation.down: sessionFirmwareReboot
                    }

                    SessionActionButton {
                        id: sessionHibernate
                        buttonIcon: "downloading"
                        buttonText: Translation.tr("Hibernate")
                        onClicked:  { Session.hibernate(); sessionRoot.hide() }
                        onFocusChanged: { if (focus) sessionRoot.subtitle = buttonText }
                        KeyNavigation.up: sessionLock
                        KeyNavigation.right: sessionShutdown
                    }
                    SessionActionButton {
                        id: sessionShutdown
                        buttonIcon: "power_settings_new"
                        buttonText: Translation.tr("Shutdown")
                        onClicked:  { Session.poweroff(); sessionRoot.hide() }
                        onFocusChanged: { if (focus) sessionRoot.subtitle = buttonText }
                        KeyNavigation.left: sessionHibernate
                        KeyNavigation.right: sessionReboot
                        KeyNavigation.up: sessionSleep
                    }
                    SessionActionButton {
                        id: sessionReboot
                        buttonIcon: "restart_alt"
                        buttonText: Translation.tr("Reboot")
                        onClicked:  { Session.reboot(); sessionRoot.hide() }
                        onFocusChanged: { if (focus) sessionRoot.subtitle = buttonText }
                        KeyNavigation.left: sessionShutdown
                        KeyNavigation.right: sessionFirmwareReboot
                        KeyNavigation.up: sessionLogout
                    }
                    SessionActionButton {
                        id: sessionFirmwareReboot
                        buttonIcon: "settings_applications"
                        buttonText: Translation.tr("Reboot to firmware settings")
                        onClicked:  { Session.rebootToFirmware(); sessionRoot.hide() }
                        onFocusChanged: { if (focus) sessionRoot.subtitle = buttonText }
                        KeyNavigation.up: sessionTaskManager
                        KeyNavigation.left: sessionReboot
                    }
                }

                DescriptionLabel {
                    Layout.alignment: Qt.AlignHCenter
                    text: sessionRoot.subtitle
                }
            }

            RowLayout {
                anchors {
                    top: contentColumn.bottom
                    topMargin: 10
                    horizontalCenter: contentColumn.horizontalCenter
                }
                spacing: 10

                Loader {
                    active: root.packageManagerRunning
                    visible: active
                    sourceComponent: DescriptionLabel {
                        text: Translation.tr("Your package manager is running")
                        textColor: Appearance.m3colors.m3onErrorContainer
                        color: Appearance.m3colors.m3errorContainer
                    }
                }
                Loader {
                    active: root.downloadRunning
                    visible: active
                    sourceComponent: DescriptionLabel {
                        text: Translation.tr("There might be a download in progress")
                        textColor: Appearance.m3colors.m3onErrorContainer
                        color: Appearance.m3colors.m3errorContainer
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "session"
        enabled: Config.options?.panelFamily !== "waffle"

        function toggle(): void {
            GlobalStates.sessionOpen = !GlobalStates.sessionOpen;
        }

        function close(): void {
            GlobalStates.sessionOpen = false
        }

        function open(): void {
            GlobalStates.sessionOpen = true
        }
    }
    Loader {
        active: CompositorService.isHyprland
        sourceComponent: Item {
            GlobalShortcut {
                name: "sessionToggle"
                description: "Toggles session screen on press"

                onPressed: {
                    GlobalStates.sessionOpen = !GlobalStates.sessionOpen;
                }
            }

            GlobalShortcut {
                name: "sessionOpen"
                description: "Opens session screen on press"

                onPressed: {
                    GlobalStates.sessionOpen = true
                }
            }

            GlobalShortcut {
                name: "sessionClose"
                description: "Closes session screen on press"

                onPressed: {
                    GlobalStates.sessionOpen = false
                }
            }
        }
    }

}
