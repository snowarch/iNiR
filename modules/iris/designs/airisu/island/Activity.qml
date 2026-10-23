pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.iris.style
import qs.modules.iris.components
import "../components"

// AIRISU's activity page: one lacquer panel for each thing that runs (the recording, the timer, a download, a command),
// each in its subject's pigment (the recording the accent, because it is live; the timer time's; a job its own line).
// Each sets its state over its name, its figure in Dot leaning at the right, its keys after it, and how far it has come
// as a dot strip along its foot (Signal S4: progress is dots). Under them, who uses the mic, the camera or the screen.
// Everything it reads and does is the engine's.
ColumnLayout {
    id: page
    property Item island: null
    readonly property real d: Airisu.d
    spacing: Airisu.u(2)

    readonly property bool recording: page.island?.recording ?? false
    readonly property string timerKind: page.island?.timerKind ?? ""

    component Key: IrisButton {
        id: key
        property string glyph
        property color under: Airisu.ground
        property color ink: key.emphasized ? Airisu.inkOnSeal : Airisu.inkOn(key.under)
        quiet: !key.emphasized
        skinData: ({ under: key.under })
        implicitWidth: Math.round(36 * page.d)
        implicitHeight: Math.round(32 * page.d)
        MaterialSymbol {
            anchors.centerIn: parent
            text: key.glyph
            iconSize: Math.round(18 * page.d)
            fill: 1
            color: key.ink
        }
    }
    // One panel: its mark, its state over its name, its figure, its keys; how far it has come is its coat.
    component Slip: Item {
        id: slip
        property string glyph
        property color pigment: Airisu.pigment("rest")
        property string reading
        property string name
        property string figure
        property real progress: -1
        property bool indeterminate: false
        property bool running: true
        default property alias keys: keyRow.data
        property alias actions: actionRow.data
        property bool hasActions: false
        readonly property color lacquer: Airisu.lacquerOf(slip.pigment)
        readonly property color coat: Airisu.coat(slip.pigment)
        readonly property color ink: Airisu.inkOn(slip.lacquer)
        readonly property color inkSecond: ColorUtils.mix(slip.ink, slip.lacquer, 0.74) // iris-literal: second tone on lacquer
        readonly property color inkThird: ColorUtils.mix(slip.ink, slip.lacquer, 0.52)  // iris-literal: third tone on lacquer
        readonly property int pad: Airisu.u(3)
        Layout.fillWidth: true
        implicitHeight: column.implicitHeight + 2 * slip.pad

        ALacquer {
            anchors.fill: parent
            lacquer: slip.lacquer
            coat: slip.coat
            share: 0
            travel: Airisu.snap
        }
        ColumnLayout {
            id: column
            x: slip.pad
            y: slip.pad
            width: parent.width - 2 * slip.pad
            spacing: Airisu.u(2)
            RowLayout {
                id: body
                Layout.fillWidth: true
                spacing: Airisu.u(3)
                MaterialSymbol {
                    Layout.alignment: Qt.AlignVCenter
                    iconSize: Math.round(18 * page.d)
                    fill: 1
                    text: slip.glyph
                    color: slip.running ? slip.ink : slip.inkThird
                }
                Column {
                    Layout.fillWidth: true
                    spacing: 0
                    AText {
                        width: parent.width
                        size: IrisStyle.typeFootnote
                        font.weight: Font.Bold
                        color: slip.inkSecond
                        text: slip.reading
                    }
                    AText {
                        width: parent.width
                        size: IrisStyle.typeLabel
                        font.weight: Font.Bold
                        color: slip.ink
                        text: slip.name
                    }
                }
                AText {
                    visible: slip.figure.length > 0
                    Layout.alignment: Qt.AlignVCenter
                    voice: "figure"
                    lean: Airisu.lean
                    size: IrisStyle.typeDisplay
                    text: slip.figure
                    color: slip.running ? slip.ink : slip.inkThird
                }
                Row {
                    id: keyRow
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Airisu.u(1)
                }
            }
            IrisDotStrip {
                visible: slip.progress >= 0 || slip.indeterminate
                Layout.fillWidth: true
                value: Math.max(0, slip.progress)
                indeterminate: slip.indeterminate
                fillColor: slip.ink
                emptyColor: IrisStyle.unlit(slip.ink)
            }
            RowLayout {
                id: actionRow
                visible: slip.hasActions
                Layout.fillWidth: true
                spacing: Airisu.u(1)
            }
        }
    }

    Slip {
        visible: page.recording
        id: recordSlip
        glyph: "radio_button_checked"
        pigment: Airisu.pigment("live")
        reading: RecorderStatus.effectiveAudioMode === "none" ? Translation.tr("No audio")
            : RecorderStatus.effectiveAudioMode === "microphone" ? Translation.tr("Microphone")
            : RecorderStatus.effectiveAudioMode === "both" ? Translation.tr("System and microphone")
            : Translation.tr("System audio")
        name: Translation.tr("Screen recording")
        figure: page.island?.clockText(RecorderStatus.elapsedSeconds) ?? ""
        Key {
            glyph: "stop"
            emphasized: true
            under: recordSlip.lacquer
            Accessible.name: Translation.tr("Stop recording")
            onClicked: {
                Quickshell.execDetached([Directories.recordScriptPath, "--stop"])
                RecorderStatus.scheduleQuickCheck()
            }
        }
    }

    Slip {
        id: timerSlip
        visible: page.timerKind.length > 0
        readonly property bool paused: page.island?.timerPaused ?? false
        glyph: page.island?.timerGlyph ?? "timer"
        pigment: Airisu.pigment("time")
        reading: timerSlip.paused ? Translation.tr("Paused")
            : page.timerKind === "pomodoro"
                ? Translation.tr("Cycle %1 of %2").arg(TimerService.pomodoroCycle + 1).arg(TimerService.cyclesBeforeLongBreak)
            : Translation.tr("Running")
        name: page.island?.timerLabel ?? ""
        figure: page.island?.clockText(page.island?.timerSeconds ?? 0) ?? ""
        progress: page.timerKind !== "stopwatch" ? (page.island?.timerProgress ?? 0) : -1
        running: !timerSlip.paused
        Key {
            glyph: timerSlip.paused ? "play_arrow" : "pause"
            under: timerSlip.lacquer
            Accessible.name: timerSlip.paused ? Translation.tr("Resume") : Translation.tr("Pause")
            onClicked: {
                if (page.timerKind === "pomodoro") TimerService.togglePomodoro()
                else if (page.timerKind === "countdown") TimerService.toggleCountdown()
                else TimerService.toggleStopwatch()
            }
        }
        Key {
            glyph: "close"
            under: timerSlip.lacquer
            Accessible.name: Translation.tr("Stop timer")
            onClicked: {
                if (page.timerKind === "pomodoro") TimerService.stopPomodoro()
                else if (page.timerKind === "countdown") TimerService.stopCountdown()
                else TimerService.stopStopwatch()
            }
        }
    }

    Repeater {
        model: LiveActivities.list.slice().sort((a, b) => b.started - a.started)
        Slip {
            id: job
            required property var modelData
            required property int index
            readonly property real share: Number(job.modelData.progress ?? -1)
            readonly property bool ended: Boolean(job.modelData.ended)
            readonly property var appActions: job.ended ? [] : Array.from(job.modelData.actions ?? [])
            readonly property string app: String(job.modelData.app ?? "")
            glyph: job.ended ? (job.modelData.failed ? "close" : "check") : String(job.modelData.glyph ?? "bolt")
            reading: [job.app !== job.name ? job.app : "", String(job.modelData.detail ?? "")].filter(part => part.length > 0).join(" · ")
                || (job.share < 0 ? Translation.tr("Working") : Translation.tr("In progress"))
            name: String(job.modelData.title ?? "")
            figure: job.ended ? "" : job.share >= 0 ? (page.island?.percentOf(job.modelData) ?? "") : (page.island?.elapsedOf(job.modelData) ?? "")
            progress: job.ended ? (job.modelData.failed ? job.share : 1) : job.share
            indeterminate: !job.ended && job.share < 0
            running: !job.ended
            hasActions: job.appActions.length > 0
            pigment: job.modelData.failed ? Airisu.pigment("live") : Airisu.pigment("rest")
            Key {
                glyph: "close"
                under: job.lacquer
                Accessible.name: Translation.tr("Dismiss")
                onClicked: LiveActivities.dismiss(String(job.modelData.id))
            }
            actions: [
                Repeater {
                    model: job.appActions.filter(action => /^(cancel|stop|abort)$/i.test(action.id))
                    IrisButton {
                        required property var modelData
                        text: modelData.text.length > 0 ? modelData.text : Translation.tr("Stop")
                        danger: true
                        skinData: ({ under: job.lacquer })
                        onClicked: Notifications.attemptInvokeAction(job.modelData.notificationId, modelData.id)
                    }
                },
                Item { Layout.fillWidth: true },
                Repeater {
                    id: others
                    model: job.appActions.filter(action => !/^(cancel|stop|abort)$/i.test(action.id))
                    IrisButton {
                        required property var modelData
                        required property int index
                        text: modelData.text
                        emphasized: index === others.count - 1
                        skinData: ({ under: job.lacquer })
                        onClicked: Notifications.attemptInvokeAction(job.modelData.notificationId, modelData.id)
                    }
                }
            ]
        }
    }

    // Who uses the mic, the camera or the screen: a ruled list with the label voice's head, no lacquer (nothing runs
    // of its own here; it is a reading of what others do).
    ColumnLayout {
        visible: Privacy.anyActive
        Layout.fillWidth: true
        Layout.topMargin: Airisu.u(1)
        spacing: Airisu.u(2)
        IrisLabel { text: Translation.tr("In use") }
        Repeater {
            model: [
                { on: Privacy.micActive, what: Translation.tr("Microphone"), who: Privacy.micApps.join(", "), live: true },
                { on: Privacy.cameraActive, what: Translation.tr("Camera"), who: Privacy.cameraApps.join(", "), live: true }
            ].concat(Privacy.casts.map(cast => ({ on: true, what: Translation.tr("Screen"), live: false,
                who: [Privacy.castViewer(cast), Privacy.castTarget(cast)].filter(part => part.length > 0).join(" · ") })))
                .filter(row => row.on)
            RowLayout {
                id: use
                required property var modelData
                Layout.fillWidth: true
                spacing: Airisu.u(2)
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: Math.round(7 * page.d)
                    implicitHeight: implicitWidth
                    radius: width / 2
                    color: use.modelData.live ? IrisStyle.signal : IrisStyle.text
                }
                AText {
                    Layout.alignment: Qt.AlignVCenter
                    size: IrisStyle.typeLabel
                    font.weight: Font.Bold
                    text: use.modelData.what
                }
                AText {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    size: IrisStyle.typeFootnote
                    color: IrisStyle.textSecondary
                    elide: Text.ElideRight
                    text: use.modelData.who.length > 0 ? use.modelData.who : Translation.tr("An app")
                }
            }
        }
    }
}
