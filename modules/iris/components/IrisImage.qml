pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// An image decoded for the pixels it covers: its size times its window's device pixel ratio,
// rounded up to 32 px steps so a resize or a morph does not decode again every frame, and
// mipmapped so the leftover of the step, or a decode twice the size, shrinks without aliasing.
Image {
    id: root

    property real decodeWidth: root.width
    property real decodeHeight: root.height
    readonly property real pixelRatio: root.QsWindow.window?.devicePixelRatio ?? 1

    function step(value: real): int {
        return Math.max(32, Math.ceil(value * root.pixelRatio / 32) * 32)
    }

    sourceSize: Qt.size(root.step(root.decodeWidth), root.step(root.decodeHeight))
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    smooth: true
    mipmap: true
    retainWhileLoading: true
}
