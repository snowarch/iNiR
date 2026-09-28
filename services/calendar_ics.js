// ICS/iCalendar parser — pure JavaScript, zero dependencies.
// Handles VEVENT components with support for:
//   - DTSTART/DTEND (date-time and date-only/all-day)
//   - SUMMARY, DESCRIPTION, LOCATION
//   - RRULE recurrence (DAILY, WEEKLY, MONTHLY, YEARLY with INTERVAL, BYDAY, BYMONTHDAY, COUNT, UNTIL)
//     expanded up to 90 days out, minus EXDATE and instances moved by a RECURRENCE-ID override
//   - Timezone-aware parsing via TZID parameter
//   - Folded lines (RFC 5545 line unfolding)

// Parse a raw ICS string into an array of event objects.
// Each event: { title, description, location, startDate, endDate, allDay,
//               sourceId, sourceName, sourceColor, uid, recurrence }
function parseICS(icsText, sourceId, sourceName, sourceColor) {
    if (!icsText || typeof icsText !== "string") return []

    // Unfold continued lines (lines starting with space or tab are continuations)
    const unfolded = icsText.replace(/\r\n[ \t]/g, "").replace(/\r\n/g, "\n").replace(/\r/g, "\n")
    const lines = unfolded.split("\n")

    const events = []
    const series = []
    const overrides = []
    let inEvent = false
    let current = null

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim()

        if (line === "BEGIN:VEVENT") {
            inEvent = true
            current = {}
            continue
        }

        if (line === "END:VEVENT" && inEvent) {
            inEvent = false
            if (current.DTSTART) {
                const base = _buildEvent(current, sourceId, sourceName, sourceColor)
                if (base) {
                    events.push(base)
                    if (current["RECURRENCE-ID"]) {
                        const moved = _parseICSDate(current["RECURRENCE-ID"], current["RECURRENCE-ID_PARAMS"])
                        if (moved) overrides.push(base.uid + "@" + moved.date.getTime())
                    } else if (current.RRULE) {
                        series.push({ base: base, rrule: current.RRULE, exdates: current.EXDATE || [] })
                    }
                }
            }
            current = null
            continue
        }

        if (inEvent && current) {
            // Parse property: NAME;PARAMS:VALUE or NAME:VALUE
            const colonIdx = line.indexOf(":")
            if (colonIdx === -1) continue

            const propPart = line.substring(0, colonIdx)
            const value = line.substring(colonIdx + 1)

            // Split property name from parameters
            const semiIdx = propPart.indexOf(";")
            const propName = semiIdx === -1 ? propPart : propPart.substring(0, semiIdx)
            const params = semiIdx === -1 ? "" : propPart.substring(semiIdx + 1)

            // Store both value and params for date fields
            if (propName === "DTSTART" || propName === "DTEND" || propName === "RECURRENCE-ID") {
                current[propName] = value
                current[propName + "_PARAMS"] = params
            } else if (propName === "EXDATE") {
                // Repeatable, and each line may list several dates.
                current.EXDATE = current.EXDATE || []
                for (const one of value.split(",")) {
                    const parsed = _parseICSDate(one.trim(), params)
                    if (parsed) current.EXDATE.push(parsed.date.getTime())
                }
            } else {
                current[propName] = _unescapeICS(value)
            }
        }
    }

    // Expanded after every VEVENT is read: an override may come before or after its series.
    const moved = new Set(overrides)
    for (const entry of series) {
        const skip = new Set(moved)
        for (const exdate of entry.exdates) skip.add(entry.base.uid + "@" + exdate)
        if (skip.has(entry.base.uid + "@" + new Date(entry.base.startDate).getTime())) events.splice(events.indexOf(entry.base), 1)
        for (const occurrence of _expandRecurrence(entry.base, entry.rrule)) {
            if (!skip.has(entry.base.uid + "@" + new Date(occurrence.startDate).getTime())) events.push(occurrence)
        }
    }

    return events
}

function _buildEvent(props, sourceId, sourceName, sourceColor) {
    const startResult = _parseICSDate(props.DTSTART, props.DTSTART_PARAMS)
    if (!startResult) return null

    const endResult = props.DTEND ? _parseICSDate(props.DTEND, props.DTEND_PARAMS) : null

    return {
        title: props.SUMMARY || "(No title)",
        description: props.DESCRIPTION || "",
        location: props.LOCATION || "",
        startDate: startResult.date.toISOString(),
        endDate: endResult ? endResult.date.toISOString() : startResult.date.toISOString(),
        allDay: startResult.allDay,
        sourceId: sourceId,
        sourceName: sourceName,
        sourceColor: sourceColor || "#4285F4",
        uid: props.UID || "",
        source: "external",
        recurrence: props.RRULE ? _parseRRULEFreq(props.RRULE) : "none"
    }
}

// Parse ICS date string. Handles:
//   20260415T100000Z       (UTC)
//   20260415T100000        (local/floating)
//   20260415               (date-only = all-day)
//   TZID=America/New_York:20260415T100000
function _parseICSDate(value, params) {
    if (!value) return null

    // Check for TZID in params
    let tzid = ""
    if (params) {
        const tzMatch = params.match(/TZID=([^;:]+)/)
        if (tzMatch) tzid = tzMatch[1]
    }

    // Check VALUE=DATE for all-day
    const isDateOnly = value.length === 8 || (params && params.includes("VALUE=DATE"))

    let dateStr = value

    if (isDateOnly) {
        // YYYYMMDD -> all-day event
        const y = parseInt(dateStr.substring(0, 4))
        const m = parseInt(dateStr.substring(4, 6)) - 1
        const d = parseInt(dateStr.substring(6, 8))
        return { date: new Date(y, m, d), allDay: true }
    }

    // YYYYMMDDTHHMMSS or YYYYMMDDTHHMMSSZ
    const isUTC = dateStr.endsWith("Z")
    dateStr = dateStr.replace("Z", "")

    const y = parseInt(dateStr.substring(0, 4))
    const mo = parseInt(dateStr.substring(4, 6)) - 1
    const d = parseInt(dateStr.substring(6, 8))
    const h = parseInt(dateStr.substring(9, 11)) || 0
    const mi = parseInt(dateStr.substring(11, 13)) || 0
    const s = parseInt(dateStr.substring(13, 15)) || 0

    let date
    if (isUTC) {
        date = new Date(Date.UTC(y, mo, d, h, mi, s))
    } else {
        // Floating or TZID — treat as local time
        // (full TZID conversion would require a tz database, out of scope for v1)
        date = new Date(y, mo, d, h, mi, s)
    }

    return { date: date, allDay: false }
}

function _parseRRULEFreq(rrule) {
    if (!rrule) return "none"
    const match = rrule.match(/FREQ=(\w+)/)
    if (!match) return "none"
    switch (match[1]) {
        case "DAILY": return "daily"
        case "WEEKLY": return "weekly"
        case "MONTHLY": return "monthly"
        case "YEARLY": return "yearly"
        default: return "none"
    }
}

const _WEEKDAYS = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]

function _parseRule(rrule) {
    const rule = {}
    for (const part of rrule.split(";")) {
        const eq = part.indexOf("=")
        if (eq > 0) rule[part.substring(0, eq).toUpperCase()] = part.substring(eq + 1)
    }
    return rule
}

// BYDAY entries as { day: 0-6, nth: 0 | ±n } ("MO", "2TU", "-1FR").
function _parseByDay(value) {
    if (!value) return []
    const out = []
    for (const token of value.split(",")) {
        const match = token.trim().toUpperCase().match(/^([+-]?\d+)?(SU|MO|TU|WE|TH|FR|SA)$/)
        if (match) out.push({ day: _WEEKDAYS.indexOf(match[2]), nth: match[1] ? parseInt(match[1]) : 0 })
    }
    return out
}

function _atTimeOf(template, y, m, d) {
    return new Date(y, m, d, template.getHours(), template.getMinutes(), template.getSeconds())
}

// The occurrences one period of the rule produces, in order.
function _occurrencesInPeriod(freq, rule, byDay, byMonthDay, start, index, interval) {
    const step = index * interval
    if (freq === "daily") {
        const day = _atTimeOf(start, start.getFullYear(), start.getMonth(), start.getDate() + step)
        return byDay.length === 0 || byDay.some(entry => entry.day === day.getDay()) ? [day] : []
    }
    if (freq === "weekly") {
        const weekStart = _WEEKDAYS.indexOf(String(rule.WKST || "MO").toUpperCase())
        const offset = (start.getDay() - (weekStart < 0 ? 1 : weekStart) + 7) % 7
        const first = new Date(start.getFullYear(), start.getMonth(), start.getDate() - offset + step * 7)
        const days = byDay.length > 0 ? byDay.map(entry => entry.day) : [start.getDay()]
        const out = []
        for (let i = 0; i < 7; i++) {
            const day = _atTimeOf(start, first.getFullYear(), first.getMonth(), first.getDate() + i)
            if (days.includes(day.getDay())) out.push(day)
        }
        return out
    }
    if (freq === "monthly" || freq === "yearly") {
        const y = freq === "yearly" ? start.getFullYear() + step : start.getFullYear() + Math.floor((start.getMonth() + step) / 12)
        const m = freq === "yearly" ? start.getMonth() : (start.getMonth() + step) % 12
        const length = new Date(y, m + 1, 0).getDate()
        const out = []
        if (byDay.length > 0) {
            for (const entry of byDay) {
                const matches = []
                for (let d = 1; d <= length; d++) if (new Date(y, m, d).getDay() === entry.day) matches.push(d)
                const picked = entry.nth === 0 ? matches : [matches[entry.nth > 0 ? entry.nth - 1 : matches.length + entry.nth]]
                for (const d of picked) if (d) out.push(_atTimeOf(start, y, m, d))
            }
        } else {
            const monthDays = byMonthDay.length > 0 ? byMonthDay : [start.getDate()]
            for (const wanted of monthDays) {
                const d = wanted < 0 ? length + wanted + 1 : wanted
                // A day the month doesn't have (31 in April, 29 February) is skipped, not rolled over.
                if (d >= 1 && d <= length) out.push(_atTimeOf(start, y, m, d))
            }
        }
        return out.sort((a, b) => a - b)
    }
    return []
}

// Expand a recurring event up to 90 days into the future.
// Returns an array of new event objects (copies with adjusted dates), without the base occurrence.
function _expandRecurrence(baseEvent, rrule) {
    const freq = _parseRRULEFreq(rrule)
    if (freq === "none") return []

    const rule = _parseRule(rrule)
    const interval = Math.max(1, parseInt(rule.INTERVAL) || 1)
    const maxCount = rule.COUNT ? parseInt(rule.COUNT) : Infinity
    const untilDate = rule.UNTIL ? _parseICSDate(rule.UNTIL, rule.UNTIL.length === 8 ? "VALUE=DATE" : "")?.date : null
    if (untilDate && rule.UNTIL.length === 8) untilDate.setHours(23, 59, 59)
    const byDay = _parseByDay(rule.BYDAY)
    const byMonthDay = String(rule.BYMONTHDAY || "").split(",").map(v => parseInt(v)).filter(v => !isNaN(v) && v !== 0)

    const now = new Date()
    const horizon = new Date()
    horizon.setDate(horizon.getDate() + 90) // 90-day lookahead

    const startDate = new Date(baseEvent.startDate)
    const duration = new Date(baseEvent.endDate).getTime() - startDate.getTime()

    const results = []
    let count = 0
    // Periods, not occurrences, bound the walk, so a daily series started years ago still reaches today.
    for (let index = 0; index < 20000 && count < maxCount; index++) {
        const period = _occurrencesInPeriod(freq, rule, byDay, byMonthDay, startDate, index, interval)
        if (period.length > 0 && period[0] > horizon) break
        for (const current of period) {
            if (current < startDate) continue
            if (count >= maxCount || current > horizon || (untilDate && current > untilDate)) return results
            count++
            if (current.getTime() === startDate.getTime()) continue // the base event, already listed

            // Skip past events
            if (current.getTime() + duration < now.getTime()) continue

            results.push(Object.assign({}, baseEvent, {
                startDate: current.toISOString(),
                endDate: new Date(current.getTime() + duration).toISOString(),
                uid: baseEvent.uid + "_recur_" + count
            }))
        }
        if (untilDate && period.length > 0 && period[0] > untilDate) break
    }

    return results
}

// Unescape ICS special characters
function _unescapeICS(text) {
    if (!text) return ""
    return text
        .replace(/\\n/g, "\n")
        .replace(/\\,/g, ",")
        .replace(/\\;/g, ";")
        .replace(/\\\\/g, "\\")
}
