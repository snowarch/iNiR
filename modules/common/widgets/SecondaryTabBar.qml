pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common

TabBar {
    id: root
    property real indicatorPadding: 8
    property bool wheelNavigationEnabled: true
    property bool bottomBorderVisible: true
    Layout.fillWidth: true

    function _tabItemAt(index: int): Item {
        const row = root?.contentItem?.children?.[0]
        const items = row?.children ?? []
        if (index < 0 || index >= items.length)
            return null
        return items[index] ?? null
    }

    background: Item {
        WheelHandler {
            enabled: root.wheelNavigationEnabled
            onWheel: (event) => {
                if (event.angleDelta.y < 0) root.incrementCurrentIndex();
                else if (event.angleDelta.y > 0) root.decrementCurrentIndex();
            }
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        }

        Rectangle {
            id: activeIndicator
            z: 9999
            anchors.bottom: parent.bottom
            topLeftRadius: height
            topRightRadius: height
            bottomLeftRadius: 0
            bottomRightRadius: 0
            color: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary

            property Item currentTabItem: root._tabItemAt(root.currentIndex)
            property real targetVisualWidth: {
                const item = currentTabItem
                if (!item)
                    return Math.max(0, root.width / Math.max(root.count, 1) - root.indicatorPadding * 2)

                const rawWidth = Number(item.tabContentWidth ?? item.width)
                const safeWidth = Number.isFinite(rawWidth) ? rawWidth : item.width
                return Math.max(0, Math.min(item.width, safeWidth))
            }
            property real targetVisualX: {
                const item = currentTabItem
                if (!item)
                    return root.indicatorPadding

                const mapped = item.mapToItem(parent, 0, 0)
                const rawX = Number(mapped?.x ?? 0)
                const safeX = Number.isFinite(rawX) ? rawX : 0
                return safeX + (item.width - targetVisualWidth) / 2
            }

            height: 3
            x: targetVisualX
            width: targetVisualWidth

            Behavior on x {
                NumberAnimation {
                    duration: Appearance.animation.elementMove.duration
                    easing.type: Appearance.animation.elementMove.type
                    easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: Appearance.animation.elementMove.duration
                    easing.type: Appearance.animation.elementMove.type
                    easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                }
            }
        }

        Rectangle { // Tabbar bottom border
            id: tabBarBottomBorder
            z: 9998
            visible: root.bottomBorderVisible
            anchors.bottom: parent.bottom
            height: visible ? 1 : 0
            anchors {
                left: parent.left
                right: parent.right
            }
            color: Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle : Appearance.colors.colOutlineVariant
        }
    }
}
