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
