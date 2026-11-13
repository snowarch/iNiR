pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common

// The door through which anything but Settings itself (a companion, a plugin, IPC) changes the person's settings:
// only the rows the active family's Settings shows, only values those rows allow, every change kept with its way back.
// Rows come from the family (`settings.index` verb): { key, type: bool|number|choice, label, section, description,
// keywords, min, max, step, scale, unit, choices: [{ value, label }] }. A family with a `settings.apply` verb writes
// its own rows (whatever else the row does then happens too); otherwise the door writes Config.
Singleton {
    id: root

    readonly property int historyLimit: 50
    // Newest first: { at, by, steps: [{ key, before, after }] }. Its own file, written only from here: states.json
    // reloads itself when anyone writes it, and a change landing in that window was lost (11-13, a nest run).
    property var history: []
    property var _from: null
    property var _byKey: ({})
    property var _rows: []

    // Every row the active family's Settings can change, by key.
    function index(): var {
        const verb = GlobalStates.familyVerb("settings", "index")
        const listed = verb ? verb() : null
        const rows = Array.isArray(listed) ? listed : []
        if (rows === root._from) return root._byKey
        const byKey = {}, kept = []
        for (const row of rows) {
            const key = String(row?.key ?? "")
            if (!key || key in byKey || !["bool", "number", "choice"].includes(row.type)) continue
            // A key the shell doesn't declare is a row from another version of the family: nothing to write.
            if (Config.getNestedValue(key) === undefined) continue
            byKey[key] = row
            kept.push(row)
        }
        root._from = rows
        root._byKey = byKey
        root._rows = kept
        return byKey
    }

    function row(key: string): var {
        return root.index()[key] ?? null
    }

    function _plain(text: string): string {
        // V4 ignores \p{...} (Qt 6.12): accents go by decomposing all, and NFC puts kana and hangul back together.
        return String(text ?? "").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").normalize("NFC")
    }

    // The rows a phrase names, best first: each word of it must start a word of the row's name, its key, its section,
    // its description or its keywords, in the person's language or in English.
    function find(query: string, limit: int): var {
        const words = root._plain(query).split(/[\s.,;:!?¿¡()\[\]{}"'`\/\\|_+=*&%$#@<>~^\u3000-\u303f\uff01-\uff0f-]+/).filter(word => word.length > 0)
        if (words.length === 0) return []
        root.index()
        const hits = []
        for (const row of root._rows) {
            const fields = [
                [root._plain(Translation.tr(row.label) + " " + row.label), 4],
                [root._plain(Translation.tr(row.section ?? "") + " " + (row.section ?? "") + " " + Translation.tr(row.page ?? "")), 2],
                [root._plain(row.key.replace(/([a-z])([A-Z])/g, "$1 $2").replace(/[.]/g, " ")), 3],
                [root._plain((row.keywords ?? []).join(" ") + " " + Translation.tr(row.description ?? "") + " " + (row.choices ?? []).map(c => Translation.tr(c.label)).join(" ")), 1]
            ]
            let score = 0
            for (const word of words) {
                // A word that starts one of the row's words counts whole; one inside a longer word, half.
                const best = Math.max(...fields.map(([text, weight]) => (" " + text).includes(" " + word) ? weight
                    : word.length >= 4 && text.includes(word) ? weight / 2 : 0))
                if (best === 0) { score = 0; break }
                score += best
            }
            if (score > 0) hits.push({ row: row, score: score + (root._plain(Translation.tr(row.label)) === words.join(" ") ? 10 : 0) })
        }
        hits.sort((a, b) => b.score - a.score)
        return hits.slice(0, limit > 0 ? limit : 8).map(hit => root.describe(hit.row.key))
    }

    // One row as a person reads it: its name and section in their language, its value now, what it allows.
    function describe(key: string): var {
        const row = root.row(key)
        if (!row) return null
        const out = { key: row.key, type: row.type, label: Translation.tr(row.label), section: Translation.tr(row.section ?? ""),
            value: Config.getNestedValue(row.key), shown: root.say(row, Config.getNestedValue(row.key)) }
        if (row.type === "number") Object.assign(out, { min: row.min, max: row.max, step: row.step ?? 0 })
        if (row.type === "choice") out.choices = row.choices.map(choice => ({ value: choice.value, label: Translation.tr(choice.label) }))
        return out
    }

    // A value as its row shows it: On, a choice's name, a number in the row's own unit.
    function say(row: var, value: var): string {
        if (row.type === "bool") return value ? Translation.tr("On") : Translation.tr("Off")
        if (row.type === "choice") {
            const choice = row.choices.find(candidate => candidate.value === value)
            return choice ? Translation.tr(choice.label) : String(value)
        }
        const shown = Math.round(Number(value) * Number(row.scale ?? 1) * 100) / 100
        const unit = row.unit ? Translation.tr(row.unit) : ""
        return String(shown) + (/^[a-z]/i.test(unit) ? " " : "") + unit
    }

    // What a value becomes once it fits its row, or { error }.
    function check(key: string, value: var): var {
        const row = root.row(key)
        if (!row) return { error: "no setting " + key + " in this Settings" }
        if (row.type === "bool") {
            const word = String(value).toLowerCase()
            if (value === true || ["true", "on", "1", "yes"].includes(word)) return { value: true }
            if (value === false || ["false", "off", "0", "no"].includes(word)) return { value: false }
            return { error: key + " is on or off" }
        }
        if (row.type === "number") {
            // "70%" is read the way the row shows it: a 0..1 row shown as a percentage takes 0.7.
            const unit = String(row.unit ?? "").trim()
            const typed = String(value).trim()
            const shown = unit.length > 0 && typed.endsWith(unit) && typed.length > unit.length
            const number = shown ? Number(typed.slice(0, -unit.length)) / Number(row.scale ?? 1) : Number(value)
            const bounds = row.min + " to " + row.max + (row.scale || row.unit ? " (" + root.say(row, row.min) + " to " + root.say(row, row.max) + ")" : "")
            if (typeof value === "boolean" || typed === "" || !Number.isFinite(number))
                return { error: key + " is a number from " + bounds }
            if (number < row.min || number > row.max) return { error: key + " goes from " + bounds }
            const step = Number(row.step ?? 0)
            const snapped = step > 0 ? row.min + Math.round((number - row.min) / step) * step : number
            return { value: Math.round(Math.min(row.max, snapped) * 1e6) / 1e6 }
        }
        const text = root._plain(String(value))
        const choice = row.choices.find(candidate => candidate.value === value || String(candidate.value) === String(value))
            ?? row.choices.find(candidate => root._plain(candidate.label) === text || root._plain(Translation.tr(candidate.label)) === text)
        return choice ? { value: choice.value } : { error: key + " is one of " + row.choices.map(candidate => JSON.stringify(candidate.value)).join(", ") }
    }

    // Change settings: { key: value, ... }. Every value is checked first; nothing is written if one doesn't fit.
    // Returns { changed: [{ key, before, after }] } or { error }. `by` names who asked (shown in the history).
    function request(changes: var, by: string): var {
        const steps = []
        for (const key of Object.keys(changes ?? {})) {
            const fit = root.check(key, changes[key])
            if (fit.error) return { error: fit.error }
            const before = Config.getNestedValue(key)
            if (JSON.stringify(before) !== JSON.stringify(fit.value)) steps.push({ key: key, before: before, after: fit.value })
        }
        if (steps.length === 0) return { changed: [] }
        root._write(steps.map(step => [step.key, step.after]))
        const entry = { at: Date.now(), by: String(by ?? ""), steps: steps }
        root._keep([entry].concat(root.history).slice(0, root.historyLimit))
        const first = root.row(steps[0].key)
        Undo.offer(steps.length === 1 ? Translation.tr(first.label) + ": " + root.say(first, steps[0].after)
            : Translation.tr("Changed %1 settings").arg(steps.length), () => root._revert(entry))
        return { changed: steps }
    }

    function _write(pairs: var): void {
        const apply = GlobalStates.familyVerb("settings", "apply")
        const rest = {}
        for (const [key, value] of pairs)
            if (!(apply && apply(key, value) === true)) rest[key] = value
        if (Object.keys(rest).length > 0) Config.setNestedValues(rest)
    }

    function _keep(history: var): void {
        root.history = history
        historyFile.setText(JSON.stringify(history))
    }

    function _revert(entry: var): void {
        // Only what still holds the value this change gave it goes back; a later change keeps its own.
        root._write(entry.steps.filter(step => JSON.stringify(Config.getNestedValue(step.key)) === JSON.stringify(step.after))
            .map(step => [step.key, step.before]))
        root._keep(root.history.filter(other => other !== entry))
    }

    // Take back the last change made through the door; returns what it was, or "" when there is none.
    function undoLast(): string {
        const last = root.history[0]
        if (!last) return ""
        root._revert(last)
        return last.steps.map(step => step.key).join(", ")
    }

    FileView {
        id: historyFile
        path: Directories.statePath + "/settings-history.json"
        printErrors: false
        onLoaded: {
            try {
                const kept = JSON.parse(historyFile.text())
                // A change made before the file was read stays in front of what it held.
                if (Array.isArray(kept)) root.history = root.history.concat(kept).slice(0, root.historyLimit)
            } catch (e) {}
        }
    }

    function _json(value: var): string {
        return JSON.stringify(value ?? null)
    }

    /// Reads and changes settings the way the person's Settings does: only the rows the active family's Settings
    /// shows, only the values those rows allow. Each change shows an Undo notice and is kept in a history.
    ///
    /// Answers are JSON. A value is JSON too (`true`, `0.8`, `"bottom"`); a bare word is read as text, a choice may
    /// be named by its label, and a number may carry the unit its row shows (`70%`).
    /// ```kdl
    /// Mod+Shift+S { spawn "inir" "setting" "set" "time.secondPrecision" "true"; }
    /// ```
    IpcHandler {
        target: "setting"

        /// The settings a phrase names, best first: key, label, section, value now and what it allows.
        function find(query: string): string {
            return root._json(root.find(query, 8))
        }

        /// One setting: its label, section, value now and what it allows; null when Settings has no such row.
        function get(key: string): string {
            return root._json(root.describe(key))
        }

        /// Change one setting; returns `{"changed": [{key, before, after}]}` or `{"error": ...}`.
        function set(key: string, value: string): string {
            let parsed = value
            try { parsed = JSON.parse(value) } catch (e) {}
            const changes = {}
            changes[key] = parsed
            return root._json(root.request(changes, "ipc"))
        }

        /// Take back the last change made through `setting set` (or a companion); returns the keys it put back, or "".
        function undo(): string {
            return root.undoLast()
        }

        /// The last changes made this way, newest first: when, who asked, and each key before and after.
        function history(): string {
            return root._json(root.history)
        }
    }
}
