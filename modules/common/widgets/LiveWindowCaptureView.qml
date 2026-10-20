import QtQuick
import Quickshell.Wayland

// Loaded by LiveWindowCapture only on qs-rs: `niriWindowId` does not exist in Quickshell.
Item {
    id: view
    property Item host: null
    readonly property bool streaming: stream.hasContent

    clip: (view.host?.fillMode ?? Image.PreserveAspectCrop) === Image.PreserveAspectCrop

    ScreencopyView {
        id: stream
        // The cast is the window's whole surface, so it is sized by its own aspect, never stretched to the tile.
        readonly property real aspect: stream.sourceSize.width > 0 && stream.sourceSize.height > 0
            ? stream.sourceSize.width / stream.sourceSize.height : view.width / Math.max(1, view.height)
        readonly property bool crop: (view.host?.fillMode ?? Image.PreserveAspectCrop) === Image.PreserveAspectCrop
        anchors.centerIn: parent
        width: stream.crop ? Math.max(view.width, view.height * stream.aspect) : Math.min(view.width, view.height * stream.aspect)
        height: stream.width / stream.aspect
        niriWindowId: view.host ? view.host.windowId : -1
        live: view.host?.effectiveLive ?? false
        visible: stream.hasContent
    }
}
