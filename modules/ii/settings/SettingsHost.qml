import qs
import QtQuick
import Quickshell
import qs.services
import qs.modules.ii.settings
import qs.modules.common

// Material's Settings while it is the one in use: its page names for everyone who opens a page by name, and the
// overlay chrome when Settings opens inside the shell. overlayStyle picks the chrome; anything unknown is the nav rail.
Scope {
    id: root

    readonly property bool overlay: Config.options?.settingsUi?.overlayMode ?? false
    readonly property string overlayStyle: Config.options?.settingsUi?.overlayStyle ?? "rail"

    Binding {
        target: GlobalStates
        property: "settingsPageKeys"
        value: SettingsPageRegistry.pages.map(page => page.key)
    }

    Component.onCompleted: DevNavigation.registerSettingsPages(SettingsPageRegistry.pages)
    // Another family's Settings has its own names, or none.
    Component.onDestruction: GlobalStates.settingsPageKeys = []

    LazyLoader {
        active: root.overlay && root.overlayStyle !== "focus" && root.overlayStyle !== "editorial"
        component: SettingsOverlay {}
    }

    LazyLoader {
        active: root.overlay && root.overlayStyle === "focus"
        component: SettingsFocus {}
    }

    LazyLoader {
        active: root.overlay && root.overlayStyle === "editorial"
        component: SettingsEditorial {}
    }
}
