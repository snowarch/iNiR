pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.shared.overlay

// MangoHud's frame cap, read from and written to its own config: the cap in large (type it, step it, scroll it),
// the usual caps and the display's own rate one click away. MangoHud picks the file up by itself.
StyledOverlayWidget {
    id: root
    resizable: false

    readonly property string confPath: Directories.configPath + "/MangoHud/MangoHud.conf"
    // -1 until the file is read; 0 means no cap.
    property int limit: -1
    property int draft: -1
    readonly property int shown: root.draft >= 0 ? root.draft : Math.max(0, root.limit)
    property string saveState: ""
    property bool installed: true

    readonly property int refreshHz: {
        const out = NiriService.outputs?.[NiriService.currentOutput]
        const mode = out?.modes?.[out?.current_mode ?? -1]
        return mode?.refresh_rate ? Math.round(mode.refresh_rate / 1000) : 0
    }
    readonly property var presets: {
        const caps = [30, 60, 120, 144]
        if (root.refreshHz > 0 && !caps.includes(root.refreshHz)) caps.push(root.refreshHz)
        caps.sort((a, b) => a - b)
        return [{ value: 0, label: "Off" }].concat(caps.slice(0, 5).map(v => ({ value: v, label: String(v) })))
    }


    // The last uncommented fps_limit line: its values and where it sits.
    function parse(text: string): var {
        const lines = text.split("\n")
        for (let i = lines.length - 1; i >= 0; i--) {
            const m = /^\s*fps_limit\s*=\s*([0-9,\s]*)$/.exec(lines[i])
            if (!m) continue
            const values = m[1].split(",").map(v => parseInt(v.trim())).filter(v => !isNaN(v))
            return { index: i, values: values.length > 0 ? values : [0] }
        }
        return null
    }
    // A cap list (MangoHud's toggle cycles it) keeps its other values; the chosen one goes first.
    function compose(text: string, value: int): string {
        const found = root.parse(text)
        if (!found) {
            const base = text.length === 0 || text.endsWith("\n") ? text : text + "\n"
            return base + "fps_limit=" + value + "\n"
        }
        const old = found.values
        const list = old.includes(value) ? [value].concat(old.filter(v => v !== value)) : [value].concat(old.slice(1))
        const lines = text.split("\n")
        lines[found.index] = "fps_limit=" + list.join(",")
        return lines.join("\n")
    }

    function set(value: int): void {
        root.draft = Math.max(0, Math.min(1000, value))
        root.saveState = "saving"
        writeTimer.restart()
    }
    function step(up: bool): void {
        const v = root.shown
        if (up) root.set(v === 0 ? 30 : Math.floor(v / 5) * 5 + 5)
        else root.set(v <= 5 ? 0 : Math.ceil(v / 5) * 5 - 5)
    }

    Timer {
        id: writeTimer
        interval: 280
        onTriggered: conf.setText(root.compose(conf.loadedText, root.draft))
    }
    Timer {
        id: savedTimer
        interval: 1600
        onTriggered: if (root.saveState === "saved") root.saveState = ""
    }

    FileView {
        id: conf
        property string loadedText: ""
        path: root.confPath
        watchChanges: true
        printErrors: false
        onFileChanged: conf.reload()
        onLoaded: {
            conf.loadedText = conf.text()
            const found = root.parse(conf.loadedText)
            root.limit = found ? found.values[0] : 0
            if (!writeTimer.running) root.draft = -1
        }
        onLoadFailed: error => {
            conf.loadedText = ""
            root.limit = 0
        }
        onSaved: {
            root.saveState = "saved"
            savedTimer.restart()
            conf.reload()
        }
        onSaveFailed: error => {
            console.warn("[Overlay FPS] Could not write", root.confPath, error)
            root.saveState = "failed"
            root.draft = -1
        }
    }

    Process {
        running: true
        command: ["bash", "-c", "command -v mangohud >/dev/null"]
        onExited: code => root.installed = code === 0
    }

    contentItem: Item {
        anchors.fill: parent
        implicitWidth: Math.round(300 * root.d)
        implicitHeight: root.installed ? column.implicitHeight : Math.round(150 * root.d)

        ColumnLayout {
            id: column
            anchors.fill: parent
            visible: root.installed
            spacing: Math.round(10 * root.d)

            // The cap itself: a figure you can type into, with its frame time.
            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(6 * root.d)

                Item {
                    Layout.fillWidth: true
                    implicitHeight: figure.implicitHeight + caption.implicitHeight

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: event => root.step(event.angleDelta.y > 0)
                    }

                    Row {
                        id: figure
                        spacing: Math.round(6 * root.d)
                        StyledTextInput {
                            id: field
                            visible: root.shown > 0 || activeFocus
                            width: Math.max(Math.round(24 * root.d), contentWidth + 2)
                            color: OverlayLook.colOnLayer1
                            selectionColor: OverlayLook.colToggle
                            selectedTextColor: OverlayLook.colOnToggle
                            font.family: OverlayLook.fontNumbers
                            font.features: ({ "tnum": 1 })
                            font.pixelSize: Math.round(OverlayLook.typeFigure * 1.3)
                            font.weight: Font.DemiBold
                            validator: IntValidator { bottom: 0; top: 1000 }
                            inputMethodHints: Qt.ImhDigitsOnly
                            selectByMouse: true
                            Accessible.name: Translation.tr("FPS limit")
                            Binding on text {
                                when: !field.activeFocus
                                value: String(root.shown)
                            }
                            onEditingFinished: {
                                const v = parseInt(field.text)
                                if (!isNaN(v) && v !== root.shown) root.set(v)
                                field.focus = false
                            }
                            Keys.onEscapePressed: field.focus = false
                            Keys.onUpPressed: root.step(true)
                            Keys.onDownPressed: root.step(false)
                        }
                        StyledText {
                            anchors.baseline: field.baseline
                            text: root.shown > 0 || field.activeFocus ? Translation.tr("fps") : Translation.tr("Uncapped")
                            color: root.shown > 0 || field.activeFocus ? OverlayLook.colSubtext : OverlayLook.colOnLayer1
                            font.family: root.shown > 0 || field.activeFocus ? OverlayLook.fontMain : OverlayLook.fontNumbers
                            font.pixelSize: root.shown > 0 || field.activeFocus ? OverlayLook.typeLabel : Math.round(OverlayLook.typeFigure * 1.3)
                            font.weight: root.shown > 0 || field.activeFocus ? Font.Medium : Font.DemiBold
                            MouseArea {
                                anchors.fill: parent
                                enabled: !field.visible
                                cursorShape: Qt.IBeamCursor
                                onClicked: {
                                    field.text = ""
                                    field.forceActiveFocus()
                                }
                            }
                        }
                    }
                    StyledText {
                        id: caption
                        anchors.top: figure.bottom
                        text: root.shown > 0 ? Translation.tr("%1 ms per frame").arg((1000 / root.shown).toFixed(1))
                            : Translation.tr("Games run as fast as they can")
                        color: OverlayLook.colSubtext
                        font.family: OverlayLook.fontMain
                        font.pixelSize: OverlayLook.typeMeta
                    }
                }

                OverlayButton {
                    Layout.alignment: Qt.AlignVCenter
                    filled: true
                    glyph: "remove"
                    enabled: root.shown > 0
                    tip: Translation.tr("Lower")
                    onClicked: root.step(false)
                }
                OverlayButton {
                    Layout.alignment: Qt.AlignVCenter
                    filled: true
                    glyph: "add"
                    enabled: root.shown < 1000
                    tip: Translation.tr("Raise")
                    onClicked: root.step(true)
                }
            }

            OverlaySegments {
                Layout.fillWidth: true
                options: root.presets
                current: root.shown
                accessibleName: Translation.tr("FPS limit")
                onPicked: value => root.set(value)
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(2 * root.d)
                spacing: Math.round(6 * root.d)
                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.refreshHz > 0 ? Translation.tr("Display %1 Hz · games run with MangoHud").arg(root.refreshHz)
                        : Translation.tr("Applies to games run with MangoHud")
                    color: OverlayLook.colFaint
                    font.family: OverlayLook.fontMain
                    font.pixelSize: OverlayLook.typeFootnote
                }
                StyledText {
                    visible: root.saveState === "saved" || root.saveState === "failed"
                    text: root.saveState === "failed" ? Translation.tr("Couldn't save") : Translation.tr("Saved")
                    color: root.saveState === "failed" ? OverlayLook.colError : OverlayLook.colSuccess
                    font.family: OverlayLook.fontMain
                    font.pixelSize: OverlayLook.typeFootnote
                    font.weight: Font.DemiBold
                }
            }
        }

        // Without MangoHud there is nothing to cap.
        Column {
            anchors.centerIn: parent
            visible: !root.installed
            spacing: Math.round(6 * root.d)
            MaterialSymbol {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "speed"
                iconSize: Math.round(28 * root.d)
                color: OverlayLook.colFaint
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Translation.tr("MangoHud isn't installed")
                color: OverlayLook.colOnLayer1
                font.family: OverlayLook.fontMain
                font.pixelSize: OverlayLook.typeBody
                font.weight: Font.DemiBold
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, Math.round(260 * root.d))
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: Translation.tr("Install it to cap a game's frame rate from here.")
                color: OverlayLook.colSubtext
                font.family: OverlayLook.fontMain
                font.pixelSize: OverlayLook.typeMeta
            }
        }
    }
}
