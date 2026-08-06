//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env INIR_STANDALONE_WINDOW=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
// Launcher keeps QT_SCALE_FACTOR=1; shell scaling lives in appearance.typography.sizeScale

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.functions as CF
import qs.modules.waffle.looks
import qs.modules.waffle.settings

ApplicationWindow {
    id: root
    
    property bool uiReady: Config.ready
    property string pendingStartSection: ""
    
    property var pages: [
        {
            name: Translation.tr("Quick"),
            icon: "flash-on",
            component: Qt.resolvedUrl("modules/waffle/settings/pages/WQuickPage.qml")
        },
        {
            name: Translation.tr("General"),
            icon: "settings",
            component: Qt.resolvedUrl("modules/waffle/settings/pages/WGeneralPage.qml")
        },
        {
            name: Translation.tr("Taskbar"),
            icon: "desktop",
            component: Qt.resolvedUrl("modules/waffle/settings/pages/WBarPage.qml")
        },
        {
            name: Translation.tr("Background"),
            icon: "image",
            component: Qt.resolvedUrl("modules/waffle/settings/pages/WBackgroundPage.qml")
        },
        {
            name: Translation.tr("Themes"),
            icon: "dark-theme",
            component: Qt.resolvedUrl("modules/waffle/settings/pages/WThemesPage.qml")
        },
        {
            name: Translation.tr("Gowall"),
            icon: "wand",
            component: Qt.resolvedUrl("modules/waffle/settings/pages/WGowallPage.qml")
        },
        {
            name: Translation.tr("Interface"),
            icon: "apps",
            component: Qt.resolvedUrl("modules/waffle/settings/pages/WInterfacePage.qml")
        },
        {
            name: Translation.tr("Modules"),
            icon: "settings-cog-multiple",
            component: Qt.resolvedUrl("modules/waffle/settings/pages/WModulesPage.qml")
        },
        {
            name: Translation.tr("Waffle Style"),
            icon: "desktop",
            component: Qt.resolvedUrl("modules/waffle/settings/pages/WWaffleStylePage.qml")
        },
        {
            name: Translation.tr("Shortcuts"),
            icon: "keyboard",
            component: Qt.resolvedUrl("modules/waffle/settings/pages/WShortcutsPage.qml")
        },
        {
            name: Translation.tr("About"),
            icon: "info",
            component: Qt.resolvedUrl("modules/waffle/settings/pages/WAboutPage.qml")
        },
        {
            name: Translation.tr("Monitors"),
            icon: "desktop",
            component: Qt.resolvedUrl("modules/waffle/settings/pages/WMonitorVisibilityPage.qml")
        },
        {
            name: Translation.tr("Autostart"),
            icon: "power",
            component: Qt.resolvedUrl("modules/waffle/settings/pages/WAutostartPage.qml")
        },
        {
            name: Translation.tr("Workspace Strip"),
            icon: "desktop",
            component: Qt.resolvedUrl("modules/waffle/settings/pages/WWorkspaceStripPage.qml")
        },
        {
            name: Translation.tr("Mascot"),
            icon: "image",
            component: Qt.resolvedUrl("modules/waffle/settings/pages/WMascotPage.qml")
        },
        {
            name: Translation.tr("AI"),
            icon: "wand",
            component: Qt.resolvedUrl("modules/waffle/settings/pages/WAiPage.qml")
        },
        {
            name: Translation.tr("Effects"),
            icon: "eye",
            component: Qt.resolvedUrl("modules/waffle/settings/pages/WEffectsPage.qml")
        },
        {
            name: Translation.tr("Shell Layout"),
            icon: "desktop",
            component: Qt.resolvedUrl("modules/waffle/settings/pages/WShellLayoutPage.qml")
        }
    ]
    
    property int currentPage: 0
    property int _requestedStartPage: -1
    property bool _navigationInitialized: false

    function _persistCurrentPage(): void {
        if (root._navigationInitialized && Persistent.ready && Persistent.states?.settings)
            Persistent.states.settings.wafflePage = Math.max(0, Math.min(root.currentPage, root.pages.length - 1))
    }

    function initializeNavigation(): void {
        if (root._navigationInitialized || !Persistent.ready)
            return
        const persisted = Persistent.states?.settings?.wafflePage ?? 0
        const requested = root._requestedStartPage >= 0 ? root._requestedStartPage : persisted
        root.currentPage = Math.max(0, Math.min(requested, root.pages.length - 1))
        root._navigationInitialized = true
        root._persistCurrentPage()
        root.tryOpenPendingSection()
    }

    onCurrentPageChanged: root._persistCurrentPage()
    
    visible: true
    onClosing: Qt.quit()
    title: "Settings — iNiR"

    function tryOpenPendingSection(): void {
        if (!root.pendingStartSection || !root.uiReady)
            return

        const targetLabel = root.pendingStartSection
        root.pendingStartSection = ""
        Qt.callLater(() => {
            settingsContent.openSearchResult({
                pageIndex: root.currentPage,
                targetLabel: targetLabel
            })
        })
    }
    
    Component.onCompleted: {
        Quickshell.watchFiles = false
        Config.readWriteDelay = 0
        const startPage = parseInt(Quickshell.env("QS_SETTINGS_PAGE"));
        if (!isNaN(startPage)) root._requestedStartPage = startPage;

        const startSection = Quickshell.env("QS_SETTINGS_SECTION");
        if (startSection)
            root.pendingStartSection = startSection;

        root.initializeNavigation()
    }

    Connections {
        target: Persistent
        function onReadyChanged() { root.initializeNavigation() }
    }
    
    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) ThemeService.applyCurrentTheme()
            root.tryOpenPendingSection()
        }
    }
    
    minimumWidth: 700
    minimumHeight: 450
    width: 1000
    height: 650
    color: root.uiReady ? Looks.colors.bg0Opaque : "transparent"
    
    // Loading state
    Item {
        anchors.fill: parent
        visible: !root.uiReady
        
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 16
            
            FluentIcon {
                Layout.alignment: Qt.AlignHCenter
                icon: "settings"
                implicitSize: 32
                color: Looks.colors.accent
                opacity: loadingPulse.running ? 1 : 0.6
                
                SequentialAnimation on opacity {
                    id: loadingPulse
                    running: !root.uiReady
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 800; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 0.9; duration: 800; easing.type: Easing.InOutQuad }
                }
                
                RotationAnimation on rotation {
                    running: !root.uiReady
                    from: 0; to: 360
                    duration: 3000
                    loops: Animation.Infinite
                }
            }
            
            WText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("Loading...")
                font.pixelSize: Looks.font.pixelSize.normal
                color: Looks.colors.subfg
            }
        }
    }
    
    // Main content
    WSettingsContent {
        id: settingsContent
        anchors.fill: parent
        visible: root.uiReady
        opacity: visible ? 1 : 0
        
        pages: root.pages
        currentPage: root.currentPage
        onCurrentPageChanged: {
            if (navigationReady && root.currentPage !== currentPage)
                root.currentPage = currentPage
        }
        onCloseRequested: root.close()
        Component.onCompleted: root.tryOpenPendingSection()
        
        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }
    }
    
    // Keyboard shortcuts
    Shortcut {
        sequence: "Ctrl+PageDown"
        onActivated: root.currentPage = Math.min(root.currentPage + 1, root.pages.length - 1)
    }
    
    Shortcut {
        sequence: "Ctrl+PageUp"
        onActivated: root.currentPage = Math.max(root.currentPage - 1, 0)
    }
    
    Shortcut {
        sequence: "Ctrl+Tab"
        onActivated: root.currentPage = (root.currentPage + 1) % root.pages.length
    }
    
    Shortcut {
        sequence: "Ctrl+Shift+Tab"
        onActivated: root.currentPage = (root.currentPage - 1 + root.pages.length) % root.pages.length
    }
}
