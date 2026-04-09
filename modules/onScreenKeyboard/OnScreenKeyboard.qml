import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Scope { // Scope
    id: root
    property bool pinned: Config.options?.osk.pinnedOnStartup ?? false

    component OskControlButton: GroupButton {
        baseWidth: 40
        baseHeight: 40
        clickedWidth: baseWidth
        clickedHeight: baseHeight + 10
        buttonRadius: Appearance.rounding.normal
    }

    Loader {
        id: oskLoader
        active: GlobalStates.oskOpen
        onActiveChanged: {
            if (!oskLoader.active) {
                Ydotool.releaseAllKeys();
            }
        }

        sourceComponent: PanelWindow {
            id: oskRoot
            visible: oskLoader.active && !GlobalStates.screenLocked

            // Full-screen overlay — mask limits input to keyboard area only
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            function hide() {
                GlobalStates.oskOpen = false
            }

            function snapToNearestEdge() {
                const margin = Appearance.sizes.elevationMargin
                const kw = oskBackground.width
                const kh = oskBackground.height
                const pw = oskRoot.width
                const ph = oskRoot.height
                const cx = oskBackground.x + kw / 2
                const cy = oskBackground.y + kh / 2

                // Horizontal: snap to left third, center, or right third
                let targetX
                if (cx < pw / 3) targetX = margin
                else if (cx > pw * 2 / 3) targetX = pw - kw - margin
                else targetX = (pw - kw) / 2

                // Vertical: snap to top or bottom
                let targetY
                if (cy < ph / 2) targetY = margin
                else targetY = ph - kh - margin

                oskBackground.animatePosition = true
                oskBackground.x = targetX
                oskBackground.y = targetY
            }

            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:osk"
            WlrLayershell.layer: WlrLayer.Overlay
            // Hyprland 0.49: Focus is always exclusive and setting this breaks mouse focus grab
            // WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"

            mask: Region {
                item: oskBackground
            }

            // Background shadow follows keyboard
            StyledRectangularShadow {
                target: oskBackground
            }
            Rectangle {
                id: oskBackground
                property bool animatePosition: false
                property real padding: 10

                width: oskRowLayout.implicitWidth + padding * 2
                height: oskRowLayout.implicitHeight + padding * 2

                // Initial position: bottom center (binding breaks on first drag)
                x: parent ? (parent.width - width) / 2 : 0
                y: parent ? parent.height - height - Appearance.sizes.elevationMargin : 0

                color: Appearance.colors.colLayer0
                radius: Appearance.rounding.windowRounding
                transformOrigin: Item.Center
                property real initScale: 0.98
                scale: initScale

                Component.onCompleted: {
                    initScale = 1.0
                }

                Behavior on scale {
                    animation: NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }

                Behavior on x {
                    enabled: oskBackground.animatePosition
                    NumberAnimation {
                        duration: Appearance.animation.elementMove.duration
                        easing.type: Appearance.animation.elementMove.type
                        easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                    }
                }
                Behavior on y {
                    enabled: oskBackground.animatePosition
                    NumberAnimation {
                        duration: Appearance.animation.elementMove.duration
                        easing.type: Appearance.animation.elementMove.type
                        easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                    }
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        oskRoot.hide()
                    }
                }

                RowLayout {
                    id: oskRowLayout
                    anchors.centerIn: parent
                    spacing: 5

                    ColumnLayout {
                        spacing: 2

                        VerticalButtonGroup {
                            OskControlButton { // Pin (locks position)
                                toggled: root.pinned
                                downAction: () => root.pinned = !root.pinned
                                contentItem: MaterialSymbol {
                                    text: root.pinned ? "lock" : "keep"
                                    horizontalAlignment: Text.AlignHCenter
                                    iconSize: Appearance.font.pixelSize.larger
                                    color: root.pinned ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer0
                                }
                            }
                            OskControlButton {
                                onClicked: () => {
                                    oskRoot.hide()
                                }
                                contentItem: MaterialSymbol {
                                    horizontalAlignment: Text.AlignHCenter
                                    text: "keyboard_hide"
                                    iconSize: Appearance.font.pixelSize.larger
                                }
                            }
                        }

                        // Drag handle
                        Item {
                            id: oskDragHandle
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 30
                            opacity: root.pinned ? 0.25 : 0.6

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Appearance.animation.elementMoveFast.duration
                                    easing.type: Appearance.animation.elementMoveFast.type
                                }
                            }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "drag_indicator"
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colOnLayer0
                            }

                            DragHandler {
                                id: oskDragHandler
                                enabled: !root.pinned
                                target: oskBackground
                                xAxis.minimum: 0
                                xAxis.maximum: oskRoot.width - oskBackground.width
                                yAxis.minimum: 0
                                yAxis.maximum: oskRoot.height - oskBackground.height
                                onActiveChanged: {
                                    if (active) {
                                        oskBackground.animatePosition = false
                                    } else {
                                        oskRoot.snapToNearestEdge()
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.topMargin: 20
                        Layout.bottomMargin: 20
                        Layout.fillHeight: true
                        implicitWidth: 1
                        color: Appearance.colors.colOutlineVariant
                    }
                    OskContent {
                        id: oskContent
                        Layout.fillWidth: true
                    }
                }
            }

        }
    }

    IpcHandler {
        target: "osk"

        function toggle(): void {
            GlobalStates.oskOpen = !GlobalStates.oskOpen;
        }

        function close(): void {
            GlobalStates.oskOpen = false
        }

        function open(): void {
            GlobalStates.oskOpen = true
        }
    }
    Loader {
        active: CompositorService.isHyprland
        sourceComponent: Item {
            GlobalShortcut {
                name: "oskToggle"
                description: "Toggles on screen keyboard on press"

                onPressed: {
                    GlobalStates.oskOpen = !GlobalStates.oskOpen;
                }
            }

            GlobalShortcut {
                name: "oskOpen"
                description: "Opens on screen keyboard on press"

                onPressed: {
                    GlobalStates.oskOpen = true
                }
            }

            GlobalShortcut {
                name: "oskClose"
                description: "Closes on screen keyboard on press"

                onPressed: {
                    GlobalStates.oskOpen = false
                }
            }
        }
    }

}
