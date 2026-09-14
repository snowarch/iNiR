.pragma library

function resolveHardwareBrightness(current, max, lastGood) {
    const hasLast = Number.isFinite(lastGood) && lastGood >= 0.01
    const maxOk = Number.isFinite(max) && max > 0
    const currentOk = Number.isFinite(current)
    if (!maxOk || !currentOk) {
        return {
            value: hasLast ? lastGood : Number.NaN,
            restore: hasLast,
            rawMax: maxOk ? max : undefined,
        }
    }
    const normalized = current / max
    if (current <= 0 || normalized < 0.01) {
        return {
            value: hasLast ? lastGood : Number.NaN,
            restore: hasLast,
            rawMax: max,
        }
    }
    return {
        value: normalized,
        restore: false,
        rawMax: max,
    }
}

function pickRestoreValue(lastGood, currentBrightness) {
    if (Number.isFinite(lastGood) && lastGood >= 0.01)
        return lastGood
    if (Number.isFinite(currentBrightness) && currentBrightness >= 0.01)
        return currentBrightness
    return Number.NaN
}

function isInternalPanel(name) {
    const n = String(name || "").toUpperCase()
    return n.startsWith("EDP") || n.startsWith("DSI") || n.startsWith("LVDS")
}

function isExternalOutput(name) {
    if (!name)
        return false
    return !isInternalPanel(name)
}

function outputsToPinOff(names) {
    const out = []
    const list = names || []
    for (let i = 0; i < list.length; ++i) {
        if (isExternalOutput(list[i]))
            out.push(list[i])
    }
    return out
}

function preservePinnedOnRepeatedSleep(existingPinned, connectedNames) {
    return mergeOutputNames(existingPinned, outputsToPinOff(connectedNames))
}

function sleepCommandQueue(connectedNames) {
    const pin = outputsToPinOff(connectedNames)
    const cmds = []
    for (let i = 0; i < pin.length; ++i)
        cmds.push(niriOutputOffArgs(pin[i]))
    cmds.push(niriPowerOffMonitorsArgs())
    return cmds
}

function wakeCommandQueue(pinnedNames) {
    const cmds = [niriPowerOnMonitorsArgs()]
    const pin = pinnedNames || []
    for (let i = 0; i < pin.length; ++i)
        cmds.push(niriOutputOnArgs(pin[i]))
    return cmds
}

function niriPowerOffMonitorsArgs() {
    return ["niri", "msg", "action", "power-off-monitors"]
}

function niriPowerOnMonitorsArgs() {
    return ["niri", "msg", "action", "power-on-monitors"]
}

function niriOutputOffArgs(name) {
    return ["niri", "msg", "output", String(name), "off"]
}

function niriOutputOnArgs(name) {
    return ["niri", "msg", "output", String(name), "on"]
}

function wakeOutputRetryLimit() {
    return 25
}

function wakeOutputRetryMs() {
    return 400
}

function shouldRetryWakeOutput(attempt, limit) {
    const cap = Number.isFinite(limit) ? limit : wakeOutputRetryLimit()
    return attempt < cap
}

function disabledExternalOutputNames(jsonText) {
    let data
    try {
        data = JSON.parse(jsonText)
    } catch (e) {
        return []
    }
    if (!data || typeof data !== "object")
        return []
    const names = []
    const keys = Object.keys(data)
    for (let i = 0; i < keys.length; ++i) {
        const name = keys[i]
        if (!isExternalOutput(name))
            continue
        const info = data[name]
        if (!info || info.current_mode == null)
            names.push(name)
    }
    return names
}

function mergeOutputNames(a, b) {
    const out = []
    const seen = {}
    const lists = [a || [], b || []]
    for (let i = 0; i < lists.length; ++i) {
        const list = lists[i]
        for (let j = 0; j < list.length; ++j) {
            const n = list[j]
            if (!n || seen[n])
                continue
            seen[n] = true
            out.push(n)
        }
    }
    return out
}
