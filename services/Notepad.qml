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

    // Guard: FileView fires onLoaded after our own setText() write (it watches
    // the file). Without this, a self-write reload re-parses a stale/cached
    // buffer and reassigns tabs/currentTab mid-edit, dropping freshly added
    // tabs or their text. Skip the reload that our own save triggers.
    property bool _saving: false

    function _save() {
        _saving = true
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
        printErrors: false

        onLoaded: {
            if (root._saving) { root._saving = false; return }
            try {
                const data = JSON.parse(tabsFileView.text())
                if (Array.isArray(data.tabs) && data.tabs.length > 0) {
                    root.tabs = data.tabs
                    root.currentTab = Math.max(0, Math.min(data.currentTab ?? 0, data.tabs.length - 1))
                    return
                }
            } catch (e) {}
            // Invalid/empty JSON — try legacy migration
            legacyFileView.path = Qt.resolvedUrl(root.legacyFilePath)
        }

        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) {
                // Try migrating from legacy notepad.txt
                legacyFileView.path = Qt.resolvedUrl(root.legacyFilePath)
            } else {
                console.log("[Notepad] Error loading tabs file:", error)
            }
        }
    }

    // Legacy notepad.txt migration. No declarative `path`: if set eagerly the
    // FileView auto-loads on startup, races the tabs JSON load, and its onLoaded
    // unconditionally resets tabs to a single legacy note and saves — wiping every
    // extra tab on every restart. Only load it on demand when the tabs file is
    // genuinely missing/invalid (path assigned above).
    FileView {
        id: legacyFileView
        printErrors: false

        onLoaded: {
            const content = legacyFileView.text()
            root.tabs = [{ title: "Note 1", text: content || "" }]
            root.currentTab = 0
            root._save()
        }

        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound)
                console.log("[Notepad] Error loading legacy notepad:", error)
            // No legacy file either — fresh start
            const parentDir = root.tabsFilePath.substring(0, root.tabsFilePath.lastIndexOf('/'))
            Quickshell.execDetached(["/usr/bin/mkdir", "-p", parentDir])
            root.tabs = [{ title: "Note 1", text: "" }]
            root.currentTab = 0
            root._save()
        }
    }
}
