pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.settings
import qs.modules.iris.style
import qs.modules.iris.widgets
import qs.modules.background.widgets

// What Spotlight can do besides apps, by area: every switch and pick Settings shows (IrisOptions.quickActions),
// every other option and section as a way into Settings, the themes, and the shell's actions that act under
// iRiS. Matching forgives: word starts, initials ("nl" → Night light), one typo, letters in order ("nght"),
// and the short words people type ("bt", "dnd", "wifi"). Typing an area's name lists that area.
Singleton {
    id: root

    // Actions that only mean something in another family.
    readonly property var otherFamilyActions: ["toggle-bar-autohide", "toggle-dock", "toggle-dashboard", "toggle-media-controls",
        "wallpaper-coverflow", "open-sidebar-left", "open-sidebar-right", "switch-family-iris"]
    readonly property var categoryAreas: ({ system: "System", tools: "Tools", media: "Media", appearance: "Appearance", settings: "General", setup: "System" })
    readonly property var aliases: ({
        bt: ["bluetooth"], wifi: ["wi-fi", "wireless", "network"], wlan: ["wi-fi", "network"], dnd: ["disturb", "silent"],
        vol: ["volume"], mic: ["microphone"], ss: ["screenshot"], rec: ["record"], wp: ["wallpaper"], wall: ["wallpaper"],
        cc: ["control"], kb: ["keyboard"], bg: ["wallpaper", "background"], notif: ["notifications"], notifs: ["notifications"],
        anim: ["motion", "animations"], perf: ["performance", "low power"]
    })

    function fold(text: string): string {
        let out = String(text ?? "").toLowerCase()
        if (typeof out.normalize === "function") out = out.normalize("NFD").replace(/[̀-ͯ]/g, "")
        return out
    }
    function tokens(text: string): var { return root.fold(text).split(/[^a-z0-9]+/).filter(part => part.length > 0) }

    // One edit (insert, delete, substitute or swap) apart, for words long enough that a typo is likely.
    function near(a: string, b: string, limit: int): bool {
        if (Math.abs(a.length - b.length) > limit) return false
        const prev2 = [], prev = [], cur = []
        for (let j = 0; j <= b.length; j++) prev[j] = j
        for (let i = 1; i <= a.length; i++) {
            cur[0] = i
            let best = cur[0]
            for (let j = 1; j <= b.length; j++) {
                const cost = a[i - 1] === b[j - 1] ? 0 : 1
                let v = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
                if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1]) v = Math.min(v, prev2[j - 2] + 1)
                cur[j] = v
                best = Math.min(best, v)
            }
            if (best > limit) return false
            for (let j = 0; j <= b.length; j++) { prev2[j] = prev[j]; prev[j] = cur[j] }
        }
        return prev[b.length] <= limit
    }
    // near(a, b, 1) in one pass: equal, or one insert, delete, substitute or adjacent swap apart. The full
    // table above ran for every token of ~600 entries per key and cost 20-30 ms on the GUI thread.
    function oneEdit(a: string, b: string): bool {
        const la = a.length, lb = b.length
        if (la - lb > 1 || lb - la > 1) return false
        let i = 0
        while (i < la && i < lb && a[i] === b[i]) i++
        if (la === lb) {
            if (i === la || a.slice(i + 1) === b.slice(i + 1)) return true
            return i + 1 < la && a[i] === b[i + 1] && a[i + 1] === b[i] && a.slice(i + 2) === b.slice(i + 2)
        }
        return la > lb ? a.slice(i + 1) === b.slice(i) : a.slice(i) === b.slice(i + 1)
    }
    function inOrder(word: string, token: string): bool {
        if (word.length < 3 || token[0] !== word[0]) return false
        let at = 0
        for (const ch of token) if (ch === word[at] && ++at === word.length) return true
        return false
    }

    // How well one typed word reads as part of an entry, 0 to 1.
    function wordScore(word: string, entry: var): real {
        let best = 0
        for (const token of entry.nameTokens) {
            if (token === word) return 1
            if (word.length >= 2 && token.startsWith(word)) best = Math.max(best, 0.92)
            else if (word.length >= 4) {
                const head = token.slice(0, Math.max(word.length, Math.min(token.length, word.length + 1)))
                if (word.length >= 8 ? root.near(word, head, 2) : root.oneEdit(word, head)) best = Math.max(best, 0.72)
                else if (root.inOrder(word, token)) best = Math.max(best, 0.55)
            }
            else if (root.inOrder(word, token)) best = Math.max(best, 0.55)
        }
        // Initials: whole ("nl" → Night light) or three letters in; two letters of a longer name are a guess.
        if (word.length >= 2 && entry.initials.startsWith(word))
            best = Math.max(best, entry.initials === word || word.length >= 3 ? 0.88 : 0.6)
        for (const token of entry.otherTokens) {
            if (token === word) best = Math.max(best, 0.8)
            else if (word.length >= 3 && token.startsWith(word)) best = Math.max(best, 0.7)
        }
        // A word that only turns up in the description ranks under one the row is named or keyworded by.
        for (const token of entry.describedTokens) {
            if (token === word) best = Math.max(best, 0.64)
            else if (word.length >= 3 && token.startsWith(word)) best = Math.max(best, 0.6)
        }
        if (best < 0.6 && word.length >= 3 && entry.flat.includes(word)) best = 0.6
        return best
    }
    readonly property var parsed: ({ query: null, words: [], aliasParts: [], whole: "" })
    function parse(query: string): var {
        if (root.parsed.query !== query) {
            const words = root.tokens(query)
            root.parsed.words = words
            root.parsed.aliasParts = words.map(word => (root.aliases[word] ?? []).map(alias => root.tokens(alias)))
            root.parsed.whole = root.fold(query).trim()
            root.parsed.query = query
        }
        return root.parsed
    }
    function score(query: string, entry: var): real {
        const q = root.parse(query)
        const words = q.words
        if (words.length === 0) return 0
        let sum = 0
        for (let w = 0; w < words.length; w++) {
            let best = root.wordScore(words[w], entry)
            for (const own of q.aliasParts[w]) {
                const s = own.reduce((acc, part) => Math.min(acc, root.wordScore(part, entry)), 1)
                best = Math.max(best, s * 0.97)
            }
            if (best <= 0) return 0
            sum += best
        }
        return sum / words.length + (entry.foldedName.startsWith(q.whole) ? 0.05 : 0)
    }
    function prepare(entry: var): var {
        const name = String(entry.name ?? "")
        entry.foldedName = root.fold(name)
        entry.nameTokens = root.tokens(name + " " + (entry.english ?? ""))
        entry.initials = root.tokens(name).map(token => token[0]).join("")
        entry.otherTokens = root.tokens([entry.detail ?? "", entry.areaName ?? "", entry.words ?? ""].join(" "))
        entry.describedTokens = root.tokens(entry.description ?? "")
        entry.flat = entry.nameTokens.join("")
        return entry
    }

    // A desktop widget found by name: shown on the desktop when it is there, added first when it is not. Arranging
    // is where a widget is found, so this enters it and selects the widget.
    function findWidget(key: string, on: bool): void {
        if (!on) DesktopWidgetLayout.setGloballyEnabled(key, true)
        GlobalStates.setWidgetEditMode(true)
        GlobalStates.selectDesktopWidget((GlobalStates.focusedScreen?.name ?? "") + "::" + key)
    }
    function widgetEntries(): var {
        const output = GlobalStates.focusedScreen?.name ?? ""
        const found = IrisFaceData.galleryEntries.concat(IrisFaceData.otherEntries)
        for (const custom of (CustomWidgets.ready ? CustomWidgets.widgets : []))
            found.push({ key: "custom." + custom.id, glyph: custom.icon || "widgets", english: custom.name, label: custom.name, tint: DesktopWidgetIdentity.customTint })
        return found.map(widget => {
            const on = DesktopWidgetLayout.enabled(output, widget.key, Config.getNestedValue("background.widgets." + widget.key + ".enable", false))
            return root.prepare({ name: widget.label, english: widget.english, detail: on ? Translation.tr("On the desktop") : Translation.tr("Not on the desktop"),
                area: "widgets", areaName: Translation.tr("Widgets"), words: widget.key + " " + DesktopWidgetIdentity.keywordsOf(widget.key),
                icon: widget.glyph, tint: widget.tint, kind: "widget", on: on, keepOpen: false, priority: 250,
                run: () => root.findWidget(widget.key, on) })
        })
    }

    function openSettings(where: string): void {
        const page = SettingsPageRegistry.pages.findIndex(entry => entry.key === "iris")
        if (page >= 0) GlobalStates.openSettingsPage(page, where)
        else GlobalStates.openSettings()
    }

    function build(): var {
        const out = []
        const quick = IrisOptions.quickActions()
        for (const action of quick) out.push(root.prepare({
            name: action.name, english: action.english ?? "", detail: action.detail, area: action.area ?? "", areaName: action.areaName ?? "",
            words: action.words, icon: action.icon, tint: action.tint, kind: action.pick ? "pick" : "switch",
            isOn: action.isOn, pick: Boolean(action.pick), keepOpen: true, run: action.run, priority: action.priority ?? 100 }))
        for (const action of GlobalActions.allActions) {
            const id = String(action.id ?? "")
            if (id.startsWith("style-") || root.otherFamilyActions.includes(id)) continue
            const area = root.categoryAreas[String(action.category ?? "")] ?? "Tools"
            const toggles = typeof action.isOn === "function"
            out.push(root.prepare({ name: action.name, detail: action.description ?? "", area: String(action.category ?? ""), areaName: Translation.tr(area),
                words: [id].concat(action.keywords ?? []).join(" "), icon: action.icon ?? "bolt", tint: IrisStyle.identity.purple,
                kind: "run", isOn: toggles ? action.isOn : null, keepOpen: toggles, run: () => action.execute(""), priority: toggles ? 10 : 200 }))
        }
        for (const widget of root.widgetEntries()) out.push(widget)
        const flipped = new Set(quick.map(action => String(action.id ?? "").replace(/^set:/, "").split("=")[0]))
        for (const section of IrisOptions.sections) {
            const title = Translation.tr(section.title)
            out.push(root.prepare({ name: title, english: section.title, detail: Translation.tr(section.subtitle ?? ""), area: section.id, areaName: title,
                words: "settings", icon: section.icon, tint: section.tint, kind: "section", keepOpen: false, priority: 300,
                run: () => root.openSettings(section.id) }))
        }
        for (const spec of IrisOptions.settings) {
            const path = String(spec.path ?? "")
            if (path.length === 0 || flipped.has(path) || spec.mirror || !IrisOptions.shown(spec) || !spec.label) continue
            const section = IrisOptions.sectionById(String(spec.section ?? ""))
            const group = String(spec.group ?? "")
            out.push(root.prepare({ name: Translation.tr(spec.label), english: spec.label,
                detail: Translation.tr(section.title) + (group ? " › " + Translation.tr(group) : ""), area: section.id, areaName: Translation.tr(section.title),
                words: [group, section.title].concat(spec.keywords ?? []).join(" "), description: spec.description ?? "", icon: IrisOptions.groupGlyphs[group] ?? section.icon, tint: section.tint,
                kind: "setting", keepOpen: false, priority: 400, run: () => root.openSettings(group ? section.id + "/" + group : section.id) }))
        }
        return out
    }
    // Rebuilt once per config revision, and only when someone searches.
    readonly property var cache: ({ revision: -1, entries: [] })
    function entries(): var {
        if (root.cache.revision !== Config.revision || root.cache.entries.length === 0) {
            root.cache.entries = root.build()
            root.cache.revision = Config.revision
        }
        return root.cache.entries
    }

    // Everything that answers the query, best first. An area's name lists what lives there.
    function search(query: string): var {
        const all = root.entries()
        const whole = root.fold(query).trim()
        if (whole.length === 0) return []
        const areas = new Set(all.filter(entry => entry.kind === "section" && whole.length >= 3
            && root.tokens(entry.name + " " + (entry.english ?? "")).some(token => token.startsWith(whole))).map(entry => entry.area))
        const hits = []
        for (const entry of all) {
            let s = root.score(query, entry)
            if (areas.has(entry.area) && entry.kind !== "section") s = Math.max(s, 0.66)
            if (s > 0) hits.push({ entry: entry, score: s })
        }
        hits.sort((a, b) => b.score - a.score || a.entry.priority - b.entry.priority)
        return hits
    }
}
