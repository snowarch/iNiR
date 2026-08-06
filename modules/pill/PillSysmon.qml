pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * System-vitals backend for the 系 SYSTEM surface. Polls CPU, memory, swap,
 * network, disk and (when a discrete GPU is present) GPU load, temperature and
 * VRAM, exposing them as live properties the surface binds to. Polling only runs
 * while `open` is true, on three decoupled cadences so a slow source never
 * stalls the dials: the cheap /proc and hwmon reads refresh every 500ms, the GPU
 * query every 1s, and disk plus uptime every 5s. Opening the surface primes all
 * three at once so the dials are populated immediately.
 *
 * CPU load is a two-sample delta of /proc/stat (busy vs total jiffies); network
 * rates are a two-sample delta of /proc/net/dev summed over every interface but
 * loopback, divided by the fast interval. CPU temperature resolves once to the
 * most accurate hwmon sensor available: AMD Tdie, else Intel "Package id 0",
 * else AMD Tctl, else the first temp1_input. The GPU path resolves once to
 * nvidia (nvidia-smi), AMD (sysfs gpu_busy_percent) or none; an Intel-only or
 * GPU-less machine reports `hasGpu` false so the surface drops to two dials and
 * hides the VRAM cell. Disk is the root filesystem's used percent.
 */
Singleton {
    id: root

    property bool open: false

    property int cpu: 0
    property int cpuTemp: -1

    property bool hasGpu: false
    property string gpuVendor: ""
    property string amdDev: ""
    property int gpu: 0
    property int gpuTemp: -1
    property bool hasVram: false
    property real vramUsedGb: 0
    property real vramTotalGb: 0

    property real memUsedGb: 0
    property real memTotalGb: 0
    property int memPct: 0
    property real swapUsedGb: 0

    property real netDown: 0
    property real netUp: 0

    property int diskPct: 0
    property string uptime: ""

    property string tempPath: ""

    property real prevCpuTotal: 0
    property real prevCpuIdle: 0
    property real prevRx: 0
    property real prevTx: 0
    property real prevNetTime: 0

    function primeAll() {
        if (tempPath.length === 0 || gpuVendor.length === 0) {
            detectProc.running = true;
            return;
        }
        prevCpuTotal = 0;
        prevRx = 0;
        prevNetTime = 0;
        fastProc.running = true;
        if (hasGpu)
            gpuProc.running = true;
        slowProc.running = true;
    }

    onOpenChanged: if (open) primeAll()

    function fmtUptime(sec) {
        var d = Math.floor(sec / 86400);
        var h = Math.floor((sec % 86400) / 3600);
        var m = Math.floor((sec % 3600) / 60);
        var hh = h < 10 ? "0" + h : "" + h;
        var mm = m < 10 ? "0" + m : "" + m;
        return "UP " + d + "D " + hh + ":" + mm;
    }

    Component.onCompleted: detectProc.running = true

    Process {
        id: detectProc
        command: ["sh", "-c",
            "tp=''; for h in /sys/class/hwmon/hwmon*; do for l in \"$h\"/temp*_label; do [ -r \"$l\" ] || continue; [ \"$(cat \"$l\")\" = Tdie ] && { tp=\"${l%_label}_input\"; break 2; }; done; done; "
            + "[ -z \"$tp\" ] && for h in /sys/class/hwmon/hwmon*; do for l in \"$h\"/temp*_label; do [ -r \"$l\" ] || continue; [ \"$(cat \"$l\")\" = 'Package id 0' ] && { tp=\"${l%_label}_input\"; break 2; }; done; done; "
            + "[ -z \"$tp\" ] && for h in /sys/class/hwmon/hwmon*; do for l in \"$h\"/temp*_label; do [ -r \"$l\" ] || continue; [ \"$(cat \"$l\")\" = Tctl ] && { tp=\"${l%_label}_input\"; break 2; }; done; done; "
            + "[ -z \"$tp\" ] && for h in /sys/class/hwmon/hwmon*; do [ -r \"$h/temp1_input\" ] && { tp=\"$h/temp1_input\"; break; }; done; "
            + "echo \"TEMP $tp\"; "
            + "if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then echo 'GPU nvidia'; "
            + "else for d in /sys/class/drm/card*/device; do [ -r \"$d/vendor\" ] || continue; [ \"$(cat \"$d/vendor\")\" = 0x1002 ] && [ -r \"$d/gpu_busy_percent\" ] && { v=0; [ -r \"$d/mem_info_vram_total\" ] && v=1; echo \"GPU amd $d $v\"; break; }; done; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].trim().split(/\s+/);
                    if (p[0] === "TEMP" && p.length > 1)
                        root.tempPath = p.slice(1).join(" ");
                    else if (p[0] === "GPU" && p[1] === "nvidia") {
                        root.gpuVendor = "nvidia";
                        root.hasGpu = true;
                        root.hasVram = true;
                    } else if (p[0] === "GPU" && p[1] === "amd") {
                        root.gpuVendor = "amd";
                        root.amdDev = p.slice(2, p.length - 1).join(" ");
                        root.hasGpu = true;
                        root.hasVram = p[p.length - 1] === "1";
                    }
                }
                if (root.gpuVendor.length === 0)
                    root.gpuVendor = "none";
                if (root.open)
                    root.primeAll();
            }
        }
    }

    Process {
        id: fastProc
        command: ["sh", "-c",
            "read -r _ a b c d e f g h _ < /proc/stat; echo \"CPU $((a+b+c+d+e+f+g+h)) $((d+e))\"; "
            + "awk '/^MemTotal:/{mt=$2}/^MemAvailable:/{ma=$2}/^SwapTotal:/{st=$2}/^SwapFree:/{sf=$2}END{print \"MEM\",mt,ma,st,sf}' /proc/meminfo; "
            + "awk 'NR>2{gsub(\":\",\" \");if($1!=\"lo\"){rx+=$2;tx+=$10}}END{print \"NET\",rx+0,tx+0}' /proc/net/dev; "
            + "if [ -n \"$1\" ] && [ -r \"$1\" ]; then echo \"TMP $(cat \"$1\")\"; else echo 'TMP -'; fi",
            "_", root.tempPath]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].trim().split(/\s+/);
                    if (p[0] === "CPU") {
                        var total = parseFloat(p[1]);
                        var idle = parseFloat(p[2]);
                        if (root.prevCpuTotal > 0) {
                            var dt = total - root.prevCpuTotal;
                            var di = idle - root.prevCpuIdle;
                            root.cpu = dt > 0 ? Math.max(0, Math.min(100, Math.round(100 * (dt - di) / dt))) : 0;
                        }
                        root.prevCpuTotal = total;
                        root.prevCpuIdle = idle;
                    } else if (p[0] === "MEM") {
                        var mt = parseFloat(p[1]);
                        var ma = parseFloat(p[2]);
                        var st = parseFloat(p[3]);
                        var sf = parseFloat(p[4]);
                        root.memTotalGb = mt / 1048576;
                        root.memUsedGb = (mt - ma) / 1048576;
                        root.memPct = mt > 0 ? Math.round(100 * (mt - ma) / mt) : 0;
                        root.swapUsedGb = (st - sf) / 1048576;
                    } else if (p[0] === "NET") {
                        var rx = parseFloat(p[1]);
                        var tx = parseFloat(p[2]);
                        var now = Date.now();
                        var dt = (now - root.prevNetTime) / 1000;
                        if (root.prevNetTime > 0 && dt > 0) {
                            root.netDown = Math.max(0, (rx - root.prevRx) / dt / 1048576);
                            root.netUp = Math.max(0, (tx - root.prevTx) / dt / 1048576);
                        }
                        root.prevRx = rx;
                        root.prevTx = tx;
                        root.prevNetTime = now;
                    } else if (p[0] === "TMP") {
                        root.cpuTemp = p[1] === "-" ? -1 : Math.round(parseFloat(p[1]) / 1000);
                    }
                }
            }
        }
    }

    Process {
        id: gpuProc
        command: root.gpuVendor === "nvidia"
            ? ["sh", "-c", "nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits | head -1"]
            : ["sh", "-c",
                "d=\"$1\"; echo \"BUSY $(cat \"$d/gpu_busy_percent\" 2>/dev/null)\"; "
                + "t=$(cat \"$d\"/hwmon/hwmon*/temp1_input 2>/dev/null | head -1); echo \"TEMP ${t:-0}\"; "
                + "echo \"VU $(cat \"$d/mem_info_vram_used\" 2>/dev/null)\"; echo \"VT $(cat \"$d/mem_info_vram_total\" 2>/dev/null)\"",
                "_", root.amdDev]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.gpuVendor === "nvidia") {
                    var c = this.text.trim().split(",");
                    if (c.length >= 4) {
                        root.gpu = Math.max(0, Math.min(100, Math.round(parseFloat(c[0]) || 0)));
                        root.gpuTemp = Math.round(parseFloat(c[1]) || 0);
                        root.vramUsedGb = (parseFloat(c[2]) || 0) / 1024;
                        root.vramTotalGb = (parseFloat(c[3]) || 0) / 1024;
                    }
                    return;
                }
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].trim().split(/\s+/);
                    if (p[0] === "BUSY")
                        root.gpu = Math.max(0, Math.min(100, Math.round(parseFloat(p[1]) || 0)));
                    else if (p[0] === "TEMP")
                        root.gpuTemp = Math.round((parseFloat(p[1]) || 0) / 1000);
                    else if (p[0] === "VU")
                        root.vramUsedGb = (parseFloat(p[1]) || 0) / 1073741824;
                    else if (p[0] === "VT")
                        root.vramTotalGb = (parseFloat(p[1]) || 0) / 1073741824;
                }
            }
        }
    }

    Process {
        id: slowProc
        command: ["sh", "-c",
            "df -P / | awk 'NR==2{gsub(\"%\",\"\",$5);print \"DISK \"$5}'; awk '{print \"UP \"int($1)}' /proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].trim().split(/\s+/);
                    if (p[0] === "DISK")
                        root.diskPct = parseInt(p[1], 10) || 0;
                    else if (p[0] === "UP")
                        root.uptime = root.fmtUptime(parseInt(p[1], 10) || 0);
                }
            }
        }
    }

    Timer {
        interval: 500
        running: root.open
        repeat: true
        onTriggered: if (!fastProc.running) fastProc.running = true
    }

    Timer {
        interval: 1000
        running: root.open && root.hasGpu
        repeat: true
        onTriggered: if (!gpuProc.running) gpuProc.running = true
    }

    Timer {
        interval: 5000
        running: root.open
        repeat: true
        onTriggered: if (!slowProc.running) slowProc.running = true
    }
}
