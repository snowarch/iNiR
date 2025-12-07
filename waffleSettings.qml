//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_SCALE_FACTOR=1

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
    
    property bool uiReady: Config.ready && ThemeService.ready
    
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
        }
    ]
    
    property int currentPage: 0
    
    visible: true
    onClosing: Qt.quit()
    title: "illogical-impulse Settings"
    
    Component.onCompleted: {
        Config.readWriteDelay = 0
    }
    
    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) ThemeService.applyCurrentTheme()
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
        
        WText {
            anchors.centerIn: parent
            text: Translation.tr("Loading...")
            font.pixelSize: Looks.font.pixelSize.larger
            color: Looks.colors.subfg
        }
    }
    
    // Main content
    WSettingsContent {
        anchors.fill: parent
        visible: root.uiReady
        opacity: visible ? 1 : 0
        
        pages: root.pages
        currentPage: root.currentPage
        onCurrentPageChanged: root.currentPage = currentPage
        onCloseRequested: root.close()
        
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
