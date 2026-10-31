pragma ComponentBehavior: Bound
import QtQuick
import qs
import qs.modules.common.widgets

// One widget on one screen: built-in, an extra mascot or someone's own. Its file is made only while it is shown, and
// told at construction which desktop it sits on, so its first read of config is already the right screen's.
FadeLoader {
    id: slot

    required property var desktop
    required property string file
    property int order: 0
    property var props: ({})

    z: item?.desktopStackZ ?? 0
    containmentMask: GlobalStates.widgetEditMode ? hitMask : null
    WidgetInputMask { id: hitMask; loader: slot }

    function _sync(): void {
        if (slot.active)
            slot.setSource(slot.file, Object.assign({ desktop: slot.desktop, widgetIndex: slot.order }, slot.props))
        else
            slot.source = ""
    }
    onActiveChanged: slot._sync()
    Component.onCompleted: if (slot.active) slot._sync()
}
