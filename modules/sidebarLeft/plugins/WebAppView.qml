pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
// DISABLED: webapps — requires quickshell-webengine rebuild
// import QtWebEngine
import Qt5Compat.GraphicalEffects as GE
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    // Plugin manifest data — set ONCE at creation time via createObject
    required property string pluginId
    required property string pluginUrl
    property string pluginName: ""
    property string pluginIcon: "language"

    // Userscript JS source code — pre-read by scan-plugins.py
    // Injected via runJavaScript after each successful page load.
    property var userscriptSources: []

    // External profile — created by SidebarLeftContent with storageName
    // already set, avoiding the off-the-record → disk-based transition
    required property WebEngineProfile webProfile

    // Lifecycle: kept for future per-plugin hibernate option
    property bool frozen: false

    // Navigation state
    readonly property bool canGoBack: webView.canGoBack
    readonly property bool canGoForward: webView.canGoForward
    readonly property bool isLoading: webView.loading
    readonly property string currentTitle: webView.title ?? ""
    readonly property real loadProgress: webView.loadProgress / 100.0

    signal closeRequested()

    // Style tokens
    readonly property color colText: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText
        : Appearance.colors.colOnLayer1
    readonly property color colTextSecondary: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
        : Appearance.colors.colSubtext
    readonly property color colBg: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? "transparent"
        : Appearance.colors.colLayer1
    readonly property color colBgHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colLayer1Hover
    readonly property color colBorder: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
        : Appearance.inirEverywhere ? Appearance.inir.colBorder
        : Appearance.colors.colLayer0Border
    readonly property real rounding: Appearance.rounding.verysmall

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Navigation bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: root.colBg
            border.width: Appearance.inirEverywhere || Appearance.angelEverywhere ? 1 : 0
            border.color: root.colBorder
            radius: root.rounding

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                spacing: 2

                // Close / back to list
                RippleButton {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    buttonRadius: root.rounding
                    colBackground: "transparent"
                    colBackgroundHover: root.colBgHover
                    onClicked: root.closeRequested()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "arrow_back"
                        iconSize: 16
                        color: root.colText
                    }
                }

                // Back
                RippleButton {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    buttonRadius: root.rounding
                    colBackground: "transparent"
                    colBackgroundHover: root.colBgHover
                    enabled: root.canGoBack
                    opacity: enabled ? 1 : 0.35
                    onClicked: webView.goBack()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "chevron_left"
                        iconSize: 18
                        color: root.colText
                    }
                }

                // Title
                StyledText {
                    Layout.fillWidth: true
                    text: root.currentTitle || root.pluginName
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.colTextSecondary
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }

                // Reload
                RippleButton {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    buttonRadius: root.rounding
                    colBackground: "transparent"
                    colBackgroundHover: root.colBgHover
                    onClicked: root.isLoading ? webView.stop() : webView.reload()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: root.isLoading ? "close" : "refresh"
                        iconSize: 16
                        color: root.colText
                    }
                }

                // Forward
                RippleButton {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    buttonRadius: root.rounding
                    colBackground: "transparent"
                    colBackgroundHover: root.colBgHover
                    enabled: root.canGoForward
                    opacity: enabled ? 1 : 0.35
                    onClicked: webView.goForward()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "chevron_right"
                        iconSize: 18
                        color: root.colText
                    }
                }
            }

            // Loading progress bar
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                width: parent.width * root.loadProgress
                height: 2
                color: Appearance.colors.colPrimary
                visible: root.isLoading
                radius: 1
                Behavior on width {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
            }
        }

        // WebEngine container — clipped with rounded corners via OpacityMask
        Item {
            id: webViewClip
            Layout.fillWidth: true
            Layout.fillHeight: true

            WebEngineView {
                id: webView
                anchors.fill: parent

                // URL is NOT bound here — set by deferredLoadTimer below.
                // This gives the profile time to fully initialize its disk
                // backend (cookies, localStorage) before navigation starts.
                // Without this delay, the profile may still be off-the-record
                // when the page loads, so auth tokens aren't found.

                // Always active — WebApps run in background for audio/WebSocket
                lifecycleState: WebEngineView.LifecycleState.Active

                // Profile created externally with storageName pre-set
                profile: root.webProfile

                // Allow autoplay — webapps like Discord need audio for
                // notifications/calls without requiring a click first.
                settings.playbackRequiresUserGesture: false

                onLoadingChanged: function(loadRequest) {
                    if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
                        root._injectUserscripts()
                    }
                }

                onContextMenuRequested: function(request) {
                    request.accepted = true
                }

                // Auto-grant all permission requests (storage access, notifications, etc.)
                // This is a private shell, not a public browser — no reason to block.
                onPermissionRequested: function(request) {
                    request.grant()
                }

                // Handle new window requests (e.g., target="_blank") — open in same view
                onNewWindowRequested: function(request) {
                    webView.url = request.requestedUrl
                }

                // Suppress noisy WebEngine JS warnings (font preload, CORS, etc.)
                // that pollute quickshell logs. Errors still pass through.
                onJavaScriptConsoleMessage: function(level, message, lineNumber, sourceID) {
                    if (level === WebEngineView.ErrorMessageLevel)
                        console.error("[WebApp:" + root.pluginId + "]", message)
                }
            }

            // Deferred URL load — waits for profile disk backend to initialize.
            // The WebEngineProfile starts off-the-record (storageName set via
            // QML binding evaluates AFTER C++ constructor). The "Switching to
            // disk-based behavior" transition takes time — localStorage is
            // unavailable until then. 800ms gives the profile enough time.
            Timer {
                id: deferredLoadTimer
                interval: 800
                running: true
                onTriggered: webView.url = root.pluginUrl
            }

            // Rounded corner mask — clips the WebEngineView's foreign texture
            layer.enabled: true
            layer.effect: GE.OpacityMask {
                maskSource: Rectangle {
                    width: webViewClip.width
                    height: webViewClip.height
                    radius: root.rounding
                }
            }
        }
    }

    // ─── Userscript injection ───────────────────────────────────────
    // Uses WebEngine.script() factory to create WebEngineScript values
    // at DocumentCreation/MainWorld. This gives full access to
    // localStorage, document.cookie, etc.
    //
    // Quickshell's runJavaScript() runs in an isolated world where
    // localStorage is undefined. The only way to get MainWorld access
    // is via UserScripts (Chromium's content script system).

    property bool _userscriptsInstalled: false

    function _installUserscripts(): void {
        if (root._userscriptsInstalled) return
        const sources = root.userscriptSources ?? []
        if (sources.length === 0) return

        root._userscriptsInstalled = true

        for (let i = 0; i < sources.length; i++) {
            const code = sources[i]
            if (!code || code.length === 0) continue

            // WebEngine singleton has the factory: WebEngine.script()
            let script = WebEngine.script()
            script.name = root.pluginId + "_us_" + i
            script.sourceCode = code
            script.injectionPoint = 1  // DocumentReady (DOMContentLoaded)
            script.worldId = 0         // MainWorld
            script.runOnSubframes = false
            webView.userScripts.insert(script)
        }
    }

    function _injectUserscripts(): void {
        root._installUserscripts()
    }

    // Install userscripts at creation time — BEFORE the deferred URL
    // load timer fires, so they're active for the first page load.
    Component.onCompleted: root._installUserscripts()

    // Loading overlay
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 36
        color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
             : Appearance.inirEverywhere ? Appearance.inir.colLayer0
             : Appearance.colors.colLayer0
        visible: root.loadProgress < 0.1 && root.isLoading
        opacity: visible ? 1 : 0
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: 200 }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 12

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: root.pluginIcon
                iconSize: 48
                color: root.colTextSecondary
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: root.pluginName || Translation.tr("Loading...")
                font.pixelSize: Appearance.font.pixelSize.normal
                color: root.colText
            }
        }
    }
}
