pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root
    required property var loader

    containmentMask: QtObject {
        function contains(point: point): bool {
            const widget = root.loader?.item
            if (!widget || !widget.visible)
                return false
            const local = widget.mapFromItem(root.loader, point.x, point.y)
            return typeof widget.containsEditPoint === "function"
                ? widget.containsEditPoint(local) : widget.contains(local)
        }
    }
}
