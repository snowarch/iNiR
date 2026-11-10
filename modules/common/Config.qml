pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import "functions/ConfigMigrations.js" as ConfigMigrations

Singleton {
    id: root
    property string filePath: Directories.shellConfigPath
    property alias options: configOptionsJsonAdapter
    property bool ready: false
    property int revision: 0
    property bool isSettingsProcess: (Quickshell.env("INIR_STANDALONE_WINDOW") ?? "") === "1"
    property int readWriteDelay: 50 // milliseconds
    property bool blockWrites: false
    // Custom widget data stored outside JsonAdapter to avoid VME crash on property var
    property var customWidgetData: ({})
    property bool customWidgetDataSynced: false
    // Extra mascot desktop-widget instances (dynamic id keys), same VME-crash
    // workaround as customWidgetData above — kept as an independent parallel
    // bucket rather than folded into customWidgetData's control flow, so the
    // proven custom-widget path stays untouched.
    property var mascotInstances: ({})
    property bool mascotInstancesSynced: false

    signal configChanged

    function _bumpRevision(): void {
        root.revision = (root.revision + 1) % 2147483647;
    }

    function flushWrites(): void {
        fileWriteTimer.stop();
        fileReloadTimer.stop();
        root._prepareCustomInject();
        root._writeInFlight = true;
        // These mutations are being committed right now. Leaving them in the
        // pending journal makes a later external config change replay an old
        // already-saved value (e.g. App Filters toggling itself back on).
        root._pendingMutations = ({});
        root._writeRetries = 0;
        root._writeMirrorToDisk();
        writeFlightGuard.restart();
    }

    function _applyNestedKey(nestedKey, value, quiet) {
        let keys = [];
        if (Array.isArray(nestedKey)) {
            keys = nestedKey;
        } else if (typeof nestedKey === "string") {
            keys = nestedKey.split(".");
        } else {
            console.warn("[Config] setNestedValue called with invalid nestedKey:", nestedKey);
            return;
        }

        if (keys.length === 0) {
            console.warn("[Config] setNestedValue called with empty key");
            return;
        }

        let convertedValue = value;
        if (typeof value === "string") {
            let trimmed = value.trim();
            if (trimmed === "true" || trimmed === "false" || !isNaN(Number(trimmed))) {
                try {
                    convertedValue = JSON.parse(trimmed);
                } catch (e) {
                    convertedValue = value;
                }
            }
        }

        // Route custom widget paths to standalone property (outside adapter)
        if (keys.length >= 3 && keys[0] === "background" && keys[1] === "widgets" && keys[2] === "custom") {
            const subKeys = keys.slice(3);
            if (subKeys.length === 0) {
                root.customWidgetData = (typeof convertedValue === "object" && convertedValue !== null) ? convertedValue : {};
                root._customSnapshotForInject = root._cloneObject(root.customWidgetData);
                root._pendingCustomInject = root._hasObjectKeys(root._customSnapshotForInject);
                return;
            }
            let data = {};
            try {
                data = JSON.parse(JSON.stringify(root.customWidgetData ?? {}));
            } catch (e) {
                data = {};
            }
            let obj = data;
            for (let i = 0; i < subKeys.length - 1; ++i) {
                if (!obj[subKeys[i]] || typeof obj[subKeys[i]] !== "object")
                    obj[subKeys[i]] = {};
                obj = obj[subKeys[i]];
            }
            obj[subKeys[subKeys.length - 1]] = convertedValue;
            root.customWidgetData = data;
            root._customSnapshotForInject = root._cloneObject(data);
            root._pendingCustomInject = root._hasObjectKeys(root._customSnapshotForInject);
            return;
        }

        // Route extra mascot widget instances the same way as custom widgets
        if (keys.length >= 3 && keys[0] === "background" && keys[1] === "widgets" && keys[2] === "mascotInstances") {
            const subKeys = keys.slice(3);
            if (subKeys.length === 0) {
                root.mascotInstances = (typeof convertedValue === "object" && convertedValue !== null) ? convertedValue : {};
                root._mascotSnapshotForInject = root._cloneObject(root.mascotInstances);
                root._pendingMascotInject = root._hasObjectKeys(root._mascotSnapshotForInject);
                return;
            }
            let data = {};
            try {
                data = JSON.parse(JSON.stringify(root.mascotInstances ?? {}));
            } catch (e) {
                data = {};
            }
            let obj = data;
            for (let i = 0; i < subKeys.length - 1; ++i) {
                if (!obj[subKeys[i]] || typeof obj[subKeys[i]] !== "object")
                    obj[subKeys[i]] = {};
                obj = obj[subKeys[i]];
            }
            obj[subKeys[subKeys.length - 1]] = convertedValue;
            root.mascotInstances = data;
            root._mascotSnapshotForInject = root._cloneObject(data);
            root._pendingMascotInject = root._hasObjectKeys(root._mascotSnapshotForInject);
            return;
        }

        let obj = root.options;

        // Traverse to parent object. A schema object holds only what it declares: a key it lacks has no place, and
        // assigning it threw, which also cut a batch (setNestedValues) short at that key. It is named and skipped.
        for (let i = 0; i < keys.length - 1; ++i) {
            if (!obj[keys[i]] || typeof obj[keys[i]] !== "object") {
                if (root._isQtObject(obj) && !(keys[i] in obj))
                    return root._undeclared(keys, i, quiet);
                obj[keys[i]] = {};
            }
            obj = obj[keys[i]];
        }

        const lastKey = keys[keys.length - 1];
        if (root._isQtObject(obj) && !(lastKey in obj))
            return root._undeclared(keys, keys.length - 1, quiet);
        const isPlainObject = convertedValue !== null && typeof convertedValue === "object" && !Array.isArray(convertedValue);
        if (isPlainObject && root._isQtObject(obj[lastKey])) {
            root._assignObjectInto(obj[lastKey], convertedValue);
        } else {
            obj[lastKey] = convertedValue;
        }
        return true;
    }
    // A write to a key the schema does not declare: said once with the whole path (the caller writes it in the wrong
    // place: a widget's own keys go through DesktopWidgetLayout), never thrown. A preview of one passes quietly: the
    // drag's control shows the value and its write on release goes where that key lives.
    property var _undeclaredSaid: ({})
    function _undeclared(keys, at, quiet): bool {
        const path = keys.join(".");
        if (!quiet && !root._undeclaredSaid[path]) {
            root._undeclaredSaid[path] = true;
            console.warn("[Config] " + path + ": the schema declares no " + keys.slice(0, at + 1).join(".") + ", the write is dropped");
        }
        return false;
    }

    function _isQtObject(v) {
        // QObjects always expose objectName; plain JS objects/arrays don't
        return v !== null && typeof v === "object" && v.objectName !== undefined;
    }

    // The engine rejects wholesale QJSValue → JsonObject* assignment, so
    // object payloads aimed at schema-backed sections land key by key.
    function _assignObjectInto(target, value) {
        const ks = Object.keys(value);
        for (let i = 0; i < ks.length; ++i) {
            const k = ks[i];
            const v = value[k];
            if (v !== null && typeof v === "object" && !Array.isArray(v) && root._isQtObject(target[k])) {
                root._assignObjectInto(target[k], v);
            } else {
                target[k] = v;
            }
        }
    }

    // Rows bound to an option re-send it as they load (a switch's onCheckedChanged); writing those back pinned
    // defaults into the file and made every row re-read. A value the option already has is not a write, unless a
    // drag previewed it first.
    property var _previewedKeys: ({})
    function _alreadyHolds(nestedKey, value): bool {
        if (value !== null && typeof value === "object") return false;
        const path = Array.isArray(nestedKey) ? nestedKey.join(".") : String(nestedKey ?? "");
        if (!path || root._previewedKeys[path]) return false;
        const now = root.getNestedValue(nestedKey, undefined);
        return now !== undefined && (typeof now !== "object" || now === null) && now === value;
    }

    // A list handed over from QML (a typed config list, a list a signal carried) is a sequence, not an Array: the
    // mirror kept it as one and the file got it as {"0": ..., "1": ...}, which the schema's list then refused at the
    // next load. Every value is stored as plain JSON data.
    function _plain(value: var): var {
        if (value === null || typeof value !== "object" || root._isQtObject(value)) return value;
        if (Array.isArray(value)) return value.map(item => root._plain(item));
        if (typeof value.length === "number" && Object.getPrototypeOf(value) !== Object.prototype)
            return Array.from(value, item => root._plain(item));
        const out = {};
        for (const key of Object.keys(value)) out[key] = root._plain(value[key]);
        return out;
    }

    function setNestedValue(nestedKey, value) {
        value = root._plain(value);
        if (root._alreadyHolds(nestedKey, value)) return;
        delete root._previewedKeys[Array.isArray(nestedKey) ? nestedKey.join(".") : String(nestedKey ?? "")];
        if (_applyNestedKey(nestedKey, value) === false) return;
        _applyToMirror(nestedKey, value);
        _recordPendingMutation(nestedKey, value);
        fileWriteTimer.restart();
        root._bumpRevision();
        root.configChanged();
    }

    // A value shown while a control is being dragged: its consumers follow it, but nothing is written and the
    // revision stays (every Settings row re-reads on a revision). The drag ends with setNestedValue.
    function previewNestedValue(nestedKey, value) {
        root._previewedKeys[Array.isArray(nestedKey) ? nestedKey.join(".") : String(nestedKey ?? "")] = true;
        _applyNestedKey(nestedKey, root._plain(value), true);
    }

    // Batch multiple key-value pairs, emitting configChanged only once.
    // Usage: Config.setNestedValues({ "a.b.c": 1, "x.y": "hello" })
    function setNestedValues(updates) {
        if (!updates || typeof updates !== "object")
            return;
        updates = root._plain(updates);
        const paths = Object.keys(updates).filter(path => !root._alreadyHolds(path, updates[path]));
        for (let i = 0; i < paths.length; ++i) {
            delete root._previewedKeys[paths[i]];
            if (_applyNestedKey(paths[i], updates[paths[i]]) === false) continue;
            _applyToMirror(paths[i], updates[paths[i]]);
            _recordPendingMutation(paths[i], updates[paths[i]]);
        }
        if (paths.length > 0) {
            fileWriteTimer.restart();
            root._bumpRevision();
            root.configChanged();
        }
    }

    // Extra mascot desktop-widget instances live outside the typed schema
    // (see mascotInstances above) — dedicated add/remove helpers so callers
    // never hand-roll delete-vs-set-undefined semantics on that bucket.
    function addMascotInstance(initial): string {
        const id = Date.now().toString(36) + Math.floor(Math.random() * 1000).toString(36);
        const data = root._cloneObject(root.mascotInstances);
        data[id] = Object.assign({ enable: true }, initial ?? {});
        root.mascotInstances = data;
        root._mascotSnapshotForInject = root._cloneObject(data);
        root._pendingMascotInject = true;
        fileWriteTimer.restart();
        root._bumpRevision();
        root.configChanged();
        return id;
    }

    function _putMascotInstance(id: string, value: var): void {
        const data = root._cloneObject(root.mascotInstances ?? {});
        data[id] = value;
        root.mascotInstances = data;
        root._mascotSnapshotForInject = data;
        root._pendingMascotInject = true;
        fileWriteTimer.restart();
        root._bumpRevision();
        root.configChanged();
    }

    function removeMascotInstance(id: string): void {
        if (!id || !root.mascotInstances || !(id in root.mascotInstances)) return;
        const data = root._cloneObject(root.mascotInstances);
        const gone = data[id];
        Undo.offer(Translation.tr("Removed a mascot"), () => { if (!(id in (root.mascotInstances ?? {}))) root._putMascotInstance(id, gone) });
        delete data[id];
        root.mascotInstances = data;
        root._mascotSnapshotForInject = data;
        root._pendingMascotInject = true;
        fileWriteTimer.restart();
        root._bumpRevision();
        root.configChanged();
    }

    function _applyToMirror(nestedKey, value): void {
        let keys = Array.isArray(nestedKey) ? nestedKey : String(nestedKey).split(".");
        if (keys.length === 0) return;
        // Skip custom widget paths — those are handled separately
        if (keys.length >= 3 && keys[0] === "background" && keys[1] === "widgets" && keys[2] === "custom") return;
        // Skip extra mascot instance paths — same reason
        if (keys.length >= 3 && keys[0] === "background" && keys[1] === "widgets" && keys[2] === "mascotInstances") return;
        let obj = root._jsonMirror;
        let schema = root.options;
        for (let i = 0; i < keys.length - 1; i++) {
            if (!obj[keys[i]] || typeof obj[keys[i]] !== "object")
                obj[keys[i]] = {};
            obj = obj[keys[i]];
            schema = (schema !== null && typeof schema === "object") ? schema[keys[i]] : undefined;
        }

        // The mirror is what reaches disk, and _assignObjectInto only merges an
        // object payload into schema-backed sections. Replacing wholesale here
        // would drop the keys the payload omitted from the file while they stay
        // alive in memory — the setting looks applied and comes back changed on
        // the next start. Mirror the same decision, on the same nodes.
        const lastKey = keys[keys.length - 1];
        const isPlainObject = value !== null && typeof value === "object" && !Array.isArray(value);
        if (isPlainObject && root._isQtObject(schema?.[lastKey])) {
            if (!obj[lastKey] || typeof obj[lastKey] !== "object" || Array.isArray(obj[lastKey]))
                obj[lastKey] = {};
            root._mergeIntoMirror(obj[lastKey], value, schema[lastKey]);
        } else {
            obj[lastKey] = value;
        }
    }

    // Settings runs as a separate Quickshell process. Keep only the paths this
    // process has changed while its deferred write is pending so an external
    // config update can be loaded first and these local mutations replayed on
    // top. Without this, either process can flush a stale full-file mirror and
    // silently undo the other process (most visible with App Filters).
    property var _pendingMutations: ({})
    property bool _rebasingExternalChange: false

    function _recordPendingMutation(nestedKey, value): void {
        const path = Array.isArray(nestedKey) ? nestedKey.join(".") : String(nestedKey ?? "")
        if (!path) return
        const next = Object.assign({}, root._pendingMutations ?? {})
        next[path] = (value !== null && typeof value === "object")
            ? root._cloneObject(value) : value
        root._pendingMutations = next
    }

    function _reapplyPendingMutations(): void {
        const pending = root._pendingMutations ?? {}
        const paths = Object.keys(pending)
        for (let i = 0; i < paths.length; ++i) {
            const path = paths[i]
            root._applyNestedKey(path, pending[path])
            root._applyToMirror(path, pending[path])
        }
        if (paths.length > 0) {
            root._bumpRevision()
            root.configChanged()
            fileWriteTimer.restart()
        }
    }

    function _mergeIntoMirror(target, value, schemaNode): void {
        const ks = Object.keys(value);
        for (let i = 0; i < ks.length; ++i) {
            const k = ks[i];
            const v = value[k];
            const isPlainObject = v !== null && typeof v === "object" && !Array.isArray(v);
            if (isPlainObject && root._isQtObject(schemaNode?.[k])) {
                if (!target[k] || typeof target[k] !== "object" || Array.isArray(target[k]))
                    target[k] = {};
                root._mergeIntoMirror(target[k], v, schemaNode[k]);
            } else {
                target[k] = v;
            }
        }
    }

    function getNestedValue(nestedKey, fallback) {
        let keys = [];
        if (Array.isArray(nestedKey)) {
            keys = nestedKey;
        } else if (typeof nestedKey === "string") {
            keys = nestedKey.split(".");
        } else {
            return fallback;
        }

        if (keys.length === 0)
            return fallback;

        root.revision;
        let obj = root.options;
        let startIndex = 0;
        if (keys.length >= 3 && keys[0] === "background" && keys[1] === "widgets" && keys[2] === "custom") {
            obj = root.customWidgetData;
            startIndex = 3;
        } else if (keys.length >= 3 && keys[0] === "background" && keys[1] === "widgets" && keys[2] === "mascotInstances") {
            obj = root.mascotInstances;
            startIndex = 3;
        }

        for (let i = startIndex; i < keys.length; ++i) {
            if (obj === undefined || obj === null)
                return fallback;
            obj = obj[keys[i]];
        }
        return (obj === undefined || obj === null) ? fallback : obj;
    }

    // Custom widget data lives outside the JsonAdapter (property var inside
    // nested JsonObjects causes a VME segfault). Sync from raw JSON on load.
    function _syncVarProperties(): void {
        let text = "";
        try {
            text = configFileView.text();
        } catch (e) {}
        if (!text || text.length === 0) {
            try {
                rawConfigReader.reload();
                text = rawConfigReader.text();
            } catch (e) {}
        }
        try {
            const raw = JSON.parse(text);
            root.customWidgetData = raw?.background?.widgets?.custom ?? {};
            root.customWidgetDataSynced = true;
            root.mascotInstances = raw?.background?.widgets?.mascotInstances ?? {};
            root.mascotInstancesSynced = true;
        } catch (e) {
            root.customWidgetDataSynced = false;
            root.mascotInstancesSynced = false;
        }
    }

    // writeAdapter() is async — onSaved fires when done. Suppress reloads
    // while a write is in flight so reload() doesn't drop the write op.
    property bool _writeInFlight: false
    property bool _pendingWrite: false
    property bool _pendingCustomInject: false
    property bool _pendingMascotInject: false
    property bool _pendingReload: false
    property int _writeRetries: 0

    // Every write must exit through here; a stuck _writeInFlight freezes all persistence.
    function _endWriteFlight(reason: string): void {
        writeFlightGuard.stop();
        root._writeInFlight = false;
        root._writeRetries = 0;
        if (reason.length > 0)
            console.warn("[Config] write flight released:", reason);
        // Someone else changed the file meanwhile: load it before anything of ours goes out,
        // or the next write serializes memory from before their change and undoes it. The
        // echo of our own save also lands here; it matches the disk and changes nothing.
        if (root._pendingReload) {
            root._pendingReload = false;
            if (root._diskChanged()) {
                root._rebaseOnDisk();
                return;
            }
        }
        if (root._pendingCustomInject || root._pendingMascotInject) {
            root._pendingCustomInject = false;
            root._pendingMascotInject = false;
            customInjectTimer.restart();
            return;
        }
        if (root._pendingWrite) {
            root._pendingWrite = false;
            fileWriteTimer.restart();
            return;
        }
        if (root._pendingReload) {
            root._pendingReload = false;
            fileReloadTimer.restart();
        }
    }
    function _diskChanged(): bool {
        diskProbe.reload();
        return diskProbe.text() !== configFileView.text();
    }

    // Reload the file and replay on top what this process changed since its last write; the
    // custom/mascot inject or write still owed goes out after that (_resumeAfterRebase).
    function _rebaseOnDisk(): void {
        fileWriteTimer.stop();
        fileReloadTimer.stop();
        root._rebasingExternalChange = true;
        configFileView.reload();
    }

    function _resumeAfterRebase(): void {
        if (root._pendingCustomInject || root._pendingMascotInject) {
            root._pendingCustomInject = false;
            root._pendingMascotInject = false;
            customInjectTimer.restart();
        } else if (root._pendingWrite) {
            root._pendingWrite = false;
            fileWriteTimer.restart();
        }
    }
    property var _customSnapshotForInject: ({})
    property var _mascotSnapshotForInject: ({})
    // In-memory mirror of the disk JSON. Updated synchronously on every
    // setNestedValue call. This is the authoritative source for writes —
    // never read back from FileView.text() or the adapter for serialization.
    property var _jsonMirror: ({})

    function _cloneObject(obj: var): var {
        try {
            return JSON.parse(JSON.stringify(obj ?? {}));
        } catch (e) {
            return {};
        }
    }

    function _hasObjectKeys(obj: var): bool {
        return obj && typeof obj === "object" && Object.keys(obj).length > 0;
    }

    function _customDataForWrite(): var {
        if (root._hasObjectKeys(root.customWidgetData))
            return root._cloneObject(root.customWidgetData);
        try {
            const current = JSON.parse(configFileView.text());
            const currentCustom = current?.background?.widgets?.custom ?? {};
            if (root._hasObjectKeys(currentCustom))
                return root._cloneObject(currentCustom);
        } catch (e) {}
        try {
            rawConfigReader.reload();
            const raw = JSON.parse(rawConfigReader.text());
            const diskCustom = raw?.background?.widgets?.custom ?? {};
            if (root._hasObjectKeys(diskCustom))
                return root._cloneObject(diskCustom);
        } catch (e) {}
        return {};
    }

    function _mascotInstancesDataForWrite(): var {
        // Once synced from disk this session, in-memory is authoritative —
        // an intentionally-emptied bucket (user deleted their last instance)
        // must NOT be resurrected from a stale on-disk snapshot below.
        if (root._hasObjectKeys(root.mascotInstances) || root.mascotInstancesSynced)
            return root._cloneObject(root.mascotInstances);
        try {
            const current = JSON.parse(configFileView.text());
            const currentMascot = current?.background?.widgets?.mascotInstances ?? {};
            if (root._hasObjectKeys(currentMascot))
                return root._cloneObject(currentMascot);
        } catch (e) {}
        try {
            rawConfigReader.reload();
            const raw = JSON.parse(rawConfigReader.text());
            const diskMascot = raw?.background?.widgets?.mascotInstances ?? {};
            if (root._hasObjectKeys(diskMascot))
                return root._cloneObject(diskMascot);
        } catch (e) {}
        return {};
    }

    function _prepareCustomInject(): void {
        root._customSnapshotForInject = root._customDataForWrite();
        root._pendingCustomInject = root._hasObjectKeys(root._customSnapshotForInject);
        if (root._pendingCustomInject && !root._hasObjectKeys(root.customWidgetData))
            root.customWidgetData = root._cloneObject(root._customSnapshotForInject);

        root._mascotSnapshotForInject = root._mascotInstancesDataForWrite();
        root._pendingMascotInject = root._hasObjectKeys(root._mascotSnapshotForInject);
        if (root._pendingMascotInject && !root._hasObjectKeys(root.mascotInstances))
            root.mascotInstances = root._cloneObject(root._mascotSnapshotForInject);
    }

    // A writer mid-save leaves the file empty or cut: reading it as the config would write the defaults over the settings.
    property int _loadRetries: 0
    function _retryLoad(): bool {
        if (root._loadRetries >= 20)
            return false;
        root._loadRetries++;
        loadRetryTimer.restart();
        return true;
    }

    Timer {
        id: loadRetryTimer
        interval: 250
        repeat: false
        onTriggered: configFileView.reload()
    }

    // JSON in the layout the adapter writes (Qt's indented form: sorted keys, empty containers on two lines, a final
    // newline). The mirror wrote JSON.stringify's layout right after each adapter save, so every start rewrote the whole
    // file into the other form with the same values.
    function _qtJson(value, depth = 0): string {
        const pad = "    ".repeat(depth), inner = "    ".repeat(depth + 1);
        if (Array.isArray(value)) {
            if (value.length === 0) return "[\n" + pad + "]";
            return "[\n" + value.map(v => inner + root._qtJson(v === undefined || typeof v === "function" ? null : v, depth + 1))
                .join(",\n") + "\n" + pad + "]";
        }
        if (value !== null && typeof value === "object") {
            const keys = Object.keys(value).filter(k => value[k] !== undefined && typeof value[k] !== "function").sort();
            if (keys.length === 0) return "{\n" + pad + "}";
            return "{\n" + keys.map(k => inner + JSON.stringify(k) + ": " + root._qtJson(value[k], depth + 1)).join(",\n")
                + "\n" + pad + "}";
        }
        return JSON.stringify(value) ?? "null";
    }

    // Fallback: write the mirror directly when writeAdapter() doesn't emit onSaved.
    function _writeMirrorToDisk(): void {
        if (!root.ready) return;
        try {
            let obj = root._jsonMirror;
            if (!obj || Object.keys(obj).length === 0) return;
            if (root._hasObjectKeys(root.customWidgetData)) {
                if (!obj.background) obj.background = {};
                if (!obj.background.widgets) obj.background.widgets = {};
                obj.background.widgets.custom = root.customWidgetData;
            }
            if (root._hasObjectKeys(root.mascotInstances)) {
                if (!obj.background) obj.background = {};
                if (!obj.background.widgets) obj.background.widgets = {};
                obj.background.widgets.mascotInstances = root.mascotInstances;
            }
            configFileView.setText(root._qtJson(obj) + "\n");
        } catch (e) {
            console.warn("[Config] mirror write failed:", e.message);
        }
    }

    function _injectCustomDataSync(): void {
        const customData = root._hasObjectKeys(root._customSnapshotForInject)
            ? root._customSnapshotForInject : root.customWidgetData;
        const mascotData = root._hasObjectKeys(root._mascotSnapshotForInject)
            ? root._mascotSnapshotForInject : root.mascotInstances;
        const hasCustom = root._hasObjectKeys(customData);
        const hasMascot = root._hasObjectKeys(mascotData);
        if (!hasCustom && !hasMascot) return;
        try {
            if (!root._jsonMirror.background) root._jsonMirror.background = {};
            if (!root._jsonMirror.background.widgets) root._jsonMirror.background.widgets = {};
            if (hasCustom) {
                root._jsonMirror.background.widgets.custom = customData;
                root.customWidgetData = root._cloneObject(customData);
                root._customSnapshotForInject = ({});
            }
            if (hasMascot) {
                root._jsonMirror.background.widgets.mascotInstances = mascotData;
                root.mascotInstances = root._cloneObject(mascotData);
                root._mascotSnapshotForInject = ({});
            }
            root._writeInFlight = true;
            configFileView.setText(root._qtJson(root._jsonMirror) + "\n");
        } catch (e) { root._writeInFlight = false; }
    }

    Timer {
        id: fileReloadTimer
        interval: root.readWriteDelay
        repeat: false
        onTriggered: {
            if (root._writeInFlight || customInjectTimer.running) {
                root._pendingReload = true;
                return;
            }
            root._echoChecks = Math.min(root._echoChecks + 1, 4);
            rawConfigReader.reload();
        }
    }

    // Every save of ours comes back as a fileChanged; reloading it repopulates the whole
    // adapter and bumps `revision` for every reader. Reload only when the disk differs.
    property int _echoChecks: 0

    function _reloadIfExternal(): void {
        if (root._writeInFlight || customInjectTimer.running) {
            root._pendingReload = true;
            return;
        }
        if (rawConfigReader.text() === configFileView.text())
            return;
        configFileView.reload();
        root._syncVarProperties();
        root.configChanged();
    }

    Timer {
        id: fileWriteTimer
        interval: root.readWriteDelay
        repeat: false
        onTriggered: {
            if (!root.ready) {
                root._pendingWrite = true;
                return;
            }
            if (root._writeInFlight) {
                root._pendingWrite = true;
                return;
            }
            root._prepareCustomInject();
            root._pendingWrite = false;
            root._writeInFlight = true;
            root._pendingMutations = ({});
            root._writeRetries = 0;
            fileReloadTimer.stop();
            // Try writeAdapter first — it properly emits QObject property signals
            // which 2476 consumers depend on via Config.options?.x bindings.
            configFileView.writeAdapter();
            writeFlightGuard.restart();
        }
    }

    // If writeAdapter doesn't emit onSaved within 2s (QS 0.3 dirty-detection
    // edge case), fall back to writing the mirror directly.
    Timer {
        id: writeFlightGuard
        interval: 2000
        repeat: false
        onTriggered: {
            if (!root._writeInFlight)
                return;
            // No save came back because ours was a no-op (the file already had those bytes), and
            // the file changed since: writing the mirror now would undo that change.
            if (root._pendingReload && root._diskChanged()) {
                root._endWriteFlight("");
                return;
            }
            // The file already holds the mirror byte for byte: a write that changes nothing is never acknowledged.
            if (configFileView.text() === root._qtJson(root._jsonMirror) + "\n") {
                root._endWriteFlight("");
                return;
            }
            if (root._writeRetries >= 2) {
                root._endWriteFlight("write never acknowledged");
                return;
            }
            root._writeRetries++;
            root._writeMirrorToDisk();
            writeFlightGuard.restart();
        }
    }

    Timer {
        id: customInjectTimer
        interval: 1
        repeat: false
        onTriggered: root._injectCustomDataSync()
    }

    // Plugins' parts of the config (`iris`, `waffles` slots in the adapter) are filled before the file is read: the
    // plugin's schema (plugin.json `configKey` and part `config`), or, when no installed plugin owns the key, a holder
    // that reads and writes that subtree back whole, so removing a plugin loses none of its settings.
    // The slots are the adapter's empty JsonObject properties (ConfigOptions declares them without a value), so the
    // list has one owner.
    readonly property var _pluginSlots: Object.keys(configOptionsJsonAdapter).filter(k => /^[a-z]\w*$/.test(k)
        && !root._reservedNames.includes(k) && configOptionsJsonAdapter[k] === null)
    // The active family's own subtree (`material`, `waffles`, `iris`): what a shared surface reads for that family's
    // look of it, so the base never names a family.
    readonly property var family: {
        const key = String(Plugins.manifests?.[Plugins.active]?.configKey ?? "");
        return key.length > 0 && root._slotsReady ? configOptionsJsonAdapter[key] : null;
    }
    readonly property var _reservedNames: ["objectName", "property", "signal", "readonly", "alias", "function", "default",
        "required", "import", "as", "on", "enum", "component", "pragma", "var", "let", "const", "if", "else", "for", "while",
        "do", "return", "new", "delete", "typeof", "instanceof", "in", "of", "this", "null", "true", "false", "switch",
        "case", "break", "continue", "class", "extends", "super", "void", "with", "yield", "try", "catch", "finally",
        "throw", "debugger", "export", "static"]
    property bool _slotsReady: false

    Connections {
        target: Plugins
        function onReadyChanged(): void { root._installSlots(false) }
    }
    Component.onCompleted: root._installSlots(false)
    // Plugins should answer within a frame or two; if it never does, the config still loads (every slot a holder).
    Timer {
        interval: 3000
        running: !root._slotsReady
        onTriggered: {
            console.warn("[Config] plugins not read after 3 s; plugin settings load without their schemas");
            root._installSlots(true);
        }
    }

    function _installSlots(force: bool): void {
        if (root._slotsReady || !(Plugins.ready || force)) return;
        let disk = root._migrateDisk();
        for (const key of root._pluginSlots) {
            const owner = Object.keys(Plugins.manifests).find(id => Plugins.manifests[id].configKey === key);
            let slot = null;
            if (owner) {
                const component = Qt.createComponent(Plugins.part(owner, "config"), Component.PreferSynchronous);
                slot = component.status === Component.Ready ? component.createObject(configOptionsJsonAdapter) : null;
                if (!slot) console.warn(`[Config] ${owner}'s config schema failed to load: ${component.errorString()}`);
            }
            if (!slot)
                slot = root._holderFor(disk?.[key]);
            configOptionsJsonAdapter[key] = slot;
        }
        if (ConfigMigrations.listsBack(disk, path => root._schemaHoldsList(path))) {
            diskProbe.setText(root._qtJson(disk) + "\n");
            console.log("[Config] lists stored as maps read back as lists");
        }
        root._slotsReady = true;
    }

    function _schemaHoldsList(path: string): bool {
        let node = configOptionsJsonAdapter;
        for (const key of path.split(".")) {
            if (node === null || typeof node !== "object" || !(key in node)) return false;
            node = node[key];
        }
        return node !== null && typeof node === "object" && !root._isQtObject(node) && typeof node.length === "number";
    }

    // Keys that changed owner move in the file itself before anything reads it (ConfigMigrations.js), so the person's
    // values follow them whatever path brought this version.
    function _migrateDisk(): var {
        diskProbe.reload();
        const text = diskProbe.text() || "";
        let disk = {};
        try { disk = JSON.parse(text || "{}"); } catch (e) { return {}; }
        if (text.length > 0 && ConfigMigrations.migrate(disk)) {
            diskProbe.setText(root._qtJson(disk) + "\n");
            console.log("[Config] moved keys to their owners (ConfigMigrations.js)");
        }
        return disk;
    }

    function _holderFor(subtree): QtObject {
        const keys = subtree && typeof subtree === "object" && !Array.isArray(subtree)
            ? Object.keys(subtree).filter(k => /^[a-z_][A-Za-z0-9_]*$/.test(k) && !root._reservedNames.includes(k)) : [];
        return Qt.createQmlObject(`import Quickshell.Io\nJsonObject {\n${keys.map(k => `    property var ${k}`).join("\n")}\n}`,
            configOptionsJsonAdapter, "configHolder");
    }

    // What is on disk right now, read on the spot (external-change checks around a write).
    FileView {
        id: diskProbe
        path: root.filePath
        preload: false
        blockAllReads: true
        blockWrites: true
        printErrors: false
    }

    // Raw reader for keys the adapter can't handle (property var in JsonObject)
    FileView {
        id: rawConfigReader
        path: root.filePath
        onLoaded: {
            if (root._echoChecks <= 0)
                return;
            root._echoChecks--;
            root._reloadIfExternal();
        }
        onLoadFailed: {
            if (root._echoChecks <= 0)
                return;
            root._echoChecks = 0;
            configFileView.reload();
        }
    }

    FileView {
        id: configFileView
        path: root._slotsReady ? root.filePath : ""
        watchChanges: true
        blockWrites: root.blockWrites
        onFileChanged: {
            if (root._writeInFlight) {
                root._pendingReload = true;
                return;
            }
            if (fileWriteTimer.running || Object.keys(root._pendingMutations ?? {}).length > 0) {
                fileWriteTimer.stop();
                root._rebasingExternalChange = true;
                configFileView.reload();
                return;
            }
            fileReloadTimer.restart();
        }
        onSaved: root._endWriteFlight("")
        onSaveFailed: error => root._endWriteFlight(`save failed (${error})`)
        onLoaded: {
            // Initialize the in-memory JSON mirror from disk
            try {
                root._jsonMirror = JSON.parse(configFileView.text());
            } catch (e) {
                if (root._retryLoad())
                    return;
                Quickshell.execDetached(["cp", "--", root.filePath, root.filePath + ".unreadable"]);
                root._jsonMirror = {};
            }
            root._loadRetries = 0;
            // Workaround: JsonAdapter doesn't populate property var inside nested JsonObjects.
            // Manually sync custom widget data from the raw JSON.
            root._syncVarProperties();
            root._bumpRevision();
            root.ready = true;
            if (root._rebasingExternalChange) {
                root._rebasingExternalChange = false;
                root._reapplyPendingMutations();
                root._resumeAfterRebase();
            }
        }
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                console.log("[Config] File not found, creating new file.");
                // Ensure parent directory exists
                const parentDir = root.filePath.substring(0, root.filePath.lastIndexOf('/'));
                Quickshell.execDetached(["mkdir", "-p", parentDir]);
                root.customWidgetData = {};
                root.customWidgetDataSynced = true;
                root.mascotInstances = {};
                root.mascotInstancesSynced = true;
                writeAdapter();
            } else if (root._retryLoad()) {
                return;
            }
            // Set ready even on failure so UI doesn't stay blank
            root.ready = true;
        }

        ConfigOptions {
            id: configOptionsJsonAdapter
        }
    }
}
