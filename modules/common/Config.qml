pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

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
        root._writeRetries = 0;
        root._writeMirrorToDisk();
        writeFlightGuard.restart();
    }

    function _applyNestedKey(nestedKey, value) {
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

        // Traverse to parent object
        for (let i = 0; i < keys.length - 1; ++i) {
            if (!obj[keys[i]] || typeof obj[keys[i]] !== "object") {
                obj[keys[i]] = {};
            }
            obj = obj[keys[i]];
        }

        const lastKey = keys[keys.length - 1];
        const isPlainObject = convertedValue !== null && typeof convertedValue === "object" && !Array.isArray(convertedValue);
        if (isPlainObject && root._isQtObject(obj[lastKey])) {
            root._assignObjectInto(obj[lastKey], convertedValue);
        } else {
            obj[lastKey] = convertedValue;
        }
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

    function setNestedValue(nestedKey, value) {
        _applyNestedKey(nestedKey, value);
        _applyToMirror(nestedKey, value);
        fileWriteTimer.restart();
        root._bumpRevision();
        root.configChanged();
    }

    // Batch multiple key-value pairs, emitting configChanged only once.
    // Usage: Config.setNestedValues({ "a.b.c": 1, "x.y": "hello" })
    function setNestedValues(updates) {
        if (!updates || typeof updates !== "object")
            return;
        const paths = Object.keys(updates);
        for (let i = 0; i < paths.length; ++i) {
            _applyNestedKey(paths[i], updates[paths[i]]);
            _applyToMirror(paths[i], updates[paths[i]]);
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

    function removeMascotInstance(id: string): void {
        if (!id || !root.mascotInstances || !(id in root.mascotInstances)) return;
        const data = root._cloneObject(root.mascotInstances);
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

    // Fallback: write the mirror directly when writeAdapter() doesn't emit onSaved.
    function _writeMirrorToDisk(): void {
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
            configFileView.setText(JSON.stringify(obj, null, 4));
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
            configFileView.setText(JSON.stringify(root._jsonMirror, null, 4));
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
            configFileView.reload();
            root._syncVarProperties();
            root.configChanged();
        }
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

    // Raw reader for keys the adapter can't handle (property var in JsonObject)
    FileView {
        id: rawConfigReader
        path: root.filePath
    }

    FileView {
        id: configFileView
        path: root.filePath
        watchChanges: true
        blockWrites: root.blockWrites
        onFileChanged: {
            if (root._writeInFlight) {
                root._pendingReload = true;
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
                root._jsonMirror = {};
            }
            // Workaround: JsonAdapter doesn't populate property var inside nested JsonObjects.
            // Manually sync custom widget data from the raw JSON.
            root._syncVarProperties();
            root._bumpRevision();
            root.ready = true;
        }
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                console.log("[Config] File not found, creating new file.");
                // Ensure parent directory exists
                const parentDir = root.filePath.substring(0, root.filePath.lastIndexOf('/'));
                Quickshell.execDetached(["/usr/bin/mkdir", "-p", parentDir]);
                root.customWidgetData = {};
                root.customWidgetDataSynced = true;
                root.mascotInstances = {};
                root.mascotInstancesSynced = true;
                writeAdapter();
            }
            // Set ready even on failure so UI doesn't stay blank
            root.ready = true;
        }

        JsonAdapter {
            id: configOptionsJsonAdapter

            // Panel system
            property list<string> enabledPanels: ["iiBar", "iiBackground", "iiBackdrop", "iiCheatsheet", "iiControlPanel", "iiDock", "iiLock", "iiMediaControls", "iiNotificationPopup", "iiOnScreenDisplay", "iiOnScreenKeyboard", "iiOverlay", "iiOverview", "iiPolkit", "iiRegionSelector", "iiScreenCorners", "iiSessionScreen", "iiSidebarLeft", "iiSidebarRight", "iiTilingOverlay", "iiVerticalBar", "iiWallpaperSelector", "iiWallpaperLauncher", "iiCoverflowSelector", "iiClipboard", "iiShellUpdate", "iiDashboard", "iiMascotCompanion"]
            property list<string> knownPanels: [] // Tracks panels the user has seen; used to distinguish "user disabled" from "new in update"
            property string panelFamily: "ii" // "ii" or "waffle"
            property bool familyTransitionAnimation: true // Show animated overlay when switching families

            property JsonObject policies: JsonObject {
                property int ai: 0 // 0: No | 1: Yes | 2: Local
                property int weeb: 0 // 0: No | 1: Open | 2: Closet
            }

            property JsonObject ai: JsonObject {
                property string systemPrompt: "## Style\n- Use casual tone, don't be formal! Make sure you answer precisely without hallucination and prefer bullet points over walls of text. You can have a friendly greeting at the beginning of the conversation, but don't repeat the user's question\n\n## Context (ignore when irrelevant)\n- You are a helpful and inspiring sidebar assistant on a {DISTRO} Linux system\n- Desktop environment: {DE}\n- Current date & time: {DATETIME}\n- Focused app: {WINDOWCLASS}\n\n## Presentation\n- Use Markdown features in your response: \n  - **Bold** text to **highlight keywords** in your response\n  - **Split long information into small sections** with h2 headers and a relevant emoji at the start of it (for example `## 🐧 Linux`). Bullet points are preferred over long paragraphs, unless you're offering writing support or instructed otherwise by the user.\n- Asked to compare different options? You should firstly use a table to compare the main aspects, then elaborate or include relevant comments from online forums *after* the table. Make sure to provide a final recommendation for the user's use case!\n- Use LaTeX formatting for mathematical and scientific notations whenever appropriate. Enclose all LaTeX '$$' delimiters. NEVER generate LaTeX code in a latex block unless the user explicitly asks for it. DO NOT use LaTeX for regular documents (resumes, letters, essays, CVs, etc.).\n"
                property string tool: "functions" // search, functions, or none
                property list<var> extraModels: [
                    {
                        "api_format": "openai" // Most of the time you want "openai". Use "gemini" for Google's models
                        ,
                        "description": "This is a custom model. Edit the config to add more! | Anyway, this is DeepSeek R1 Distill LLaMA 70B",
                        "endpoint": "https://openrouter.ai/api/v1/chat/completions",
                        "homepage": "https://openrouter.ai/deepseek/deepseek-r1-distill-llama-70b:free" // Not mandatory
                        ,
                        "icon": "spark-symbolic" // Not mandatory
                        ,
                        "key_get_link": "https://openrouter.ai/settings/keys" // Not mandatory
                        ,
                        "key_id": "openrouter",
                        "model": "deepseek/deepseek-r1-distill-llama-70b:free",
                        "name": "Custom: DS R1 Dstl. LLaMA 70B",
                        "requires_key": true
                    }
                ]
            }

            property JsonObject mascot: JsonObject {
                property bool enable: false // Show the iNiR mascot illustration across shell surfaces (empty states, About, etc.)
                property JsonObject surfaces: JsonObject {
                    // Where the static mascot may appear; each maps to a group of placements
                    property bool emptyStates: true // Notifications, clipboard, todo, media, calendar, wallpapers, search results
                    property bool about: true // About pages
                    property bool session: true // Session (power) screen
                    property bool aiChat: true // AI chat greeting
                    property bool dashboard: true // Dashboard welcome/weather cards
                    property bool cheatsheet: true // Cheatsheet nav rail
                    property bool bootGreeting: true // Boot welcome wave
                    property bool updates: true // Shell update overlay
                    property bool dialogs: true // Close confirmation and similar dialogs
                }
                property JsonObject companion: JsonObject {
                    property bool enable: true // Playful companion: she peeks from screen edges and reacts to events (needs mascot.enable)
                    property int intervalMinutes: 25 // Roughly how often she peeks on her own; event reactions are rate-limited separately
                    property int size: 150 // Sprite size in px
                    property int visibleSeconds: 8 // How long a peek stays before she slides away (hover keeps her)
                    property int slideMs: 400 // Slide in/out animation duration
                    property bool musicRequireArtist: true // Ignore artist-less MPRIS players (browser videos posing as music)
                    property JsonObject events: JsonObject {
                        // Which shell events she reacts to (event reactions, not idle peeks)
                        property bool music: true
                        property bool battery: true
                        property bool update: true
                        property bool network: true
                        property bool dnd: true
                        property bool notification: true
                        property bool wallpaper: true
                        property bool screenshot: true
                        property bool gaming: true
                        property bool workspace: true
                        property bool unlock: true
                    }
                    property JsonObject eventPoses: JsonObject {
                        // Per-event pose override; "" rotates the manifest pose pool
                        property string music: ""
                        property string battery: ""
                        property string update: ""
                        property string network: ""
                        property string dnd: ""
                        property string notification: ""
                        property string wallpaper: ""
                        property string screenshot: ""
                        property string gaming: ""
                        property string workspace: ""
                        property string unlock: ""
                    }
                    property list<string> customLines: [] // Extra things she can say on idle peeks (one per entry)
                    property JsonObject edges: JsonObject {
                        property bool left: true
                        property bool right: true
                        property bool top: true
                        property bool bottom: true
                    }
                    property string placement: "peek" // "peek" | "panel-sitter" — float off-screen edge or sit on bar/dock
                    property bool contextualPlacement: false // Opt-in: appear near triggering widget instead of random edge
                    property string monitor: "primary" // "primary" | "focused" — which screen she appears on
                }
                property JsonObject surfacePoses: JsonObject {
                    // Per-surface pose override ("" = each spot's curated
                    // default). GIF catalog names animate. Fine keys win over
                    // the coarse emptyStates group they were split from.
                    property string emptyStates: ""
                    property string about: ""
                    property string session: ""
                    property string aiChat: ""
                    property string dashboard: ""
                    property string cheatsheet: ""
                    property string updates: ""
                    property string dialogs: ""
                    property string notifications: ""
                    property string clipboard: ""
                    property string mediaControls: ""
                    property string todo: ""
                    property string calendar: ""
                    property string wifi: ""
                    property string startMenu: ""
                    property string wallpaperSelector: ""
                    property string bootGreeting: ""
                }
                property JsonObject personality: JsonObject {
                    property bool enabled: true // Session-long mood flavor (sleepy/hyper/snarky/contemplative)
                    property int idleMoodIntervalMinutes: 30 // How often mood rolls (with ±50% jitter)
                    property bool commentary: true // Personal observations (3AM commits, uptime, app marathons); off = generic lines only
                    property string voiceMode: "adaptive" // adaptive | casual | dry | composed | chaotic
                }
                property JsonObject chaos: JsonObject {
                    property bool enable: false // Chaos mode: she may run across the desktop and mess with widgets/panels
                    property bool allowRearrange: false // Let her actually relocate widgets (otherwise everything bounces back)
                    property bool sfx: true // Impact foley from the freedesktop sound theme during chaos
                    property bool systemEvents: true // Rare romps reacting to low battery, notification pileup, or late-night hours
                }
            }

            property JsonObject appearance: JsonObject {
                property string theme: "auto" // Theme preset ID: "auto" for wallpaper-based, or preset name like "gruvbox-dark", "catppuccin-mocha", "custom", etc.
                property string globalStyle: "material" // "material" | "cards" | "aurora" | "inir" | "angel" | "zzz" | "cookie"
                // Shared skin for every island surface (islands bar, island dock,
                // island sidebars, island search). Consumed by IslandPanel.
                property JsonObject island: JsonObject {
                property bool glass: true // Blurred wallpaper behind translucent island cards (needs opacity < 100%)
                property real glassBlur: 1 // Blur intensity of the glass backdrop (0.2–1)
                    property int radius: 18 // Corner radius where the surface doesn't set its own
                    property real opacity: 1 // Gradient fill opacity (0–1)
                    property bool shadow: true // Soft drop shadow behind the card
                    property bool sheen: true // 1px lit top edge
                }
                property bool colorInvert: false // Rotate all m3 colors 180° (complementary palette). Shell-only, does not affect external apps.
                property JsonObject aurora: JsonObject {
                    property JsonObject transparency: JsonObject {
                        property real overlay: 0.38       // Main panels
                        property real subSurface: 0.52    // Cards/groups
                        property real popup: 0.42         // Popups/menus
                        property real tooltip: 0.35       // Tooltips
                        property real layer: 0.40         // General layer glass (colLayer1/2/3)
                    }
                    property string customPreset: ""
                }
                property string angelSubStyle: "frost" // "frost" | "neon" | "void"
                // ZZZ personality axis: silhouette variant. "square" = sharp
                // console plates with cut-corner chamfers (classic ZZZ). "round" =
                // softer anime UI — pills for controls, rounded panels, no chamfer.
                property JsonObject zzz: JsonObject {
                    property string shape: "square" // "square" | "round"
                    property bool glass: true // subtle wallpaper-blur behind the grid (gated by effectsEnabled)
                    // Master switches for the ZZZ panel backdrop layers. Each ANDs with
                    // the per-panel intent, so turning one off hides that layer shell-wide.
                    property JsonObject backdrop: JsonObject {
                        property bool burst: true      // diagonal accent slashes (dashboard triad, etc.)
                        property bool ghost: true      // large ghost wordmark behind content (panel name)
                        property bool grid: true       // faint technical engineering grid
                        property bool ticks: true      // scan ticks (used on the session screen)
                        property real burstSize: 1.0   // size multiplier for the diagonal burst
                    }
                }
                property JsonObject angel: JsonObject {
                    property JsonObject blur: JsonObject {
                        property real intensity: 0.25
                        property real saturation: 0.15
                        property real overlayOpacity: 0.35
                        property real noiseOpacity: 0.15
                        property real vignetteStrength: 0.4
                    }
                    property JsonObject transparency: JsonObject {
                        property real panel: 0.35
                        property real card: 0.50
                        property real popup: 0.35
                        property real tooltip: 0.25
                    }
                    property JsonObject escalonado: JsonObject {
                        property int offsetX: 2
                        property int offsetY: 2
                        property int hoverOffsetX: 7
                        property int hoverOffsetY: 7
                        property real opacity: 0.40
                        property real borderOpacity: 0.60
                        property real hoverOpacity: 0.60
                    }
                    property JsonObject escalonadoShadow: JsonObject {
                        property int offsetX: 4
                        property int offsetY: 4
                        property int hoverOffsetX: 10
                        property int hoverOffsetY: 10
                        property real opacity: 0.30
                        property real borderOpacity: 0.50
                        property real hoverOpacity: 0.50
                        property bool glass: true
                        property real glassBlur: 0.15
                        property real glassOverlay: 0.50
                    }
                    property JsonObject border: JsonObject {
                        property real width: 1.5
                        property int accentBarHeight: 0
                        property int accentBarWidth: 0
                        property real coverage: 0.0
                        property real opacity: 0.0
                        property real hoverOpacity: 0.0
                        property real activeOpacity: 0.0
                        property int insetGlowHeight: 0
                        property real insetGlowOpacity: 0.0
                    }
                    property JsonObject surface: JsonObject {
                        property int panelBorderWidth: 0
                        property int cardBorderWidth: 1
                        property real panelBorderOpacity: 0.0
                        property real cardBorderOpacity: 0.30
                    }
                    property JsonObject glow: JsonObject {
                        property real opacity: 0.80
                        property real strongOpacity: 0.65
                    }
                    property JsonObject rounding: JsonObject {
                        property int small: 10
                        property int normal: 15
                        property int large: 25
                    }
                    property real colorStrength: 1.0
                    property string customPreset: ""
                }
                property list<string> recentThemes: []  // Last 4 used themes
                property list<string> favoriteThemes: []  // User's favorite themes
                property JsonObject themeSchedule: JsonObject {
                    property bool enabled: false
                    property string dayTheme: "auto"
                    property string nightTheme: "auto"
                    property string dayStart: "06:00"
                    property string nightStart: "18:00"
                }
                // Corner style preference per global style (0=Hug, 1=Float, 2=Rect, 3=Card)
                property JsonObject globalStyleCornerStyles: JsonObject {
                    property int material: 1
                    property int cards: 3
                    property int aurora: 0
                    property int inir: 1
                    property int angel: 1
                    property int zzz: 0
                    property int cookie: 1
                }
                property bool extraBackgroundTint: true
                property bool softenColors: true
                property JsonObject customTheme: JsonObject {
                    property bool darkmode: true
                    property string m3background: "#282828"
                    property string m3onBackground: "#ebdbb2"
                    property string m3surface: "#282828"
                    property string m3surfaceDim: "#1d2021"
                    property string m3surfaceBright: "#3c3836"
                    property string m3surfaceContainerLowest: "#1d2021"
                    property string m3surfaceContainerLow: "#282828"
                    property string m3surfaceContainer: "#32302f"
                    property string m3surfaceContainerHigh: "#3c3836"
                    property string m3surfaceContainerHighest: "#504945"
                    property string m3onSurface: "#ebdbb2"
                    property string m3surfaceVariant: "#504945"
                    property string m3onSurfaceVariant: "#d5c4a1"
                    property string m3inverseSurface: "#ebdbb2"
                    property string m3inverseOnSurface: "#282828"
                    property string m3outline: "#928374"
                    property string m3outlineVariant: "#665c54"
                    property string m3shadow: "#000000"
                    property string m3scrim: "#000000"
                    property string m3surfaceTint: "#fe8019"
                    property string m3primary: "#fe8019"
                    property string m3onPrimary: "#1d2021"
                    property string m3primaryContainer: "#af3a03"
                    property string m3onPrimaryContainer: "#fbd5a8"
                    property string m3inversePrimary: "#d65d0e"
                    property string m3secondary: "#b8bb26"
                    property string m3onSecondary: "#1d2021"
                    property string m3secondaryContainer: "#79740e"
                    property string m3onSecondaryContainer: "#d5c4a1"
                    property string m3tertiary: "#83a598"
                    property string m3onTertiary: "#1d2021"
                    property string m3tertiaryContainer: "#427b58"
                    property string m3onTertiaryContainer: "#d5c4a1"
                    property string m3error: "#fb4934"
                    property string m3onError: "#1d2021"
                    property string m3errorContainer: "#cc241d"
                    property string m3onErrorContainer: "#fbd5a8"
                    property string m3primaryFixed: "#fabd2f"
                    property string m3primaryFixedDim: "#d79921"
                    property string m3onPrimaryFixed: "#1d2021"
                    property string m3onPrimaryFixedVariant: "#3c3836"
                    property string m3secondaryFixed: "#b8bb26"
                    property string m3secondaryFixedDim: "#98971a"
                    property string m3onSecondaryFixed: "#1d2021"
                    property string m3onSecondaryFixedVariant: "#3c3836"
                    property string m3tertiaryFixed: "#8ec07c"
                    property string m3tertiaryFixedDim: "#689d6a"
                    property string m3onTertiaryFixed: "#1d2021"
                    property string m3onTertiaryFixedVariant: "#3c3836"
                    property string m3success: "#b8bb26"
                    property string m3onSuccess: "#1d2021"
                    property string m3successContainer: "#79740e"
                    property string m3onSuccessContainer: "#d5c4a1"
                }
                property int fakeScreenRounding: 2 // 0: None | 1: Always | 2: When not fullscreen
                property JsonObject transparency: JsonObject {
                    property bool enable: false
                    property bool automatic: true
                    property real backgroundTransparency: 0.11
                    property real contentTransparency: 0.57
                }
                property JsonObject wallpaperTheming: JsonObject {
                    // Auto-pick the light/dark scheme from the wallpaper's brightness
                    // on each wallpaper change, so UI text stays readable. Opt-in;
                    // when off, the mode follows the manual dark-mode toggle as before.
                    property bool autoDarkLightMode: false
                    property bool enableAppsAndShell: true
                    property bool enableQtApps: true
                    property bool enableTerminal: true
                    property bool enableVesktop: true
                    property bool enableZed: true
                    property bool enableVSCode: true
                    property bool enableChrome: true
                    property bool enableSpicetify: false
                    property bool enableSteam: false
                    property bool enablePearDesktop: true
                    property bool enableOpenCode: false
                    property bool enableNeovim: false
                    property bool enableCava: false
                    property real colorStrength: 1.0
                    property JsonObject vscodeEditors: JsonObject {
                        property bool code: true           // Official VSCode
                        property bool codium: true         // VSCodium (FOSS)
                        property bool codeOss: true        // Code - OSS
                        property bool codeInsiders: true   // Code - Insiders
                        property bool cursor: true         // Cursor AI
                        property bool windsurf: true       // Windsurf AI
                        property bool windsurfNext: true   // Windsurf - Next
                        property bool qoder: true          // Qoder
                        property bool antigravity: true    // Antigravity
                        property bool positron: true       // Positron
                        property bool voidEditor: true     // Void
                        property bool melty: true          // Melty
                        property bool pearai: true         // PearAI
                        property bool aide: true           // Aide
                    }
                    property bool useBackdropForColors: false
                    property bool colorsOnlyMode: false
                    property string previewSourcePath: ""
                    property JsonObject terminals: JsonObject {
                        property bool kitty: true
                        property bool alacritty: true
                        property bool foot: true
                        property bool wezterm: true
                        property bool ghostty: true
                        property bool konsole: true
                        property bool starship: true
                        property bool btop: true
                        property bool lazygit: true
                        property bool yazi: true
                        property bool omp: true
                    }
                    property JsonObject terminalGenerationProps: JsonObject {
                        property real harmony: 0.6
                        property real harmonizeThreshold: 100
                        property real termFgBoost: 0.35
                        property bool forceDarkMode: false
                    }
                    property JsonObject terminalColorAdjustments: JsonObject {
                        property real saturation: 0.65  // 0.0 - 1.0
                        property real brightness: 0.60  // 0.0 - 1.0 (lightness for dark mode)
                        property real harmony: 0.40     // 0.0 - 1.0 (how much to shift towards primary)
                        property real backgroundBrightness: 0.50  // 0.0 - 1.0 (0=darkest, 1=lightest)
                    }
                }
                property JsonObject cava: JsonObject {
                    property string colorSource: "theme" // Internal visualizers + standalone cava: theme | vibrant | cover
                    property int gradientCount: 8 // 1-8; one color becomes a solid standalone cava foreground
                    property string foreground: "" // empty = gradient; hex = solid foreground
                    property string background: "" // empty = palette surface; hex = override
                    property int sensitivity: 100 // 1-500
                    property int bars: 0 // 0 = auto
                    property int framerate: 60 // 30-165
                    property int barWidth: 2
                    property int barSpacing: 1
                    property bool stereo: true
                    property int waveOpacity: 30 // 5-100, fill alpha for WaveVisualizer (0.05–1.0)
                }
                property JsonObject palette: JsonObject {
                    property string type: "auto" // Allowed: auto, scheme-content, scheme-expressive, scheme-fidelity, scheme-fruit-salad, scheme-monochrome, scheme-neutral, scheme-rainbow, scheme-tonal-spot
                    property string accentColor: "" // Seed color hex for scheme variant (e.g. "#ab1234"), empty = use theme primary
                }
                property JsonObject typography: JsonObject {
                    property string mainFont: "Roboto Flex"
                    property string titleFont: "Gabarito"
                    property string monospaceFont: "JetBrainsMono Nerd Font"
                    property real sizeScale: 1.0
                    property bool syncWithSystem: true // Sync fonts with GTK/KDE apps
                    property JsonObject variableAxes: JsonObject {
                        property int wght: 300
                        property int wdth: 105
                        property int grad: 150
                    }
                }
                property string iconTheme: "WhiteSur-dark" // System icon theme (tray, GTK/Qt apps)
                property string dockIconTheme: "" // Dock icon theme (overrides system for dock only)
                property real shellScale: 1.0 // Legacy compatibility key. Launcher keeps QT_SCALE_FACTOR=1; use appearance.typography.sizeScale.
                property string iiMotionProfile: "classic" // "classic" | "contextual"
                property JsonObject desaturation: JsonObject {
                    property bool enable: false
                    property real saturation: -0.7  // -1 to 0 (0 = normal, -1 = full grayscale)
                    property real brightness: -0.15 // -1 to 1 (0 = normal)
                    property string scope: "all"    // "all" | "panels" | "custom"
                    property bool bar: true
                    property bool dock: true
                    property bool sidebars: true
                    property bool overlays: true
                    property bool popups: true
                }
                // Per-category multipliers on top of Appearance.animation.* base durations.
                // 1.0 = default speed, <1 faster, >1 slower. Zeroed regardless when
                // performance.reduceAnimations disables animations.
                property JsonObject animationSpeed: JsonObject {
                    property real movement: 1.0   // elementMove, elementResize
                    property real enterExit: 1.0  // elementMoveEnter, elementMoveExit
                    property real clickBounce: 1.0 // clickBounce, elementMoveFast
                    property real scroll: 1.0     // scroll, menuDecel
                }
                // Curve override per category. "default" keeps the existing style/motion-profile
                // aware pick in Appearance.animation.*; any other value forces that curve everywhere.
                property JsonObject animationCurve: JsonObject {
                    property string movement: "default"
                    property string enterExit: "default"
                    property string clickBounce: "default"
                    property string scroll: "default"
                }
            }

            property JsonObject performance: JsonObject {
                property bool lowPower: false
                property bool reduceAnimations: false
                // JSGCHeap watchdog (#164). Stats stay on `inir memory`;
                // the restart notification is opt-in.
                property bool memoryMonitoring: true
                property int jsgcThreshold: 300
                property bool memoryWarningNotification: false
                // Delegate shaped panel blur to Niri via ext-background-effect-v1.
                // The request is only activated on Niri; QML blur remains the fallback.
                property bool compositorBlur: true
                property string blurBackend: "auto" // auto | wallpaper | compositor | off
                property JsonObject blurAreas: JsonObject {
                    property string bar: "inherit"
                    property string dock: "inherit"
                    property string panels: "inherit"
                    property string islands: "inherit"
                    property string widgets: "inherit"
                }
            }

            property JsonObject powerProfiles: JsonObject {
                property bool restoreOnStart: true
                property string preferredProfile: "" // "power-saver" | "balanced" | "performance"
            }

            property JsonObject idle: JsonObject {
                property int screenOffTimeout: 300 // seconds, 0 = disabled
                property int lockTimeout: 600 // seconds, 0 = disabled
                property int suspendTimeout: 0 // seconds, 0 = disabled
                property bool lockBeforeSleep: true
                // Tighter timeouts applied only while running on battery.
                // Ignored on desktops (no battery present).
                property JsonObject onBattery: JsonObject {
                    property bool enable: false
                    property int screenOffTimeout: 120
                    property int lockTimeout: 300
                    property int suspendTimeout: 600
                }
            }

            property JsonObject modules: JsonObject {
                property bool altSwitcher: false
                property bool bar: true
                property bool background: true
                property bool cheatsheet: true
                property bool clipboard: true
                property bool crosshair: false
                property bool dock: true
                property bool lock: true
                property bool mediaControls: true
                property bool notificationPopup: true
                property bool onScreenDisplay: true
                property bool onScreenKeyboard: true
                property bool overview: true
                property bool overlay: true
                property bool polkit: true
                property bool regionSelector: true
                property bool reloadPopup: true
                property bool screenCorners: true
                property bool sessionScreen: true
                property bool sidebarLeft: true
                property bool sidebarRight: true
                property bool verticalBar: true
                property bool wallpaperSelector: true
            }

            property JsonObject gameMode: JsonObject {
                property bool autoDetect: true
                property bool disableAnimations: true
                property bool disableEffects: true
                property bool disableNiriAnimations: true
                property bool disableReloadToasts: true
                property bool disableDiscoverOverlay: true
                property bool suppressNotifications: true // Hide notification popups during GameMode
                property bool minimalMode: true // Make panels transparent/minimal during GameMode
                // Throttle Niri window list updates - 100ms = 10 FPS, sufficient for smooth UI
                // Lower values increase CPU usage with diminishing returns on perceived smoothness
                property int niriWindowListUpdateIntervalMs: 100
                property int niriWindowListUpdateIntervalMsGameMode: 500 // 2 FPS during gaming - minimal overhead
                property int checkInterval: 5000 // ms - fallback only, events are primary
            }

            property JsonObject reloadToasts: JsonObject {
                property bool enable: true
            }

            property JsonObject audio: JsonObject {
                // Values in %
                property JsonObject protection: JsonObject {
                    // Prevent sudden bangs
                    property bool enable: true
                    property real maxAllowedIncrease: 10
                    property real maxAllowed: 100
                }
            }

            property JsonObject compositor: JsonObject {
                property bool autoExpandSingleTilingWindow: false
            }

            property JsonObject apps: JsonObject {
                property string bluetooth: "kcmshell6 kcm_bluetooth"
                property string network: "kitty -1 fish -c nmtui"
                property string networkEthernet: "kcmshell6 kcm_networkmanagement"
                property string taskManager: "missioncenter"
                property string terminal: "kitty" // This is only for shell actions
                property string browser: "firefox" // Used by launcher-backed browser shortcuts
                property string volumeMixer: "pavucontrol"
                property string discord: "discord" // Shell command to launch Discord client
                property string update: "kitty -e sudo pacman -Syu" // Command to run system updates
                property string manageUser: "kcmshell6 kcm_users" // User account management
            }

            property JsonObject background: JsonObject {
                property JsonObject widgets: JsonObject {
                    // "panel" (stock per-style plate) | "island" (Ricelin card)
                    property string style: "panel"
                    property int dynamicOpacity: 0 // 0-100: reduce widget opacity when windows are on current workspace
                    // Opt-in local wallpaper sampling. Off keeps semantic widget
                    // colors stable when widgets move; on lets eligible widgets
                    // choose readable ink/semantic foregrounds from their region.
                    property bool adaptColorsToWallpaperPosition: false
                    property JsonObject powerSaving: JsonObject {
                        property bool enable: true
                        property bool pauseOnGameMode: true
                        property bool pauseOnFullscreen: true
                        property bool pauseWhenWindowsPresent: false
                        property bool showPausedEffect: true
                    }
                    property list<string> screenList: []
                    property list<var> outputOverrides: []
                    // Persistent bottom-to-top widget instance keys. Entries are
                    // output-qualified ("OUTPUT::configEntryName") so each screen
                    // keeps its own overlap order after edit mode closes/restarts.
                    property list<string> layerOrder: []
                    property JsonObject clock: JsonObject {
                        property bool enable: false
                        property bool locked: false
                        property string placementStrategy: "free" // "free", "leastBusy", "mostBusy"
                        property real x: 100
                        property real y: 100
                        property string style: "digital" // Options: "cookie", "digital"
                        property int dim: 70 // Extra dim for clock text (0-100)
                        property string fontFamily: "Space Grotesk"
                        property string timeFormat: "system" // "system", "24h", "12h"
                        property string dateStyle: "long" // "long", "minimal", "weekday", "numeric"
                        property bool showDate: true
                        property bool showSeconds: false
                        property bool showShadow: true
                        property int timeScale: 100
                        property int dateScale: 100
                        property int widgetScale: 100
                        property int widgetOpacity: 100
                        property bool showBackground: false
                        property bool useBlur: false
                        property bool showBorder: false
                        property real backgroundOpacity: 0
                        property real borderWidth: 0
                        property real borderOpacity: 0.08
                        property real cornerRadius: -1
                        property string colorMode: "auto"
                        property JsonObject palette: JsonObject {
                            property string primary: "primary"
                            property string secondary: "secondary"
                            property string tertiary: "tertiary"
                            property string signal: "signal"
                            property string surface: "surface"
                        }
                        property JsonObject cookie: JsonObject {
                            property bool aiStyling: false
                            property int sides: 15
                            property string dialNumberStyle: "full"   // Options: "dots" , "numbers", "full" , "none"
                            property string hourHandStyle: "hollow"   // Options: "classic", "fill", "hollow", "hide"
                            property string minuteHandStyle: "hide"   // Options "classic", "thin", "medium", "bold", "hide"
                            property string secondHandStyle: "hide"   // Options: "dot", "line", "classic", "hide"
                            property string dateStyle: "bubble"       // Options: "border", "rect", "bubble" , "hide"
                            property bool timeIndicators: false
                            property bool hourMarks: false
                            property bool dateInClock: true
                            property bool constantlyRotate: false
                            property bool useSineCookie: false
                            property int size: 230
                            property string preset: "default"
                        }
                        property JsonObject digital: JsonObject {
                            property bool adaptToWallpaper: true
                            property bool animateChange: true
                            property int fontWeight: 600
                            property int spacing: 6
                            property string preset: "default"
                        }
                        property JsonObject quote: JsonObject {
                            property bool enable: false
                            property string text: ""
                        }
                    }
                    property JsonObject weather: JsonObject {
                        property bool enable: false
                        property bool locked: false
                        property string placementStrategy: "free" // "free", "leastBusy", "mostBusy"
                        property real x: 100
                        property real y: 200
                        property int size: 200
                        property int tempSize: 80
                        property int iconSize: 80
                        property bool showTemp: true
                        property bool showIcon: true
                        property bool showCondition: false
                        property int padding: 20
                        property int tempFontWeight: 500 // Font.Medium
                        property real conditionOpacity: 0.7
                        property string preset: "default"
                        property string style: "pill" // "pill" (shape), "card" (adaptive overlay), "detail" (M3 tonal)
                        property bool showMetrics: true // "detail" style only
                        property string shape: "pill" // MaterialShape shape name
                        property int widgetScale: 100
                        property int widgetOpacity: 100
                        property bool showBackground: true
                        property bool useBlur: false
                        property bool showBorder: true
                        property real backgroundOpacity: 0.16
                        property real borderWidth: 1
                        property real borderOpacity: 0.20
                        property real cornerRadius: -1
                        property string colorMode: "auto"
                        property JsonObject palette: JsonObject {
                            property string primary: "primary"
                            property string secondary: "secondary"
                            property string tertiary: "tertiary"
                            property string signal: "signal"
                            property string surface: "surface"
                        }
                        property int dim: 0
                    }

                    property JsonObject customImage: JsonObject {
                        property bool enable: false
                        property bool locked: false
                        property string placementStrategy: "free"
                        property string sourceMode: "file" // "file" | "folder"
                        property string path: ""
                        property string folder: ""
                        property string mediaFilter: "all" // "all" | "images" | "gifs" | "videos"
                        property int intervalSeconds: 30
                        property string order: "sequential" // "sequential" | "random"
                        property int transitionDuration: 450
                        property string shape: "Cookie4Sided"
                        property string fitMode: "cover"
                        property int size: 220
                        property int dim: 0
                        property int widgetScale: 100
                        property int widgetOpacity: 100
                        property JsonObject palette: JsonObject {
                            property string primary: "primary"
                            property string secondary: "secondary"
                            property string tertiary: "tertiary"
                            property string signal: "signal"
                            property string surface: "surface"
                        }
                        property real x: 120
                        property real y: 320
                    }

                    property JsonObject imageConverter: JsonObject {
                        property bool enable: false
                        property bool locked: false
                        property string placementStrategy: "free"
                        property string selectedFormat: "webp"
                        property int contentWidth: 292
                        property int contentHeight: 260
                        property int widgetScale: 100
                        property int widgetOpacity: 100
                        property string colorMode: "auto"
                        property JsonObject palette: JsonObject {
                            property string primary: "primary"
                            property string secondary: "secondary"
                            property string tertiary: "tertiary"
                            property string signal: "signal"
                            property string surface: "surface"
                        }
                        property int dim: 0
                        property bool showBackground: true
                        property bool useBlur: false
                        property bool showBorder: true
                        property real backgroundOpacity: 0.22
                        property real borderWidth: 1
                        property real borderOpacity: 0.22
                        property real cornerRadius: -1
                        property real x: 120
                        property real y: 360
                    }

                    property JsonObject mediaControls: JsonObject {
                        property bool enable: false
                        property bool locked: false
                        property string placementStrategy: "free" // "free", "leastBusy", "mostBusy"
                        property string playerPreset: "full" // "full", "compact", "minimal", "albumart", "visualizer", "classic", "lyrics", "lyricsSplit", "expandingLyrics"
                        property string visualizerType: "wave" // "wave", "bars"
                        property string visualizerPosition: "bottom" // "bottom", "top", "fill", "none"
                        property bool lyricsExpanded: false
                        property real x: 240
                        property real y: 240
                        property int widgetScale: 100
                        property int widgetOpacity: 100
                        property string colorMode: "auto"
                        property JsonObject palette: JsonObject {
                            property string primary: "primary"
                            property string secondary: "secondary"
                            property string tertiary: "tertiary"
                            property string signal: "signal"
                            property string surface: "surface"
                        }
                        property int dim: 0
                    }

                    property JsonObject visualizer: JsonObject {
                        property bool enable: false
                        property bool locked: false
                        property string placementStrategy: "free"
                        property string vizType: "bars"
                        property string preset: "default" // legacy, kept for compat
                        property string paletteMode: "cava" // "cava", "accent", "primary"
                        property string barsOrigin: "bottom" // "bottom", "top", "center", "mirror"
                        property string waveMode: "fill" // "fill", "line", "ribbon"
                        property string frequencyProfile: "flat" // "flat", "bass", "warm", "vocal", "treble", "smile"
                        property int smoothing: 2
                        property int fillRatio: 90
                        property int barOpacity: 100
                        property int waveOpacity: -1 // -1 = use global (appearance.cava.waveOpacity)
                        property int barCount: 48
                        property int barSpacing: 2
                        property int barRadius: 2
                        property int barMinHeight: 1
                        property int lineWidth: 2
                        property int edgeInset: 0
                        property int edgeSoftness: 28
                        property int accentStrength: 70
                        property int contentWidth: 304
                        property int contentHeight: 104
                        property int dim: 0
                        property int widgetScale: 100
                        property int widgetOpacity: 100
                        property bool showBackground: true
                        property bool useBlur: false
                        property bool showBorder: true
                        property real backgroundOpacity: 0.16
                        property real borderWidth: 1
                        property real borderOpacity: 0.20
                        property real cornerRadius: -1
                        property string colorMode: "auto"
                        property JsonObject palette: JsonObject {
                            property string primary: "primary"
                            property string secondary: "secondary"
                            property string tertiary: "tertiary"
                            property string signal: "signal"
                            property string surface: "surface"
                        }
                        property real x: 100
                        property real y: 100
                    }

                    property JsonObject systemMonitor: JsonObject {
                        property bool enable: false
                        property bool locked: false
                        property string placementStrategy: "free"
                        property string displayMode: "bars" // "bars", "graph", "rings", "text", "tiles"
                        property int barCount: 32
                        property int barSpacing: 2
                        property real trackAlpha: 0.08
                        property real fillOpacity: 0.7
                        property real graphFillOpacity: 0.3
                        property bool showCpu: true
                        property bool showMemory: true
                        property bool showGpu: true
                        property bool showTemp: false
                        property bool showDisk: false
                        property bool showLabels: true
                        property int contentWidth: 320
                        property int contentHeight: 120
                        property string preset: "default"
                        property int dim: 0
                        property int widgetScale: 100
                        property int widgetOpacity: 100
                        property bool showBackground: true
                        property bool useBlur: false
                        property bool showBorder: true
                        property real backgroundOpacity: 0.16
                        property real borderWidth: 1
                        property real borderOpacity: 0.20
                        property real cornerRadius: -1
                        property string colorMode: "auto"
                        property JsonObject palette: JsonObject {
                            property string primary: "primary"
                            property string secondary: "secondary"
                            property string tertiary: "tertiary"
                            property string signal: "signal"
                            property string surface: "surface"
                        }
                        property real x: 50
                        property real y: 400
                    }

                    property JsonObject battery: JsonObject {
                        property bool enable: false
                        property bool locked: false
                        property string placementStrategy: "free"
                        property string displayMode: "ring"
                        property bool showTime: true
                        property int ringSize: 72
                        property int ringLineWidth: 6
                        property int barCount: 20
                        property int barSpacing: 2
                        property int barRadius: 2
                        property int pillHeight: 12
                        property string preset: "default"
                        property int dim: 0
                        property int widgetScale: 100
                        property int widgetOpacity: 100
                        property bool showBackground: true
                        property bool useBlur: false
                        property bool showBorder: true
                        property real backgroundOpacity: 0.16
                        property real borderWidth: 1
                        property real borderOpacity: 0.20
                        property real cornerRadius: -1
                        property string colorMode: "auto"
                        property JsonObject palette: JsonObject {
                            property string primary: "primary"
                            property string secondary: "secondary"
                            property string tertiary: "tertiary"
                            property string signal: "signal"
                            property string surface: "surface"
                        }
                        property real x: 50
                        property real y: 50
                    }

                    property JsonObject notes: JsonObject {
                        property bool enable: false
                        property bool locked: false
                        property string placementStrategy: "free"
                        property string text: ""
                        property int fontSize: 14
                        property string fontFamily: "sans"
                        property string textAlign: "left"
                        property int contentWidth: 240
                        property int contentHeight: 160
                        property int dim: 0
                        property int widgetScale: 100
                        property int widgetOpacity: 100
                        property bool showBackground: true
                        property bool useBlur: false
                        property bool showBorder: true
                        property real backgroundOpacity: 0.10
                        property real borderWidth: 1
                        property real borderOpacity: 0.12
                        property real cornerRadius: -1
                        property string colorMode: "auto"
                        property JsonObject palette: JsonObject {
                            property string primary: "primary"
                            property string secondary: "secondary"
                            property string tertiary: "tertiary"
                            property string signal: "signal"
                            property string surface: "surface"
                        }
                        property real x: 80
                        property real y: 80
                    }

                    property JsonObject japaneseTypography: JsonObject {
                        property bool enable: false
                        property bool locked: false
                        property string placementStrategy: "free"
                        property string preset: "exhibition"
                        property string primaryText: "夏の記憶"
                        property string secondaryText: "潮風と、あの子と、終わらない夏"
                        property string sealText: "特別展"
                        property string footerText: "PACIFIC DRIVE-IN"
                        property string dateText: "7.12 — 8.31"
                        property bool showSecondary: true
                        property bool showSeal: true
                        property bool showFooter: true
                        property bool showRule: true
                        property string fontPreset: "mincho"
                        property string fontFamily: "serif"
                        property string secondaryFontFamily: ""
                        property string latinFontFamily: ""
                        property int primaryWeight: 500
                        property int secondaryWeight: 400
                        property int latinWeight: 600
                        property int primarySize: 72
                        property int secondarySize: 18
                        property int footerSize: 14
                        property int dateSize: 12
                        property int primaryColumns: 2
                        property int secondaryColumns: 2
                        property int columnGap: 14
                        property int letterSpacing: 2
                        property int secondaryLetterSpacing: 1
                        property bool mirrorLayout: false
                        property bool rotateLatin: false
                        property string paletteMode: "adaptive"
                        property string palettePreset: "adaptive"
                        property string primaryColor: "#E7D4B2"
                        property string secondaryColor: "#CDB48D"
                        property string sealColor: "#A64B39"
                        property string detailColor: "#D0B996"
                        property string ruleColor: "#C18A53"
                        property int primaryOpacity: 100
                        property int secondaryOpacity: 78
                        property int sealOpacity: 100
                        property int detailOpacity: 72
                        property int ruleOpacity: 78
                        property real sealFillOpacity: 0
                        property int ruleThickness: 1
                        property string outlineColor: "#000000"
                        property int outlineOpacity: 0
                        property int shadowStrength: 35
                        property int contentWidth: 330
                        property int contentHeight: 600
                        property int dim: 10
                        property int widgetScale: 100
                        property int widgetOpacity: 100
                        property bool showBackground: false
                        property bool useBlur: false
                        property bool showBorder: false
                        property real backgroundOpacity: 0
                        property real borderWidth: 0
                        property real borderOpacity: 0.12
                        property real cornerRadius: -1
                        property string colorMode: "auto"
                        property JsonObject palette: JsonObject {
                            property string primary: "primary"
                            property string secondary: "secondary"
                            property string tertiary: "tertiary"
                            property string signal: "signal"
                            property string surface: "surface"
                        }
                        property real x: 56
                        property real y: 120
                    }

                    property JsonObject calendarUpcoming: JsonObject {
                        property bool enable: false
                        property bool locked: false
                        property string placementStrategy: "free"
                        property int maxEvents: 5
                        property bool showDate: true
                        property bool showTime: true
                        property bool showLocation: false
                        property bool groupByDay: true
                        property int contentWidth: 280
                        property int contentHeight: 220
                        property int dim: 0
                        property int widgetScale: 100
                        property int widgetOpacity: 100
                        property bool showBackground: true
                        property bool useBlur: false
                        property bool showBorder: true
                        property real backgroundOpacity: 0.10
                        property real borderWidth: 1
                        property real borderOpacity: 0.12
                        property real cornerRadius: -1
                        property string colorMode: "auto"
                        property JsonObject palette: JsonObject {
                            property string primary: "primary"
                            property string secondary: "secondary"
                            property string tertiary: "tertiary"
                            property string signal: "signal"
                            property string surface: "surface"
                        }
                        property real x: 80
                        property real y: 80
                    }

                    property JsonObject uptime: JsonObject {
                        property bool enable: false
                        property bool locked: false
                        property string placementStrategy: "free"
                        property int contentWidth: 250
                        property int contentHeight: 96
                        property int widgetScale: 100
                        property int widgetOpacity: 100
                        property bool showBackground: true
                        property bool useBlur: false
                        property bool showBorder: true
                        property real backgroundOpacity: 0.16
                        property real borderWidth: 1
                        property real borderOpacity: 0.20
                        property real cornerRadius: -1
                        property string colorMode: "auto"
                        property JsonObject palette: JsonObject {
                            property string primary: "primary"
                            property string secondary: "secondary"
                            property string tertiary: "tertiary"
                            property string signal: "signal"
                            property string surface: "surface"
                        }
                        property int dim: 0
                        property real x: 80
                        property real y: 80
                    }

                    property JsonObject worldClock: JsonObject {
                        property bool enable: false
                        property bool locked: false
                        property string placementStrategy: "free"
                        property int contentWidth: 300
                        property int contentHeight: 210
                        property int widgetScale: 100
                        property int widgetOpacity: 100
                        property bool showBackground: true
                        property bool useBlur: false
                        property bool showBorder: true
                        property real backgroundOpacity: 0.16
                        property real borderWidth: 1
                        property real borderOpacity: 0.20
                        property real cornerRadius: -1
                        property string colorMode: "auto"
                        property JsonObject palette: JsonObject {
                            property string primary: "primary"
                            property string secondary: "secondary"
                            property string tertiary: "tertiary"
                            property string signal: "signal"
                            property string surface: "surface"
                        }
                        property int dim: 0
                        property real x: 80
                        property real y: 200
                        property list<string> timezones: ["Australia/Sydney", "Asia/Tokyo", "Europe/London", "America/New_York"]
                    }

                    property JsonObject userCard: JsonObject {
                        property bool enable: false
                        property bool locked: false
                        property string placementStrategy: "free"
                        property int contentWidth: 280
                        property int contentHeight: 176
                        property int widgetScale: 100
                        property int widgetOpacity: 100
                        property bool showBackground: true
                        property bool useBlur: false
                        property bool showBorder: true
                        property real backgroundOpacity: 0.16
                        property real borderWidth: 1
                        property real borderOpacity: 0.20
                        property real cornerRadius: -1
                        property string colorMode: "auto"
                        property JsonObject palette: JsonObject {
                            property string primary: "primary"
                            property string secondary: "secondary"
                            property string tertiary: "tertiary"
                            property string signal: "signal"
                            property string surface: "surface"
                        }
                        property int dim: 0
                        property real x: 80
                        property real y: 420
                    }

                    property JsonObject mascot: JsonObject {
                        property bool enable: false
                        property bool locked: false
                        property string placementStrategy: "free"
                        property int contentWidth: 200
                        property int widgetScale: 100
                        property int widgetOpacity: 100
                        property bool showBackground: false
                        property bool useBlur: false
                        property bool showBorder: false
                        property real backgroundOpacity: 0.16
                        property real borderWidth: 1
                        property real borderOpacity: 0.20
                        property real cornerRadius: -1
                        property string colorMode: "auto"
                        property JsonObject palette: JsonObject {
                            property string primary: "primary"
                            property string secondary: "secondary"
                            property string tertiary: "tertiary"
                            property string signal: "signal"
                            property string surface: "surface"
                        }
                        property int dim: 0
                        property string pose: "reading"
                        property string poseFilter: "all" // all | featured | pixel | street | chibi | loops | manual
                        property string posePickerMode: "buttons" // desktop quick controls: buttons | gallery
                        property string customPath: "" // any user image/GIF replaces the catalog pose
                        property string anchorWidget: "" // configEntryName of another widget she perches on top of; "" = free
                        property real x: 120
                        property real y: 320
                    }

                    property JsonObject newsTicker: JsonObject {
                        property bool enable: false
                        property bool locked: false
                        property string placementStrategy: "free"
                        property int contentWidth: 320
                        property int contentHeight: 92
                        property int widgetScale: 100
                        property int widgetOpacity: 100
                        property bool showBackground: true
                        property bool useBlur: false
                        property bool showBorder: true
                        property real backgroundOpacity: 0.16
                        property real borderWidth: 1
                        property real borderOpacity: 0.20
                        property real cornerRadius: -1
                        property string colorMode: "auto"
                        property JsonObject palette: JsonObject {
                            property string primary: "primary"
                            property string secondary: "secondary"
                            property string tertiary: "tertiary"
                            property string signal: "signal"
                            property string surface: "surface"
                        }
                        property int dim: 0
                        property real x: 100
                        property real y: 260
                    }

                    property JsonObject editGrid: JsonObject {
                        property int size: 32
                        property bool snap: true
                    }

                    // Custom widget data lives in root.customWidgetData (not here)
                    // to avoid JsonAdapter crash on property var inside JsonObject.
                }
                property string wallpaperPath: ""
                property string thumbnailPath: ""
                property string fillMode: "fill" // "fill", "fit", "center", "tile"
                property bool enableAnimation: true // Enable animated wallpapers (video/gif). When disabled, shows thumbnail instead (better performance)
                property bool pauseAnimationOnBattery: true // Freeze video/gif wallpapers while on battery power (all surfaces, both families)
                property bool hideWhenFullscreen: true
                property JsonObject effects: JsonObject {
                    property bool enableBlur: false
                    property int blurRadius: 32
                    property int thumbnailBlurStrength: 50
                    property bool enableAnimatedBlur: false // Enable blur for animated wallpapers (video/gif) - has performance impact
                    property int dim: 0 // 0-100 percentage (base overlay)
                    property int dynamicDim: 0 // Extra dim when there are windows on the current workspace (0-100)
                    property JsonObject ripple: JsonObject {
                        property bool enable: false
                        property bool charging: true
                        property bool overview: true
                        property bool reload: true
                        property bool lock: true
                        property bool session: true
                        property bool hotcorners: true
                        property int rippleDuration: 3000
                        property real sparkleIntensity: 1.0 // 0.0 = no sparkles, 2.0 = intense
                        property real glowIntensity: 1.0    // 0.0 = no glow, 2.0 = strong
                        property real ringWidth: 0.15       // 0.05 = thin ring, 0.5 = wide ring
                    }
                }
                property JsonObject backdrop: JsonObject {
                    property bool enable: true
                    property bool hideWallpaper: false
                    property bool useMainWallpaper: true
                    property string wallpaperPath: ""
                    property string thumbnailPath: "" // Thumbnail for animated wallpapers (video/gif)
                    property bool enableAnimation: false // Enable animated wallpapers (video/gif) in backdrop (disabled by default for performance)
                    property bool enableAnimatedBlur: false // Enable blur for animated wallpapers (video/gif) - has performance impact
                    property int blurRadius: 32
                    property int dim: 35
                    property real saturation: 0
                    property real contrast: 0
                    property bool vignetteEnabled: false
                    property real vignetteIntensity: 0.5
                    property real vignetteRadius: 0.7
                    property bool useAuroraStyle: false
                    property real auroraOverlayOpacity: 0.38
                }
                property JsonObject parallax: JsonObject {
                    property bool enable: false
                    property string axis: "vertical"
                    property bool vertical: false
                    property bool autoVertical: false
                    property bool enableWorkspace: true
                    property real workspaceShift: 1.0
                    property real workspaceZoom: 1.0 // Relative to wallpaper size, with headroom applied internally
                    property real zoom: 1.0
                    property bool enableSidebar: true
                    property real panelShift: 0.15
                    property real widgetsFactor: 1.2
                    property real widgetDepth: 1.2
                    property bool pauseDuringTransitions: true
                    property int transitionSettleMs: 220
                }
                property JsonObject multiMonitor: JsonObject {
                    property bool enable: false
                }
                property list<var> wallpapersByMonitor: []
                property JsonObject autoWallpaper: JsonObject {
                    property bool enable: false
                    property int intervalMinutes: 30 // minutes between wallpaper changes
                    property bool generateColors: true // regenerate theme colors on each change
                    property string folder: "" // empty = use current wallpaper folder
                }
                property JsonObject pan: JsonObject {
                    property real x: 0.0 // Focal point offset X (-1.0 to 1.0, stored as fraction; -1 = full left, +1 = full right)
                    property real y: 0.0 // Focal point offset Y (-1.0 to 1.0; -1 = top, +1 = bottom)
                    property real zoom: 1.0 // Extra zoom on top of fill-crop (1.0 = standard fill, 2.0 = 2× zoom, max 3.0)
                }
                property JsonObject backend: JsonObject {
                    property string provider: "awww"
                    property JsonObject awww: JsonObject {
                        property int transitionFps: 60
                        property int simpleStep: 5
                        property int spatialStep: 30
                    }
                }
                property JsonObject transition: JsonObject {
                    property bool enable: true
                    property string type: "crossfade" // "crossfade" | "slide" | "zoom" | "blurFade"
                    property string direction: "right"
                    property int duration: 800 // ms
                    property list<var> bezier: [0.54, 0.0, 0.34, 0.99]
                }
                property bool hideUpscaleNotification: false
            }

            property JsonObject bar: JsonObject {
                // Options for bar.appearanceStyle === "pill": the morphing centre
                // island that replaces the bar and grows on hover.
                property JsonObject pill: JsonObject {
                    property bool barMode: false // Rest expanded: the hover row stays out as a persistent bar
                    property real scale: 1 // UI scale multiplier on top of the screen-height ratio
                    property real opacity: 1 // Pill body fill opacity
                    property real topGap: 1 // Distance from the top edge, in 8px units
                    property real appGap: 1 // How much reserved band the pill keeps below itself
                    property bool showGlyphs: true // 時 kanji instead of a clock icon at rest
                    property bool clockSeconds: false
                    property bool time12h: false
                    property bool musicViz: true // Draw live spectrum wings outside the pill
                    property bool toasts: true // Notification toasts take over the resting pill
                    property bool osd: true // Volume/brightness/mic/workspace changes flash on the pill
                    property bool compactAnnounces: false // Keep toast/OSD faces at the resting pill size
                    property real rowSpacing: 20 // Air between the hover row's groups (workspaces | clock | status), px
                    property real iconSpacing: 12 // Air between the status icons, px
                    property real iconSize: 17 // Icon size of the pill's furniture, px
                    // The soul bead that glides between hover targets.
                    property JsonObject soul: JsonObject {
                        property bool enable: true
                        property real size: 1 // Bead size multiplier
                        property string style: "orb" // "orb" (living swirl) | "ember" (plain dot) | "ring" (hollow outline)
                    }
                    // Per-surface glyph overrides; empty string = stock kanji.
                    property JsonObject glyphs: JsonObject {
                        property string clock: ""
                        property string media: ""
                        property string mediaPaused: ""
                        property string link: ""
                        property string notify: ""
                        property string clear: ""
                        property string dnd: ""
                        property string sysmon: ""
                        property string glance: ""
                        property string clipboard: ""
                        property string clipboardSearch: ""
                        property string recorder: ""
                        property string power: ""
                        property string battery: ""
                        property string calendar: ""
                        property string mixer: ""
                        property string launcher: ""
                        property string workspaces: ""
                    }
                    // Hover-row furniture: every module in the expanded row can be
                    // switched off (surface-bound icons follow surfaces.* instead).
                    property JsonObject modules: JsonObject {
                        property bool workspaces: true
                        property bool weather: true
                        property bool tray: true
                        property bool wifi: true
                        property bool battery: true
                        property bool inbox: true
                        property bool mixer: true
                        property bool sidebars: true // The two shortcuts into iNiR's own sidebars
                        property bool power: true
                    }
                    // Optional hover-row surfaces; the stock ones are always available.
                    property JsonObject surfaces: JsonObject {
                        property bool sysmon: true // 系 SYSTEM vitals surface + its monitor icon
                        property bool clipboard: true // 控 clipboard history surface + its icon
                        property bool glance: true // 今 TODAY surface (weather + agenda + tasks) + its icon
                        property bool launcher: true // 探 app launcher surface + its icon
                        property bool recorder: false // 録 screen recorder surface + its icon (surface stays reachable over IPC)
                    }
                }

                // Options for bar.appearanceStyle === "islands": floating Ricelin
                // capsules per bar section.
                property JsonObject islands: JsonObject {
                    property int inset: 4 // Vertical breathing room around each island, px
                    property int padding: 12 // Horizontal capsule padding around edge-section content, px
                }

                // Options for the separate M3 implementation under modules/barM3/. It
                // keeps its own layout/appearance contract instead of reusing
                // bar.layout/bar.modules/bar.borderless, because its grouping
                // model (three flat layouts of widget names, string grouping
                // style, per-position pill radii) is incompatible with iNiR's
                // five-zone registry. Nothing here changes any other bar.
                property JsonObject m3: JsonObject {
                    // 0: Hug | 1: Float | 2: Plain rectangle | 3: Material 3
                    property int cornerStyle: 3
                    // "pills" (adjacent groups join into one continuous shape)
                    // | "separated" (every group is its own capsule)
                    // | "transparent" (no group surface at all)
                    property string borderless: "separated"
                    property bool showBackground: true
                    property bool verbose: true
                    property JsonObject clock: JsonObject {
                        property string timeFontFamily: ""
                        property int timePixelSize: 0
                        property string dateFontFamily: ""
                        property int datePixelSize: 0
                    }
                    property int gapsOut: 5 // Outer gap the float/M3 styles detach by
                    // Widget names resolve to modules/barM3/<Name>.qml. Available:
                    // media, workspaces, activeWindow, leftSidebarButton, docktoPanel,
                    // visualizer, divisor, resources, sysTray, systemIcons, utilButtons,
                    // networkSpeed, updatesCount, batteryIndicator, weatherBar,
                    // clockWidget, notificationUnreadCount, powerButton.
                    // The showcase uses a mirrored visualizer around the in-bar dock.
                    // The active layout is kept separate from the user's custom
                    // layout. Presets may replace the active lists, but must never
                    // destroy the last custom arrangement.
                    property string layoutMode: "auto" // "auto" | "compact" | "showcase" | "information" | "custom"
                    property bool customLayoutSaved: false
                    property JsonObject layouts: JsonObject {
                        property list<string> leftLayout: ["media", "workspaces"]
                        property list<string> middleLayout: ["visualizer", "docktoPanel", "visualizer"]
                        property list<string> rightLayout: ["utilButtons", "systemIcons", "weatherBar", "clockWidget"]
                    }
                    property JsonObject customLayouts: JsonObject {
                        property list<string> leftLayout: []
                        property list<string> middleLayout: []
                        property list<string> rightLayout: []
                    }
                    property JsonObject divider: JsonObject {
                        property string style: "rect" // "rect" | "dot" | "space"
                        property int spacing: 20
                    }
                    property JsonObject tooltips: JsonObject {
                        property bool clickToShow: false
                    }
                    property JsonObject indicators: JsonObject {
                        property JsonObject notifications: JsonObject {
                            property bool showUnreadCount: false
                        }
                    }
                    property JsonObject media: JsonObject {
                        property string preferredPlayer: ""
                        property bool alwaysVisible: false
                        property bool onlyTitle: false
                        property int maxWidth: 280
                        property int minWidth: 100
                    }
                    property JsonObject resources: JsonObject {
                        property string style: "filled"
                        property bool showValue: false
                        property bool alwaysShowSwap: false
                        property bool alwaysShowCpu: true
                        property bool alwaysShowCpuTemp: false
                        property bool alwaysShowDisk: false
                        property bool alwaysShowRam: true
                        property int memoryWarningThreshold: 95
                        property int swapWarningThreshold: 85
                        property int cpuWarningThreshold: 90
                    }
                    property JsonObject tray: JsonObject {
                        // M3 tray icons follow the semantic pill foreground by default.
                        // Users can opt out to keep each application's original colors.
                        property bool monochromeIcons: true
                    }
                    property JsonObject workspaces: JsonObject {
                        property bool monochromeIcons: true
                        property bool showAppIcons: true
                        property string indicatorStyle: "dot" // "dot" | "icon"
                        property bool alwaysShowNumbers: false
                        property list<string> numberMap: ["1", "2"]
                        property bool useNerdFont: false
                    }
                    property JsonObject utilButtons: JsonObject {
                        property bool showScreenSnip: true
                        property bool showColorPicker: false
                        property bool showMicToggle: false
                        property bool showKeyboardToggle: true
                        property bool showWallpaperToggle: false
                        property bool showDarkModeToggle: true
                        property bool showPerformanceProfileToggle: false
                        property bool showScreenRecord: false
                    }
                    // The dock rendered inside the bar.
                    // iconSize/buttonSize at 0 scale with the bar height; set a
                    // px value to pin them regardless of how tall the bar is.
                    property JsonObject dockToPanel: JsonObject {
                        property real iconSize: 0
                        property real buttonSize: 0
                        property real buttonSpacing: 2
                    }
                }

                property JsonObject activeWindow: JsonObject {
                    property bool showTitle: true // Show window title under the app name in the bar's active window indicator
                }
                property JsonObject autoHide: JsonObject {
                    property bool enable: false
                    property int hoverRegionWidth: 2
                    property bool pushWindows: false
                    property JsonObject showWhenPressingSuper: JsonObject {
                        property bool enable: true
                        property int delay: 140
                    }
                }
                property bool bottom: false // Instead of top
                property int height: 40 // Bar content height in px (pre-scale). 0 keeps the theme default (40). Range: 24–80.
                property real opacity: 1.0 // Background opacity (0–1). Lets you make the bar translucent without changing global style.
                property int cornerStyle: 1 // 0: Hug | 1: Float | 2: Plain rectangle
                property string appearanceStyle: "classic" // "classic" | "islands" (separate floating groups) | "scenic" (gradient scrim) | "frame" (outlined floating frame) | "m3" (no bar surface; each section is a colLayer0 capsule and each module wears a Material 3 tonal container) | "pill" (morphing centre island, see bar.pill). Horizontal bar only.
                property int customRounding: -1 // -1: use global theme rounding | 0+: override bar rounding (px)
                property bool floatStyleShadow: true // Show shadow behind bar when cornerStyle == 1 (Float)
                property bool borderless: true // true for no grouping of items
                property string topLeftIcon: "distro" // Options: "distro" or any icon name in ~/.config/quickshell/inir/assets/icons
                property bool showBackground: true
                property bool showScrollHints: true // Show brightness/volume scroll hints on hover
                property string leftScrollAction: "brightness" // "brightness", "volume", "workspace", "none"
                property string rightScrollAction: "volume" // "brightness", "volume", "workspace", "none"
                property JsonObject blurBackground: JsonObject {
                    property bool enabled: false
                    property real overlayOpacity: 0.3
                }
                // Audio spectrum painted into the bar surface. Only runs while
                // something is actually playing.
                property JsonObject visualizer: JsonObject {
                    property bool enable: false
                    property string multiMonitorMode: "primary" // "primary" | "all"
                    property string type: "bars" // "bars" | "wave"
                    property real height: 0.6 // Share of the bar height the spectrum may fill (0.1–1)
                    property real opacity: 0.35 // Spectrum opacity over the bar surface (0–1)
                    property string barsOrigin: "bottom" // "bottom" | "top" | "center" | "mirror"
                    property int density: 12 // Horizontal pixels allocated to each rendered bar
                    property int gap: 2 // Gap between rendered bars, px
                    property int smoothing: 2 // Frequency smoothing radius
                    property string waveMode: "fill" // "fill" | "line" | "ribbon"
                    property real lineWidth: 2 // Wave edge width, px
                    property int edgeInset: 0 // Horizontal inset from each surface edge, px
                    property int edgeSoftness: 28 // Curvature-aware peak headroom, 0-100
                    property string frequencyProfile: "flat" // "flat" | "bass" | "warm" | "vocal" | "treble" | "smile"
                    property int accentStrength: 70 // Frequency profile strength, 0-100
                    property string pillWingMode: "bounded" // "bounded" | "screen" | "bleed"
                    property int pillWingLength: 180 // Spectrum length on each side of the pill, px
                    property int pillWingGap: 12 // Air between the pill and each spectrum wing, px
                    property int pillScreenPadding: 24 // Air between screen edges and screen-spanning wings, px
                    property int pillUnderlap: 28 // Spectrum overlap behind the pill in bleed mode, px
                    property int pillEdgeFade: 92 // Fade toward screen edges, 0-100
                }
                property bool verbose: true
                property bool vertical: false
                property JsonObject clock: JsonObject {
                    property string timeFontFamily: ""
                    property int timePixelSize: 0
                    property string dateFontFamily: ""
                    property int datePixelSize: 0
                }
                property JsonObject vignette: JsonObject {
                    property bool enabled: false
                    property real intensity: 0.6
                    property real radius: 0.5
                }
                property JsonObject modules: JsonObject {
                    property bool leftSidebarButton: true
                    property bool activeWindow: true
                    property bool resources: false
                    property bool media: true
                    property bool workspaces: true
                    property bool clock: true
                    property bool utilButtons: false
                    property bool battery: true
                    property bool rightSidebarButton: true
                    property bool sysTray: true
                    property bool weather: true
                    property bool taskbar: false
                }
                property JsonObject modulesPlacement: JsonObject {
                    property string resources: "start"
                    property string media: "start"
                    property string workspaces: "center"
                    property string clock: "end"
                    property string utilButtons: "end"
                    property string battery: "end"
                }
                // Deprecated: kept so old config.json loads without error until
                // migration 028 removes them. Not consumed by the bar.
                property JsonObject modulesLayout: JsonObject {
                    property list<string> order: ["resources", "media", "workspaces", "clock", "utilButtons", "battery"]
                }
                property JsonObject edgeModulesLayout: JsonObject {
                    property list<string> leftOrder: ["leftSidebarButton", "activeWindow"]
                    property list<string> rightOrder: ["rightSidebarButton", "sysTray", "weather"]
                }
                // Modular bar layout — widget ids per structural zone.
                // Zones map 1:1 to the bar's real sections so workspaces stays
                // screen-centered and pill surfaces / scroll areas are preserved:
                //   left        → left edge section (scroll=brightness, click=left sidebar)
                //   centerLeft  → left central pill group
                //   center      → the centered pivot group (normally workspaces)
                //   centerRight → right central pill group (scroll, triple-tap fx)
                //   right       → right edge section (click=right sidebar)
                // Known ids: leftSidebarButton, activeWindow, taskbar, resources,
                //   media, workspaces, clock, utilButtons, battery, weather, tray,
                //   rightSidebarButton.
                property JsonObject layout: JsonObject {
                    property list<string> left: ["leftSidebarButton", "activeWindow"]
                    property list<string> centerLeft: ["resources", "media"]
                    property list<string> center: ["workspaces"]
                    property list<string> centerRight: ["clock", "utilButtons", "battery"]
                    property list<string> right: ["rightSidebarButton", "tray", "timer", "shellUpdate", "spacer", "weather"]
                    property int spacerWidth: 0 // Minimum width for each flexible spacer, in px. 0 keeps it pure flex.
                    property string spacerMode: "auto" // "auto": elastic in edge zones, fixed gap in centre pills; "fill": always elastic; "fixed": always spacerWidth
                    // Set true once the old fixed layout has been translated into
                    // the arrays above (handled by a migration). Until then the
                    // bar falls back to its classic hardcoded layout so existing
                    // users are never affected.
                    property bool migrated: false
                }
                property JsonObject resources: JsonObject {
                    property bool showMemoryIndicator: true
                    property bool showSwapIndicator: true
                    property bool showTempIndicator: true
                    property bool showCpuIndicator: true
                    property bool showGpuIndicator: true
                    property bool alwaysShowSwap: true
                    property bool alwaysShowTemp: true
                    property bool alwaysShowCpu: true
                    property bool alwaysShowGpu: true
                    property int tempCautionThreshold: 65
                    property int tempWarningThreshold: 80
                    property int memoryWarningThreshold: 95
                    property int swapWarningThreshold: 85
                    property int cpuWarningThreshold: 90
                    property int gpuWarningThreshold: 90
                }
                property list<string> screenList: [] // List of names, like "eDP-1", find out with 'hyprctl monitors' command
                property JsonObject utilButtons: JsonObject {
                    property bool showScreenSnip: true
                    property bool showScreenRecord: true
                    property bool showColorPicker: false
                    property bool showMicToggle: false
                    property bool showKeyboardToggle: true
                    property bool showKeyboardLayoutSwitch: false
                    property bool showDarkModeToggle: true
                    property bool showPerformanceProfileToggle: false
                    property bool showScreenCast: false
                    property string screenCastOutput: "HDMI-A-1"
                    property bool showNotepad: true
                }
                property JsonObject tray: JsonObject {
                    property bool monochromeIcons: true
                    property bool showItemId: false
                    property bool invertPinnedItems: true // Makes the below a whitelist for the tray and blacklist for the pinned area
                    property list<string> pinnedItems: []
                    property bool filterPassive: true
                }
                property JsonObject workspaces: JsonObject {
                    property string scrollBehavior: "workspace" // "workspace" or "column"
                    property bool invertScroll: false // Invert scroll direction
                    property bool monochromeIcons: true
                    property bool dynamicCount: true // Auto-detect workspace count (Niri)
                    property int shown: 10 // Only used when dynamicCount is false
                    property bool wrapAround: true // Cycle from last to first and vice versa
                    property int scrollSteps: 3 // Wheel steps required to switch
                    property bool showAppIcons: true
                    property bool alwaysShowNumbers: false
                    property int showNumberDelay: 300 // milliseconds
                    property list<string> numberMap: ["1", "2"] // Characters to show instead of numbers on workspace indicator
                    property bool useNerdFont: false
                    property bool perMonitor: true // Each bar shows workspaces for its own monitor (Niri)
                    property bool automaticIndicatorColor: true // Derive active workspace indicator color from the current theme
                    property string indicatorColor: "" // Manual active workspace indicator color when automaticIndicatorColor is false
                }
                property JsonObject weather: JsonObject {
                    property bool enable: true
                    property bool useUSCS: false // Instead of metric (SI) units
                    property int fetchInterval: 10 // minutes
                    property string city: "" // Manual city name (e.g. "Buenos Aires"). Empty = auto-detect
                    property bool enableGPS: false // Use geoclue GPS if available
                    property real manualLat: 0 // Manual latitude (e.g. -34.6037)
                    property real manualLon: 0 // Manual longitude (e.g. -58.3816)
                }
                property JsonObject indicators: JsonObject {
                    property JsonObject notifications: JsonObject {
                        property bool showUnreadCount: false
                    }
                }
            }

            property JsonObject battery: JsonObject {
                property int low: 20
                property int critical: 5
                property int full: 101
                property bool automaticSuspend: true
                property int suspend: 3
                property bool notifyFull: true
                property JsonObject chargeLimit: JsonObject {
                    property bool enable: false
                    property int threshold: 80
                }
            }

            // External calendar integration (ICS/iCal URL sync)
            property JsonObject calendar: JsonObject {
                property JsonObject externalSync: JsonObject {
                    property bool enable: false
                    property int refreshMinutes: 15
                    // Array of calendar sources: { id, name, url, color, enabled }
                    property list<var> sources: []
                }
                // Show upcoming events below calendar grid
                property bool showUpcoming: true
                // Number of days to show in upcoming view
                property int upcomingDays: 3
            }

            property JsonObject closeConfirm: JsonObject {
                property bool enabled: false
            }

            property JsonObject conflictKiller: JsonObject {
                property bool autoKillNotificationDaemons: false
                property bool autoKillTrays: false
            }

            property JsonObject crosshair: JsonObject {
                // Valorant crosshair format. Use https://www.vcrdb.net/builder
                property string code: "0;P;d;1;0l;10;0o;2;1b;0"
            }

            property JsonObject display: JsonObject {
                property string primaryMonitor: ""
            }

            property JsonObject dock: JsonObject {
                property string style: "panel" // "panel" | "pill" | "macos" | "island" | "m3"
                property bool cardStyle: false
                property bool enable: true
                property bool monochromeIcons: true
                property string position: "bottom" // "top", "bottom", "left", "right"
                property real height: 60
                property real iconSize: 35
                property real hoverRegionHeight: 2
                property bool pinnedOnStartup: true
                property bool hoverToReveal: false // When false, only reveals on empty workspace
                property bool showOnDesktop: true // Show dock when no window is focused (desktop visible)
                property bool showBackground: true
                property bool minimizeUnfocused: false // Show dot for unfocused apps
                property bool enableBlurGlass: true
                property bool separatePinnedFromRunning: true // Waffle-style: pinned-only apps on left, running on right
                property bool notificationBadge: true // Count of pending notifications on the app icon
                property list<string> pinnedApps: [ // IDs of pinned entries
                    "org.gnome.Nautilus", "firefox", "kitty",]
                property list<string> ignoredAppRegexes: []
                property list<string> screenList: [] // List of screen names to show dock on (e.g. ["DP-2"]). Empty = all screens
                // Smart indicator settings
                property bool smartIndicator: true // Show which window is focused
                property bool showAllWindowDots: true // Show dots for all windows (even inactive apps)
                property int maxIndicatorDots: 5 // Maximum dots to show
                // Window preview on hover
                property bool hoverPreview: true // Show window preview popup on hover
                property int hoverPreviewDelay: 400 // Delay before showing preview (ms)
                property bool keepPreviewOnClick: false // Keep preview open when clicking a window thumbnail
                // Drag & drop reordering
                property bool enableDragReorder: true // Allow drag to reorder pinned apps
            }

            property JsonObject controlPanel: JsonObject {
                // "panel" (stock per-style card) | "island" (Ricelin card)
                property string style: "panel"
                property bool keepLoaded: false
                property bool compactMode: true
                property bool showMediaSection: true
                property bool showWeatherSection: true
                property bool showWallpaperSection: true
                property bool showSystemSection: true
                property bool showSlidersSection: true
                property bool showQuickActionsSection: true
                property bool showWallpaperSchemeChips: false
            }

            // Dashboard hub panel (ii family). Widget ids per column:
            //   welcome, clock, weather, calendar, agenda, media, notifications,
            //   todo, system, github. Columns collapse when empty.
            property JsonObject dashboard: JsonObject {
                property bool enable: true
                property bool keepLoaded: false
                property bool showHeader: true
                property bool showPowerButtons: true
                property JsonObject appearance: JsonObject {
                    property string density: "comfortable" // "comfortable" | "compact"
                    property real cardOpacity: 1.0 // Card surface opacity (0.3–1); content stays opaque
                    property bool showCardTitles: true
                }
                property string subtitle: "" // Custom phrase under the welcome greeting
                property real widthRatio: 0.62 // Panel width as fraction of screen width (0.4–0.9)
                property JsonObject layout: JsonObject {
                    property list<string> left: ["welcome", "clock", "system", "github"]
                    property list<string> center: ["notifications", "todo"]
                    property list<string> right: ["media", "weather", "calendar"]
                }
                property JsonObject github: JsonObject {
                    property string username: "" // GitHub user for the contributions widget. Empty disables fetching.
                }
            }

            property JsonObject interactions: JsonObject {
                property JsonObject scrolling: JsonObject {
                    property bool fasterTouchpadScroll: false // Enable faster scrolling with touchpad
                    property int mouseScrollDeltaThreshold: 120 // delta >= this then it gets detected as mouse scroll rather than touchpad
                    property int mouseScrollFactor: 120
                    property int touchpadScrollFactor: 450
                }
                property JsonObject deadPixelWorkaround: JsonObject { // Hyprland leaves out 1 pixel on the right for interactions
                    property bool enable: false
                }
            }

            property JsonObject language: JsonObject {
                property string ui: "auto" // UI language. "auto" for system locale, or specific language code like "zh_CN", "en_US"
                property JsonObject translator: JsonObject {
                    property string engine: "auto" // Run `trans -list-engines` for available engines. auto should use google
                    // Defaults tuned for ES -> EN (American English)
                    // Codes follow what `trans` expects, e.g. "es" and "en"
                    property string targetLanguage: "en" // American English
                    property string sourceLanguage: "es" // Spanish
                }
            }

            property JsonObject light: JsonObject {
                property JsonObject night: JsonObject {
                    property bool automatic: true
                    property bool enabled: false // Manual night light state when automatic mode is disabled
                    property string from: "19:00" // Format: "HH:mm", 24-hour time
                    property string to: "06:30"   // Format: "HH:mm", 24-hour time
                    property int colorTemperature: 5000
                }
                property JsonObject antiFlashbang: JsonObject {
                    property bool enable: false
                }
            }

            property JsonObject lock: JsonObject {
                property bool useHyprlock: false
                property bool launchOnStartup: false
                property JsonObject blur: JsonObject {
                    property bool enable: true
                    property real radius: 100
                    property real extraZoom: 1.1
                }
                property bool centerClock: true
                property bool showLockedText: true
                property JsonObject security: JsonObject {
                    property bool unlockKeyring: true
                    property bool requirePasswordToPower: false
                }
                property bool materialShapeChars: true
                property bool enableAnimation: false // Play video/GIF wallpapers on lock screen (default: show first frame)
                property JsonObject dim: JsonObject {
                    property bool enable: false
                    property real opacity: 0.3 // 0.0 = no dim, 1.0 = full black
                }
                property JsonObject clock: JsonObject {
                    property string style: "default" // "default", "minimal", "analog"
                    property string position: "center" // "center", "topLeft", "bottomLeft"
                }
                property JsonObject notifications: JsonObject {
                    property bool enable: false
                    property int maxCount: 3
                    property bool showBody: true
                    property string position: "auto" // "auto" (center ii, right waffle), "center", "left", "right"
                }
                property JsonObject status: JsonObject {
                    property bool enable: true
                }
                property JsonObject widgets: JsonObject {
                    property bool weather: true
                    property bool media: true
                    property bool powerButtons: true
                    property bool hintText: true
                }
            }

            property JsonObject media: JsonObject {
                // Attempt to remove dupes (the aggregator playerctl one and browsers' native ones when there's plasma browser integration)
                property bool filterDuplicatePlayers: true
                // Popup mode: "dock" (bottom overlay, default) or "bar" (anchored to bar widget)
                property string popupMode: "dock"
                property list<string> screenList: []
            }

            property JsonObject hotspot: JsonObject {
                property string ssid: "iNiR Hotspot"
                property string password: "inirhotspot"
                property string band: "bg" // "bg" = 2.4GHz, "a" = 5GHz
            }

            property JsonObject keyboardIndicators: JsonObject {
                property bool showPopup: true
                property bool showPanel: true
                property JsonObject popup: JsonObject {
                    property bool layout: true
                    property bool caps: true
                    property bool num: false
                }
                property JsonObject panel: JsonObject {
                    property bool layout: true
                    property bool caps: true
                    property bool num: false
                }
            }

            property JsonObject networking: JsonObject {
                property string userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
            }

            property JsonObject notifications: JsonObject {
                property int timeout: 7000
                property list<string> screenList: []
                // Daily window where popups are suppressed. History is unaffected.
                // A window whose end is before its start wraps past midnight.
                property JsonObject quietHours: JsonObject {
                    property bool enable: false
                    property string start: "22:00"
                    property string end: "08:00"
                }
                // Timeouts por urgencia (ms). 0 = no expira automáticamente
                property int timeoutLow: 5000
                property int timeoutNormal: 7000
                property int timeoutCritical: 0
                // Always use user timeout settings instead of app-defined ones
                property bool ignoreAppTimeout: false
                // Max popup lifetime (ms). Caps persistent notifications. 0 = no cap.
                property int maxPopupLifetime: 30000
                // Posición del popup de notificaciones: topRight, bottomRight, topLeft, bottomLeft
                property string position: "topRight"
                // Margen respecto a los bordes de pantalla (px)
                property int edgeMargin: 4
                // Slightly enlarge notifications when the mouse hovers over them
                property bool scaleOnHover: false
                // Do Not Disturb mode
                property bool silent: false
                // Use legacy manual counter (false = auto-sync with popup list, true = manual counter)
                property bool useLegacyCounter: true
            }

            property JsonObject osd: JsonObject {
                property int timeout: 1000
                property bool mediaEnabled: true
                property list<string> screenList: []
            }

            property JsonObject osk: JsonObject {
                property string layout: "qwerty_full"
                property bool pinnedOnStartup: false
                property bool keepOnTop: false
            }

            property JsonObject overlay: JsonObject {
                property bool openingZoomAnimation: true
                property bool darkenScreen: true
                property real clickthroughOpacity: 0.8
                property real backgroundOpacity: 0.9 // 0-1, opacidad de los paneles de overlay
                property int scrimDim: 35 // 0-100, intensidad del oscurecido de pantalla
                // Duraciones de animación del overlay (ms)
                property int animationDurationMs: 180
                property int scrimAnimationDurationMs: 140
                property JsonObject floatingImage: JsonObject {
                    property string imageSource: "https://media.tenor.com/H5U5bJzj3oAAAAAi/kukuru.gif"
                    property real scale: 0.5
                }
                property JsonObject recorder: JsonObject {
                    property bool autoHideOnFullscreen: true
                    property bool suppressToasts: true
                    property bool disableNiriAnims: false
                }
            }

            property JsonObject overview: JsonObject {
                property bool enable: true
                property real scale: 0.17 // Relative to screen size
                property real rows: 3
                property real columns: 1
                property bool centerIcons: true
                property bool backgroundBlurEnable: true
                property int backgroundBlurRadius: 22
                property int backgroundDim: 35
                property int scrimDim: 35
                property int topMargin: 0
                property int bottomMargin: 0
                property bool respectBar: true
                property real maxPanelWidthRatio: 1.0
                property int workspaceSpacing: 5
                property int windowTileMargin: 6
                property int iconMinSize: 0
                property int iconMaxSize: 0
                property bool showWorkspaceNumbers: true
                property bool switchToWorkspaceOnOpen: false
                property int switchWorkspaceIndex: 0
                property bool focusAnimationEnable: true
                property int focusAnimationDurationMs: 180
                property int scrollWorkspaceSteps: 2
                property bool keepOverviewOpenOnWindowClick: true
                property bool closeAfterWindowMove: true
                property bool showPreviews: false // Show window thumbnails in overview
                property bool activeScreenOnly: true // Show only on active screen (multi-monitor)
                property bool allAppsGrid: false // Show an all-apps grid instead of the workspace overview
                property string allAppsGridMode: "minimal" // "minimal" (alphabetical) or "folder" (by category)
                property JsonObject dashboard: JsonObject {
                    property bool enable: false
                    property bool showToggles: true
                    property bool showMedia: true
                    property bool showVolume: true
                    property bool showWeather: true
                    property bool showSystem: true
                }
            }

            // Settings for the custom Alt-Tab switcher in ii
            property JsonObject altSwitcher: JsonObject {
                // Preset style: "default" (sidebar) or "list" (centered list)
                property string preset: "default"
                property bool noVisualUi: false
                // Whether to tint app icons (monochrome), similar to dock/workspaces
                property bool monochromeIcons: false
                // Enable/disable slide in/out animation
                property bool enableAnimation: true
                // Slide animation duration in milliseconds
                property int animationDurationMs: 200
                // Whether to order windows by most recently used (MRU) instead of by workspace/app name
                property bool useMostRecentFirst: true
                // Enable local glass-like blur behind the switcher panel
                property bool enableBlurGlass: true
                // Background opacity for the switcher panel (0-1)
                property real backgroundOpacity: 0.9
                // Blur strength for the glass effect (0-1, mapped from UI percentage)
                property real blurAmount: 0.4
                // Dim strength for the fullscreen scrim (0-100)
                property int scrimDim: 35
                property string panelAlignment: "right" // right | center
                property bool useM3Layout: false
                property bool compactStyle: false // Compact horizontal icon-only style
                property bool showOverviewWhileSwitching: false
                property int autoHideDelayMs: 500
            }

            property JsonObject regionSelector: JsonObject {
                property int borderSize: 4
                property int numSize: 48
                // Remember the snip action/shape picked in the overlay toolbar,
                // so the screenshot keybind reopens with the same choice.
                property bool rememberSnipChoice: true
                property int lastAction: 0 // SnipAction ordinal: 0 Shot, 1 Edit, 2 Search, 3 OCR (Record never persists)
                property int lastMode: 0 // SelectionMode ordinal: 0 rectangle, 1 circle
                property JsonObject targetRegions: JsonObject {
                    property bool windows: true
                    property bool layers: false
                    property bool content: true
                    property bool showLabel: false
                    property real opacity: 0.3
                    property real contentRegionOpacity: 0.8
                    property int selectionPadding: 5
                }
                property JsonObject rect: JsonObject {
                    property bool showAimLines: true
                }
                property JsonObject circle: JsonObject {
                    property int strokeWidth: 6
                    property int padding: 10
                }
                property JsonObject annotation: JsonObject {
                    property bool useSatty: false
                    // Use the in-shell native annotation editor for the Edit action
                    // instead of the external swappy/satty tools.
                    property bool useNativeEditor: true
                }
                property string screenshotNameFormat: "ss-%Y%m%d-%H%M%S" // date(1) format for screenshot filenames (without extension)
            }

            property JsonObject resources: JsonObject {
                property int updateInterval: 3000
                property bool monitorGpu: true
            }

            property JsonObject musicRecognition: JsonObject {
                property int timeout: 16
                property int interval: 4
            }

            property JsonObject voiceSearch: JsonObject {
                property int duration: 5
                property string provider: "auto" // auto | local | groq | gemini | openai
                property string language: "auto"
                property string localModelPath: ""
                property string groqModel: "whisper-large-v3-turbo"
                property string geminiModel: "gemini-2.5-flash"
                property string openaiModel: "gpt-4o-mini-transcribe"
            }

            property JsonObject clipboard: JsonObject {
                // Decoded text of pinned entries, newest first. Stored decoded so a
                // pin survives cliphist rotating its store past the original id.
                property list<string> pinned: []
            }

            property JsonObject search: JsonObject {
                property string style: "default" // "default" | "island" (Ricelin gradient card surface)
                property int nonAppResultDelay: 30 // This prevents lagging when typing
                property string engineBaseUrl: "https://www.google.com/search?q="
                property list<string> excludedSites: ["quora.com", "facebook.com"]
                property bool sloppy: false // Uses levenshtein distance based scoring instead of fuzzy sort. Very weird.
                property JsonObject prefix: JsonObject {
                    property bool showDefaultActionsWithoutPrefix: true
                    property string action: "/"
                    property string app: ">"
                    property string clipboard: ";"
                    property string emojis: ":"
                    property string math: "="
                    property string shellCommand: "$"
                    property string webSearch: "?"
                }
                property JsonObject imageSearch: JsonObject {
                    property string imageSearchEngineBaseUrl: "https://yandex.com/images/search?rpt=imageview&url="
                    property string fileUploadApiEndpoint: "https://0x0.st"
                    property string fileUploadApiFallback: "https://litterbox.catbox.moe/resources/internals/api.php"
                    property string fileUploadApiFallback2: "https://catbox.moe/user/api.php"
                    property bool useCircleSelection: false
                }
                property JsonObject globalActions: JsonObject {
                    property bool enableSystem: true
                    property bool enableAppearance: true
                    property bool enableTools: true
                    property bool enableMedia: true
                    property bool enableSettings: true
                    property bool enablePackages: true
                    property bool enableSetup: true
                    property bool enableCustom: true
                }
            }

            property JsonObject sidebar: JsonObject {
                property string style: "panel" // "panel" | "island" (Ricelin gradient card face)
                property bool cardStyle: false
                property list<string> screenList: []
                property string layout: "default" // "default" | "compact"
                property bool keepRightSidebarLoaded: true
                property bool keepLeftSidebarLoaded: true
                property bool instantOpen: false
                property string animationType: "slide" // "slide" | "fade" | "pop" | "reveal"
                property bool collapseEmptyNotifications: false // Shrink right sidebar when there are no notifications (default layout)
                property bool collapseWidgetsTab: false // Shrink left sidebar to its content on tabs with finite height (Widgets)
                property JsonObject shellLayout: JsonObject {
                    property JsonObject feature: JsonObject {
                        property string slot: "left" // "left" | "right"
                        property string sizeMode: "full" // "full" | "fit" | "custom"
                        property int customHeight: 720
                        property int width: 460
                    }
                    property JsonObject system: JsonObject {
                        property string slot: "right" // "left" | "right"
                        property string sizeMode: "full" // "full" | "fit" | "custom"
                        property int customHeight: 720
                        property int width: 460
                    }
                }
                property bool openFolderOnDownload: false // Open file manager after wallpaper download
                property JsonObject translator: JsonObject {
                    property bool enable: false
                    property int delay: 300 // Delay before sending request. Reduces (potential) rate limits and lag.
                }
                property JsonObject ai: JsonObject {
                    property bool textFadeIn: false
                }
                property JsonObject booru: JsonObject {
                    property bool allowNsfw: false
                    property string defaultProvider: "yandere"
                    property int limit: 20
                    property JsonObject zerochan: JsonObject {
                        property string username: "[unset]"
                    }
                    property JsonObject downloadPath: JsonObject {
                        property string sfw: ""
                        property string nsfw: ""
                    }
                }
                // Wallhaven-specific sidebar module options
                property JsonObject wallhaven: JsonObject {
                    // Enable/disable the Wallhaven tab in the left sidebar
                    property bool enable: true
                    // Default page size for API search
                    property int limit: 24
                    // Optional API key for NSFW & user-specific filters
                    property string apiKey: ""
                }
                // News tab - Google News RSS, geo feed follows the Weather location
                property JsonObject news: JsonObject {
                    property bool enable: true
                    property string mode: "local" // "local" | "top" | "topic"
                    property string topic: "WORLD"
                }
                // Anime Schedule tab - AniList API
                property JsonObject animeSchedule: JsonObject {
                    property bool enable: false
                    property bool showNsfw: false
                    // Custom streaming site URL (use %s for search query placeholder)
                    // Examples: "https://9animetv.to/search?keyword=%s", "https://anitaku.pe/search.html?keyword=%s"
                    property string watchSite: ""
                }
                // Tools tab - Niri debug options and quick actions
                property JsonObject tools: JsonObject {
                    property bool enable: false
                }
                // Software catalog tab - curated app install/remove
                property JsonObject software: JsonObject {
                    property bool enable: false
                }
                // Web Apps / Plugins tab - embedded webapps in sidebar
                property JsonObject plugins: JsonObject {
                    property bool enable: false
                    property string lastActivePlugin: ""
                }
                // YT Music tab - Search and play YouTube music via yt-dlp
                property JsonObject ytmusic: JsonObject {
                    property bool enable: false
                    property bool autoConnect: true
                    property bool hideSyncBanner: false
                    property string browser: "firefox"
                    property string cookiesPath: ""
                    property bool useManualCookies: false
                    property bool connected: false
                    property string resolvedBrowserArg: ""
                    property string audioQuality: "best"
                    property bool normalizeVolume: true   // EBU R128 loudness normalization (YouTube-style, ~-14 LUFS)
                    property bool verbose: false
                    property bool shuffleMode: false
                    property int repeatMode: 0
                    property list<string> recentSearches: []
                    property list<var> queue: []
                    property list<var> playlists: []
                    property list<var> liked: []
                    property string lastLikedSync: ""
                    property bool upNextNotifications: true
                    property bool suppressUpNextInFullscreen: true
                    property int volume: 100
                    property JsonObject profile: JsonObject {
                        property string name: ""
                        property string avatar: ""
                        property string url: ""
                    }
                    property JsonObject cache: JsonObject {
                        property list<var> playlists: []
                        property list<var> albums: []
                        property list<var> liked: []
                    }
                    property JsonObject resume: JsonObject {
                        property string videoId: ""
                        property string title: ""
                        property string artist: ""
                        property string thumbnail: ""
                        property string url: ""
                        property real position: 0
                        property bool wasPlaying: false
                        property list<var> activePlaylist: []
                        property int currentIndex: -1
                        property string activePlaylistSource: ""
                    }
                }
                // Widgets tab in left sidebar
                property JsonObject widgets: JsonObject {
                    property bool enable: true
                    // Widget visibility
                    property bool media: true
                    property bool week: true
                    property bool context: true
                    property bool note: false
                    property bool launch: false
                    property bool controls: true
                    property bool status: true
                    property bool crypto: false
                    property bool wallpaper: false
                    property bool worldClock: false
                    // ContextCard specific
                    property bool contextShowWeather: true
                    // Widget order (drag to reorder)
                    property list<string> widgetOrder: ["context", "week", "media", "note", "launch", "controls", "status", "crypto", "wallpaper", "worldclock"]
                    // Spacing between widgets (px)
                    property int spacing: 8

                    // GlanceHeader behavior
                    property JsonObject glance: JsonObject {
                        property bool showVolume: true
                        property bool showGameMode: true
                        property bool showDnd: true
                    }

                    // StatusRings behavior
                    property JsonObject statusRings: JsonObject {
                        property bool showCpu: true
                        property bool showRam: true
                        property bool showDisk: true
                        property bool showTemp: true
                        property bool showBattery: true
                    }

                    // ControlsCard behavior
                    property JsonObject controlsCard: JsonObject {
                        property bool showDarkMode: true
                        property bool showDnd: true
                        property bool showNightLight: true
                        property bool showGameMode: true
                        property bool showNetwork: true
                        property bool showBluetooth: true
                        property bool showSettings: true
                        property bool showLock: true
                    }

                    // CryptoWidget behavior
                    property JsonObject crypto_settings: JsonObject {
                        property int refreshInterval: 60
                        property list<string> coins: ["bitcoin", "ethereum"]
                    }

                    // WorldClockWidget behavior
                    property JsonObject worldClock_settings: JsonObject {
                        // IANA timezones to display, e.g. "Europe/London". Empty = auto-suggest by region.
                        property list<string> timezones: []
                        property bool showSeconds: false
                        property bool use24Hour: true
                        property bool showDate: true
                        property bool highlightLocal: true
                    }

                    // QuickLaunch shortcuts
                    property list<var> quickLaunch: [
                        {
                            "icon": "folder",
                            "name": "Files",
                            "cmd": "/usr/bin/nautilus"
                        },
                        {
                            "icon": "terminal",
                            "name": "Terminal",
                            "cmd": "/usr/bin/kitty"
                        },
                        {
                            "icon": "web",
                            "name": "Browser",
                            "cmd": "/usr/bin/firefox"
                        },
                        {
                            "icon": "code",
                            "name": "Code",
                            "cmd": "/usr/bin/code"
                        }
                    ]

                    // QuickWallpaper settings
                    property JsonObject quickWallpaper: JsonObject {
                        property int itemSize: 72
                        property bool showHeader: true
                    }
                }
                property JsonObject cornerOpen: JsonObject {
                    property bool enable: false
                    property bool bottom: false
                    property bool valueScroll: true
                    property bool clickless: false
                    property int cornerRegionWidth: 250
                    property int cornerRegionHeight: 5
                    property bool visualize: false
                    property bool clicklessCornerEnd: true
                    property int clicklessCornerVerticalOffset: 1
                }

                property JsonObject quickToggles: JsonObject {
                    property string style: "android" // Options: classic, android
                    property JsonObject android: JsonObject {
                        property int columns: 4
                        property list<var> toggles: [
                            {
                                "size": 1,
                                "type": "network"
                            },
                            {
                                "size": 1,
                                "type": "bluetooth"
                            },
                            {
                                "size": 1,
                                "type": "audio"
                            },
                            {
                                "size": 1,
                                "type": "mic"
                            }
                        ]
                    }
                }

                property JsonObject quickSliders: JsonObject {
                    property bool enable: true
                    property bool showMic: true
                    property bool showVolume: true
                    property bool showBrightness: true
                }

                property JsonObject left: JsonObject {
                    // Stable ids keep disabled tabs in their chosen position so
                    // re-enabling a feature restores it where the user placed it.
                    property list<string> tabOrder: ["widgets", "ai", "translator", "anime", "animeSchedule", "wallhaven", "news", "ytmusic", "tools", "software"]
                }

                // Right sidebar widget toggles
                property JsonObject right: JsonObject {
                    property list<string> enabledWidgets: ["calendar", "events", "todo", "calculator", "sysmon", "weather"]
                    // Controls section order for compact layout (drag to reorder)
                    property list<string> controlsSectionOrder: ["sliders", "toggles", "devices", "media", "quickActions"]
                    // Section order for the default layout (modular sidebar).
                    // Known ids: system, sliders, toggles, notifications, widgets.
                    // Unknown ids are ignored; missing ids append in default order.
                    property list<string> sectionOrder: ["system", "sliders", "toggles", "notifications", "widgets"]
                    // Look of the "system" section. "profile" = wallpaper
                    // banner + avatar + user@host card; "classic" = the flat
                    // uptime pill next to the button pill.
                    property string headerStyle: "profile"
                    // Banner media of the profile header: "wallpaper" (the
                    // monitor's live wallpaper), "custom" (headerBannerPath),
                    // "solid" (flat token plate), or "none" (collapse it).
                    property string headerBanner: "wallpaper"
                    property string headerBannerPath: ""
                    // Relative allocation of the two elastic zones. Values are
                    // normalized together by the live resize handle.
                    property JsonObject sectionWeights: JsonObject {
                        property real notifications: 1
                        property real widgets: 1
                    }
                }

                property JsonObject screenTime: JsonObject {
                    property bool enable: false
                    property int pollIntervalSeconds: 5
                    property int retentionDays: 30
                }
            }

            property JsonObject sounds: JsonObject {
                property bool battery: false
                property bool timer: false
                property bool pomodoro: false
                property string theme: "freedesktop"
                property bool notifications: true
                property real volume: 0.5
                property JsonObject events: JsonObject {
                    // Per-event override: "" = theme default; a bare name
                    // plays that sound from the current theme; an absolute
                    // path (or file://) plays the file directly
                    property string notification: ""
                    property string notificationCritical: ""
                    property string batteryLow: ""
                    property string batteryCritical: ""
                    property string batteryFull: ""
                    property string powerPlug: ""
                    property string powerUnplug: ""
                    property string pomodoroDone: ""
                    property string timerDone: ""
                }
            }

            property JsonObject time: JsonObject {
                // https://doc.qt.io/qt-6/qtime.html#toString
                property string format: "hh:mm"
                property string shortDateFormat: "dd/MM"
                property string dateFormat: "ddd, dd/MM"
                property JsonObject pomodoro: JsonObject {
                    property int breakTime: 300
                    property int cyclesBeforeLongBreak: 4
                    property int focus: 1500
                    property int longBreak: 900
                }
                property bool secondPrecision: false
            }

            property JsonObject wallpapers: JsonObject {
                property string directory: "" // Custom wallpapers directory path. Empty = ~/Pictures/Wallpapers
            }

            property JsonObject wallpaperSelector: JsonObject {
                property bool useSystemFileDialog: false
                property string selectionTarget: "main"
                property string targetMonitor: ""
                property string style: "grid" // "grid" | "coverflow" | "launcher"
                property string coverflowView: "gallery" // "gallery" | "skew"
            }

            property JsonObject screenRecord: JsonObject {
                property JsonObject recordingOsd: JsonObject {
                    property bool autoHide: false
                }
                property bool showOsd: false
                property bool showNotifications: true
                property string savePath: "" // Empty = use XDG Videos or ~/Videos
                property string qualityPreset: "balanced"
                property string videoCodec: "libx264"
                property string audioCodec: "aac"
                property string accelerationMode: "auto"
                property string hardwareDevice: "/dev/dri/renderD128"
                property int fps: 60
                property int videoBitrateKbps: 12000
                property int audioBitrateKbps: 192
                property string audioMode: "system" // "none" | "system" | "microphone" | "both"
                property string audioSource: "" // Legacy single-source override; retained for existing configs
                property string systemAudioSource: "" // Empty = default sink monitor
                property string microphoneSource: "" // Empty = default non-monitor source
                property string audioBackend: ""
                property int audioSampleRate: 48000
                property string pixelFormat: "yuv420p"
                property string preset: "veryfast"
                property int crf: 21
                property string vaapiFilter: "scale_vaapi=format=nv12:out_range=full"
                property bool enableFallback: true
                property string recordingNameFormat: "recording_%Y-%m-%d_%H.%M.%S" // date(1) format for recording filenames (without extension)
                property JsonObject discordCompress: JsonObject {
                    property bool enabled: false
                    property real targetSizeMb: 10
                    property real safetyMarginMb: 0.5
                    property bool onlyIfNeeded: true
                    property int audioBitrateKbps: 96
                    property string preset: "slow"
                    property int maxDimension: 1280
                }
            }

            property JsonObject windows: JsonObject {
                property bool showTitlebar: true // Client-side decoration for shell apps
                property bool centerTitle: true
                // Optional per-window identity remapping for apps whose windows
                // all share one app_id (e.g. browser PWA windows). Each entry:
                // { appIdRegex, titleRegex, desktopId } — both regexes are
                // optional but at least one is required. The first matching
                // rule wins; malformed rules are ignored; empty = no changes.
                property list<var> appIdentityRules: []
            }

            property JsonObject settingsUi: JsonObject {
                property bool overlayMode: true // true = layer shell overlay (live preview), false = separate window
                // Chrome used in overlay mode. "rail" = persistent nav rail beside a
                // narrowed content pane; "focus" = drill-down, one page at a time.
                // Orthogonal to overlayMode: this picks the look, that picks the host.
                property string overlayStyle: "rail"
                property bool easyMode: true    // true = curated essentials only; nav and sub-sections filter to a friendlier subset
                // JSON-encoded [{label, pages:[int]}] — custom nav arrangement; "" = registry defaults.
                // String on purpose: property var inside JsonObject crashes the VME.
                property string categories: ""
                property JsonObject overlayAppearance: JsonObject {
                    property int scrimDim: 35           // % dim of the backdrop scrim behind the settings panel (0-100)
                    // Opacity of the settings panel background (0.6-1.0). The
                    // floor is a legibility contract, not a taste call: the panel
                    // is a single surface and the cards on it carry the reading
                    // contrast, so below it the solid styles put a sharp wallpaper
                    // behind the text and aurora thins to a bare 64 px blur. Both
                    // settings hosts clamp on read.
                    property real backgroundOpacity: 1.0
                    // Blur radius (%) of the backdrop behind the settings overlay,
                    // painted by the same shared GlassBackground the rest of the
                    // shell uses. 0 keeps the surface out of the tree entirely.
                    property int backdropBlur: 0
                }
            }

            property JsonObject hacks: JsonObject {
                property int arbitraryRaceConditionDelay: 20 // milliseconds
            }

            property JsonObject tray: JsonObject {
                property bool monochromeIcons: true
                property bool showItemId: false
                property bool invertPinnedItems: true
                property list<string> pinnedItems: []
                property bool filterPassive: true
            }
            property JsonObject updates: JsonObject {
                property int checkInterval: 120
                property int adviseUpdateThreshold: 75
                property int stronglyAdviseUpdateThreshold: 200
            }
            property JsonObject shellUpdates: JsonObject {
                property bool enabled: true
                property int checkIntervalMinutes: 360
                property string dismissedCommit: ""
                property string lastNotifiedCommit: ""
                // When true, performUpdate() launches setup in a terminal window so the
                // user sees the full TUI output (progress bars, success/warn/error lines)
                // instead of just the bar pill X/N indicator. Auto-closes on success,
                // pauses on failure so the user can read the error.
                property bool openTerminalOnUpdate: true
            }
            property JsonObject bootGreeting: JsonObject {
                property bool enable: false
                property int autoDismissDelay: 5000
                property bool showWeather: true
                property bool showDate: true
            }
            property JsonObject welcomeWizard: JsonObject {
                property bool completed: false
                property bool skipped: false
                property string profile: "balanced"
            }

            property JsonObject workspaceStrip: JsonObject {
                // Chrome dialect: "auto" follows the bar (island look only when
                // the pill bar is active), "island"/"stock" force it.
                property string style: "auto"
                property string side: "right"
                property int panelWidth: 480
                property int previewSize: 150
                property int triggerWidth: 6
                property int openDelay: 110
                property int closeDelay: 320
                property bool showPreviews: true
                property bool showAppIcons: true
                property bool showMetadata: true
                property bool showMediaPlayer: true
                property bool perMonitor: true
                property bool scrollNavigation: false
                property bool scrollNavigationSwitchWorkspace: true
                property int scrollNavigationDebounceMs: 180
            }

            property JsonObject waffles: JsonObject {
                property JsonObject settings: JsonObject {
                    property bool useMaterialStyle: false
                }
                property JsonObject modules: JsonObject {
                    property bool sidebarLeft: false
                    property bool sidebarRight: false
                    property bool dock: false
                    property bool mediaControls: false
                    property bool screenCorners: false
                    property bool widgets: true
                }
                property JsonObject tweaks: JsonObject {
                    property bool smootherMenuAnimations: true
                    property bool switchHandlePositionFix: true
                }
                property JsonObject altSwitcher: JsonObject {
                    property string preset: "thumbnails"
                    property bool noVisualUi: false
                    property bool monochromeIcons: false
                    property bool enableAnimation: true
                    property int animationDurationMs: 300
                    property real backgroundOpacity: 1.0
                    property real blurAmount: 0.0
                    property int scrimDim: 0
                    property int autoHideDelayMs: 500
                    property bool showOverviewWhileSwitching: false
                    property bool compactStyle: false
                    property string panelAlignment: "center"
                    property bool useM3Layout: false
                    property bool useMostRecentFirst: true
                    property bool quickSwitch: false
                    property bool autoHide: true
                    property bool closeOnFocus: true
                    property int thumbnailWidth: 280
                    property int thumbnailHeight: 180
                    property real scrimOpacity: 0.4
                }
                property JsonObject background: JsonObject {
                    property string wallpaperPath: "" // Empty = use main wallpaper
                    property string thumbnailPath: "" // Thumbnail for animated wallpapers (video/gif)
                    property bool useMainWallpaper: true
                    property bool enableAnimation: true // Enable animated wallpapers (video/gif)
                    property bool hideWhenFullscreen: true
                    property JsonObject transition: JsonObject {
                        property bool enable: true
                        property string type: "crossfade"
                        property string direction: "right"
                        property int duration: 800
                    }
                    property JsonObject effects: JsonObject {
                        property bool enableBlur: false
                        property int blurRadius: 32
                        property int dim: 0
                        property int dynamicDim: 0
                        property bool enableAnimatedBlur: false // Enable blur for animated wallpapers (video/gif) - has performance impact
                        property int thumbnailBlurStrength: 70 // Blur strength for animated wallpapers (0-100)
                    }
                    property JsonObject backdrop: JsonObject {
                        property bool enable: true
                        property bool hideWallpaper: false
                        property bool useMainWallpaper: true
                        property string wallpaperPath: ""
                        property string thumbnailPath: "" // Thumbnail for animated wallpapers (video/gif)
                        property bool enableAnimation: false // Enable animated wallpapers (video/gif) in backdrop (disabled by default for performance)
                        property bool enableAnimatedBlur: false // Enable blur for animated wallpapers (video/gif) - has performance impact
                        property int blurRadius: 32
                        property int dim: 35
                        property real saturation: 0
                        property real contrast: 0
                        property bool vignetteEnabled: false
                        property real vignetteIntensity: 0.5
                        property real vignetteRadius: 0.7
                    }
                    property JsonObject parallax: JsonObject {
                        property bool enable: false
                        property string axis: "horizontal"
                        property bool vertical: false
                        property bool autoVertical: true
                        property bool enableWorkspace: false
                        property real workspaceShift: 1.0
                        property real workspaceZoom: 1.0
                        property real zoom: 1.0
                        property bool enableSidebar: false
                        property real panelShift: 0.12
                        property real widgetsFactor: 1.0
                        property real widgetDepth: 1.0
                        property bool pauseDuringTransitions: true
                        property int transitionSettleMs: 220
                    }
                    property JsonObject widgets: JsonObject {
                        property JsonObject clock: JsonObject {
                            property bool enable: false
                            property string placementStrategy: "leastBusy"
                            property int x: 100
                            property int y: 100
                            property int dim: 55
                            property string fontFamily: "Segoe UI Variable Display"
                            property string style: "hero"
                            property string timeFormat: "system"
                            property string dateStyle: "long"
                            property string colorMode: "adaptive"
                            property bool showDate: true
                            property bool showSeconds: false
                            property bool showShadow: true
                            property bool showLockStatus: true
                            property int timeScale: 100
                            property int dateScale: 100
                            property JsonObject digital: JsonObject {
                                property bool animateChange: true
                            }
                        }
                    }
                }
                property JsonObject bar: JsonObject {
                    property bool bottom: true
                    property bool leftAlignApps: false
                    property bool monochromeIcons: false
                    property bool tintTrayIcons: false
                    property int iconSize: 26
                    property int searchIconSize: 24
                    property list<string> screenList: [] // Waffle taskbar output filter. Empty = all screens.
                    property JsonObject activationWatermark: JsonObject {
                        property bool enable: false
                    }
                    property JsonObject desktopPeek: JsonObject {
                        property bool hoverPeek: false
                        property int hoverDelay: 500
                    }
                    property JsonObject notifications: JsonObject {
                        property bool showUnreadCount: true
                    }
                }
                property JsonObject notifications: JsonObject {
                    property bool showUnreadCount: true
                }
                property JsonObject actionCenter: JsonObject {
                    property list<string> toggles: ["network", "hotspot", "bluetooth", "easyEffects", "powerProfile", "idleInhibitor", "nightLight", "darkMode", "antiFlashbang", "cloudflareWarp", "mic", "musicRecognition", "notifications", "onScreenKeyboard", "gameMode", "screenSnip", "colorPicker"]
                }
                property JsonObject calendar: JsonObject {
                    property bool force2CharDayOfWeek: true
                    property string locale: ""
                }
                property JsonObject theming: JsonObject {
                    property bool useMaterialColors: true // Use Material ii colors instead of W11 grey
                    property JsonObject font: JsonObject {
                        property string family: "Noto Sans"
                        property real scale: 1.0 // Font size multiplier (0.8 - 1.5)
                    }
                }
                property JsonObject startMenu: JsonObject {
                    property string sizePreset: "normal" // mini, compact, normal, large, wide
                    property real scale: 1.0 // Start menu scale (0.8 - 1.5)
                }
                property JsonObject behavior: JsonObject {
                    property bool allowMultiplePanels: false // Allow multiple panels open at once (for screenshots)
                }
                property JsonObject widgetsPanel: JsonObject {
                    property bool showDateTime: true
                    property bool showWeather: true
                    property bool showSystem: true
                    property bool showMedia: true
                    property bool showQuickActions: true
                    property list<string> quickActions: ["files", "terminal", "settings", "wallpaper", "screenshot", "screenRecord", "session"]
                    property bool weatherHideLocation: false // Privacy: hide city name
                    // Individual quick action toggles (used by settings switches)
                    property bool showFiles: true
                    property bool showTerminal: true
                    property bool showSettings: true
                    property bool showWallpaper: true
                    property bool showScreenshot: true
                    property bool showScreenRecord: true
                    property bool showSession: true
                    property bool showColorScheme: true
                }
                property JsonObject workspaceNames: JsonObject {
                    // Custom workspace names, keyed by workspace index (1-based)
                    // Example: "1": "Main", "2": "Work", "3": "Gaming"
                }
                property JsonObject taskView: JsonObject {
                    property string mode: "centered" // "carousel" or "centered"
                    property bool closeOnSelect: false // Close TaskView when clicking a window
                }
            }
            property JsonObject workSafety: JsonObject {
                property JsonObject enable: JsonObject {
                    property bool wallpaper: false
                    property bool clipboard: false
                }
                property JsonObject triggerCondition: JsonObject {
                    property list<string> networkNameKeywords: ["airport", "cafe", "college", "company", "eduroam", "free", "guest", "public", "school", "university"]
                    property list<string> fileKeywords: ["anime", "booru", "ecchi", "hentai", "yande.re", "konachan", "breast", "nipples", "pussy", "nsfw", "spoiler", "girl"]
                    property list<string> linkKeywords: ["hentai", "porn", "sukebei", "hitomi.la", "rule34", "gelbooru", "fanbox", "dlsite"]
                }
            }
        }
    }
}
