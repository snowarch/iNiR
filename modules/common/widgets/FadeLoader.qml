import QtQuick

import qs.modules.common
import qs.modules.common.widgets

Loader {
    id: root
    property bool shown: true
    property bool _animatingOut: false
    opacity: shown ? 1 : 0
    visible: opacity > 0
    active: shown || _animatingOut
    enabled: shown

    onShownChanged: {
        if (shown)
            _animatingOut = false
        else
            _animatingOut = opacity > 0
    }

    onOpacityChanged: {
        if (!shown && opacity <= 0)
            _animatingOut = false
    }

    Behavior on opacity {
        enabled: Appearance.animationsEnabled
        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
}
