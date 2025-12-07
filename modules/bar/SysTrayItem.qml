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
    property bool targetMenuOpen: false
    // Check if this is a problematic app that needs special handling
    property bool isProblematicApp: TrayService.getProblematicAppInfo(item) !== null

    signal menuOpened(qsWindow: var)
    signal menuClosed()

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    implicitWidth: 20
    implicitHeight: 20
    onPressed: (event) => {
        switch (event.button) {
        case Qt.LeftButton: {
            // Use smart activate for problematic apps (Spotify, Discord, etc.)
            // Falls back to normal activate() if not a known problematic app
            if (!TrayService.smartActivate(item)) {
                item.activate();
            }
            break;
        }
        case Qt.MiddleButton:
            // Middle click: try secondary activate (useful for some apps)
            item.secondaryActivate();
            break;
        case Qt.RightButton:
            if (item.hasMenu) menu.open();
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

    Loader {
        id: menu
        function open() {
            menu.active = true;
        }
        active: false
        sourceComponent: SysTrayMenu {
            Component.onCompleted: this.open();
            trayItemMenuHandle: root.item.menu
            anchor {
                window: root.QsWindow.window
                rect.x: root.x + ((Config.options?.bar?.vertical ?? false) ? 0 : QsWindow.window?.width)
                rect.y: root.y + ((Config.options?.bar?.vertical ?? false) ? QsWindow.window?.height : 0)
                rect.height: root.height
                rect.width: root.width
                edges: (Config.options?.bar?.bottom ?? false) ? (Edges.Top | Edges.Left) : (Edges.Bottom | Edges.Right)
                gravity: (Config.options?.bar?.bottom ?? false) ? (Edges.Top | Edges.Left) : (Edges.Bottom | Edges.Right)
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
        anchorEdges: (!(Config.options?.bar?.bottom ?? false) && !(Config.options?.bar?.vertical ?? false)) ? Edges.Bottom : Edges.Top
    }

}
