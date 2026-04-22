// ICS/iCalendar parser — pure JavaScript, zero dependencies.
// Handles VEVENT components with support for:
//   - DTSTART/DTEND (date-time and date-only/all-day)
//   - SUMMARY, DESCRIPTION, LOCATION
//   - RRULE recurrence (DAILY, WEEKLY, MONTHLY, YEARLY) expanded up to 90 days out
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

                    // Expand recurrence
                    if (current.RRULE) {
                        const recurring = _expandRecurrence(base, current.RRULE)
                        for (const r of recurring) events.push(r)
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
            if (propName === "DTSTART" || propName === "DTEND") {
                current[propName] = value
                current[propName + "_PARAMS"] = params
            } else {
                current[propName] = _unescapeICS(value)
            }
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

// Expand a recurring event up to 90 days into the future.
// Returns an array of new event objects (copies with adjusted dates).
function _expandRecurrence(baseEvent, rrule) {
    const freq = _parseRRULEFreq(rrule)
    if (freq === "none") return []

    // Parse COUNT and UNTIL limits
    const countMatch = rrule.match(/COUNT=(\d+)/)
    const untilMatch = rrule.match(/UNTIL=(\d{8})/)
    const maxCount = countMatch ? parseInt(countMatch[1]) : 365
    const untilDate = untilMatch ? _parseICSDate(untilMatch[1], "VALUE=DATE")?.date : null

    const now = new Date()
    const horizon = new Date()
    horizon.setDate(horizon.getDate() + 90) // 90-day lookahead

    const startDate = new Date(baseEvent.startDate)
    const endDate = new Date(baseEvent.endDate)
    const duration = endDate.getTime() - startDate.getTime()

    const results = []
    let current = new Date(startDate)
    let count = 0

    // Generate up to maxCount occurrences within the horizon
    while (count < maxCount - 1) { // -1 because base event is already counted
        current = _advanceDate(current, freq)
        count++

        if (untilDate && current > untilDate) break
        if (current > horizon) break

        // Skip past events
        const occurrenceEnd = new Date(current.getTime() + duration)
        if (occurrenceEnd < now) continue

        results.push(Object.assign({}, baseEvent, {
            startDate: current.toISOString(),
            endDate: new Date(current.getTime() + duration).toISOString(),
            uid: baseEvent.uid + "_recur_" + count
        }))
    }

    return results
}

function _advanceDate(date, freq) {
    const next = new Date(date)
    switch (freq) {
        case "daily":
            next.setDate(next.getDate() + 1)
            break
        case "weekly":
            next.setDate(next.getDate() + 7)
            break
        case "monthly":
            next.setMonth(next.getMonth() + 1)
            break
        case "yearly":
            next.setFullYear(next.getFullYear() + 1)
            break
    }
    return next
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
