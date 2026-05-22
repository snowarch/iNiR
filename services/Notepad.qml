pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import Quickshell
import Quickshell.Io
import QtQuick

/**
 * Multi-tab persistent notepad.
 * Stores tabs as JSON in notepad-tabs.json, migrates legacy notepad.txt.
 * Backward compat: `text` property reflects current tab content.
 */
Singleton {
    id: root

    readonly property string tabsFilePath: `${Directories.stateUserPath}/notepad-tabs.json`
    readonly property string legacyFilePath: Directories.notepadPath

    // Current tab state
    property int currentTab: 0
    property var tabs: [{ title: "Note 1", text: "" }]
    // Convenience: current tab text (backward compat)
    readonly property string text: (tabs[currentTab]?.text) ?? ""

    function setTextValue(newText) {
        if (currentTab < 0 || currentTab >= tabs.length) return
        const t = tabs.slice()
        t[currentTab] = Object.assign({}, t[currentTab], { text: newText })
        tabs = t
        _save()
    }

    function setTabTitle(index, title) {
        if (index < 0 || index >= tabs.length) return
        const t = tabs.slice()
        t[index] = Object.assign({}, t[index], { title: title })
        tabs = t
        _save()
    }

    function addTab(title) {
        const t = tabs.slice()
        const name = title || `Note ${t.length + 1}`
        t.push({ title: name, text: "" })
        tabs = t
        currentTab = t.length - 1
        _save()
    }

    function removeTab(index) {
        if (tabs.length <= 1) return // Keep at least one tab
        const t = tabs.slice()
        t.splice(index, 1)
        tabs = t
        if (currentTab >= t.length) currentTab = t.length - 1
        _save()
    }

    function switchTab(index) {
        if (index < 0 || index >= tabs.length) return
        currentTab = index
        _save()
    }

    function _save() {
        tabsFileView.setText(JSON.stringify({ currentTab: currentTab, tabs: tabs }))
    }

    function refresh() {
        tabsFileView.reload()
    }

    Component.onCompleted: refresh()

    // Tabs JSON storage
    FileView {
        id: tabsFileView
        path: Qt.resolvedUrl(root.tabsFilePath)

        onLoaded: {
            try {
                const data = JSON.parse(tabsFileView.text())
                if (Array.isArray(data.tabs) && data.tabs.length > 0) {
                    root.tabs = data.tabs
                    root.currentTab = Math.max(0, Math.min(data.currentTab ?? 0, data.tabs.length - 1))
                    return
                }
            } catch (e) {}
            // Invalid/empty JSON — try legacy migration
            legacyFileView.reload()
        }

        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) {
                // Try migrating from legacy notepad.txt
                legacyFileView.reload()
            } else {
                console.log("[Notepad] Error loading tabs file:", error)
            }
        }
    }

    // Legacy notepad.txt migration
    FileView {
        id: legacyFileView
        path: Qt.resolvedUrl(root.legacyFilePath)

        onLoaded: {
            const content = legacyFileView.text()
            root.tabs = [{ title: "Note 1", text: content || "" }]
            root.currentTab = 0
            root._save()
        }

        onLoadFailed: {
            // No legacy file either — fresh start
            const parentDir = root.tabsFilePath.substring(0, root.tabsFilePath.lastIndexOf('/'))
            Quickshell.execDetached(["/usr/bin/mkdir", "-p", parentDir])
            root.tabs = [{ title: "Note 1", text: "" }]
            root.currentTab = 0
            root._save()
        }
    }
}
