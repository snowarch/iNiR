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

    // A twin with the other filtering at the same size shares its texture, and the later one flips it (QSGPlainTexture
    // "Mipmap settings changed"), across windows too: mipmapped decodes 2 px over the step and plain 1 px, sizes
    // nothing else asks for.
    readonly property int apart: root.mipmap ? 2 : 1
    sourceSize: Qt.size(root.step(root.decodeWidth) + root.apart, root.step(root.decodeHeight) + root.apart)
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    smooth: true
    mipmap: true
    retainWhileLoading: true
}
