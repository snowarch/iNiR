pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.services

// Live snips that sit on this screen's desktop, drawn in the desktop's own window among the widgets.
Item {
    id: desk
    required property string screenName

    Repeater {
        model: LivePins.pins.filter(pin => !pin.onTop && (pin.output === desk.screenName || pin.output === "")).map(pin => pin.id)
        LivePinCard {
            required property string modelData
            pinId: modelData
            x: Math.round(liveX)
            y: Math.round(liveY)
            bounds: Qt.size(desk.width, desk.height)
            enabled: !GlobalStates.widgetEditMode && !GlobalStates.screenLocked
        }
    }
}
