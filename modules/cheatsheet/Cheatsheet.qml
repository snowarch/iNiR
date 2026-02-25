import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property var pages: [
        {
            "icon": "keyboard",
            "name": Translation.tr("Keybinds"),
            "component": "CheatsheetKeybinds.qml"
        },
        {
            "icon": "experiment",
            "name": Translation.tr("Elements"),
            "component": "CheatsheetPeriodicTable.qml"
        },
    ]

    property bool cheatsheetOpen: false
    property int currentPage: Persistent.states?.cheatsheet?.tabIndex ?? 0
    onCurrentPageChanged: {
        if (Persistent.states?.cheatsheet)
            Persistent.states.cheatsheet.tabIndex = currentPage
    }

    function open() { cheatsheetOpen = true; }
    function close() { cheatsheetOpen = false; }
    function toggle() { cheatsheetOpen = !cheatsheetOpen; }

    IpcHandler {
        target: "cheatsheet"
        function toggle(): void { root.toggle(); }
        function close(): void { root.close(); }
        function open(): void { root.open(); }
    }

    // Hyprland-only shortcuts
    Loader {
        active: CompositorService.isHyprland
        sourceComponent: Item {
            GlobalShortcut {
                name: "cheatsheetToggle"
                description: "Toggles cheatsheet on press"
                onPressed: root.toggle()
            }
            GlobalShortcut {
                name: "cheatsheetOpen"
                description: "Opens cheatsheet on press"
                onPressed: root.open()
            }
            GlobalShortcut {
                name: "cheatsheetClose"
                description: "Closes cheatsheet on press"
                onPressed: root.close()
            }
        }
    }

    PanelWindow {
        id: window

        Component.onCompleted: visible = root.cheatsheetOpen

        Connections {
            target: root
            function onCheatsheetOpenChanged() {
                if (root.cheatsheetOpen) {
                    _closeTimer.stop()
                    window.visible = true
                } else {
                    _closeTimer.restart()
                }
            }
        }

        Timer {
            id: _closeTimer
            interval: 250
            onTriggered: window.visible = false
        }

        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "quickshell:cheatsheet"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.cheatsheetOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Item {
            id: keyHandler
            anchors.fill: parent
            focus: root.cheatsheetOpen

            Keys.onPressed: function(event) {
                if (!root.cheatsheetOpen) return
                
                if (event.key === Qt.Key_Escape) {
                    root.close()
                    event.accepted = true
                } else if (event.modifiers === Qt.ControlModifier) {
                    if (event.key === Qt.Key_PageDown || event.key === Qt.Key_Tab) {
                        root.currentPage = (root.currentPage + 1) % root.pages.length
                        event.accepted = true
                    } else if (event.key === Qt.Key_PageUp || event.key === Qt.Key_Backtab) {
                        root.currentPage = (root.currentPage - 1 + root.pages.length) % root.pages.length
                        event.accepted = true
                    }
                }
            }
        }

        // Scrim backdrop (matches Overview pattern)
        Rectangle {
            anchors.fill: parent
            z: -1
            color: ColorUtils.transparentize(Appearance.m3colors.m3background, 1 - 0.85)
            opacity: root.cheatsheetOpen ? 1 : 0

            Behavior on color {
                enabled: Appearance.animationsEnabled
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }

            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: root.cheatsheetOpen
                        ? (Appearance.animation.elementMoveEnter.duration)
                        : (Appearance.animation.elementMoveExit.duration)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.cheatsheetOpen
                        ? Appearance.animationCurves.emphasizedDecel
                        : Appearance.animationCurves.emphasizedAccel
                }
            }
        }

        // Click outside to close
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: mouse => {
                const localPos = mapToItem(cheatsheetBackground, mouse.x, mouse.y)
                const outside = (localPos.x < 0 || localPos.x > cheatsheetBackground.width
                        || localPos.y < 0 || localPos.y > cheatsheetBackground.height)
                if (outside) {
                    root.close()
                } else {
                    mouse.accepted = false
                }
            }
        }

        StyledRectangularShadow {
            target: cheatsheetBackground
            radius: cheatsheetBackground.radius
        }

        Rectangle {
            id: cheatsheetBackground
            anchors.centerIn: parent
            color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                 : Appearance.inirEverywhere ? Appearance.inir.colLayer0
                 : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                 : Appearance.colors.colLayer0
            border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
                        : Appearance.inirEverywhere ? 1 : 1
            border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                        : Appearance.inirEverywhere ? Appearance.inir.colBorder
                        : Appearance.colors.colLayer0Border
            radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                  : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
                  : Appearance.rounding.windowRounding

            Behavior on color {
                enabled: Appearance.animationsEnabled
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
            Behavior on border.color {
                enabled: Appearance.animationsEnabled
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }

            property real padding: 8
            width: Math.min(parent.width - 80, 1100)
            height: Math.min(parent.height - 80, 750)

            // Scale animation for open/close
            scale: root.cheatsheetOpen ? 1.0 : 0.95
            opacity: root.cheatsheetOpen ? 1 : 0
            
            Behavior on scale {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: root.cheatsheetOpen ? 
                        (Appearance.animation?.elementMoveEnter?.duration ?? 400) :
                        (Appearance.animation?.elementMoveExit?.duration ?? 200)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.cheatsheetOpen ?
                        (Appearance.animationCurves?.emphasizedDecel ?? [0.05, 0.7, 0.1, 1, 1, 1]) :
                        (Appearance.animationCurves?.emphasizedAccel ?? [0.3, 0, 0.8, 0.15, 1, 1])
                }
            }
            
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: root.cheatsheetOpen ? 
                        (Appearance.animation?.elementMoveEnter?.duration ?? 400) :
                        (Appearance.animation?.elementMoveExit?.duration ?? 200)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.cheatsheetOpen ?
                        (Appearance.animationCurves?.emphasizedDecel ?? [0.05, 0.7, 0.1, 1, 1, 1]) :
                        (Appearance.animationCurves?.emphasizedAccel ?? [0.3, 0, 0.8, 0.15, 1, 1])
                }
            }

            RowLayout {
                id: cheatsheetLayout
                anchors.fill: parent
                anchors.margins: cheatsheetBackground.padding
                spacing: 8

                Item {
                    id: navRailWrapper
                    Layout.fillHeight: true
                    implicitWidth: navRail.expanded ? 150 : 60
                    Behavior on implicitWidth {
                        enabled: Appearance.animationsEnabled
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }

                    NavigationRail {
                        id: navRail
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }
                        spacing: 10
                        expanded: cheatsheetBackground.width > 900

                        NavigationRailExpandButton {
                            focus: root.cheatsheetOpen
                        }

                        NavigationRailTabArray {
                            currentIndex: root.currentPage
                            expanded: navRail.expanded
                            Repeater {
                                model: root.pages
                                NavigationRailButton {
                                    required property var index
                                    required property var modelData
                                    toggled: root.currentPage === index
                                    onPressed: root.currentPage = index
                                    expanded: navRail.expanded
                                    buttonIcon: modelData.icon
                                    buttonText: modelData.name
                                    showToggledHighlight: false
                                }
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }

                        NavigationRailButton {
                            buttonIcon: "close"
                            buttonText: Translation.tr("Close")
                            expanded: navRail.expanded
                            onPressed: root.close()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Appearance.m3colors.m3surfaceContainerLow
                    radius: Appearance.rounding.small

                    Item {
                        anchors.fill: parent

                        Repeater {
                            model: root.pages.length
                            delegate: Loader {
                                anchors.fill: parent
                                active: true
                                source: root.pages[index].component
                                visible: index === root.currentPage
                                opacity: visible ? 1 : 0

                                Behavior on opacity {
                                    enabled: Appearance.animationsEnabled
                                    NumberAnimation {
                                        duration: 180
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: Appearance.animationCurves.emphasizedLastHalf
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
