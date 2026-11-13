import QtQuick
import Quickshell.Wayland
import qs.services

// Loaded by LiveWindowCrop only on qs-rs: `niriWindowId`, `toplevelId` and `sourceRect` do not exist in Quickshell.
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

    // Umbriel names its windows by its own ids. `toplevelId` exists only on runtimes with toplevel-image-copy, the
    // only ones that load this view there (CompositorService.windowCapture), so it is set rather than bound.
    readonly property string toplevelId: CompositorService.isUmbriel
        ? String(NiriService.umbrielWindowKey(view.host?.windowId ?? -1) ?? "") : ""
    onToplevelIdChanged: stream.toplevelId = view.toplevelId

    ScreencopyView {
        id: stream
        anchors.fill: parent
        niriWindowId: CompositorService.niriNative && view.host ? view.host.windowId : -1
        live: view.host?.effectiveLive ?? false
        readonly property rect crop: view.host?.crop ?? Qt.rect(0, 0, 0, 0)
        readonly property size base: view.host?.base ?? Qt.size(0, 0)
        sourceRect: Qt.rect(stream.crop.x * view.scale, stream.crop.y * view.scale,
            stream.crop.width * view.scale, stream.crop.height * view.scale)
        sourceRectBase: Qt.size(stream.base.width * view.scale, stream.base.height * view.scale)
        visible: stream.hasContent
    }
}
