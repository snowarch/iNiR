import QtQuick

// Esc while a drag is live puts the thing back. It holds the keys for the drag and hands them to whoever had them
// after. The surface binds `active` to its drag, adds `&& !letGo` to the dragging MouseArea or DragHandler's
// `enabled` (dropping the grab is what cancels it) and returns the thing in its own onCanceled.
Item {
    id: root

    property bool active: false
    readonly property bool letGo: _letGo
    property bool _letGo: false
    property Item _before: null
    signal cancel()

    width: 0
    height: 0

    onActiveChanged: {
        if (active) {
            root._before = Window.activeFocusItem
            root.forceActiveFocus()
        } else {
            if (root.activeFocus && root._before)
                root._before.forceActiveFocus()
            root.focus = false
            root._before = null
        }
    }

    Keys.onEscapePressed: event => {
        event.accepted = true
        root.cancel()
        // A grab only drops when its handler turns off: one tick off, then back.
        root._letGo = true
        root._letGo = false
    }
}
