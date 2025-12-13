pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
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

    property string failMessage: Translation.tr("That didn't work. Tips:\n- Check your query and NSFW settings\n- Make sure your Wallhaven API key is set if you want NSFW")
    property var responses: []
    property int runningRequests: 0

    // Wallhaven rate limiting (HTTP 429) can trigger easily when paging quickly.
    // Keep a simple cooldown to prevent request spam and make UI behavior predictable.
    property int nowMs: 0
    property int rateLimitedUntilMs: 0
    readonly property bool isRateLimited: nowMs < rateLimitedUntilMs

    readonly property bool _active: (Config.options?.sidebar?.wallhaven?.enable ?? false) && (GlobalStates?.sidebarLeftOpen ?? false)

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

    function _detailUrl(id) {
        var url = apiBase + "/w/" + encodeURIComponent(id)
        if (apiKey && apiKey.length > 0) {
            url += "?apikey=" + encodeURIComponent(apiKey)
        }
        return url
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
    property string sortingMode: "toplist"
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
