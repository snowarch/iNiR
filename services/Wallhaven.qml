pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs
import qs.services
import QtQuick

/**
 * Simple wallpaper search service for wallhaven.cc
 * Reuses BooruResponseData so it can be rendered with existing Booru UI components.
 */
QtObject {
    id: root

    property Component wallhavenResponseComponent: BooruResponseData {}

    signal responseFinished()

    signal tagSuggestion(string query, var suggestions)

    property string failMessage: Translation.tr("That didn't work. Tips:\n- Check your query and NSFW settings\n- Make sure your Wallhaven API key is set if you want NSFW")
    property var responses: []
    property int runningRequests: 0

    property string _lastTagSuggestionQuery: ""
    property var _lastTagSuggestions: ([])

    // Wallhaven rate limiting (HTTP 429) can trigger easily when paging quickly.
    // Keep a simple cooldown to prevent request spam and make UI behavior predictable.
    property int nowMs: 0
    property int rateLimitedUntilMs: 0
    readonly property bool isRateLimited: nowMs < rateLimitedUntilMs

    readonly property bool _active: (Config.options?.sidebar?.wallhaven?.enable ?? true) && (GlobalStates?.sidebarLeftOpen ?? false)

    property Timer wallhavenClock: Timer {
        interval: 500
        repeat: true
        running: true
        onTriggered: root.nowMs = Date.now()
    }

    Component.onCompleted: {
        root.nowMs = Date.now()
    }

    // Throttling
    property int minSearchIntervalMs: 1200
    property int minTagIntervalMs: 1200
    property int _nextSearchAllowedMs: 0
    property int _nextTagAllowedMs: 0

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

    property var defaultUserAgent: Config.options?.networking?.userAgent || "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"

    property string tagSuggestionBase: "https://wallhaven.cc/tag/search"
    property int tagSuggestionCacheMs: 5 * 60 * 1000
    property var _tagSuggestionCache: ({})
    property var currentTagRequest: null

    // Cache + queue for counts (meta.total) per tag id
    property int tagCountCacheMs: 10 * 60 * 1000
    property var _tagCountCache: ({}) // id -> { ts, total }
    property var _tagCountRequests: ({}) // id -> bool
    property var _tagCountQueue: ([])

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

        // Match links to /tag/<id> and capture the visible name.
        // Keep this regex intentionally permissive; Wallhaven HTML changes.
        const patterns = [
            // Most robust: capture the entire anchor contents (can include nested spans/icons), then strip tags.
            new RegExp('href=["\'](?:https?:\\/\\/wallhaven\\.cc)?\\/tag\\/(\\d+)["\'][^>]*>([\\s\\S]*?)<\\/a>', 'g'),
            // href=/tag/123 ... </a>
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

        const id = root._tagCountQueue[0]
        root._tagCountQueue = root._tagCountQueue.slice(1)
        if (!id || id.length === 0)
            return
        if (root._tagCountRequests[id])
            return

        root._tagCountRequests[id] = true
        root._nextTagAllowedMs = root.nowMs + root.minTagIntervalMs

        const url = root.apiSearchEndpoint + "?q=" + encodeURIComponent("id:" + id) + "&page=1&per_page=1&categories=111&purity=100&sorting=date_added&order=desc" + ((apiKey && apiKey.length > 0) ? ("&apikey=" + encodeURIComponent(apiKey)) : "")
        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        try {
            xhr.setRequestHeader("User-Agent", defaultUserAgent)
        } catch (e) {
        }
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return

            root._tagCountRequests[id] = false

            if (xhr.status === 200) {
                try {
                    const payload = JSON.parse(xhr.responseText)
                    const meta = payload.meta || {}
                    const total = meta.total !== undefined ? parseInt(meta.total) : 0
                    root._tagCountCache[id] = { ts: root.nowMs, total: total }

                    // Re-emit last suggestions if they include this id
                    if (root._lastTagSuggestions && root._lastTagSuggestions.length > 0) {
                        let changed = false
                        const updated = root._lastTagSuggestions.map(s => {
                            if (s && s.id === id) {
                                const next = {
                                    id: s.id,
                                    name: s.name,
                                    count: total
                                }
                                changed = true
                                return next
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
            } else if (xhr.status === 429) {
                root.rateLimitedUntilMs = root.nowMs + 30000
                // requeue
                root._tagCountRequests[id] = false
                if (root._tagCountQueue.indexOf(id) === -1) {
                    root._tagCountQueue = [...root._tagCountQueue, id]
                }
            }
        }
        try {
            xhr.send()
        } catch (e) {
            console.log("[Wallhaven] Error sending tag count request:", e)
            root._tagCountRequests[id] = false
        }
    }

    function triggerTagSearch(query, preferQuoted) {
        root.nowMs = Date.now()
        const q = (query || "").trim()
        if (q.length === 0)
            return

        if (preferQuoted === undefined)
            preferQuoted = true

        if (currentTagRequest) {
            currentTagRequest.abort()
        }

        const cached = root._tagSuggestionCache[q]
        if (cached && (root.nowMs - (cached.ts || 0) < root.tagSuggestionCacheMs)) {
            root.tagSuggestion(q, cached.items || [])
            return
        }

        const searchQ = preferQuoted ? ("\"" + q + "\"") : q
        const url = root.tagSuggestionBase + "?q=" + encodeURIComponent(searchQ)
        var xhr = new XMLHttpRequest()
        currentTagRequest = xhr
        xhr.open("GET", url)
        try {
            xhr.setRequestHeader("User-Agent", defaultUserAgent)
        } catch (e) {
            // Ignore if platform disallows setting UA
        }
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return

            if (currentTagRequest === xhr) {
                currentTagRequest = null
            }

            if (xhr.status !== 200) {
                console.log("[Wallhaven] Tag suggestion request failed:", xhr.status, url)
                root.tagSuggestion(q, [])
                return
            }

            try {
                const html = xhr.responseText || ""
                const results = root._parseTagSuggestionsFromHtml(html)
                // Fallback: wallhaven tag search sometimes responds better without quotes.
                if (results.length === 0 && preferQuoted) {
                    Qt.callLater(() => root.triggerTagSearch(q, false))
                    return
                }

                // Attach counts if cached and queue count fetches for missing
                const enriched = results.map(s => {
                    const id = s?.id ?? ""
                    if (id.length === 0)
                        return s
                    const cachedCount = root._tagCountCache[id]
                    if (cachedCount && (root.nowMs - (cachedCount.ts || 0) < root.tagCountCacheMs)) {
                        return {
                            id: s.id,
                            name: s.name,
                            count: cachedCount.total
                        }
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

        try {
            xhr.send()
        } catch (e) {
            console.log("[Wallhaven] Error sending tag suggestion request:", e)
            currentTagRequest = null
            root.tagSuggestion(q, [])
        }
    }

    function _applyTagsToResponses(id, tagsJoined) {
        // Update any existing response images with this id
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
                // Re-assign to trigger bindings
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

        // Queue tag fetches to avoid request storms.
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

        // Pop front
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

        var url = _detailUrl(id)
        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return

            wallpaperTagRequests[id] = false

            if (xhr.status === 200) {
                try {
                    var payload = JSON.parse(xhr.responseText)
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
            } else if (xhr.status === 429) {
                // Backoff and retry later
                root.rateLimitedUntilMs = root.nowMs + 30000
                wallpaperTagCache[id] = undefined
                if (tagQueue.indexOf(id) === -1) {
                    tagQueue = [...tagQueue, id]
                }
            } else {
                // Cache empty to avoid retry storms
                wallpaperTagCache[id] = ""
            }
        }
        try {
            xhr.send()
        } catch (e) {
            console.log("[Wallhaven] Error sending detail request:", e)
            wallpaperTagRequests[id] = false
            // Retry later
            if (tagQueue.indexOf(id) === -1) {
                tagQueue = [...tagQueue, id]
            }
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
    // Reuse global NSFW toggle used by Anime boorus for now
    property bool allowNsfw: Persistent.states?.booru?.allowNsfw ?? false
    // Listing mode: "toplist", "date_added", "random", etc.
    property string sortingMode: "date_added"
    // Toplist range when sortingMode == "toplist": 1d, 3d, 1w, 1M, 3M, 6M, 1y
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

        // categories: general, anime, people -> 111 = all
        params.push("categories=111")

        // purity: 100 = sfw, 110 = sfw+sketchy, 111 = sfw+sketchy+nsfw
        var purity = "100" // default: SFW only
        if (nsfw && apiKey && apiKey.length > 0) {
            purity = "111"
        }
        params.push("purity=" + purity)

        // Sorting / listing mode
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
        // nsfw/limit/page kept for API parity with Booru.makeRequest
        if (nsfw === undefined)
            nsfw = allowNsfw

        // Coalesce requests: if something is already running or we are rate limited,
        // keep only the latest request and retry automatically.
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
        console.log("[Wallhaven] Making request to", url)

        var newResponse = wallhavenResponseComponent.createObject(null, {
            "provider": "wallhaven",
            "tags": tags,
            "page": page || 1,
            "images": [],
            "message": ""
        })

        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return

            function finish() {
                runningRequests = Math.max(0, runningRequests - 1)
                responses = [...responses, newResponse]
                root.responseFinished()

                if (root.pendingSearch && !root.isRateLimited) {
                    const next = root.pendingSearch
                    root.pendingSearch = null
                    Qt.callLater(() => root.makeRequest(next.tags, next.nsfw, next.limit, next.page))
                }
            }

            if (xhr.status === 200) {
                try {
                    var payload = JSON.parse(xhr.responseText)
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
                        // Wallhaven search results typically do not include per-wallpaper tags.
                        // We fill tags via the detail endpoint asynchronously.
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
                } finally {
                    finish()
                }
            } else {
                console.log("[Wallhaven] Request failed with status:", xhr.status)
                if (xhr.status === 429) {
                    // 30s cooldown (simple backoff). Keep message user-friendly.
                    root.rateLimitedUntilMs = root.nowMs + 30000
                    newResponse.message = Translation.tr("Wallhaven rate-limited (HTTP 429). Please wait ~30s and try again.")
                } else {
                    newResponse.message = failMessage
                }
                finish()
            }
        }

        try {
            runningRequests += 1
            xhr.send()
        } catch (e) {
            console.log("[Wallhaven] Error sending request:", e)
            runningRequests = Math.max(0, runningRequests - 1)
            newResponse.message = failMessage
            responses = [...responses, newResponse]
            root.responseFinished()
        }
    }
}
