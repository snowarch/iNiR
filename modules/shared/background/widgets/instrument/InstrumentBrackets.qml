pragma ComponentBehavior: Bound

import QtQuick

// Two opposite corner ticks that frame a picture or a reading, the Instrument's registration marks.
Item {
    id: root
    property color color
    property real length: 13
    property real weight: 2

    Rectangle { width: root.length; height: root.weight; color: root.color; anchors { left: parent.left; top: parent.top } }
    Rectangle { width: root.weight; height: root.length; color: root.color; anchors { left: parent.left; top: parent.top } }
    Rectangle { width: root.length; height: root.weight; color: root.color; anchors { right: parent.right; bottom: parent.bottom } }
    Rectangle { width: root.weight; height: root.length; color: root.color; anchors { right: parent.right; bottom: parent.bottom } }
}
