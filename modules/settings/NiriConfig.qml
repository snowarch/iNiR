pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root
    settingsPageIndex: 12
    settingsPageName: Translation.tr("Compositor")

    property var outputList: []
    property int selectedOutputIndex: 0

    readonly property var currentOutput: outputList.length > selectedOutputIndex ? outputList[selectedOutputIndex] : null
    readonly property string currentOutputName: currentOutput?.name ?? ""
    readonly property string currentResolution: currentOutput?.current_resolution ?? ""
    readonly property real currentRate: currentOutput?.current_rate ?? 0
    readonly property string currentRateString: currentOutput?.current_rate_string ?? (currentRate > 0 ? currentRate.toFixed(3) : "")
    readonly property real currentScale: currentOutput?.scale ?? 1.0
    readonly property string currentTransform: currentOutput?.transform ?? "Normal"
    readonly property bool vrrSupported: currentOutput?.vrr_supported ?? false
    readonly property bool vrrEnabled: currentOutput?.vrr_enabled ?? false
    readonly property string niriConfigPath: validationData?.config_path ?? ""
    readonly property string niriConfigDir: customConfigData?.config_dir ?? ""
    readonly property bool hasAnyProcessError: processErrors.outputs.length > 0 || processErrors.input.length > 0 || processErrors.layout.length > 0 || processErrors.animations.length > 0 || processErrors.windowRules.length > 0 || processErrors.cursorThemes.length > 0 || processErrors.validation.length > 0 || processErrors.customizations.length > 0

    readonly property var resolutionOptions: {
        const out = currentOutput
        if (!out?.resolutions) return []
        return out.resolutions.map(r => ({
            displayName: `${r.width}x${r.height}` + (r.preferred ? " ★" : ""),
            value: `${r.width}x${r.height}`,
            width: r.width,
            height: r.height,
            rates: r.rates
        }))
    }

    readonly property var refreshOptions: {
        const res = currentResolution
        if (!res || !currentOutput?.resolutions) return []
        const match = currentOutput.resolutions.find(r => `${r.width}x${r.height}` === res)
        if (!match?.rates) return []
        return match.rates.map(r => ({
            displayName: `${r.rate_string ?? Number(r.rate).toFixed(3)} Hz` + (r.preferred ? " ★" : ""),
            value: r.rate,
            rateString: r.rate_string ?? Number(r.rate).toFixed(3)
        })).sort((a, b) => b.value - a.value)
    }

    readonly property var scaleOptions: [
        { displayName: "0.5x", value: 0.5 },
        { displayName: "0.75x", value: 0.75 },
        { displayName: "1x", value: 1.0 },
        { displayName: "1.25x", value: 1.25 },
        { displayName: "1.5x", value: 1.5 },
        { displayName: "1.75x", value: 1.75 },
        { displayName: "2x", value: 2.0 },
        { displayName: "2.5x", value: 2.5 },
        { displayName: "3x", value: 3.0 }
    ]

    readonly property var transformOptions: [
        { displayName: Translation.tr("Normal"), icon: "screen_rotation", value: "normal" },
        { displayName: "90°", icon: "screen_rotation", value: "90" },
        { displayName: "180°", icon: "screen_rotation", value: "180" },
        { displayName: "270°", icon: "screen_rotation", value: "270" },
        { displayName: Translation.tr("Flipped"), icon: "flip", value: "flipped" },
        { displayName: Translation.tr("Flipped 90°"), icon: "flip", value: "flipped-90" },
        { displayName: Translation.tr("Flipped 180°"), icon: "flip", value: "flipped-180" },
        { displayName: Translation.tr("Flipped 270°"), icon: "flip", value: "flipped-270" }
    ]

    property var inputData: ({})
    readonly property var keyboardData: inputData?.keyboard ?? {}
    readonly property var generalInputData: inputData?.general ?? {}
    readonly property var touchpadData: inputData?.touchpad ?? {}
    readonly property var mouseData: inputData?.mouse ?? {}
    readonly property var trackpointData: inputData?.trackpoint ?? {}
    readonly property var cursorData: inputData?.cursor ?? {}

    property var layoutData: ({})
    property var animationsData: ({})
    property var windowRulesData: ({})
    property var cursorThemes: []
    property var validationData: ({ valid: true, output: "", config_path: "" })
    property var customConfigData: ({ customized: false, config_dir: "", summary: {}, files: [] })
    readonly property var customConfigSummary: customConfigData?.summary ?? ({ managed_override: 0, extra_file: 0, expected_generated: 0, user_extra: 0, actionable: 0, total: 0 })
    readonly property int customConfigManagedOverrideCount: Number(customConfigSummary?.managed_override ?? 0)
    readonly property int customConfigExtraFileCount: Number(customConfigSummary?.extra_file ?? 0)
    readonly property int customConfigExpectedGeneratedCount: Number(customConfigSummary?.expected_generated ?? 0)
    readonly property int customConfigUserExtraCount: Number(customConfigSummary?.user_extra ?? 0)
    readonly property int customConfigActionableCount: Number(customConfigSummary?.actionable ?? (customConfigManagedOverrideCount + customConfigExtraFileCount))
    readonly property int customConfigDiffCount: Number(customConfigSummary?.total ?? (customConfigData?.files?.length ?? 0))
    readonly property bool hasCustomConfigDiffs: customConfigActionableCount > 0
    readonly property bool showCustomConfigStatusSection: customConfigActionableCount > 0 || customConfigUserExtraCount > 0
    readonly property var actionableCustomConfigFiles: (customConfigData?.files ?? []).filter(file => {
        const kind = String(file?.kind ?? "")
        return kind === "managed-override" || kind === "extra-file"
    })
    readonly property var informationalCustomConfigFiles: (customConfigData?.files ?? []).filter(file => {
        const kind = String(file?.kind ?? "")
        return kind === "expected-generated" || kind === "user-extra"
    })
    property var processErrors: ({
        outputs: "",
        input: "",
        layout: "",
        animations: "",
        windowRules: "",
        cursorThemes: "",
        validation: "",
        customizations: ""
    })
    property string lastActionError: ""
    property string lastActionInfo: ""

    property bool inputReady: false
    property bool layoutReady: false
    property bool outputReady: false
    property bool animationsReady: false
    property bool windowRulesReady: false
    property bool validationReady: false
    property bool customizationsReady: false
    property bool positionEditorReady: false
    property bool shadowEditorReady: false

    // Display safety / serialization state
    property string previousMode: ""
    property real previousScale: -1
    property string previousTransform: ""
    property bool confirmationPending: false
    property int confirmCountdown: 10
    property string pendingOutputName: ""
    property string pendingChangeType: ""
    property string pendingChangeValue: ""
    property string pendingPreviewKind: ""
    property string pendingSetSection: ""
    property string pendingActionLabel: ""
    property string applyOutputPurpose: ""
    property string applyOutputTargetName: ""
    property string applyOutputKey: ""
    property string applyOutputValue: ""
    property string applyRollbackKey: ""
    property string applyRollbackValue: ""
    property string persistOutputPurpose: ""
    property string persistOutputTargetName: ""
    property string persistOutputKey: ""
    property string persistOutputValue: ""
    property string persistRollbackKey: ""
    property string persistRollbackValue: ""
    property var setRequestQueue: []
    readonly property bool displayControlsLocked: confirmationPending || applyOutputProcess.running || persistOutputProcess.running

    readonly property string scriptPath: Quickshell.shellPath("scripts/niri-config.py")
    readonly property var keyboardLayoutOptions: [
        { displayName: "US English", value: "us" },
        { displayName: "Spanish", value: "es" },
        { displayName: "German", value: "de" },
        { displayName: "French", value: "fr" },
        { displayName: "Portuguese (BR)", value: "br" },
        { displayName: "Italian", value: "it" },
        { displayName: "UK English", value: "gb" },
        { displayName: "Russian", value: "ru" },
        { displayName: "Japanese", value: "jp" },
        { displayName: "Korean", value: "kr" },
        { displayName: "Latin American", value: "latam" },
        { displayName: Translation.tr("Custom..."), value: "__custom__" }
    ]

    function openPathExternally(path: string): void {
        if (!path || path.length === 0)
            return;
        const target = path.startsWith("file://") ? path : ("file://" + path);
        Qt.openUrlExternally(target);
    }

    // Humanized animation type names
    readonly property var animationLabels: ({
        "workspace-switch": Translation.tr("Workspace switch"),
        "window-open": Translation.tr("Window open"),
        "window-close": Translation.tr("Window close"),
        "horizontal-view-movement": Translation.tr("Horizontal scroll"),
        "window-movement": Translation.tr("Window movement"),
        "window-resize": Translation.tr("Window resize"),
        "config-notification-open-close": Translation.tr("Config notification"),
        "exit-confirmation-open-close": Translation.tr("Exit confirmation"),
        "screenshot-ui-open": Translation.tr("Screenshot UI"),
        "overview-open-close": Translation.tr("Overview"),
        "recent-windows-close": Translation.tr("Recent windows")
    })
    readonly property var modKeyOptions: ["Super", "Alt", "Ctrl", "Shift", "Mod3", "Mod5"]
    readonly property var trackLayoutOptions: [
        { displayName: Translation.tr("Global"), value: "global" },
        { displayName: Translation.tr("Per window"), value: "window" }
    ]
    readonly property var tapButtonMapOptions: [
        { displayName: Translation.tr("Left / Right / Middle"), value: "left-right-middle" },
        { displayName: Translation.tr("Left / Middle / Right"), value: "left-middle-right" }
    ]
    readonly property var clickMethodOptions: [
        { displayName: Translation.tr("Button areas"), value: "button-areas" },
        { displayName: Translation.tr("Clickfinger"), value: "clickfinger" }
    ]
    readonly property var touchpadScrollMethodOptions: [
        { displayName: Translation.tr("Two-finger"), value: "two-finger" },
        { displayName: Translation.tr("Edge"), value: "edge" },
        { displayName: Translation.tr("On button down"), value: "on-button-down" },
        { displayName: Translation.tr("Disable scrolling"), value: "no-scroll" }
    ]
    readonly property var pointerScrollMethodOptions: [
        { displayName: Translation.tr("On button down"), value: "on-button-down" },
        { displayName: Translation.tr("Disable scrolling"), value: "no-scroll" },
        { displayName: Translation.tr("Two-finger"), value: "two-finger" },
        { displayName: Translation.tr("Edge"), value: "edge" }
    ]
    readonly property var defaultColumnDisplayOptions: [
        { displayName: Translation.tr("Normal"), value: "normal" },
        { displayName: Translation.tr("Tabbed"), value: "tabbed" }
    ]
    readonly property var warpMouseModeOptions: [
        { displayName: Translation.tr("Separate axes"), value: "separate" },
        { displayName: Translation.tr("Center window"), value: "center-xy" },
        { displayName: Translation.tr("Always center"), value: "center-xy-always" }
    ]

    function loadOutputs() { outputsProcess.running = true }
    function loadInput() { inputProcess.running = true }
    function loadLayout() { layoutProcess.running = true }
    function loadAnimations() { animationsProcess.running = true }
    function loadWindowRules() { windowRulesProcess.running = true }
    function loadCursorThemes() { cursorThemesProcess.running = true }
    function loadValidation() { validationProcess.running = true }
    function loadCustomizations() { customizationsProcess.running = true }

    function setProcessError(key, message) {
        processErrors = Object.assign({}, processErrors, { [key]: message })
    }

    function resetBanner(message) {
        if (message === undefined)
            message = ""
        lastActionError = ""
        lastActionInfo = message
    }

    function handleJsonResult(rawText, processKey, onSuccess) {
        try {
            const parsed = JSON.parse(rawText)
            if (parsed && typeof parsed === "object" && parsed.error) {
                const errorText = String(parsed.error)
                setProcessError(processKey, errorText)
                if (processKey === "validation") {
                    validationData = { valid: false, output: errorText, config_path: "" }
                    validationReady = true
                }
                return
            }
            setProcessError(processKey, "")
            onSuccess(parsed)
        } catch (e) {
            const parseError = Translation.tr("Failed to parse %1 response.").arg(processKey)
            console.warn(`[NiriConfig] ${processKey} parse failure:`, e)
            setProcessError(processKey, parseError)
        }
    }

    function saveAndRefresh(message) {
        resetBanner(message)
        loadValidation()
        loadCustomizations()
    }

    function refreshAll() {
        loadOutputs()
        loadInput()
        loadLayout()
        loadAnimations()
        loadWindowRules()
        loadCursorThemes()
        loadValidation()
        loadCustomizations()
    }

    function getConfigValue(path, fallback) {
        const parts = String(path ?? "").split(".")
        let cursor = Config.options

        for (const part of parts) {
            if (!part.length)
                continue
            if (cursor === null || cursor === undefined || cursor[part] === undefined)
                return fallback
            cursor = cursor[part]
        }

        return cursor === undefined || cursor === null ? fallback : cursor
    }

    function armPositionEditor() {
        positionEditorReady = false
        positionEditorTimer.restart()
    }

    function armShadowEditor() {
        shadowEditorReady = false
        shadowEditorTimer.restart()
    }

    function clearPreviewState() {
        confirmationPending = false
        previousMode = ""
        previousScale = -1
        previousTransform = ""
        pendingOutputName = ""
        pendingChangeType = ""
        pendingChangeValue = ""
        pendingPreviewKind = ""
        pendingActionLabel = ""
        confirmCountdown = 10
    }

    function clearApplyOutputState() {
        applyOutputPurpose = ""
        applyOutputTargetName = ""
        applyOutputKey = ""
        applyOutputValue = ""
        applyRollbackKey = ""
        applyRollbackValue = ""
    }

    function clearPersistOutputState() {
        persistOutputPurpose = ""
        persistOutputTargetName = ""
        persistOutputKey = ""
        persistOutputValue = ""
        persistRollbackKey = ""
        persistRollbackValue = ""
    }

    function outputValueForKey(output, key) {
        if (!output)
            return ""
        if (key === "position")
            return `${output?.position?.x ?? 0},${output?.position?.y ?? 0}`
        if (key === "vrr")
            return (output?.vrr_enabled ?? false) ? "on" : "off"
        if (key === "scale")
            return String(output?.scale ?? 1.0)
        if (key === "transform")
            return String(output?.transform ?? "Normal").toLowerCase()
        if (key === "mode") {
            const resolution = output?.current_resolution ?? ""
            const rate = output?.current_rate ?? 0
            const rateString = output?.current_rate_string ?? (rate > 0 ? Number(rate).toFixed(3) : "")
            return resolution.length > 0 && rateString.length > 0 ? `${resolution}@${rateString}` : ""
        }
        return ""
    }

    function previewRollbackRequest() {
        if (pendingPreviewKind === "mode" && previousMode.length > 0)
            return { key: "mode", value: previousMode }
        if (pendingPreviewKind === "scale" && previousScale >= 0)
            return { key: "scale", value: String(previousScale) }
        if (pendingPreviewKind === "transform" && previousTransform.length > 0)
            return { key: "transform", value: previousTransform }
        return null
    }

    function startOutputApply(outputName, key, value, purpose, rollbackKey, rollbackValue) {
        applyOutputPurpose = purpose
        applyOutputTargetName = outputName
        applyOutputKey = key
        applyOutputValue = String(value)
        applyRollbackKey = rollbackKey ?? ""
        applyRollbackValue = rollbackValue ?? ""
        applyOutputProcess.command = ["python3", scriptPath, "apply-output", outputName, `${key}=${String(value)}`]
        applyOutputProcess.running = true
    }

    function startOutputPersist(outputName, key, value, purpose, rollbackKey, rollbackValue) {
        persistOutputPurpose = purpose
        persistOutputTargetName = outputName
        persistOutputKey = key
        persistOutputValue = String(value)
        persistRollbackKey = rollbackKey ?? ""
        persistRollbackValue = rollbackValue ?? ""
        persistOutputProcess.command = ["python3", scriptPath, "persist-output", outputName, `${key}=${String(value)}`]
        persistOutputProcess.running = true
    }

    function applyOutput(key, value) {
        if (!currentOutputName.length)
            return
        startOutputApply(currentOutputName, key, value, "adhoc", "", "")
    }

    function persistOutput(key, value) {
        if (!currentOutputName.length)
            return
        startOutputPersist(currentOutputName, key, value, "adhoc", "", "")
    }

    function applyAndPersistOutput(key, value) {
        if (displayControlsLocked)
            return

        const output = currentOutput
        const outputName = currentOutputName
        if (!output || !outputName.length)
            return

        startOutputApply(outputName, key, value, "apply-and-persist", key, outputValueForKey(output, key))
    }

    // Display safety: apply transient change, start confirmation timer
    function safeApplyOutput(changeType, key, value) {
        if (displayControlsLocked)
            return

        const outputName = currentOutputName
        if (!outputName.length)
            return

        // Store current state for revert
        if (changeType === "mode") {
            previousMode = `${currentResolution}@${currentRateString || currentRate.toFixed(3)}`
            previousScale = -1
            previousTransform = ""
        } else if (changeType === "scale") {
            previousScale = currentScale
            previousMode = ""
            previousTransform = ""
        } else if (changeType === "transform") {
            previousTransform = currentTransform.toLowerCase()
            previousMode = ""
            previousScale = -1
        }

        pendingOutputName = outputName
        pendingChangeType = key
        pendingChangeValue = value
        pendingPreviewKind = changeType
        pendingActionLabel = Translation.tr("Previewing display change")
        confirmCountdown = 10

        startOutputApply(outputName, key, value, "preview", "", "")
    }

    function confirmDisplayChange() {
        if (!confirmationPending || applyOutputProcess.running || persistOutputProcess.running || !pendingOutputName.length)
            return

        const rollback = previewRollbackRequest()

        confirmationPending = false
        pendingActionLabel = Translation.tr("Saving display settings")
        startOutputPersist(pendingOutputName, pendingChangeType, pendingChangeValue, "preview-confirm", rollback ? rollback.key : "", rollback ? rollback.value : "")
    }

    function revertDisplayChange() {
        if (!pendingOutputName.length || applyOutputProcess.running || persistOutputProcess.running)
            return

        const outputName = pendingOutputName
        const rollback = previewRollbackRequest()

        confirmationPending = false

        if (!rollback) {
            clearPreviewState()
            lastActionInfo = Translation.tr("Display preview reverted.")
            return
        }

        pendingActionLabel = Translation.tr("Reverting display preview")
        startOutputApply(outputName, rollback.key, rollback.value, "preview-revert", "", "")
    }

    function runNextSetRequest() {
        if (setProcess.running || setRequestQueue.length === 0)
            return

        const nextQueue = setRequestQueue.slice()
        const request = nextQueue.shift()
        setRequestQueue = nextQueue
        pendingSetSection = request.section
        pendingActionLabel = `${request.section}.${request.key}`
        setProcess.command = ["python3", scriptPath, "set", request.section, request.key, request.value]
        setProcess.running = true
    }

    function setConfig(section, key, value) {
        const normalizedValue = String(value)
        const nextQueue = []

        for (const request of setRequestQueue) {
            if (request.section === section && request.key === key)
                continue
            nextQueue.push(request)
        }

        nextQueue.push({ section: section, key: key, value: normalizedValue })
        setRequestQueue = nextQueue
        runNextSetRequest()
    }

    function setBooleanConfig(section, key, enabled) {
        setConfig(section, key, enabled ? "on" : "off")
    }

    function setFocusFollowsMouse(enabled, percent) {
        if (percent === undefined)
            percent = -1
        if (!enabled) {
            setConfig("input", "focus-follows-mouse", "off")
            return
        }
        const finalPercent = percent >= 0 ? percent : (generalInputData?.focus_follows_mouse_max_scroll ?? 0)
        setConfig("input", "focus-follows-mouse", `max-scroll-amount=\"${finalPercent}%\"`)
    }

    function setWarpMouseMode(mode) {
        if (mode === "off") {
            setConfig("input", "warp-mouse-to-focus", "off")
            return
        }
        setConfig("input", "warp-mouse-to-focus", mode)
    }

    function animationIsEnabled(typeData) {
        return !(typeData?.off ?? false)
    }

    function processErrorSummary() {
        const messages = []
        for (const key of ["outputs", "input", "layout", "animations", "windowRules", "cursorThemes", "validation", "customizations"]) {
            const message = String(processErrors[key] ?? "").trim()
            if (message.length > 0)
                messages.push(message)
        }
        return messages.join("\n")
    }

    function choiceIndex(options, value) {
        for (let i = 0; i < options.length; ++i) {
            if (String(options[i].value) === String(value))
                return i
        }
        return -1
    }

    Component.onCompleted: {
        refreshAll()
    }

    onCurrentOutputChanged: armPositionEditor()
    onLayoutDataChanged: armShadowEditor()

    // Force-resync display combo boxes when output data refreshes.
    // Inline bindings on currentIndex get broken by user interaction (classic QML issue),
    // and Binding elements inside ContentSubsection resolve `root` to ContentSubsection's
    // own root, not NiriConfig. So we resync imperatively here.
    onOutputListChanged: Qt.callLater(resyncDisplayCombos)
    onSelectedOutputIndexChanged: Qt.callLater(resyncDisplayCombos)

    function resyncDisplayCombos() {
        resolutionCombo.currentIndex = choiceIndex(resolutionCombo.model, currentResolution)
        refreshRateCombo.currentIndex = choiceIndex(refreshRateCombo.model, currentRate)
        scaleCombo.currentIndex = choiceIndex(scaleCombo.model, currentScale)
        rotationCombo.currentIndex = choiceIndex(rotationCombo.model, currentTransform.toLowerCase())
    }

    // =====================
    // CONFIRMATION TIMER
    // =====================
    Timer {
        id: confirmTimer
        interval: 1000
        repeat: true
        running: root.confirmationPending
        onTriggered: {
            root.confirmCountdown--
            if (root.confirmCountdown <= 0) {
                root.revertDisplayChange()
            }
        }
    }

    Timer {
        id: positionEditorTimer
        interval: 1
        repeat: false
        onTriggered: root.positionEditorReady = true
    }

    // Deferred output refresh — gives Niri time to commit display changes
    // before we query the new state (avoids stale reads after scale/mode changes).
    Timer {
        id: _deferredOutputRefresh
        interval: 300
        repeat: false
        onTriggered: root.loadOutputs()
    }

    Timer {
        id: shadowEditorTimer
        interval: 1
        repeat: false
        onTriggered: root.shadowEditorReady = true
    }

    // =====================
    // PROCESSES
    // =====================
    Process {
        id: outputsProcess
        command: ["python3", root.scriptPath, "outputs"]
        stdout: StdioCollector {
            id: outputsCollector
            onStreamFinished: {
                root.outputReady = false
                root.handleJsonResult(outputsCollector.text, "outputs", data => {
                    if (Array.isArray(data))
                        root.outputList = data
                    root.outputReady = true
                })
            }
        }
        stderr: StdioCollector { id: outputsErrorCollector }
        onExited: (exitCode) => {
            if (exitCode !== 0)
                root.setProcessError("outputs", (outputsErrorCollector.text || outputsCollector.text || Translation.tr("Unable to query connected outputs.")).trim())
        }
    }

    Process {
        id: inputProcess
        command: ["python3", root.scriptPath, "get-input"]
        stdout: StdioCollector {
            id: inputCollector
            onStreamFinished: {
                root.inputReady = false
                root.handleJsonResult(inputCollector.text, "input", data => {
                    root.inputData = data
                    root.inputReady = true
                })
            }
        }
        stderr: StdioCollector { id: inputErrorCollector }
        onExited: (exitCode) => {
            if (exitCode !== 0)
                root.setProcessError("input", (inputErrorCollector.text || inputCollector.text || Translation.tr("Unable to read input configuration.")).trim())
        }
    }

    Process {
        id: layoutProcess
        command: ["python3", root.scriptPath, "get-layout"]
        stdout: StdioCollector {
            id: layoutCollector
            onStreamFinished: {
                root.layoutReady = false
                root.handleJsonResult(layoutCollector.text, "layout", data => {
                    root.layoutData = data
                    root.layoutReady = true
                })
            }
        }
        stderr: StdioCollector { id: layoutErrorCollector }
        onExited: (exitCode) => {
            if (exitCode !== 0)
                root.setProcessError("layout", (layoutErrorCollector.text || layoutCollector.text || Translation.tr("Unable to read layout configuration.")).trim())
        }
    }

    Process {
        id: animationsProcess
        command: ["python3", root.scriptPath, "get-animations"]
        stdout: StdioCollector {
            id: animationsCollector
            onStreamFinished: {
                root.animationsReady = false
                root.handleJsonResult(animationsCollector.text, "animations", data => {
                    root.animationsData = data
                    root.animationsReady = true
                })
            }
        }
        stderr: StdioCollector { id: animationsErrorCollector }
        onExited: (exitCode) => {
            if (exitCode !== 0)
                root.setProcessError("animations", (animationsErrorCollector.text || animationsCollector.text || Translation.tr("Unable to read animations configuration.")).trim())
        }
    }

    Process {
        id: windowRulesProcess
        command: ["python3", root.scriptPath, "get-window-rules"]
        stdout: StdioCollector {
            id: windowRulesCollector
            onStreamFinished: {
                root.windowRulesReady = false
                root.handleJsonResult(windowRulesCollector.text, "windowRules", data => {
                    root.windowRulesData = data
                    root.windowRulesReady = true
                })
            }
        }
        stderr: StdioCollector { id: windowRulesErrorCollector }
        onExited: (exitCode) => {
            if (exitCode !== 0)
                root.setProcessError("windowRules", (windowRulesErrorCollector.text || windowRulesCollector.text || Translation.tr("Unable to read window rules.")).trim())
        }
    }

    Process {
        id: cursorThemesProcess
        command: ["python3", root.scriptPath, "list-cursor-themes"]
        stdout: StdioCollector {
            id: cursorThemesCollector
            onStreamFinished: {
                root.handleJsonResult(cursorThemesCollector.text, "cursorThemes", data => {
                    root.cursorThemes = Array.isArray(data) ? data : []
                })
            }
        }
        stderr: StdioCollector { id: cursorThemesErrorCollector }
        onExited: (exitCode) => {
            if (exitCode !== 0)
                root.setProcessError("cursorThemes", (cursorThemesErrorCollector.text || cursorThemesCollector.text || Translation.tr("Unable to enumerate cursor themes.")).trim())
        }
    }

    Process {
        id: validationProcess
        command: ["python3", root.scriptPath, "validate"]
        stdout: StdioCollector {
            id: validationCollector
            onStreamFinished: {
                root.validationReady = false
                root.handleJsonResult(validationCollector.text, "validation", data => {
                    root.validationData = data
                    root.validationReady = true
                })
            }
        }
        stderr: StdioCollector { id: validationErrorCollector }
        onExited: (exitCode) => {
            if (exitCode !== 0)
                root.setProcessError("validation", (validationErrorCollector.text || validationCollector.text || Translation.tr("Unable to validate Niri configuration.")).trim())
        }
    }

    Process {
        id: customizationsProcess
        command: ["python3", root.scriptPath, "detect-customizations"]
        stdout: StdioCollector {
            id: customizationsCollector
            onStreamFinished: {
                root.customizationsReady = false
                root.handleJsonResult(customizationsCollector.text, "customizations", data => {
                    root.customConfigData = data
                    root.customizationsReady = true
                })
            }
        }
        stderr: StdioCollector { id: customizationsErrorCollector }
        onExited: (exitCode) => {
            if (exitCode !== 0)
                root.setProcessError("customizations", (customizationsErrorCollector.text || customizationsCollector.text || Translation.tr("Unable to inspect custom Niri configuration.")).trim())
        }
    }

    Process {
        id: applyOutputProcess
        stdout: StdioCollector { id: applyOutputCollector }
        stderr: StdioCollector { id: applyOutputErrorCollector }
        onExited: (exitCode) => {
            const purpose = root.applyOutputPurpose
            const stdout = (applyOutputCollector.text || "").trim()
            const stderr = (applyOutputErrorCollector.text || "").trim()

            // Parse JSON results for detailed failure info
            let jsonFailed = false
            let failDetail = ""
            try {
                const parsed = JSON.parse(stdout)
                if (parsed?.results) {
                    const failed = parsed.results.filter(r => r.success === false)
                    if (failed.length > 0) {
                        jsonFailed = true
                        failDetail = failed.map(r => `${r.key}: ${r.output || "failed"}`).join("; ")
                    }
                }
            } catch (_) {
                // Not JSON — fall through to text-based handling
            }

            const effectiveFailed = exitCode !== 0 || jsonFailed
            const text = failDetail || stderr || stdout

            if (!effectiveFailed) {
                if (purpose === "preview") {
                    root.lastActionError = ""
                    root.confirmationPending = true
                } else if (purpose === "preview-revert") {
                    root.lastActionError = ""
                    root.clearPreviewState()
                    root.lastActionInfo = Translation.tr("Display preview reverted.")
                } else if (purpose === "preview-revert-after-failure") {
                    root.clearPreviewState()
                    root.lastActionInfo = Translation.tr("Display preview reverted after save failure.")
                } else if (purpose === "apply-and-persist") {
                    root.lastActionError = ""
                    root.startOutputPersist(root.applyOutputTargetName, root.applyOutputKey, root.applyOutputValue, "apply-and-persist", root.applyRollbackKey, root.applyRollbackValue)
                } else if (purpose === "apply-and-persist-rollback") {
                    root.lastActionInfo = Translation.tr("Display change reverted after save failure.")
                } else {
                    root.lastActionError = ""
                }
                root._deferredOutputRefresh.restart()
            } else {
                if (purpose === "preview" || purpose === "preview-revert" || purpose === "preview-revert-after-failure")
                    root.clearPreviewState()
                root.lastActionError = text.length > 0 ? text : ((purpose === "preview")
                    ? Translation.tr("Failed to preview display change.")
                    : ((purpose === "preview-revert" || purpose === "preview-revert-after-failure" || purpose === "apply-and-persist-rollback")
                        ? Translation.tr("Failed to revert display change.")
                        : Translation.tr("Failed to apply display change.")))
            }
            root.clearApplyOutputState()
        }
    }

    Process {
        id: persistOutputProcess
        stdout: StdioCollector { id: persistOutputCollector }
        stderr: StdioCollector { id: persistOutputErrorCollector }
        onExited: (exitCode) => {
            const purpose = root.persistOutputPurpose
            const text = (persistOutputErrorCollector.text || persistOutputCollector.text || "").trim()
            if (exitCode === 0) {
                root.lastActionError = ""
                if (purpose === "preview-confirm")
                    root.clearPreviewState()
                root.saveAndRefresh(Translation.tr("Display settings saved."))
                root.loadOutputs()
            } else {
                root.lastActionError = text.length > 0 ? text : Translation.tr("Failed to save display settings.")

                if (purpose === "preview-confirm" && root.persistRollbackKey.length > 0 && root.persistRollbackValue.length > 0) {
                    root.pendingActionLabel = Translation.tr("Reverting display preview")
                    root.startOutputApply(root.persistOutputTargetName, root.persistRollbackKey, root.persistRollbackValue, "preview-revert-after-failure", "", "")
                } else if (purpose === "apply-and-persist" && root.persistRollbackKey.length > 0 && root.persistRollbackValue.length > 0) {
                    root.startOutputApply(root.persistOutputTargetName, root.persistRollbackKey, root.persistRollbackValue, "apply-and-persist-rollback", "", "")
                } else if (purpose === "preview-confirm") {
                    root.clearPreviewState()
                }
            }
            root.clearPersistOutputState()
        }
    }

    Process {
        id: setProcess
        stdout: StdioCollector { id: setCollector }
        stderr: StdioCollector { id: setErrorCollector }
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                root.lastActionError = (setErrorCollector.text || setCollector.text || Translation.tr("Failed to update Niri configuration.")).trim()
                root.pendingSetSection = ""
                root.pendingActionLabel = ""
                root.runNextSetRequest()
                return
            }

            root.lastActionError = ""

            if (root.pendingSetSection === "input") {
                root.loadInput()
            } else if (root.pendingSetSection === "layout") {
                root.loadLayout()
            } else if (root.pendingSetSection === "animations") {
                root.loadAnimations()
            } else if (root.pendingSetSection === "window-rules") {
                root.loadWindowRules()
            }

            root.saveAndRefresh(Translation.tr("Niri configuration updated."))
            root.pendingSetSection = ""
            root.pendingActionLabel = ""
            root.runNextSetRequest()
        }
    }

    // =====================
    // DISPLAY CONFIRMATION OVERLAY
    // =====================
    Item {
        id: confirmBanner
        visible: root.confirmationPending
        Layout.fillWidth: true
        implicitHeight: confirmCol.implicitHeight + 24

        // Auto-scroll to this banner when confirmation becomes pending
        onVisibleChanged: {
            if (visible) {
                // mapToItem(null, ...) gives the y in content coordinates via the layout
                // Use a small delay so the layout has time to position the item
                scrollToBannerTimer.restart()
            }
        }

        Timer {
            id: scrollToBannerTimer
            interval: 50
            onTriggered: {
                // Scroll the flickable so the banner is near the top with some padding
                const bannerY = confirmBanner.mapToItem(root.contentItem, 0, 0).y
                if (bannerY < root.contentY || bannerY > root.contentY + root.height - confirmBanner.height) {
                    root.contentY = Math.max(0, bannerY - 16)
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Appearance.colors.colLayer2
            radius: Appearance.rounding.screenRounding
            border.width: 2
            border.color: Appearance.colors.colPrimary

            ColumnLayout {
                id: confirmCol
                anchors {
                    fill: parent
                    margins: 16
                }
                spacing: 12

                RowLayout {
                    spacing: 8

                    MaterialSymbol {
                        text: "monitor"
                        iconSize: Appearance.font.pixelSize.hugeass
                        color: Appearance.colors.colPrimary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            text: Translation.tr("Keep these display settings?")
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer1
                        }
                        StyledText {
                            text: Translation.tr("Reverting in %1 seconds...").arg(root.confirmCountdown)
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }
                        StyledText {
                            text: {
                                if (root.pendingPreviewKind === "mode")
                                    return Translation.tr("Previewing %1").arg(root.pendingChangeValue)
                                if (root.pendingPreviewKind === "scale")
                                    return Translation.tr("Previewing scale %1x").arg(root.pendingChangeValue)
                                if (root.pendingPreviewKind === "transform")
                                    return Translation.tr("Previewing rotation %1").arg(root.pendingChangeValue)
                                return ""
                            }
                            visible: text.length > 0
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colPrimary
                        }
                    }
                }

                // Countdown bar
                Rectangle {
                    Layout.fillWidth: true
                    height: 4
                    radius: 2
                    color: Appearance.colors.colLayer1

                    Rectangle {
                        width: parent.width * (root.confirmCountdown / 10.0)
                        height: parent.height
                        radius: 2
                        color: Appearance.colors.colPrimary

                        Behavior on width {
                            NumberAnimation { duration: 900; easing.type: Easing.Linear }
                        }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 8

                    Button {
                        text: Translation.tr("Revert")
                        onClicked: root.revertDisplayChange()

                        background: Rectangle {
                            implicitWidth: 80
                            implicitHeight: 36
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colLayer1
                        }

                        contentItem: StyledText {
                            text: parent.text
                            color: Appearance.colors.colOnLayer1
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Button {
                        text: Translation.tr("Keep changes")
                        onClicked: root.confirmDisplayChange()

                        background: Rectangle {
                            implicitWidth: 120
                            implicitHeight: 36
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colPrimary
                        }

                        contentItem: StyledText {
                            text: parent.text
                            color: Appearance.colors.colOnPrimary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: compositorIntro.implicitHeight

        ColumnLayout {
            id: compositorIntro
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 4

            StyledText {
                text: Translation.tr("Niri Configuration")
                font.pixelSize: Appearance.font.pixelSize.huge
                font.family: Appearance.font.family.title
                color: Appearance.colors.colOnLayer1
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Adjust displays, input, layout and animation behavior. Display changes preview live and revert automatically if you don't keep them.")
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
            }
        }
    }

    Item {
        id: statusBanner
        Layout.fillWidth: true
        visible: root.lastActionError.length > 0 || root.lastActionInfo.length > 0 || !root.validationData.valid || root.hasAnyProcessError
        implicitHeight: statusColumn.implicitHeight + 24

        readonly property bool isError: root.lastActionError.length > 0 || !root.validationData.valid || root.hasAnyProcessError
        readonly property color accentColor: isError ? Appearance.colors.colError : Appearance.colors.colPrimary

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(statusBanner.accentColor.r, statusBanner.accentColor.g, statusBanner.accentColor.b, 0.10)
            radius: Appearance.rounding.screenRounding
            border.width: 2
            border.color: statusBanner.accentColor

            ColumnLayout {
                id: statusColumn
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialSymbol {
                        text: statusBanner.isError ? "error" : "check_circle"
                        color: statusBanner.accentColor
                        iconSize: Appearance.font.pixelSize.hugeass
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            text: root.lastActionError.length > 0
                                ? root.lastActionError
                                : !root.validationData.valid
                                    ? (root.validationData.output?.length > 0 ? root.validationData.output : Translation.tr("Niri config validation failed."))
                                    : root.hasAnyProcessError
                                        ? root.processErrorSummary()
                                        : root.lastActionInfo
                            wrapMode: Text.WordWrap
                            color: Appearance.colors.colOnLayer1
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.niriConfigPath.length > 0
                            text: Translation.tr("Config file: %1").arg(root.niriConfigPath)
                            wrapMode: Text.WrapAnywhere
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.family: Appearance.font.family.monospace
                        }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 8

                    Button {
                        visible: !root.validationData.valid || root.hasAnyProcessError
                        text: Translation.tr("Retry")
                        onClicked: root.refreshAll()

                        background: Rectangle {
                            implicitWidth: 80
                            implicitHeight: 36
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colPrimary
                        }

                        contentItem: StyledText {
                            text: parent.text
                            color: Appearance.colors.colOnPrimary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }

                    Button {
                        visible: root.lastActionError.length > 0 || root.lastActionInfo.length > 0
                        text: Translation.tr("Dismiss")
                        onClicked: {
                            root.lastActionError = ""
                            root.lastActionInfo = ""
                        }

                        background: Rectangle {
                            implicitWidth: 80
                            implicitHeight: 36
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colLayer1
                        }

                        contentItem: StyledText {
                            text: parent.text
                            color: Appearance.colors.colOnLayer1
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }
                }
            }
        }
    }

    // =====================
    // NIRI CONFIG STATUS
    // =====================
    SettingsCardSection {
        visible: root.showCustomConfigStatusSection
        expanded: false
        icon: "rule_settings"
        title: Translation.tr("Niri config status")

        SettingsGroup {
            Item {
                Layout.fillWidth: true
                implicitHeight: summaryRow.implicitHeight

                RowLayout {
                    id: summaryRow
                    anchors.fill: parent
                    spacing: 8

                    MaterialSymbol {
                        text: root.hasCustomConfigDiffs ? "warning" : "task_alt"
                        iconSize: Appearance.font.pixelSize.normal
                        color: root.hasCustomConfigDiffs ? Appearance.colors.colError : Appearance.colors.colPrimary
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.hasCustomConfigDiffs
                            ? Translation.tr("%1 actionable override files detected").arg(root.customConfigActionableCount)
                            : Translation.tr("No actionable managed overrides detected")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                        wrapMode: Text.WordWrap
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.hasCustomConfigDiffs
                    ? Translation.tr("These entries differ from iNiR-managed defaults and may affect update compatibility.")
                    : Translation.tr("Only expected generated/user-owned files were found. No managed override warnings.")
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                StyledText {
                    text: Translation.tr("Managed overrides: %1").arg(root.customConfigManagedOverrideCount)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: root.customConfigManagedOverrideCount > 0 ? Appearance.colors.colError : Appearance.colors.colSubtext
                }

                StyledText {
                    text: Translation.tr("Extra files: %1").arg(root.customConfigExtraFileCount)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: root.customConfigExtraFileCount > 0 ? Appearance.colors.colError : Appearance.colors.colSubtext
                }

                StyledText {
                    text: Translation.tr("Generated/user files: %1").arg(root.customConfigExpectedGeneratedCount + root.customConfigUserExtraCount)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Button {
                    visible: root.niriConfigDir.length > 0
                    text: Translation.tr("Open config folder")
                    onClicked: root.openPathExternally(root.niriConfigDir)

                    background: Rectangle {
                        implicitWidth: 140
                        implicitHeight: 36
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer2
                    }

                    contentItem: StyledText {
                        text: parent.text
                        color: Appearance.colors.colOnLayer1
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }

                Button {
                    visible: root.niriConfigPath.length > 0
                    text: Translation.tr("Open config file")
                    onClicked: root.openPathExternally(root.niriConfigPath)

                    background: Rectangle {
                        implicitWidth: 120
                        implicitHeight: 36
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer2
                    }

                    contentItem: StyledText {
                        text: parent.text
                        color: Appearance.colors.colOnLayer1
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.niriConfigDir.length > 0
                text: Translation.tr("Config directory: %1").arg(root.niriConfigDir)
                wrapMode: Text.WrapAnywhere
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.family: Appearance.font.family.monospace
            }

            Repeater {
                model: root.actionableCustomConfigFiles

                delegate: ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    required property var modelData

                    SettingsDivider {}

                    ContentSubsection {
                        title: modelData.path ?? ""
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: modelData.reason ?? ""
                        wrapMode: Text.WordWrap
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.small
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        visible: (modelData.preview?.length ?? 0) > 0
                        color: Appearance.colors.colLayer2
                        radius: Appearance.rounding.small
                        border.width: 1
                        border.color: Appearance.colors.colOutlineVariant
                        implicitHeight: previewText.implicitHeight + 16

                        StyledText {
                            id: previewText
                            anchors.fill: parent
                            anchors.margins: 8
                            text: (modelData.preview ?? []).join("\n")
                            wrapMode: Text.WrapAnywhere
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.family: Appearance.font.family.monospace
                            color: Appearance.colors.colOnLayer1
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Informational files")
                visible: root.informationalCustomConfigFiles.length > 0
            }

            Repeater {
                model: root.informationalCustomConfigFiles

                delegate: ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    required property var modelData

                    SettingsDivider {}

                    StyledText {
                        Layout.fillWidth: true
                        text: modelData.path ?? ""
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        wrapMode: Text.WrapAnywhere
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: modelData.reason ?? ""
                        wrapMode: Text.WordWrap
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }
        }
    }

    // =====================
    // DISPLAYS SECTION
    // =====================
    SettingsCardSection {
        icon: "monitor"
        title: Translation.tr("Displays")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Monitor changes are applied as a live preview first. If the new mode is incompatible, settings revert automatically after 15 seconds.")
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
            }

            ContentSubsection {
                title: Translation.tr("Monitor")
                visible: root.outputList.length > 1

                StyledComboBox {
                    Layout.fillWidth: true
                    enabled: !root.displayControlsLocked
                    model: root.outputList.map(o => ({
                        displayName: `${o.name} — ${o.make} ${o.model}`,
                        value: o.name
                    }))
                    textRole: "displayName"
                    currentIndex: root.choiceIndex(model, root.currentOutputName)
                    onActivated: {
                        const idx = root.outputList.findIndex(o => o.name === model[currentIndex].value)
                        if (idx >= 0)
                            root.selectedOutputIndex = idx
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: monitorInfoRow.implicitHeight + 8
                visible: root.currentOutput !== null

                RowLayout {
                    id: monitorInfoRow
                    anchors {
                        left: parent.left; right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 8; rightMargin: 8
                    }
                    spacing: 10

                    MaterialSymbol {
                        text: "monitor"
                        iconSize: Appearance.font.pixelSize.hugeass
                        color: Appearance.colors.colPrimary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            text: root.currentOutputName
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer1
                        }
                        StyledText {
                            text: {
                                const o = root.currentOutput
                                if (!o) return ""
                                const make = o.make ?? ""
                                const model = o.model ?? ""
                                const phys = o.physical_size ?? [0, 0]
                                let info = `${make} ${model}`.trim()
                                if (phys[0] > 0 && phys[1] > 0) {
                                    const diag = Math.sqrt(phys[0]*phys[0] + phys[1]*phys[1]) / 25.4
                                    info += ` — ${diag.toFixed(1)}"`
                                }
                                return info
                            }
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }

            SettingsDivider { visible: root.currentOutput !== null }

            ContentSubsection {
                title: Translation.tr("Resolution")
                visible: root.resolutionOptions.length > 0

                StyledComboBox {
                    id: resolutionCombo
                    Layout.fillWidth: true
                    enabled: !root.displayControlsLocked
                    model: root.resolutionOptions
                    textRole: "displayName"
                    onActivated: {
                        const selectedValue = model[currentIndex].value
                        const match = root.currentOutput?.resolutions?.find(r => `${r.width}x${r.height}` === selectedValue)
                        if (match?.rates?.length > 0) {
                            const best = match.rates.reduce((a, b) => a.rate > b.rate ? a : b)
                            root.safeApplyOutput("mode", "mode", `${selectedValue}@${best.rate_string ?? Number(best.rate).toFixed(3)}`)
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Refresh rate")
                visible: root.refreshOptions.length > 1

                StyledComboBox {
                    id: refreshRateCombo
                    Layout.fillWidth: true
                    enabled: !root.displayControlsLocked
                    model: root.refreshOptions
                    textRole: "displayName"
                    onActivated: root.safeApplyOutput("mode", "mode", `${root.currentResolution}@${model[currentIndex].rateString}`)
                }
            }

            ContentSubsection {
                title: Translation.tr("Output position")
                tooltip: Translation.tr("Logical coordinates in Niri global space. Useful for stacked or side-by-side monitor layouts.")
                visible: root.currentOutput !== null

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    ConfigSpinBox {
                        id: positionXSpin
                        Layout.fillWidth: true
                        enabled: !root.displayControlsLocked
                        text: "X"
                        value: root.currentOutput?.position?.x ?? 0
                        from: -10000
                        to: 10000
                        stepSize: 10
                        onValueChanged: {
                            if (!root.outputReady || !root.positionEditorReady) return
                            root.applyAndPersistOutput("position", `${value},${positionYSpin.value}`)
                        }
                    }

                    ConfigSpinBox {
                        id: positionYSpin
                        Layout.fillWidth: true
                        enabled: !root.displayControlsLocked
                        text: "Y"
                        value: root.currentOutput?.position?.y ?? 0
                        from: -10000
                        to: 10000
                        stepSize: 10
                        onValueChanged: {
                            if (!root.outputReady || !root.positionEditorReady) return
                            root.applyAndPersistOutput("position", `${positionXSpin.value},${value}`)
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Scale")

                StyledComboBox {
                    id: scaleCombo
                    Layout.fillWidth: true
                    enabled: !root.displayControlsLocked
                    model: root.scaleOptions
                    textRole: "displayName"
                    onActivated: root.safeApplyOutput("scale", "scale", String(model[currentIndex].value))
                }
            }

            ContentSubsection {
                title: Translation.tr("Rotation")

                StyledComboBox {
                    id: rotationCombo
                    Layout.fillWidth: true
                    enabled: !root.displayControlsLocked
                    model: root.transformOptions
                    textRole: "displayName"
                    onActivated: root.safeApplyOutput("transform", "transform", model[currentIndex].value)
                }
            }

            ContentSubsection {
                title: Translation.tr("Variable refresh rate (VRR)")
                tooltip: Translation.tr("Adaptive sync / FreeSync / G-Sync. Reduces tearing in games and video.")
                visible: root.vrrSupported

                SettingsSwitch {
                    Layout.fillWidth: true
                    enabled: !root.displayControlsLocked
                    buttonIcon: "display_settings"
                    text: Translation.tr("Enable VRR")
                    checked: root.vrrEnabled
                    onCheckedChanged: {
                        if (!root.outputReady) return
                        root.applyAndPersistOutput("vrr", checked ? "on" : "off")
                    }
                }
            }
        }
    }

    // =====================
    // LAYOUT SECTION
    // =====================
    SettingsCardSection {
        expanded: false
        icon: "grid_view"
        title: Translation.tr("Layout")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Window gaps")
                tooltip: Translation.tr("Space between windows and screen edges in pixels")

                ConfigSpinBox {
                    text: Translation.tr("Gap size (px)")
                    value: root.layoutData?.gaps ?? 25
                    from: 0
                    to: 64
                    stepSize: 1
                    onValueChanged: {
                        if (!root.layoutReady) return
                        root.setConfig("layout", "gaps", value)
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Focus behavior")
                tooltip: Translation.tr("When to center the focused column on screen")

                ConfigSelectionArray {
                    currentValue: root.layoutData?.center_focused ?? "never"
                    options: [
                        { displayName: Translation.tr("Never"), icon: "align_horizontal_left", value: "never" },
                        { displayName: Translation.tr("On overflow"), icon: "align_horizontal_center", value: "on-overflow" },
                        { displayName: Translation.tr("Always"), icon: "center_focus_strong", value: "always" }
                    ]
                    onSelected: newValue => {
                        root.setConfig("layout", "center-focused-column", newValue)
                    }
                }
            }

            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "center_focus_strong"
                text: Translation.tr("Always center a single column")
                checked: root.layoutData?.always_center_single_column ?? false
                onCheckedChanged: {
                    if (!root.layoutReady) return
                    root.setBooleanConfig("layout", "always-center-single-column", checked)
                }
            }

            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "fullscreen"
                text: Translation.tr("Auto-expand a single tiling window")
                checked: Config.options?.compositor?.autoExpandSingleTilingWindow ?? false
                onCheckedChanged: Config.setNestedValue("compositor.autoExpandSingleTilingWindow", checked)
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Runs the same Niri maximize-column action as Mod+D when the focused workspace has exactly one normal tiling window. It skips fullscreen-like windows and Game Mode, and it does not rebalance after more windows appear.")
                wrapMode: Text.WordWrap
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }

            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "vertical_align_top"
                text: Translation.tr("Empty workspace above first")
                checked: root.layoutData?.empty_workspace_above_first ?? false
                onCheckedChanged: {
                    if (!root.layoutReady) return
                    root.setBooleanConfig("layout", "empty-workspace-above-first", checked)
                }
            }

            ContentSubsection {
                title: Translation.tr("Default column display")
                tooltip: Translation.tr("Choose whether new columns open normally or in tabbed mode.")

                StyledComboBox {
                    Layout.fillWidth: true
                    model: root.defaultColumnDisplayOptions
                    textRole: "displayName"
                    currentIndex: root.choiceIndex(model, root.layoutData?.default_column_display ?? "normal")
                    onActivated: root.setConfig("layout", "default-column-display", model[currentIndex].value)
                }
            }

            SettingsDivider {}

            ContentSubsection {
                title: Translation.tr("Window border")
            }

            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "border_style"
                text: Translation.tr("Enable border")
                checked: root.layoutData?.border?.enabled ?? false
                onCheckedChanged: {
                    if (!root.layoutReady) return
                    root.setBooleanConfig("layout", "border.enabled", checked)
                }
            }

            ContentSubsection {
                title: Translation.tr("Border width")
                visible: root.layoutData?.border?.enabled ?? false

                ConfigSpinBox {
                    text: Translation.tr("Width (px)")
                    value: root.layoutData?.border?.width ?? 4
                    from: 1
                    to: 8
                    stepSize: 1
                    onValueChanged: {
                        if (!root.layoutReady) return
                        root.setConfig("layout", "border.width", value)
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Border active color")
                visible: root.layoutData?.border?.enabled ?? false

                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: "#RRGGBB"
                    text: root.layoutData?.border?.active_color ?? "#707070"
                    onEditingFinished: {
                        const val = text.trim()
                        if (val.length > 0)
                            root.setConfig("layout", "border.active-color", val)
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Border inactive color")
                visible: root.layoutData?.border?.enabled ?? false

                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: "#RRGGBB"
                    text: root.layoutData?.border?.inactive_color ?? "#d0d0d0"
                    onEditingFinished: {
                        const val = text.trim()
                        if (val.length > 0)
                            root.setConfig("layout", "border.inactive-color", val)
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Border urgent color")
                visible: root.layoutData?.border?.enabled ?? false

                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: "#RRGGBB"
                    text: root.layoutData?.border?.urgent_color ?? "#cc4444"
                    onEditingFinished: {
                        const val = text.trim()
                        if (val.length > 0)
                            root.setConfig("layout", "border.urgent-color", val)
                    }
                }
            }

            SettingsDivider {}

            ContentSubsection {
                title: Translation.tr("Focus ring")
            }

            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "radio_button_checked"
                text: Translation.tr("Enable focus ring")
                checked: root.layoutData?.focus_ring?.enabled ?? false
                onCheckedChanged: {
                    if (!root.layoutReady) return
                    root.setBooleanConfig("layout", "focus-ring.enabled", checked)
                }
            }

            ContentSubsection {
                title: Translation.tr("Focus ring width")
                visible: root.layoutData?.focus_ring?.enabled ?? false

                ConfigSpinBox {
                    text: Translation.tr("Width (px)")
                    value: root.layoutData?.focus_ring?.width ?? 1
                    from: 1
                    to: 8
                    stepSize: 1
                    onValueChanged: {
                        if (!root.layoutReady) return
                        root.setConfig("layout", "focus-ring.width", value)
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Focus ring active color")
                visible: root.layoutData?.focus_ring?.enabled ?? false

                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: "#RRGGBB"
                    text: root.layoutData?.focus_ring?.active_color ?? "#808080"
                    onEditingFinished: {
                        const val = text.trim()
                        if (val.length > 0)
                            root.setConfig("layout", "focus-ring.active-color", val)
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Focus ring inactive color")
                visible: root.layoutData?.focus_ring?.enabled ?? false

                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: "#RRGGBB"
                    text: root.layoutData?.focus_ring?.inactive_color ?? "#505050"
                    onEditingFinished: {
                        const val = text.trim()
                        if (val.length > 0)
                            root.setConfig("layout", "focus-ring.inactive-color", val)
                    }
                }
            }

            SettingsDivider {}

            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "shadow"
                text: Translation.tr("Window shadow")
                checked: root.layoutData?.shadow?.enabled ?? true
                onCheckedChanged: {
                    if (!root.layoutReady) return
                    root.setBooleanConfig("layout", "shadow.enabled", checked)
                }
            }

            ContentSubsection {
                title: Translation.tr("Shadow softness")
                visible: root.layoutData?.shadow?.enabled ?? true

                ConfigSpinBox {
                    text: Translation.tr("Softness")
                    value: root.layoutData?.shadow?.softness ?? 30
                    from: 0
                    to: 100
                    stepSize: 1
                    onValueChanged: {
                        if (!root.layoutReady) return
                        root.setConfig("layout", "shadow.softness", value)
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Shadow spread")
                visible: root.layoutData?.shadow?.enabled ?? true

                ConfigSpinBox {
                    text: Translation.tr("Spread")
                    value: root.layoutData?.shadow?.spread ?? 5
                    from: -32
                    to: 64
                    stepSize: 1
                    onValueChanged: {
                        if (!root.layoutReady) return
                        root.setConfig("layout", "shadow.spread", value)
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Shadow offset")
                visible: root.layoutData?.shadow?.enabled ?? true

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    ConfigSpinBox {
                        id: shadowOffsetXSpin
                        Layout.fillWidth: true
                        text: "X"
                        value: root.layoutData?.shadow?.offset_x ?? 0
                        from: -100
                        to: 100
                        stepSize: 1
                        onValueChanged: {
                            if (!root.layoutReady || !root.shadowEditorReady) return
                            root.setConfig("layout", "shadow.offset", `${value},${shadowOffsetYSpin.value}`)
                        }
                    }

                    ConfigSpinBox {
                        id: shadowOffsetYSpin
                        Layout.fillWidth: true
                        text: "Y"
                        value: root.layoutData?.shadow?.offset_y ?? 5
                        from: -100
                        to: 100
                        stepSize: 1
                        onValueChanged: {
                            if (!root.layoutReady || !root.shadowEditorReady) return
                            root.setConfig("layout", "shadow.offset", `${shadowOffsetXSpin.value},${value}`)
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Shadow color")
                visible: root.layoutData?.shadow?.enabled ?? true

                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: "#RRGGBBAA"
                    text: root.layoutData?.shadow?.color ?? "#0007"
                    onEditingFinished: {
                        const val = text.trim()
                        if (val.length > 0)
                            root.setConfig("layout", "shadow.color", val)
                    }
                }
            }

            SettingsDivider {}

            ContentSubsection {
                title: Translation.tr("Struts")
                tooltip: Translation.tr("Shrink the tiling area by this many pixels from each edge")
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ConfigSpinBox {
                    Layout.fillWidth: true
                    text: Translation.tr("Left")
                    icon: "arrow_back"
                    value: root.layoutData?.struts?.left ?? 0
                    from: 0
                    to: 512
                    stepSize: 8
                    onValueChanged: {
                        if (!root.layoutReady) return
                        root.setConfig("layout", "struts.left", value)
                    }
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    text: Translation.tr("Right")
                    icon: "arrow_forward"
                    value: root.layoutData?.struts?.right ?? 0
                    from: 0
                    to: 512
                    stepSize: 8
                    onValueChanged: {
                        if (!root.layoutReady) return
                        root.setConfig("layout", "struts.right", value)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ConfigSpinBox {
                    Layout.fillWidth: true
                    text: Translation.tr("Top")
                    icon: "arrow_upward"
                    value: root.layoutData?.struts?.top ?? 0
                    from: 0
                    to: 512
                    stepSize: 8
                    onValueChanged: {
                        if (!root.layoutReady) return
                        root.setConfig("layout", "struts.top", value)
                    }
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    text: Translation.tr("Bottom")
                    icon: "arrow_downward"
                    value: root.layoutData?.struts?.bottom ?? 0
                    from: 0
                    to: 512
                    stepSize: 8
                    onValueChanged: {
                        if (!root.layoutReady) return
                        root.setConfig("layout", "struts.bottom", value)
                    }
                }
            }

            SettingsDivider {}

            ContentSubsection {
                title: Translation.tr("Overview zoom")
                tooltip: Translation.tr("How much workspaces are scaled in the overview")

                ConfigSpinBox {
                    text: Translation.tr("Zoom (%)")
                    value: Math.round((root.layoutData?.overview_zoom ?? 0.75) * 100)
                    from: 30
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        if (!root.layoutReady) return
                        root.setConfig("layout", "overview.zoom", (value / 100.0).toFixed(2))
                    }
                }
            }
        }
    }

    // =====================
    // WINDOW RULES SECTION
    // =====================
    SettingsCardSection {
        expanded: false
        icon: "rounded_corner"
        title: Translation.tr("Window Rules")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Corner radius")
                tooltip: Translation.tr("Rounding applied to window corners (0 = square)")

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledSlider {
                        id: cornerRadiusSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 32
                        value: root.windowRulesData?.corner_radius ?? 16
                        stepSize: 1
                        configuration: StyledSlider.Configuration.S

                        onMoved: {
                            if (pressed) return
                            root.setConfig("window-rules", "corner-radius", String(Math.round(value)))
                        }
                    }

                    StyledText {
                        text: Math.round(cornerRadiusSlider.value) + "px"
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.monospace
                        color: Appearance.colors.colSubtext
                        Layout.preferredWidth: 35
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            SettingsDivider {}

            ContentSubsection {
                title: Translation.tr("Inactive window opacity")
                tooltip: Translation.tr("Transparency of unfocused windows (1.0 = fully opaque)")

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledSlider {
                        id: inactiveOpacitySlider
                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        value: Math.round((root.windowRulesData?.inactive_opacity ?? 0.9) * 100)
                        stepSize: 5
                        configuration: StyledSlider.Configuration.S

                        onMoved: {
                            if (pressed) return
                            root.setConfig("window-rules", "inactive-opacity", (value / 100.0).toFixed(2))
                        }
                    }

                    StyledText {
                        text: (inactiveOpacitySlider.value / 100.0).toFixed(2)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.monospace
                        color: Appearance.colors.colSubtext
                        Layout.preferredWidth: 35
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "crop"
                text: Translation.tr("Clip windows to rounded geometry")
                checked: root.windowRulesData?.clip_to_geometry ?? true
                onCheckedChanged: {
                    if (!root.windowRulesReady) return
                    root.setConfig("window-rules", "clip-to-geometry", checked ? "true" : "false")
                }
            }
        }
    }

    // =====================
    // KEYBOARD SECTION
    // =====================
    SettingsCardSection {
        expanded: false
        icon: "keyboard"
        title: Translation.tr("Keyboard")

        SettingsGroup {
            // --- Keyboard layout ---
            ContentSubsection {
                title: Translation.tr("Keyboard layout")
                tooltip: Translation.tr("XKB keyboard layout (e.g. us, es, de, fr)")

                StyledComboBox {
                    id: keyboardLayoutCombo
                    Layout.fillWidth: true
                    model: root.keyboardLayoutOptions
                    textRole: "displayName"
                    currentIndex: {
                        const idx = root.choiceIndex(model, root.keyboardData?.layout ?? "us")
                        return idx >= 0 ? idx : root.keyboardLayoutOptions.length - 1
                    }
                    onActivated: {
                        const selected = model[currentIndex].value
                        if (selected !== "__custom__")
                            root.setConfig("input", "keyboard.layout", selected)
                    }
                }

                MaterialTextField {
                    Layout.fillWidth: true
                    visible: keyboardLayoutCombo.currentIndex === root.keyboardLayoutOptions.length - 1
                    placeholderText: Translation.tr("XKB layout code (e.g. pl, ar, th, vi)")
                    text: root.keyboardData?.layout ?? ""
                    onEditingFinished: {
                        const val = text.trim()
                        if (val.length > 0)
                            root.setConfig("input", "keyboard.layout", val)
                    }
                }
            }

            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "dialpad"
                text: Translation.tr("Numlock on startup")
                checked: root.keyboardData?.numlock ?? false
                onCheckedChanged: {
                    if (!root.inputReady) return
                    root.setBooleanConfig("input", "keyboard.numlock", checked)
                }
            }

            ContentSubsection {
                title: Translation.tr("Track layout")
                tooltip: Translation.tr("Keep the same layout globally or remember it per window.")

                StyledComboBox {
                    Layout.fillWidth: true
                    model: root.trackLayoutOptions
                    textRole: "displayName"
                    currentIndex: root.choiceIndex(model, root.keyboardData?.track_layout ?? "global")
                    onActivated: root.setConfig("input", "keyboard.track-layout", model[currentIndex].value)
                }
            }

            ContentSubsection {
                title: Translation.tr("Variant")
                tooltip: Translation.tr("Optional XKB variant, for example colemak_dh or nodeadkeys.")

                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Optional - e.g. colemak_dh")
                    text: root.keyboardData?.variant ?? ""
                    onEditingFinished: root.setConfig("input", "keyboard.variant", text.trim())
                }
            }

            ContentSubsection {
                title: Translation.tr("XKB options")
                tooltip: Translation.tr("Comma-separated options passed to libxkbcommon, such as compose:ralt or ctrl:nocaps.")

                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Optional - e.g. grp:win_space_toggle,compose:ralt")
                    text: root.keyboardData?.options ?? ""
                    onEditingFinished: root.setConfig("input", "keyboard.options", text.trim())
                }
            }

            ContentSubsection {
                title: Translation.tr("Modifiers")
                tooltip: Translation.tr("Choose which modifier Niri treats as Mod on bare metal and in nested sessions.")

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledComboBox {
                        Layout.fillWidth: true
                        model: root.modKeyOptions.map(value => ({ displayName: value, value }))
                        textRole: "displayName"
                        currentIndex: root.choiceIndex(model, root.generalInputData?.mod_key ?? "Super")
                        onActivated: root.setConfig("input", "mod-key", model[currentIndex].value)
                    }

                    StyledComboBox {
                        Layout.fillWidth: true
                        model: root.modKeyOptions.map(value => ({ displayName: value, value }))
                        textRole: "displayName"
                        currentIndex: root.choiceIndex(model, root.generalInputData?.mod_key_nested ?? "Alt")
                        onActivated: root.setConfig("input", "mod-key-nested", model[currentIndex].value)
                    }
                }
            }

            SettingsDivider {}

            ContentSubsection {
                title: Translation.tr("Key repeat delay")
                tooltip: Translation.tr("Milliseconds before a held key starts repeating")

                ConfigSpinBox {
                    text: Translation.tr("Delay (ms)")
                    value: root.keyboardData?.repeat_delay ?? 250
                    from: 100
                    to: 1000
                    stepSize: 50
                    onValueChanged: {
                        if (!root.inputReady) return
                        root.setConfig("input", "keyboard.repeat-delay", value)
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Key repeat rate")
                tooltip: Translation.tr("Characters per second when a key is held")

                ConfigSpinBox {
                    text: Translation.tr("Rate (chars/s)")
                    value: root.keyboardData?.repeat_rate ?? 50
                    from: 10
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        if (!root.inputReady) return
                        root.setConfig("input", "keyboard.repeat-rate", value)
                    }
                }
            }
        }
    }

    // =====================
    // TOUCHPAD SECTION
    // =====================
    SettingsCardSection {
        expanded: false
        icon: "touch_app"
        title: Translation.tr("Touchpad")

        SettingsGroup {
            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "touch_app"
                text: Translation.tr("Tap to click")
                checked: root.touchpadData?.tap ?? true
                onCheckedChanged: {
                    if (!root.inputReady) return
                    root.setBooleanConfig("input", "touchpad.tap", checked)
                }
            }

            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "swipe"
                text: Translation.tr("Natural scroll")
                checked: root.touchpadData?.natural_scroll ?? false
                onCheckedChanged: {
                    if (!root.inputReady) return
                    root.setBooleanConfig("input", "touchpad.natural-scroll", checked)
                }
            }

            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "block"
                text: Translation.tr("Disable while typing")
                checked: root.touchpadData?.dwt ?? false
                onCheckedChanged: {
                    if (!root.inputReady) return
                    root.setBooleanConfig("input", "touchpad.dwt", checked)
                }
            }

            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "joystick"
                text: Translation.tr("Disable while trackpointing")
                checked: root.touchpadData?.dwtp ?? false
                onCheckedChanged: {
                    if (!root.inputReady) return
                    root.setBooleanConfig("input", "touchpad.dwtp", checked)
                }
            }

            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "mouse"
                text: Translation.tr("Disable with external mouse")
                checked: root.touchpadData?.disabled_on_external_mouse ?? false
                onCheckedChanged: {
                    if (!root.inputReady) return
                    root.setBooleanConfig("input", "touchpad.disabled-on-external-mouse", checked)
                }
            }

            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "left_click"
                text: Translation.tr("Left-handed")
                checked: root.touchpadData?.left_handed ?? false
                onCheckedChanged: {
                    if (!root.inputReady) return
                    root.setBooleanConfig("input", "touchpad.left-handed", checked)
                }
            }

            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "ads_click"
                text: Translation.tr("Middle-click emulation")
                checked: root.touchpadData?.middle_emulation ?? false
                onCheckedChanged: {
                    if (!root.inputReady) return
                    root.setBooleanConfig("input", "touchpad.middle-emulation", checked)
                }
            }

            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "pan_tool"
                text: Translation.tr("Drag lock")
                checked: root.touchpadData?.drag_lock ?? false
                onCheckedChanged: {
                    if (!root.inputReady) return
                    root.setBooleanConfig("input", "touchpad.drag-lock", checked)
                }
            }

            ContentSubsection {
                title: Translation.tr("Touchpad acceleration")

                ConfigSelectionArray {
                    currentValue: root.touchpadData?.accel_profile ?? "adaptive"
                    options: [
                        { displayName: Translation.tr("Adaptive"), icon: "tune", value: "adaptive" },
                        { displayName: Translation.tr("Flat"), icon: "horizontal_rule", value: "flat" }
                    ]
                    onSelected: newValue => {
                        root.setConfig("input", "touchpad.accel-profile", newValue)
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Touchpad scrolling")

                StyledComboBox {
                    Layout.fillWidth: true
                    model: root.touchpadScrollMethodOptions
                    textRole: "displayName"
                    currentIndex: root.choiceIndex(model, root.touchpadData?.scroll_method ?? "two-finger")
                    onActivated: root.setConfig("input", "touchpad.scroll-method", model[currentIndex].value)
                }
            }

            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "lock"
                text: Translation.tr("Scroll button lock")
                checked: root.touchpadData?.scroll_button_lock ?? false
                onCheckedChanged: {
                    if (!root.inputReady) return
                    root.setBooleanConfig("input", "touchpad.scroll-button-lock", checked)
                }
            }

            ContentSubsection {
                title: Translation.tr("Tap button map")

                StyledComboBox {
                    Layout.fillWidth: true
                    model: root.tapButtonMapOptions
                    textRole: "displayName"
                    currentIndex: root.choiceIndex(model, root.touchpadData?.tap_button_map ?? "left-right-middle")
                    onActivated: root.setConfig("input", "touchpad.tap-button-map", model[currentIndex].value)
                }
            }

            ContentSubsection {
                title: Translation.tr("Click method")

                StyledComboBox {
                    Layout.fillWidth: true
                    model: root.clickMethodOptions
                    textRole: "displayName"
                    currentIndex: root.choiceIndex(model, root.touchpadData?.click_method ?? "button-areas")
                    onActivated: root.setConfig("input", "touchpad.click-method", model[currentIndex].value)
                }
            }

            ContentSubsection {
                title: Translation.tr("Touchpad speed")
                tooltip: Translation.tr("Acceleration speed. Negative = slower, positive = faster.")

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledSlider {
                        id: touchpadSpeedSlider
                        Layout.fillWidth: true
                        from: -100
                        to: 100
                        value: Math.round((root.touchpadData?.accel_speed ?? 0) * 100)
                        stepSize: 5
                        configuration: StyledSlider.Configuration.S

                        onMoved: {
                            if (pressed) return
                            root.setConfig("input", "touchpad.accel-speed", (value / 100.0).toFixed(2))
                        }
                    }

                    StyledText {
                        text: (touchpadSpeedSlider.value / 100.0).toFixed(2)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.monospace
                        color: Appearance.colors.colSubtext
                        Layout.preferredWidth: 40
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }

    // =====================
    // MOUSE SECTION
    // =====================
    SettingsCardSection {
        expanded: false
        icon: "mouse"
        title: Translation.tr("Mouse")

        SettingsGroup {
            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "swipe"
                text: Translation.tr("Natural scroll")
                checked: root.mouseData?.natural_scroll ?? false
                onCheckedChanged: {
                    if (!root.inputReady) return
                    root.setBooleanConfig("input", "mouse.natural-scroll", checked)
                }
            }

            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "left_click"
                text: Translation.tr("Left-handed")
                checked: root.mouseData?.left_handed ?? false
                onCheckedChanged: {
                    if (!root.inputReady) return
                    root.setBooleanConfig("input", "mouse.left-handed", checked)
                }
            }

            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "ads_click"
                text: Translation.tr("Middle-click emulation")
                checked: root.mouseData?.middle_emulation ?? false
                onCheckedChanged: {
                    if (!root.inputReady) return
                    root.setBooleanConfig("input", "mouse.middle-emulation", checked)
                }
            }

            ContentSubsection {
                title: Translation.tr("Mouse acceleration")

                ConfigSelectionArray {
                    currentValue: root.mouseData?.accel_profile ?? "flat"
                    options: [
                        { displayName: Translation.tr("Adaptive"), icon: "tune", value: "adaptive" },
                        { displayName: Translation.tr("Flat"), icon: "horizontal_rule", value: "flat" }
                    ]
                    onSelected: newValue => {
                        root.setConfig("input", "mouse.accel-profile", newValue)
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Mouse scrolling")

                StyledComboBox {
                    Layout.fillWidth: true
                    model: root.pointerScrollMethodOptions
                    textRole: "displayName"
                    currentIndex: root.choiceIndex(model, root.mouseData?.scroll_method ?? "no-scroll")
                    onActivated: root.setConfig("input", "mouse.scroll-method", model[currentIndex].value)
                }
            }

            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "lock"
                text: Translation.tr("Scroll button lock")
                checked: root.mouseData?.scroll_button_lock ?? false
                onCheckedChanged: {
                    if (!root.inputReady) return
                    root.setBooleanConfig("input", "mouse.scroll-button-lock", checked)
                }
            }

            ContentSubsection {
                title: Translation.tr("Mouse speed")
                tooltip: Translation.tr("Acceleration speed. Negative = slower, positive = faster.")

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledSlider {
                        id: mouseSpeedSlider
                        Layout.fillWidth: true
                        from: -100
                        to: 100
                        value: Math.round((root.mouseData?.accel_speed ?? 0) * 100)
                        stepSize: 5
                        configuration: StyledSlider.Configuration.S

                        onMoved: {
                            if (pressed) return
                            root.setConfig("input", "mouse.accel-speed", (value / 100.0).toFixed(2))
                        }
                    }

                    StyledText {
                        text: (mouseSpeedSlider.value / 100.0).toFixed(2)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.monospace
                        color: Appearance.colors.colSubtext
                        Layout.preferredWidth: 40
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }

    // =====================
    // TRACKPOINT SECTION
    // =====================
    SettingsCardSection {
        expanded: false
        icon: "joystick"
        title: Translation.tr("Trackpoint")

        SettingsGroup {
            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "swap_vert"
                text: Translation.tr("Natural scroll")
                checked: root.trackpointData?.natural_scroll ?? false
                onCheckedChanged: {
                    if (!root.inputReady) return
                    root.setBooleanConfig("input", "trackpoint.natural-scroll", checked)
                }
            }

            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "left_click"
                text: Translation.tr("Left-handed")
                checked: root.trackpointData?.left_handed ?? false
                onCheckedChanged: {
                    if (!root.inputReady) return
                    root.setBooleanConfig("input", "trackpoint.left-handed", checked)
                }
            }

            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "ads_click"
                text: Translation.tr("Middle-click emulation")
                checked: root.trackpointData?.middle_emulation ?? false
                onCheckedChanged: {
                    if (!root.inputReady) return
                    root.setBooleanConfig("input", "trackpoint.middle-emulation", checked)
                }
            }

            ContentSubsection {
                title: Translation.tr("Trackpoint acceleration")

                ConfigSelectionArray {
                    currentValue: root.trackpointData?.accel_profile ?? "flat"
                    options: [
                        { displayName: Translation.tr("Adaptive"), icon: "tune", value: "adaptive" },
                        { displayName: Translation.tr("Flat"), icon: "horizontal_rule", value: "flat" }
                    ]
                    onSelected: newValue => root.setConfig("input", "trackpoint.accel-profile", newValue)
                }
            }

            ContentSubsection {
                title: Translation.tr("Trackpoint scrolling")

                StyledComboBox {
                    Layout.fillWidth: true
                    model: root.pointerScrollMethodOptions
                    textRole: "displayName"
                    currentIndex: root.choiceIndex(model, root.trackpointData?.scroll_method ?? "on-button-down")
                    onActivated: root.setConfig("input", "trackpoint.scroll-method", model[currentIndex].value)
                }
            }

            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "lock"
                text: Translation.tr("Scroll button lock")
                checked: root.trackpointData?.scroll_button_lock ?? false
                onCheckedChanged: {
                    if (!root.inputReady) return
                    root.setBooleanConfig("input", "trackpoint.scroll-button-lock", checked)
                }
            }

            ContentSubsection {
                title: Translation.tr("Trackpoint speed")
                tooltip: Translation.tr("Acceleration speed. Negative = slower, positive = faster.")

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledSlider {
                        id: trackpointSpeedSlider
                        Layout.fillWidth: true
                        from: -100
                        to: 100
                        value: Math.round((root.trackpointData?.accel_speed ?? 0) * 100)
                        stepSize: 5
                        configuration: StyledSlider.Configuration.S

                        onMoved: {
                            if (pressed) return
                            root.setConfig("input", "trackpoint.accel-speed", (value / 100.0).toFixed(2))
                        }
                    }

                    StyledText {
                        text: (trackpointSpeedSlider.value / 100.0).toFixed(2)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.monospace
                        color: Appearance.colors.colSubtext
                        Layout.preferredWidth: 40
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }

    // =====================
    // CURSOR SECTION
    // =====================
    SettingsCardSection {
        expanded: false
        icon: "point_scan"
        title: Translation.tr("Cursor")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Cursor theme")
                visible: root.cursorThemes.length > 0

                StyledComboBox {
                    Layout.fillWidth: true
                    model: root.cursorThemes
                    currentIndex: root.cursorThemes.indexOf(root.cursorData?.theme ?? "")
                    onActivated: root.setConfig("input", "cursor.xcursor-theme", model[currentIndex])
                }
            }

            ContentSubsection {
                title: Translation.tr("Cursor size")
                tooltip: Translation.tr("Size in pixels (typically 24 or 32)")

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledSlider {
                        id: cursorSizeSlider
                        Layout.fillWidth: true
                        from: 16
                        to: 48
                        value: root.cursorData?.size ?? 24
                        stepSize: 2
                        configuration: StyledSlider.Configuration.S

                        onMoved: {
                            if (pressed) return
                            root.setConfig("input", "cursor.xcursor-size", String(Math.round(value)))
                        }
                    }

                    StyledText {
                        text: Math.round(cursorSizeSlider.value) + "px"
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.monospace
                        color: Appearance.colors.colSubtext
                        Layout.preferredWidth: 35
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "keyboard_hide"
                text: Translation.tr("Hide cursor while typing")
                checked: root.cursorData?.hide_when_typing ?? true
                onCheckedChanged: {
                    if (!root.inputReady) return
                    root.setBooleanConfig("input", "cursor.hide-when-typing", checked)
                }
            }
        }
    }

    // =====================
    // GENERAL INPUT SECTION
    // =====================
    SettingsCardSection {
        expanded: false
        icon: "settings_input_composite"
        title: Translation.tr("General Input")

        SettingsGroup {
            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "power_settings_new"
                text: Translation.tr("Disable power key handling")
                checked: root.generalInputData?.disable_power_key_handling ?? false
                onCheckedChanged: {
                    if (!root.inputReady) return
                    root.setBooleanConfig("input", "disable-power-key-handling", checked)
                }
            }

            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "history"
                text: Translation.tr("Workspace auto back-and-forth")
                checked: root.generalInputData?.workspace_auto_back_and_forth ?? false
                onCheckedChanged: {
                    if (!root.inputReady) return
                    root.setBooleanConfig("input", "workspace-auto-back-and-forth", checked)
                }
            }

            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "center_focus_strong"
                text: Translation.tr("Warp pointer to focused window")
                checked: root.generalInputData?.warp_mouse_to_focus ?? false
                onCheckedChanged: {
                    if (!root.inputReady) return
                    root.setWarpMouseMode(checked ? (root.generalInputData?.warp_mouse_to_focus_mode ?? "separate") : "off")
                }
            }

            ContentSubsection {
                title: Translation.tr("Warp mode")
                visible: root.generalInputData?.warp_mouse_to_focus ?? false

                StyledComboBox {
                    Layout.fillWidth: true
                    model: root.warpMouseModeOptions
                    textRole: "displayName"
                    currentIndex: root.choiceIndex(model, root.generalInputData?.warp_mouse_to_focus_mode ?? "separate")
                    onActivated: root.setWarpMouseMode(model[currentIndex].value)
                }
            }

            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "mouse"
                text: Translation.tr("Focus follows mouse")
                checked: root.generalInputData?.focus_follows_mouse ?? false
                onCheckedChanged: {
                    if (!root.inputReady) return
                    root.setFocusFollowsMouse(checked)
                }
            }

            ContentSubsection {
                title: Translation.tr("Focus follows mouse threshold")
                tooltip: Translation.tr("Maximum scroll amount allowed when focusing a window by hover. 0% means only fully visible windows.")
                visible: root.generalInputData?.focus_follows_mouse ?? false

                ConfigSpinBox {
                    text: Translation.tr("Max scroll (%)")
                    value: root.generalInputData?.focus_follows_mouse_max_scroll ?? 0
                    from: 0
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        if (!root.inputReady) return
                        root.setFocusFollowsMouse(true, value)
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Niri exposes many more compositor options in raw KDL. This page covers the most common ones safely and validates every change before keeping it.")
                wrapMode: Text.WordWrap
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }
    }

    // =====================
    // ANIMATIONS SECTION
    // =====================
    SettingsCardSection {
        expanded: false
        icon: "animation"
        title: Translation.tr("Animations")

        SettingsGroup {
            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "animation"
                text: Translation.tr("Enable animations")
                checked: root.animationsData?.enabled ?? true
                onCheckedChanged: {
                    if (!root.animationsReady) return
                    root.setBooleanConfig("animations", "enabled", checked)
                }
            }

            ContentSubsection {
                title: Translation.tr("Global slowdown")
                tooltip: Translation.tr("1.0 is normal speed. Higher values make every animation slower.")

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledSlider {
                        id: slowdownSlider
                        Layout.fillWidth: true
                        from: 50
                        to: 500
                        value: Math.round((root.animationsData?.slowdown ?? 1.0) * 100)
                        stepSize: 10
                        configuration: StyledSlider.Configuration.S
                        onMoved: {
                            if (pressed) return
                            root.setConfig("animations", "slowdown", (value / 100.0).toFixed(2))
                        }
                    }

                    StyledText {
                        text: (slowdownSlider.value / 100.0).toFixed(2) + "x"
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.monospace
                        color: Appearance.colors.colSubtext
                        Layout.preferredWidth: 42
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            StyledText {
                text: Translation.tr("Tune the spring physics for each animation type. Higher stiffness = snappier, higher damping = less bounce.")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: Object.keys(root.animationsData?.types ?? {})

                delegate: ColumnLayout {
                    id: animDelegate
                    Layout.fillWidth: true
                    spacing: 4

                    required property string modelData
                    readonly property var springData: root.animationsData?.types?.[modelData] ?? {}

                    SettingsDivider {}

                    ContentSubsection {
                        title: root.animationLabels[animDelegate.modelData] ?? animDelegate.modelData
                    }

                    SettingsSwitch {
                        Layout.fillWidth: true
                        buttonIcon: "animation"
                        text: Translation.tr("Enable this animation")
                        checked: root.animationIsEnabled(animDelegate.springData)
                        onCheckedChanged: {
                            if (!root.animationsReady) return
                            root.setBooleanConfig("animations", animDelegate.modelData + ".enabled", checked)
                        }
                    }

                    StyledText {
                        text: Translation.tr("Damping ratio")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        visible: (animDelegate.springData?.mode ?? "spring") === "spring" && root.animationIsEnabled(animDelegate.springData)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: (animDelegate.springData?.mode ?? "spring") === "spring" && root.animationIsEnabled(animDelegate.springData)

                        StyledSlider {
                            id: dampingSlider
                            Layout.fillWidth: true
                            from: 1
                            to: 200
                            value: Math.round((animDelegate.springData?.damping_ratio ?? 1.0) * 100)
                            stepSize: 5
                            configuration: StyledSlider.Configuration.S

                            onMoved: {
                                if (pressed) return
                                root.setConfig("animations", animDelegate.modelData + ".damping-ratio", (value / 100.0).toFixed(2))
                            }
                        }

                        StyledText {
                            text: (dampingSlider.value / 100.0).toFixed(2)
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.family: Appearance.font.family.monospace
                            color: Appearance.colors.colSubtext
                            Layout.preferredWidth: 35
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    StyledText {
                        text: Translation.tr("Stiffness")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        visible: (animDelegate.springData?.mode ?? "spring") === "spring" && root.animationIsEnabled(animDelegate.springData)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: (animDelegate.springData?.mode ?? "spring") === "spring" && root.animationIsEnabled(animDelegate.springData)

                        StyledSlider {
                            id: stiffnessSlider
                            Layout.fillWidth: true
                            from: 50
                            to: 2000
                            value: animDelegate.springData?.stiffness ?? 800
                            stepSize: 50
                            configuration: StyledSlider.Configuration.S

                            onMoved: {
                                if (pressed) return
                                root.setConfig("animations", animDelegate.modelData + ".stiffness", String(Math.round(value)))
                            }
                        }

                        StyledText {
                            text: String(Math.round(stiffnessSlider.value))
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.family: Appearance.font.family.monospace
                            color: Appearance.colors.colSubtext
                            Layout.preferredWidth: 40
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }
        }
    }

    // =====================
    // APPLICATIONS SECTION
    // =====================
    SettingsCardSection {
        expanded: false
        icon: "apps"
        title: Translation.tr("Applications")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Choose known app presets for common shell actions, or switch a slot to a custom command when you need something more specific.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: AppLauncher.slotDefinitions()

                delegate: ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    required property var modelData

                    readonly property int _rev: AppLauncher._configRevision
                    readonly property var presetOptions: { void(_rev); return AppLauncher.presetOptions(modelData.id) }
                    readonly property string presetId: { void(_rev); return AppLauncher.presetIdFor(modelData.id) }

                    StyledText {
                        text: modelData.label
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: modelData.description
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.small
                        wrapMode: Text.WordWrap
                    }

                    StyledComboBox {
                        Layout.fillWidth: true
                        model: presetOptions
                        textRole: "displayName"
                        currentIndex: root.choiceIndex(model, presetId)
                        onActivated: {
                            const selectedValue = model[currentIndex].value
                            if (selectedValue !== "__custom__")
                                AppLauncher.applyPreset(modelData.id, selectedValue)
                        }
                    }

                    MaterialTextField {
                        Layout.fillWidth: true
                        visible: presetId === "__custom__"
                        placeholderText: modelData.placeholder
                        text: { void(_rev); return AppLauncher.commandFor(modelData.id) }
                        onEditingFinished: AppLauncher.setCustomCommand(modelData.id, text)
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: { void(_rev); return Translation.tr("Current command: %1").arg(AppLauncher.commandFor(modelData.id)) }
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.monospace
                        wrapMode: Text.WrapAnywhere
                    }

                    SettingsDivider { visible: index < AppLauncher.slotDefinitions().length - 1 }
                }
            }
        }
    }
}
