pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs
import qs.services
import QtQuick
import Quickshell.Io

/**
 * Simple wallpaper search service for wallhaven.cc
 * Reuses BooruResponseData so it can be rendered with existing Booru UI components.
 * Uses curl for HTTP requests to properly set User-Agent header (XMLHttpRequest in Qt
 * doesn't allow setting restricted headers like User-Agent).
 */
QtObject {
    id: root

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(...args);
    }

    property Component wallhavenResponseComponent: BooruResponseData {}

    signal responseFinished()
    signal tagSuggestion(string query, var suggestions)

    property string failMessage: Translation.tr("That didn't work. Tips:\n- Check your query and NSFW settings\n- Make sure your Wallhaven API key is set if you want NSFW")
    property var responses: []
    property int runningRequests: 0

    property string _lastTagSuggestionQuery: ""
    property var _lastTagSuggestions: ([])

    // Wallhaven rate limiting (HTTP 429) can trigger easily when paging quickly.
    property real nowMs: Date.now()
    property real rateLimitedUntilMs: 0
    readonly property bool isRateLimited: nowMs < rateLimitedUntilMs

    readonly property bool _active: (Config.options?.sidebar?.wallhaven?.enable ?? true) && (GlobalStates?.sidebarLeftOpen ?? false)

    property Timer wallhavenClock: Timer {
        interval: 500
        repeat: true
        running: root._active
        onTriggered: root.nowMs = Date.now()
    }

    Component.onCompleted: {
        root.nowMs = Date.now()
    }

    // Throttling
    property int minSearchIntervalMs: 1200
    property int minTagIntervalMs: 1200
    property real _nextSearchAllowedMs: 0
    property real _nextTagAllowedMs: 0

    // Pending search request (coalesced)
    property var pendingSearch: null

    property Timer pendingSearchTimer: Timer {
        interval: 300
        repeat: true
        running: root._active || (root.pendingSearch !== null)
        onTriggered: {
            if (!root.pendingSearch)
                return
            if (root.isRateLimited)
                return
            if (root.runningRequests > 0)
                return
            if (root.nowMs < root._nextSearchAllowedMs)
                return

            const next = root.pendingSearch
            root.pendingSearch = null
            root.makeRequest(next.tags, next.nsfw, next.limit, next.page)
        }
    }

    // Tag fetch queue
    property var tagQueue: ([])
    property var wallpaperTagCache: ({})
    property var wallpaperTagRequests: ({})

    // Basic settings
    readonly property string apiBase: "https://wallhaven.cc/api/v1"
    readonly property string apiSearchEndpoint: apiBase + "/search"

    property string defaultUserAgent: Config.options?.networking?.userAgent || "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"

    property string tagSuggestionBase: "https://wallhaven.cc/tag/search"
    property int tagSuggestionCacheMs: 5 * 60 * 1000
    property var _tagSuggestionCache: ({})
    property var currentTagRequest: null

    // Cache + queue for counts (meta.total) per tag id
    property int tagCountCacheMs: 10 * 60 * 1000
    property var _tagCountCache: ({})
    property var _tagCountRequests: ({})
    property var _tagCountQueue: ([])

    // Process for main search requests
    property var _currentSearchUrl: ""
    property var _currentSearchResponse: null

    property Process searchProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root._handleSearchResponse(text)
            }
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
        root._tagCountRequests[id] = false
        root._tagCountCurrentId = ""

        if (!text || text.length === 0) {
            return
        }

        try {
            const payload = JSON.parse(text)
            const meta = payload.meta || {}
            const total = meta.total !== undefined ? parseInt(meta.total) : 0
            root._tagCountCache[id] = { ts: root.nowMs, total: total }

            if (root._lastTagSuggestions && root._lastTagSuggestions.length > 0) {
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

    function triggerTagSearch(query, preferQuoted) {
        root.nowMs = Date.now()
        const q = (query || "").trim()
        if (q.length === 0)
            return

        if (preferQuoted === undefined)
            preferQuoted = true

        if (root.tagSuggestionProcess.running) {
            root.tagSuggestionProcess.running = false
        }

        const cached = root._tagSuggestionCache[q]
        if (cached && (root.nowMs - (cached.ts || 0) < root.tagSuggestionCacheMs)) {
            root.tagSuggestion(q, cached.items || [])
            return
        }

        const searchQ = preferQuoted ? ("\"" + q + "\"") : q
        const url = root.tagSuggestionBase + "?q=" + encodeURIComponent(searchQ)
        
        root._tagSuggestionQuery = q
        root._tagSuggestionPreferQuoted = preferQuoted
        
        _log("[Wallhaven] Fetching tag suggestions for", q)
        root.tagSuggestionProcess.command = ["/usr/bin/curl", "-s", "--max-time", "15", "-H", "User-Agent: " + defaultUserAgent, url]
        root.tagSuggestionProcess.running = true
    }

    function _handleTagSuggestionResponse(text): void {
        const q = root._tagSuggestionQuery
        const preferQuoted = root._tagSuggestionPreferQuoted

        if (!text || text.length === 0) {
            _log("[Wallhaven] Tag suggestion request failed: empty response")
            root.tagSuggestion(q, [])
            return
        }

        try {
            const results = root._parseTagSuggestionsFromHtml(text)
            
            if (results.length === 0 && preferQuoted) {
                Qt.callLater(() => root.triggerTagSearch(q, false))
                return
            }

            const enriched = results.map(s => {
                const id = s?.id ?? ""
                if (id.length === 0)
                    return s
                const cachedCount = root._tagCountCache[id]
                if (cachedCount && (root.nowMs - (cachedCount.ts || 0) < root.tagCountCacheMs)) {
                    return { id: s.id, name: s.name, count: cachedCount.total }
                }
                root._queueTagCount(id)
                return s
            })

            root._tagSuggestionCache[q] = { ts: root.nowMs, items: enriched }
            root._lastTagSuggestionQuery = q
            root._lastTagSuggestions = enriched
            root.tagSuggestion(q, enriched)
        } catch (e) {
            console.log("[Wallhaven] Failed to parse tag suggestions:", e)
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
        wallpaperTagRequests[id] = false

        if (!text || text.length === 0) {
            wallpaperTagCache[id] = ""
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
            wallpaperTagCache[id] = joined
            _applyTagsToResponses(id, joined)
        } catch (e) {
            console.log("[Wallhaven] Failed to parse detail response:", e)
            wallpaperTagCache[id] = ""
        }
    }

    property Timer tagQueueTimer: Timer {
        interval: 350
        repeat: true
        running: root._active || ((root.tagQueue && root.tagQueue.length > 0))
        onTriggered: root._fetchNextTag()
    }

    // Config-driven options
    property string apiKey: Config.options?.sidebar?.wallhaven?.apiKey ?? ""
    property int defaultLimit: Config.options?.sidebar?.wallhaven?.limit ?? 24
    property bool allowNsfw: Persistent.states?.booru?.allowNsfw ?? false
    property string sortingMode: "date_added"
    property string topRange: "1M"

    function clearResponses() {
        responses = []
    }

    function addSystemMessage(message) {
        var resp = wallhavenResponseComponent.createObject(null, {
            "provider": "system",
            "tags": [],
            "page": -1,
            "images": [],
            "message": message
        })
        responses = [...responses, resp]
        responseFinished()
    }

    function _buildSearchUrl(tags, nsfw, limit, page) {
        var url = apiSearchEndpoint
        var params = []

        var q = (tags || []).join(" ").trim()
        if (q.length > 0)
            params.push("q=" + encodeURIComponent(q))

        page = page || 1
        params.push("page=" + page)

        var effLimit = (limit && limit > 0) ? limit : defaultLimit
        params.push("per_page=" + effLimit)

        params.push("categories=111")

        var purity = "100"
        if (nsfw && apiKey && apiKey.length > 0) {
            purity = "111"
        }
        params.push("purity=" + purity)

        var sorting = sortingMode
        params.push("sorting=" + sorting)
        params.push("order=desc")
        if (sorting === "toplist" && topRange.length > 0) {
            params.push("topRange=" + topRange)
        }

        if (apiKey && apiKey.length > 0) {
            params.push("apikey=" + encodeURIComponent(apiKey))
        }

        return url + "?" + params.join("&")
    }

    function makeRequest(tags, nsfw, limit, page) {
        root.nowMs = Date.now()
        if (nsfw === undefined)
            nsfw = allowNsfw

        if (root.isRateLimited || runningRequests > 0 || root.nowMs < root._nextSearchAllowedMs) {
            root.pendingSearch = {
                tags: tags,
                nsfw: nsfw,
                limit: limit,
                page: page
            }
            return
        }

        root._nextSearchAllowedMs = root.nowMs + root.minSearchIntervalMs

        var url = _buildSearchUrl(tags, nsfw, limit, page)
        _log("[Wallhaven] Making request to", url)

        var newResponse = wallhavenResponseComponent.createObject(null, {
            "provider": "wallhaven",
            "tags": tags,
            "page": page || 1,
            "images": [],
            "message": ""
        })

        root._currentSearchUrl = url
        root._currentSearchResponse = newResponse
        runningRequests += 1

        root.searchProcess.command = ["/usr/bin/curl", "-s", "--max-time", "20", "-H", "User-Agent: " + defaultUserAgent, url]
        root.searchProcess.running = true
    }

    function _handleSearchResponse(text): void {
        runningRequests = Math.max(0, runningRequests - 1)
        
        var newResponse = root._currentSearchResponse
        if (!newResponse) {
            root._processPendingSearch()
            return
        }

        if (!text || text.length === 0) {
            _log("[Wallhaven] Request failed: empty response")
            newResponse.message = failMessage
            responses = [...responses, newResponse]
            root.responseFinished()
            root._currentSearchResponse = null
            root._processPendingSearch()
            return
        }

        try {
            var payload = JSON.parse(text)
            var list = payload.data || []
            var images = list.map(function(item) {
                var path = item.path || ""
                var thumbs = item.thumbs || {}
                var preview = thumbs.small || thumbs.large || path
                var sample = thumbs.large || path
                var ratio = 1.0
                if (item.ratio) {
                    ratio = parseFloat(item.ratio)
                } else if (item.dimension_x && item.dimension_y) {
                    ratio = item.dimension_x / item.dimension_y
                }
                var tagsJoined = ""
                var purity = item.purity || "sfw"
                var isNsfw = purity !== "sfw"
                var fileExt = ""
                if (path && path.indexOf(".") !== -1) {
                    fileExt = path.split(".").pop()
                }
                return {
                    "id": item.id,
                    "width": item.dimension_x,
                    "height": item.dimension_y,
                    "aspect_ratio": ratio,
                    "tags": tagsJoined,
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
            newResponse.images = images
            newResponse.message = images.length > 0 ? "" : failMessage
        } catch (e) {
            console.log("[Wallhaven] Failed to parse response:", e)
            newResponse.message = failMessage
        }

        responses = [...responses, newResponse]
        root.responseFinished()
        root._currentSearchResponse = null
        root._processPendingSearch()
    }

    function _processPendingSearch(): void {
        if (root.pendingSearch && !root.isRateLimited) {
            const next = root.pendingSearch
            root.pendingSearch = null
            Qt.callLater(() => root.makeRequest(next.tags, next.nsfw, next.limit, next.page))
        }
    }
}
