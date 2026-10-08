pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

/**
 * Presentation adapter for the 系 SYSTEM surface. CPU, memory, swap, GPU and
 * temperatures come from ResourceUsage. This singleton owns only the pill's
 * network, VRAM and uptime polling, preserving the surface-specific cadence
 * without a second hardware telemetry implementation.
 */
Singleton {
    id: root

    property bool open: false

    readonly property int cpu: Math.round(ResourceUsage.cpuUsage * 100)
    readonly property int cpuTemp: ResourceUsage.cpuTemp > 0 ? ResourceUsage.cpuTemp : -1
    readonly property bool gpuUsageAvailable: ResourceUsage.gpuUsageAvailable
    readonly property bool hasGpu: root.gpuUsageAvailable
    readonly property int gpu: Math.round(ResourceUsage.gpuUsage * 100)
    readonly property int gpuTemp: ResourceUsage.gpuTemp > 0 ? ResourceUsage.gpuTemp : -1

    // VRAM is an optional pill detail; load and temperature remain shared.
    readonly property bool hasVram: root.gpuUsageAvailable && root.vramAvailable
    property bool vramAvailable: false
    property real vramUsedGb: 0
    property real vramTotalGb: 0

    readonly property real memUsedGb: ResourceUsage.memoryUsed / 1048576
    readonly property real memTotalGb: ResourceUsage.memoryTotal / 1048576
    readonly property int memPct: Math.round(ResourceUsage.memoryUsedPercentage * 100)
    readonly property real swapUsedGb: ResourceUsage.swapUsed / 1048576

    property real netDown: 0
    property real netUp: 0
    readonly property int diskPct: Math.round(ResourceUsage.diskUsedPercentage * 100)
    property string uptime: ""

    property real prevRx: 0
    property real prevTx: 0
    property real prevNetTime: 0

    function primeAll() {
        ResourceUsage.ensureRunning();
        prevRx = 0;
        prevTx = 0;
        prevNetTime = 0;
        vramAvailable = false;
        netProc.running = true;
        vramProc.running = root.hasGpu;
        slowProc.running = true;
    }

    onOpenChanged: {
        if (open) { ResourceUsage.keepAlive(); primeAll(); }
        else ResourceUsage.releaseKeepAlive();
    }
    Component.onDestruction: { if (open) ResourceUsage.releaseKeepAlive(); }

    function fmtUptime(sec) {
        var d = Math.floor(sec / 86400);
        var h = Math.floor((sec % 86400) / 3600);
        var m = Math.floor((sec % 3600) / 60);
        var hh = h < 10 ? "0" + h : "" + h;
        var mm = m < 10 ? "0" + m : "" + m;
        return "UP " + d + "D " + hh + ":" + mm;
    }

    Process {
        id: netProc
        command: ["sh", "-c",
            "awk 'NR>2{gsub(\":\",\" \" );if($1!=\"lo\"){rx+=$2;tx+=$10}}END{print rx+0,tx+0}' /proc/net/dev"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var p = this.text.trim().split(/\s+/);
                if (p.length < 2) return;
                var rx = parseFloat(p[0]);
                var tx = parseFloat(p[1]);
                var now = Date.now();
                var dt = (now - root.prevNetTime) / 1000;
                if (root.prevNetTime > 0 && dt > 0) {
                    root.netDown = Math.max(0, (rx - root.prevRx) / dt / 1048576);
                    root.netUp = Math.max(0, (tx - root.prevTx) / dt / 1048576);
                }
                root.prevRx = rx;
                root.prevTx = tx;
                root.prevNetTime = now;
            }
        }
    }

    // VRAM is presentation-only data; use ResourceUsage's selected device and
    // polling gate so a suspended/disabled GPU is never woken by this surface.
    Process {
        id: vramProc
        command: ["sh", "-c",
            "[ \"$2\" = 1 ] || exit 0; "
            + "if [ -f \"$1/power/runtime_status\" ]; then state=$(cat \"$1/power/runtime_status\"); case \"$state\" in active|unsupported) ;; *) exit 0 ;; esac; fi; "
            + "vendor=$(cat \"$1/vendor\" 2>/dev/null); if [ \"$vendor\" = 0x1002 ]; then "
            + "echo VU $(cat \"$1/mem_info_vram_used\" 2>/dev/null); "
            + "echo VT $(cat \"$1/mem_info_vram_total\" 2>/dev/null); "
            + "elif [ \"$vendor\" = 0x10de ] && command -v nvidia-smi >/dev/null 2>&1; then "
            + "timeout 2 nvidia-smi --id=\"${1##*/}\" --query-gpu=memory.used,memory.total --format=csv,noheader,nounits | head -1 | awk -F, '{print \"NU \"$1; print \"NT \"$2}'; fi",
            "_", ResourceUsage.gpuDevicePath, ResourceUsage.gpuPollingAllowed ? 1 : 0]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.vramAvailable = false;
                if (!root.open || !ResourceUsage.gpuPollingAllowed) return;

                for (var line of this.text.split("\n")) {
                    var p = line.trim().split(/\s+/);
                    if (p[0] === "VU") { root.vramUsedGb = (parseFloat(p[1]) || 0) / 1073741824; root.vramAvailable = root.vramTotalGb > 0; }
                    else if (p[0] === "VT") { root.vramTotalGb = (parseFloat(p[1]) || 0) / 1073741824; root.vramAvailable = root.vramTotalGb > 0; }
                    else if (p[0] === "NU") { root.vramUsedGb = (parseFloat(p[1]) || 0) / 1024; root.vramAvailable = root.vramTotalGb > 0; }
                    else if (p[0] === "NT") { root.vramTotalGb = (parseFloat(p[1]) || 0) / 1024; root.vramAvailable = root.vramTotalGb > 0; }
                }
            }
        }
    }

    Process {
        id: slowProc
        command: ["sh", "-c",
            "awk '{print \"UP \"int($1)}' /proc/uptime"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                for (var line of this.text.split("\n")) {
                    var p = line.trim().split(/\s+/);
                    if (p[0] === "UP") root.uptime = root.fmtUptime(parseInt(p[1], 10) || 0);
                }
            }
        }
    }

    Timer {
        interval: 500
        running: root.open
        repeat: true
        onTriggered: if (!netProc.running) netProc.running = true
    }

    Timer {
        interval: 1000
        running: root.open && root.hasGpu
        repeat: true
        onTriggered: if (!vramProc.running) vramProc.running = true
    }

    Timer {
        interval: 5000
        running: root.open
        repeat: true
        onTriggered: if (!slowProc.running) slowProc.running = true
    }
}
