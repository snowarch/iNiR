import qs
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
    property bool _presentedOpen: false
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

    readonly property bool cheatsheetOpen: GlobalStates.cheatsheetOpen
    property int currentPage: Persistent.states?.cheatsheet?.tabIndex ?? 0
    onCurrentPageChanged: {
        if (Persistent.states?.cheatsheet)
            Persistent.states.cheatsheet.tabIndex = currentPage
    }

    function open() { GlobalStates.cheatsheetOpen = true; }
    function close() { GlobalStates.cheatsheetOpen = false; }
    function toggle() { GlobalStates.cheatsheetOpen = !GlobalStates.cheatsheetOpen; }

    PanelWindow {
        id: window

        Component.onCompleted: {
            visible = root.cheatsheetOpen
            if (root.cheatsheetOpen)
                Qt.callLater(() => { root._presentedOpen = root.cheatsheetOpen })
        }

        Connections {
            target: root
            function onCheatsheetOpenChanged() {
                if (root.cheatsheetOpen) {
                    _closeTimer.stop()
                    window.visible = true
                    Qt.callLater(() => { root._presentedOpen = root.cheatsheetOpen })
                } else {
                    root._presentedOpen = false
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

        // Scrim backdrop (matches Overview pattern)
        Rectangle {
            anchors.fill: parent
            z: -1
            color: ColorUtils.transparentize(Appearance.colors.colBackground, 1 - 0.85)
            opacity: root._presentedOpen ? 1 : 0

            Behavior on color {
                enabled: Appearance.animationsEnabled
                animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }

            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: root._presentedOpen
                        ? (Appearance.animation.elementMoveEnter.duration)
                        : (Appearance.animation.elementMoveExit.duration)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root._presentedOpen
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
            visible: !Appearance.zzzEverywhere
        }

        Rectangle {
            id: cheatsheetBackground
            anchors.centerIn: parent
            color: Appearance.zzzEverywhere ? Appearance.zzz.bg0
                 : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                 : Appearance.inirEverywhere ? Appearance.inir.colLayer0
                 : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                 : Appearance.colors.colLayer0
            border.width: Appearance.zzzEverywhere ? 1
                        : Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
                        : Appearance.inirEverywhere ? 1 : 1
            Behavior on border.width {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
            border.color: Appearance.zzzEverywhere ? Appearance.zzz.borderColor
                        : Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                        : Appearance.inirEverywhere ? Appearance.inir.colBorder
                        : Appearance.colors.colLayer0Border
            radius: Appearance.zzzEverywhere ? Appearance.zzz.panelRadius
                  : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                  : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
                  : Appearance.rounding.windowRounding
            Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }

            Behavior on color {
                enabled: Appearance.animationsEnabled
                animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
            Behavior on border.color {
                enabled: Appearance.animationsEnabled
                animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }

            property real padding: 8
            width: Math.min(parent.width - 80, 1100)
            height: Math.min(parent.height - 80, 750)

            // Key handler on the content ancestor so events from any
            // focused child (search field, nav buttons) propagate here.
            Keys.onPressed: event => {
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

            // Scale animation for open/close
            scale: root._presentedOpen ? 1.0 : 0.95
            opacity: root._presentedOpen ? 1 : 0
            
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
                        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }

                    MascotImage {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: active && navRail.expanded
                        width: navRail.expanded ? 130 : 54
                        height: width
                        surface: "cheatsheet"
                        pose: "cheatsheet-sensei"
                        Behavior on width {
                            enabled: Appearance.animationsEnabled
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
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
                    color: Appearance.zzzEverywhere ? Appearance.zzz.bg1 : Appearance.colors.colSurfaceContainerLow
                    radius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.rounding.small
                    Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
                    Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }

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
