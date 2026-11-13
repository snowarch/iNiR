pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Qt5Compat.GraphicalEffects
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.shared.overlay

// The connection as a game feels it: the latency large over its trace (a lost reply spikes to the top), how steady
// it is beneath, then what flows down and up. Latency is the time to open a TCP connection (no ping tools needed);
// nothing runs while the tool is out of sight.
StyledOverlayWidget {
    id: root

    readonly property string target: {
        const t = Config.getNestedValue("overlay.network.target", "cloudflare")
        return ["cloudflare", "google", "router"].includes(t) ? t : "cloudflare"
    }
    options: [
        { key: "overlay.network.target", label: "Measure against", fallback: "cloudflare",
            choices: [{ value: "cloudflare", label: "Cloudflare" }, { value: "google", label: "Google" }, { value: "router", label: "Router" }] }
    ]

    // The default route: its interface carries the traffic, its gateway is the router.
    property string iface: ""
    property string gateway: ""
    readonly property bool online: root.iface.length > 0
    readonly property string host: !root.online ? ""
        : root.target === "router" ? root.gateway
        : root.target === "google" ? "8.8.8.8" : "1.1.1.1"
    readonly property int port: root.target === "router" ? 80 : 443
    readonly property string targetName: root.target === "router" ? Translation.tr("Router") : root.target === "google" ? "Google" : "Cloudflare"

    // Round trips in ms, -1 for a lost one; the newest last.
    property list<real> samples: []
    readonly property int keep: 60
    onHostChanged: root.samples = []

    readonly property var stats: {
        const recent = root.samples.slice(-30)
        const ok = recent.filter(v => v >= 0)
        const last = ok.length > 0 ? ok[ok.length - 1] : -1
        let jitter = 0
        for (let i = 1; i < ok.length; i++)
            jitter += Math.abs(ok[i] - ok[i - 1])
        return {
            last: last,
            jitter: ok.length > 1 ? jitter / (ok.length - 1) : 0,
            loss: recent.length > 0 ? (recent.length - ok.length) / recent.length : 0,
            lostNow: root.samples.length > 0 && root.samples[root.samples.length - 1] < 0
        }
    }
    // The trace's ceiling: 100 ms, or room above the worst recent reply.
    readonly property real ceiling: {
        let worst = 0
        for (const v of root.samples)
            worst = Math.max(worst, v)
        return Math.max(100, Math.ceil(worst * 1.25 / 50) * 50)
    }
    readonly property list<real> trace: root.samples.map(v => v < 0 ? 1 : Math.min(1, v / root.ceiling))

    function sample(line: string): void {
        const us = Number(line.trim())
        if (!isFinite(us)) return
        const next = root.samples.slice(-(root.keep - 1))
        next.push(us < 0 ? -1 : us / 1000)
        root.samples = next
    }
    function ms(v: real): string { return v < 10 ? v.toFixed(1) : String(Math.round(v)) }

    property real downRate: 0
    property real upRate: 0
    property real _rx: -1
    property real _tx: -1
    property real _at: 0
    function rate(bytes: real): string {
        const units = ["B/s", "KB/s", "MB/s", "GB/s"]
        let value = Math.max(0, bytes)
        let unit = 0
        while (value >= 1024 && unit < units.length - 1) {
            value /= 1024
            unit++
        }
        return value.toFixed(unit > 0 && value < 100 ? 1 : 0) + " " + units[unit]
    }

    FileView {
        id: routes
        path: "/proc/net/route"
        printErrors: false
        onLoaded: {
            // Iface Destination Gateway Flags RefCnt Use Metric ...; the default route with the lowest metric.
            let best = null
            for (const line of routes.text().split("\n").slice(1)) {
                const f = line.trim().split(/\s+/)
                if (f.length < 7 || f[1] !== "00000000") continue
                if (!best || Number(f[6]) < Number(best[6])) best = f
            }
            root.iface = best ? best[0] : ""
            const g = best ? best[2] : ""
            root.gateway = g.length === 8 ? [6, 4, 2, 0].map(i => parseInt(g.substr(i, 2), 16)).join(".") : ""
        }
    }
    FileView {
        id: traffic
        path: "/proc/net/dev"
        printErrors: false
        onLoaded: {
            const line = traffic.text().split("\n").find(l => l.trim().startsWith(root.iface + ":"))
            if (!line || !root.online) {
                root.downRate = 0
                root.upRate = 0
                return
            }
            const f = line.slice(line.indexOf(":") + 1).trim().split(/\s+/)
            const rx = Number(f[0])
            const tx = Number(f[8])
            const now = Date.now()
            if (root._rx >= 0 && now > root._at) {
                root.downRate = Math.max(0, rx - root._rx) * 1000 / (now - root._at)
                root.upRate = Math.max(0, tx - root._tx) * 1000 / (now - root._at)
            }
            root._rx = rx
            root._tx = tx
            root._at = now
        }
    }
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.visible
        onTriggered: {
            routes.reload()
            traffic.reload()
        }
    }

    // One prober per host: a new target or the tool going out of sight ends it. Each second it opens a connection
    // and prints the microseconds it took; a refusal is a reply too, a timeout or no route prints -1.
    Instantiator {
        model: root.visible && root.host.length > 0 ? [root.host] : []
        delegate: Process {
            required property string modelData
            running: true
            command: ["bash", "-c", `export LC_ALL=C
f="\${XDG_RUNTIME_DIR:-/tmp}/inir-latency.$$"
trap 'exit 0' TERM INT HUP
trap 'rm -f "$f"' EXIT
exec 9<> <(:)
while :; do
  s=$EPOCHREALTIME
  if timeout 2 bash -c 'exec 3<>"/dev/tcp/$1/$2"' _ "$1" "$2" 2>"$f"; then ok=1
  else err=; read -r err < "$f"; [[ $err == *refused* ]] && ok=1 || ok=0; fi
  e=$EPOCHREALTIME
  if (( ok )); then echo $(( 10#\${e//[.,]/} - 10#\${s//[.,]/} )); else echo -1; fi
  read -t 1 -u 9
done`, "_", modelData, String(root.port)]
            stdout: SplitParser { onRead: data => root.sample(data) }
        }
    }

    contentItem: Item {
        anchors.fill: parent
        implicitWidth: Math.round(300 * root.d)
        implicitHeight: Math.round(220 * root.d)

        ColumnLayout {
            anchors.fill: parent
            spacing: Math.round(8 * root.d)

            // Latency: its figure over its trace.
            Rectangle {
                id: card
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: OverlayLook.roundingNormal
                color: OverlayLook.colRecessed
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: card.width
                        height: card.height
                        radius: card.radius
                    }
                }

                Graph {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.top: readout.bottom
                    anchors.topMargin: Math.round(6 * root.d)
                    visible: root.online
                    values: root.trace
                    points: root.keep
                    alignment: Graph.Alignment.Right
                    color: root.stats.last >= 150 || root.stats.loss > 0.1 ? OverlayLook.colError : OverlayLook.colPrimary
                    fillOpacity: 0.22
                }

                Column {
                    id: readout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Math.round(12 * root.d)
                    spacing: 0
                    Row {
                        spacing: Math.round(6 * root.d)
                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.online ? "network_ping" : "signal_disconnected"
                            iconSize: Math.round(16 * root.d)
                            fill: 1
                            color: root.online ? OverlayLook.colPrimary : OverlayLook.colSubtext
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.online ? Translation.tr("Latency to %1").arg(root.targetName) : Translation.tr("Offline")
                            color: OverlayLook.colSubtext
                            font.family: OverlayLook.fontMain
                            font.pixelSize: OverlayLook.typeMeta
                            font.weight: Font.DemiBold
                        }
                    }
                    Row {
                        spacing: Math.round(4 * root.d)
                        StyledText {
                            id: figure
                            text: !root.online || root.stats.last < 0 ? "--" : root.ms(root.stats.last)
                            color: root.stats.last >= 150 ? OverlayLook.colError : OverlayLook.colOnLayer1
                            font.family: OverlayLook.fontNumbers
                            font.features: ({ "tnum": 1 })
                            font.pixelSize: OverlayLook.typeFigure
                            font.weight: Font.DemiBold
                        }
                        StyledText {
                            anchors.baseline: figure.baseline
                            visible: figure.text !== "--"
                            text: "ms"
                            color: OverlayLook.colSubtext
                            font.family: OverlayLook.fontMain
                            font.pixelSize: OverlayLook.typeMeta
                            font.weight: Font.DemiBold
                        }
                    }
                    StyledText {
                        width: parent.width
                        elide: Text.ElideRight
                        visible: root.online
                        text: root.stats.lostNow ? Translation.tr("No reply")
                            : root.samples.length < 2 ? Translation.tr("Measuring…")
                            : [Translation.tr("Jitter %1 ms").arg(root.ms(root.stats.jitter)),
                               Translation.tr("Loss %1%").arg(Math.round(root.stats.loss * 100))].join("  ·  ")
                        color: root.stats.lostNow || root.stats.loss > 0.1 ? OverlayLook.colError : OverlayLook.colSubtext
                        font.family: OverlayLook.fontMain
                        font.pixelSize: OverlayLook.typeMeta
                    }
                }
            }

            // What flows now on the default route.
            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(4 * root.d)
                Repeater {
                    model: [
                        { glyph: "arrow_downward", label: Translation.tr("Down"), value: root.downRate },
                        { glyph: "arrow_upward", label: Translation.tr("Up"), value: root.upRate }
                    ]
                    Rectangle {
                        id: flow
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: Math.round(40 * root.d)
                        radius: OverlayLook.roundingSmall
                        color: OverlayLook.colRecessed
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Math.round(10 * root.d)
                            anchors.rightMargin: Math.round(10 * root.d)
                            spacing: Math.round(6 * root.d)
                            MaterialSymbol {
                                text: flow.modelData.glyph
                                iconSize: Math.round(16 * root.d)
                                color: OverlayLook.colPrimary
                            }
                            StyledText {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: flow.modelData.label
                                color: OverlayLook.colSubtext
                                font.family: OverlayLook.fontMain
                                font.pixelSize: OverlayLook.typeFootnote
                                font.weight: Font.DemiBold
                            }
                            StyledText {
                                text: root.online ? root.rate(flow.modelData.value) : "--"
                                color: OverlayLook.colOnLayer1
                                font.family: OverlayLook.fontNumbers
                                font.features: ({ "tnum": 1 })
                                font.pixelSize: OverlayLook.typeMeta
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }
            }
        }
    }
}
