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
import qs.modules.shared.lock as LockUi
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
    property bool oskVisible: false
    property bool dragging: false
    property bool peeking: false
    property rect selectedRect: Qt.rect(0, 0, 0, 0)
    readonly property bool arranging: root.editing && !root.peeking
    property bool onCentreX: false
    property bool onCentreY: false
    readonly property real d: IrisStyle.density
    readonly property real typeScale: IrisStyle.typeScale * IrisLockOptions.typeScale
    readonly property real margin: Math.round(56 * root.d)
    // When this lock went up: the stage is made when the session locks (or the rehearsal opens).
    readonly property date lockedAt: new Date()

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
        // The frosted scene the plate cuts its piece from, for a Design that cuts it with its own die.
        readonly property Item frost: root.frost
        readonly property bool skinned: plateSkin.active
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
            visible: !glass.skinned && glass.material === "glass" && root.frost !== null
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
            visible: !glass.skinned && (glass.material !== "none" || glass.outline)
            radius: glass.radius
            color: glass.material === "glass" ? IrisStyle.mediaGlass
                : glass.material === "tint" ? IrisStyle.mediaScrim : "transparent"
            border.width: glass.material !== "tint" && !glass.lit ? 1 : 0
            border.color: glass.material === "none" ? IrisStyle.onMediaFill : IrisStyle.mediaHairline
        }
        readonly property bool lit: glass.material === "glass" && IrisStyle.edgeLit
        IrisGlassEdge {
            anchors.fill: parent
            visible: !glass.skinned && glass.lit && shown
            radius: glass.radius
        }
        IrisSkin { id: plateSkin; part: "lockPlate"; host: glass }
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

    component Reading: Item {
        id: reading
        property string kind: "" // keyboard · network · battery, for a Design that sets each its own way
        property string glyph: ""
        property string label: ""
        property real typeScale: 1
        property real unit: 1
        property real battery: -1 // a level draws the battery instead of the glyph
        readonly property bool skinned: readingSkin.active
        implicitWidth: reading.skinned ? (readingSkin.item?.implicitWidth ?? 0) : readingRow.implicitWidth
        implicitHeight: reading.skinned ? (readingSkin.item?.implicitHeight ?? 0) : readingRow.implicitHeight
        IrisSkin { id: readingSkin; part: "lockReading"; host: reading }
        Row {
        id: readingRow
        visible: !reading.skinned
        spacing: Math.round(5 * reading.unit)
        MaterialSymbol {
            visible: reading.battery < 0 || reading.glyph === "bolt"
            anchors.verticalCenter: parent.verticalCenter
            text: reading.glyph
            iconSize: Math.round(17 * reading.unit)
            color: IrisStyle.onMediaSecondary
        }
        IrisBatteryMark {
            visible: reading.battery >= 0
            anchors.verticalCenter: parent.verticalCenter
            markHeight: Math.round(10 * reading.unit)
            level: reading.battery
            tint: IrisStyle.onMediaSecondary
            frame: IrisStyle.onMediaTertiary
        }
        IrisText {
            anchors.verticalCenter: parent.verticalCenter
            text: reading.label
            color: IrisStyle.onMediaSecondary
            font.pixelSize: Math.round(13 * reading.typeScale)
            font.weight: IrisStyle.weight(Font.Medium)
        }
        }
    }

    component ActivityPlate: Item {
        id: plate
        property bool shown: false
        property string glyph: ""
        property color tint: IrisStyle.onMedia
        property string label: ""
        property string figure: ""
        property bool countDown: false
        property real progress: -1
        property bool live: false // something is being made now (a recording), not counted
        readonly property real unit: root.d
        readonly property real textScale: IrisLockOptions.typeScale
        readonly property bool skinned: activitySkin.active
        visible: plate.shown
        implicitWidth: Math.round(380 * root.d)
        implicitHeight: plate.shown ? (plate.skinned ? (activitySkin.item?.implicitHeight ?? 0) : Math.round(64 * root.d)) : 0

        Glass {
            anchors.fill: parent
            radius: IrisStyle.radiusPlate
        }
        IrisSkin { id: activitySkin; part: "lockActivity"; host: plate }
        RowLayout {
            visible: !plate.skinned
            anchors.fill: parent
            anchors.leftMargin: 12 * root.d
            anchors.rightMargin: 20 * root.d
            spacing: 12 * root.d
            Rectangle {
                Layout.preferredWidth: Math.round(40 * root.d)
                Layout.preferredHeight: Layout.preferredWidth
                radius: IrisStyle.capsule(width)
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
            visible: !plate.skinned && plate.progress >= 0
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 22 * root.d
            anchors.bottomMargin: 7 * root.d
            width: (parent.width - 44 * root.d) * Math.max(0, Math.min(1, plate.progress))
            height: Math.max(2, 2 * root.d)
            radius: IrisStyle.capsule(height)
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
        // What a Design's edit marks read: the pointer over the block, its name and its switch.
        readonly property bool hovered: grip.containsMouse
        readonly property bool arranging: root.arranging
        readonly property string label: IrisLockOptions.labelOf(body.blockId)
        readonly property real unit: root.d
        readonly property bool skinned: chromeSkin.active
        function toggle(): void { IrisLockOptions.toggle(body.blockId) }
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
            visible: root.arranging && !body.skinned
            anchors.fill: parent
            anchors.margins: -Math.round(8 * root.d)
            radius: IrisStyle.radiusPlate
            color: body.picked ? IrisStyle.tintFill(IrisStyle.accentOnMedia)
                : grip.containsMouse ? IrisStyle.onMediaFill : "transparent"
            border.width: body.picked || grip.containsMouse ? Math.max(1, Math.round(1.5 * root.d)) : 0
            border.color: body.picked ? IrisStyle.accentOnMedia : IrisStyle.onMediaFillHover
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
        }
        Row {
            id: chrome
            visible: root.arranging && !body.skinned && (body.picked || grip.containsMouse)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: Math.round(14 * root.d)
            spacing: Math.round(4 * root.d)
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: chromeLabel.implicitWidth + Math.round(16 * root.d)
                height: Math.round(24 * root.d)
                radius: IrisStyle.capsule(height)
                color: body.picked ? IrisStyle.accentOnMedia : IrisStyle.mediaScrim
                IrisText {
                    id: chromeLabel
                    anchors.centerIn: parent
                    text: IrisLockOptions.labelOf(body.blockId)
                    color: body.picked ? IrisStyle.onTintFor(IrisStyle.accentOnMedia) : IrisStyle.onMedia
                    font.pixelSize: IrisStyle.typeFootnote
                    font.weight: IrisStyle.weight(Font.DemiBold)
                }
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(24 * root.d)
                height: width
                radius: IrisStyle.capsule(width)
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

        IrisSkin { id: chromeSkin; part: "lockChrome"; host: body; visible: root.arranging }

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
        color: IrisStyle.accentOnMedia
        opacity: 0.7
    }
    Rectangle {
        visible: root.dragging && root.onCentreY
        height: Math.max(1, Math.round(root.d))
        width: root.width
        y: Math.round(root.height / 2 - height / 2)
        color: IrisStyle.accentOnMedia
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
            readonly property bool skinned: seatSkin.active
            width: Math.round((seatRing.hot ? 34 : 18) * root.d)
            height: seatRing.width
            radius: IrisStyle.capsule(seatRing.width)
            x: Math.round(seatRing.seat.x - seatRing.width / 2)
            y: Math.round(seatRing.seat.y - seatRing.height / 2)
            color: seatRing.skinned ? "transparent" : seatRing.hot ? IrisStyle.tintFill(IrisStyle.accentOnMedia) : "transparent"
            border.width: seatRing.skinned ? 0 : Math.max(1, Math.round(1.5 * root.d))
            border.color: seatRing.hot ? IrisStyle.accentOnMedia : IrisStyle.onMediaFillHover
            Behavior on width { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
            IrisSkin { id: seatSkin; part: "lockSeat"; host: seatRing }
        }
    }

    Component {
        id: clockBlock
        Item {
            id: clock
            readonly property var entry: {
                Config.revision
                return IrisLockOptions.entry("clock")
            }
            readonly property string style: String(clock.entry?.style ?? "stack")
            // What a Design's clock reads: every Type and Clock row, resolved.
            readonly property bool showDate: Boolean(clock.entry?.date ?? true) && clock.style === "stack"
            readonly property int timeSize: Math.round(Math.max(24, Number(IrisLockOptions.typeOptions?.clockSize ?? 112))
                * root.typeScale * (clock.style === "minimal" ? 0.45 : 1))
            readonly property int timeWeight: Math.max(100, Math.min(900, Number(IrisLockOptions.typeOptions?.clockWeight ?? 700)))
            readonly property real tracking: Number(IrisLockOptions.typeOptions?.clockTracking ?? -2)
            readonly property string family: IrisLockOptions.clockFamily
            readonly property color colour: IrisLockOptions.accentColour
            readonly property real textScale: IrisLockOptions.typeScale
            readonly property int renderType: root.renderFor("clock")
            readonly property var context: root.context
            readonly property real unit: root.d
            // When the lock went up, in the clock's own format, and the machine it locked.
            readonly property date lockedAt: root.lockedAt
            readonly property string lockedText: {
                const wanted = String(IrisLockOptions.typeOptions?.clockFormat ?? "auto")
                const twelve = wanted === "12h" || (wanted === "auto" && DateTime.timeDisplay.toLowerCase().includes("m"))
                return Qt.formatDateTime(root.lockedAt, twelve ? "h:mm AP" : "HH:mm")
            }
            readonly property string machine: SystemInfo.hostname
            readonly property bool skinned: clockSkin.active
            implicitWidth: clock.skinned ? (clockSkin.item?.implicitWidth ?? 0) : clockColumn.implicitWidth
            implicitHeight: clock.skinned ? (clockSkin.item?.implicitHeight ?? 0) : clockColumn.implicitHeight
            IrisSkin { id: clockSkin; part: "lockClock"; host: clock }
            readonly property string dateText: {
                const style = String(IrisLockOptions.typeOptions?.dateFormat ?? "long")
                const date = DateTime.clock.date
                if (style === "weekday") return Translation.locale.toString(date, "dddd")
                if (style === "short") return Translation.locale.toString(date, "ddd d MMM")
                if (style === "numeric") return Qt.locale().toString(date, Locale.ShortFormat)
                return Translation.locale.toString(date, "dddd, d MMMM")
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
            Column {
            id: clockColumn
            visible: !clock.skinned
            spacing: -Math.round(6 * root.d)
            IrisText {

                renderType: root.renderFor("clock")
                anchors.horizontalCenter: clockColumn.horizontalCenter
                visible: clock.showDate
                text: clock.dateText
                color: IrisStyle.onMedia
                font.pixelSize: Math.round(21 * root.typeScale)
                font.weight: IrisStyle.weight(Font.DemiBold)
            }
            IrisText {

                renderType: root.renderFor("clock")
                anchors.horizontalCenter: clockColumn.horizontalCenter
                text: clock.timeText
                color: clock.colour
                font.family: clock.family
                font.features: ({ "tnum": 1 })
                font.pixelSize: clock.timeSize
                font.weight: clock.timeWeight
                font.letterSpacing: clock.tracking
            }
            }
        }
    }

    component Chip: Item {
        id: chip
        property string glyph: ""
        property string label: ""
        property string figure: ""
        property color tint: IrisStyle.onMedia
        property real battery: -1 // a level draws the battery instead of the glyph
        // For a Design that sets a label over the datum: what the datum is (the city, when the event is), and the
        // datum itself when it is words rather than a figure.
        property string ruby: ""
        property string headline: ""
        readonly property real unit: root.d
        readonly property real textScale: IrisLockOptions.typeScale
        readonly property int renderType: root.renderFor("glance")
        readonly property bool skinned: chipSkin.active
        implicitWidth: chip.skinned ? (chipSkin.item?.implicitWidth ?? 0) : chipRow.implicitWidth + Math.round(30 * root.d)
        implicitHeight: chip.skinned ? (chipSkin.item?.implicitHeight ?? 0) : Math.round(40 * root.d)
        Glass {
            anchors.fill: parent
            radius: IrisStyle.capsule(height)
        }
        IrisSkin { id: chipSkin; part: "lockChip"; host: chip }
        Row {
            id: chipRow
            visible: !chip.skinned
            anchors.centerIn: parent
            spacing: Math.round(7 * root.d)
            MaterialSymbol {
                visible: chip.battery < 0 || chip.glyph === "bolt"
                anchors.verticalCenter: parent.verticalCenter
                text: chip.glyph
                fill: 1
                iconSize: Math.round(17 * root.d)
                color: chip.tint
            }
            IrisBatteryMark {
                visible: chip.battery >= 0
                anchors.verticalCenter: parent.verticalCenter
                markHeight: Math.round(11 * root.d)
                level: chip.battery
                tint: chip.tint
                frame: IrisStyle.onMediaTertiary
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
                ruby: Weather.showVisibleCity && Weather.visibleCity.length > 0 ? Weather.visibleCity : Translation.tr("Weather")
            }
            Chip {
                visible: Boolean(glance.entry?.events ?? true) && glance.nextEvent !== null
                glyph: "event"
                tint: IrisStyle.identity.red
                label: glance.nextEvent ? IrisFaceData.eventTitle(glance.nextEvent) + " · "
                    + IrisFaceData.eventWhen(glance.nextEvent, DateTime.clock.date) : ""
                ruby: glance.nextEvent ? IrisFaceData.eventWhen(glance.nextEvent, DateTime.clock.date) : ""
                headline: glance.nextEvent ? IrisFaceData.eventTitle(glance.nextEvent) : ""
            }
            Chip {
                visible: Boolean(glance.entry?.battery ?? true) && Battery.available
                glyph: Battery.isCharging ? "bolt" : ""
                battery: Battery.percentage
                tint: Battery.percentage < 0.2 && !Battery.isCharging ? IrisStyle.dangerOnMedia : IrisStyle.onMedia
                figure: Math.round(Battery.percentage * 100) + "%"
                ruby: Battery.isCharging ? Translation.tr("Charging") : Translation.tr("Battery")
            }
        }
    }

    Component {
        id: mediaBlock
        Item {
            id: media
            readonly property bool playing: MprisController.activePlayer !== null
                && String(MprisController.titleOf(MprisController.activePlayer) ?? "").length > 0
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
                overMedia: true
                offersOpen: false
            }
        }
    }

    Component {
        id: activityBlock
        Column {
            spacing: Math.round(10 * root.d)
            ActivityPlate {
                shown: RecorderStatus.isRecording
                live: true
                glyph: "radio_button_checked"
                tint: IrisStyle.dangerOnMedia
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
                tint: paused ? IrisStyle.onMediaSecondary : IrisStyle.highlightOnMedia
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
                kind: "keyboard"
                glyph: "keyboard"
                label: String(NiriService.keyboardLayoutNames[NiriService.currentKeyboardLayoutIndex] ?? "")
            }
            Reading {
                unit: root.d
                typeScale: root.typeScale
                visible: Boolean(status.entry?.network ?? true)
                kind: "network"
                // What the machine is connected by, not whether the Wi-Fi radio is on.
                glyph: Network.materialSymbol
                label: Network.ethernet ? Translation.tr("Ethernet")
                    : !Network.wifiEnabled ? Translation.tr("Offline")
                    : (Network.wifiStatus === "connected" || Network.wifiStatus === "limited")
                        ? (Network.networkName || Translation.tr("Wi-Fi"))
                    : Translation.tr("Not connected")
            }
            Reading {
                unit: root.d
                typeScale: root.typeScale
                visible: Boolean(status.entry?.battery ?? true) && Battery.available
                kind: "battery"
                glyph: Battery.isCharging ? "bolt" : ""
                battery: Battery.percentage
                label: Math.round(Battery.percentage * 100) + "%"
            }
        }
    }

    Component {
        id: sessionBlock
        Item {
            id: session
            readonly property var entry: {
                Config.revision
                return IrisLockOptions.entry("session")
            }
            // What a Design's sign-in reads. The field stays this block's TextInput whoever draws it, so focus, the
            // keyboard, the lock keyboard and PAM never change; a Design gets how much is typed, never what.
            readonly property var context: root.context
            readonly property bool editing: root.editing
            readonly property bool oskVisible: root.oskVisible
            readonly property int typed: passwordInput.length
            readonly property int cursor: passwordInput.cursorPosition
            readonly property int selectionStart: passwordInput.selectionStart
            readonly property int selectionEnd: passwordInput.selectionEnd
            readonly property bool focused: passwordInput.activeFocus
            readonly property real unit: root.d
            readonly property real textScale: IrisLockOptions.typeScale
            readonly property int renderType: root.renderFor("session")
            readonly property string displayName: SystemInfo.displayName || SystemInfo.username
            readonly property string userName: SystemInfo.username
            readonly property string hint: root.context.unlockInProgress ? Translation.tr("Unlocking…")
                : root.context.showFailure ? Translation.tr("Incorrect password")
                : root.context.fingerprintsConfigured ? Translation.tr("Touch the fingerprint reader or enter your password")
                : ""
            function toggleKeyboard(): void { root.oskVisible = !root.oskVisible }
            function submit(): void { root.submitted() }
            function focusField(): void { passwordInput.forceActiveFocus() }
            readonly property Item look: sessionSkin.item
            readonly property bool skinned: sessionSkin.active
            implicitWidth: session.skinned ? (session.look?.implicitWidth ?? 0) : column.implicitWidth
            implicitHeight: session.skinned ? (session.look?.implicitHeight ?? 0) : column.implicitHeight

            Column {
            id: column
            visible: !session.skinned
            spacing: 0
            Rectangle {
                anchors.horizontalCenter: column.horizontalCenter
                visible: avatar.visible
                width: avatar.width + Math.round(8 * IrisStyle.density)
                height: width
                radius: IrisStyle.capsule(width)
                color: IrisStyle.mediaGlass
                border.width: Math.max(1, Math.round(1.5 * root.d))
                border.color: IrisStyle.mediaHairline
                ClippingRectangle {
                id: avatar
                anchors.centerIn: parent
                visible: Boolean(session.entry?.avatar ?? true)
                width: avatar.visible ? Math.round(84 * root.d) : 0
                height: avatar.width
                radius: IrisStyle.capsule(width)
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
                anchors.horizontalCenter: column.horizontalCenter
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
                anchors.horizontalCenter: column.horizontalCenter
                width: Math.round(Math.max(160, Number(session.entry?.width ?? 248)) * root.d)
                height: Math.round(44 * root.d)
                Glass {
                    anchors.fill: parent
                    radius: IrisStyle.capsule(height)
                    outline: true
                }
                Rectangle {
                    anchors.fill: parent
                    radius: IrisStyle.capsule(height)
                    color: passwordInput.activeFocus ? IrisStyle.onMediaFill : "transparent"
                    border.width: root.context.showFailure ? Math.max(1, Math.round(1.5 * root.d)) : 0
                    border.color: IrisStyle.tintBorder(IrisStyle.dangerOnMedia)
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
                    // A Design that draws the field answers a failure its own way.
                    function onFailed(): void { if (IrisStyle.motionEnabled && !session.skinned) shake.restart() }
                }

                Rectangle {
                    id: keyboardButton
                    anchors.left: parent.left
                    anchors.leftMargin: 6 * root.d
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(32 * root.d)
                    height: width
                    radius: IrisStyle.capsule(width)
                    color: root.oskVisible || keyboardArea.containsMouse ? IrisStyle.onMediaFillHover : IrisStyle.onMediaFill
                    Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "keyboard"
                        iconSize: Math.round(18 * root.d)
                        color: IrisStyle.onMedia
                    }
                    MouseArea {
                        id: keyboardArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !root.editing
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.Button
                        Accessible.name: Translation.tr("Virtual keyboard")
                        onClicked: root.oskVisible = !root.oskVisible
                    }
                }

                Rectangle {
                    id: submitButton
                    anchors.right: parent.right
                    anchors.rightMargin: 6 * root.d
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(32 * root.d)
                    height: width
                    radius: IrisStyle.capsule(width)
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
                anchors.horizontalCenter: column.horizontalCenter
                visible: Boolean(session.entry?.hint ?? true)
                height: visible ? implicitHeight : 0
                text: session.hint || " "
                color: root.context.showFailure ? IrisStyle.dangerOnMedia : IrisStyle.onMediaSecondary
                font.pixelSize: Math.round(12 * root.typeScale)
            }
            }
            // A Design that sets the whole sign-in on one plate (a card) gets the lock's plate under it.
            Glass {
                anchors.fill: parent
                visible: session.skinned && Boolean(session.look?.plated ?? false)
            }
            IrisSkin { id: sessionSkin; part: "lockSignIn"; host: session }

            TextInput {
                id: passwordInput
                // Between the capsule's two buttons, or over the field a Design draws (its marks are the Design's).
                x: session.look ? Math.round(session.look.fieldX ?? 0)
                    : capsule.x + keyboardButton.x + keyboardButton.width + Math.round(6 * root.d)
                y: session.look ? Math.round(session.look.fieldY ?? 0) : capsule.y + Math.round((capsule.height - height) / 2)
                width: session.look ? Math.round(session.look.fieldWidth ?? 0)
                    : Math.max(0, submitButton.x - keyboardButton.x - keyboardButton.width - Math.round(12 * root.d))
                height: session.look ? Math.round(session.look.fieldHeight ?? 0) : implicitHeight
                transform: Translate { x: shakeOffset.x }
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                passwordCharacter: "●"
                horizontalAlignment: TextInput.AlignHCenter
                color: session.skinned ? "transparent" : IrisStyle.onMedia
                selectionColor: session.skinned ? "transparent" : IrisStyle.onMediaFillHover
                selectedTextColor: session.skinned ? "transparent" : IrisStyle.onMedia
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
                    visible: !session.skinned && passwordInput.text.length === 0
                    text: root.context.fingerprintsConfigured ? Translation.tr("Password or fingerprint") : Translation.tr("Enter Password")
                    color: IrisStyle.onMediaSecondary
                    font.pixelSize: Math.round(13 * root.typeScale)
                }
            }
        }
    }

    // The shared lock keyboard (Material and Waffle have it too), in the lock's glass: keys type into the password field.
    LockUi.LockKeyboard {
        id: lockKeyboard
        z: 10
        visible: root.oskVisible && !root.editing
        x: Math.round((root.width - width) / 2)
        width: Math.min(root.width * 0.6, Math.round(640 * root.d))
        themeBgColor: IrisStyle.surface
        themeKeySurfaceColor: IrisStyle.fillHover
        themeTextColor: IrisStyle.text
        themeSubtextColor: IrisStyle.textSecondary
        themeAccentColor: IrisStyle.accent
        themeAccentActiveColor: IrisStyle.accent
        themeAccentTextColor: IrisStyle.inkOnAccent
        themeRounding: IrisStyle.radiusSheet
        themeKeyRounding: IrisStyle.radiusRow
        themeAnimDuration: IrisStyle.duration(120)
        themeFontSize: IrisStyle.typeBody
        themeFontSizeLarge: IrisStyle.typeHeadline
        themeFontSizeSmall: IrisStyle.typeMeta
        themeFontFamily: IrisStyle.fontMain

        // Below the password field when there is room, above it otherwise: never over what is being typed.
        function place(): void {
            const gap = Math.round(14 * root.d)
            const edge = Math.round(56 * root.d)
            if (!root.input) { lockKeyboard.y = Math.round(root.height - lockKeyboard.height - edge); return }
            const at = root.input.mapToItem(root, 0, 0)
            const mid = at.y + root.input.height / 2
            const capsuleBottom = mid + Math.round(22 * root.d) + Math.round(30 * root.d)
            const capsuleTop = mid - Math.round(22 * root.d)
            lockKeyboard.y = Math.round(root.height - capsuleBottom - gap - edge >= lockKeyboard.height
                ? capsuleBottom + gap
                : Math.max(edge, capsuleTop - gap - lockKeyboard.height))
        }
        onVisibleChanged: if (visible) lockKeyboard.place()
        onHeightChanged: lockKeyboard.place()
        Connections {
            target: root
            function onRelayout(): void { lockKeyboard.place() }
        }

        onKeyClicked: key => {
            if (!root.input) return
            root.input.text += key
            root.input.forceActiveFocus()
        }
        onBackspaceClicked: {
            if (!root.input) return
            if (root.input.text.length > 0) root.input.text = root.input.text.slice(0, -1)
            root.input.forceActiveFocus()
        }
        onEnterClicked: if (root.context.currentText.length > 0) root.submitted()
        onCloseRequested: root.oskVisible = false
    }
}
