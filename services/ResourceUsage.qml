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

    // Temperature properties (in Celsius)
    property int cpuTemp: 0
    property int gpuTemp: 0
    property int maxTemp: Math.max(cpuTemp, gpuTemp)
    property real tempPercentage: Math.min(maxTemp / 100, 1.0)  // Normalized to 100°C max
    property int tempWarningThreshold: 80  // Warning at 80°C

    property string maxAvailableMemoryString: kbToGbString(ResourceUsage.memoryTotal)
    property string maxAvailableSwapString: kbToGbString(ResourceUsage.swapTotal)
    property string maxAvailableCpuString: "--"

    readonly property int historyLength: Config?.options.resources.historyLength ?? 60
    property list<real> cpuUsageHistory: []
    property list<real> memoryUsageHistory: []
    property list<real> swapUsageHistory: []

    function kbToGbString(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    function updateMemoryUsageHistory() {
        memoryUsageHistory = [...memoryUsageHistory, memoryUsedPercentage]
        if (memoryUsageHistory.length > historyLength) {
            memoryUsageHistory.shift()
        }
    }
    function updateSwapUsageHistory() {
        swapUsageHistory = [...swapUsageHistory, swapUsedPercentage]
        if (swapUsageHistory.length > historyLength) {
            swapUsageHistory.shift()
        }
    }
    function updateCpuUsageHistory() {
        cpuUsageHistory = [...cpuUsageHistory, cpuUsage]
        if (cpuUsageHistory.length > historyLength) {
            cpuUsageHistory.shift()
        }
    }
    function updateHistories() {
        updateMemoryUsageHistory()
        updateSwapUsageHistory()
        updateCpuUsageHistory()
    }


	Timer {
		interval: Config.options?.resources?.updateInterval ?? 3000
	    running: true 
	    repeat: true
		onTriggered: {
	        // Reload files
	        fileMeminfo.reload()
	        fileStat.reload()
	        fileCpuTemp.reload()
	        fileGpuTemp.reload()

	        // Parse memory and swap usage
	        const textMeminfo = fileMeminfo.text()
	        memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 1)
	        memoryFree = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0)
	        swapTotal = Number(textMeminfo.match(/SwapTotal: *(\d+)/)?.[1] ?? 1)
	        swapFree = Number(textMeminfo.match(/SwapFree: *(\d+)/)?.[1] ?? 0)

	        // Parse CPU usage
	        const textStat = fileStat.text()
	        const cpuLine = textStat.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
	        if (cpuLine) {
	            const stats = cpuLine.slice(1).map(Number)
	            const total = stats.reduce((a, b) => a + b, 0)
	            // idle (stats[3]) + iowait (stats[4]) = not working
	            const idle = stats[3] + stats[4]

	            if (previousCpuStats) {
	                const totalDiff = total - previousCpuStats.total
	                const idleDiff = idle - previousCpuStats.idle
	                cpuUsage = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0
	            }

	            previousCpuStats = { total, idle }
	        }

	        // Parse temperatures (millidegrees to degrees)
	        const cpuTempRaw = parseInt(fileCpuTemp.text()) || 0
	        const gpuTempRaw = parseInt(fileGpuTemp.text()) || 0
	        cpuTemp = Math.round(cpuTempRaw / 1000)
	        gpuTemp = Math.round(gpuTempRaw / 1000)

            root.updateHistories()
	    }
	}

	FileView { id: fileMeminfo; path: "/proc/meminfo" }
    FileView { id: fileStat; path: "/proc/stat" }
    // Temperature sensors - k10temp for AMD CPU, amdgpu for AMD GPU
    // These paths are auto-detected at startup
    FileView { id: fileCpuTemp; path: root._cpuTempPath }
    FileView { id: fileGpuTemp; path: root._gpuTempPath }

    // Auto-detect temperature sensor paths
    property string _cpuTempPath: ""
    property string _gpuTempPath: ""

    Component.onCompleted: {
        detectTempSensors.running = true
    }

    Process {
        id: detectTempSensors
        // Detect CPU: k10temp (AMD), coretemp (Intel), cpu_thermal (ARM)
        // Detect GPU: amdgpu (AMD), nvidia (NVIDIA), nouveau (NVIDIA open)
        command: ["bash", "-c", `
            for hwmon in /sys/class/hwmon/hwmon*; do
                name=$(cat $hwmon/name 2>/dev/null)
                case "$name" in
                    k10temp|coretemp|cpu_thermal|zenpower)
                        echo "cpu:$hwmon/temp1_input"
                        ;;
                    amdgpu|radeon|nvidia|nouveau|i915)
                        echo "gpu:$hwmon/temp1_input"
                        ;;
                esac
            done
            # Fallback to thermal_zone if no hwmon found
            if [ ! -f /sys/class/hwmon/hwmon*/temp1_input ]; then
                for tz in /sys/class/thermal/thermal_zone*; do
                    type=$(cat $tz/type 2>/dev/null)
                    case "$type" in
                        *cpu*|*CPU*|x86_pkg_temp) echo "cpu:$tz/temp" ;;
                        *gpu*|*GPU*) echo "gpu:$tz/temp" ;;
                    esac
                done
            fi
        `]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(":")
                if (parts.length === 2) {
                    const [type, path] = parts
                    if (type === "cpu" && !root._cpuTempPath) root._cpuTempPath = path
                    else if (type === "gpu" && !root._gpuTempPath) root._gpuTempPath = path
                }
            }
        }
    }

    Process {
        id: findCpuMaxFreqProc
        command: ["bash", "-c", "lscpu | grep 'CPU max MHz' | awk '{print $4}'"]
        running: true
        stdout: StdioCollector {
            id: outputCollector
            onStreamFinished: {
                const mhz = parseFloat(outputCollector.text)
                if (isNaN(mhz) || mhz <= 0) {
                    root.maxAvailableCpuString = "--"
                } else {
                    root.maxAvailableCpuString = (mhz / 1000).toFixed(0) + " GHz"
                }
            }
        }
    }
}
