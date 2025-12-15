pragma Singleton

import QtQuick
import Quickshell
import qs.modules.common
import qs.services

Singleton {
    id: root

    property bool ready: false
    readonly property string currentTheme: Config.options?.appearance?.theme ?? "auto"
    readonly property bool isAutoTheme: currentTheme === "auto"
    readonly property bool isStandaloneSettingsWindow: (Quickshell.env("QS_NO_RELOAD_POPUP") ?? "") === "1"
    readonly property bool defaultApplyExternal: !isStandaloneSettingsWindow

    onCurrentThemeChanged: {
        if (Config.ready) {
            console.log("[ThemeService] currentTheme changed to:", currentTheme, "- applying");
            Qt.callLater(() => applyCurrentTheme(defaultApplyExternal));
        }
    }

    function setTheme(themeId, applyExternal = true) {
        console.log("[ThemeService] setTheme called with:", themeId);
        Config.setNestedValue(["appearance", "theme"], themeId)
        console.log("[ThemeService] Config updated, now applying theme");
        if (themeId === "auto") {
            console.log("[ThemeService] Auto theme, regenerating from wallpaper");
            // Force regeneration of colors from wallpaper
            Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--noswitch"]);
        } else {
            console.log("[ThemeService] Manual theme, calling ThemePresets.applyPreset");
            ThemePresets.applyPreset(themeId, applyExternal);
        }
        console.log("[ThemeService] setTheme completed");
    }

    function applyCurrentTheme(applyExternal = defaultApplyExternal) {
        console.log("[ThemeService] applyCurrentTheme called, currentTheme:", currentTheme, "isAutoTheme:", isAutoTheme);
        if (isAutoTheme) {
            console.log("[ThemeService] Delegating to MaterialThemeLoader");
            MaterialThemeLoader.reapplyTheme();
        } else {
            console.log("[ThemeService] Applying manual theme:", currentTheme);
            ThemePresets.applyPreset(currentTheme, applyExternal);
        }
        root.ready = true;
    }
}
