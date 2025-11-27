import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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
        return Quickshell.screens[0];
    }
    property bool packageManagerRunning: false
    property bool downloadRunning: false

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
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }

        StyledText {
            id: descriptionLabelText
            anchors.centerIn: parent
            color: descriptionLabel.textColor
            text: descriptionLabel.text
        }
    }

    function detectRunningStuff() {
        packageManagerRunning = false;
        downloadRunning = false;
        detectPackageManagerProc.running = false;
        detectPackageManagerProc.running = true;
        detectDownloadProc.running = false;
        detectDownloadProc.running = true;
    }

    Process {
        id: detectPackageManagerProc
        command: ["pidof", "pacman", "yay", "paru", "dnf", "zypper", "apt", "apx", "xbps", "flatpak", "snap", "apk",
            "yum", "epsi", "pikman"]
        onExited: (exitCode, exitStatus) => {
            root.packageManagerRunning = (exitCode === 0);
        }
    }

    Process {
        id: detectDownloadProc
        command: ["bash", "-c", "pidof curl wget aria2c yt-dlp 2>/dev/null"]
        onExited: (exitCode, exitStatus) => {
            root.downloadRunning = (exitCode === 0);
        }
    }

    Loader {
        id: sessionLoader
        active: GlobalStates.sessionOpen
        onActiveChanged: {
            if (sessionLoader.active) root.detectRunningStuff();
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
            visible: sessionLoader.active
            property string subtitle
            
            function hide() {
                GlobalStates.sessionOpen = false;
            }

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:session"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // Background blur for Niri
            Rectangle {
                anchors.fill: parent
                color: ColorUtils.transparentize(Appearance.m3colors.m3background, 0.5)
                // If Quickshell supports recursive blur or if we can use a shader, put it here.
                // For now, relying on compositor blur if rule exists, or just semi-transparent dark background.
                // Niri specific: layer-rule { blur; } for this namespace "quickshell:session" is needed in config.kdl
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
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
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
