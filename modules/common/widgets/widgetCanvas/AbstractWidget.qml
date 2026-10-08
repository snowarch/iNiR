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
    property real dragThreshold: 6
    property bool dragAboveContent: false
    // An open hand everywhere reads as "this is a handle" even over the widget's own controls. Hosts
    // that have an edit mode show it only there; the drag itself still works with the arrow.
    property bool grabCursor: true
    property bool dragMoved: false
    // MouseArea releases its pressed/drag flags before emitting released.
    // Keep placement bindings suspended until the consumer commits the drop.
    property bool _dragSessionActive: false
    readonly property bool containsPress: _dragArea.pressed || root._dragSessionActive
    readonly property bool isDragging: _dragArea.drag.active

    signal pressed()
    signal released()
    signal canceled()

    function center() {
        root.x = (root.parent.width - root.width) / 2
        root.y = (root.parent.height - root.height) / 2
    }

    MouseArea {
        id: _dragArea
        anchors.fill: parent
        z: root.dragAboveContent ? 100 : 0
        property real startX: 0
        property real startY: 0
        // When the widget isn't draggable (NotesWidget out of edit mode, locked widgets,
        // etc.), keep this MouseArea passive so children like TextEdit can receive
        // clicks and keyboard focus. Otherwise the drag MouseArea swallows the press and
        // sticky notes / future interactive widgets become un-typeable.
        enabled: root.draggable
        drag.target: root.draggable ? root : undefined
        drag.threshold: root.dragThreshold
        cursorShape: root.draggable && drag.active ? Qt.ClosedHandCursor
            : root.draggable && root.grabCursor ? Qt.OpenHandCursor : Qt.ArrowCursor
        onPressed: {
            root._dragSessionActive = true
            startX = root.x
            startY = root.y
            root.dragMoved = false
            root.pressed()
        }
        drag.onActiveChanged: if (drag.active) root.dragMoved = true
        onReleased: {
            root.released()
            root._dragSessionActive = false
        }
        onCanceled: {
            root.x = startX
            root.y = startY
            root.dragMoved = false
            root.canceled()
            root._dragSessionActive = false
        }
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
