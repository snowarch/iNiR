pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.modules.common

// Who is using the microphone, the camera or the screen right now. Mic and camera come from PipeWire links (a
// device node feeding an app's stream); cameras opened straight through V4L2 are read from /proc while a device
// exists; screen casts come from niri's event stream.
Singleton {
    id: root

    readonly property var links: Pipewire.links?.values ?? []

    function nameOf(node): string {
        if (!node) return ""
        const props = node.properties ?? {}
        return String(props["application.name"] ?? "") || String(node.description ?? "") || String(node.name ?? "")
    }
    function binaryOf(node): string {
        return String(node?.properties?.["application.process.binary"] ?? "")
    }
    function unique(names): var {
        return names.filter((name, i) => name.length > 0 && names.indexOf(name) === i)
    }
    // The shell's own meters read the mic too; they are not someone listening.
    function ours(node): bool {
        const bin = root.binaryOf(node)
        return bin === "qs" || bin === "quickshell"
    }

    readonly property var micLinks: root.links.filter(link => {
        const source = link?.source
        const target = link?.target
        return source && target && !source.isStream && !source.isSink && (source.type & PwNodeType.Audio) !== 0
            && target.isStream && !root.ours(target)
    })
    readonly property var cameraLinks: root.links.filter(link => {
        const source = link?.source
        const target = link?.target
        return source && target && !source.isStream && !source.isSink && (source.type & PwNodeType.Video) !== 0
            && !String(source.name ?? "").startsWith("niri-screen-cast") && !String(source.name ?? "").startsWith("xdpw")
            && target.isStream && !root.ours(target)
    })

    // `privacy simulate`: who pretends to use what, until the shell restarts (testing without a mic, camera or cast).
    property var simulated: ({ mic: [], camera: [], cast: [] })

    property bool micActive: root.micLinks.length > 0 || root.simulated.mic.length > 0
    readonly property var micApps: root.unique(root.micLinks.map(link => root.nameOf(link.target)).concat(root.simulated.mic))

    property var v4l2Apps: []
    readonly property var cameraApps: root.unique(root.cameraLinks.map(link => root.nameOf(link.target)).concat(root.v4l2Apps, root.simulated.camera))
    readonly property bool cameraActive: root.cameraApps.length > 0

    // A paused cast (another OBS scene) is not watching the screen.
    readonly property var casts: (NiriService.casts ?? []).filter(cast => cast?.is_active !== false)
        .concat(root.simulated.cast.map((name, i) => ({ stream_id: -1 - i, session_id: -1 - i, kind: "WlrScreencopy",
            target: { Output: { name: Quickshell.screens[0]?.name ?? "" } }, is_active: true, simulatedBy: name })))
    property bool screenSharing: root.casts.length > 0
    function castViewer(cast): string {
        if (cast?.simulatedBy) return cast.simulatedBy
        if (cast?.pw_node_id !== undefined && cast?.pw_node_id !== null) {
            const link = root.links.find(link => link?.source?.id === cast.pw_node_id && link?.target)
            if (link) return root.nameOf(link.target)
        }
        if (cast?.pid) {
            const window = (NiriService.windows ?? []).find(window => window.pid === cast.pid)
            if (window) return String(window.app_id ?? "")
        }
        return ""
    }
    function castTarget(cast): string {
        const target = cast?.target ?? {}
        if (target.Output) return String(target.Output.name ?? "")
        if (target.Window) {
            const window = (NiriService.windows ?? []).find(window => window.id === target.Window.id)
            return String(window?.title ?? window?.app_id ?? "")
        }
        return ""
    }
    readonly property var castApps: root.unique(root.casts.map(cast => root.castViewer(cast)))
    /// Who is using the microphone, the camera or the screen (PipeWire links, V4L2, niri screencasts). `simulate`
    /// lets you see the marks without one.
    IpcHandler {
        target: "privacy"
        /// Print the apps using the mic and camera and every screencast with who watches it, as JSON
        function status(): string {
            return JSON.stringify({ mic: root.micApps, camera: root.cameraApps,
                screen: root.casts.map(cast => ({ by: root.castViewer(cast), target: root.castTarget(cast), kind: cast.kind })) })
        }
        /// Pretend an app uses something until the shell restarts: `"mic Discord"`, `"camera Zoom"`, `"cast OBS"`, or
        /// `off`. For testing
        function simulate(spec: string): string {
            const words = String(spec ?? "").trim().split(/\s+/)
            const kind = words[0] ?? ""
            const who = words.slice(1).join(" ") || "Test"
            if (kind === "off") root.simulated = { mic: [], camera: [], cast: [] }
            else if (["mic", "camera", "cast"].includes(kind)) {
                const next = Object.assign({}, root.simulated)
                next[kind] = next[kind].concat([who])
                root.simulated = next
            } else return "Use: mic|camera|cast [app], or off"
            return root.ipcStatus()
        }
    }
    function ipcStatus(): string {
        return JSON.stringify({ mic: root.micApps, camera: root.cameraApps, screen: root.castApps })
    }

    readonly property bool anyActive: root.micActive || root.cameraActive || root.screenSharing

    // Cameras opened through V4L2 never show in PipeWire: look at who holds /dev/video* open, only while one exists
    // and only for a family that shows it (flag `cameraWatch`).
    readonly property bool _cameraWatched: Plugins.flag(Plugins.active, "cameraWatch")
    property bool hasCamera: false
    Process {
        running: Config.ready && root._cameraWatched
        command: ["sh", "-c", "ls /dev/video* >/dev/null 2>&1 && echo yes || echo no"]
        stdout: StdioCollector { onStreamFinished: root.hasCamera = this.text.trim() === "yes" }
    }
    Timer {
        interval: 5000
        repeat: true
        running: root.hasCamera && root._cameraWatched
        triggeredOnStart: true
        onTriggered: if (!v4l2.running) v4l2.running = true
        onRunningChanged: if (!running) root.v4l2Apps = []
    }
    Process {
        id: v4l2
        command: ["sh", "-c", "find /proc/[0-9]*/fd -maxdepth 1 -lname '/dev/video*' 2>/dev/null | cut -d/ -f3 | sort -u | while read -r p; do cat \"/proc/$p/comm\"; done 2>/dev/null | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = this.text.split("\n").map(name => name.trim()).filter(name => name.length > 0
                    && !["pipewire", "wireplumber"].includes(name))
                if (JSON.stringify(names) !== JSON.stringify(root.v4l2Apps)) root.v4l2Apps = names
            }
        }
    }
}
