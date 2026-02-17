import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects

MouseArea {
    id: root
    required property SystemTrayItem item
    property var trayParent: null  // Reference to SysTray for closing other menus
    property bool targetMenuOpen: false

    signal menuOpened(qsWindow: var)
    signal menuClosed()

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    implicitWidth: 18
    implicitHeight: 18
    onPressed: (event) => {
        switch (event.button) {
        case Qt.LeftButton: {
            // Smart toggle: click to show, click again to minimize
            // Falls back to normal activate() if not handled
            if (!TrayService.smartToggle(item)) {
                item.activate();
            }
            break;
        }
        case Qt.MiddleButton:
            // Middle click: try secondary activate (useful for some apps)
            item.secondaryActivate();
            break;
        case Qt.RightButton:
            if (item.hasMenu) {
                // Close other tray menus first
                if (trayParent) trayParent.closeAllTrayMenus();
                menu.open();
            }
            break;
        }
        event.accepted = true;
    }
    onEntered: {
        if (!item) return;
        const tooltipTitle = item.tooltipTitle ?? "";
        const title = item.title ?? "";
        const id = item.id ?? "";
        const tooltipDescription = item.tooltipDescription ?? "";
        
        tooltip.text = tooltipTitle.length > 0 ? tooltipTitle
                : (title.length > 0 ? title : id);
        if (tooltipDescription.length > 0) tooltip.text += " • " + tooltipDescription;
        if (Config.options?.bar?.tray?.showItemId) tooltip.text += "\n[" + id + "]";
    }

    // Listen for close signal from parent tray
    Connections {
        target: root.trayParent
        enabled: root.trayParent !== null
        function onCloseAllTrayMenus() {
            if (menu.active && menu.item) {
                menu.item.close();
            }
        }
    }

    Loader {
        id: menu
        function open() {
            menu.active = true;
        }
        active: false
        sourceComponent: SysTrayMenu {
            Component.onCompleted: this.open();
            trayItemMenuHandle: root.item.menu
            anchorHovered: root.containsMouse
            anchor {
                item: root
                edges: (Config.options?.bar?.vertical ?? false)
                    ? ((Config.options?.bar?.bottom ?? false) ? Edges.Left : Edges.Right)
                    : ((Config.options?.bar?.bottom ?? false) ? Edges.Top : Edges.Bottom)
                gravity: (Config.options?.bar?.vertical ?? false)
                    ? ((Config.options?.bar?.bottom ?? false) ? Edges.Left : Edges.Right)
                    : ((Config.options?.bar?.bottom ?? false) ? Edges.Top : Edges.Bottom)
                adjustment: (Config.options?.bar?.vertical ?? false)
                    ? PopupAdjustment.SlideY : PopupAdjustment.SlideX
            }
            onMenuOpened: (window) => root.menuOpened(window);
            onMenuClosed: {
                root.menuClosed();
                menu.active = false;
            }
        }
    }

    IconImage {
        id: trayIcon
        visible: !(Config.options?.bar?.tray?.monochromeIcons ?? false)
        source: root.item?.icon ?? ""
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
    }

    Loader {
        active: Config.options?.bar?.tray?.monochromeIcons ?? false
        anchors.centerIn: parent
        width: root.width
        height: root.height
        sourceComponent: Item {
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
                color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.9)
            }
        }
    }

    PopupToolTip {
        id: tooltip
        extraVisibleCondition: root.containsMouse
        alternativeVisibleCondition: extraVisibleCondition
        anchorEdges: (Config.options?.bar?.vertical ?? false)
            ? ((Config.options?.bar?.bottom ?? false) ? Edges.Left : Edges.Right)
            : ((Config.options?.bar?.bottom ?? false) ? Edges.Top : Edges.Bottom)
    }

}
