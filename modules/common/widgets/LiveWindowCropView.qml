import QtQuick
import Quickshell.Wayland

// Loaded by LiveWindowCrop only on qs-rs: `niriWindowId` and `sourceRect` do not exist in Quickshell.
Item {
    id: view
    property Item host: null
    readonly property bool streaming: stream.hasContent
    readonly property rect shownRect: stream.hasContent ? stream.effectiveSourceRect : Qt.rect(0, 0, 0, 0)
    // Buffer pixels per logical pixel of the window (its output's scale), read off the frame itself.
    readonly property real scale: {
        const w = view.host?.windowSize.width ?? 0
        return stream.sourceSize.width > 0 && w > 0 ? stream.sourceSize.width / w : 1
    }

    ScreencopyView {
        id: stream
        anchors.fill: parent
        niriWindowId: view.host ? view.host.windowId : -1
        live: view.host?.effectiveLive ?? false
        readonly property rect crop: view.host?.crop ?? Qt.rect(0, 0, 0, 0)
        readonly property size base: view.host?.base ?? Qt.size(0, 0)
        sourceRect: Qt.rect(stream.crop.x * view.scale, stream.crop.y * view.scale,
            stream.crop.width * view.scale, stream.crop.height * view.scale)
        sourceRectBase: Qt.size(stream.base.width * view.scale, stream.base.height * view.scale)
        visible: stream.hasContent
    }
}
