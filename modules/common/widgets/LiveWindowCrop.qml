import QtQuick
import Quickshell
import qs.services

// A rectangle of a window, live (qs-rs on niri: niri's ScreenCast cropped on the GPU, so it costs what a whole
// window does). `crop` is in the window's logical pixels as it was `base` big; a resize keeps each edge on its side.
Item {
    id: root
    property int windowId: -1
    property rect crop: Qt.rect(0, 0, 0, 0)
    property size base: Qt.size(0, 0)
    // The window's logical size now, to read its scale off the stream (frames come in buffer pixels).
    property size windowSize: Qt.size(0, 0)
    property bool active: true
    property bool live: true
    readonly property bool effectiveLive: root.live && !RecorderStatus.isRecording
    readonly property bool streaming: capture.item?.streaming ?? false
    // The crop on the current frame, in buffer pixels: its aspect is what the caller sizes by.
    readonly property rect shownRect: capture.item?.shownRect ?? Qt.rect(0, 0, 0, 0)

    readonly property bool supported: LivePins.supported
    readonly property bool wanted: root.supported && root.active && root.windowId >= 0 && !GameMode.active

    Loader {
        id: capture
        anchors.fill: parent
        active: root.wanted
        // Sets properties only qs-rs has: compiled only where they exist.
        source: "LiveWindowCropView.qml"
        onLoaded: item.host = root
    }
}
