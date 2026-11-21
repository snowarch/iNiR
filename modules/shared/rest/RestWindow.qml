pragma ComponentBehavior: Bound
import qs
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.common

// The rest screen's host, the same in every family: a window on each screen over everything but the lock, sent away by
// a key, a click or a moved pointer. A family gives it a backdrop that stays still and a face that drifts a little each
// minute, so nothing marks the panel. Idle decides when it shows (GlobalStates.restOpen); this only draws it.
Scope {
    id: root

    property Component backdrop: null
    property Component face: null
    // Rest arrives slowly and leaves at once: the person is back.
    property int fadeIn: Appearance.animationsEnabled ? 900 : 0
    property int fadeOut: Appearance.animationsEnabled ? 160 : 0
    property real driftReach: 28
    property int driftEvery: 40000

    readonly property bool shown: GlobalStates.restOpen && !GlobalStates.screenLocked
    property real driftX: 0
    property real driftY: 0

    function leave(): void {
        GlobalStates.restOpen = false
    }

    // The still picture of the wallpaper this screen shows (a video's first frame).
    function wallpaperOf(screen): string {
        return Wallpapers.stillUrlFor(Wallpapers.desktopWallpaperPath(WallpaperListener.getMonitorName(screen)))
    }

    Timer {
        interval: root.driftEvery
        repeat: true
        running: root.shown
        onTriggered: {
            root.driftX = Math.round((Math.random() * 2 - 1) * root.driftReach)
            root.driftY = Math.round((Math.random() * 2 - 1) * root.driftReach)
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            readonly property bool primary: (win.modelData?.name ?? "") === (GlobalStates.primaryScreen?.name ?? "")

            screen: win.modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.namespace: "quickshell:rest"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.shown && win.primary && !PolkitService.active
                ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            // Leaving, it lets every click through at once.
            mask: Region { item: root.shown ? stage : null }

            Item {
                id: stage
                anchors.fill: parent
                opacity: 0
                property bool armed: false
                Component.onCompleted: stage.armed = true

                states: State {
                    name: "shown"
                    when: stage.armed && root.shown
                    PropertyChanges { target: stage; opacity: 1 }
                }
                transitions: [
                    Transition {
                        to: "shown"
                        NumberAnimation { property: "opacity"; duration: root.fadeIn; easing.type: Easing.InOutSine }
                    },
                    Transition {
                        from: "shown"
                        NumberAnimation { property: "opacity"; duration: root.fadeOut; easing.type: Easing.OutCubic }
                    }
                ]

                Loader {
                    anchors.fill: parent
                    sourceComponent: root.backdrop
                    onLoaded: if ("screen" in item) item.screen = win.modelData
                }

                Loader {
                    anchors.fill: parent
                    sourceComponent: root.face
                    onLoaded: if ("screen" in item) item.screen = win.modelData
                    transform: Translate {
                        x: root.driftX
                        y: root.driftY
                        Behavior on x {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: 6000; easing.type: Easing.InOutSine }
                        }
                        Behavior on y {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: 6000; easing.type: Easing.InOutSine }
                        }
                    }
                }

                // The first position is where the pointer already was; only a real move wakes the screen.
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.BlankCursor
                    property real fromX: -1
                    property real fromY: -1
                    onPositionChanged: mouse => {
                        if (fromX < 0) {
                            fromX = mouse.x
                            fromY = mouse.y
                        } else if (Math.abs(mouse.x - fromX) + Math.abs(mouse.y - fromY) > 16) {
                            root.leave()
                        }
                    }
                    onPressed: root.leave()
                    onWheel: root.leave()
                }

                Item {
                    anchors.fill: parent
                    focus: root.shown && win.primary
                    Keys.onPressed: event => {
                        event.accepted = true
                        root.leave()
                    }
                }
            }
        }
    }
}
