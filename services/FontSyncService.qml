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
    readonly property string monoFont: Config.options?.appearance?.typography?.monospaceFont ?? "JetBrainsMono Nerd Font"
    readonly property real sizeScale: Config.options?.appearance?.typography?.sizeScale ?? 1.0

    // Calculate font size (base 11pt scaled)
    readonly property int fontSize: Math.round(11 * sizeScale)

    // Full font string for GTK (format: "Font Name Size")
    readonly property string gtkFontString: `${mainFont} ${fontSize}`

    // Enable/disable sync (user preference)
    readonly property bool syncEnabled: Config.options?.appearance?.typography?.syncWithSystem ?? true

    // Debounce timer to avoid rapid updates
    property bool _pendingSync: false
    property bool _rerunAfterExit: false

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
    onMonoFontChanged: _queueSync()
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
        if (fontSyncProc.running) {
            _rerunAfterExit = true
            return
        }
        fontSyncProc.running = true
    }

    // Manual sync function (can be called from settings UI)
    function syncNow(): void {
        _log("[FontSyncService] Manual sync triggered")
        _doSync()
    }

    Process {
        id: fontSyncProc
        running: false
        command: [
            Quickshell.shellPath("scripts/colors/sync-system-fonts.sh"),
            root.mainFont,
            root.monoFont,
            String(root.fontSize)
        ]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root._log("[FontSyncService] GTK/KDE fonts updated:", root.gtkFontString)
            } else {
                console.warn("[FontSyncService] System font sync failed, exit code:", exitCode)
            }
            if (root._rerunAfterExit) {
                root._rerunAfterExit = false
                Qt.callLater(() => root._doSync())
            }
        }
    }

    // Initialize on load
    Component.onCompleted: {
        if (syncEnabled) {
            // Reconcile persisted desktop settings on every shell start. The old
            // implementation only synced after a value changed, leaving GTK/KDE
            // stale after upgrades, manual edits, or restored configs.
            Qt.callLater(() => {
                _log("[FontSyncService] Initialized, current font:", mainFont, "size:", fontSize)
                root._queueSync()
            })
        }
    }
}
