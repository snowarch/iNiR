pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.iris.style

// A proof of the active Design (校正刷り): every control part it skins, in each state a person reaches (rest, pointer,
// press, keyboard, inactive), drawn on stand-in hosts and saved as one image. A Design's author sees what a pointer or
// a key would show without either; `inir iris proof <file.png>`. The window sits under everything and takes no input.
PanelWindow {
    id: root
    property string target: ""
    signal done(string result)

    readonly property real d: IrisStyle.density
    readonly property int cellWidth: Math.round(176 * root.d)
    readonly property int labelWidth: Math.round(120 * root.d)
    readonly property var states: [
        { name: "rest", look: ({}) },
        { name: "pointer", look: ({ hovered: true, hoveredIndex: 1 }) },
        { name: "press", look: ({ hovered: true, down: true, pressed: true, held: true, dragging: true, engaged: true, pressedIndex: 0 }) },
        { name: "keyboard", look: ({ visualFocus: true, keyed: true, focusedIndex: 2 }) },
        { name: "inactive", look: ({ enabled: false }) }
    ]
    // Each row: a part, its size and what its host says at rest.
    readonly property var rows: [
        { part: "button", name: "button · primary", w: 96, h: 30, look: ({ emphasized: true, text: "Apply" }) },
        { part: "button", name: "button", w: 96, h: 30, look: ({ text: "Details" }) },
        { part: "button", name: "button · chosen", w: 96, h: 30, look: ({ selected: true, text: "Chosen" }) },
        { part: "button", name: "button · quiet", w: 96, h: 30, look: ({ quiet: true, text: "Restore" }) },
        { part: "button", name: "button · danger", w: 96, h: 30, look: ({ danger: true, text: "Remove" }) },
        { part: "switch", name: "switch · off", w: -1, h: -1, look: ({ on: false }) },
        { part: "switch", name: "switch · on", w: -1, h: -1, look: ({ on: true }) },
        { part: "segmented", name: "segmented", w: 156, h: 30, look: ({ options: [{ label: "Low" }, { label: "Mid" }, { label: "High" }], selectedIndex: 0 }) },
        { part: "slider", name: "slider", w: 150, h: 30, look: ({ value: 0.62 }) },
        { part: "meter", name: "level", w: 150, h: 40, look: ({ shownValue: 0.48, label: "Volume", icon: "volume_up" }) },
        { part: "meter", name: "level · muted", w: 150, h: 40, look: ({ shownValue: 0.48, muted: true, label: "Volume", icon: "volume_off" }) },
        { part: "scrubber", name: "scrubber · time", w: 150, h: 16, look: ({ shownValue: 0.4, live: true }) },
        { part: "scrubber", name: "scrubber · knob", w: 150, h: 20, look: ({ shownValue: 0.7, knob: true }) },
        { part: "ring", name: "ring", w: 34, h: 34, look: ({ progress: 0.66, stroke: 3 }) },
        { part: "cardHeader", name: "card head", w: 150, h: 46, look: ({ title: "Bluetooth", detail: "2 connected" }) },
        { part: "groupHeader", name: "group head", w: 150, h: 30, look: ({ title: "Notifications" }) }
    ]
    // The scenes a Design draws on the engine's model, each sample in the states a person brings it to. A stand-in
    // model only: nothing here reaches a service.
    readonly property real minute: 60000
    readonly property var scenes: [
        { part: "banner", name: "banner", w: Number(IrisDesign.surface("banners", "width", 380)),
            states: [{ name: "rest", look: ({}) }, { name: "pointer", look: ({ hovered: true }) }],
            samples: [
                { name: "actions", look: ({ notification: ({ notificationId: -1, appName: "Discord", appIcon: "discord", image: "",
                    summary: "Kai", urgency: "1", time: Date.now() - 1500, timer: ({ interval: 4000 }),
                    body: "are you around tonight? I pushed the new build and would love a second pair of eyes on the Island before it goes out",
                    actions: [{ identifier: "reply", text: "Reply" }, { identifier: "read", text: "Mark as read" }] }) }) },
                { name: "critical", look: ({ notification: ({ notificationId: -1, appName: "iNiR", appIcon: "", image: "",
                    summary: "Battery critically low", urgency: "2", time: Date.now() - 4 * root.minute, timer: null,
                    body: "6% left. Plug in the charger or the session will suspend.", actions: [] }) }) },
                { name: "unplaced", look: ({ notification: ({ notificationId: -1, appName: "", appIcon: "", image: "",
                    summary: "Backup finished", urgency: "0", time: Date.now() - 2 * root.minute, timer: null,
                    body: "", actions: [] }) }) }
            ] },
        { part: "osd", name: "osd", w: -1, cell: 420,
            states: [{ name: "capsule", look: ({ osd: ({ levelStyle: "capsule" }) }) }, { name: "bar", look: ({ osd: ({ levelStyle: "bar" }) }) },
                { name: "minimal", look: ({ osd: ({ levelStyle: "minimal" }) }) }],
            samples: [
                { name: "volume", look: ({ osd: ({ kind: "volume", level: true, value: 0.48, icon: "volume_down", levelFigure: true, open: true }) }) },
                { name: "muted", look: ({ osd: ({ kind: "volume", level: true, value: 0.48, muted: true, icon: "volume_off", levelFigure: true, open: true }) }) },
                { name: "brightness", look: ({ osd: ({ kind: "brightness", level: true, value: 0.8, icon: "light_mode", levelFigure: false, open: true }) }) },
                { name: "lock", single: true, look: ({ osd: ({ kind: "keyboard", keyboardIcon: "keyboard_capslock", keyboardActive: true, keyboardText: "Caps Lock on", open: true }) }) },
                { name: "layout", single: true, look: ({ osd: ({ kind: "keyboard", keyboardIcon: "language", keyboardActive: true, keyboardText: "ES", open: true }) }) },
                { name: "song", single: true, look: ({ osd: ({ kind: "media", mediaTitle: "Blue Monday", mediaArtist: "New Order", mediaAction: "next", mediaIcon: "skip_next", open: true }) }) },
                { name: "connection", single: true, look: ({ osd: ({ kind: "connection", connection: ({ icon: "headphones", title: "WH-1000XM4", detail: "Connected", tone: "", kind: "bluetooth", value: 80 }), connectionTint: IrisStyle.identity.blue, open: true }) }) },
                { name: "held back", single: true, look: ({ osd: ({ kind: "warning", warningText: "The output was too loud", open: true }) }) }
            ] }
    ]
    // A sample's look, with a state's look laid over it (one level deep, so a state can change one field of a model).
    function lookOf(sample: var, state: var): var {
        const out = Object.assign({}, sample)
        for (const key in state) {
            const a = out[key], b = state[key]
            out[key] = a && b && typeof a === "object" && typeof b === "object" ? Object.assign({}, a, b) : b
        }
        return out
    }

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "quickshell:irisProof"
    exclusionMode: ExclusionMode.Ignore
    anchors.left: true
    anchors.top: true
    implicitWidth: sheet.width
    implicitHeight: sheet.height
    color: "transparent"
    mask: Region {}

    // Every property a control host carries, so one stand-in serves every part.
    component Host: Item {
        property bool emphasized: false
        property bool danger: false
        property bool selected: false
        property bool quiet: false
        property bool hovered: false
        property bool down: false
        property bool pressed: false
        property bool held: false
        property bool dragging: false
        property bool engaged: false
        property bool visualFocus: false
        property bool keyed: false
        property string text: ""
        property bool on: false
        property var options: []
        property int selectedIndex: -1
        property int hoveredIndex: -1
        property int pressedIndex: -1
        property int focusedIndex: -1
        property bool glyphOnly: false
        property bool pictured: false
        property real value: 0
        property real shownValue: 0
        property bool vertical: false
        property bool muted: false
        property string label: ""
        property string icon: ""
        property bool knob: false
        property bool live: true
        property real progress: 0
        property real stroke: 2.5
        property color tint: IrisStyle.text
        property string title: ""
        property string detail: ""
        function slotX(i: int): real { return i * width / Math.max(1, options.length) }
    }

    Rectangle {
        id: sheet
        readonly property int pad: Math.round(32 * root.d)
        width: grid.implicitWidth + 2 * sheet.pad
        height: grid.implicitHeight + 2 * sheet.pad
        color: IrisStyle.bodySurface

        Column {
            id: grid
            x: sheet.pad
            y: sheet.pad
            spacing: Math.round(18 * root.d)
            Row {
                Item { width: root.labelWidth; height: 1 }
                Repeater {
                    model: root.states
                    Text {
                        required property var modelData
                        width: root.cellWidth
                        text: modelData.name
                        color: IrisStyle.textSecondary
                        font.family: IrisStyle.fontMono
                        font.pixelSize: IrisStyle.typeMeta
                    }
                }
            }
            Repeater {
                model: root.rows
                Row {
                    id: row
                    required property var modelData
                    Text {
                        width: root.labelWidth
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.name
                        color: IrisStyle.textSecondary
                        font.family: IrisStyle.fontMono
                        font.pixelSize: IrisStyle.typeMeta
                    }
                    Repeater {
                        model: root.states
                        Item {
                            id: cell
                            required property var modelData
                            width: root.cellWidth
                            height: Math.round(Math.max(46, row.modelData.h) * root.d)
                            Host {
                                id: host
                                x: Math.round(12 * root.d)
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.round((row.modelData.w > 0 ? row.modelData.w : Number(IrisDesign.surface("switch", "width", 76))) * root.d)
                                height: Math.round((row.modelData.h > 0 ? row.modelData.h : Number(IrisDesign.surface("switch", "height", 26))) * root.d)
                                Component.onCompleted: {
                                    for (const key in row.modelData.look) host[key] = row.modelData.look[key]
                                    for (const key in cell.modelData.look) host[key] = cell.modelData.look[key]
                                }
                                Loader {
                                    anchors.fill: parent
                                    source: IrisDesign.skin(row.modelData.part)
                                    onLoaded: item.host = host
                                }
                            }
                        }
                    }
                }
            }
            Repeater {
                model: root.scenes.filter(scene => IrisDesign.skin(scene.part).length > 0)
                Column {
                    id: scene
                    required property var modelData
                    spacing: Math.round(18 * root.d)
                    Row {
                        Item { width: root.labelWidth; height: 1 }
                        Repeater {
                            model: scene.modelData.states
                            Text {
                                required property var modelData
                                width: Math.round(((scene.modelData.cell ?? scene.modelData.w) + 24) * root.d)
                                text: modelData.name
                                color: IrisStyle.textSecondary
                                font.family: IrisStyle.fontMono
                                font.pixelSize: IrisStyle.typeMeta
                            }
                        }
                    }
                    Repeater {
                        model: scene.modelData.samples
                        Row {
                            id: sample
                            required property var modelData
                            Text {
                                width: root.labelWidth
                                text: scene.modelData.name + " · " + sample.modelData.name
                                color: IrisStyle.textSecondary
                                font.family: IrisStyle.fontMono
                                font.pixelSize: IrisStyle.typeMeta
                            }
                            Repeater {
                                model: sample.modelData.single ? scene.modelData.states.slice(0, 1) : scene.modelData.states
                                Item {
                                    id: sceneCell
                                    required property var modelData
                                    width: Math.round(((scene.modelData.cell ?? scene.modelData.w) + 24) * root.d)
                                    height: (stage.item?.implicitHeight ?? 0) + Math.round(24 * root.d)
                                    // The body the engine would give it, outlined so its bounds read.
                                    Rectangle {
                                        x: stage.x
                                        y: stage.y
                                        width: stage.width
                                        height: stage.item?.implicitHeight ?? 0
                                        color: IrisStyle.bodySurface
                                        border.width: 1
                                        border.color: IrisStyle.hairline
                                    }
                                    Loader {
                                        id: stage
                                        width: scene.modelData.w > 0 ? Math.round(scene.modelData.w * root.d) : (item?.implicitWidth ?? 0)
                                        height: item?.implicitHeight ?? 0
                                        source: IrisDesign.skin(scene.modelData.part)
                                        onLoaded: {
                                            const look = root.lookOf(sample.modelData.look, sceneCell.modelData.look)
                                            for (const key in look) item[key] = look[key]
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Timer {
        interval: 900
        running: root.target.length > 0
        onTriggered: {
            const target = root.target
            const ok = sheet.grabToImage(result => root.done(result.saveToFile(target) ? target : "could not save " + target))
            if (!ok) root.done("could not grab")
        }
    }
}
