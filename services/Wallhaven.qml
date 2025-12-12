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
        if (!id || id.length === 0)
            return
        if (wallpaperTagCache[id] !== undefined)
            return
        if (wallpaperTagRequests[id])
            return

        wallpaperTagRequests[id] = true
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
            wallpaperTagCache[id] = ""
        }
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
        // nsfw/limit/page kept for API parity with Booru.makeRequest
        if (nsfw === undefined)
            nsfw = allowNsfw
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

                    // Fetch real tags per wallpaper (always-on)
                    for (let i = 0; i < images.length; ++i) {
                        if (images[i] && images[i].id) {
                            root.ensureWallpaperTags(images[i].id)
                        }
                    }
                } catch (e) {
                    console.log("[Wallhaven] Failed to parse response:", e)
                    newResponse.message = failMessage
                } finally {
                    finish()
                }
            } else {
                console.log("[Wallhaven] Request failed with status:", xhr.status)
                newResponse.message = failMessage
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
