.pragma library

var presets = {
    subtle: { zoom: 1.03, workspaceShift: 0.7, panelShift: 0.08, widgetDepth: 0.9 },
    balanced: { zoom: 1.07, workspaceShift: 1.0, panelShift: 0.15, widgetDepth: 1.2 },
    immersive: { zoom: 1.12, workspaceShift: 1.25, panelShift: 0.22, widgetDepth: 1.38 }
}

function clamp(value, minValue, maxValue) {
    var numeric = Number(value)
    if (!Number.isFinite(numeric))
        numeric = minValue
    return Math.max(minValue, Math.min(maxValue, numeric))
}

function clamp01(value) {
    return clamp(value, 0, 1)
}

function resolveAxis(axisValue, legacyAutoVertical, legacyVertical, width, height) {
    var axis = String(axisValue ?? "")
    if (axis === "horizontal" || axis === "vertical")
        return axis
    if (axis === "auto" || legacyAutoVertical === true)
        return Number(height ?? 0) > Number(width ?? 0) ? "vertical" : "horizontal"
    return legacyVertical === true ? "vertical" : "horizontal"
}

function normalizedWorkspaceProgress(workspaceId, lower, upper) {
    var current = Number(workspaceId ?? 1)
    var minimum = Number(lower ?? 0)
    var maximum = Number(upper ?? minimum + 1)
    var span = Math.max(1, maximum - minimum)
    return clamp01((current - minimum) / span)
}

function countActive(values) {
    if (!values || values.length === 0)
        return 0
    var total = 0
    for (var index = 0; index < values.length; index++) {
        if (values[index])
            total += 1
    }
    return total
}

function axisValue(axis, workspaceAxis, workspaceEnabled, workspaceProgress, workspaceShift, panelEnabled, negativeStates, positiveStates, panelShift) {
    var result = 0.5
    if (workspaceEnabled && axis === workspaceAxis) {
        var shift = clamp(workspaceShift, 0, 1.5)
        result = 0.5 + (clamp01(workspaceProgress) - 0.5) * shift
    }
    if (panelEnabled && axis === "horizontal") {
        var offset = (countActive(positiveStates) - countActive(negativeStates)) * clamp(panelShift, 0, 0.3)
        result += offset
    }
    return clamp01(result)
}

function resolveZoom(options, fallback) {
    return clamp(options?.zoom ?? options?.workspaceZoom ?? fallback ?? 1.07, 1, 1.4)
}

function resolveWidgetDepth(options, fallback) {
    return clamp(options?.widgetDepth ?? options?.widgetsFactor ?? fallback ?? 1.2, 0.5, 1.8)
}

function resolvePanelShift(options, fallback) {
    return clamp(options?.panelShift ?? options?.sidebarShift ?? fallback ?? 0.15, 0, 0.3)
}

function resolveWorkspaceShift(options, fallback) {
    return clamp(options?.workspaceShift ?? fallback ?? 1, 0, 1.5)
}

function resolveTransitionSettle(options, fallback) {
    return Math.round(clamp(options?.transitionSettleMs ?? fallback ?? 220, 0, 2000))
}

function preset(id) {
    return presets[id] ?? presets.balanced
}

function detectPreset(zoom, workspaceShift, panelShift, widgetDepth) {
    var epsilon = 0.021
    var keys = Object.keys(presets)
    for (var index = 0; index < keys.length; index++) {
        var key = keys[index]
        var candidate = presets[key]
        if (Math.abs(Number(zoom) - candidate.zoom) <= epsilon
                && Math.abs(Number(workspaceShift) - candidate.workspaceShift) <= epsilon
                && Math.abs(Number(panelShift) - candidate.panelShift) <= epsilon
                && Math.abs(Number(widgetDepth) - candidate.widgetDepth) <= epsilon) {
            return key
        }
    }
    return "custom"
}
