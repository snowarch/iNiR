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
    property bool keepOnTop: Config.options?.osk?.keepOnTop ?? false

    // Aggregated competing-overlay signal. Whenever any of these toggles, this
    // value changes and the inner PanelWindow re-stacks itself on top of its
    // wlr-layer. Sum-of-bits keeps the binding invalidating across overlapping
    // open/close transitions.
    readonly property int _competingStackToken:
          (GlobalStates.overviewOpen          ? (1 <<  0) : 0)
        + (GlobalStates.overlayOpen           ? (1 <<  1) : 0)
        + (GlobalStates.sidebarLeftOpen       ? (1 <<  2) : 0)
        + (GlobalStates.sidebarRightOpen      ? (1 <<  3) : 0)
        + (GlobalStates.settingsOverlayOpen   ? (1 <<  4) : 0)
        + (GlobalStates.clipboardOpen         ? (1 <<  5) : 0)
        + (GlobalStates.altSwitcherOpen       ? (1 <<  6) : 0)
        + (GlobalStates.mediaControlsOpen     ? (1 <<  7) : 0)
        + (GlobalStates.wallpaperSelectorOpen ? (1 <<  8) : 0)
        + (GlobalStates.coverflowSelectorOpen ? (1 <<  9) : 0)
        + (GlobalStates.cheatsheetOpen        ? (1 << 10) : 0)
        + (GlobalStates.controlPanelOpen      ? (1 << 11) : 0)
        + (GlobalStates.regionSelectorOpen    ? (1 << 12) : 0)
        + (GlobalStates.sessionOpen           ? (1 << 13) : 0)
        + (GlobalStates.searchOpen            ? (1 << 14) : 0)
        + (GlobalStates.waffleActionCenterOpen        ? (1 << 15) : 0)
        + (GlobalStates.waffleNotificationCenterOpen  ? (1 << 16) : 0)
        + (GlobalStates.waffleWidgetsOpen             ? (1 << 17) : 0)
        + (GlobalStates.waffleClipboardOpen           ? (1 << 18) : 0)
        + (GlobalStates.waffleTaskViewOpen            ? (1 << 19) : 0)
        + (GlobalStates.waffleAltSwitcherOpen         ? (1 << 20) : 0)

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
            // Brief unmap window used by restack() to recreate the wlr-layer-shell
            // surface, which puts it back on top of the Overlay layer.
            property bool _remapping: false
            visible: oskLoader.active && !GlobalStates.screenLocked && !_remapping

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

            // Re-raise within wlr-layer Overlay when another overlay opens.
            // wlr-layer-shell does not define z-order within a layer, but every
            // compositor (Niri, Hyprland, sway, river) appends a freshly-mapped
            // surface to the top of its layer. We exploit that by briefly
            // unmapping the OSK surface so the next map lands on top.
            // `set_layer` alone does NOT re-stack — tested, doesn't work.
            function restack(): void {
                if (!root.keepOnTop) return;
                if (!oskLoader.active || GlobalStates.screenLocked) return;
                oskRoot._remapping = true;
                restackTimer.restart();
            }
            Timer {
                id: restackTimer
                interval: 40
                repeat: false
                onTriggered: oskRoot._remapping = false
            }
            on_CompetingTokenChanged: oskRoot.restack()
            readonly property int _competingToken: root._competingStackToken
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
                            OskControlButton { // Keep on top of other overlays (launcher, sidebars, ...)
                                toggled: root.keepOnTop
                                downAction: () => Config.setNestedValue("osk.keepOnTop", !root.keepOnTop)
                                contentItem: MaterialSymbol {
                                    text: "flip_to_front"
                                    horizontalAlignment: Text.AlignHCenter
                                    iconSize: Appearance.font.pixelSize.larger
                                    color: root.keepOnTop ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer0
                                }
                                StyledToolTip {
                                    text: Translation.tr("Keep keyboard above launcher and other overlays")
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
