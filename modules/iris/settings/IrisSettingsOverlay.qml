pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.field as Field

PanelWindow {
    id: root
    visible: GlobalStates.settingsOverlayOpen || body.frame.progress > 0
    IrisOutputHold {
        id: outputHold
        wanted: GlobalStates.focusedScreen
        live: root.visible
    }
    screen: outputHold.output
    color: "transparent"
    anchors { left: true; right: true; top: true; bottom: true }
    margins {
        left: IrisFrame.band
        right: IrisFrame.band
        top: IrisFrame.band
        bottom: IrisFrame.band
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell:iris-settings"
    WlrLayershell.layer: GlobalStates.settingsNativeDialogOpen ? WlrLayer.Bottom : WlrLayer.Overlay
    WlrLayershell.keyboardFocus: GlobalStates.settingsNativeDialogOpen ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
    mask: GlobalStates.settingsOverlayOpen && body.frame.armed ? null : frameRegion
    Region { id: frameRegion; item: body.frame }
    Field.IrisBlurRegion {
        window: root
        shapes: body.frame.blurShapes
        windowWidth: root.width
        windowHeight: root.height
    }

    IrisSettings {
        id: body
        anchors.fill: parent
    }
}
