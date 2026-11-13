pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// Live snips kept above the windows: each is its own small window (the card and its shadow), moved by its margins.
// Those on the desktop are drawn by the desktop itself (LivePinDesk), which niri stacks over any later Bottom layer.
Scope {
    Variants {
        // Ids, not the pin objects: an update replaces the object and would rebuild the window under the pointer.
        model: GlobalStates.screenLocked ? [] : LivePins.pins.filter(pin => pin.onTop).map(pin => pin.id)

        PanelWindow {
            id: pinWindow
            required property string modelData
            // Room for the shadow; the mask keeps it click-through.
            readonly property int pad: 18

            screen: Quickshell.screens.find(s => s.name === card.pin?.output) ?? Quickshell.screens[0]
            visible: card.pin !== null
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "inir:livepin"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors { top: true; left: true }
            margins {
                left: Math.round(card.liveX) - pinWindow.pad
                top: Math.round(card.liveY) - pinWindow.pad
            }
            implicitWidth: card.width + pinWindow.pad * 2
            implicitHeight: card.height + pinWindow.pad * 2
            // The card's rect, not `item: card`: a runtime that ignores scale kept the mask of its 0.9 pop-in, and the
            // grip and buttons on its edges let the pointer through to the window below.
            mask: Region { x: pinWindow.pad; y: pinWindow.pad; width: card.width; height: card.height }

            LivePinCard {
                id: card
                pinId: pinWindow.modelData
                x: pinWindow.pad
                y: pinWindow.pad
                bounds: Qt.size(pinWindow.screen?.width ?? 1920, pinWindow.screen?.height ?? 1080)
            }
        }
    }
}
