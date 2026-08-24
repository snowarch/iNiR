pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    readonly property int schemaVersion: 1
    readonly property string filePath: `${Directories.stateUserPath}/desktop-items.json`
    readonly property int itemWidth: 92
    readonly property int itemHeight: 94
    readonly property int itemIconSize: 42

    property bool ready: false
    property bool available: false
    property var items: ({})
    property list<string> invalidItemIds: []
    property string lastError: ""
    readonly property int itemCount: Object.keys(root.items).length
    readonly property bool canUndo: root._tombstone !== null

    property var _tombstone: null
    property var _invalidRecords: ({})
    property var _documentExtras: ({})
    property bool _writeInFlight: false
    property bool _pendingWrite: false
    property bool _pendingReload: false
    property bool _stateDirPending: false

    signal itemCreated(string itemId, var item)
    signal itemUpdated(string itemId, var item)
    signal itemRemoved(string itemId)
    signal itemRestored(string itemId, var item)

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1")
            console.log("[DesktopItems]", ...args)
    }

    function _error(message: string): void {
        root.lastError = message
        console.warn("[DesktopItems]", message)
    }

    function _writable(): bool {
        if (root.ready && root.available)
            return true
        root._error("Cannot modify desktop items while the state is unavailable")
        return false
    }

    function _newId(): string {
        let candidate = ""
        do {
            candidate = `${Date.now().toString(36)}-${(++_idCounter).toString(36)}-${Math.random().toString(36).slice(2, 10)}`
        } while (root.items[candidate] !== undefined)
        return candidate
    }

    function _isObject(value: var): bool {
        return value !== null && typeof value === "object" && !Array.isArray(value)
    }

    function _normalize(raw: var, itemId: string): var {
        if (!root._isObject(raw))
            return null

        const kind = String(raw.kind ?? "").trim()
        if (!["application", "file", "folder", "url"].includes(kind))
            return null

        const target = String(raw.target ?? "").trim()
        if (target.length === 0)
            return null

        const record = Object.assign({}, raw)
        record.kind = kind
        record.target = target
        record.label = typeof raw.label === "string" && raw.label.length > 0
            ? raw.label
            : target
        record.customLabel = raw.customLabel === true
        record.icon = typeof raw.icon === "string" ? raw.icon : ""
        record.output = typeof raw.output === "string" ? raw.output : ""
        record.x = typeof raw.x === "number" && isFinite(raw.x) ? raw.x : 0
        record.y = typeof raw.y === "number" && isFinite(raw.y) ? raw.y : 0
        record.locked = raw.locked === true
        record.layer = typeof raw.layer === "number" && isFinite(raw.layer)
            ? Math.trunc(raw.layer)
            : 0
        record.trusted = raw.trusted !== false
        return record
    }

    function _loadDocument(text: string): void {
        let parsed
        try {
            parsed = JSON.parse(text)
        } catch (error) {
            root.available = false
            root._error(`Invalid JSON: ${error}`)
            return
        }

        if (!root._isObject(parsed) || parsed.version !== root.schemaVersion || !root._isObject(parsed.items)) {
            root.available = false
            root._error(`Unsupported desktop-items schema (expected version ${root.schemaVersion})`)
            return
        }

        const validItems = ({})
        const invalidItems = ({})
        const invalidIds = []
        for (const itemId of Object.keys(parsed.items)) {
            const normalized = root._normalize(parsed.items[itemId], itemId)
            if (normalized === null) {
                invalidItems[itemId] = parsed.items[itemId]
                invalidIds.push(itemId)
            } else {
                validItems[itemId] = normalized
            }
        }

        const extras = Object.assign({}, parsed)
        delete extras.version
        delete extras.items

        root.items = validItems
        root._invalidRecords = invalidItems
        root.invalidItemIds = invalidIds
        root._documentExtras = extras
        root.available = true
        root.lastError = invalidIds.length > 0
            ? `Skipped ${invalidIds.length} invalid desktop item record(s)`
            : ""
        root._log("Loaded", root.itemCount, "items; skipped", invalidIds.length)
    }

    function _serializedDocument(): string {
        const records = Object.assign({}, root._invalidRecords, root.items)
        const document = Object.assign({}, root._documentExtras, {
            version: root.schemaVersion,
            items: records
        })
        return JSON.stringify(document, null, 2)
    }

    function _queuePersist(): void {
        if (!root.ready || !root.available)
            return

        root._pendingWrite = true
        writeTimer.restart()
    }

    function _finishWrite(): void {
        root._writeInFlight = false
        if (root._pendingWrite) {
            writeTimer.restart()
            return
        }
        if (root._pendingReload) {
            root._pendingReload = false
            reloadTimer.restart()
        }
    }

    function _commit(nextItems: var): void {
        root.items = nextItems
        root._queuePersist()
    }

    function create(input: var): string {
        if (!root.ready || !root.available) {
            root._error("Cannot create an item before the state is ready")
            return ""
        }

        const itemId = root._newId()
        const normalized = root._normalize(input, itemId)
        if (normalized === null) {
            root._error("Rejected invalid desktop item")
            return ""
        }

        const nextItems = Object.assign({}, root.items)
        nextItems[itemId] = normalized
        root._commit(nextItems)
        root.itemCreated(itemId, Object.assign({}, normalized))
        return itemId
    }

    function createMany(inputs: var): list<string> {
        if (!root.ready || !root.available) {
            root._error("Cannot create items before the state is ready")
            return []
        }
        if (!Array.isArray(inputs))
            return []

        const nextItems = Object.assign({}, root.items)
        const created = []
        const createdRecords = []
        for (const input of inputs) {
            const itemId = root._newId()
            const normalized = root._normalize(input, itemId)
            if (normalized === null)
                continue
            nextItems[itemId] = normalized
            created.push(itemId)
            createdRecords.push({ id: itemId, item: normalized })
        }
        if (created.length > 0) {
            root._commit(nextItems)
            for (const record of createdRecords)
                root.itemCreated(record.id, Object.assign({}, record.item))
        }
        return created
    }

    function get(itemId: string): var {
        return root.items[itemId] === undefined ? null : Object.assign({}, root.items[itemId])
    }

    function listItems(): list<var> {
        return Object.keys(root.items).map(itemId => Object.assign({ id: itemId }, root.items[itemId]))
    }

    function listForOutput(output: string): list<var> {
        return root.listItems().filter(item => item.output === output)
    }

    function gridPitchX(gridSize: int): int {
        const unit = Math.max(1, Math.round(Number(gridSize) || 1))
        return Math.ceil(root.itemWidth / unit) * unit
    }

    function gridPitchY(gridSize: int): int {
        const unit = Math.max(1, Math.round(Number(gridSize) || 1))
        return Math.ceil(root.itemHeight / unit) * unit
    }

    function arrangePosition(output: string, desiredX: real, desiredY: real,
            workWidth: real, workHeight: real, gridSize: int,
            snapEnabled: bool, excludeItemId = ""): var {
        const maxX = Math.max(0, Math.round(Number(workWidth) || 0) - root.itemWidth)
        const maxY = Math.max(0, Math.round(Number(workHeight) || 0) - root.itemHeight)
        const clampedX = Math.max(0, Math.min(maxX, Math.round(Number(desiredX) || 0)))
        const clampedY = Math.max(0, Math.min(maxY, Math.round(Number(desiredY) || 0)))
        if (!snapEnabled)
            return { x: clampedX, y: clampedY }

        const pitchX = root.gridPitchX(gridSize)
        const pitchY = root.gridPitchY(gridSize)
        const anchorX = Math.max(0, Math.min(maxX,
            Math.round(clampedX / pitchX) * pitchX))
        const anchorY = Math.max(0, Math.min(maxY,
            Math.round(clampedY / pitchY) * pitchY))
        const occupied = root.listForOutput(String(output ?? ""))
            .filter(item => String(item.id ?? "") !== String(excludeItemId ?? ""))

        function isFree(x, y): bool {
            for (const item of occupied) {
                const itemX = Number(item.x ?? 0)
                const itemY = Number(item.y ?? 0)
                if (x < itemX + root.itemWidth
                        && x + root.itemWidth > itemX
                        && y < itemY + root.itemHeight
                        && y + root.itemHeight > itemY)
                    return false
            }
            return true
        }

        const candidates = []
        for (let y = 0; y <= maxY; y += pitchY) {
            for (let x = 0; x <= maxX; x += pitchX) {
                const dx = x - anchorX
                const dy = y - anchorY
                candidates.push({ x: x, y: y, distance: dx * dx + dy * dy })
            }
        }
        candidates.sort((a, b) => a.distance - b.distance
            || a.y - b.y || a.x - b.x)
        for (const candidate of candidates) {
            if (isFree(candidate.x, candidate.y))
                return { x: candidate.x, y: candidate.y }
        }
        return { x: anchorX, y: anchorY }
    }

    function update(itemId: string, patch: var): bool {
        if (!root._writable())
            return false
        const current = root.items[itemId]
        if (current === undefined || !root._isObject(patch))
            return false

        const normalized = root._normalize(Object.assign({}, current, patch), itemId)
        if (normalized === null) {
            root._error(`Rejected invalid update for desktop item ${itemId}`)
            return false
        }

        const nextItems = Object.assign({}, root.items)
        nextItems[itemId] = normalized
        root._commit(nextItems)
        root.itemUpdated(itemId, Object.assign({}, normalized))
        return true
    }

    function duplicate(itemId: string, overrides = ({})): string {
        const current = root.items[itemId]
        if (current === undefined)
            return ""
        return root.create(Object.assign({}, current, overrides))
    }

    function repair(itemId: string, target: string, kind = ""): bool {
        const current = root.items[itemId]
        if (current === undefined || String(target ?? "").trim().length === 0)
            return false
        const patch = { target: String(target).trim() }
        if (kind.length > 0)
            patch.kind = kind
        return root.update(itemId, patch)
    }

    function remove(itemId: string): bool {
        if (!root._writable())
            return false
        const current = root.items[itemId]
        if (current === undefined)
            return false

        root._tombstone = { id: itemId, item: Object.assign({}, current) }
        const nextItems = Object.assign({}, root.items)
        delete nextItems[itemId]
        root._commit(nextItems)
        root.itemRemoved(itemId)
        return true
    }

    function undoRemove(): bool {
        if (root._tombstone === null)
            return false
        if (!root._writable())
            return false

        const tombstone = root._tombstone
        if (root.items[tombstone.id] !== undefined)
            return false

        const nextItems = Object.assign({}, root.items)
        nextItems[tombstone.id] = Object.assign({}, tombstone.item)
        root._tombstone = null
        root._commit(nextItems)
        root.itemRestored(tombstone.id, Object.assign({}, tombstone.item))
        return true
    }

    function diagnostics(): string {
        return JSON.stringify({
            version: root.schemaVersion,
            filePath: root.filePath,
            ready: root.ready,
            available: root.available,
            itemCount: root.itemCount,
            invalidItemIds: root.invalidItemIds,
            canUndo: root.canUndo,
            pendingWrite: root._pendingWrite || root._writeInFlight,
            lastError: root.lastError
        })
    }

    function _requestReload(): void {
        if (root._writeInFlight) {
            root._pendingReload = true
            return
        }
        reloadTimer.restart()
    }

    Timer {
        id: writeTimer
        interval: 80
        repeat: false
        onTriggered: {
            if (root._writeInFlight)
                return
            root._pendingWrite = false
            root._writeInFlight = true
            stateFileView.setText(root._serializedDocument())
        }
    }

    Timer {
        id: reloadTimer
        interval: 100
        repeat: false
        onTriggered: stateFileView.reload()
    }

    FileView {
        id: stateFileView
        path: Qt.resolvedUrl(root.filePath)
        watchChanges: true
        atomicWrites: true

        onLoaded: {
            if (root._writeInFlight) {
                root._pendingReload = true
                return
            }
            root._loadDocument(stateFileView.text())
            root.ready = true
        }

        onFileChanged: root._requestReload()

        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root.ready = false
                root.available = false
                if (!root._stateDirPending) {
                    root._stateDirPending = true
                    ensureStateDir.running = true
                }
            } else {
                root.available = false
                root._error(`Failed to load desktop items: ${error}`)
            }
        }

        onSaved: root._finishWrite()
        onSaveFailed: error => {
            root.available = false
            root._pendingWrite = false
            root._error(`Failed to save desktop items: ${error}`)
            root._finishWrite()
        }
    }

    Process {
        id: ensureStateDir
        running: false
        command: [
            "/usr/bin/mkdir", "-p",
            root.filePath.substring(0, root.filePath.lastIndexOf('/'))
        ]
        onExited: (exitCode, exitStatus) => {
            root._stateDirPending = false
            if (exitCode !== 0) {
                root.ready = true
                root.available = false
                root._error(`Failed to prepare desktop-item state directory (${exitCode})`)
                return
            }
            root.items = ({})
            root._invalidRecords = ({})
            root._documentExtras = ({})
            root.invalidItemIds = []
            root.available = true
            root.lastError = ""
            root.ready = true
            root._queuePersist()
        }
    }

    property int _idCounter: 0

    Component.onCompleted: {
        if (stateFileView.loaded)
            root.ready = true
    }
}
