pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions

// One colour taken from the screen. Every screen is captured (grim) and shown still, a loupe follows the pointer and
// a click reads that pixel straight from the capture. Ours because hyprpicker needs ext-image-copy-capture, which
// Niri does not offer. pick() starts it; picked(color) or cancelled() ends it.
Scope {
    id: root

    signal picked(color value)
    signal cancelled()

    // "", waiting (whatever opened it gets out of the picture), capturing, showing, reading.
    property string stage: ""
    readonly property bool running: root.stage !== ""
    property var captures: ({})

    function pick(): void {
        if (root.running)
            return
        root.stage = "waiting"
        settle.restart()
    }
    function cancel(): void {
        root.finish()
        root.cancelled()
    }
    function finish(): void {
        settle.stop()
        root.stage = ""
        root.captures = ({})
        cleanup.running = true
    }

    Timer {
        id: settle
        interval: 260
        onTriggered: {
            root.stage = "capturing"
            capture.command = ["bash", "-c", "dir=\"${XDG_RUNTIME_DIR:-/tmp}/inir-pick\"; rm -rf \"$dir\"; mkdir -p \"$dir\" || exit 1; stamp=$(date +%s%N); for o in \"$@\"; do grim -t ppm -o \"$o\" \"$dir/$o-$stamp.ppm\" && printf '%s\\t%s\\n' \"$o\" \"$dir/$o-$stamp.ppm\"; done", "_"].concat(Quickshell.screens.map(screen => screen.name))
            capture.running = true
        }
    }
    Process {
        id: capture
        stdout: StdioCollector {
            id: captureOut
            onStreamFinished: {
                const found = {}
                captureOut.text.split("\n").forEach(line => {
                    const parts = line.split("\t")
                    if (parts.length === 2)
                        found[parts[0]] = parts[1]
                })
                root.captures = found
                if (Object.keys(found).length > 0) {
                    root.stage = "showing"
                } else {
                    console.warn("[ScreenColorPicker] grim captured nothing")
                    root.cancel()
                }
            }
        }
    }

    // The pixel is read from the capture's own bytes (P6: three header lines, then RGB).
    Process {
        id: reader
        stdout: StdioCollector {
            id: readerOut
            onStreamFinished: {
                const rgb = readerOut.text.trim().split(/\s+/).map(Number)
                if (rgb.length === 3 && rgb.every(n => isFinite(n))) {
                    const value = Qt.rgba(rgb[0] / 255, rgb[1] / 255, rgb[2] / 255, 1)
                    root.finish()
                    root.picked(value)
                } else {
                    root.cancel()
                }
            }
        }
    }
    function read(file: string, x: int, y: int): void {
        root.stage = "reading"
        reader.command = ["bash", "-c", "{ read -r m; read -r w h; read -r mx; } < \"$1\" && od -An -tu1 -j $(( ${#m} + ${#w} + ${#h} + ${#mx} + 4 + ($3 * w + $2) * 3 )) -N 3 \"$1\"", "_", file, String(x), String(y)]
        reader.running = true
    }

    Process {
        id: cleanup
        command: ["bash", "-c", "rm -rf \"${XDG_RUNTIME_DIR:-/tmp}/inir-pick\""]
    }

    Variants {
        model: root.stage === "showing" || root.stage === "reading" ? Quickshell.screens : []

        PanelWindow {
            id: window
            required property var modelData
            readonly property string file: root.captures[window.modelData.name] ?? ""
            readonly property bool focusedHere: (GlobalStates.focusedScreen?.name ?? "") === window.modelData.name
            readonly property real s: FamilyStyle.density
            // Captured pixels per logical pixel.
            readonly property real ratio: still.sourceSize.width > 0 ? still.sourceSize.width / Math.max(1, window.width) : 1
            readonly property int px: Math.max(0, Math.min(still.sourceSize.width - 1, Math.floor(area.mouseX * window.ratio)))
            readonly property int py: Math.max(0, Math.min(still.sourceSize.height - 1, Math.floor(area.mouseY * window.ratio)))

            screen: window.modelData
            color: "black"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "inir:screenColorPicker"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: window.focusedHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Image {
                id: still
                anchors.fill: parent
                source: window.file.length > 0 ? "file://" + window.file : ""
                asynchronous: false
                smooth: true
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.BlankCursor
                focus: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (root.stage !== "showing")
                        return
                    if (mouse.button === Qt.RightButton)
                        root.cancel()
                    else
                        root.read(window.file, window.px, window.py)
                }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        root.cancel()
                        event.accepted = true
                    } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && area.containsMouse && root.stage === "showing") {
                        root.read(window.file, window.px, window.py)
                        event.accepted = true
                    }
                }
            }

            // The loupe: the pixels around the pointer, large, the one that will be taken framed in its middle.
            Item {
                id: loupe
                readonly property int cells: 11
                readonly property real cell: Math.round(12 * window.s)
                visible: area.containsMouse
                width: loupe.cells * loupe.cell
                height: width
                x: Math.round(area.mouseX - width / 2)
                y: Math.round(area.mouseY - height / 2)

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -4
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: "#66000000"
                }
                ClippingRectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "black"
                    border.width: 3
                    border.color: "#FFFFFF"

                    // The captured pixels around the pointer, one texel each, drawn large without smoothing.
                    ShaderEffectSource {
                        anchors.fill: parent
                        sourceItem: still
                        sourceRect: Qt.rect((window.px - (loupe.cells - 1) / 2) / window.ratio, (window.py - (loupe.cells - 1) / 2) / window.ratio,
                            loupe.cells / window.ratio, loupe.cells / window.ratio)
                        textureSize: Qt.size(loupe.cells, loupe.cells)
                        smooth: false
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: loupe.cell + 2
                        height: width
                        color: "transparent"
                        border.width: 1
                        border.color: "#FFFFFF"
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -1
                            color: "transparent"
                            border.width: 1
                            border.color: "#99000000"
                        }
                    }
                }
            }

            // What to do, once, at the bottom of the screen the pointer is on.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round(48 * window.s)
                visible: window.focusedHere
                // Out of the way when the pointer comes down to it.
                opacity: area.containsMouse && area.mouseY > y - loupe.height ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: FamilyStyle.feedbackDuration } }
                width: hint.implicitWidth + Math.round(28 * window.s)
                height: Math.round(36 * window.s)
                radius: height / 2
                color: FamilyStyle.bodySurface
                border.width: 1
                border.color: FamilyStyle.border
                StyledText {
                    id: hint
                    anchors.centerIn: parent
                    text: Translation.tr("Click to take a colour  ·  Esc to cancel")
                    color: FamilyStyle.textStrong
                    font.family: FamilyStyle.fontMain
                    font.pixelSize: FamilyStyle.typeMeta
                }
            }
        }
    }
}
