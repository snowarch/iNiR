pragma Singleton

import QtQuick
import Quickshell
import qs.modules.common
import qs.services

Singleton {
    id: root

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(...args);
    }

    property bool ready: false
    readonly property string currentTheme: Config.options?.appearance?.theme ?? "auto"
    readonly property bool isAutoTheme: currentTheme === "auto"
    readonly property bool isStandaloneSettingsWindow: (Quickshell.env("QS_NO_RELOAD_POPUP") ?? "") === "1"
    readonly property bool defaultApplyExternal: !isStandaloneSettingsWindow
    readonly property bool vesktopEnabled: (Config.options?.appearance?.wallpaperTheming?.enableVesktop ?? true) !== false

    onCurrentThemeChanged: {
        if (Config.ready) {
            root._log("[ThemeService] currentTheme changed to:", currentTheme, "- applying");
            Qt.callLater(() => applyCurrentTheme(defaultApplyExternal));
        }
    }

    function setTheme(themeId, applyExternal = true) {
        root._log("[ThemeService] setTheme called with:", themeId);
        Config.setNestedValue(["appearance", "theme"], themeId)
        root._log("[ThemeService] Config updated, now applying theme");
        if (themeId === "auto") {
            root._log("[ThemeService] Auto theme, regenerating from wallpaper");
            // Force regeneration of colors from wallpaper
            Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--noswitch"]);
        } else {
            root._log("[ThemeService] Manual theme, calling ThemePresets.applyPreset");
            ThemePresets.applyPreset(themeId, applyExternal);
        }
        root._log("[ThemeService] setTheme completed");
    }

    function applyCurrentTheme(applyExternal = defaultApplyExternal) {
        root._log("[ThemeService] applyCurrentTheme called, currentTheme:", currentTheme, "isAutoTheme:", isAutoTheme);
        if (isAutoTheme) {
            root._log("[ThemeService] Delegating to MaterialThemeLoader");
            MaterialThemeLoader.reapplyTheme();

            if (applyExternal && vesktopEnabled) {
                Qt.callLater(() => {
                    Quickshell.execDetached([
                        "/usr/bin/python3",
                        Directories.scriptPath + "/colors/system24_palette.py"
                    ]);
                });
            }
        } else {
            root._log("[ThemeService] Applying manual theme:", currentTheme);
            ThemePresets.applyPreset(currentTheme, applyExternal);
        }
        root.ready = true;
    }
}
