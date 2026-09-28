pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.widgets

Item {
    id: root
    // A block the person resized is drawn scaled; native glyphs smear under a transform, curves do not.
    function renderFor(block: string): int {
        return Math.abs(IrisLockOptions.scaleOf(block) - 1) < 0.001 ? Text.NativeRendering : Text.CurveRendering
    }

    required property var context
    property Item frost: null
    property bool editing: false
    readonly property string selected: GlobalStates.irisLockSelection
    property Item input: null
    property bool dragging: false
    property bool peeking: false
    property rect selectedRect: Qt.rect(0, 0, 0, 0)
    readonly property bool arranging: root.editing && !root.peeking
    property bool onCentreX: false
    property bool onCentreY: false
    readonly property real d: IrisStyle.density
    readonly property real typeScale: IrisStyle.typeScale * IrisLockOptions.typeScale
    readonly property real margin: Math.round(56 * root.d)

    signal submitted()
    signal relayout()
    onWidthChanged: root.relayout()
    onHeightChanged: root.relayout()

    // A plate cuts its own piece out of one frosted copy of the scene, so glass stays
    // glass over a playing video without a blur pass per plate.
    component Glass: Item {
        id: glass
        property real radius: IrisStyle.radiusPlate
        property bool outline: false
        property point at: Qt.point(0, 0)
        property real zoom: 1
        readonly property string material: IrisLockOptions.material
        function sync(): void {
            const origin = glass.mapToItem(root, 0, 0)
            const unit = glass.mapToItem(root, 1, 0)
            glass.zoom = Math.max(0.01, unit.x - origin.x)
            glass.at = origin
        }
        Component.onCompleted: Qt.callLater(glass.sync)
        onWidthChanged: Qt.callLater(glass.sync)
        onHeightChanged: Qt.callLater(glass.sync)
        Connections {
            target: root
            function onRelayout(): void { Qt.callLater(glass.sync) }
        }
        ClippingRectangle {
            anchors.fill: parent
            visible: glass.material === "glass" && root.frost !== null
            radius: glass.radius
            color: "transparent"
            ShaderEffectSource {
                sourceItem: root.frost
                x: -glass.at.x / glass.zoom
                y: -glass.at.y / glass.zoom
                width: root.width / glass.zoom
                height: root.height / glass.zoom
                live: true
            }
        }
        Rectangle {
            anchors.fill: parent
            visible: glass.material !== "none" || glass.outline
            radius: glass.radius
            color: glass.material === "glass" ? IrisStyle.mediaGlass
                : glass.material === "tint" ? IrisStyle.mediaScrim : "transparent"
            border.width: glass.material !== "tint" ? 1 : 0
            border.color: glass.material === "none" ? IrisStyle.onMediaFill : IrisStyle.mediaHairline
        }
    }

    function clockText(total: real): string {
        const s = Math.max(0, Math.floor(total))
        const h = Math.floor(s / 3600)
        const m = Math.floor((s % 3600) / 60)
        const sec = String(s % 60).padStart(2, "0")
        return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + sec : m + ":" + sec
    }

    function nearestZone(x: real, y: real): string {
        let best = ""
        let distance = Number.POSITIVE_INFINITY
        for (const zone of IrisLockOptions.zones) {
            const a = IrisLockOptions.zoneAnchor(zone, root.width, root.height, root.margin)
            const away = Math.hypot(x - a.x, y - a.y)
            if (away < distance) { distance = away; best = zone }
        }
        return distance < Math.round(140 * root.d) ? best : ""
    }

    component Reading: Row {
        id: reading
        property string glyph: ""
        property string label: ""
        property real typeScale: 1
        property real unit: 1
        spacing: Math.round(5 * reading.unit)
        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            text: reading.glyph
            iconSize: Math.round(17 * reading.unit)
            color: IrisStyle.onMediaSecondary
        }
        IrisText {
            anchors.verticalCenter: parent.verticalCenter
            text: reading.label
            color: IrisStyle.onMediaSecondary
            font.pixelSize: Math.round(13 * reading.typeScale)
            font.weight: IrisStyle.weight(Font.Medium)
        }
    }

    component ActivityPlate: Item {
        id: plate
        property bool shown: false
        property string glyph: ""
        property color tint: IrisStyle.text
        property string label: ""
        property string figure: ""
        property bool countDown: false
        property real progress: -1
        visible: plate.shown
        implicitWidth: Math.round(380 * root.d)
        implicitHeight: plate.shown ? Math.round(64 * root.d) : 0

        Glass {
            anchors.fill: parent
            radius: IrisStyle.radiusPlate
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12 * root.d
            anchors.rightMargin: 20 * root.d
            spacing: 12 * root.d
            Rectangle {
                Layout.preferredWidth: Math.round(40 * root.d)
                Layout.preferredHeight: Layout.preferredWidth
                radius: width / 2
                color: IrisStyle.tintFill(plate.tint)
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: plate.glyph
                    fill: 1
                    iconSize: 20 * root.d
                    color: plate.tint
                }
            }
            IrisText {
                Layout.fillWidth: true
                text: plate.label
                color: IrisStyle.onMedia
                font.pixelSize: Math.round(15 * root.typeScale)
                font.weight: IrisStyle.weight(Font.DemiBold)
                elide: Text.ElideRight
            }
            IrisNumber {
                text: plate.figure
                countDown: plate.countDown
                color: plate.tint
                pixelSize: Math.round(26 * root.typeScale)
                weight: Font.Bold
                letterSpacing: -1
            }
        }
        Rectangle {
            visible: plate.progress >= 0
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 22 * root.d
            anchors.bottomMargin: 7 * root.d
            width: (parent.width - 44 * root.d) * Math.max(0, Math.min(1, plate.progress))
            height: Math.max(2, 2 * root.d)
            radius: height / 2
            color: plate.tint
        }
    }

    component BlockBody: Item {
        id: body
        property string blockId: ""
        readonly property var entry: {
            Config.revision
            return IrisLockOptions.entry(body.blockId)
        }
        readonly property real blockScale: IrisLockOptions.scaleOf(body.blockId)
        readonly property bool on: Boolean(body.entry?.enable ?? false)
        readonly property bool picked: root.editing && root.selected === body.blockId
        implicitWidth: Math.max(slot.implicitWidth * body.blockScale, root.arranging ? Math.round(120 * root.d) : 0)
        implicitHeight: Math.max(slot.implicitHeight * body.blockScale, root.arranging ? Math.round(34 * root.d) : 0)
        visible: body.on || root.arranging
        opacity: body.on || !root.arranging ? 1 : 0.34
        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
        onPickedChanged: if (body.picked) root.selectedRect = Qt.rect(body.x, body.y, body.width, body.height)
        onXChanged: { root.relayout(); if (body.picked) root.selectedRect = Qt.rect(body.x, body.y, body.width, body.height) }
        onYChanged: { root.relayout(); if (body.picked) root.selectedRect = Qt.rect(body.x, body.y, body.width, body.height) }
        onBlockScaleChanged: root.relayout()

        Loader {
            id: slot
            anchors.centerIn: parent
            scale: body.blockScale
            sourceComponent: body.blockId === "clock" ? clockBlock
                : body.blockId === "glance" ? glanceBlock
                : body.blockId === "media" ? mediaBlock
                : body.blockId === "activity" ? activityBlock
                : body.blockId === "session" ? sessionBlock
                : statusBlock
        }

        Rectangle {
            visible: root.arranging
            anchors.fill: parent
            anchors.margins: -Math.round(8 * root.d)
            radius: IrisStyle.radiusPlate
            color: body.picked ? IrisStyle.tintFill(IrisStyle.accent)
                : grip.containsMouse ? IrisStyle.onMediaFill : "transparent"
            border.width: body.picked || grip.containsMouse ? Math.max(1, Math.round(1.5 * root.d)) : 0
            border.color: body.picked ? IrisStyle.accent : IrisStyle.onMediaFillHover
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
        }
        Row {
            id: chrome
            visible: root.arranging && (body.picked || grip.containsMouse)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: Math.round(14 * root.d)
            spacing: Math.round(4 * root.d)
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: chromeLabel.implicitWidth + Math.round(16 * root.d)
                height: Math.round(24 * root.d)
                radius: height / 2
                color: body.picked ? IrisStyle.accent : IrisStyle.mediaScrim
                IrisText {
                    id: chromeLabel
                    anchors.centerIn: parent
                    text: IrisLockOptions.labelOf(body.blockId)
                    color: body.picked ? IrisStyle.onAccent : IrisStyle.onMedia
                    font.pixelSize: IrisStyle.typeFootnote
                    font.weight: IrisStyle.weight(Font.DemiBold)
                }
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(24 * root.d)
                height: width
                radius: width / 2
                color: powerArea.containsMouse ? IrisStyle.onMediaFillHover : IrisStyle.mediaScrim
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: body.on ? "visibility" : "visibility_off"
                    iconSize: Math.round(14 * root.d)
                    color: body.on ? IrisStyle.onMedia : IrisStyle.onMediaSecondary
                }
                MouseArea {
                    id: powerArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Show this block")
                    onClicked: IrisLockOptions.toggle(body.blockId)
                }
            }
        }

        MouseArea {
            id: grip
            anchors.fill: parent
            anchors.margins: -Math.round(8 * root.d)
            enabled: root.arranging
            visible: root.arranging
            hoverEnabled: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            property point origin: Qt.point(0, 0)
            property bool moved: false
            onPressed: mouse => {
                GlobalStates.irisLockSelection = body.blockId
                grip.origin = Qt.point(mouse.x, mouse.y)
                grip.moved = false
            }
            onPositionChanged: mouse => {
                if (!grip.pressed) return
                if (!grip.moved && Math.hypot(mouse.x - grip.origin.x, mouse.y - grip.origin.y) < 6) return
                if (!grip.moved) root.dragging = true
                grip.moved = true
                const scene = grip.mapToItem(root, mouse.x, mouse.y)
                // A block never leaves the screen: the centre is held half a block in.
                const halfW = body.width / 2
                const halfH = body.height / 2
                let cx = Math.max(halfW, Math.min(root.width - halfW, scene.x - grip.origin.x + grip.width / 2))
                let cy = Math.max(halfH, Math.min(root.height - halfH, scene.y - grip.origin.y + grip.height / 2))
                const pull = (mouse.modifiers & Qt.ShiftModifier) ? 0 : Math.round(10 * root.d)
                root.onCentreX = Math.abs(cx - root.width / 2) < pull
                root.onCentreY = Math.abs(cy - root.height / 2) < pull
                if (root.onCentreX) cx = root.width / 2
                if (root.onCentreY) cy = root.height / 2
                IrisLockOptions.place(body.blockId, "free", cx / Math.max(1, root.width), cy / Math.max(1, root.height))
            }
            onReleased: mouse => {
                root.dragging = false
                root.onCentreX = false
                root.onCentreY = false
                if (!grip.moved) return
                if (mouse.modifiers & Qt.ShiftModifier) return
                const centre = body.mapToItem(root, body.width / 2, body.height / 2)
                const zone = root.nearestZone(centre.x, centre.y)
                if (zone.length > 0) IrisLockOptions.write(body.blockId, { zone: zone })
            }
            onCanceled: { root.dragging = false; root.onCentreX = false; root.onCentreY = false }
        }
    }

    property var zoneExtents: ({})
    function noteZone(zone: string, top: real, bottom: real): void {
        const current = root.zoneExtents[zone]
        if (current && current.top === top && current.bottom === bottom) return
        const next = Object.assign({}, root.zoneExtents)
        next[zone] = { top: top, bottom: bottom }
        root.zoneExtents = next
    }
    // A middle zone settles between the zones above and below it instead of running into them.
    function middleY(zone: string, height: real): real {
        const above = zone === "left" ? "topLeft" : zone === "right" ? "topRight" : "top"
        const below = zone === "left" ? "bottomLeft" : zone === "right" ? "bottomRight" : "bottom"
        const gap = Math.round(24 * root.d)
        const ceiling = (root.zoneExtents[above]?.bottom ?? 0) + gap
        const floor = (root.zoneExtents[below]?.top ?? root.height) - gap
        let y = root.height / 2 - height / 2
        if (y + height > floor) y = floor - height
        if (y < ceiling) y = ceiling
        return y
    }

    Repeater {
        model: IrisLockOptions.zones
        delegate: Column {
            id: zoneColumn
            required property string modelData
            readonly property bool middle: ["center", "left", "right"].includes(zoneColumn.modelData)
            readonly property var seat: IrisLockOptions.zoneAnchor(zoneColumn.modelData, root.width, root.height, root.margin)
            readonly property var members: {
                Config.revision
                return IrisLockOptions.shown(zoneColumn.modelData, root.arranging)
            }
            spacing: Math.round(18 * root.d)
            onXChanged: root.relayout()
            onYChanged: root.relayout()
            x: Math.round(zoneColumn.seat.align === Qt.AlignLeft ? zoneColumn.seat.x
                : zoneColumn.seat.align === Qt.AlignRight ? zoneColumn.seat.x - width
                : zoneColumn.seat.x - width / 2)
            y: Math.round(zoneColumn.middle ? root.middleY(zoneColumn.modelData, height)
                : zoneColumn.seat.up ? zoneColumn.seat.y - height : zoneColumn.seat.y)
            function note(): void {
                if (zoneColumn.middle) return
                root.noteZone(zoneColumn.modelData, zoneColumn.members.length > 0 ? zoneColumn.y : root.height,
                    zoneColumn.members.length > 0 ? zoneColumn.y + zoneColumn.height : 0)
            }
            onHeightChanged: Qt.callLater(zoneColumn.note)
            onMembersChanged: Qt.callLater(zoneColumn.note)
            Component.onCompleted: Qt.callLater(zoneColumn.note)
            Repeater {
                model: ScriptModel { values: zoneColumn.members }
                delegate: BlockBody {
                    required property string modelData
                    blockId: modelData
                    x: Math.round(zoneColumn.seat.align === Qt.AlignLeft ? 0
                        : zoneColumn.seat.align === Qt.AlignRight ? zoneColumn.width - width
                        : (zoneColumn.width - width) / 2)
                }
            }
        }
    }

    Repeater {
        model: ScriptModel {
            values: {
                Config.revision
                return IrisLockOptions.loose(root.arranging)
            }
        }
        delegate: BlockBody {
            id: loose
            required property string modelData
            blockId: modelData
            x: Math.round(Number(loose.entry?.fx ?? 0.5) * root.width - width / 2)
            y: Math.round(Number(loose.entry?.fy ?? 0.5) * root.height - height / 2)
        }
    }

    Rectangle {
        visible: root.dragging && root.onCentreX
        width: Math.max(1, Math.round(root.d))
        height: root.height
        x: Math.round(root.width / 2 - width / 2)
        color: IrisStyle.accent
        opacity: 0.7
    }
    Rectangle {
        visible: root.dragging && root.onCentreY
        height: Math.max(1, Math.round(root.d))
        width: root.width
        y: Math.round(root.height / 2 - height / 2)
        color: IrisStyle.accent
        opacity: 0.7
    }

    // Where a dropped block would settle. Only while carrying one, and the nearest
    // seat swells so the snap is a promise instead of a surprise.
    Repeater {
        model: root.dragging && root.arranging ? IrisLockOptions.zones : []
        delegate: Rectangle {
            id: seatRing
            required property string modelData
            readonly property var seat: IrisLockOptions.zoneAnchor(seatRing.modelData, root.width, root.height, root.margin)
            readonly property bool hot: root.nearestZone(root.selectedRect.x + root.selectedRect.width / 2,
                root.selectedRect.y + root.selectedRect.height / 2) === seatRing.modelData
            width: Math.round((seatRing.hot ? 34 : 18) * root.d)
            height: seatRing.width
            radius: seatRing.width / 2
            x: Math.round(seatRing.seat.x - seatRing.width / 2)
            y: Math.round(seatRing.seat.y - seatRing.height / 2)
            color: seatRing.hot ? IrisStyle.tintFill(IrisStyle.accent) : "transparent"
            border.width: Math.max(1, Math.round(1.5 * root.d))
            border.color: seatRing.hot ? IrisStyle.accent : IrisStyle.onMediaFillHover
            Behavior on width { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
        }
    }

    Component {
        id: clockBlock
        Column {
            id: clock
            readonly property var entry: {
                Config.revision
                return IrisLockOptions.entry("clock")
            }
            readonly property string style: String(clock.entry?.style ?? "stack")
            spacing: -Math.round(6 * root.d)
            readonly property string dateText: {
                const style = String(IrisLockOptions.typeOptions?.dateFormat ?? "long")
                const date = DateTime.clock.date
                if (style === "weekday") return Qt.locale().toString(date, "dddd")
                if (style === "short") return Qt.locale().toString(date, "ddd d MMM")
                if (style === "numeric") return Qt.locale().toString(date, Locale.ShortFormat)
                return Qt.locale().toString(date, "dddd, d MMMM")
            }
            readonly property string timeText: {
                const wanted = String(IrisLockOptions.typeOptions?.clockFormat ?? "auto")
                const seconds = Boolean(IrisLockOptions.typeOptions?.seconds ?? false)
                if (wanted === "auto" && !seconds) return DateTime.timeDisplay
                const pattern = (wanted === "12h" ? "h:mm" : wanted === "24h" ? "HH:mm"
                    : (DateTime.timeDisplay.toLowerCase().includes("m") ? "h:mm" : "HH:mm"))
                    + (seconds ? ":ss" : "") + (wanted === "12h" ? " AP" : "")
                return Qt.formatDateTime(DateTime.clock.date, pattern)
            }
            IrisText {

                renderType: root.renderFor("clock")
                anchors.horizontalCenter: clock.horizontalCenter
                visible: Boolean(clock.entry?.date ?? true) && clock.style === "stack"
                text: clock.dateText
                color: IrisStyle.onMedia
                font.pixelSize: Math.round(21 * root.typeScale)
                font.weight: IrisStyle.weight(Font.DemiBold)
            }
            IrisText {

                renderType: root.renderFor("clock")
                anchors.horizontalCenter: clock.horizontalCenter
                text: clock.timeText
                color: IrisLockOptions.accentColour
                font.family: IrisLockOptions.clockFamily
                font.features: ({ "tnum": 1 })
                font.pixelSize: Math.round(Math.max(24, Number(IrisLockOptions.typeOptions?.clockSize ?? 112))
                    * root.typeScale * (clock.style === "minimal" ? 0.45 : 1))
                font.weight: Math.max(100, Math.min(900, Number(IrisLockOptions.typeOptions?.clockWeight ?? 700)))
                font.letterSpacing: Number(IrisLockOptions.typeOptions?.clockTracking ?? -2)
            }
        }
    }

    component Chip: Item {
        id: chip
        property string glyph: ""
        property string label: ""
        property string figure: ""
        property color tint: IrisStyle.onMedia
        implicitWidth: chipRow.implicitWidth + Math.round(30 * root.d)
        implicitHeight: Math.round(40 * root.d)
        Glass {
            anchors.fill: parent
            radius: height / 2
        }
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: Math.round(7 * root.d)
            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.glyph
                fill: 1
                iconSize: Math.round(17 * root.d)
                color: chip.tint
            }
            IrisText {

                renderType: root.renderFor("clock")
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.figure.length > 0
                text: chip.figure
                color: IrisStyle.onMedia
                font.family: IrisStyle.fontNumbers
                font.features: ({ "tnum": 1 })
                font.weight: IrisStyle.weight(Font.DemiBold)
                font.pixelSize: Math.round(15 * root.typeScale)
            }
            IrisText {

                renderType: root.renderFor("clock")
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.label.length > 0
                width: Math.min(implicitWidth, Math.round(220 * root.d))
                text: chip.label
                elide: Text.ElideRight
                color: IrisStyle.onMediaSecondary
                font.weight: IrisStyle.weight(Font.Medium)
                font.pixelSize: Math.round(13 * root.typeScale)
            }
        }
    }

    Component {
        id: glanceBlock
        Row {
            id: glance
            readonly property var entry: {
                Config.revision
                return IrisLockOptions.entry("glance")
            }
            readonly property string temperature: {
                const value = parseFloat(String(Weather.data?.temp ?? ""))
                return isNaN(value) ? "" : Math.round(value) + "°"
            }
            readonly property var nextEvent: {
                void DateTime.clock.date
                return IrisFaceData.upcomingEvents(DateTime.clock.date, 2)[0] ?? null
            }
            spacing: Math.round(8 * root.d)
            Chip {
                visible: Boolean(glance.entry?.weather ?? true) && glance.temperature.length > 0
                glyph: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
                figure: glance.temperature
                label: Weather.showVisibleCity ? Weather.visibleCity : ""
            }
            Chip {
                visible: Boolean(glance.entry?.events ?? true) && glance.nextEvent !== null
                glyph: "event"
                tint: IrisStyle.identity.red
                label: glance.nextEvent ? IrisFaceData.eventTitle(glance.nextEvent) + " · "
                    + IrisFaceData.eventWhen(glance.nextEvent, DateTime.clock.date) : ""
            }
            Chip {
                visible: Boolean(glance.entry?.battery ?? true) && Battery.available
                glyph: Battery.isCharging ? "battery_charging_full" : Battery.percentage < 0.2 ? "battery_alert" : "battery_full"
                tint: Battery.percentage < 0.2 && !Battery.isCharging ? IrisStyle.danger : IrisStyle.onMedia
                figure: Math.round(Battery.percentage * 100) + "%"
            }
        }
    }

    Component {
        id: mediaBlock
        Item {
            id: media
            readonly property bool playing: MprisController.activePlayer !== null
                && String(MprisController.activePlayer?.trackTitle ?? "").length > 0
            readonly property bool bare: {
                Config.revision
                return String(IrisLockOptions.entry("media")?.style ?? "card") === "bare"
            }
            implicitWidth: Math.round(380 * root.d)
            implicitHeight: media.playing || root.editing ? mediaCard.implicitHeight : 0
            Glass {
                anchors.fill: parent
                visible: !media.bare
                radius: IrisStyle.radiusSheet
            }
            IrisMediaCard {
                id: mediaCard
                anchors.fill: parent
                active: media.playing
                showBackground: false
            }
        }
    }

    Component {
        id: activityBlock
        Column {
            spacing: Math.round(10 * root.d)
            ActivityPlate {
                shown: RecorderStatus.isRecording
                glyph: "radio_button_checked"
                tint: IrisStyle.danger
                label: Translation.tr("Recording")
                figure: root.clockText(RecorderStatus.elapsedSeconds)
            }
            ActivityPlate {
                readonly property string kind: TimerService.pomodoroRunning ? "pomodoro"
                    : TimerService.countdownRunning ? "countdown"
                    : TimerService.stopwatchRunning ? "stopwatch" : ""
                readonly property bool paused: kind === "pomodoro" ? TimerService.pomodoroPaused
                    : kind === "countdown" ? TimerService.countdownPaused : TimerService.stopwatchPaused
                shown: kind.length > 0
                glyph: paused ? "pause" : kind === "stopwatch" ? "timer" : kind === "pomodoro" && TimerService.pomodoroBreak ? "coffee" : "hourglass_top"
                tint: paused ? IrisStyle.onMediaSecondary : IrisStyle.secondaryAccent
                label: kind === "pomodoro" ? (TimerService.pomodoroBreak ? Translation.tr("Break") : Translation.tr("Focus"))
                    : kind === "countdown" ? Translation.tr("Timer") : Translation.tr("Stopwatch")
                countDown: kind !== "stopwatch"
                figure: root.clockText(kind === "pomodoro" ? TimerService.pomodoroSecondsLeft
                    : kind === "countdown" ? TimerService.countdownSecondsLeft
                    : Math.floor(TimerService.stopwatchTime / 100))
                progress: kind === "pomodoro" ? 1 - TimerService.pomodoroSecondsLeft / Math.max(1, TimerService.pomodoroLapDuration)
                    : kind === "countdown" ? 1 - TimerService.countdownSecondsLeft / Math.max(1, TimerService.countdownDuration) : -1
            }
        }
    }

    Component {
        id: statusBlock
        Row {
            id: status
            readonly property var entry: {
                Config.revision
                return IrisLockOptions.entry("status")
            }
            spacing: Math.round(14 * root.d)
            Reading {
                unit: root.d
                typeScale: root.typeScale
                visible: Boolean(status.entry?.keyboard ?? true) && NiriService.hasMultipleKeyboardLayouts
                glyph: "keyboard"
                label: String(NiriService.keyboardLayoutNames[NiriService.currentKeyboardLayoutIndex] ?? "")
            }
            Reading {
                unit: root.d
                typeScale: root.typeScale
                visible: Boolean(status.entry?.network ?? true)
                glyph: Network.wifiEnabled ? "wifi" : "wifi_off"
                label: Network.wifiEnabled ? (Network.networkName || Translation.tr("Wi-Fi")) : Translation.tr("Offline")
            }
            Reading {
                unit: root.d
                typeScale: root.typeScale
                visible: Boolean(status.entry?.battery ?? true) && Battery.available
                glyph: Battery.isCharging ? "bolt" : "battery_full"
                label: Math.round(Battery.percentage * 100) + "%"
            }
        }
    }

    Component {
        id: sessionBlock
        Column {
            id: session
            readonly property var entry: {
                Config.revision
                return IrisLockOptions.entry("session")
            }
            spacing: 0
            Rectangle {
                anchors.horizontalCenter: session.horizontalCenter
                visible: avatar.visible
                width: avatar.width + Math.round(8 * root.d)
                height: width
                radius: width / 2
                color: IrisStyle.mediaGlass
                border.width: Math.max(1, Math.round(1.5 * root.d))
                border.color: IrisStyle.mediaHairline
                ClippingRectangle {
                id: avatar
                anchors.centerIn: parent
                visible: Boolean(session.entry?.avatar ?? true)
                width: avatar.visible ? Math.round(84 * root.d) : 0
                height: avatar.width
                radius: width / 2
                color: IrisStyle.onMediaFill
                property int sourceIndex: 0
                IrisImage {
                    id: avatarImage
                    anchors.fill: parent
                    source: Directories.avatarSourceAt(avatar.sourceIndex)
                    visible: avatarImage.status === Image.Ready
                    onStatusChanged: {
                        if (avatarImage.status === Image.Error && avatar.sourceIndex + 1 < Directories.userAvatarPaths.length)
                            Qt.callLater(() => avatar.sourceIndex++)
                    }
                }
                IrisText {

                    renderType: root.renderFor("session")
                    anchors.centerIn: parent
                    visible: avatarImage.status !== Image.Ready
                    text: (SystemInfo.displayName || SystemInfo.username || "?").charAt(0).toUpperCase()
                    color: IrisStyle.onMedia
                    font.pixelSize: Math.round(34 * root.typeScale)
                    font.weight: IrisStyle.weight(Font.DemiBold)
                }
                }
            }
            Item { width: 1; height: avatar.visible ? Math.round(12 * root.d) : 0 }
            IrisText {

                renderType: root.renderFor("session")
                anchors.horizontalCenter: session.horizontalCenter
                visible: Boolean(session.entry?.name ?? true)
                height: visible ? implicitHeight : 0
                text: SystemInfo.displayName || SystemInfo.username
                color: IrisStyle.onMedia
                font.pixelSize: Math.round(18 * root.typeScale)
                font.weight: IrisStyle.weight(Font.DemiBold)
            }
            Item { width: 1; height: Math.round(16 * root.d) }
            Item {
                id: capsule
                anchors.horizontalCenter: session.horizontalCenter
                width: Math.round(Math.max(160, Number(session.entry?.width ?? 248)) * root.d)
                height: Math.round(44 * root.d)
                Glass {
                    anchors.fill: parent
                    radius: height / 2
                    outline: true
                }
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: passwordInput.activeFocus ? IrisStyle.onMediaFill : "transparent"
                    border.width: root.context.showFailure ? Math.max(1, Math.round(1.5 * root.d)) : 0
                    border.color: IrisStyle.tintBorder(IrisStyle.danger)
                    Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                }

                transform: Translate { id: shakeOffset }
                SequentialAnimation {
                    id: shake
                    NumberAnimation { target: shakeOffset; property: "x"; to: -12 * root.d; duration: 45; easing.type: Easing.OutQuad }
                    NumberAnimation { target: shakeOffset; property: "x"; to: 10 * root.d; duration: 70; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: shakeOffset; property: "x"; to: -6 * root.d; duration: 60; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: shakeOffset; property: "x"; to: 0; duration: 55; easing.type: Easing.OutQuad }
                }
                Connections {
                    target: root.context
                    function onFailed(): void { if (IrisStyle.motionEnabled) shake.restart() }
                }

                TextInput {
                    id: passwordInput
                    anchors.left: parent.left
                    anchors.right: submitButton.left
                    anchors.leftMargin: 16 * root.d
                    anchors.rightMargin: 6 * root.d
                    anchors.verticalCenter: parent.verticalCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    horizontalAlignment: TextInput.AlignHCenter
                    color: IrisStyle.onMedia
                    selectionColor: IrisStyle.onMediaFillHover
                    font.family: IrisStyle.fontMain
                    font.pixelSize: Math.round(14 * root.typeScale)
                    font.letterSpacing: 1
                    clip: true
                    enabled: !root.context.unlockInProgress && !root.editing
                    text: root.context.currentText
                    onTextChanged: if (root.context.currentText !== passwordInput.text) root.context.currentText = passwordInput.text
                    onAccepted: root.submitted()
                    Component.onCompleted: root.input = passwordInput
                    Component.onDestruction: if (root.input === passwordInput) root.input = null

                    IrisText {

                        renderType: root.renderFor("session")
                        anchors.centerIn: parent
                        visible: passwordInput.text.length === 0
                        text: root.context.fingerprintsConfigured ? Translation.tr("Password or fingerprint") : Translation.tr("Enter Password")
                        color: IrisStyle.onMediaSecondary
                        font.pixelSize: Math.round(13 * root.typeScale)
                    }
                }

                Rectangle {
                    id: submitButton
                    anchors.right: parent.right
                    anchors.rightMargin: 6 * root.d
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(32 * root.d)
                    height: width
                    radius: width / 2
                    color: submitArea.containsMouse ? IrisStyle.onMediaFillHover : IrisStyle.onMediaFill
                    opacity: root.context.currentText.length > 0 || root.context.unlockInProgress ? 1 : 0
                    visible: submitButton.opacity > 0
                    Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: root.context.unlockInProgress ? "more_horiz" : "arrow_forward"
                        iconSize: Math.round(18 * root.d)
                        color: IrisStyle.onMedia
                    }
                    MouseArea {
                        id: submitArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !root.editing
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.Button
                        Accessible.name: Translation.tr("Unlock")
                        onClicked: root.submitted()
                    }
                }
            }
            Item { width: 1; height: Math.round(10 * root.d) }
            IrisText {

                renderType: root.renderFor("session")
                anchors.horizontalCenter: session.horizontalCenter
                visible: Boolean(session.entry?.hint ?? true)
                height: visible ? implicitHeight : 0
                text: root.context.unlockInProgress ? Translation.tr("Unlocking…")
                    : root.context.showFailure ? Translation.tr("Incorrect password")
                    : root.context.fingerprintsConfigured ? Translation.tr("Touch the fingerprint reader or enter your password")
                    : " "
                color: root.context.showFailure ? IrisStyle.danger : IrisStyle.onMediaSecondary
                font.pixelSize: Math.round(12 * root.typeScale)
            }
        }
    }
}
