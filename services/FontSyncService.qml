pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

/**
 * FontSyncService - Synchronizes shell fonts with GTK and KDE applications.
 *
 * When the user changes typography settings in iNiR, this service automatically
 * updates the system font settings for GTK (via gsettings) and KDE (via kwriteconfig6).
 */
Singleton {
    id: root

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(...args);
    }

    // Track the current font from config
    readonly property string mainFont: Config.options?.appearance?.typography?.mainFont ?? "Roboto Flex"
    readonly property real sizeScale: Config.options?.appearance?.typography?.sizeScale ?? 1.0

    // Calculate font size (base 11pt scaled)
    readonly property int fontSize: Math.round(11 * sizeScale)

    // Full font string for GTK (format: "Font Name Size")
    readonly property string gtkFontString: `${mainFont} ${fontSize}`

    // Enable/disable sync (user preference)
    readonly property bool syncEnabled: Config.options?.appearance?.typography?.syncWithSystem ?? true

    // Debounce timer to avoid rapid updates
    property bool _pendingSync: false

    Timer {
        id: syncDebounce
        interval: 500
        onTriggered: {
            if (root._pendingSync && root.syncEnabled) {
                root._doSync()
            }
            root._pendingSync = false
        }
    }

    // Watch for font changes
    onMainFontChanged: _queueSync()
    onSizeScaleChanged: _queueSync()
    onSyncEnabledChanged: {
        if (syncEnabled) _queueSync()
    }

    function _queueSync(): void {
        if (!syncEnabled) return
        _pendingSync = true
        syncDebounce.restart()
    }

    function _doSync(): void {
        _log("[FontSyncService] Syncing font:", gtkFontString)

        // Sync to GTK
        gsettingsProc.running = false
        gsettingsProc.running = true

        // Sync to KDE
        kwriteconfigFontProc.running = false
        kwriteconfigFontProc.running = true

        kwriteconfigFixedFontProc.running = false
        kwriteconfigFixedFontProc.running = true
    }

    // Manual sync function (can be called from settings UI)
    function syncNow(): void {
        _log("[FontSyncService] Manual sync triggered")
        _doSync()
    }

    // GTK font sync via gsettings
    Process {
        id: gsettingsProc
        running: false
        command: [
            "/usr/bin/gsettings", "set",
            "org.gnome.desktop.interface", "font-name",
            root.gtkFontString
        ]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                _log("[FontSyncService] GTK font updated:", root.gtkFontString)
            } else {
                console.warn("[FontSyncService] Failed to update GTK font, exit code:", exitCode)
            }
        }
    }

    // KDE font sync via kwriteconfig6 (General font)
    Process {
        id: kwriteconfigFontProc
        running: false
        command: [
            "/usr/bin/kwriteconfig6",
            "--file", "kdeglobals",
            "--group", "General",
            "--key", "font",
            `${root.mainFont},${root.fontSize},-1,5,400,0,0,0,0,0,0,0,0,0,0,1`
        ]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                _log("[FontSyncService] KDE font updated:", root.mainFont)
            } else {
                _log("[FontSyncService] kwriteconfig6 not available or failed (this is normal on non-KDE systems)")
            }
        }
    }

    // KDE fixed font (monospace) sync
    Process {
        id: kwriteconfigFixedFontProc
        running: false
        property string monoFont: Config.options?.appearance?.typography?.monospaceFont ?? "JetBrainsMono Nerd Font"
        command: [
            "/usr/bin/kwriteconfig6",
            "--file", "kdeglobals",
            "--group", "General",
            "--key", "fixed",
            `${monoFont},${root.fontSize},-1,5,400,0,0,0,0,0,0,0,0,0,0,1`
        ]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                _log("[FontSyncService] KDE fixed font updated")
            }
        }
    }

    // Initialize on load
    Component.onCompleted: {
        if (syncEnabled) {
            // Small delay to let config fully load
            Qt.callLater(() => {
                _log("[FontSyncService] Initialized, current font:", mainFont, "size:", fontSize)
            })
        }
    }
}
