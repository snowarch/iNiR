pragma ComponentBehavior: Bound

import QtQuick
import qs.services

Item {
    id: root
    property string widgetId: ""
    property string slot: ""
    property var targetScreen
    readonly property var entry: CustomWidgets.ready
        ? (CustomWidgets.widgets.find(widget => widget.id === root.widgetId) ?? null)
        : null
    readonly property string sourcePath: String(root.entry?.irisQmlPath ?? "")

    implicitWidth: moduleLoader.item?.implicitWidth ?? 0
    implicitHeight: moduleLoader.item?.implicitHeight ?? 0

    Loader {
        id: moduleLoader
        anchors.centerIn: parent
        active: root.sourcePath.length > 0
        source: root.sourcePath
        onLoaded: {
            if (!item) return
            if (item.hasOwnProperty("irisSlot")) item.irisSlot = root.slot
            if (item.hasOwnProperty("targetScreen")) item.targetScreen = root.targetScreen
        }
    }
}
