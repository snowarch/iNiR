pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.common
import "root:"
import qs.services

/**
 * AnimeService - AniList GraphQL API
 * Provides anime schedule, seasonal anime, and top airing
 * API Docs: https://anilist.github.io/ApiV2-GraphQL-Docs/
 */
Singleton {
    id: root

    readonly property string apiUrl: "https://graphql.anilist.co"
    
    property var schedule: []
    property var seasonalAnime: []
    property var topAiring: []
    property string currentDay: Qt.formatDate(new Date(), "dddd").toLowerCase()
    
    // Season selection for Seasonal tab
    property string selectedSeason: getCurrentSeason()
    property int selectedYear: new Date().getFullYear()
    readonly property var seasons: ["WINTER", "SPRING", "SUMMER", "FALL"]
    
    function getCurrentSeason(): string {
        const month = new Date().getMonth()
        return month < 3 ? "WINTER" : month < 6 ? "SPRING" : month < 9 ? "SUMMER" : "FALL"
    }
    
    function getSeasonDisplayName(season: string): string {
        const names = { "WINTER": "Winter", "SPRING": "Spring", "SUMMER": "Summer", "FALL": "Fall" }
        return names[season] ?? season
    }
    
    function nextSeason(): void {
        const idx = seasons.indexOf(selectedSeason)
        if (idx === 3) {
            selectedSeason = seasons[0]
            selectedYear++
        } else {
            selectedSeason = seasons[idx + 1]
        }
        invalidateSeasonalCache()
        fetchSeasonalAnime()
    }
    
    function prevSeason(): void {
        const idx = seasons.indexOf(selectedSeason)
        if (idx === 0) {
            selectedSeason = seasons[3]
            selectedYear--
        } else {
            selectedSeason = seasons[idx - 1]
        }
        invalidateSeasonalCache()
        fetchSeasonalAnime()
    }
    
    function invalidateSeasonalCache(): void {
        const timestamps = _cacheTimestamps
        delete timestamps["seasonal"]
        _cacheTimestamps = timestamps
        seasonalAnime = []
    }
    
    property bool loadingSchedule: false
    property bool loadingSeasonal: false
    property bool loadingTop: false
    property bool loading: loadingSchedule || loadingSeasonal || loadingTop
    property string lastError: ""
    
    property var _cacheTimestamps: ({})
    property var _scheduleCache: ({})
    readonly property int cacheValidityMs: 10 * 60 * 1000
    
    // Day to AniList weekday number (1=Monday, 7=Sunday)
    readonly property var _dayToNum: ({
        "monday": 1, "tuesday": 2, "wednesday": 3, "thursday": 4,
        "friday": 5, "saturday": 6, "sunday": 7
    })
    
    function _graphql(query, variables, callback) {
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        const response = JSON.parse(xhr.responseText)
                        if (response.errors) {
                            callback(null, response.errors[0].message)
                        } else {
                            callback(response.data, null)
                        }
                    } catch (e) {
                        callback(null, "Parse error: " + e.message)
                    }
                } else if (xhr.status === 429) {
                    root.lastError = "Rate limited, retrying..."
                    Qt.callLater(() => root._graphql(query, variables, callback), 1000)
                } else {
                    callback(null, "HTTP " + xhr.status)
                }
            }
        }
        xhr.open("POST", root.apiUrl)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.setRequestHeader("Accept", "application/json")
        xhr.send(JSON.stringify({ query, variables }))
    }
    
    function _isCacheValid(key) {
        const timestamp = root._cacheTimestamps[key]
        return timestamp && (Date.now() - timestamp) < root.cacheValidityMs
    }
    
    function _updateCache(key) {
        const timestamps = root._cacheTimestamps
        timestamps[key] = Date.now()
        root._cacheTimestamps = timestamps
    }
    
    function fetchSchedule(day) {
        const targetDay = day === "today" ? root.currentDay : day
        const cacheKey = "schedule_" + targetDay
        
        if (root._isCacheValid(cacheKey) && root._scheduleCache[targetDay]) {
            root.schedule = root._scheduleCache[targetDay]
            return
        }
        
        root.loadingSchedule = true
        root.lastError = ""
        
        const dayNum = root._dayToNum[targetDay] ?? 1
        const isAdult = Config.options?.sidebar?.animeSchedule?.showNsfw ?? false
        
        // Get current airing anime that air on this day
        const query = `
            query ($day: Int, $isAdult: Boolean) {
                Page(perPage: 25) {
                    airingSchedules(airingAt_greater: 0, sort: TIME, notYetAired: false) {
                        media {
                            id
                            title { romaji english native }
                            coverImage { large medium }
                            averageScore
                            episodes
                            status
                            genres
                            studios(isMain: true) { nodes { name } }
                            source
                            format
                            season
                            seasonYear
                            nextAiringEpisode { airingAt episode }
                            siteUrl
                            isAdult
                        }
                        airingAt
                        episode
                    }
                }
            }
        `
        
        // Alternative: fetch currently airing anime and filter by broadcast day
        const scheduleQuery = `
            query ($isAdult: Boolean) {
                Page(perPage: 50) {
                    media(status: RELEASING, type: ANIME, isAdult: $isAdult, sort: POPULARITY_DESC) {
                        id
                        title { romaji english native }
                        coverImage { large medium }
                        averageScore
                        episodes
                        status
                        genres
                        studios(isMain: true) { nodes { name } }
                        source
                        format
                        season
                        seasonYear
                        nextAiringEpisode { airingAt episode }
                        siteUrl
                        isAdult
                    }
                }
            }
        `
        
        root._graphql(scheduleQuery, { isAdult }, (data, error) => {
            root.loadingSchedule = false
            if (error) {
                root.lastError = error
                return
            }
            
            const now = Date.now() / 1000
            const filtered = (data.Page?.media ?? []).filter(anime => {
                if (!anime.nextAiringEpisode) return false
                const airingDate = new Date(anime.nextAiringEpisode.airingAt * 1000)
                const airingDay = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"][airingDate.getDay()]
                return airingDay === targetDay
            })
            
            const normalized = filtered.map(anime => root._normalizeAnime(anime))
            root._scheduleCache[targetDay] = normalized
            root.schedule = normalized
            root._updateCache(cacheKey)
        })
    }
    
    function fetchSeasonalAnime() {
        const cacheKey = "seasonal_" + selectedSeason + "_" + selectedYear
        if (root._isCacheValid(cacheKey) && root.seasonalAnime.length > 0) return
        
        root.loadingSeasonal = true
        root.lastError = ""
        
        const season = selectedSeason
        const year = selectedYear
        const isAdult = Config.options?.sidebar?.animeSchedule?.showNsfw ?? false
        
        const query = `
            query ($season: MediaSeason, $year: Int, $isAdult: Boolean) {
                Page(perPage: 25) {
                    media(season: $season, seasonYear: $year, type: ANIME, isAdult: $isAdult, sort: POPULARITY_DESC) {
                        id
                        title { romaji english native }
                        coverImage { large medium }
                        averageScore
                        episodes
                        status
                        genres
                        studios(isMain: true) { nodes { name } }
                        source
                        format
                        season
                        seasonYear
                        nextAiringEpisode { airingAt episode }
                        siteUrl
                        isAdult
                    }
                }
            }
        `
        
        root._graphql(query, { season, year, isAdult }, (data, error) => {
            root.loadingSeasonal = false
            if (error) {
                root.lastError = error
                return
            }
            root.seasonalAnime = (data.Page?.media ?? []).map(anime => root._normalizeAnime(anime))
            root._updateCache("seasonal_" + season + "_" + year)
        })
    }
    
    function fetchTopAiring() {
        const cacheKey = "top_airing"
        if (root._isCacheValid(cacheKey) && root.topAiring.length > 0) return
        
        root.loadingTop = true
        root.lastError = ""
        
        const isAdult = Config.options?.sidebar?.animeSchedule?.showNsfw ?? false
        
        const query = `
            query ($isAdult: Boolean) {
                Page(perPage: 25) {
                    media(status: RELEASING, type: ANIME, isAdult: $isAdult, sort: SCORE_DESC) {
                        id
                        title { romaji english native }
                        coverImage { large medium }
                        averageScore
                        episodes
                        status
                        genres
                        studios(isMain: true) { nodes { name } }
                        source
                        format
                        season
                        seasonYear
                        nextAiringEpisode { airingAt episode }
                        siteUrl
                        isAdult
                    }
                }
            }
        `
        
        root._graphql(query, { isAdult }, (data, error) => {
            root.loadingTop = false
            if (error) {
                root.lastError = error
                return
            }
            root.topAiring = (data.Page?.media ?? []).map(anime => root._normalizeAnime(anime))
            root._updateCache(cacheKey)
        })
    }
    
    function _normalizeAnime(anime) {
        const nextEp = anime.nextAiringEpisode
        let broadcast = ""
        if (nextEp?.airingAt) {
            const d = new Date(nextEp.airingAt * 1000)
            broadcast = Qt.formatDateTime(d, "ddd hh:mm") + " (Ep " + nextEp.episode + ")"
        }
        
        return {
            id: anime.id,
            title: anime.title?.english ?? anime.title?.romaji ?? "",
            titleEnglish: anime.title?.english ?? anime.title?.romaji ?? "",
            titleJapanese: anime.title?.native ?? "",
            image: anime.coverImage?.large ?? anime.coverImage?.medium ?? "",
            imageSmall: anime.coverImage?.medium ?? "",
            score: (anime.averageScore ?? 0) / 10,
            episodes: anime.episodes ?? "?",
            status: anime.status ?? "",
            airing: anime.status === "RELEASING",
            genres: anime.genres ?? [],
            studios: (anime.studios?.nodes ?? []).map(s => s.name),
            source: anime.source ?? "",
            type: anime.format ?? "TV",
            season: anime.season ?? "",
            year: anime.seasonYear ?? "",
            broadcast,
            url: anime.siteUrl ?? ("https://anilist.co/anime/" + anime.id)
        }
    }
    
    function refresh() {
        root._cacheTimestamps = {}
        root._scheduleCache = {}
        root.fetchSchedule("today")
    }
    
    function getDayName(day) {
        const days = {
            "monday": "Monday", "tuesday": "Tuesday", "wednesday": "Wednesday",
            "thursday": "Thursday", "friday": "Friday", "saturday": "Saturday", "sunday": "Sunday"
        }
        return days[day] ?? day
    }
    
    function formatBroadcast(broadcast) {
        return broadcast ?? ""
    }
    
    Component.onCompleted: {
        if (Config.options?.sidebar?.animeSchedule?.enable) {
            Qt.callLater(() => root.fetchSchedule("today"))
        }
    }
}
