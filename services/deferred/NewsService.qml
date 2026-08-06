pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.common
import qs.services
import "root:"

/**
 * NewsService - Google News RSS (no auth/API key required)
 *
 * Feeds:
 *  - "local": geo headlines for the city resolved by the Weather service
 *    (reuses its manual-location/GPS/IP chain — no duplicate detection here)
 *  - "top": top stories for the user's locale
 *  - topic boards: WORLD, NATION, BUSINESS, TECHNOLOGY, ENTERTAINMENT,
 *    SCIENCE, SPORTS, HEALTH
 */
Singleton {
    id: root

    // Data
    property var articles: []
    property bool loading: false
    property string lastError: ""

    // Cache per feed key
    property var _cache: ({})
    property var _cacheTimestamps: ({})
    readonly property int cacheValidityMs: 15 * 60 * 1000

    readonly property var topics: ["WORLD", "NATION", "BUSINESS", "TECHNOLOGY", "ENTERTAINMENT", "SCIENCE", "SPORTS", "HEALTH"]

    // Locale params for Google News. Qt.locale().name is "es_AR"-style.
    readonly property string _lang: Qt.locale().name.split("_")[0] || "en"
    readonly property string _country: (Qt.locale().name.split("_")[1] || "US")
    readonly property string _localeQuery: `hl=${_lang}&gl=${_country}&ceid=${_country}:${_lang}`

    // City for the geo feed, from Weather's already-resolved location.
    readonly property string localCity: {
        const name = Weather.location?.name ?? ""
        return (Weather.location?.valid ?? false) ? name.split(",")[0].trim() : ""
    }

    function feedUrl(mode, topic) {
        if (mode === "local" && root.localCity.length > 0)
            return `https://news.google.com/rss/headlines/section/geo/${encodeURIComponent(root.localCity)}?${root._localeQuery}`
        if (mode === "topic" && root.topics.includes(topic))
            return `https://news.google.com/rss/headlines/section/topic/${topic}?${root._localeQuery}`
        return `https://news.google.com/rss?${root._localeQuery}`
    }

    function fetch(mode, topic) {
        const url = root.feedUrl(mode, topic)
        if (root._isCacheValid(url) && root._cache[url]) {
            root.articles = root._cache[url]
            return
        }
        root.loading = true
        root.lastError = ""
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            root.loading = false
            if (xhr.status !== 200) {
                root.lastError = "HTTP " + xhr.status
                return
            }
            const parsed = root._parseRss(xhr.responseText)
            root._cache[url] = parsed
            root._cacheTimestamps[url] = Date.now()
            root.articles = parsed
        }
        xhr.open("GET", url)
        xhr.setRequestHeader("User-Agent", Config.options?.networking?.userAgent ?? "Mozilla/5.0")
        xhr.send()
    }

    function refresh(mode, topic) {
        root._cache = {}
        root._cacheTimestamps = {}
        root.fetch(mode, topic)
    }

    function _isCacheValid(key) {
        const ts = root._cacheTimestamps[key]
        return ts ? (Date.now() - ts) < root.cacheValidityMs : false
    }

    // Minimal RSS <item> extraction — Google News items are flat and regular,
    // a full XML parser buys nothing here.
    function _parseRss(xml) {
        const items = []
        const itemRe = /<item>([\s\S]*?)<\/item>/g
        let m
        while ((m = itemRe.exec(xml)) !== null && items.length < 30) {
            const block = m[1]
            const title = root._decodeHtml(root._tag(block, "title"))
            const link = root._tag(block, "link")
            const pubDate = root._tag(block, "pubDate")
            const source = root._decodeHtml(root._tag(block, "source"))
            if (!title || !link)
                continue
            // Google News titles end in " - Source"; strip when source is known.
            const cleanTitle = source && title.endsWith(" - " + source)
                ? title.slice(0, title.length - source.length - 3) : title
            items.push({
                title: cleanTitle,
                url: link,
                source: source,
                timestamp: pubDate ? Date.parse(pubDate) / 1000 : 0
            })
        }
        return items
    }

    function _tag(block, name) {
        const m = block.match(new RegExp(`<${name}[^>]*>([\\s\\S]*?)</${name}>`))
        if (!m)
            return ""
        return m[1].replace(/<!\[CDATA\[([\s\S]*?)\]\]>/, "$1").trim()
    }

    function _decodeHtml(html) {
        if (!html)
            return ""
        return html.replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&apos;/g, "'")
    }

    function formatTime(timestamp) {
        if (!timestamp)
            return ""
        const diff = Date.now() / 1000 - timestamp
        if (diff < 3600)
            return Math.max(1, Math.floor(diff / 60)) + "m"
        if (diff < 86400)
            return Math.floor(diff / 3600) + "h"
        return Math.floor(diff / 86400) + "d"
    }

    function openArticle(article) {
        // Focus an existing browser window first so the link doesn't open unseen.
        if (typeof NiriService !== "undefined" && NiriService.windows) {
            const browserPatterns = ["firefox", "chromium", "chrome", "brave", "zen", "librewolf", "vivaldi", "opera"]
            const windows = NiriService.windows ?? []
            for (let i = 0; i < windows.length; i++) {
                const appId = (windows[i].app_id ?? "").toLowerCase()
                if (browserPatterns.some(p => appId.includes(p))) {
                    NiriService.focusWindow(windows[i].id)
                    break
                }
            }
        }
        Qt.openUrlExternally(article.url)
    }
}
