pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property bool presented: false
    property bool closing: false
    readonly property string monitorName: screen?.name ?? ""

    visible: presented || closing
    screen: {
        const target = GlobalStates.wallpaperSelectorTargetMonitor
        return Quickshell.screens.find(candidate => candidate.name === target)
            ?? GlobalStates.focusedScreen
            ?? GlobalStates.primaryScreen
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell:wallpaperLauncher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: GlobalStates.wallpaperLauncherOpen
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    anchors { top: true; right: true; bottom: true; left: true }

    Component.onCompleted: {
        if (GlobalStates.wallpaperLauncherOpen)
            Qt.callLater(() => root.presented = true)
    }

    Connections {
        target: GlobalStates
        function onWallpaperLauncherOpenChanged(): void {
            if (GlobalStates.wallpaperLauncherOpen) {
                closeTimer.stop()
                root.presented = true
                root.closing = false
            } else {
                if (Appearance.animationsEnabled) {
                    root.closing = true
                    root.presented = false
                    closeTimer.restart()
                } else {
                    root.presented = false
                    root.closing = false
                }
            }
        }
    }

    Timer {
        id: closeTimer
        interval: Math.max(220, Appearance.animation.elementMoveExit.duration + 20)
        onTriggered: root.closing = false
    }

    IpcHandler {
        target: "wallpaperLauncher"
        function next(): void { content.moveSelection(1) }
        function previous(): void { content.moveSelection(-1) }
        function applyCurrent(): void { content.activateCurrent() }
        function status(): string { return content.statusJson() }
    }

    MouseArea {
        anchors.fill: parent
        enabled: GlobalStates.wallpaperLauncherOpen
        onClicked: mouse => {
            const local = mapToItem(content, mouse.x, mouse.y)
            if (local.x < 0 || local.x > content.width
                    || local.y < 0 || local.y > content.height)
                GlobalStates.wallpaperLauncherOpen = false
            else
                mouse.accepted = false
        }
    }

    WallpaperLauncherContent {
        id: content
        monitorName: root.monitorName
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: Math.max(Appearance.sizes.spacingLarge,
                Appearance.sizes.hyprlandGapsOut * 2)
        }
        width: Math.min(implicitWidth,
            parent.width - Math.max(Appearance.sizes.spacingLarge * 2,
                Appearance.sizes.hyprlandGapsOut * 4))
        height: implicitHeight
        transformOrigin: Item.Bottom
        scale: root.presented ? 1 : (root.closing ? 0.985 : 0.96)
        opacity: root.presented ? 1 : 0
        property real revealOffset: root.presented ? 0 : (root.closing ? 10 : 18)
        transform: Translate { y: content.revealOffset }

        Behavior on scale {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: root.presented
                    ? Appearance.animation.elementMoveEnter.duration
                    : Appearance.animation.elementMoveExit.duration
                easing.type: root.presented
                    ? Appearance.animation.elementMoveEnter.type
                    : Appearance.animation.elementMoveExit.type
                easing.bezierCurve: root.presented
                    ? Appearance.animation.elementMoveEnter.bezierCurve
                    : Appearance.animation.elementMoveExit.bezierCurve
            }
        }
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: root.presented
                    ? Appearance.animation.elementMoveEnter.duration
                    : Appearance.animation.elementMoveExit.duration
                easing.type: root.presented
                    ? Appearance.animation.elementMoveEnter.type
                    : Appearance.animation.elementMoveExit.type
                easing.bezierCurve: root.presented
                    ? Appearance.animation.elementMoveEnter.bezierCurve
                    : Appearance.animation.elementMoveExit.bezierCurve
            }
        }
        Behavior on revealOffset {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: root.presented
                    ? Appearance.animation.elementMoveEnter.duration
                    : Appearance.animation.elementMoveExit.duration
                easing.type: root.presented
                    ? Appearance.animation.elementMoveEnter.type
                    : Appearance.animation.elementMoveExit.type
                easing.bezierCurve: root.presented
                    ? Appearance.animation.elementMoveEnter.bezierCurve
                    : Appearance.animation.elementMoveExit.bezierCurve
            }
        }
    }
}
