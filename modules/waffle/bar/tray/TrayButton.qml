pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.modules.waffle.bar

BarIconButton {
    id: root

    required property SystemTrayItem item
    property alias menuOpen: menu.visible
    readonly property bool barAtBottom: Config.options.waffles.bar.bottom
    readonly property bool tintIcons: Config.options.waffles.bar.tintTrayIcons

    iconScale: 0
    Component.onCompleted: {
        root.iconScale = 1
    }
    Behavior on iconScale {
        animation: Looks.transition.enter.createObject(this)
    }

    onClicked: {
        // Use smart activate for problematic apps (Spotify, Discord, etc.)
        // Falls back to normal activate() if not a known problematic app
        if (!TrayService.smartActivate(item)) {
            item?.activate();
        }
    }

    altAction: () => {
        if (item?.hasMenu) menu.active = true
    }

    // Normal icon (no tint)
    IconImage {
        visible: !root.tintIcons
        anchors.centerIn: parent
        width: 16
        height: 16
        source: root.item?.icon ?? ""
    }

    // Tinted icon (same style as WAppIcon)
    Loader {
        active: root.tintIcons
        anchors.centerIn: parent
        width: 16
        height: 16
        sourceComponent: Item {
            anchors.fill: parent
            IconImage {
                id: tintedIcon
                visible: false
                anchors.fill: parent
                source: root.item?.icon ?? ""
            }
            Desaturate {
                id: desaturatedIcon
                visible: false
                anchors.fill: parent
                source: tintedIcon
                desaturation: 0.8
            }
            ColorOverlay {
                anchors.fill: desaturatedIcon
                source: desaturatedIcon
                color: ColorUtils.transparentize(Looks.colors.accent, 0.9)
            }
        }
    }

    WaffleTrayMenu {
        id: menu
        trayItemMenuHandle: root.item?.menu ?? null
    }

    BarToolTip {
        extraVisibleCondition: root.shouldShowTooltip && !root.Drag.active
        text: TrayService.getTooltipForItem(root.item)
    }
}
