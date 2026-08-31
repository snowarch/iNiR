pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.services

/**
 * Game-aware performance telemetry for the Super+G overlay.
 *
 * FPS and frametime are only authoritative when a game is instrumented by
 * MangoHud. ResourceUsage remains the safe fallback for machine-wide load.
 */
Singleton {
    id: root

    property int _consumers: 0
    property bool mangoHudInstalled: false

    property bool gameDetected: false
    property string gameName: ""
    property string gameAppId: ""
    property int gamePid: 0

    property bool telemetryAvailable: false
    property real _mangoFps: -1
    property real _mangoFrametime: -1
    property real _mangoCpuLoad: -1
    property real _mangoCpuPower: -1
    property real _mangoCpuFrequencyMhz: -1
    property real _mangoGpuLoad: -1
    property real _mangoCpuTemp: -1
    property real _mangoGpuTemp: -1
    property real _mangoGpuCoreClockMhz: -1
    property real _mangoGpuMemoryClockMhz: -1
    property real _mangoVramUsedGb: -1
    property real _mangoGpuPower: -1
    property real _mangoGpuVoltage: -1
    property real _mangoRamUsedGb: -1
    property real _mangoSwapUsedGb: -1
    property real _mangoProcessMemoryGb: -1
    property string _mangoGraphicsApi: ""
    property string _mangoWineProton: ""
    property string _mangoFexStats: ""
    property string _mangoHudVersion: ""
    property string _mangoCpuName: ""
    property string _mangoGpuName: ""
    property string _mangoGpuDriver: ""
    property real _systemVramUsedGb: -1
    property real _systemVramTotalGb: -1
    property real _systemGpuLoad: -1
    property real _systemGpuTemp: -1
    property real _systemGpuPower: -1
    property real _systemGpuCoreClockMhz: -1
    property real _systemGpuMemoryClockMhz: -1
    property real _systemCpuFrequencyMhz: -1
    property string _rigCpuName: ""
    property int _rigCpuCores: 0
    property string _rigGpuName: ""
    property string _rigGpuDriver: ""
    property real _rigVramTotalGb: -1
    property real _rigRamTotalGb: -1
    property string _rigKernelVersion: ""
    property string _rigDistroName: ""
    property int _lastSampleAgeMs: -1
    property string _lastSampleId: ""
    property string _gameTargetKey: ""
    property string gameResolution: ""
    property list<real> _cpuCoreLoads: []
    property var _previousCoreStats: ({})
    property var _lastGameWindow: null

    property list<real> fpsHistory: []
    property list<real> frametimeHistory: []
    readonly property int historyLength: 60

    readonly property real fps: telemetryAvailable ? _mangoFps : -1
    readonly property real frametime: telemetryAvailable ? _mangoFrametime : -1
    readonly property real cpuLoad: _validMetric(_mangoCpuLoad)
        ? _mangoCpuLoad : ResourceUsage.cpuUsage * 100
    readonly property real cpuPower: _mangoCpuPower > 0 ? _mangoCpuPower : -1
    readonly property real cpuFrequencyMhz: _mangoCpuFrequencyMhz > 0
        ? _mangoCpuFrequencyMhz : _systemCpuFrequencyMhz
    readonly property list<real> cpuCoreLoads: _cpuCoreLoads
    readonly property int cpuCoreCount: _rigCpuCores > 0 ? _rigCpuCores : _cpuCoreLoads.length
    readonly property real gpuLoad: _preferSystemMetric(_mangoGpuLoad, _systemGpuLoad) >= 0
        ? _preferSystemMetric(_mangoGpuLoad, _systemGpuLoad) : ResourceUsage.gpuUsage * 100
    readonly property real cpuTemp: _mangoCpuTemp > 0
        ? _mangoCpuTemp : (ResourceUsage.cpuTemp > 0 ? ResourceUsage.cpuTemp : -1)
    readonly property real gpuTemp: _preferSystemMetric(_mangoGpuTemp, _systemGpuTemp) >= 0
        ? _preferSystemMetric(_mangoGpuTemp, _systemGpuTemp)
        : (ResourceUsage.gpuTemp > 0 ? ResourceUsage.gpuTemp : -1)
    readonly property real gpuCoreClockMhz: _preferSystemMetric(_mangoGpuCoreClockMhz,
        _systemGpuCoreClockMhz)
    readonly property real gpuMemoryClockMhz: _preferSystemMetric(_mangoGpuMemoryClockMhz,
        _systemGpuMemoryClockMhz)
    readonly property real gpuPower: _preferSystemMetric(_mangoGpuPower, _systemGpuPower)
    readonly property real gpuVoltage: _mangoGpuVoltage > 0 ? _mangoGpuVoltage : -1
    readonly property real ramUsedGb: _validMetric(_mangoRamUsedGb)
        ? _mangoRamUsedGb : ResourceUsage.memoryUsed / (1024 * 1024)
    readonly property real ramTotalGb: ResourceUsage.memoryTotal > 0
        ? ResourceUsage.memoryTotal / (1024 * 1024) : _rigRamTotalGb
    readonly property real vramUsedGb: _validMetric(_systemVramUsedGb)
        ? _systemVramUsedGb : _mangoVramUsedGb
    readonly property real vramTotalGb: _validMetric(_systemVramTotalGb)
        ? _systemVramTotalGb : _rigVramTotalGb
    readonly property real vramUsagePercent: _validMetric(root.vramUsedGb)
        && root.vramTotalGb > 0
        ? Math.min(100, root.vramUsedGb / root.vramTotalGb * 100) : -1
    readonly property real processMemoryGb: _validMetric(_mangoProcessMemoryGb)
        ? _mangoProcessMemoryGb : -1
    readonly property real swapUsedGb: _validMetric(_mangoSwapUsedGb)
        ? _mangoSwapUsedGb : ResourceUsage.swapUsed / (1024 * 1024)
    readonly property real swapTotalGb: ResourceUsage.swapTotal / (1024 * 1024)
    readonly property real diskUsedGb: ResourceUsage.diskUsed / (1024 * 1024 * 1024)
    readonly property real diskTotalGb: ResourceUsage.diskTotal / (1024 * 1024 * 1024)
    readonly property real diskUsagePercent: ResourceUsage.diskUsedPercentage * 100
    readonly property int sampleAgeMs: _lastSampleAgeMs
    readonly property string graphicsApi: _mangoGraphicsApi.length > 0 ? _mangoGraphicsApi : "--"
    readonly property string wineProtonVersion: _mangoWineProton.length > 0 ? _mangoWineProton : "--"
    readonly property string fexStats: _mangoFexStats.length > 0 ? _mangoFexStats : "--"
    readonly property string mangoHudVersion: _mangoHudVersion.length > 0 ? _mangoHudVersion : "--"
    readonly property string cpuName: _mangoCpuName.length > 0
        ? _mangoCpuName : (_rigCpuName.length > 0 ? _rigCpuName : "--")
    readonly property string gpuName: _mangoGpuName.length > 0
        ? _mangoGpuName : (_rigGpuName.length > 0 ? _rigGpuName : "--")
    readonly property string gpuDriver: _mangoGpuDriver.length > 0
        ? _mangoGpuDriver : (_rigGpuDriver.length > 0 ? _rigGpuDriver : "--")
    readonly property string kernelVersion: _rigKernelVersion.length > 0 ? _rigKernelVersion : "--"
    readonly property string distroName: SystemInfo.distroName !== "Unknown"
        ? SystemInfo.distroName : (_rigDistroName.length > 0 ? _rigDistroName : "--")
    readonly property string displayResolution: {
        const screen = GlobalStates.primaryScreen ?? Quickshell.screens[0]
        return screen && screen.width > 0 && screen.height > 0
            ? `${screen.width}x${screen.height}` : "--"
    }
    readonly property string mangoHudLogDirectory:
        `${Directories.stateUserPath}/mangohud`

    readonly property real averageFps: {
        if (root.fpsHistory.length === 0) return -1
        let total = 0
        for (const value of root.fpsHistory) total += value
        return total / root.fpsHistory.length
    }
    readonly property real onePercentLow: {
        if (root.fpsHistory.length === 0) return -1
        const values = [...root.fpsHistory].sort((a, b) => a - b)
        const count = Math.max(1, Math.ceil(values.length * 0.01))
        let total = 0
        for (let i = 0; i < count; i++) total += values[i]
        return total / count
    }
    readonly property real minimumFps: root.fpsHistory.length > 0
        ? Math.min(...root.fpsHistory) : -1
    readonly property real maximumFps: root.fpsHistory.length > 0
        ? Math.max(...root.fpsHistory) : -1
    readonly property real averageFrametime: root.frametimeHistory.length > 0
        ? root.frametimeHistory.reduce((total, value) => total + value, 0)
            / root.frametimeHistory.length : -1
    readonly property real minimumFrametime: root.frametimeHistory.length > 0
        ? Math.min(...root.frametimeHistory) : -1
    readonly property real maximumFrametime: root.frametimeHistory.length > 0
        ? Math.max(...root.frametimeHistory) : -1
    readonly property real framePacingJitterMs: {
        if (root.frametimeHistory.length === 0) return -1
        const average = root.averageFrametime
        let squaredDelta = 0
        for (const value of root.frametimeHistory)
            squaredDelta += Math.pow(value - average, 2)
        return Math.sqrt(squaredDelta / root.frametimeHistory.length)
    }
    readonly property real framePacingPercent: root.averageFrametime > 0
        ? root.framePacingJitterMs / root.averageFrametime * 100 : -1
    readonly property real fpsGraphScale: {
        let highest = 60
        for (const value of root.fpsHistory) highest = Math.max(highest, value)
        return Math.max(60, Math.ceil(highest / 30) * 30)
    }
    readonly property real frametimeGraphScale: {
        let highest = 16
        for (const value of root.frametimeHistory) highest = Math.max(highest, value)
        return Math.max(16, Math.ceil(highest / 4) * 4)
    }
    readonly property var fpsGraphValues: {
        const scale = root.fpsGraphScale
        return root.fpsHistory.map(value => Math.max(0, Math.min(1, value / scale)))
    }
    readonly property var frametimeGraphValues: {
        const scale = root.frametimeGraphScale
        return root.frametimeHistory.map(value => Math.max(0, Math.min(1, value / scale)))
    }

    readonly property string telemetryState: {
        if (!root.gameDetected) return "no-game"
        if (root.telemetryAvailable) return "live"
        return root.mangoHudInstalled ? "logging-not-configured" : "mangohud-missing"
    }
    readonly property string monitorScript: FileUtils.trimFileProtocol(
        `${Directories.scriptPath}/game-performance-monitor.py`)

    function _validMetric(value: real): bool {
        return value >= 0 && isFinite(value)
    }

    function _preferSystemMetric(mango: real, system: real): real {
        return _validMetric(system) && (!_validMetric(mango) || mango <= 0 && system > 0)
            ? system : mango
    }

    function acquire(): void {
        root._consumers++
        if (root._consumers !== 1) return
        ResourceUsage.keepAlive()
        if (!rigInfoProcess.running) rigInfoProcess.running = true
        if (!root.mangoHudInstalled && !mangoHudProbe.running)
            mangoHudProbe.running = true
        root._refreshTarget()
    }

    function release(): void {
        if (root._consumers <= 0) return
        root._consumers--
        if (root._consumers !== 0) return
        ResourceUsage.releaseKeepAlive()
        if (telemetryProcess.running) telemetryProcess.running = false
        if (systemVramProcess.running) systemVramProcess.running = false
        root._resetTelemetry()
        root.gameDetected = false
        root.gameName = ""
        root.gameAppId = ""
        root.gamePid = 0
        root.gameResolution = ""
        root._gameTargetKey = ""
        root._cpuCoreLoads = []
        root._previousCoreStats = ({})
        root._lastGameWindow = null
    }

    function _focusedWindow(): var {
        if (CompositorService.isNiri) {
            const windows = NiriService.windows
            let focused = null
            if (Array.isArray(windows)) {
                focused = windows.find(window => window.is_focused) ?? null
            }
            const active = NiriService.activeWindow
            const toplevel = ToplevelManager.activeToplevel
            const likelyGame = [focused, active, toplevel]
                .find(window => window && root._isLikelyGame(window))
            if (likelyGame) return likelyGame
            return focused ?? active ?? toplevel
        }

        if (CompositorService.isHyprland) {
            const windows = HyprlandData.windowList
            if (Array.isArray(windows)) {
                const focused = windows.find(window =>
                    window.focusHistoryID === 0 || window.focused === true)
                if (focused) return focused
            }
        }

        return ToplevelManager.activeToplevel
    }

    function _isLikelyGame(window: var): bool {
        const appId = String(window?.app_id ?? window?.appId
            ?? window?.class ?? window?.initialClass ?? "").toLowerCase()
        const title = String(window?.title ?? window?.initialTitle ?? "").toLowerCase()
        const identity = `${appId} ${title}`
        return /(steam_app_|steam_proton|proton|wine|lutris|heroic|gamescope|godot|unity|unreal|minecraft|counter[- ]strike|overwatch|warframe|dirt|rally)/.test(identity)
    }

    function _windowAppId(window: var): string {
        return String(window?.app_id ?? window?.appId ?? window?.class
            ?? window?.initialClass ?? "").trim()
    }

    function _windowPid(window: var): int {
        return Number(window?.pid ?? 0)
    }

    function _windowTargetKey(window: var, appId: string, pid: int): string {
        const niriId = window?.id
        if (niriId !== undefined && niriId !== null)
            return `niri:${niriId}`

        const hyprlandAddress = String(window?.address ?? "").trim()
        if (hyprlandAddress.length > 0)
            return `hyprland:${hyprlandAddress}`

        const title = String(window?.title ?? window?.initialTitle ?? "")
        return `${pid}:${appId}:${title}`
    }

    function _windowResolution(window: var): string {
        const size = window?.layout?.window_size ?? window?.size
        if (Array.isArray(size) && size.length >= 2) {
            const width = Number(size[0])
            const height = Number(size[1])
            if (width > 0 && height > 0)
                return `${Math.round(width)}x${Math.round(height)}`
        }

        const width = Number(window?.width ?? 0)
        const height = Number(window?.height ?? 0)
        return width > 0 && height > 0
            ? `${Math.round(width)}x${Math.round(height)}` : ""
    }

    function _displayName(window: var, appId: string): string {
        const title = String(window?.title ?? "").trim()
        if (title.length > 0 && !/^steam_app_\d+$/i.test(title)) return title
        const desktopEntry = AppSearch.lookupDesktopEntry(appId)
        return String(desktopEntry?.name ?? appId ?? "").trim()
    }

    function _refreshTarget(): void {
        if (root._consumers === 0) return

        const focusedWindow = root._focusedWindow()
        const window = GlobalStates.overlayOpen && !focusedWindow && root._lastGameWindow
            ? root._lastGameWindow : focusedWindow
        const appId = root._windowAppId(window)
        const pid = root._windowPid(window)
        const detected = !!window && pid > 0 && root._isLikelyGame(window)

        if (!detected) {
            if (focusedWindow || !GlobalStates.overlayOpen) root._lastGameWindow = null
            root.gameDetected = false
            root.gameName = ""
            root.gameAppId = ""
            root.gamePid = 0
            root.gameResolution = ""
            root._gameTargetKey = ""
            root._resetTelemetry()
            if (telemetryProcess.running) telemetryProcess.running = false
            return
        }

        const targetKey = root._windowTargetKey(window, appId, pid)
        if (targetKey !== root._gameTargetKey) {
            root._gameTargetKey = targetKey
            root.gamePid = pid
            root._resetTelemetry()
            if (telemetryProcess.running) telemetryProcess.running = false
        }

        root.gameDetected = true
        root.gameAppId = appId
        root.gameName = root._displayName(window, appId)
        root.gameResolution = root._windowResolution(window)
        root._lastGameWindow = window

        if (!telemetryProcess.running) telemetryProcess.running = true
    }

    function _resetTelemetry(): void {
        root.telemetryAvailable = false
        root._mangoFps = -1
        root._mangoFrametime = -1
        root._mangoCpuLoad = -1
        root._mangoCpuPower = -1
        root._mangoCpuFrequencyMhz = -1
        root._mangoGpuLoad = -1
        root._mangoCpuTemp = -1
        root._mangoGpuTemp = -1
        root._mangoGpuCoreClockMhz = -1
        root._mangoGpuMemoryClockMhz = -1
        root._mangoVramUsedGb = -1
        root._mangoGpuPower = -1
        root._mangoGpuVoltage = -1
        root._mangoRamUsedGb = -1
        root._mangoSwapUsedGb = -1
        root._mangoProcessMemoryGb = -1
        root._mangoGraphicsApi = ""
        root._mangoWineProton = ""
        root._mangoFexStats = ""
        root._mangoHudVersion = ""
        root._mangoCpuName = ""
        root._mangoGpuName = ""
        root._mangoGpuDriver = ""
        root._lastSampleAgeMs = -1
        root._lastSampleId = ""
        root.fpsHistory = []
        root.frametimeHistory = []
    }

    function _markTelemetryUnavailable(): void {
        root.telemetryAvailable = false
        root._mangoFps = -1
        root._mangoFrametime = -1
        root._mangoCpuLoad = -1
        root._mangoCpuPower = -1
        root._mangoCpuFrequencyMhz = -1
        root._mangoGpuLoad = -1
        root._mangoCpuTemp = -1
        root._mangoGpuTemp = -1
        root._mangoGpuCoreClockMhz = -1
        root._mangoGpuMemoryClockMhz = -1
        root._mangoVramUsedGb = -1
        root._mangoGpuPower = -1
        root._mangoGpuVoltage = -1
        root._mangoRamUsedGb = -1
        root._mangoSwapUsedGb = -1
        root._mangoProcessMemoryGb = -1
        root._mangoGraphicsApi = ""
        root._mangoWineProton = ""
        root._mangoFexStats = ""
        root._mangoHudVersion = ""
        root._mangoCpuName = ""
        root._mangoGpuName = ""
        root._mangoGpuDriver = ""
        root._lastSampleAgeMs = -1
        root._lastSampleId = ""
    }

    function _payloadMetric(payload: var, key: string): real {
        const raw = payload?.[key]
        if (raw === null || raw === undefined || raw === "")
            return -1
        const value = Number(raw)
        return isFinite(value) ? value : -1
    }

    function _consumeRigInfo(output: string): void {
        const line = output.trim().split("\n").find(value => value.trim().length > 0) ?? ""
        if (line.length === 0) return

        const fields = line.split("\t").map(value => value.trim())
        root._rigCpuName = fields[0] ?? ""
        root._rigCpuCores = Number(fields[1] ?? 0)
        root._rigGpuName = fields[2] ?? ""
        root._rigGpuDriver = fields[3] ?? ""
        const vramMb = Number(fields[4] ?? -1)
        const ramKb = Number(fields[5] ?? -1)
        root._rigVramTotalGb = vramMb > 0 ? vramMb / 1024 : -1
        root._rigRamTotalGb = ramKb > 0 ? ramKb / (1024 * 1024) : -1
        root._rigKernelVersion = fields[6] ?? ""
        root._rigDistroName = fields[7] ?? ""
    }

    function _refreshSystemVram(): void {
        if (root._consumers > 0 && !systemVramProcess.running)
            systemVramProcess.running = true
    }

    function _resetSystemGpuMetrics(): void {
        root._systemVramUsedGb = -1
        root._systemVramTotalGb = -1
        root._systemGpuLoad = -1
        root._systemGpuTemp = -1
        root._systemGpuPower = -1
        root._systemGpuCoreClockMhz = -1
        root._systemGpuMemoryClockMhz = -1
    }

    function _consumeSystemVram(output: string): void {
        const line = output.trim().split("\n")
            .map(value => value.trim())
            .find(value => value.length > 0) ?? ""
        if (line.length === 0) {
            root._resetSystemGpuMetrics()
            return
        }

        const amdBytes = line.startsWith("amd:")
        const values = (amdBytes ? line.slice(4) : line)
            .split(",")
            .map(value => Number(value.trim()))
        if (values.length < 2 || !root._validMetric(values[0])
            || !root._validMetric(values[1])) {
            root._resetSystemGpuMetrics()
            return
        }

        const divisor = amdBytes ? 1024 * 1024 * 1024 : 1024
        root._systemVramUsedGb = values[0] / divisor
        root._systemVramTotalGb = values[1] / divisor
        if (amdBytes) {
            root._systemGpuLoad = -1
            root._systemGpuTemp = -1
            root._systemGpuPower = -1
            root._systemGpuCoreClockMhz = -1
            root._systemGpuMemoryClockMhz = -1
            return
        }

        root._systemGpuPower = values.length > 2 && root._validMetric(values[2])
            ? values[2] : -1
        root._systemGpuCoreClockMhz = values.length > 3 && root._validMetric(values[3])
            ? values[3] : -1
        root._systemGpuMemoryClockMhz = values.length > 4 && root._validMetric(values[4])
            ? values[4] : -1
        root._systemGpuLoad = values.length > 5 && root._validMetric(values[5])
            ? values[5] : -1
        root._systemGpuTemp = values.length > 6 && root._validMetric(values[6])
            ? values[6] : -1
    }

    function _pollCpuCoreLoads(): void {
        cpuStatFile.reload()
        cpuInfoFile.reload()
        const frequency = Number(cpuInfoFile.text().match(/^cpu MHz\s*:\s*([\d.]+)/m)?.[1] ?? -1)
        root._systemCpuFrequencyMhz = frequency > 0 ? frequency : -1
        const previous = root._previousCoreStats
        const nextStats = ({})
        const nextLoads = []

        for (const line of cpuStatFile.text().split("\n")) {
            const match = line.match(/^cpu(\d+)\s+(.+)$/)
            if (!match) continue
            const index = Number(match[1])
            const stats = match[2].trim().split(/\s+/).map(Number)
            if (stats.length < 5 || stats.some(value => !isFinite(value))) continue

            const total = stats.reduce((sum, value) => sum + value, 0)
            const idle = stats[3] + stats[4]
            const old = previous[index]
            let load = -1
            if (old) {
                const totalDelta = total - old.total
                const idleDelta = idle - old.idle
                if (totalDelta > 0)
                    load = Math.max(0, Math.min(100,
                        (totalDelta - idleDelta) / totalDelta * 100))
            }
            nextStats[index] = { total, idle }
            nextLoads.push({ index, load })
        }

        nextLoads.sort((a, b) => a.index - b.index)
        root._previousCoreStats = nextStats
        root._cpuCoreLoads = nextLoads.map(core => core.load)
    }

    function _appendTelemetrySample(fps: real, frametime: real, sampleId: string): void {
        if (!root._validMetric(fps) || !root._validMetric(frametime)
            || sampleId.length > 0 && sampleId === root._lastSampleId)
            return
        let nextFps = [...root.fpsHistory, fps]
        let nextFrametime = [...root.frametimeHistory, frametime]
        while (nextFps.length > root.historyLength) nextFps.shift()
        while (nextFrametime.length > root.historyLength) nextFrametime.shift()
        root.fpsHistory = nextFps
        root.frametimeHistory = nextFrametime
        if (sampleId.length > 0) root._lastSampleId = sampleId
    }

    function _consumeTelemetry(output: string): void {
        if (root._consumers === 0 || root.gamePid <= 0) return
        const lines = output.trim().split("\n").filter(line => line.trim().length > 0)
        if (lines.length === 0) {
            root._markTelemetryUnavailable()
            return
        }

        let payload
        try {
            payload = JSON.parse(lines[lines.length - 1])
        } catch (error) {
            root._markTelemetryUnavailable()
            return
        }

        if (Number(payload?.pid ?? 0) !== root.gamePid) {
            root._markTelemetryUnavailable()
            return
        }
        const fps = root._payloadMetric(payload, "fps")
        const frametime = root._payloadMetric(payload, "frametime")
        const age = root._payloadMetric(payload, "logAgeMs")
        const live = payload?.available === true && root._validMetric(fps)
            && root._validMetric(frametime) && age >= 0 && age <= 3000

        root.telemetryAvailable = live
        if (!live) {
            root._markTelemetryUnavailable()
            return
        }

        root._mangoFps = fps
        root._mangoFrametime = frametime
        root._lastSampleAgeMs = age
        root._mangoCpuLoad = root._payloadMetric(payload, "cpu_load")
        root._mangoCpuPower = root._payloadMetric(payload, "cpu_power")
        root._mangoCpuFrequencyMhz = root._payloadMetric(payload, "cpu_mhz")
        root._mangoGpuLoad = root._payloadMetric(payload, "gpu_load")
        root._mangoCpuTemp = root._payloadMetric(payload, "cpu_temp")
        root._mangoGpuTemp = root._payloadMetric(payload, "gpu_temp")
        root._mangoGpuCoreClockMhz = root._payloadMetric(payload, "gpu_core_clock")
        root._mangoGpuMemoryClockMhz = root._payloadMetric(payload, "gpu_mem_clock")
        root._mangoVramUsedGb = root._payloadMetric(payload, "gpu_vram_used")
        root._mangoGpuPower = root._payloadMetric(payload, "gpu_power")
        root._mangoGpuVoltage = root._payloadMetric(payload, "gpu_voltage")
        root._mangoRamUsedGb = root._payloadMetric(payload, "ram_used")
        root._mangoSwapUsedGb = root._payloadMetric(payload, "swap_used")
        root._mangoProcessMemoryGb = root._payloadMetric(payload, "process_rss")
        root._mangoGraphicsApi = String(payload?.graphicsApi ?? "").trim()
        root._mangoWineProton = String(payload?.wineProton ?? "").trim()
        root._mangoFexStats = String(payload?.fexStats ?? "").trim()
        root._mangoHudVersion = String(payload?.mangoHudVersion ?? "").trim()
        root._mangoCpuName = String(payload?.cpuName ?? "").trim()
        root._mangoGpuName = String(payload?.gpuName ?? "").trim()
        root._mangoGpuDriver = String(payload?.gpuDriver ?? "").trim()
        root._appendTelemetrySample(fps, frametime, String(payload?.sampleId ?? ""))
    }

    Timer {
        id: refreshTimer
        interval: 500
        running: root._consumers > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root._refreshTarget()
    }

    Timer {
        interval: 5000
        running: root._consumers > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root._refreshSystemVram()
    }

    Timer {
        interval: 500
        running: root._consumers > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root._pollCpuCoreLoads()
    }

    FileView {
        id: cpuStatFile
        path: "/proc/stat"
    }

    FileView {
        id: cpuInfoFile
        path: "/proc/cpuinfo"
    }

    Process {
        id: rigInfoProcess
        command: ["/usr/bin/bash", "-c", `
            cpu_model=$(awk -F: '/^model name/{gsub(/^[[:space:]]+/, "", $2); print $2; exit}' /proc/cpuinfo)
            cpu_cores=$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '0')
            ram_kb=$(awk '/^MemTotal:/{print $2; exit}' /proc/meminfo)
            kernel=$(uname -r)
            distro=$(awk -F= '/^PRETTY_NAME=/{gsub(/^"|"$/, "", $2); print $2; exit}' /etc/os-release)
            gpu_name=""
            gpu_driver=""
            gpu_vram_mb=""
            if command -v nvidia-smi >/dev/null 2>&1; then
                gpu_row=$(nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader,nounits 2>/dev/null | awk 'NR == 1 {print; exit}')
                IFS=',' read -r gpu_name gpu_driver gpu_vram_mb <<< "$gpu_row"
            fi
            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                "$cpu_model" "$cpu_cores" "$gpu_name" "$gpu_driver" "$gpu_vram_mb" \
                "$ram_kb" "$kernel" "$distro"
        `]
        running: false
        stdout: StdioCollector {
            id: rigInfoCollector
            onStreamFinished: root._consumeRigInfo(rigInfoCollector.text)
        }
    }

    Process {
        id: systemVramProcess
        command: ["/usr/bin/bash", "-c", `
            if command -v nvidia-smi >/dev/null 2>&1; then
                nvidia-smi --query-gpu=memory.used,memory.total,power.draw,clocks.gr,clocks.mem,utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n 1
                exit 0
            fi
            for device in /sys/class/drm/card*/device; do
                used="$device/mem_info_vram_used"
                total="$device/mem_info_vram_total"
                if [ -r "$used" ] && [ -r "$total" ]; then
                    printf "amd:%s,%s\\n" "$(cat "$used")" "$(cat "$total")"
                    exit 0
                fi
            done
        `]
        running: false
        stdout: StdioCollector {
            id: systemVramCollector
            onStreamFinished: root._consumeSystemVram(systemVramCollector.text)
        }
    }

    Process {
        id: mangoHudProbe
        command: ["/usr/bin/bash", "-c", "command -v mangohud >/dev/null 2>&1"]
        running: false
        onExited: (exitCode, exitStatus) => root.mangoHudInstalled = exitCode === 0
    }

    Timer {
        interval: 5000
        running: root._consumers > 0 && !root.mangoHudInstalled
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!mangoHudProbe.running) mangoHudProbe.running = true
    }

    Process {
        id: telemetryProcess
        command: [
            "/usr/bin/python3", root.monitorScript,
            "--pid", String(root.gamePid),
            "--log-dir", root.mangoHudLogDirectory,
            "--log-dir", Directories.homePath
        ]
        running: false
        stdout: StdioCollector {
            id: telemetryCollector
            onStreamFinished: root._consumeTelemetry(telemetryCollector.text)
        }
    }
}
