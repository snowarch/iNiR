pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Simple polled resource usage service with RAM, Swap, CPU usage, and temperatures.
 */
Singleton {
    id: root

    property bool _runningRequested: false
    property bool _initRequested: false
    property int _persistentConsumers: 0

    // Auto-stop polling when nothing requested it recently.
    // This prevents the service from running forever after briefly opening a panel.
    // Persistent consumers (bar, vertical bar) prevent auto-stop entirely.
    readonly property int _autoStopDelayMs: Config.options?.resources?.autoStopDelay ?? 15000
    readonly property int _diskUpdateIntervalMs: 30000
    // 0 + zero-guard avoids fake "100%" before first poll.
    property real memoryTotal: 0
    property real memoryFree: 0
    property real memoryUsed: memoryTotal - memoryFree
    property real memoryUsedPercentage: memoryTotal > 0 ? (memoryUsed / memoryTotal) : 0
    property real swapTotal: 0
    property real swapFree: 0
    property real swapUsed: swapTotal - swapFree
    property real swapUsedPercentage: swapTotal > 0 ? (swapUsed / swapTotal) : 0
    property real cpuUsage: 0
    property var previousCpuStats
    property var previousCpuCoreStats: ({})
    property list<real> cpuCoreUsage: []
    property real cpuFrequencyMhz: -1
    property real gpuUsage: 0
    property real gpuMemoryUsedGb: -1
    property real gpuMemoryTotalGb: -1
    property real gpuPower: -1
    property real gpuCoreClockMhz: -1
    property real gpuMemoryClockMhz: -1

    // Temperature properties (in Celsius)
    property int cpuTemp: 0
    property int gpuTemp: 0
    property int maxTemp: Math.max(cpuTemp, gpuTemp)
    property real tempPercentage: Math.min(maxTemp / 100, 1.0)  // Normalized to 100°C max
    property real gpuTempPercentage: Math.min(gpuTemp / 100, 1.0)  // Normalized to 100°C max
    property int tempWarningThreshold: 80  // Warning at 80°C

    // Disk usage (root partition)
    property real diskTotal: 1
    property real diskUsed: 0
    property real diskUsedPercentage: diskTotal > 0 ? diskUsed / diskTotal : 0

    property string maxAvailableMemoryString: kbToGbString(ResourceUsage.memoryTotal)
    property string maxAvailableSwapString: kbToGbString(ResourceUsage.swapTotal)
    property string maxAvailableCpuString: "--"
    property string maxAvailableGpuString: "100%"

    readonly property int historyLength: Config.options?.resources?.historyLength ?? 60
    property list<real> cpuUsageHistory: []
    property list<real> gpuUsageHistory: []
    property list<real> gpuTempHistory: []
    property list<real> cpuTempHistory: []
    property list<real> memoryUsageHistory: []
    property list<real> swapUsageHistory: []

    function kbToGbString(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    function updateMemoryUsageHistory() {
        const next = [...memoryUsageHistory, memoryUsedPercentage];
        if (next.length > historyLength) next.shift();
        memoryUsageHistory = next;
    }

    Process {
        id: detectGpuUsageSource
        // Select the backend only for the device chosen by detect_sensors.py.
        command: ["/usr/bin/bash", "-c", `
            if [ "$1" = "0x10de" ] && command -v nvidia-smi >/dev/null 2>&1; then
                echo "nvidia-smi:$(command -v nvidia-smi)"
            elif [ -f "$2/gpu_busy_percent" ]; then
                echo "sysfs:$2/gpu_busy_percent"
            elif [ "$1" = "0x8086" ] && command -v intel_gpu_top >/dev/null 2>&1; then
                echo "intel:$(command -v intel_gpu_top)"
            else
                echo "none"
            fi
        `, "inir-gpu", root._gpuVendor, root._gpuDevice]
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("sysfs:")) {
                    root._gpuUsageSource = "sysfs";
                    root._gpuUsagePath = line.slice(6);
                } else if (line.startsWith("nvidia-smi:")) {
                    root._gpuUsageSource = "nvidia-smi";
                    root._nvidiaSmiPath = line.slice(11);
                } else if (line.startsWith("intel:")) {
                    root._gpuUsageSource = "intel";
                    root._intelGpuTopPath = line.slice(6);
                } else if (line === "none") {
                    root._gpuUsageSource = "none";
                }
            }
        }
        onExited: { root._gpuBackendReady = true; if (root._runningRequested) root._pollSensors(); }
    }

    Process {
        id: nvidiaGpuProc
        // Query shared GPU metrics together so consumers do not spawn their own nvidia-smi.
        // NVIDIA reports core GPU temperature, not AMD-style junction/hotspot.
        command: ["timeout", "2", root._nvidiaSmiPath, "--id=" + root._gpuDevice.split("/").pop(), "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw,clocks.gr,clocks.mem", "--format=csv,noheader,nounits"]
        running: false
        stdout: StdioCollector {
            id: nvidiaGpuCollector
            onStreamFinished: {
                if (!root._gpuPollingAllowed) return;
                const parts = nvidiaGpuCollector.text.trim().split(",").map(s => s.trim());
                const rawUsage = parseInt(parts[0]);
                const rawTemp = parseInt(parts[1]);
                const memoryUsedMb = parseFloat(parts[2]);
                const memoryTotalMb = parseFloat(parts[3]);
                const power = parseFloat(parts[4]);
                const coreClock = parseFloat(parts[5]);
                const memoryClock = parseFloat(parts[6]);
                root.gpuUsage = !isNaN(rawUsage) ? root.clampPercentToUnit(rawUsage / 100) : 0;
                root.gpuUsageAvailable = !isNaN(rawUsage);
                root.gpuTemp = root.validTemperature(rawTemp);
                root.gpuMemoryUsedGb = !isNaN(memoryUsedMb) ? memoryUsedMb / 1024 : -1;
                root.gpuMemoryTotalGb = !isNaN(memoryTotalMb) ? memoryTotalMb / 1024 : -1;
                root.gpuPower = !isNaN(power) ? power : -1;
                root.gpuCoreClockMhz = !isNaN(coreClock) ? coreClock : -1;
                root.gpuMemoryClockMhz = !isNaN(memoryClock) ? memoryClock : -1;
            }
        }
    }

    Process {
        id: intelGpuProc
        // One short PMU sample (~one 500ms period, killed by timeout). intel_gpu_top -J emits
        // per-engine "busy" percentages; aggregate GPU usage = the busiest engine this window.
        command: ["timeout", "1", root._intelGpuTopPath, "-d", "drm:" + root._gpuCard.replace("/sys/class/drm/", "/dev/dri/"), "-J", "-s", "500"]
        running: false
        stdout: StdioCollector {
            id: intelGpuCollector
            onStreamFinished: {
                if (!root._gpuPollingAllowed) return;
                const re = /"busy"\s*:\s*([\d.]+)/g;
                let m, maxBusy = -1;
                while ((m = re.exec(intelGpuCollector.text)) !== null) {
                    const v = parseFloat(m[1]);
                    if (!isNaN(v) && v > maxBusy)
                        maxBusy = v;
                }
                // An inaccessible PMU is unavailable, not an idle GPU. Avoid repeated failing probes.
                if (maxBusy < 0) root._gpuUsageSource = "none";
                root.gpuUsageAvailable = maxBusy >= 0;
                root.gpuUsage = maxBusy < 0 ? 0 : root.clampPercentToUnit(maxBusy / 100);
            }
        }
    }
    function updateSwapUsageHistory() {
        const next = [...swapUsageHistory, swapUsedPercentage];
        if (next.length > historyLength) next.shift();
        swapUsageHistory = next;
    }
    function updateCpuUsageHistory() {
        const next = [...cpuUsageHistory, cpuUsage];
        if (next.length > historyLength) next.shift();
        cpuUsageHistory = next;
    }
    function updateGpuUsageHistory() {
        const next = [...gpuUsageHistory, gpuUsage];
        if (next.length > historyLength) next.shift();
        gpuUsageHistory = next;
    }
    function updateGpuTempHistory() {
        const next = [...gpuTempHistory, gpuTempPercentage];
        if (next.length > historyLength) next.shift();
        gpuTempHistory = next;
    }
    function updateCpuTempHistory() {
        const next = [...cpuTempHistory, Math.max(0, Math.min(1, cpuTemp / 100))];
        if (next.length > historyLength) next.shift();
        cpuTempHistory = next;
    }
    function updateHistories() {
        updateMemoryUsageHistory();
        updateSwapUsageHistory();
        updateCpuUsageHistory();
        updateGpuUsageHistory();
        updateGpuTempHistory();
        updateCpuTempHistory();
    }

    function clampPercentToUnit(value: real): real {
        return Math.max(0, Math.min(1, value));
    }

    function ensureRunning(): void {
        root._runningRequested = true;
        if (!root._initRequested) {
            root._initRequested = true;
            detectTempSensors.running = true;
            findCpuMaxFreqProc.running = true;
        }
        if (root._persistentConsumers === 0)
            autoStopTimer.restart();
        pollTimer.restart();
        // Prime values now instead of waiting one updateInterval — but only once.
        // Multiple consumers calling ensureRunning() in their Component.onCompleted
        // would race their reload() ops and drop in-flight reads (FileView warnings).
        if (!root._primed) {
            root._primed = true;
            root._pollSensors();
            root._pollDisk();
        }
    }

    property bool _primed: false

    // Register a persistent consumer (always-visible panel like bar).
    // While any persistent consumer is registered, auto-stop is disabled.
    function keepAlive(): void {
        root._persistentConsumers++;
        autoStopTimer.stop();
        ensureRunning();
    }

    function releaseKeepAlive(): void {
        root._persistentConsumers = Math.max(0, root._persistentConsumers - 1);
        if (root._persistentConsumers === 0 && root._runningRequested)
            autoStopTimer.restart();
    }

    function stop(): void {
        root._runningRequested = false;
        root._primed = false;
        root.previousCpuStats = undefined;
        root.cpuUsage = 0;
        root.previousCpuCoreStats = ({});
        root.cpuCoreUsage = [];
        root.cpuFrequencyMhz = -1;
        root._gpuPollingAllowed = false;
        pollTimer.stop();
        diskPollTimer.stop();
        autoStopTimer.stop();
    }

    Timer {
        id: autoStopTimer
        interval: root._autoStopDelayMs
        repeat: false
        onTriggered: {
            if (root._persistentConsumers === 0)
                root.stop();
        }
    }

    function _pollSensors(): void {
        fileMeminfo.reload();
        fileStat.reload();
        fileCpuInfo.reload();
        fileCpuInfo.text();
        if (root._cpuTempPath !== "") { fileCpuTemp.reload(); fileCpuTemp.text(); }
        if (!(Config.options?.resources?.monitorGpu ?? true)) {
            root._clearGpu();
        } else if (root._dGpuRuntimeStatusPath !== "") {
            fileDGpuRuntimeStatus.reload();
            fileDGpuRuntimeStatus.text();
        } else {
            root._pollGpu();
        }
    }

    function _readMemory(textMeminfo: string): void {
        // Empty text() on first call collapses to 0% via the percentage guards.
        memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 0);
        memoryFree = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0);
        swapTotal = Number(textMeminfo.match(/SwapTotal: *(\d+)/)?.[1] ?? 0);
        swapFree = Number(textMeminfo.match(/SwapFree: *(\d+)/)?.[1] ?? 0);

    }

    function _readCpu(textStat: string): void {
        // /proc/stat includes steal; guest times are already included in user/nice.
        const cpuLine = textStat.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)(?:\s+(\d+))?/);
        if (cpuLine) {
            const stats = cpuLine.slice(1).map(v => Number(v ?? 0));
            const total = stats.reduce((a, b) => a + b, 0);
            // idle (stats[3]) + iowait (stats[4]) = not working
            const idle = stats[3] + stats[4];

            if (previousCpuStats) {
                const totalDiff = total - previousCpuStats.total;
                const idleDiff = idle - previousCpuStats.idle;
                cpuUsage = totalDiff > 0 && idleDiff >= 0 ? root.clampPercentToUnit(1 - idleDiff / totalDiff) : 0;
            }

            previousCpuStats = {
                total,
                idle
            };
        }

        const previousCoreStats = root.previousCpuCoreStats;
        const nextCoreStats = ({});
        const nextCoreUsage = [];
        for (const line of textStat.split("\n")) {
            const match = line.match(/^cpu(\d+)\s+(.+)$/);
            if (!match)
                continue;
            const index = Number(match[1]);
            const stats = match[2].trim().split(/\s+/).map(Number);
            if (stats.length < 5 || stats.some(value => !isFinite(value)))
                continue;
            const total = stats.reduce((sum, value) => sum + value, 0);
            const idle = stats[3] + stats[4];
            const old = previousCoreStats[index];
            let usage = -1;
            if (old) {
                const totalDiff = total - old.total;
                const idleDiff = idle - old.idle;
                if (totalDiff > 0)
                    usage = root.clampPercentToUnit((totalDiff - idleDiff) / totalDiff);
            }
            nextCoreStats[index] = { total, idle };
            nextCoreUsage.push({ index, usage });
        }
        nextCoreUsage.sort((a, b) => a.index - b.index);
        root.previousCpuCoreStats = nextCoreStats;
        root.cpuCoreUsage = nextCoreUsage.map(core => core.usage);
    }

    function validTemperature(value: real): int {
        return isFinite(value) && value > 0 && value < 150 ? Math.round(value) : 0;
    }

    function _clearGpu(): void {
        root._gpuPollingAllowed = false;
        root.gpuUsage = 0;
        root.gpuUsageAvailable = false;
        root.gpuTemp = 0;
        root.gpuMemoryUsedGb = -1;
        root.gpuMemoryTotalGb = -1;
        root.gpuPower = -1;
        root.gpuCoreClockMhz = -1;
        root.gpuMemoryClockMhz = -1;
    }

    function _pollGpu(): void {
        if (!root._runningRequested || !(Config.options?.resources?.monitorGpu ?? true)) {
            root._clearGpu();
            return;
        }
        if (!root._gpuBackendReady) return;
        root._gpuPollingAllowed = true;
        // With preload disabled, text() starts the asynchronous read; onLoaded consumes it.
        if (root._gpuUsageSource !== "nvidia-smi" && root._gpuTempPath !== "") {
            fileGpuTemp.reload();
            fileGpuTemp.text();
        }
        if (root._gpuUsageSource === "sysfs") {
            fileGpuUsage.reload();
            fileGpuUsage.text();
            fileGpuVramUsed.reload();
            fileGpuVramUsed.text();
            fileGpuVramTotal.reload();
            fileGpuVramTotal.text();
        }
        else if (root._gpuUsageSource === "nvidia-smi" && !nvidiaGpuProc.running)
            nvidiaGpuProc.running = true;
        else if (root._gpuUsageSource === "intel" && !intelGpuProc.running)
            intelGpuProc.running = true;
    }

    function _pollDisk(): void {
        if (!diskProc.running)
            diskProc.running = true;
    }

    Timer {
        id: pollTimer
        interval: Config.options?.resources?.updateInterval ?? 3000
        running: root._runningRequested
        repeat: true
        onTriggered: {
            root.updateHistories();
            root._pollSensors();
        }
    }

    Timer {
        id: diskPollTimer
        interval: root._diskUpdateIntervalMs
        running: root._runningRequested
        repeat: true
        onTriggered: root._pollDisk()
    }

    FileView {
        id: fileMeminfo
        path: "/proc/meminfo"
        onLoaded: root._readMemory(text())
    }
    FileView {
        id: fileStat
        path: "/proc/stat"
        onLoaded: root._readCpu(text())
    }
    FileView {
        id: fileCpuInfo
        path: "/proc/cpuinfo"
        preload: false
        onLoaded: {
            const frequency = Number(text().match(/^cpu MHz\s*:\s*([\d.]+)/m)?.[1] ?? -1);
            root.cpuFrequencyMhz = frequency > 0 ? frequency : -1;
        }
        onLoadFailed: root.cpuFrequencyMhz = -1
    }
    // Temperature sensors - k10temp for AMD CPU, amdgpu for AMD GPU
    // These paths are auto-detected at startup
    FileView {
        id: fileCpuTemp
        path: root._cpuTempPath
        preload: false
        onLoaded: root.cpuTemp = root.validTemperature(Number(text()) / 1000)
        onLoadFailed: root.cpuTemp = 0
    }
    FileView {
        id: fileGpuTemp
        path: root._gpuTempPath
        preload: false
        onLoaded: { if (root._gpuPollingAllowed) root.gpuTemp = root.validTemperature(Number(text()) / 1000); }
        onLoadFailed: root.gpuTemp = 0
    }
    FileView {
        id: fileGpuUsage
        path: root._gpuUsagePath
        preload: false
        onLoaded: {
            if (!root._gpuPollingAllowed) return;
            const value = parseInt(text());
            root.gpuUsageAvailable = !isNaN(value);
            root.gpuUsage = isNaN(value) ? 0 : root.clampPercentToUnit(value / 100);
        }
        onLoadFailed: { root.gpuUsage = 0; root.gpuUsageAvailable = false; }
    }
    FileView {
        id: fileGpuVramUsed
        path: root._gpuDevice.length > 0 ? `${root._gpuDevice}/mem_info_vram_used` : ""
        preload: false
        onLoaded: {
            if (!root._gpuPollingAllowed) return;
            const bytes = text().trim().length > 0 ? Number(text()) : NaN;
            root.gpuMemoryUsedGb = isFinite(bytes) && bytes >= 0 ? bytes / (1024 * 1024 * 1024) : -1;
        }
        onLoadFailed: root.gpuMemoryUsedGb = -1
    }
    FileView {
        id: fileGpuVramTotal
        path: root._gpuDevice.length > 0 ? `${root._gpuDevice}/mem_info_vram_total` : ""
        preload: false
        onLoaded: {
            if (!root._gpuPollingAllowed) return;
            const bytes = text().trim().length > 0 ? Number(text()) : NaN;
            root.gpuMemoryTotalGb = isFinite(bytes) && bytes > 0 ? bytes / (1024 * 1024 * 1024) : -1;
        }
        onLoadFailed: root.gpuMemoryTotalGb = -1
    }
    // Runtime PM status of the selected GPU; reading it does not wake the device.
    FileView {
        id: fileDGpuRuntimeStatus
        path: root._dGpuRuntimeStatusPath
        preload: false
        onLoaded: {
            const state = text().trim();
            if (state === "active" || state === "unsupported") root._pollGpu();
            else root._clearGpu();
        }
        onLoadFailed: root._clearGpu()
    }

    // Auto-detect temperature sensor paths
    property string _cpuTempPath: ""
    property string _gpuTempPath: ""
    readonly property string gpuDevicePath: _gpuDevice
    readonly property bool gpuPollingAllowed: _gpuPollingAllowed
    property bool gpuUsageAvailable: false
    property string cpuSensorLabel: ""
    property string gpuSensorLabel: ""
    property string _gpuDevice: ""
    property string _gpuVendor: ""
    property string _gpuCard: ""
    property bool _gpuBackendReady: false
    property bool _gpuPollingAllowed: false
    property string _gpuUsagePath: ""
    property string _gpuUsageSource: "none"
    property string _nvidiaSmiPath: ""
    property string _intelGpuTopPath: ""
    // Selected GPU power/runtime_status, when exported by the driver.
    property string _dGpuRuntimeStatusPath: ""

    Component.onCompleted: {
        // Lazy: only start monitoring when a panel/widget requests it.
    }

    Process {
        id: detectTempSensors
        command: ["python3", Quickshell.shellPath("scripts/detect_sensors.py")]
        stdout: SplitParser {
            onRead: line => {
                const split = line.indexOf(":");
                if (split < 0) return;
                const key = line.slice(0, split), value = line.slice(split + 1);
                if (key === "cpu") root._cpuTempPath = value;
                else if (key === "gpu") root._gpuTempPath = value;
                else if (key === "gpuDevice") root._gpuDevice = value;
                else if (key === "gpuVendor") root._gpuVendor = value;
                else if (key === "gpuCard") root._gpuCard = value;
                else if (key === "gpuRuntime") root._dGpuRuntimeStatusPath = value;
                else if (key === "cpuLabel") root.cpuSensorLabel = value;
                else if (key === "gpuLabel") root.gpuSensorLabel = value;
            }
        }
        onExited: { detectGpuUsageSource.running = true; }
    }

    Process {
        id: findCpuMaxFreqProc
        environment: ({
                LANG: "C",
                LC_ALL: "C"
            })
        command: ["/usr/bin/bash", "-c", "/usr/bin/lscpu | /usr/bin/grep 'CPU max MHz' | /usr/bin/awk '{print $4}'"]
        running: false
        stdout: StdioCollector {
            id: outputCollector
            onStreamFinished: {
                const mhz = parseFloat(outputCollector.text);
                if (isNaN(mhz) || mhz <= 0) {
                    root.maxAvailableCpuString = "--";
                } else {
                    root.maxAvailableCpuString = (mhz / 1000).toFixed(0) + " GHz";
                }
            }
        }
    }

    Process {
        id: diskProc
        command: ["/usr/bin/df", "-B1", "/"]
        running: false
        stdout: StdioCollector {
            id: diskCollector
            onStreamFinished: {
                const lines = diskCollector.text.trim().split("\n");
                if (lines.length >= 2) {
                    const parts = lines[1].split(/\s+/);
                    if (parts.length >= 4) {
                        root.diskTotal = parseInt(parts[1]) || 1;
                        root.diskUsed = parseInt(parts[2]) || 0;
                    }
                }
            }
        }
    }
}
