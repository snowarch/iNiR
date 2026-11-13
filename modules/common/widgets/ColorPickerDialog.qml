pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.modules.common

// A colour chooser drawn by the shell in the family's look, in place of Qt's white fallback dialog. Same surface as
// QtQuick.Dialogs' ColorDialog: selectedColor, open(), close(), visible, accepted, rejected.
Scope {
    id: root

    property string title: ""
    property color selectedColor: "#808080"
    readonly property bool visible: loader.active

    signal accepted()
    signal rejected()

    function open(): void { loader.active = true }
    function close(): void {
        dropper.finish()
        loader.active = false
    }

    // The sheet's dropper; the chooser steps aside while it runs so the screen is read without it.
    ScreenColorPicker {
        id: dropper
        onPicked: value => {
            if (loader.item)
                loader.item.sheet.take(value)
        }
    }

    LazyLoader {
        id: loader

        PanelWindow {
            readonly property alias sheet: sheet
            screen: GlobalStates.focusedScreen
            visible: !dropper.running
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "inir:colorPicker"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            ColorPickerSheet {
                id: sheet
                anchors.fill: parent
                title: root.title
                startColor: root.selectedColor
                onDropperRequested: dropper.pick()
                onChosen: picked => {
                    root.selectedColor = picked
                    loader.active = false
                    root.accepted()
                }
                onCancelled: {
                    loader.active = false
                    root.rejected()
                }
            }
        }
    }
}
