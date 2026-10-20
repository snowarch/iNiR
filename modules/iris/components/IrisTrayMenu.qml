pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common
import qs.services

Item {
    id: root

    property var handle: null
    property Item anchorItem: parent
    property var trail: []
    property var extra: []
    property string title: ""
    property string icon: ""
    property string opensToward: ""
    readonly property var current: root.trail.length > 0 ? root.trail[root.trail.length - 1] : root.handle
    readonly property bool opened: menu.active
    width: 0
    height: 0

    function open(): void {
        if (!root.handle) return
        root.trail = []
        menu.requestOpen()
    }
    function close(): void { menu.close() }
    // An entry the app already took back (a new layout, or the app went away): its wrapper outlives it.
    function alive(entry): bool { return !!entry && typeof entry.triggered === "function" }
    function label(text: string): string {
        return String(text ?? "").replace(/__/g, "\u0000").replace(/_/g, "").replace(/\u0000/g, "_")
    }

    QsMenuOpener {
        id: opener
        menu: root.current
    }
    // Holds the whole menu while a submenu shows: with only the submenu referenced, the runtime let the root
    // go, and with it every entry under it, the submenu included (it opened empty, titled "Back").
    QsMenuOpener {
        menu: root.handle
    }

    readonly property var entries: {
        const rows = []
        if (root.trail.length === 0 && root.title.length > 0)
            rows.push({ type: "header", text: root.title, image: root.icon })
        if (root.trail.length > 0) {
            rows.push({ text: root.label(root.trail[root.trail.length - 1]?.text ?? "") || Translation.tr("Back"),
                iconName: "chevron_left", keepOpen: true, action: () => root.trail = root.trail.slice(0, -1) })
            rows.push({ type: "separator" })
        }
        for (const entry of opener.children?.values ?? []) {
            if (!entry) continue
            if (entry.isSeparator) {
                if (rows.length > 0 && rows[rows.length - 1].type !== "separator") rows.push({ type: "separator" })
                continue
            }
            const toggles = entry.buttonType !== QsMenuButtonType.None
            const nested = entry.hasChildren
            rows.push({
                text: root.label(entry.text),
                image: String(entry.icon ?? ""),
                enabled: entry.enabled,
                checked: toggles ? entry.checkState === Qt.Checked : undefined,
                submenu: nested,
                keepOpen: nested,
                dbusEntry: entry,
                action: nested ? () => root.trail = root.trail.concat([entry])
                    : () => { if (root.alive(entry)) entry.triggered() }
            })
        }
        while (rows.length > 0 && rows[rows.length - 1].type === "separator") rows.pop()
        if (rows.length > 0 && rows[0].type === "header" && rows.length > 1 && rows[1].type !== "separator")
            rows.splice(1, 0, { type: "separator" })
        if (root.trail.length === 0 && root.extra.length > 0)
            return (rows.length > 0 ? rows.concat([{ type: "separator" }]) : rows).concat(root.extra)
        return rows
    }

    // The open menu keeps the rows it opened with, so a layout the app replaces under it would leave rows of entries
    // that no longer exist. Once the new layout lands, rows that are not in it reopen the menu on the new one.
    readonly property var liveEntries: opener.children?.values ?? []
    onLiveEntriesChanged: if (root.opened) staleCheck.restart()
    Timer {
        id: staleCheck
        // After a submenu step has swapped the rows (it does so on the next tick) and the old entries are gone.
        interval: 50
        onTriggered: {
            if (root.trail.some(entry => !root.alive(entry))) root.trail = []
            if (!root.opened) return
            const live = root.liveEntries
            if ((menu.shown ?? []).some(row => row?.dbusEntry && !live.includes(row.dbusEntry))) menu.requestOpen()
        }
    }

    IrisDesktopMenu {
        id: menu
        anchorItem: root.anchorItem
        opensToward: root.opensToward
        model: root.entries
    }
}
