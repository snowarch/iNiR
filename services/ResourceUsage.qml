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

    // Auto-stop polling when nothing requested it recently.
    // This prevents the service from running forever after briefly opening a panel.
    readonly property int _autoStopDelayMs: Config.options?.resources?.autoStopDelay ?? 15000
    property real memoryTotal: 1
    property real memoryFree: 0
    property real memoryUsed: memoryTotal - memoryFree
    property real memoryUsedPercentage: memoryUsed / memoryTotal
    property real swapTotal: 1
    property real swapFree: 0
    property real swapUsed: swapTotal - swapFree
    property real swapUsedPercentage: swapTotal > 0 ? (swapUsed / swapTotal) : 0
    property real cpuUsage: 0
    property var previousCpuStats
    property real gpuUsage: 0

    // Temperature properties (in Celsius)
    property int cpuTemp: 0
    property int gpuTemp: 0
    property int maxTemp: Math.max(cpuTemp, gpuTemp)
    property real tempPercentage: Math.min(maxTemp / 100, 1.0)  // Normalized to 100°C max
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
    property list<real> memoryUsageHistory: []
    property list<real> swapUsageHistory: []

    function kbToGbString(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    function updateMemoryUsageHistory() {
        memoryUsageHistory = [...memoryUsageHistory, memoryUsedPercentage];
        if (memoryUsageHistory.length > historyLength) {
            memoryUsageHistory.shift();
        }
    }

    Process {
        id: detectGpuUsageSource
        // NVIDIA GPUs are detected first by vendor ID (0x10de) and prefer nvidia-smi,
        // because their sysfs gpu_busy_percent can exist but always return 0.
        // AMD/Intel use the native DRM sysfs counter. Fall back to nvidia-smi otherwise.
        command: ["/usr/bin/bash", "-c", `
            nvidia_path=""
            if command -v nvidia-smi >/dev/null 2>&1; then
                nvidia_path=$(command -v nvidia-smi)
            fi

            is_nvidia=""
            for vendor_file in /sys/class/drm/card*/device/vendor; do
                [ -f "$vendor_file" ] || continue
                vendor=$(cat "$vendor_file" 2>/dev/null)
                [ "$vendor" = "0x10de" ] && is_nvidia=1 && break
            done

            if [ -n "$is_nvidia" ] && [ -n "$nvidia_path" ]; then
                echo "nvidia-smi:$nvidia_path"
                exit 0
            fi

            for card in /sys/class/drm/card*; do
                path="$card/device/gpu_busy_percent"
                if [ -f "$path" ]; then
                    echo "sysfs:$path"
                    exit 0
                fi
            done

            if [ -n "$nvidia_path" ]; then
                echo "nvidia-smi:$nvidia_path"
                exit 0
            fi

            echo "none"
        `]
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("sysfs:")) {
                    root._gpuUsageSource = "sysfs";
                    root._gpuUsagePath = line.slice(6);
                } else if (line.startsWith("nvidia-smi:")) {
                    root._gpuUsageSource = "nvidia-smi";
                    root._nvidiaSmiPath = line.slice(11);
                } else if (line === "none") {
                    root._gpuUsageSource = "none";
                }
            }
        }
    }

    Process {
        id: nvidiaGpuProc
        // Query utilization and temperature together for efficiency.
        // temperature.gpu returns the hotspot/junction temp matching what btop shows.
        command: ["/usr/bin/bash", "-c", root._nvidiaSmiPath + " --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n 1"]
        running: false
        stdout: StdioCollector {
            id: nvidiaGpuCollector
            onStreamFinished: {
                const parts = nvidiaGpuCollector.text.trim().split(",").map(s => s.trim());
                const rawUsage = parseInt(parts[0]);
                const rawTemp = parseInt(parts[1]);
                root.gpuUsage = !isNaN(rawUsage) ? root.clampPercentToUnit(rawUsage / 100) : 0;
                if (!isNaN(rawTemp))
                    root.gpuTemp = rawTemp;
            }
        }
    }
    function updateSwapUsageHistory() {
        swapUsageHistory = [...swapUsageHistory, swapUsedPercentage];
        if (swapUsageHistory.length > historyLength) {
            swapUsageHistory.shift();
        }
    }
    function updateCpuUsageHistory() {
        cpuUsageHistory = [...cpuUsageHistory, cpuUsage];
        if (cpuUsageHistory.length > historyLength) {
            cpuUsageHistory.shift();
        }
    }
    function updateGpuUsageHistory() {
        gpuUsageHistory = [...gpuUsageHistory, gpuUsage];
        if (gpuUsageHistory.length > historyLength) {
            gpuUsageHistory.shift();
        }
    }
    function updateHistories() {
        updateMemoryUsageHistory();
        updateSwapUsageHistory();
        updateCpuUsageHistory();
        updateGpuUsageHistory();
    }

    function clampPercentToUnit(value: real): real {
        return Math.max(0, Math.min(1, value));
    }

    function ensureRunning(): void {
        root._runningRequested = true;
        if (!root._initRequested) {
            root._initRequested = true;
            detectTempSensors.running = true;
            detectGpuUsageSource.running = true;
            detectHybridGpu.running = true;
            findCpuMaxFreqProc.running = true;
        }
        autoStopTimer.restart();
        pollTimer.restart();
    }

    function stop(): void {
        root._runningRequested = false;
        pollTimer.stop();
        autoStopTimer.stop();
    }

    Timer {
        id: autoStopTimer
        interval: root._autoStopDelayMs
        repeat: false
        onTriggered: {
            root.stop();
        }
    }

    Timer {
        id: pollTimer
        interval: Config.options?.resources?.updateInterval ?? 3000
        running: root._runningRequested
        repeat: true
        onTriggered: {
            autoStopTimer.restart();

            // Determine whether GPU polling should be skipped this cycle.
            // On hybrid (iGPU+dGPU) systems, querying GPU data via nvidia-smi or hwmon
            // prevents the discrete GPU from entering runtime suspend, wasting ~9-10W at idle.
            // Reading runtime_status is a pure kernel sysfs read — it does NOT wake the hardware.
            const gpuMonitorEnabled = Config.options?.resources?.monitorGpu ?? true;
            let skipGpu = !gpuMonitorEnabled;
            if (!skipGpu && root._dGpuRuntimeStatusPath !== "") {
                fileDGpuRuntimeStatus.reload();
                skipGpu = fileDGpuRuntimeStatus.text().trim() === "suspended";
            }

            // Reload files
            fileMeminfo.reload();
            fileStat.reload();
            fileCpuTemp.reload();
            if (!skipGpu) {
                if (root._gpuUsageSource !== "nvidia-smi")
                    fileGpuTemp.reload();
                if (root._gpuUsageSource === "sysfs")
                    fileGpuUsage.reload();
            }

            // Parse memory and swap usage
            const textMeminfo = fileMeminfo.text();
            memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 1);
            memoryFree = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0);
            swapTotal = Number(textMeminfo.match(/SwapTotal: *(\d+)/)?.[1] ?? 1);
            swapFree = Number(textMeminfo.match(/SwapFree: *(\d+)/)?.[1] ?? 0);

            // Parse CPU usage
            const textStat = fileStat.text();
            const cpuLine = textStat.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/);
            if (cpuLine) {
                const stats = cpuLine.slice(1).map(Number);
                const total = stats.reduce((a, b) => a + b, 0);
                // idle (stats[3]) + iowait (stats[4]) = not working
                const idle = stats[3] + stats[4];

                if (previousCpuStats) {
                    const totalDiff = total - previousCpuStats.total;
                    const idleDiff = idle - previousCpuStats.idle;
                    cpuUsage = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0;
                }

                previousCpuStats = {
                    total,
                    idle
                };
            }

            // Parse temperatures (millidegrees to degrees)
            const cpuTempRaw = parseInt(fileCpuTemp.text()) || 0;
            cpuTemp = Math.round(cpuTempRaw / 1000);
            // GPU temp: skip when suspended/disabled to avoid hwmon reads waking a suspended dGPU
            if (!skipGpu && root._gpuUsageSource !== "nvidia-smi") {
                const gpuTempRaw = parseInt(fileGpuTemp.text()) || 0;
                gpuTemp = Math.round(gpuTempRaw / 1000);
            }

            // Parse GPU usage — skip entirely when dGPU is suspended or monitoring is disabled
            if (skipGpu) {
                gpuUsage = 0;
            } else if (root._gpuUsageSource === "sysfs") {
                const gpuBusyPercent = parseInt(fileGpuUsage.text());
                if (isNaN(gpuBusyPercent)) {
                    gpuUsage = 0;
                } else {
                    gpuUsage = root.clampPercentToUnit(gpuBusyPercent / 100);
                }
            } else if (root._gpuUsageSource === "nvidia-smi" && !nvidiaGpuProc.running) {
                nvidiaGpuProc.running = true;
            } else if (root._gpuUsageSource === "none") {
                gpuUsage = 0;
            }

            root.updateHistories();

            // Update disk usage
            diskProc.running = true;
        }
    }

    FileView {
        id: fileMeminfo
        path: "/proc/meminfo"
    }
    FileView {
        id: fileStat
        path: "/proc/stat"
    }
    // Temperature sensors - k10temp for AMD CPU, amdgpu for AMD GPU
    // These paths are auto-detected at startup
    FileView {
        id: fileCpuTemp
        path: root._cpuTempPath
    }
    FileView {
        id: fileGpuTemp
        path: root._gpuTempPath
    }
    FileView {
        id: fileGpuUsage
        path: root._gpuUsagePath
    }
    // Hybrid GPU: runtime PM status of the discrete GPU (kernel-only read, never wakes hardware)
    FileView {
        id: fileDGpuRuntimeStatus
        path: root._dGpuRuntimeStatusPath
    }

    // Auto-detect temperature sensor paths
    property string _cpuTempPath: ""
    property string _gpuTempPath: ""
    property string _gpuUsagePath: ""
    property string _gpuUsageSource: "none"
    property string _nvidiaSmiPath: ""
    // Hybrid GPU: path to dGPU power/runtime_status (empty = not hybrid or detection pending)
    property string _dGpuRuntimeStatusPath: ""

    Component.onCompleted: {
        // Lazy: only start monitoring when a panel/widget requests it.
    }

    Process {
        id: detectTempSensors
        // Detect CPU and GPU temperature sensors
        // Extended support for older hardware, laptops, and various platforms
        command: ["/usr/bin/bash", "-c", `
            cpu_found=""
            gpu_found=""

            for hwmon in /sys/class/hwmon/hwmon*; do
                name=$(cat $hwmon/name 2>/dev/null)

                # Find best temp input (prefer temp1, but check others)
                temp_input=""
                for t in $hwmon/temp*_input; do
                    [ -f "$t" ] && temp_input="$t" && break
                done
                [ -z "$temp_input" ] && continue

                # CPU sensors - extended list for various hardware
                case "$name" in
                    coretemp|k10temp|zenpower|cpu_thermal|fam15h_power|acpitz|thinkpad|dell_smm|hp_wmi|asus_ec|it87|nct6775|w83627ehf|lm75|lm78|lm85|via_cputemp|pch_*)
                        [ -z "$cpu_found" ] && echo "cpu:$temp_input" && cpu_found=1
                        ;;
                esac

                # GPU sensors
                case "$name" in
                    amdgpu|radeon|nvidia|nouveau|i915|xe|panfrost|lima|v3d|vc4)
                        [ -z "$gpu_found" ] && echo "gpu:$temp_input" && gpu_found=1
                        ;;
                esac
            done

            # Fallback to thermal_zone if hwmon didn't find sensors
            for tz in /sys/class/thermal/thermal_zone*; do
                [ -f "$tz/temp" ] || continue
                type=$(cat $tz/type 2>/dev/null | tr '[:upper:]' '[:lower:]')

                case "$type" in
                    *cpu*|x86_pkg_temp|acpitz|*soc*|*core*|*package*|*processor*|int3400*|pch*|b0d4*)
                        [ -z "$cpu_found" ] && echo "cpu:$tz/temp" && cpu_found=1
                        ;;
                    *gpu*|*radeon*|*amdgpu*|*nvidia*)
                        [ -z "$gpu_found" ] && echo "gpu:$tz/temp" && gpu_found=1
                        ;;
                esac
            done
        `]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(":");
                if (parts.length === 2) {
                    const [type, path] = parts;
                    if (type === "cpu" && !root._cpuTempPath)
                        root._cpuTempPath = path;
                    else if (type === "gpu" && !root._gpuTempPath)
                        root._gpuTempPath = path;
                }
            }
        }
    }

    Process {
        id: detectHybridGpu
        // Detect iGPU+dGPU hybrid setups by reading DRM boot_vga flags.
        // boot_vga=1 → primary display GPU (iGPU on laptops), boot_vga=0 → secondary (dGPU).
        // On hybrid systems, outputs the dGPU's runtime_status path so the poll loop can
        // check suspend state before issuing any GPU query, preventing unwanted dGPU wake-ups.
        // On non-hybrid desktops (single GPU or no boot_vga support) outputs "none".
        command: ["/usr/bin/bash", "-c", `
            igpu_found=""
            dgpu_runtime=""

            for card in /sys/class/drm/card*/; do
                name=$(basename "$card")
                echo "$name" | grep -qE '^card[0-9]+$' || continue
                bvga_file="\${card}device/boot_vga"
                [ -f "$bvga_file" ] || continue
                bvga=$(cat "$bvga_file" 2>/dev/null)
                if [ "$bvga" = "1" ]; then
                    igpu_found=1
                elif [ "$bvga" = "0" ]; then
                    runtime="\${card}device/power/runtime_status"
                    [ -f "$runtime" ] && dgpu_runtime="$runtime"
                fi
            done

            if [ -n "$igpu_found" ] && [ -n "$dgpu_runtime" ]; then
                echo "dgpu:$dgpu_runtime"
            else
                echo "none"
            fi
        `]
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("dgpu:"))
                    root._dGpuRuntimeStatusPath = line.slice(5);
            }
        }
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
