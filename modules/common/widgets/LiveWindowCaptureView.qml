import QtQuick
import Quickshell.Wayland
import qs.services

// Loaded by LiveWindowCapture only on qs-rs: `niriWindowId` and `toplevelId` do not exist in Quickshell.
Item {
    id: view
    property Item host: null
    readonly property bool streaming: stream.hasContent

    // Umbriel names its windows by its own ids. `toplevelId` exists only on runtimes with toplevel-image-copy, the
    // only ones that load this view there (CompositorService.windowCapture), so it is set rather than bound.
    readonly property string toplevelId: CompositorService.isUmbriel
        ? String(NiriService.umbrielWindowKey(view.host?.windowId ?? -1) ?? "") : ""
    onToplevelIdChanged: stream.toplevelId = view.toplevelId

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
        niriWindowId: CompositorService.niriNative && view.host ? view.host.windowId : -1
        live: view.host?.effectiveLive ?? false
        visible: stream.hasContent
    }
}
