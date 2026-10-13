pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
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
        { part: "groupHeader", name: "group head", w: 150, h: 30, look: ({ title: "Notifications" }) },
        { part: "controlTile", name: "control · on", w: 84, h: 70, look: ({ skinData: ({ shape: "tile",
            control: ({ lit: true, ready: true, glyph: "dark_mode", label: "Dark", tint: IrisStyle.accent, moduleId: "darkMode" }) }) }) },
        { part: "controlTile", name: "control · off", w: 84, h: 70, look: ({ skinData: ({ shape: "tile",
            control: ({ lit: false, ready: true, glyph: "bedtime", label: "Night light", tint: IrisStyle.accent, moduleId: "nightLight" }) }) }) },
        { part: "controlTile", name: "control · line", w: 84, h: 70, look: ({ skinData: ({ shape: "tile",
            control: ({ lit: true, ready: true, glyph: "bluetooth", label: "Bluetooth", tint: IrisStyle.identity.blue, moduleId: "bluetooth" }) }) }) },
        { part: "controlTile", name: "control · round", w: 46, h: 46, look: ({ skinData: ({ shape: "disc",
            control: ({ lit: true, ready: true, glyph: "lan", label: "Ethernet", tint: IrisStyle.accent, moduleId: "network" }) }) }) },
        { part: "controlTile", name: "control · wide", w: 160, h: 64, look: ({ skinData: ({ shape: "wide", key: 38, chevron: true, open: false,
            control: ({ lit: false, ready: true, glyph: "speaker", label: "Devices", detail: "ALC897 Analog", tint: IrisStyle.accent, moduleId: "devices" }) }) }) }
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
            ] },
        { part: "session", name: "session", w: -1, cell: 680,
            states: [{ name: "rest", look: ({}) }],
            samples: [
                { name: "rest", look: ({ shown: true, host: root.sessionHost({}) }) },
                { name: "keyboard", look: ({ shown: true, host: root.sessionHost({ focusIndex: 2, keyboardNavigation: true }) }) },
                { name: "asks again", look: ({ shown: true, host: root.sessionHost({ focusIndex: 2, keyboardNavigation: true, pending: "poweroff" }) }) },
                { name: "held", look: ({ shown: true, host: root.sessionHost({ held: ({ index: 1, ink: 0.55 }) }) }) }
            ] },
        // The lock's parts over the lock's dark scene; the sign-in on the lock's plate, as the engine lays it.
        { part: "lockSignIn", name: "sign in", w: -1, cell: 400, media: true, plate: true,
            states: [{ name: "rest", look: ({}) }],
            samples: [
                { name: "waiting", look: ({ host: root.lockHost({}) }) },
                { name: "focused", look: ({ host: root.lockHost({ focused: true }) }) },
                { name: "typed", look: ({ host: root.lockHost({ focused: true, typed: 7, cursor: 7 }) }) },
                { name: "selected", look: ({ host: root.lockHost({ focused: true, typed: 7, cursor: 7, selectionStart: 0, selectionEnd: 7 }) }) },
                { name: "keyboard", look: ({ host: root.lockHost({ focused: true, typed: 3, cursor: 3, oskVisible: true }) }) },
                { name: "checking", look: ({ host: root.lockHost({ typed: 7, cursor: 7, context: ({ unlockInProgress: true }), hint: Translation.tr("Unlocking…") }) }) },
                { name: "refused", look: ({ host: root.lockHost({ focused: true, context: ({ showFailure: true }), hint: Translation.tr("Incorrect password") }) }) },
                { name: "fingerprint", look: ({ host: root.lockHost({ focused: true, context: ({ fingerprintsConfigured: true }) }) }) },
                { name: "field alone", look: ({ host: root.lockHost({ focused: true, typed: 2, cursor: 2, entry: ({ avatar: false, name: false }) }) }) }
            ] },
        { part: "lockClock", name: "lock clock", w: -1, cell: 400, media: true,
            states: [{ name: "rest", look: ({}) }],
            samples: [
                { name: "date over time", look: ({ host: root.clockHost({}) }) },
                { name: "accent", look: ({ host: root.clockHost({ colour: IrisStyle.accentOnMedia, timeWeight: 800 }) }) },
                { name: "12 hour, long name", look: ({ host: root.clockHost({ timeText: "11:58 PM", lockedText: "11:41 PM", machine: "workstation-studio-02" }) }) },
                { name: "time alone", look: ({ host: root.clockHost({ showDate: false }) }) },
                { name: "small", look: ({ host: root.clockHost({ timeSize: 50, showDate: false }) }) }
            ] },
        { part: "lockChip", name: "glance", w: -1, cell: 220, media: true, plate: true,
            states: [{ name: "rest", look: ({}) }],
            samples: [
                { name: "weather", look: ({ host: ({ glyph: "cloud", figure: "8°", ruby: "Pergamino", tint: IrisStyle.onMedia, battery: -1 }) }) },
                { name: "event", look: ({ host: ({ glyph: "event", figure: "", ruby: "In 20 min", headline: "Stand-up", tint: IrisStyle.identity.red, battery: -1 }) }) },
                { name: "battery low", look: ({ host: ({ glyph: "", figure: "18%", ruby: Translation.tr("Battery"), tint: IrisStyle.dangerOnMedia, battery: 0.18 }) }) }
            ] },
        { part: "mediaCard", name: "player · lock", w: 380, media: true, plate: true,
            states: [{ name: "rest", look: ({}) }],
            samples: [
                { name: "playing", look: ({ host: root.mediaHost({ overMedia: true }) }) },
                { name: "stream", look: ({ host: root.mediaHost({ overMedia: true, liveStream: true, hasTimeline: false }) }) },
                { name: "nothing", look: ({ host: root.mediaHost({ overMedia: true, hasPlayer: false, hasTimeline: false, emptyDetail: Translation.tr("Your music appears here") }) }) }
            ] },
        { part: "mediaCard", name: "player · card", w: 360,
            states: [{ name: "rest", look: ({}) }],
            samples: [
                { name: "playing", look: ({ host: root.mediaHost({}) }) },
                { name: "folded", look: ({ host: root.mediaHost({ compact: true }) }) },
                { name: "offer", look: ({ host: root.mediaHost({ hasPlayer: false, hasTimeline: false, emptyDetail: "Open Spotify" }) }) }
            ] },
        { part: "lockActivity", name: "activity", w: 380, media: true, plate: true,
            states: [{ name: "rest", look: ({}) }],
            samples: [
                { name: "recording", look: ({ host: ({ live: true, glyph: "radio_button_checked", label: Translation.tr("Recording"), figure: "4:12", progress: -1 }) }) },
                { name: "timer", look: ({ host: ({ glyph: "hourglass_top", label: Translation.tr("Timer"), figure: "12:40", progress: 0.35 }) }) },
                { name: "paused", look: ({ host: ({ glyph: "pause", label: Translation.tr("Focus"), figure: "18:02", progress: 0.6 }) }) }
            ] }
    ]
    // Stand-ins for the lock's sign-in and clock blocks: how much is typed, never a password; nothing reaches PAM.
    function lockHost(state: var): var {
        const context = Object.assign({ unlockInProgress: false, showFailure: false, fingerprintsConfigured: false }, state.context ?? {})
        return Object.assign({ entry: ({ avatar: true, name: true, hint: true, width: 248 }), editing: false, oskVisible: false,
            typed: 0, cursor: 0, selectionStart: 0, selectionEnd: 0, focused: false, still: true, unit: root.d, textScale: 1,
            displayName: SystemInfo.displayName || SystemInfo.username, userName: SystemInfo.username, hint: "",
            toggleKeyboard: () => {}, submit: () => {} }, state, { context: context })
    }
    function clockHost(state: var): var {
        return Object.assign({ timeSize: 4 * IrisStyle.typeDisplay, showDate: true, dateText: Translation.locale.toString(DateTime.clock.date, "dddd, d MMMM"),
            timeText: DateTime.time, family: IrisStyle.fontNumbers, timeWeight: 700, tracking: -2, colour: IrisStyle.onMedia,
            lockedAt: new Date(Date.now() - 17 * 60000), lockedText: Qt.formatDateTime(new Date(Date.now() - 17 * 60000), "HH:mm"),
            machine: SystemInfo.hostname, context: null }, state)
    }
    // A stand-in for the player card: a record that plays nothing (its keys do nothing either).
    function mediaHost(state: var): var {
        const playback = { effectiveTitle: "Blue Monday '88", effectiveArtist: "New Order", effectiveIsPlaying: true,
            effectiveLength: 251, effectivePosition: 97, effectiveCanSeek: true, effectiveCanGoNext: true, effectiveCanGoPrevious: true,
            displayedArtFilePath: state.hasPlayer === false ? "" : String(MprisController.activePlayer?.trackArtUrl ?? ""),
            togglePlaying: () => {}, next: () => {}, previous: () => {}, seek: () => {} }
        return Object.assign({ playback: playback, player: ({ trackAlbum: "Substance" }), hasPlayer: true, liveStream: false, hasTimeline: true,
            compact: false, overMedia: false, showPlayers: false, headerReserve: 0, emptyDetail: "", emptyIcon: "", offersOpen: true }, state)
    }
    // A stand-in for the session screen's stage: its actions as the engine lists them, nothing that runs.
    function sessionHost(state: var): var {
        const actions = [
            { id: "suspend", icon: "bedtime", label: Translation.tr("Sleep"), confirm: false },
            { id: "reboot", icon: "restart_alt", label: Translation.tr("Restart"), confirm: true },
            { id: "poweroff", icon: "power_settings_new", label: Translation.tr("Shut Down"), confirm: true },
            { id: "lock", icon: "lock", label: Translation.tr("Lock"), confirm: false },
            { id: "logout", icon: "logout", label: Translation.tr("Log Out"), confirm: true }
        ]
        const pending = state.pending ?? ""
        return Object.assign({ actions: actions, focusIndex: 0, keyboardNavigation: false, pending: "", held: null,
            pendingAction: actions.find(action => action.id === pending) ?? null, trigger: () => {}, commit: () => {} }, state)
    }
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
        property var skinData: null
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
                                    // A lock part stands on the lock's dark scene.
                                    Rectangle {
                                        visible: scene.modelData.media ?? false
                                        anchors.fill: parent
                                        color: IrisStyle.darkSurfaceOpaque
                                    }
                                    // The body the engine would give it, outlined so its bounds read; a lock part's plate.
                                    Rectangle {
                                        visible: !(scene.modelData.media ?? false)
                                        x: stage.x
                                        y: stage.y
                                        width: stage.width
                                        height: stage.item?.implicitHeight ?? 0
                                        color: IrisStyle.bodySurface
                                        border.width: 1
                                        border.color: IrisStyle.hairline
                                    }
                                    Loader {
                                        x: stage.x
                                        y: stage.y
                                        width: stage.width
                                        height: stage.item?.implicitHeight ?? 0
                                        active: scene.modelData.plate ?? false
                                        source: IrisDesign.skin("lockPlate")
                                        onLoaded: item.host = ({ material: "tint", outline: true })
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
