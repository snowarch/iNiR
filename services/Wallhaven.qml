pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs
import qs.services
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Wallpaper browser request owner. Wallhaven is handled natively; curated anime
 * sources reuse the existing Booru provider URL and mapping contracts.
 */
QtObject {
    id: root

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(...args);
    }

    property Component wallhavenResponseComponent: BooruResponseData {}

    signal responseFinished()
    signal tagSuggestion(string query, var suggestions)

    property string failMessage: Translation.tr("That didn't work. Check your tags, page and NSFW settings.")
    property var responses: []
    readonly property int responseLimit: 20
    property int runningRequests: 0

    function _destroyResponsesLater(items) {
        const doomed = (items || []).filter(item => item !== null && item !== undefined)
        if (doomed.length === 0)
            return
        Qt.callLater(() => {
            for (let i = 0; i < doomed.length; ++i) {
                if (typeof doomed[i].destroy === "function")
                    doomed[i].destroy()
            }
        })
    }

    function _appendResponse(response) {
        const next = [...root.responses, response]
        const removed = []
        while (next.length > root.responseLimit)
            removed.push(next.shift())
        root.responses = next
        root._destroyResponsesLater(removed)
    }

    property string _lastTagSuggestionQuery: ""
    property string _lastTagSuggestionProvider: "wallhaven"
    property var _lastTagSuggestions: ([])

    readonly property var wallpaperProviderIds: ["wallhaven", "commons", "konachan", "yandere"]

    function _normalizedProvider(providerId): string {
        return root.wallpaperProviderIds.includes(providerId) ? providerId : "wallhaven"
    }

    // Wallhaven rate limiting (HTTP 429) can trigger easily when paging quickly.
    property real nowMs: Date.now()
    property real rateLimitedUntilMs: 0
    readonly property bool isRateLimited: nowMs < rateLimitedUntilMs

    readonly property bool _active: (Config.options?.sidebar?.wallhaven?.enable ?? true) && (GlobalStates?.sidebarLeftOpen ?? false)

    property Timer wallhavenClock: Timer {
        // Removed: nowMs is updated on-demand in handlers that need it
        interval: 500
        repeat: false
        running: false
    }

    Component.onCompleted: {
        root.nowMs = Date.now()
    }

    // Throttling
    property int minSearchIntervalMs: 1200
    property int minTagIntervalMs: 1200
    property real _nextSearchAllowedMs: 0

    property Timer _pendingSearchTimer: Timer {
        interval: Math.max(0, root._nextSearchAllowedMs - root.nowMs)
        onTriggered: root._processPendingSearch()
    }
    property real _nextTagAllowedMs: 0

    // Pending search request (coalesced)
    property var pendingSearch: null

    property Timer pendingSearchTimer: Timer {
        interval: 300
        repeat: true
        running: root._active || (root.pendingSearch !== null)
        onTriggered: {
            root.nowMs = Date.now()
            if (!root.pendingSearch)
                return
            if (root.runningRequests > 0 || root.searchProcess.running)
                return
            if (root.nowMs < root._nextSearchAllowedMs)
                return

            const next = root.pendingSearch
            if (root.isRateLimited && next.provider === "wallhaven")
                return
            root.pendingSearch = null
            root.makeRequest(next.tags, next.nsfw, next.limit, next.page,
                next.category, next.generation, next.provider, next.fitProfile)
        }
    }

    // Tag fetch queue
    property var tagQueue: ([])
    property var wallpaperTagCache: ({})
    property var _wallpaperTagCacheKeys: []
    readonly property int wallpaperTagCacheLimit: 256
    property var wallpaperTagRequests: ({})

    // Basic settings
    readonly property string apiBase: "https://wallhaven.cc/api/v1"
    readonly property string apiSearchEndpoint: apiBase + "/search"

    property string defaultUserAgent: Config.options?.networking?.userAgent || "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"

    property string tagSuggestionBase: "https://wallhaven.cc/tag/search"
    property int tagSuggestionCacheMs: 5 * 60 * 1000
    property var _tagSuggestionCache: ({})
    property var _tagSuggestionCacheKeys: []
    readonly property int tagSuggestionCacheLimit: 64
    property var currentTagRequest: null

    // Cache + queue for counts (meta.total) per tag id
    property int tagCountCacheMs: 10 * 60 * 1000
    property var _tagCountCache: ({})
    property var _tagCountCacheKeys: []
    readonly property int tagCountCacheLimit: 256
    property var _tagCountRequests: ({})
    property var _tagCountQueue: ([])

    function _boundedCacheInsert(cache, keys, key, value, limit) {
        const nextCache = Object.assign({}, cache)
        const nextKeys = (keys || []).slice()
        const existingIndex = nextKeys.indexOf(key)
        if (existingIndex >= 0)
            nextKeys.splice(existingIndex, 1)

        nextCache[key] = value
        nextKeys.push(key)
        while (nextKeys.length > limit) {
            const oldestKey = nextKeys.shift()
            delete nextCache[oldestKey]
        }
        return { cache: nextCache, keys: nextKeys }
    }

    function _storeTagSuggestion(key, value) {
        const bounded = root._boundedCacheInsert(root._tagSuggestionCache,
            root._tagSuggestionCacheKeys, key, value, root.tagSuggestionCacheLimit)
        root._tagSuggestionCache = bounded.cache
        root._tagSuggestionCacheKeys = bounded.keys
    }

    function _storeTagCount(key, value) {
        const bounded = root._boundedCacheInsert(root._tagCountCache,
            root._tagCountCacheKeys, key, value, root.tagCountCacheLimit)
        root._tagCountCache = bounded.cache
        root._tagCountCacheKeys = bounded.keys
    }

    function _storeWallpaperTags(key, value) {
        const bounded = root._boundedCacheInsert(root.wallpaperTagCache,
            root._wallpaperTagCacheKeys, key, value, root.wallpaperTagCacheLimit)
        root.wallpaperTagCache = bounded.cache
        root._wallpaperTagCacheKeys = bounded.keys
    }

    // Process for main search requests
    property var _currentSearchUrl: ""
    property var _currentSearchResponse: null
    property string _currentSearchProvider: "wallhaven"
    property var _currentSearchFitProfile: ({})
    property int _currentSearchDisplayLimit: 24
    property int _currentSearchGeneration: 0
    property int searchGeneration: 0
    property int _searchToken: 0
    property int _activeSearchToken: 0

    property Process searchProcess: Process {
        stdout: StdioCollector { id: searchStdout }
        onExited: (_exitCode, _exitStatus) => {
            root._handleSearchResponse(searchStdout.text ?? "")
        }
    }

    // Process for tag count requests
    property string _tagCountCurrentId: ""
    property Process tagCountProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root._handleTagCountResponse(text)
            }
        }
    }

    // Process for tag suggestions
    property string _tagSuggestionQuery: ""
    property string _tagSuggestionProvider: "wallhaven"
    property bool _tagSuggestionPreferQuoted: true
    property Process tagSuggestionProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root._handleTagSuggestionResponse(text)
            }
        }
    }

    // Process for wallpaper detail (tags)
    property string _tagDetailCurrentId: ""
    property Process tagDetailProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root._handleTagDetailResponse(text)
            }
        }
    }

    property Timer _tagCountTimer: Timer {
        interval: 350
        repeat: true
        running: root._active || (root._tagCountQueue && root._tagCountQueue.length > 0)
        onTriggered: root._fetchNextTagCount()
    }

    function _detailUrl(id) {
        var url = apiBase + "/w/" + encodeURIComponent(id)
        if (apiKey && apiKey.length > 0) {
            url += "?apikey=" + encodeURIComponent(apiKey)
        }
        return url
    }

    function _decodeHtmlEntities(text) {
        if (!text)
            return ""
        return text
            .replace(/&amp;/g, "&")
            .replace(/&quot;/g, "\"")
            .replace(/&#039;/g, "'")
            .replace(/&lt;/g, "<")
            .replace(/&gt;/g, ">")
    }

    function _parseTagSuggestionsFromHtml(html) {
        const results = []
        if (!html || html.length === 0)
            return results

        const patterns = [
            new RegExp('href=["\'](?:https?:\\/\\/wallhaven\\.cc)?\\/tag\\/(\\d+)["\'][^>]*>([\\s\\S]*?)<\\/a>', 'g'),
            new RegExp('href=(?:https?:\\/\\/wallhaven\\.cc)?\\/tag\\/(\\d+)[^>]*>([\\s\\S]*?)<\\/a>', 'g')
        ]

        for (let p = 0; p < patterns.length; ++p) {
            const re = patterns[p]
            let m = null
            while ((m = re.exec(html)) !== null) {
                const id = (m[1] || "").trim()
                const rawInner = (m[2] || "")
                const innerText = rawInner.replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim()
                const name = root._decodeHtmlEntities(innerText)
                if (!name)
                    continue
                if (results.find(x => x.id === id || x.name === name))
                    continue
                results.push({ id: id, name: name })
                if (results.length >= 10)
                    break
            }
            if (results.length > 0)
                break
        }

        return results
    }

    function _queueTagCount(id) {
        root.nowMs = Date.now()
        if (!id || id.length === 0)
            return
        const cached = root._tagCountCache[id]
        if (cached && (root.nowMs - (cached.ts || 0) < root.tagCountCacheMs))
            return
        if (root._tagCountRequests[id])
            return
        if (root._tagCountQueue.indexOf(id) !== -1)
            return
        root._tagCountQueue = [...root._tagCountQueue, id]
    }

    function _fetchNextTagCount(): void {
        root.nowMs = Date.now()
        if (root.isRateLimited)
            return
        if (root.nowMs < root._nextTagAllowedMs)
            return
        if (!root._tagCountQueue || root._tagCountQueue.length === 0)
            return
        if (root.tagCountProcess.running)
            return

        const id = root._tagCountQueue[0]
        root._tagCountQueue = root._tagCountQueue.slice(1)
        if (!id || id.length === 0)
            return
        if (root._tagCountRequests[id])
            return

        root._tagCountRequests[id] = true
        root._nextTagAllowedMs = root.nowMs + root.minTagIntervalMs
        root._tagCountCurrentId = id

        const url = root.apiSearchEndpoint + "?q=" + encodeURIComponent("id:" + id) + "&page=1&per_page=1&categories=111&purity=100&sorting=date_added&order=desc" + ((apiKey && apiKey.length > 0) ? ("&apikey=" + encodeURIComponent(apiKey)) : "")
        _log("[Wallhaven] Fetching tag count for", id)
        root.tagCountProcess.command = ["/usr/bin/curl", "-s", "--max-time", "15", "-H", "User-Agent: " + defaultUserAgent, url]
        root.tagCountProcess.running = true
    }

    function _handleTagCountResponse(text): void {
        const id = root._tagCountCurrentId
        delete root._tagCountRequests[id]
        root._tagCountCurrentId = ""

        if (!text || text.length === 0) {
            return
        }

        try {
            const payload = JSON.parse(text)
            const meta = payload.meta || {}
            const total = meta.total !== undefined ? parseInt(meta.total) : 0
            root._storeTagCount(id, { ts: root.nowMs, total: total })

            if (root._lastTagSuggestionProvider === "wallhaven"
                    && root._lastTagSuggestions && root._lastTagSuggestions.length > 0) {
                let changed = false
                const updated = root._lastTagSuggestions.map(s => {
                    if (s && s.id === id) {
                        changed = true
                        return { id: s.id, name: s.name, count: total }
                    }
                    return s
                })
                if (changed) {
                    root._lastTagSuggestions = updated
                    root.tagSuggestion(root._lastTagSuggestionQuery, updated)
                }
            }
        } catch (e) {
            console.log("[Wallhaven] Failed to parse tag count response:", e)
        }
    }

    function cancelTagSuggestions(): void {
        root._tagSuggestionQuery = ""
        root._tagSuggestionProvider = root.activeSearchProvider
        root._lastTagSuggestions = []
        if (root.tagSuggestionProcess.running)
            root.tagSuggestionProcess.running = false
    }

    function triggerTagSearch(query, preferQuoted, providerId) {
        root.nowMs = Date.now()
        const q = (query || "").trim()
        if (q.length === 0)
            return

        const requestedProvider = root._normalizedProvider(providerId ?? "wallhaven")
        if (preferQuoted === undefined)
            preferQuoted = requestedProvider === "wallhaven"

        root.cancelTagSuggestions()

        const cacheKey = requestedProvider + ":" + q
        const cached = root._tagSuggestionCache[cacheKey]
        if (cached && (root.nowMs - (cached.ts || 0) < root.tagSuggestionCacheMs)) {
            root.tagSuggestion(q, cached.items || [])
            return
        }

        let url = ""
        if (requestedProvider === "wallhaven") {
            const searchQ = preferQuoted ? ("\"" + q + "\"") : q
            url = root.tagSuggestionBase + "?q=" + encodeURIComponent(searchQ)
        } else {
            const provider = Booru.providers[requestedProvider]
            if (!provider?.tagSearchTemplate) {
                root.tagSuggestion(q, [])
                return
            }
            url = provider.tagSearchTemplate.replace("{{query}}", encodeURIComponent(q))
        }

        root._tagSuggestionQuery = q
        root._tagSuggestionProvider = requestedProvider
        root._tagSuggestionPreferQuoted = preferQuoted

        _log("[Wallhaven] Fetching", requestedProvider, "tag suggestions for", q)
        const command = ["/usr/bin/curl", "-s", "--globoff", "--max-time", "15"]
        if (requestedProvider === "wallhaven")
            command.push("-H", "User-Agent: " + defaultUserAgent)
        else if (requestedProvider === "waifu.im")
            command.push("-H", "Accept-Version: v7")
        command.push(url)
        root.tagSuggestionProcess.command = command
        root.tagSuggestionProcess.running = true
    }

    function _handleTagSuggestionResponse(text): void {
        const q = root._tagSuggestionQuery
        if (q.length === 0)
            return
        const requestedProvider = root._tagSuggestionProvider
        const preferQuoted = root._tagSuggestionPreferQuoted

        if (!text || text.length === 0) {
            _log("[Wallhaven] Tag suggestion request failed: empty response")
            root.tagSuggestion(q, [])
            return
        }

        try {
            if (requestedProvider !== "wallhaven") {
                const provider = Booru.providers[requestedProvider]
                const payload = JSON.parse(text)
                const results = provider?.tagMapFunc ? provider.tagMapFunc(payload) : []
                root._storeTagSuggestion(requestedProvider + ":" + q,
                    { ts: root.nowMs, items: results })
                root._lastTagSuggestionQuery = q
                root._lastTagSuggestionProvider = requestedProvider
                root._lastTagSuggestions = results
                root.tagSuggestion(q, results)
                return
            }

            const results = root._parseTagSuggestionsFromHtml(text)
            if (results.length === 0 && preferQuoted) {
                Qt.callLater(() => root.triggerTagSearch(q, false, "wallhaven"))
                return
            }

            const enriched = results.map(s => {
                const id = s?.id ?? ""
                if (id.length === 0)
                    return s
                const cachedCount = root._tagCountCache[id]
                if (cachedCount && (root.nowMs - (cachedCount.ts || 0) < root.tagCountCacheMs))
                    return { id: s.id, name: s.name, count: cachedCount.total }
                root._queueTagCount(id)
                return s
            })

            root._storeTagSuggestion("wallhaven:" + q, { ts: root.nowMs, items: enriched })
            root._lastTagSuggestionQuery = q
            root._lastTagSuggestionProvider = "wallhaven"
            root._lastTagSuggestions = enriched
            root.tagSuggestion(q, enriched)
        } catch (e) {
            console.log("[Wallhaven] Failed to parse", requestedProvider, "tag suggestions:", e)
            root.tagSuggestion(q, [])
        }
    }

    function _applyTagsToResponses(id, tagsJoined) {
        for (let r = 0; r < responses.length; ++r) {
            const resp = responses[r]
            if (!resp || resp.provider !== "wallhaven" || !resp.images)
                continue
            let changed = false
            for (let i = 0; i < resp.images.length; ++i) {
                const img = resp.images[i]
                if (img && img.id === id) {
                    img.tags = tagsJoined
                    changed = true
                }
            }
            if (changed) {
                resp.images = [...resp.images]
            }
        }
    }

    function ensureWallpaperTags(id) {
        root.nowMs = Date.now()
        if (!id || id.length === 0)
            return
        if (wallpaperTagCache[id] !== undefined)
            return
        if (wallpaperTagRequests[id])
            return

        if (tagQueue.indexOf(id) === -1) {
            tagQueue = [...tagQueue, id]
        }
    }

    function _fetchNextTag(): void {
        root.nowMs = Date.now()
        if (root.isRateLimited)
            return
        if (root.nowMs < root._nextTagAllowedMs)
            return
        if (!tagQueue || tagQueue.length === 0)
            return
        if (root.tagDetailProcess.running)
            return

        const id = tagQueue[0]
        tagQueue = tagQueue.slice(1)

        if (!id || id.length === 0)
            return
        if (wallpaperTagCache[id] !== undefined)
            return
        if (wallpaperTagRequests[id])
            return

        wallpaperTagRequests[id] = true
        root._nextTagAllowedMs = root.nowMs + root.minTagIntervalMs
        root._tagDetailCurrentId = id

        const url = _detailUrl(id)
        _log("[Wallhaven] Fetching wallpaper tags for", id)
        root.tagDetailProcess.command = ["/usr/bin/curl", "-s", "--max-time", "15", "-H", "User-Agent: " + defaultUserAgent, url]
        root.tagDetailProcess.running = true
    }

    function _handleTagDetailResponse(text): void {
        const id = root._tagDetailCurrentId
        root._tagDetailCurrentId = ""
        delete wallpaperTagRequests[id]

        if (!text || text.length === 0) {
            root._storeWallpaperTags(id, "")
            return
        }

        try {
            var payload = JSON.parse(text)
            var data = payload.data || {}
            var tags = data.tags || []
            var joined = ""
            if (tags && tags.length > 0) {
                joined = tags.map(function(t) { return t.name; }).join(" ")
            }
            root._storeWallpaperTags(id, joined)
            _applyTagsToResponses(id, joined)
        } catch (e) {
            console.log("[Wallhaven] Failed to parse detail response:", e)
            root._storeWallpaperTags(id, "")
        }
    }

    property Timer tagQueueTimer: Timer {
        interval: 350
        repeat: true
        running: root._active || ((root.tagQueue && root.tagQueue.length > 0))
        onTriggered: root._fetchNextTag()
    }

    // Config-driven options
    property string apiKey: (Config.options?.sidebar?.wallhaven?.apiKey ?? "").trim()
    property int defaultLimit: Config.options?.sidebar?.wallhaven?.limit ?? 24
    property bool allowNsfw: Persistent.states?.booru?.allowNsfw ?? false
    property string sortingMode: "toplist"
    property string topRange: "1w"
    property string activeSearchProvider: "wallhaven"
    property var activeSearchTags: []
    property string activeSearchCategory: "111"
    property var activeFitProfile: ({ mode: "auto", width: 1920, height: 1080, ratioCode: "16x9", aspect: 16 / 9 })

    function clearResponses() {
        const previous = root.responses
        root.responses = []
        root._destroyResponsesLater(previous)
    }

    function beginSearch(): void {
        root.searchGeneration += 1
        root.pendingSearch = null
        root.clearResponses()
    }

    function addSystemMessage(message) {
        var resp = wallhavenResponseComponent.createObject(null, {
            "provider": "system",
            "tags": [],
            "page": -1,
            "images": [],
            "message": message
        })
        root._appendResponse(resp)
        responseFinished()
    }

    function _buildSearchUrl(tags, nsfw, limit, page, category, fitProfile) {
        var url = apiSearchEndpoint
        var params = []

        var q = (tags || []).join(" ").trim()
        if (q.length > 0)
            params.push("q=" + encodeURIComponent(q))

        page = page || 1
        params.push("page=" + page)

        var effLimit = (limit && limit > 0) ? limit : defaultLimit
        params.push("per_page=" + effLimit)

        const requestedCategory = ["100", "010", "111"].includes(category)
            ? category : "111"
        params.push("categories=" + requestedCategory)

        const fit = fitProfile ?? root.activeFitProfile
        if (fit?.mode !== "any") {
            if (fit?.ratioCode)
                params.push("ratios=" + encodeURIComponent(fit.ratioCode))
            if (fit?.mode !== "aspect" && fit?.width > 0 && fit?.height > 0) {
                const scale = fit.mode === "native" ? 1.0 : 0.75
                const minimumWidth = Math.max(640, Math.round(fit.width * scale))
                const minimumHeight = Math.max(480, Math.round(fit.height * scale))
                params.push("atleast=" + minimumWidth + "x" + minimumHeight)
            }
        }

        var purity = "100"
        if (nsfw && apiKey && apiKey.length > 0) {
            purity = "111"
        }
        params.push("purity=" + purity)

        // Wallhaven's toplist+query only returns the week's hot posts for the tag
        // (tiny, unpageable sets). Tag searches use the API's default relevance
        // ordering; toplist applies to tagless browsing.
        const hasTags = q.length > 0
        var sorting = sortingMode
        if (hasTags && sorting === "toplist")
            sorting = "relevance"
        if (sorting !== "relevance")
            params.push("sorting=" + sorting)
        if (sorting === "toplist") {
            params.push("order=desc")
            if (topRange.length > 0)
                params.push("topRange=" + topRange)
        }

        if (apiKey && apiKey.length > 0) {
            params.push("apikey=" + encodeURIComponent(apiKey))
        }

        return url + "?" + params.join("&")
    }

    function _buildCommonsUrl(tags, limit, page) {
        const query = (tags || []).join(" ").trim()
        const category = 'incategory:"Featured pictures on Wikimedia Commons"'
        const search = query.length > 0 ? (category + " " + query) : category
        const effectiveLimit = Math.min(50, Math.max(1, (limit && limit > 0) ? limit : defaultLimit))
        const offset = Math.max(0, ((page || 1) - 1) * effectiveLimit)
        return "https://commons.wikimedia.org/w/api.php?action=query&format=json"
            + "&generator=search&gsrnamespace=6&gsrlimit=" + effectiveLimit
            + "&gsroffset=" + offset
            + "&gsrsearch=" + encodeURIComponent(search)
            + "&prop=imageinfo&iiprop=url%7Csize%7Cmime&iiurlwidth=720"
    }

    function makeRequest(tags, nsfw, limit, page, category, generation, providerId, fitProfile) {
        root.nowMs = Date.now()
        if (nsfw === undefined)
            nsfw = allowNsfw

        const requestedProvider = root._normalizedProvider(providerId ?? "wallhaven")
        const requestedTags = Array.isArray(tags) ? [...tags] : []
        const requestedCategory = ["100", "010", "111"].includes(category)
            ? category : root.activeSearchCategory
        const requestedGeneration = Number.isInteger(generation)
            ? generation : root.searchGeneration
        const requestedFit = fitProfile ?? root.activeFitProfile
        root.activeSearchProvider = requestedProvider
        root.activeSearchTags = requestedTags
        if (requestedProvider === "wallhaven")
            root.activeSearchCategory = requestedCategory
        root.activeFitProfile = requestedFit

        if ((requestedProvider === "wallhaven" && root.isRateLimited)
                || runningRequests > 0 || root.searchProcess.running
                || root.nowMs < root._nextSearchAllowedMs) {
            root.pendingSearch = {
                tags: requestedTags,
                nsfw: nsfw,
                limit: limit,
                page: page,
                category: requestedCategory,
                generation: requestedGeneration,
                provider: requestedProvider,
                fitProfile: requestedFit
            }
            // Without an in-flight response to trigger _processPendingSearch,
            // a throttled search would stay queued forever.
            if (runningRequests <= 0)
                root._pendingSearchTimer.restart()
            return
        }

        root._nextSearchAllowedMs = root.nowMs + root.minSearchIntervalMs

        const providerLimit = requestedProvider === "wallhaven"
            ? limit : Math.max(72, limit || 0)
        const url = requestedProvider === "wallhaven"
            ? root._buildSearchUrl(requestedTags, nsfw, providerLimit, page, requestedCategory, requestedFit)
            : requestedProvider === "commons"
                ? root._buildCommonsUrl(requestedTags, providerLimit, page)
                : Booru.constructRequestUrlForProvider(requestedProvider,
                    requestedTags, nsfw, providerLimit, page || 1)
        _log("[Wallhaven] Making", requestedProvider, "request to", url)

        var newResponse = wallhavenResponseComponent.createObject(null, {
            "provider": requestedProvider,
            "tags": requestedTags,
            "page": page || 1,
            "images": [],
            "message": ""
        })

        root._searchToken += 1
        root._activeSearchToken = root._searchToken

        root._currentSearchUrl = url
        root._currentSearchResponse = newResponse
        root._currentSearchProvider = requestedProvider
        root._currentSearchFitProfile = requestedFit
        root._currentSearchDisplayLimit = Math.max(1, Number(limit || root.defaultLimit))
        root._currentSearchGeneration = requestedGeneration
        runningRequests += 1

        const command = ["/usr/bin/curl", "-s", "--max-time", "20", "-w", "\n__HTTP__%{http_code}"]
        if (requestedProvider === "wallhaven")
            command.push("-H", "User-Agent: " + defaultUserAgent)
        else if (requestedProvider === "waifu.im")
            command.push("-H", "Accept-Version: v7")
        command.push(url)
        root.searchProcess.command = command
        root.searchProcess.running = true
    }

    function _extractJsonPayload(text): string {
        const raw = String(text ?? "")
        const objStart = raw.indexOf("{")
        const objEnd = raw.lastIndexOf("}")
        if (objStart >= 0 && objEnd > objStart)
            return raw.substring(objStart, objEnd + 1)
        const arrStart = raw.indexOf("[")
        const arrEnd = raw.lastIndexOf("]")
        if (arrStart >= 0 && arrEnd > arrStart)
            return raw.substring(arrStart, arrEnd + 1)
        return raw.trim()
    }

    function _handleSearchResponse(text): void {
        const token = root._activeSearchToken
        runningRequests = Math.max(0, runningRequests - 1)

        var newResponse = root._currentSearchResponse
        if (!newResponse) {
            root._processPendingSearch()
            return
        }
        if (token !== root._searchToken)
            return

        if (root._currentSearchGeneration !== root.searchGeneration) {
            root._destroyResponsesLater([newResponse])
            if (root._currentSearchResponse === newResponse)
                root._currentSearchResponse = null
            root._processPendingSearch()
            return
        }

        if (!text || text.length === 0) {
            _log("[Wallhaven] Request failed: empty response")
            newResponse.message = failMessage
            root._appendResponse(newResponse)
            root.responseFinished()
            if (root._currentSearchResponse === newResponse)
                root._currentSearchResponse = null
            root._processPendingSearch()
            return
        }

        let httpStatus = 0
        let body = text
        const httpMarker = "\n__HTTP__"
        const httpIdx = text.lastIndexOf("\n__HTTP__")
        if (httpIdx >= 0) {
            body = text.substring(0, httpIdx)
            httpStatus = parseInt(text.substring(httpIdx + httpMarker.length), 10) || 0
        } else {
            const altIdx = text.lastIndexOf("__HTTP__")
            if (altIdx >= 0) {
                body = text.substring(0, altIdx).replace(/\n$/, "")
                httpStatus = parseInt(text.substring(altIdx + 8), 10) || 0
            }
        }
        body = root._extractJsonPayload(body)

        if (httpStatus === 429) {
            root.rateLimitedUntilMs = Date.now() + 30000
            newResponse.message = Translation.tr("Wallhaven rate limit reached. Wait a moment and try again.")
            root._appendResponse(newResponse)
            root.responseFinished()
            root._currentSearchResponse = null
            root._processPendingSearch()
            return
        }
        if (httpStatus > 0 && httpStatus !== 200) {
            _log("[Wallhaven] HTTP", httpStatus)
            if (httpStatus === 401)
                newResponse.message = Translation.tr("Wallhaven rejected your API key. Check the key in settings and that your account allows NSFW.")
            else
                newResponse.message = Translation.tr("Wallhaven request failed (HTTP %1).").arg(httpStatus)
            root._appendResponse(newResponse)
            root.responseFinished()
            root._currentSearchResponse = null
            root._processPendingSearch()
            return
        }

        try {
            let images = []
            if (root._currentSearchProvider === "wallhaven") {
                var payload = JSON.parse(body)
                if (payload && payload.error) {
                    const apiError = String(payload.error)
                    newResponse.message = apiError.toLowerCase().includes("unauthor")
                        ? Translation.tr("Wallhaven rejected your API key. Check the key in settings and that your account allows NSFW.")
                        : Translation.tr("Wallhaven API error: %1").arg(apiError)
                    console.log("[Wallhaven] API error:", apiError)
                    root._appendResponse(newResponse)
                    root.responseFinished()
                    root._currentSearchResponse = null
                    root._processPendingSearch()
                    return
                }
                var list = payload.data || []
                images = list.map(function(item) {
                    var path = item.path || ""
                    var thumbs = item.thumbs || {}
                    var preview = thumbs.small || thumbs.large || path
                    var sample = thumbs.large || path
                    var ratio = 1.0
                    if (item.ratio)
                        ratio = parseFloat(item.ratio)
                    else if (item.dimension_x && item.dimension_y)
                        ratio = item.dimension_x / item.dimension_y
                    var purity = item.purity || "sfw"
                    var isNsfw = purity !== "sfw"
                    var fileExt = path && path.indexOf(".") !== -1
                        ? path.split(".").pop() : ""
                    return {
                        "id": item.id,
                        "width": item.dimension_x,
                        "height": item.dimension_y,
                        "aspect_ratio": ratio,
                        "tags": "",
                        "rating": isNsfw ? "e" : "s",
                        "is_nsfw": isNsfw,
                        "md5": Qt.md5(path || item.id),
                        "preview_url": preview,
                        "sample_url": sample,
                        "file_url": path,
                        "file_ext": fileExt,
                        "source": item.url
                    }
                })
            } else if (root._currentSearchProvider === "commons") {
                const payload = JSON.parse(body)
                const pages = payload?.query?.pages ?? {}
                images = Object.keys(pages).map(key => pages[key]).map(pageData => {
                    const info = pageData?.imageinfo?.[0] ?? {}
                    const width = Number(info.width ?? 0)
                    const height = Number(info.height ?? 0)
                    const originalUrl = info.url ?? ""
                    const mime = info.mime ?? ""
                    const title = String(pageData?.title ?? "").replace(/^File:/, "")
                    return {
                        "id": String(pageData?.pageid ?? key),
                        "width": width,
                        "height": height,
                        "aspect_ratio": width > 0 && height > 0 ? width / height : 1.0,
                        "tags": title,
                        "rating": "s",
                        "is_nsfw": false,
                        "md5": Qt.md5("commons:" + String(pageData?.pageid ?? key)),
                        "preview_url": info.thumburl ?? originalUrl,
                        "sample_url": originalUrl,
                        "file_url": originalUrl,
                        "file_ext": mime.includes("png") ? "png" : mime.includes("webp") ? "webp" : "jpg",
                        "source": info.descriptionurl ?? ("https://commons.wikimedia.org/wiki/" + encodeURIComponent(pageData?.title ?? ""))
                    }
                })
            } else if (root._currentSearchProvider === "picsum") {
                const payload = JSON.parse(body)
                const fit = root._currentSearchFitProfile
                const fitToMonitor = fit?.mode !== "any" && fit?.width > 0 && fit?.height > 0
                images = (Array.isArray(payload) ? payload : []).map(item => {
                    const originalWidth = Number(item.width ?? 0)
                    const originalHeight = Number(item.height ?? 0)
                    const id = String(item.id ?? "")
                    const targetWidth = fitToMonitor ? Math.round(fit.width) : originalWidth
                    const targetHeight = fitToMonitor ? Math.round(fit.height) : originalHeight
                    const targetAspect = targetWidth > 0 && targetHeight > 0
                        ? targetWidth / targetHeight : 1.0
                    const previewWidth = 720
                    const previewHeight = Math.max(240, Math.round(previewWidth / targetAspect))
                    const fittedUrl = fitToMonitor
                        ? "https://picsum.photos/id/" + id + "/" + targetWidth + "/" + targetHeight
                        : (item.download_url ?? "")
                    return {
                        "id": id,
                        "width": targetWidth,
                        "height": targetHeight,
                        "aspect_ratio": targetAspect,
                        "tags": item.author ?? "",
                        "rating": "s",
                        "is_nsfw": false,
                        "md5": Qt.md5("picsum:" + id + ":" + targetWidth + "x" + targetHeight),
                        "preview_url": "https://picsum.photos/id/" + id + "/" + previewWidth + "/" + previewHeight,
                        "sample_url": fittedUrl,
                        "file_url": fittedUrl,
                        "file_ext": "jpg",
                        "source": item.url ?? "https://picsum.photos"
                    }
                })
            } else {
                const provider = Booru.providers[root._currentSearchProvider]
                const payload = provider?.manualParseFunc
                    ? provider.manualParseFunc(body) : JSON.parse(body)
                images = provider?.manualParseFunc
                    ? payload : (provider?.mapFunc ? provider.mapFunc(payload) : [])
            }
            images = root._filterImagesForFit(images, root._currentSearchFitProfile)
            if (images.length > root._currentSearchDisplayLimit)
                images = images.slice(0, root._currentSearchDisplayLimit)
            newResponse.images = images
            if (images.length > 0)
                newResponse.message = ""
            else if ((newResponse.page || 1) > 1)
                newResponse.message = Translation.tr("No more results for this search.")
            else
                newResponse.message = Translation.tr("No wallpapers found for these tags and filters.")
        } catch (e) {
            console.log("[Wallhaven] Failed to parse response:", e)
            newResponse.message = failMessage
        }

        root._appendResponse(newResponse)
        root.responseFinished()
        root._currentSearchResponse = null
        root._processPendingSearch()
    }

    function _filterImagesForFit(images, fitProfile) {
        const fit = fitProfile ?? root.activeFitProfile
        if (!Array.isArray(images) || fit?.mode === "any")
            return images ?? []

        const targetAspect = Number(fit?.aspect ?? 0)
        if (!(targetAspect > 0))
            return images

        const strictResolution = fit?.mode === "native"
        const minimumScale = strictResolution ? 1.0 : 0.70
        const minimumWidth = Math.max(0, Number(fit?.width ?? 0) * minimumScale)
        const minimumHeight = Math.max(0, Number(fit?.height ?? 0) * minimumScale)
        const aspectTolerance = root._currentSearchProvider === "commons"
            ? 0.16 : (fit?.mode === "aspect" ? 0.10 : 0.13)

        return images.filter(image => {
            const width = Number(image?.width ?? 0)
            const height = Number(image?.height ?? 0)
            const aspect = Number(image?.aspect_ratio ?? (width > 0 && height > 0 ? width / height : 0))
            if (!(aspect > 0) || Math.abs(aspect / targetAspect - 1) > aspectTolerance)
                return false
            if (fit?.mode === "aspect")
                return true
            return width >= minimumWidth && height >= minimumHeight
        })
    }

    function _processPendingSearch(): void {
        root.nowMs = Date.now()
        if (root.pendingSearch) {
            const next = root.pendingSearch
            if (root.isRateLimited && next.provider === "wallhaven")
                return
            root.pendingSearch = null
            Qt.callLater(() => root.makeRequest(next.tags, next.nsfw, next.limit,
                next.page, next.category, next.generation, next.provider, next.fitProfile))
        }
    }
}
