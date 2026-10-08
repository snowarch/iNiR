pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common

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
    function label(text: string): string {
        return String(text ?? "").replace(/__/g, "\u0000").replace(/_/g, "").replace(/\u0000/g, "_")
    }

    QsMenuOpener {
        id: opener
        menu: root.current
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
                action: nested ? () => root.trail = root.trail.concat([entry]) : () => entry.triggered()
            })
        }
        while (rows.length > 0 && rows[rows.length - 1].type === "separator") rows.pop()
        if (rows.length > 0 && rows[0].type === "header" && rows.length > 1 && rows[1].type !== "separator")
            rows.splice(1, 0, { type: "separator" })
        if (root.trail.length === 0 && root.extra.length > 0)
            return (rows.length > 0 ? rows.concat([{ type: "separator" }]) : rows).concat(root.extra)
        return rows
    }

    IrisDesktopMenu {
        id: menu
        anchorItem: root.anchorItem
        opensToward: root.opensToward
        model: root.entries
    }
}
