pragma Singleton

import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

Singleton {
    id: root

    property bool smartTray: Config.options?.tray?.filterPassive ?? true
    
    // Apps that don't implement DBus Activate properly (libappindicator issue)
    // These apps need workarounds: gtk-launch or window focus
    readonly property var problematicApps: [
        // Pattern: { match: "substring to match in id/title", launch: "desktop-file-id or command" }
        { match: "spotify", launch: "spotify-launcher" },
        { match: "discord", launch: "discord" },
        { match: "vesktop", launch: "vesktop" },
        { match: "armcord", launch: "armcord" },
        { match: "slack", launch: "slack" },
        { match: "teams", launch: "teams-for-linux" },
        { match: "telegram", launch: "org.telegram.desktop" },
        { match: "signal", launch: "signal-desktop" },
        { match: "element", launch: "element-desktop" },
        { match: "steam", launch: "steam" },
        { match: "skype", launch: "skypeforlinux" },
        { match: "viber", launch: "viber" },
        { match: "zoom", launch: "zoom" },
    ]
    
    // Check if an item is a problematic app
    function getProblematicAppInfo(item): var {
        if (!item) return null;
        const id = (item.id ?? "").toLowerCase();
        const title = (item.title ?? "").toLowerCase();
        
        for (const app of problematicApps) {
            if (id.includes(app.match) || title.includes(app.match)) {
                return app;
            }
        }
        return null;
    }
    
    // Smart activate: tries to focus existing window or launch app
    // Returns true if handled, false if should fall back to item.activate()
    function smartActivate(item): bool {
        if (!item) return false;
        
        const appInfo = getProblematicAppInfo(item);
        if (!appInfo) return false;  // Not a problematic app, use normal activate
        
        const id = (item.id ?? "").toLowerCase();
        const title = (item.title ?? "").toLowerCase();
        
        // Try to find and focus existing window (Niri)
        if (CompositorService.isNiri) {
            const window = NiriService.windows.find(w => {
                const appId = (w.app_id ?? "").toLowerCase();
                const windowTitle = (w.title ?? "").toLowerCase();
                return appId.includes(appInfo.match) || windowTitle.includes(appInfo.match);
            });
            
            if (window) {
                NiriService.focusWindow(window.id);
                return true;
            }
        }
        
        // No window found - launch via gtk-launch
        // Use fish shell as per project standards
        const cmd = "gtk-launch " + appInfo.launch + " 2>/dev/null; or " + appInfo.launch + " &";
        Quickshell.execDetached(["fish", "-c", cmd]);
        return true;
    }
    
    // Filter out invalid items (null or missing id)
    function isValidItem(item) {
        return item && item.id;
    }
    
    property var _pinnedItems: Config.options?.tray?.pinnedItems ?? []
    property list<var> itemsInUserList: SystemTray.items.values.filter(i => (isValidItem(i) && _pinnedItems.includes(i.id) && (!smartTray || i.status !== Status.Passive)))
    property list<var> itemsNotInUserList: SystemTray.items.values.filter(i => (isValidItem(i) && !_pinnedItems.includes(i.id) && (!smartTray || i.status !== Status.Passive)))

    property bool invertPins: Config.options?.tray?.invertPinnedItems ?? false
    property list<var> pinnedItems: invertPins ? itemsNotInUserList : itemsInUserList
    property list<var> unpinnedItems: invertPins ? itemsInUserList : itemsNotInUserList

    function getTooltipForItem(item) {
        if (!item) return "";
        const tooltipTitle = item.tooltipTitle ?? "";
        const title = item.title ?? "";
        const id = item.id ?? "";
        const tooltipDescription = item.tooltipDescription ?? "";
        
        var result = tooltipTitle.length > 0 ? tooltipTitle
                : (title.length > 0 ? title : id);
        if (tooltipDescription.length > 0) result += " • " + tooltipDescription;
        if (Config.options?.tray?.showItemId) result += "\n[" + id + "]";
        return result;
    }

    // Pinning
    function pin(itemId) {
        var pins = Config.options?.tray?.pinnedItems ?? [];
        if (pins.includes(itemId)) return;
        pins.push(itemId);
        Config.setNestedValue("tray.pinnedItems", pins);
    }
    function unpin(itemId) {
        var pins = Config.options?.tray?.pinnedItems ?? [];
        Config.setNestedValue("tray.pinnedItems", pins.filter(id => id !== itemId));
    }
    function togglePin(itemId) {
        var pins = Config.options?.tray?.pinnedItems ?? [];
        if (pins.includes(itemId)) {
            unpin(itemId)
        } else {
            pin(itemId)
        }
    }

}
