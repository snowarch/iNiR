//@ pragma UseQApplication
//@ pragma AppId inir-settings
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env INIR_STANDALONE_WINDOW=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
// Launcher keeps QT_SCALE_FACTOR=1; shell scaling lives in appearance.typography.sizeScale

import QtQuick
import Quickshell
import qs.modules.common
import qs.services

// Settings as its own window: the family whose Settings is in use draws it (its plugin.json part `settingsApp`).
ShellRoot {
    id: root

    readonly property bool settled: Plugins.ready && Config.ready
    // The theme is applied here, as the shell does: the family's window loads only once Config is ready, so a
    // handler of its own on Config's ready never ran and a manual or preset theme opened in the factory dark (#325).
    // Wallpaper colours too: they load only once something names their loader (Waffle's Taskbar, 10-29).
    readonly property bool configReady: Config.ready
    onConfigReadyChanged: if (root.configReady) ThemeService.applyCurrentTheme()

    // A family without a window keeps its Settings inside the shell.
    function _quitIfNone(): void {
        if (!root.settled || app.url.length > 0) return
        console.warn(`[Settings] ${Plugins.settingsFamily} has no Settings window; it opens inside the shell`)
        Qt.quit()
    }
    onSettledChanged: root._quitIfNone()
    Component.onCompleted: {
        if (root.configReady) ThemeService.applyCurrentTheme()
        root._quitIfNone()
    }

    FamilyPartLoader { id: app; family: Plugins.settingsFamily; part: "settingsApp"; when: Config.ready }
}
