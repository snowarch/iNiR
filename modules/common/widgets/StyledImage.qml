import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Image {
    id: root
    asynchronous: true
    retainWhileLoading: true
    // A picture is on screen: it stays through a source change (retainWhileLoading keeps the old one while status is
    // Loading) and drops only when nothing is left to show (no source, an error). Gate on it, never on status === Ready.
    property bool painted: false
    visible: opacity > 0
    opacity: root.painted ? 1 : 0
    Behavior on opacity {
        animation: NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration; easing.type: Appearance.animation.elementMoveEnter.type; easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve }
    }

    property list<string> fallbacks: []
    property int currentFallbackIndex: 0

    Component.onCompleted: root.painted = root.status === Image.Ready
    onStatusChanged: {
        if (status === Image.Ready)
            root.painted = true;
        else if (status === Image.Null || status === Image.Error)
            root.painted = false;
        if (status === Image.Error && currentFallbackIndex < fallbacks.length) {
            source = fallbacks[currentFallbackIndex];
            currentFallbackIndex += 1;
        }
    }
}
