import QtQuick
import Quickshell

// A window's live picture where the runtime can stream one (qs-rs on niri, through niri's ScreenCast), laid over the
// cached still its caller keeps underneath: the still shows at once and the stream covers it from its first frame.
// Each live view holds a compositor session, so `active` follows whether the surface is on screen.
Item {
    id: root
    property int windowId: -1
    property bool active: true
    property bool live: true
    property int fillMode: Image.PreserveAspectCrop
    // Whether a stream is drawing: a caller may stop refreshing its still while it is.
    readonly property bool streaming: capture.item?.streaming ?? false

    // The view sets a property only qs-rs has, so it lives in its own file and is compiled only where it exists.
    readonly property bool supported: typeof Quickshell.hasVersion === "function"
        && Quickshell.hasVersion(0, 3, ["niri-window-capture"])

    Loader {
        id: capture
        anchors.fill: parent
        active: root.supported && root.active && root.windowId >= 0
        source: "LiveWindowCaptureView.qml"
        onLoaded: item.host = root
    }
}
