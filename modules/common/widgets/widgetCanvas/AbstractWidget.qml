import QtQuick
import Quickshell
import qs.modules.common

/*
 * Widget to be placed on a WidgetCanvas.
 * Item-based to allow children positioned outside bounds (toolbars) to receive input.
 */
Item {
    id: root

    property alias animateXPos: xBehavior.enabled
    property alias animateYPos: yBehavior.enabled
    property bool draggable: true
    readonly property bool containsPress: _dragArea.pressed
    readonly property bool isDragging: _dragArea.drag.active

    signal released()

    function center() {
        root.x = (root.parent.width - root.width) / 2
        root.y = (root.parent.height - root.height) / 2
    }

    MouseArea {
        id: _dragArea
        anchors.fill: parent
        // When the widget isn't draggable (NotesWidget out of edit mode, locked widgets,
        // etc.), keep this MouseArea passive so children like TextEdit can receive
        // clicks and keyboard focus. Otherwise the drag MouseArea swallows the press and
        // sticky notes / future interactive widgets become un-typeable.
        enabled: root.draggable
        drag.target: root.draggable ? root : undefined
        cursorShape: (root.draggable && pressed) ? Qt.ClosedHandCursor : root.draggable ? Qt.OpenHandCursor : Qt.ArrowCursor
        onReleased: root.released()
    }

    Behavior on x {
        id: xBehavior
        animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
    }
    Behavior on y {
        id: yBehavior
        animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
    }
}
