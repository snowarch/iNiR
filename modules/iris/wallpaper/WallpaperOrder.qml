pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.iris.style
import qs.modules.iris.components

// The list's order: a segmented control while it fits (the library's three), a pop-up for the web's six.
Item {
    id: root

    required property var engine
    readonly property real d: IrisStyle.density
    readonly property bool popped: root.engine.orders.length > 4

    visible: root.engine.sortable
    implicitHeight: Math.round(36 * root.d)
    implicitWidth: root.popped ? popup.implicitWidth : segmented.implicitWidth

    IrisSegmented {
        id: segmented
        visible: !root.popped
        anchors.verticalCenter: parent.verticalCenter
        glyphOnly: true
        implicitHeight: root.implicitHeight
        accessibleName: Translation.tr("Order")
        options: root.popped ? [] : root.engine.orders
        current: root.engine.order
        onPicked: value => root.engine.setOrder(value)
    }
    IrisPopupButton {
        id: popup
        visible: root.popped
        anchors.verticalCenter: parent.verticalCenter
        implicitHeight: root.implicitHeight
        accessibleName: Translation.tr("Order")
        options: root.popped ? root.engine.orders : []
        current: root.engine.order
        onPicked: value => root.engine.setOrder(value)
    }
}
