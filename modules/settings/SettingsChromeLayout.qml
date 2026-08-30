pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common

QtObject {
    id: root

    readonly property var defaultHeaderOrder: ["identity", "search", "actions"]
    readonly property var headerOrder: root._readHeaderOrder()

    function _readHeaderOrder(): var {
        const raw = Config.options?.settingsUi?.chromeLayout ?? ""
        if (!raw || raw.length === 0)
            return root.defaultHeaderOrder.slice()

        let saved
        try {
            saved = JSON.parse(raw)
        } catch (e) {
            return root.defaultHeaderOrder.slice()
        }

        const incoming = Array.isArray(saved)
            ? saved
            : (Array.isArray(saved?.header) ? saved.header : [])
        const allowed = root.defaultHeaderOrder
        const seen = new Set()
        const order = []
        for (const id of incoming) {
            if (!allowed.includes(id) || seen.has(id))
                continue
            seen.add(id)
            order.push(id)
        }
        for (const id of allowed) {
            if (!seen.has(id))
                order.push(id)
        }
        return order
    }

    function columnFor(id: string): int {
        const index = root.headerOrder.indexOf(id)
        return index >= 0 ? index : root.defaultHeaderOrder.indexOf(id)
    }

    function moveHeaderBlock(id: string, targetIndex: int): bool {
        const order = root.headerOrder.slice()
        const from = order.indexOf(id)
        if (from < 0)
            return false
        order.splice(from, 1)
        order.splice(Math.max(0, Math.min(targetIndex, order.length)), 0, id)
        Config.setNestedValue("settingsUi.chromeLayout",
            JSON.stringify({ version: 1, header: order }))
        return true
    }

    function reset(): void {
        Config.setNestedValue("settingsUi.chromeLayout", "")
    }
}
