pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.services.deferred

/**
 * Live provider/model discovery with a last-known-good cache.
 *
 * This singleton never owns conversations or model selection. It only exposes
 * normalized catalog records and provider health to Ai and Settings.
 */
Singleton {
    id: root

    readonly property var providers: AiProviderPresets.presets
    property var providerStates: ({})
    property var models: []
    property bool initialized: false
    property bool refreshing: false
    property int lastRefreshEpoch: 0
    readonly property int cacheVersion: 2

    readonly property int availableModelCount: models.length
    readonly property int freeModelCount: models.filter(model => model.free === true).length
    readonly property int localModelCount: models.filter(model => model.local === true).length
    readonly property int healthyProviderCount: Object.values(providerStates)
        .filter(state => state?.status === "ready").length
    readonly property int browseableProviderCount: Object.values(providerStates)
        .filter(state => state?.status === "catalog-ready").length

    property var _catalogByProvider: ({})
    property var _queue: []
    property var _activeProvider: null
    property string _stdout: ""
    property bool _pendingRefresh: false

    signal catalogUpdated()

    function providerById(providerId: string): var {
        return root.providers.find(provider => provider.id === providerId) ?? null
    }

    function stateFor(providerId: string): var {
        return root.providerStates[providerId] ?? ({
            providerId,
            status: "idle",
            modelCount: 0,
            error: "",
            fetchedAt: 0,
            hasKey: root._hasProviderKey(root.providerById(providerId)),
            catalogReady: false,
            stale: false,
        })
    }

    function modelsFor(providerId: string): var {
        return root.models.filter(model => model.providerId === providerId)
    }

    function _hasProviderKey(provider) {
        if (!provider || !provider.requiresKey) return true
        const keys = KeyringStorage.keyringData?.apiKeys ?? {}
        return (keys[provider.keyId]?.length ?? 0) > 0
    }

    function ensureInitialized(): void {
        if (root.initialized) return
        root.initialized = true
        cacheFile.reload()
        if (!KeyringStorage.loaded) {
            root._pendingRefresh = true
            KeyringStorage.fetchKeyringData()
            return
        }
        root.refreshAll()
    }

    function refreshAll(): void {
        if (root.refreshing) {
            root._pendingRefresh = true
            return
        }
        root._queue = root.providers.filter(provider => provider.catalogKind !== "static")
        root.refreshing = root._queue.length > 0
        root._startNext()
    }

    function refreshProvider(providerId: string): void {
        const provider = root.providerById(providerId)
        if (!provider || provider.catalogKind === "static") return
        if (root.refreshing) {
            const alreadyQueued = root._queue.some(item => item.id === providerId)
                || root._activeProvider?.id === providerId
            if (!alreadyQueued) root._queue = [...root._queue, provider]
            return
        }
        root._queue = [provider]
        root.refreshing = true
        root._startNext()
    }

    function _setProviderState(providerId: string, patch) {
        const current = root.providerStates[providerId] ?? ({ providerId })
        const next = Object.assign({}, current, patch)
        root.providerStates = Object.assign({}, root.providerStates, { [providerId]: next })
    }

    function _startNext(): void {
        if (catalogProcess.running) return
        if (root._queue.length === 0) {
            root.refreshing = false
            root.lastRefreshEpoch = Math.floor(Date.now() / 1000)
            root._publishModels()
            root._saveCache()
            root.catalogUpdated()
            if (root._pendingRefresh) {
                root._pendingRefresh = false
                Qt.callLater(root.refreshAll)
            }
            return
        }

        const provider = root._queue[0]
        root._queue = root._queue.slice(1)
        root._activeProvider = provider
        root._stdout = ""
        root._setProviderState(provider.id, {
            status: "loading",
            error: "",
            hasKey: root._hasProviderKey(provider),
        })

        const key = provider.requiresKey
            ? (KeyringStorage.keyringData?.apiKeys?.[provider.keyId] ?? "")
            : ""
        catalogProcess.environment = ({ "INIR_AI_PROVIDER_KEY": key })

        const chatEndpoint = provider.catalogChatEndpoint ?? provider.endpoint
        const apiFormat = provider.catalogApiFormat ?? provider.api_format ?? "openai"
        const command = [
            "/usr/bin/python3",
            `${Directories.scriptsPath}/ai/discover-provider-models.py`,
            "--provider-id", provider.id,
            "--kind", provider.catalogKind ?? "openai-compatible",
            "--models-url", provider.modelsEndpoint ?? "",
            "--chat-endpoint", chatEndpoint ?? "",
            "--api-format", apiFormat,
            "--key-id", provider.keyId ?? "",
        ]
        if (provider.requiresKey) command.push("--requires-key")
        if (provider.publicCatalog) command.push("--public-catalog")
        command.push("--auth-scheme", provider.catalogAuthScheme ?? provider.authScheme ?? "strategy")
        if (provider.local) command.push("--local")
        catalogProcess.command = command
        catalogProcess.running = true
    }

    function _handleResult(text: string): void {
        const provider = root._activeProvider
        if (!provider) return
        try {
            const result = JSON.parse(text.trim())
            const previous = root._catalogByProvider[provider.id] ?? []
            if (result.ok) {
                root._catalogByProvider = Object.assign({}, root._catalogByProvider, {
                    [provider.id]: result.models ?? [],
                })
                const hasKey = root._hasProviderKey(provider)
                const catalogOnly = !!provider.requiresKey && !!provider.publicCatalog && !hasKey
                root._setProviderState(provider.id, {
                    status: catalogOnly ? "catalog-ready" : "ready",
                    modelCount: (result.models ?? []).length,
                    error: "",
                    fetchedAt: result.fetchedAt ?? Math.floor(Date.now() / 1000),
                    stale: false,
                    hasKey,
                    catalogReady: true,
                })
            } else {
                root._setProviderState(provider.id, {
                    status: result.error === "missing-key" ? "needs-key" : "unavailable",
                    modelCount: previous.length,
                    error: result.error ?? "discovery-failed",
                    fetchedAt: root.stateFor(provider.id).fetchedAt ?? 0,
                    stale: previous.length > 0,
                    hasKey: root._hasProviderKey(provider),
                    catalogReady: previous.length > 0,
                })
            }
        } catch (error) {
            const previous = root._catalogByProvider[provider.id] ?? []
            root._setProviderState(provider.id, {
                status: "unavailable",
                modelCount: previous.length,
                error: `invalid-discovery-output: ${error}`,
                stale: previous.length > 0,
                hasKey: root._hasProviderKey(provider),
                catalogReady: previous.length > 0,
            })
        }
    }

    function _publishModels(): void {
        let merged = []
        for (const providerId of Object.keys(root._catalogByProvider)) {
            merged = merged.concat(root._catalogByProvider[providerId] ?? [])
        }
        merged.sort((a, b) => {
            if (!!a.local !== !!b.local) return a.local ? -1 : 1
            if (!!a.free !== !!b.free) return a.free ? -1 : 1
            return String(a.displayName ?? a.remoteId).localeCompare(String(b.displayName ?? b.remoteId))
        })
        root.models = merged
    }

    function _saveCache(): void {
        cacheFile.setText(JSON.stringify({
            version: root.cacheVersion,
            savedAt: root.lastRefreshEpoch,
            providers: root.providerStates,
            catalogByProvider: root._catalogByProvider,
        }))
    }

    function _loadCache(): void {
        if (!cacheFile.loaded) return
        const text = cacheFile.text()
        if (!text || text.trim().length === 0) return
        try {
            const data = JSON.parse(text)
            if ((data.version ?? 0) !== root.cacheVersion) return
            root._catalogByProvider = data.catalogByProvider ?? ({})
            root.providerStates = data.providers ?? ({})
            root.lastRefreshEpoch = data.savedAt ?? 0
            root._publishModels()
        } catch (error) {
            // A damaged cache is disposable; live discovery will rebuild it.
        }
    }

    Connections {
        target: KeyringStorage
        function onLoadedChanged(): void {
            if (!KeyringStorage.loaded || !root.initialized) return
            if (root._pendingRefresh) root._pendingRefresh = false
            root.refreshAll()
        }
        function onKeyringDataChanged(): void {
            if (!KeyringStorage.loaded || !root.initialized) return
            root.refreshAll()
        }
    }

    Process {
        id: catalogProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._stdout = text
        }
        onExited: (exitCode, exitStatus) => {
            root._handleResult(root._stdout)
            root._activeProvider = null
            Qt.callLater(root._startNext)
        }
    }

    FileView {
        id: cacheFile
        path: Qt.resolvedUrl(`${Directories.stateUserPath}/ai/model-catalog.json`)
        blockLoading: true
        printErrors: false
        watchChanges: false
        onLoadedChanged: root._loadCache()
    }
}
