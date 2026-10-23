pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// The expanded Live Activities (DESIGN.md S6): every running thing as one block, what it is in the Read voice, its
// one figure, its progress, its controls as capsules (secondary left, primary right, destructive in signal). Under
// them, who is using the mic, the camera or the screen.
ColumnLayout {
    id: page
    required property Item island
    readonly property real d: IrisStyle.density
    spacing: 0

    // Jobs that just ended stay a moment (LiveActivities.retireMs) so the page does not jump when one finishes.
    readonly property var jobs: LiveActivities.list.slice().sort((a, b) => b.started - a.started)
    readonly property bool timing: page.island.timerKind.length > 0
    readonly property bool privacy: Privacy.anyActive
    // Under Nothing: one signal, dots, Dot figures. Under Apple each block wears its colour and a capsule bar.
    readonly property bool nothing: page.island.nothingLook

    component Block: ColumnLayout {
        id: block
        property string title: ""
        property string meta: ""
        property string figure: ""
        property int roll: 0
        property bool live: false
        property bool failed: false
        property real progress: -1
        property bool indeterminate: false
        property bool first: false
        property color tint: IrisStyle.accent
        readonly property color ink: block.failed ? IrisStyle.danger : page.nothing ? IrisStyle.text : block.tint
        default property alias controls: chips.data
        Layout.fillWidth: true
        spacing: Math.round(10 * page.d)

        Rectangle {
            visible: !block.first
            Layout.fillWidth: true
            Layout.topMargin: Math.round(4 * page.d)
            Layout.bottomMargin: Math.round(4 * page.d)
            implicitHeight: 1
            color: IrisStyle.hairline
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(12 * page.d)
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: Math.round(2 * page.d)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(8 * page.d)
                    Rectangle {
                        visible: block.live
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: Math.round(7 * page.d)
                        implicitHeight: implicitWidth
                        radius: width / 2
                        color: page.nothing ? IrisStyle.signal : block.tint
                    }
                    IrisText {
                        Layout.fillWidth: true
                        text: block.title
                        color: block.failed ? IrisStyle.signalInk : IrisStyle.text
                        font.pixelSize: IrisStyle.typeHeadline
                        font.weight: IrisStyle.weight(Font.DemiBold)
                        elide: Text.ElideRight
                    }
                }
                IrisText {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: block.meta
                    role: IrisText.Meta
                    elide: Text.ElideRight
                }
            }
            IrisDotText {
                visible: block.figure.length > 0
                Layout.alignment: Qt.AlignVCenter
                text: block.figure
                direction: block.roll
                pixelSize: IrisStyle.typeDotM
                color: block.ink
            }
        }
        Rectangle {
            id: bar
            visible: !page.nothing && (block.progress >= 0 || block.indeterminate)
            Layout.fillWidth: true
            implicitHeight: Math.round(6 * page.d)
            radius: IrisStyle.capsule(height)
            color: IrisStyle.fillHover
            clip: block.indeterminate
            Rectangle {
                height: parent.height
                radius: parent.radius
                color: block.ink
                width: block.indeterminate ? parent.width * 0.3 : parent.width * Math.max(0, Math.min(1, block.progress))
                Behavior on width { enabled: !block.indeterminate; NumberAnimation { duration: IrisStyle.duration(240); easing.type: Easing.OutCubic } }
                // A job that can't say how far it is: a short capsule travels the track.
                NumberAnimation on x {
                    running: bar.visible && block.indeterminate && IrisStyle.motionEnabled
                    from: -bar.width * 0.3
                    to: bar.width
                    duration: 1400
                    loops: Animation.Infinite
                }
            }
        }
        IrisDotStrip {
            visible: page.nothing && (block.progress >= 0 || block.indeterminate)
            Layout.fillWidth: true
            value: Math.max(0, block.progress)
            indeterminate: block.indeterminate
            fillColor: block.failed ? IrisStyle.signal : IrisStyle.text
        }
        RowLayout {
            id: chips
            Layout.fillWidth: true
            spacing: Math.round(8 * page.d)
        }
    }
    component Gap: Item { Layout.fillWidth: true }
    component Use: RowLayout {
        id: use
        property bool active: false
        property bool alarm: true
        property color tint: IrisStyle.text
        property string what: ""
        property string who: ""
        default property alias controls: useControls.data
        visible: use.active
        Layout.fillWidth: true
        spacing: Math.round(10 * page.d)
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Math.round(7 * page.d)
            implicitHeight: implicitWidth
            radius: width / 2
            color: page.nothing ? (use.alarm ? IrisStyle.signal : IrisStyle.text) : use.tint
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Math.round(2 * page.d)
            IrisText {
                Layout.fillWidth: true
                text: use.what
                font.pixelSize: IrisStyle.typeBody
                font.weight: IrisStyle.weight(Font.Medium)
                elide: Text.ElideRight
            }
            IrisText {
                Layout.fillWidth: true
                text: use.who.length > 0 ? use.who : Translation.tr("An app")
                role: IrisText.Meta
                elide: Text.ElideRight
            }
        }
        RowLayout { id: useControls; spacing: Math.round(8 * page.d) }
    }


    Block {
        visible: page.island.recording
        first: true
        live: true
        tint: IrisStyle.danger
        title: Translation.tr("Screen recording")
        meta: RecorderStatus.effectiveAudioMode === "none" ? Translation.tr("No audio")
            : RecorderStatus.effectiveAudioMode === "microphone" ? Translation.tr("Microphone")
            : RecorderStatus.effectiveAudioMode === "both" ? Translation.tr("System and microphone")
            : Translation.tr("System audio")
        figure: page.island.clockText(RecorderStatus.elapsedSeconds)
        roll: 1
        Gap {}
        IrisButton {
            text: Translation.tr("Stop")
            emphasized: true
            onClicked: {
                Quickshell.execDetached([Directories.recordScriptPath, "--stop"])
                RecorderStatus.scheduleQuickCheck()
            }
        }
    }

    Block {
        visible: page.timing
        first: !page.island.recording
        live: !page.island.timerPaused
        tint: IrisStyle.secondaryAccent
        title: page.island.timerLabel
        meta: page.island.timerPaused ? Translation.tr("Paused")
            : page.island.timerKind === "pomodoro"
                ? Translation.tr("Cycle %1 of %2").arg(TimerService.pomodoroCycle + 1).arg(TimerService.cyclesBeforeLongBreak)
            : Translation.tr("Running")
        figure: page.island.clockText(page.island.timerSeconds)
        roll: page.island.timerKind === "stopwatch" ? 1 : -1
        progress: page.island.timerKind === "stopwatch" ? -1 : page.island.timerProgress
        IrisButton {
            text: page.island.timerPaused ? Translation.tr("Resume") : Translation.tr("Pause")
            onClicked: {
                if (page.island.timerKind === "pomodoro") TimerService.togglePomodoro()
                else if (page.island.timerKind === "countdown") TimerService.toggleCountdown()
                else TimerService.toggleStopwatch()
            }
        }
        IrisButton {
            text: Translation.tr("Stop")
            danger: true
            onClicked: {
                if (page.island.timerKind === "pomodoro") TimerService.stopPomodoro()
                else if (page.island.timerKind === "countdown") TimerService.stopCountdown()
                else TimerService.stopStopwatch()
            }
        }
    }

    Repeater {
        model: page.jobs
        Block {
            id: job
            required property var modelData
            required property int index
            readonly property real value: Number(job.modelData.progress ?? -1)
            readonly property bool ended: Boolean(job.modelData.ended)
            readonly property var actions: Array.from(job.modelData.actions ?? [])
            readonly property string app: String(job.modelData.app ?? "")
            first: job.index === 0 && !page.island.recording && !page.timing
            failed: Boolean(job.modelData.failed)
            tint: IrisStyle.identityColor(String(job.modelData.tint ?? "lavender"))
            title: String(job.modelData.title ?? "")
            meta: [job.app !== job.title ? job.app : "", String(job.modelData.detail ?? "")]
                .filter(part => part.length > 0).join(" · ")
            figure: job.ended ? "" : job.value >= 0 ? page.island.percentOf(job.modelData) + (page.nothing ? "" : "%")
                : page.island.elapsedOf(job.modelData)
            roll: 1
            progress: job.ended ? (job.failed ? job.value : 1) : job.value
            indeterminate: !job.ended && job.value < 0
            // The app's own buttons (Stop, Show in folder): stopping ones in signal on the left, the rest on the right,
            // the last of them primary.
            Repeater {
                model: job.ended ? [] : job.actions.filter(action => /^(cancel|stop|abort)$/i.test(action.id))
                IrisButton {
                    required property var modelData
                    text: modelData.text.length > 0 ? modelData.text : Translation.tr("Stop")
                    danger: true
                    onClicked: Notifications.attemptInvokeAction(job.modelData.notificationId, modelData.id)
                }
            }
            IrisButton {
                text: job.ended ? Translation.tr("Dismiss") : Translation.tr("Hide")
                onClicked: LiveActivities.dismiss(String(job.modelData.id))
            }
            Gap {}
            Repeater {
                id: others
                model: job.ended ? [] : job.actions.filter(action => !/^(cancel|stop|abort)$/i.test(action.id))
                IrisButton {
                    required property var modelData
                    required property int index
                    text: modelData.text
                    emphasized: index === others.count - 1
                    onClicked: Notifications.attemptInvokeAction(job.modelData.notificationId, modelData.id)
                }
            }
        }
    }

    // Who is listening or watching. Mic and camera are the signal; the screen is ink, as in the compact marks.
    ColumnLayout {
        visible: page.privacy
        Layout.fillWidth: true
        spacing: Math.round(10 * page.d)
        Rectangle {
            visible: page.island.recording || page.timing || page.jobs.length > 0
            Layout.fillWidth: true
            Layout.topMargin: Math.round(4 * page.d)
            Layout.bottomMargin: Math.round(4 * page.d)
            implicitHeight: 1
            color: IrisStyle.hairline
        }
        IrisLabel { text: Translation.tr("In use") }

        Use {
            active: Privacy.micActive
            tint: IrisStyle.identity.orange
            what: Translation.tr("Microphone")
            who: Privacy.micApps.join(", ")
            IrisButton {
                text: Audio.micMuted ? Translation.tr("Unmute") : Translation.tr("Mute")
                selected: Audio.micMuted
                onClicked: Audio.toggleMicMute()
            }
        }
        Use {
            active: Privacy.cameraActive
            tint: IrisStyle.identity.green
            what: Translation.tr("Camera")
            who: Privacy.cameraApps.join(", ")
        }
        Repeater {
            model: Privacy.casts
            Use {
                id: cast
                required property var modelData
                active: true
                alarm: false
                what: Translation.tr("Screen")
                who: [Privacy.castViewer(cast.modelData), Privacy.castTarget(cast.modelData)]
                    .filter(part => part.length > 0).join(" · ")
                IrisButton {
                    // niri can only stop PipeWire casts; a screencopy one is stopped by the app that runs it.
                    visible: cast.modelData.kind === "PipeWire"
                    text: Translation.tr("Stop")
                    danger: true
                    onClicked: NiriService.stopCast(cast.modelData.session_id)
                }
            }
        }
    }
}
