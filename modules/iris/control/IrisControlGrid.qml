pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.models.quickToggles
import qs.modules.common.widgets
import qs.modules.mediaControls.components
import qs.modules.iris.components
import qs.modules.iris.style

Item {
    id: root

    readonly property bool editing: GlobalStates.irisControlEdit
    property var targetScreen: null
    property string picker: ""
    function takePickerRequest(): void {
        const wanted = GlobalStates.irisControlPickerRequest
        if (wanted.length === 0) return
        root.picker = wanted === "none" ? "" : wanted
        GlobalStates.irisControlPickerRequest = ""
    }
    Connections {
        target: GlobalStates
        function onIrisControlPickerRequestChanged(): void { root.takePickerRequest() }
    }
    Component.onCompleted: root.takePickerRequest()
    // Right click on any tile that has a list (Wi-Fi, Bluetooth) opens it, whatever the tile's shape:
    // a small tile toggles on click and had no way to its networks or devices.
    function togglePicker(list: string): void {
        if (list.length === 0 || root.editing) return
        root.picker = root.picker === list ? "" : list
    }
    property string hint: ""
    readonly property real d: IrisStyle.density
    readonly property var monitor: Brightness.getMonitorForScreen(root.targetScreen)

    readonly property int columns: IrisControlOptions.columns
    readonly property real gap: Math.round(8 * root.d)
    readonly property real unit: Math.round((IrisControlOptions.labelled ? 70 : 64) * root.d)
    readonly property real cell: Math.max(1, (root.width - (root.columns - 1) * root.gap) / root.columns)
    readonly property real tileRadius: IrisStyle.radiusTile

    property string carrying: ""
    property bool carryingNew: false
    property point carryPoint: Qt.point(0, 0)
    property point grab: Qt.point(0, 0)
    property int dropIndex: -1
    property string resizing: ""
    property string resizeShape: ""

    readonly property var shapes: {
        Config.revision
        const out = ({})
        for (const id of IrisControlOptions.catalogueIds) {
            const wanted = id === root.resizing ? root.resizeShape : (IrisControlOptions.chosen[id] ?? "")
            out[id] = IrisControlOptions.resolveShape(id, wanted, root.columns)
        }
        return out
    }
    readonly property var base: IrisControlOptions.gridModules.filter(id => id !== root.carrying)
    function orderWith(index: int): var {
        if (root.carrying.length === 0 || index < 0) return root.base
        const list = root.base.slice()
        list.splice(index, 0, root.carrying)
        return list
    }
    readonly property var layout: IrisControlOptions.pack(root.orderWith(root.dropIndex), root.shapes, root.columns)
    readonly property var cellIds: IrisControlOptions.catalogueIds.filter(id => IrisControlOptions.kindOf(id) !== "list")

    function rectOf(spot: var): rect {
        return Qt.rect(Math.round(spot.col * (root.cell + root.gap)), Math.round(spot.row * (root.unit + root.gap)),
            Math.round(spot.w * root.cell + (spot.w - 1) * root.gap), Math.round(spot.h * root.unit + (spot.h - 1) * root.gap))
    }
    function shapeLabel(id: string): string {
        const shape = root.shapes[id]
        return shape ? shape.w + "×" + shape.h : ""
    }

    implicitHeight: root.layout.rows > 0
        ? root.layout.rows * root.unit + (root.layout.rows - 1) * root.gap
        : empty.implicitHeight + Math.round(24 * root.d)

    function contains(point: point): bool {
        const reach = Math.round(28 * root.d)
        return point.x > -reach && point.x < root.width + reach && point.y > -reach && point.y < root.height + reach
    }
    function distanceFor(index: int): real {
        const spot = IrisControlOptions.pack(root.orderWith(index), root.shapes, root.columns).placed[root.carrying]
        const r = root.rectOf(spot)
        return Math.hypot(r.x + r.width / 2 - root.carryPoint.x - root.grabCentre.x,
            r.y + r.height / 2 - root.carryPoint.y - root.grabCentre.y)
    }
    // The slot only moves when another one is clearly closer, so cells do not flicker
    // between two places while the pointer sits on a boundary.
    function nearestIndex(): int {
        if (root.overRemove || !root.contains(root.carryPoint)) return -1
        let best = root.base.length
        let bestDistance = Number.POSITIVE_INFINITY
        for (let i = 0; i <= root.base.length; i++) {
            const distance = root.distanceFor(i)
            if (distance < bestDistance - 0.5) { bestDistance = distance; best = i }
        }
        if (root.dropIndex >= 0 && best !== root.dropIndex
                && bestDistance > root.distanceFor(root.dropIndex) - 0.3 * Math.min(root.cell, root.unit))
            return root.dropIndex
        return best
    }
    property point grabCentre: Qt.point(0, 0)
    property int pendingIndex: -1
    property Item removeZone: null
    property bool overRemove: false
    Timer {
        id: dwell
        interval: 90
        onTriggered: root.dropIndex = root.pendingIndex
    }

    function beginCarry(id: string, point: point, offset: point, isNew: bool): void {
        const shape = root.shapes[id]
        const size = root.rectOf({ col: 0, row: 0, w: shape.w, h: shape.h })
        root.grab = offset
        root.grabCentre = Qt.point(size.width / 2 - offset.x, size.height / 2 - offset.y)
        root.carryingNew = isNew
        root.carryPoint = point
        root.overRemove = false
        root.carrying = id
        root.dropIndex = root.nearestIndex()
    }
    function moveCarry(point: point): void {
        if (root.carrying.length === 0) return
        root.carryPoint = point
        let over = false
        if (!root.carryingNew && root.removeZone && root.removeZone.visible) {
            const local = root.mapToItem(root.removeZone, point.x, point.y)
            over = local.x >= 0 && local.y >= 0 && local.x <= root.removeZone.width && local.y <= root.removeZone.height
        }
        root.overRemove = over
        const next = root.nearestIndex()
        if (next === root.dropIndex) { dwell.stop(); return }
        if (root.dropIndex < 0 || next < 0) { dwell.stop(); root.dropIndex = next; return }
        if (dwell.running && root.pendingIndex === next) return
        root.pendingIndex = next
        dwell.restart()
    }
    function endCarry(): void {
        if (dwell.running) { dwell.stop(); root.dropIndex = root.pendingIndex }
        const id = root.carrying
        const index = root.dropIndex
        const isNew = root.carryingNew
        const removing = root.overRemove
        root.carrying = ""
        root.carryingNew = false
        root.overRemove = false
        root.dropIndex = -1
        if (id.length === 0) return
        if (removing) { IrisControlOptions.remove(id); return }
        if (index < 0) return
        const modulesIndex = index < root.base.length
            ? IrisControlOptions.modules.filter(entry => entry !== id).indexOf(root.base[index])
            : IrisControlOptions.modules.filter(entry => entry !== id).length
        if (isNew) IrisControlOptions.add(id, modulesIndex)
        else IrisControlOptions.move(id, modulesIndex)
    }

    ColumnLayout {
        id: empty
        anchors.centerIn: parent
        width: parent.width
        visible: root.layout.rows === 0
        spacing: Math.round(6 * root.d)
        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: "dashboard_customize"
            iconSize: Math.round(26 * root.d)
            color: IrisStyle.muted
        }
        IrisText {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: parent.width
            text: root.editing ? Translation.tr("Drag controls in from the side")
                : Translation.tr("Nothing here yet. Arrange it from the header.")
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: IrisStyle.muted
            font.pixelSize: IrisStyle.typeMeta
        }
    }

    Rectangle {
        id: landing
        readonly property var spot: root.carrying.length > 0 ? root.layout.placed[root.carrying] : undefined
        readonly property rect area: landing.spot ? root.rectOf(landing.spot) : Qt.rect(0, 0, 0, 0)
        visible: landing.spot !== undefined
        x: landing.area.x
        y: landing.area.y
        width: landing.area.width
        height: landing.area.height
        radius: IrisControlOptions.roundControls ? Math.min(width, height) / 2 : root.tileRadius
        color: IrisStyle.fillQuiet
        border.width: Math.max(1, Math.round(1.5 * root.d))
        border.color: IrisStyle.tintBorder(IrisStyle.accent)
    }

    Repeater {
        model: ScriptModel { values: root.cellIds }
        delegate: Item {
            id: cell
            required property string modelData
            readonly property string moduleId: cell.modelData
            readonly property bool placed: IrisControlOptions.gridModules.includes(cell.moduleId) || cell.carried
            readonly property var spot: root.layout.placed[cell.moduleId]
            readonly property var shape: root.shapes[cell.moduleId]
            readonly property rect area: cell.spot ? root.rectOf(cell.spot)
                : root.rectOf({ col: 0, row: 0, w: cell.shape.w, h: cell.shape.h })
            readonly property bool carried: root.carrying === cell.moduleId
            readonly property bool reflows: root.editing && IrisStyle.motionEnabled && !cell.carried

            x: cell.carried ? Math.round(root.carryPoint.x - root.grab.x) : cell.area.x
            y: cell.carried ? Math.round(root.carryPoint.y - root.grab.y) : cell.area.y
            width: cell.area.width
            height: cell.area.height
            z: cell.carried ? 20 : 0
            scale: cell.carried ? 1.04 : 1
            visible: cell.placed

            Behavior on x { enabled: cell.reflows; NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
            Behavior on y { enabled: cell.reflows; NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
            Behavior on width { enabled: cell.reflows; NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
            Behavior on height { enabled: cell.reflows; NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
            Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }

            Loader {
                id: slot
                anchors.fill: parent
                active: cell.placed
                sourceComponent: {
                    const kind = IrisControlOptions.kindOf(cell.moduleId)
                    return kind === "media" ? mediaModule : kind === "level" ? levelModule
                        : kind === "levels" ? levelsModule : kind === "platter" ? platterModule : controlModule
                }
            }
            // Repeater reuses delegates: onLoaded would only see the first id a cell carried.
            Binding { target: slot.item; property: "moduleId"; value: cell.moduleId; when: slot.item !== null }

            RectangularShadow {
                anchors.fill: parent
                z: -1
                visible: cell.carried
                radius: IrisControlOptions.roundControls ? Math.min(width, height) / 2 : root.tileRadius
                blur: Math.round(22 * root.d)
                offset.y: Math.round(6 * root.d)
                color: IrisStyle.shadow
            }

            MouseArea {
                id: carryArea
                anchors.fill: parent
                visible: root.editing
                hoverEnabled: true
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property point origin: Qt.point(0, 0)
                property bool moved: false
                onEntered: root.hint = Translation.tr(IrisControlOptions.labelOf(cell.moduleId)) + " · " + root.shapeLabel(cell.moduleId)
                onExited: root.hint = ""
                onPressed: mouse => {
                    carryArea.origin = Qt.point(mouse.x, mouse.y)
                    carryArea.moved = false
                }
                onPositionChanged: mouse => {
                    if (!carryArea.pressed) return
                    const point = carryArea.mapToItem(root, mouse.x, mouse.y)
                    if (!carryArea.moved) {
                        if (Math.hypot(mouse.x - carryArea.origin.x, mouse.y - carryArea.origin.y) < 6 * root.d) return
                        carryArea.moved = true
                        root.beginCarry(cell.moduleId, point, carryArea.origin, false)
                        return
                    }
                    root.moveCarry(point)
                }
                onReleased: {
                    if (carryArea.moved) root.endCarry()
                    carryArea.moved = false
                }
                onCanceled: { carryArea.moved = false; root.carrying = ""; root.dropIndex = -1 }
            }

            IrisControlMark {
                id: removeMark
                visible: root.editing && !cell.carried
                x: -Math.round(width / 3)
                y: -Math.round(height / 3)
                glyph: "remove"
                danger: true
                label: Translation.tr("Take %1 out").arg(Translation.tr(IrisControlOptions.labelOf(cell.moduleId)))
                onHoveredOver: hovered => root.hint = hovered ? removeMark.label : ""
                onActivated: IrisControlOptions.remove(cell.moduleId)
            }
            IrisControlMark {
                id: sizeMark
                readonly property var allowed: IrisControlOptions.shapesFor(cell.moduleId, root.columns)
                readonly property bool shown: root.editing && !cell.carried && sizeMark.allowed.length > 1
                    && (carryArea.containsMouse || sizeMark.active || root.resizing === cell.moduleId)
                opacity: sizeMark.shown ? 1 : 0
                visible: sizeMark.opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                x: cell.width - Math.round(width * 2 / 3)
                y: cell.height - Math.round(height * 2 / 3)
                glyph: "open_in_full"
                label: Translation.tr("Change the size of %1").arg(Translation.tr(IrisControlOptions.labelOf(cell.moduleId)))
                draggable: true
                onActivated: IrisControlOptions.nextShape(cell.moduleId)
                onDragged: point => {
                    const local = sizeMark.mapToItem(cell, point.x, point.y)
                    const wantW = Math.max(1, Math.round(local.x / (root.cell + root.gap)))
                    const wantH = Math.max(1, Math.round(local.y / (root.unit + root.gap)))
                    let best = sizeMark.allowed[0]
                    let bestScore = Number.POSITIVE_INFINITY
                    for (const name of sizeMark.allowed) {
                        const shape = IrisControlOptions.parseShape(name, root.columns)
                        const score = Math.abs(shape.w - wantW) + Math.abs(shape.h - wantH)
                        if (score < bestScore) { bestScore = score; best = name }
                    }
                    root.resizing = cell.moduleId
                    root.resizeShape = best
                }
                onHoveredOver: hovered => root.hint = hovered ? sizeMark.label : ""
                onDropped: {
                    const shape = root.resizeShape
                    root.resizing = ""
                    if (shape.length > 0 && shape !== root.shapes[cell.moduleId]?.name) IrisControlOptions.setShape(cell.moduleId, shape)
                }
            }
        }
    }

    component ControlState: Item {
        id: ctl
        property string moduleId: ""
        readonly property QtObject model: modelLoader.item
        Loader {
            id: modelLoader
            sourceComponent: ctl.moduleId === "network" ? networkModel
                : ctl.moduleId === "bluetooth" ? bluetoothModel
                : ctl.moduleId === "vpn" ? vpnModel
                : ctl.moduleId === "hotspot" ? hotspotModel
                : ctl.moduleId === "profiles" ? profilesModel
                : ctl.moduleId === "focus" ? focusModel
                : ctl.moduleId === "gameMode" ? gameModeModel
                : ctl.moduleId === "darkMode" ? darkModeModel
                : ctl.moduleId === "nightLight" ? nightLightModel
                : ctl.moduleId === "idle" ? idleModel
                : ctl.moduleId === "audio" ? audioModel
                : ctl.moduleId === "mic" ? micModel
                : ctl.moduleId === "easyEffects" ? easyEffectsModel
                : ctl.moduleId === "musicRecognition" ? musicModel
                : ctl.moduleId === "osk" ? oskModel
                : ctl.moduleId === "snip" ? snipModel
                : ctl.moduleId === "colorPicker" ? colourModel
                : ctl.moduleId === "warp" ? warpModel
                : ctl.moduleId === "antiFlashbang" ? flashModel : null
        }
        readonly property bool recording: ctl.moduleId === "record" && RecorderStatus.isRecording
        readonly property bool headphones: /head|bluez|airpod|buds/i.test(String(Audio.defaultSink?.name ?? "") + String(Audio.defaultSink?.description ?? ""))
        readonly property string label: Translation.tr(IrisControlOptions.labelOf(ctl.moduleId))
        readonly property string glyph: ctl.moduleId === "record" ? (ctl.recording ? "stop_circle" : "radio_button_checked")
            : ctl.moduleId === "devices" ? (ctl.headphones ? "headphones" : "speaker")
            : String(ctl.model?.icon ?? IrisControlOptions.glyphOf(ctl.moduleId))
        readonly property string detail: ctl.moduleId === "devices" ? String(Audio.defaultSink?.description ?? "")
            : ctl.moduleId === "record" ? (ctl.recording ? Translation.tr("Recording") : Translation.tr("Whole screen, with sound"))
            : ctl.moduleId === "equalizer" ? ctl.eqDetail
            : String(ctl.model?.statusText ?? "")
        // The equalizer entry is an action, not a toggle: it glows while the
        // chain shapes the sound and reads the loaded preset, like a status.
        readonly property int eqActive: {
            let n = 0
            const modules = IrisAudio.modules ?? {}
            for (const id of Object.keys(modules)) {
                if (modules[id]?.active) n++
            }
            return n
        }
        readonly property bool eqShaped: {
            if (ctl.eqActive > 0) return true
            if (!IrisAudio.ready) return false
            const bands = IrisAudio.bands ?? []
            for (let i = 0; i < bands.length; i++) {
                if (Math.abs(Number(bands[i]?.gain ?? 0)) > 0.05) return true
            }
            return false
        }
        readonly property string eqDetail: !IrisAudio.ready ? Translation.tr("Waiting for engine")
            : String(IrisAudio.presetName ?? "").length > 0 ? String(IrisAudio.presetName)
            : ctl.eqActive > 0 ? Translation.tr("%1 shaping").arg(ctl.eqActive) : Translation.tr("Flat")
        readonly property bool lit: ctl.moduleId === "record" ? ctl.recording
            : ctl.moduleId === "devices" ? root.picker === "devices"
            : ctl.moduleId === "equalizer" ? ctl.eqShaped
            : Boolean(ctl.model?.toggled ?? false)
        readonly property bool ready: ctl.moduleId === "record" || ctl.moduleId === "devices"
            || Boolean(ctl.model?.available ?? true)
        readonly property color tint: IrisControlOptions.tintFor(ctl.moduleId)
        readonly property color ink: !ctl.ready ? IrisStyle.textTertiary
            : ctl.lit ? IrisStyle.onTintFor(ctl.tint) : IrisStyle.text
        // What a right click (or the chevron of a wide tile) unfolds under the grid: the list of that thing, or
        // the page of its category.
        readonly property string expands: ctl.moduleId === "network" ? "network"
            : ctl.moduleId === "bluetooth" ? "bluetooth"
            : IrisControlOptions.categoryOf(ctl.moduleId) === "display" ? "display"
            : IrisControlOptions.categoryOf(ctl.moduleId) === "system" ? "system"
            : IrisControlOptions.categoryOf(ctl.moduleId) === "sound" ? "devices" : ""
        readonly property bool listOnClick: ctl.moduleId === "network" || ctl.moduleId === "bluetooth"
        readonly property string caption: ["network", "bluetooth", "vpn", "hotspot"].includes(ctl.moduleId)
            && ctl.lit && ctl.detail.length > 0 ? ctl.detail : ctl.label
        function activate(): void {
            if (!ctl.ready || root.editing) return
            if (ctl.moduleId === "devices") { root.picker = root.picker === "devices" ? "" : "devices"; return }
            // The panel lives outside Control Center: open it by its flag (a
            // sibling agent owns the flag and the loader) and stand down.
            if (ctl.moduleId === "equalizer") {
                GlobalStates.irisEqualizerOpen = true
                GlobalStates.controlPanelOpen = false
                return
            }
            if (ctl.moduleId === "record") {
                const args = ["/usr/bin/bash", Directories.recordScriptPath]
                args.push(...(ctl.recording ? ["--stop"] : ["--fullscreen", "--sound"]))
                Quickshell.execDetached(args)
                RecorderStatus.scheduleQuickCheck()
                if (!ctl.recording) GlobalStates.controlPanelOpen = false
                return
            }
            if (ctl.moduleId === "snip" || ctl.moduleId === "colorPicker") GlobalStates.controlPanelOpen = false
            ctl.model?.mainAction()
        }
        function hover(on: bool): void {
            root.hint = on ? ctl.label + (ctl.detail.length > 0 ? " · " + ctl.detail : "")
                : (root.hint.startsWith(ctl.label) ? "" : root.hint)
        }
    }

    component Disc: IrisButton {
        id: discButton
        required property var control
        property real size: Math.round(46 * root.d)
        implicitWidth: discButton.size
        implicitHeight: discButton.size
        buttonRadius: height / 2
        buttonRadiusPressed: height / 2
        colBackground: discButton.control.lit ? discButton.control.tint : IrisStyle.fill
        colBackgroundHover: !discButton.control.ready ? discButton.colBackground
            : discButton.control.lit ? ColorUtils.mix(discButton.control.tint, IrisStyle.text, 0.85) : IrisStyle.fillHover
        Accessible.name: discButton.control.label
        Accessible.checkable: true
        Accessible.checked: discButton.control.lit
        onClicked: discButton.control.activate()
        altAction: () => { if (discButton.control.ready) root.togglePicker(discButton.control.expands) }
        HoverHandler { enabled: !root.editing; onHoveredChanged: discButton.control.hover(hovered) }
        MaterialSymbol {
            anchors.centerIn: parent
            text: discButton.control.glyph
            fill: discButton.control.lit ? 1 : 0
            iconSize: Math.round(Math.min(21 * root.d, discButton.size * 0.46))
            color: discButton.control.ink
        }
    }

    component ControlFace: Item {
        id: face
        property string moduleId: ""
        ControlState { id: faceState; moduleId: face.moduleId }
        readonly property bool wide: width >= root.cell * 1.5 && height < root.unit * 1.5
        readonly property bool disc: IrisControlOptions.roundControls && !face.wide
        readonly property real labelHeight: IrisControlOptions.labelled ? Math.round(16 * root.d) : 0

        Disc {
            visible: face.disc
            control: faceState
            size: Math.round(Math.min(46 * root.d, face.width - 8 * root.d, face.height - face.labelHeight - 6 * root.d))
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round((face.height - height - face.labelHeight) / 2)
        }
        IrisText {
            visible: face.disc && IrisControlOptions.labelled
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(2 * root.d)
            width: Math.min(implicitWidth, face.width - 4 * root.d)
            text: faceState.caption
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            color: faceState.ready ? IrisStyle.subtext : IrisStyle.textTertiary
            font.pixelSize: IrisStyle.typeFootnote
            font.weight: IrisStyle.weight(Font.Medium)
        }

        IrisButton {
            id: button
            visible: !face.disc
            anchors.fill: parent
            buttonRadius: IrisControlOptions.roundControls ? Math.min(width, height) / 2 : root.tileRadius
            buttonRadiusPressed: button.buttonRadius
            colBackground: faceState.lit && !face.wide ? faceState.tint
                : faceState.lit ? IrisStyle.tintFill(faceState.tint) : IrisStyle.fillQuiet
            colBackgroundHover: !faceState.ready ? button.colBackground
                : faceState.lit && !face.wide ? ColorUtils.mix(faceState.tint, IrisStyle.text, 0.85)
                : faceState.lit ? IrisStyle.tintFillHover(faceState.tint) : IrisStyle.fillHover
            Accessible.name: faceState.label
            Accessible.checkable: true
            Accessible.checked: faceState.lit
            onClicked: {
                if (!faceState.ready || root.editing) return
                if (face.wide && faceState.listOnClick) root.togglePicker(faceState.expands)
                else faceState.activate()
            }
            altAction: () => { if (faceState.ready) root.togglePicker(faceState.expands) }
            HoverHandler { enabled: !root.editing; onHoveredChanged: faceState.hover(hovered) }
        }

        ColumnLayout {
            visible: !face.disc && !face.wide
            anchors.centerIn: parent
            width: face.width
            spacing: Math.round(2 * root.d)
            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: faceState.glyph
                fill: faceState.lit ? 1 : 0
                iconSize: Math.round(21 * root.d)
                color: faceState.ink
            }
            IrisText {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: face.width - Math.round(8 * root.d)
                visible: IrisControlOptions.labelled
                text: faceState.label
                horizontalAlignment: Text.AlignHCenter
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: Math.round(8 * IrisStyle.typeScale)
                elide: Text.ElideRight
                color: faceState.lit ? faceState.ink : faceState.ready ? IrisStyle.subtext : IrisStyle.textTertiary
                font.pixelSize: IrisStyle.typeCaption
                font.weight: IrisStyle.weight(Font.Medium)
            }
        }

        RowLayout {
            visible: face.wide
            anchors.fill: parent
            anchors.leftMargin: Math.round((face.height - wideDisc.height) / 2)
            anchors.rightMargin: Math.round(10 * root.d)
            spacing: Math.round(10 * root.d)
            Disc {
                id: wideDisc
                control: faceState
                size: Math.round(Math.min(38 * root.d, face.height - 16 * root.d))
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: Number.POSITIVE_INFINITY
                spacing: 0
                IrisText {
                    Layout.fillWidth: true
                    text: faceState.label
                    elide: Text.ElideRight
                    color: faceState.ready ? IrisStyle.text : IrisStyle.textTertiary
                    font.pixelSize: IrisStyle.typeLabel
                    font.weight: IrisStyle.weight(Font.DemiBold)
                }
                IrisText {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: faceState.ready ? faceState.detail : Translation.tr("Unavailable")
                    elide: Text.ElideRight
                    color: IrisStyle.textSecondary
                    font.pixelSize: IrisStyle.typeFootnote
                }
            }
            MaterialSymbol {
                visible: faceState.expands.length > 0 && faceState.ready && face.width >= Math.round(170 * root.d)
                text: root.picker === faceState.expands ? "expand_less" : "chevron_right"
                iconSize: Math.round(17 * root.d)
                color: root.picker === faceState.expands ? IrisStyle.accent : IrisStyle.textSecondary
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Math.round(10 * root.d)
                    enabled: parent.visible && !root.editing
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.togglePicker(faceState.expands)
                }
            }
        }
    }

    Component {
        id: controlModule
        ControlFace {}
    }

    Component {
        id: platterModule
        Rectangle {
            id: platter
            property string moduleId: "platter"
            readonly property bool inRow: platter.width > platter.height * 1.8
            readonly property int count: Math.max(1, IrisControlOptions.platterIds.length)
            readonly property real pad: Math.round(8 * root.d)
            // Names follow the panel's own switch: a platter beside unnamed tiles is only its discs.
            readonly property real captionHeight: IrisControlOptions.labelled ? Math.round(14 * root.d) : 0
            readonly property real rowGap: Math.round(4 * root.d)
            readonly property real slotWidth: platter.inRow ? (platter.width - 2 * platter.pad) / platter.count
                : (platter.width - 2 * platter.pad) / 2
            readonly property real discSize: Math.round(Math.min(46 * root.d, platter.slotWidth - 12 * root.d,
                platter.inRow ? platter.height - 2 * platter.pad - platter.captionHeight
                    : (platter.height - 2 * platter.pad - platter.rowGap) / 2 - platter.captionHeight))
            radius: IrisStyle.radiusPlate
            color: IrisStyle.fillQuiet
            Grid {
                anchors.centerIn: parent
                columns: platter.inRow ? platter.count : 2
                rowSpacing: platter.rowGap
                Repeater {
                    model: IrisControlOptions.platterIds
                    delegate: Item {
                        id: platterSlot
                        required property string modelData
                        width: platter.slotWidth
                        height: platter.discSize + platter.captionHeight
                        ControlState { id: slotControl; moduleId: platterSlot.modelData }
                        Disc {
                            control: slotControl
                            size: platter.discSize
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        IrisText {
                            visible: IrisControlOptions.labelled
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            width: Math.min(implicitWidth, platterSlot.width - 4 * root.d)
                            text: slotControl.caption
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            color: slotControl.ready ? IrisStyle.subtext : IrisStyle.textTertiary
                            font.pixelSize: IrisStyle.typeFootnote
                            font.weight: IrisStyle.weight(Font.Medium)
                        }
                    }
                }
            }
        }
    }

    Component { id: networkModel; NetworkToggle {} }
    Component { id: bluetoothModel; BluetoothToggle {} }
    Component { id: vpnModel; VpnToggle {} }
    Component { id: hotspotModel; HotspotToggle {} }
    Component { id: profilesModel; PowerProfilesToggle {} }
    Component { id: focusModel; NotificationToggle {} }
    Component { id: gameModeModel; GameModeToggle {} }
    Component { id: darkModeModel; DarkModeToggle {} }
    Component { id: nightLightModel; NightLightToggle {} }
    Component { id: idleModel; IdleInhibitorToggle {} }
    Component { id: audioModel; AudioToggle {} }
    Component { id: micModel; MicToggle {} }
    Component { id: easyEffectsModel; EasyEffectsToggle {} }
    Component { id: musicModel; MusicRecognitionToggle {} }
    Component { id: oskModel; OnScreenKeyboardToggle {} }
    Component { id: snipModel; ScreenSnipToggle {} }
    Component { id: colourModel; ColorPickerToggle {} }
    Component { id: warpModel; CloudflareWarpToggle {} }
    Component { id: flashModel; AntiFlashbangToggle {} }

    component LevelSlider: IrisCapsuleSlider {
        id: level
        property string moduleId: ""
        readonly property real brightness: Number(root.monitor?.brightness ?? Number.NaN)
        readonly property bool ready: level.moduleId === "brightness" ? Boolean(root.monitor?.ready) && Number.isFinite(level.brightness)
            : level.moduleId === "microphone" ? Audio.source !== null : true
        vertical: level.height > level.width
        readout: level.ready && level.span >= Math.round(96 * root.d)
        fillColor: IrisControlOptions.accentSliders ? IrisStyle.accent : IrisStyle.fillStrong
        cornerCap: level.thickness / 2
        enabled: level.ready && !root.editing
        opacity: level.ready ? 1 : 0.45
        muted: level.moduleId === "volume" ? (Audio.sink?.audio?.muted ?? false)
            : level.moduleId === "microphone" ? Audio.micMuted : false
        icon: level.moduleId === "brightness" ? "light_mode"
            : level.moduleId === "microphone" ? (level.muted ? "mic_off" : "mic")
            : level.muted ? "volume_off" : (Audio.value ?? 0) < 0.34 ? "volume_mute" : (Audio.value ?? 0) < 0.67 ? "volume_down" : "volume_up"
        value: !level.ready ? 0 : level.moduleId === "brightness" ? level.brightness
            : level.moduleId === "microphone" ? Math.min(1, Audio.micVolume ?? 0) : Math.min(1, Audio.value ?? 0)
        Accessible.name: Translation.tr(IrisControlOptions.labelOf(level.moduleId))
        onMoved: next => {
            if (level.moduleId === "brightness") root.monitor?.setBrightness(next)
            else if (level.moduleId === "microphone") Audio.setSourceVolume(next)
            else Audio.setSinkVolume(next)
        }
        onIconClicked: {
            if (level.moduleId === "volume") Audio.toggleMute()
            else if (level.moduleId === "microphone") Audio.toggleMicMute()
        }
    }

    readonly property real capsule: Math.round(46 * root.d)
    readonly property real bar: Math.round(44 * root.d)

    Component {
        id: levelModule
        Item {
            id: single
            property string moduleId: ""
            readonly property bool upright: single.height > single.width
            LevelSlider {
                moduleId: single.moduleId
                anchors.centerIn: parent
                width: single.upright ? Math.min(single.width, Math.round(56 * root.d)) : single.width
                height: single.upright ? single.height : Math.min(single.height, Math.round(48 * root.d))
            }
            // The EQ door on the volume tile. Drag stays volume and the glyph
            // stays mute — both are taken, high-frequency gestures — so the
            // panel gets its own small, explicit target instead of a hidden
            // gesture. Top corner: the mute pocket lives at the bottom, and a
            // press-accepting MouseArea (not a TapHandler) keeps the tap from
            // leaking through into a drag start on the slider below.
            Item {
                visible: single.moduleId === "volume" && !root.editing
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: Math.round(2 * root.d)
                anchors.rightMargin: Math.round(2 * root.d)
                width: Math.round(28 * root.d)
                height: width
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "equalizer"
                    fill: 0
                    iconSize: Math.round(16 * root.d)
                    color: eqTap.containsMouse || eqTap.pressed ? IrisStyle.accent : IrisStyle.textSecondary
                    Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                }
                MouseArea {
                    id: eqTap
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        GlobalStates.irisEqualizerOpen = true
                        GlobalStates.controlPanelOpen = false
                    }
                }
                Accessible.role: Accessible.Button
                Accessible.name: Translation.tr("Open equalizer")
            }
        }
    }

    Component {
        id: levelsModule
        Item {
            id: group
            property string moduleId: "levels"
            readonly property var ids: IrisControlOptions.levelIds.filter(id => id !== "microphone" || Audio.source !== null)
            readonly property int count: Math.max(1, group.ids.length)
            readonly property real space: Math.round(10 * root.d)
            readonly property bool upright: group.height >= group.width * 0.6
            readonly property bool stacked: !group.upright && group.height >= group.count * Math.round(30 * root.d) + (group.count - 1) * group.space
            readonly property real along: group.upright ? Math.min(root.capsule, (group.width - (group.count - 1) * group.space) / group.count)
                : group.stacked ? Math.min(root.bar, (group.height - (group.count - 1) * group.space) / group.count)
                : (group.width - (group.count - 1) * group.space) / group.count
            Grid {
                anchors.centerIn: parent
                columns: group.stacked ? 1 : group.count
                columnSpacing: group.space
                rowSpacing: group.stacked && group.count > 1
                    ? Math.max(group.space, (group.height - group.count * group.along) / (group.count - 1)) : group.space
                Repeater {
                    model: group.ids
                    delegate: LevelSlider {
                        required property string modelData
                        moduleId: modelData
                        width: group.upright ? group.along : group.stacked ? group.width : group.along
                        height: group.upright ? group.height : group.stacked ? group.along : Math.min(group.height, root.bar)
                    }
                }
            }
        }
    }

    Component {
        id: mediaModule
        Rectangle {
            id: nowPlaying
            property string moduleId: "media"
            readonly property bool strip: nowPlaying.height < root.unit * 1.5
            readonly property bool wide: !nowPlaying.strip && nowPlaying.width > nowPlaying.height * 1.6
            readonly property real pad: Math.round((nowPlaying.strip ? 8 : 12) * root.d)
            readonly property bool hasPlayer: MprisController.activePlayer !== null && MprisController.activePlayer !== undefined
            radius: nowPlaying.strip && IrisControlOptions.roundControls ? height / 2 : IrisStyle.radiusPlate
            color: IrisStyle.fillQuiet
            clip: true
            PlayerBase { id: media; player: MprisController.activePlayer; positionUpdatesActive: nowPlaying.visible }
            Loader {
                anchors.fill: parent
                active: nowPlaying.hasPlayer && (Config.options?.iris?.player?.artworkBackground ?? true)
                    && MediaArtwork.displaySource.length > 0
                sourceComponent: IrisMediaBackdrop { source: MediaArtwork.displaySource; radius: nowPlaying.radius }
            }
            GridLayout {
                anchors.fill: parent
                anchors.margins: nowPlaying.pad
                flow: nowPlaying.strip || nowPlaying.wide ? GridLayout.LeftToRight : GridLayout.TopToBottom
                columns: nowPlaying.strip || nowPlaying.wide ? 3 : 1
                rows: nowPlaying.strip || nowPlaying.wide ? 1 : 3
                columnSpacing: Math.round(12 * root.d)
                rowSpacing: Math.round(4 * root.d)
                IrisArtwork {
                    readonly property real side: nowPlaying.strip ? nowPlaying.height - 2 * nowPlaying.pad
                        : nowPlaying.wide ? nowPlaying.height - 2 * nowPlaying.pad : Math.round(40 * root.d)
                    Layout.preferredWidth: side
                    Layout.preferredHeight: side
                    Layout.alignment: nowPlaying.strip || nowPlaying.wide ? Qt.AlignVCenter : Qt.AlignLeft | Qt.AlignTop
                    source: MediaArtwork.displaySource
                    circular: (Config.options?.iris?.player?.roundCover ?? false) && !nowPlaying.wide
                    radius: circular ? width / 2 : IrisStyle.radiusTile
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: !nowPlaying.strip
                    Layout.maximumWidth: Number.POSITIVE_INFINITY
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0
                    Item { Layout.fillHeight: true; visible: !nowPlaying.strip }
                    IrisText {
                        Layout.fillWidth: true
                        text: nowPlaying.hasPlayer ? media.effectiveTitle : Translation.tr("Not playing")
                        font.pixelSize: (nowPlaying.wide ? 14 : 13) * IrisStyle.typeScale
                        font.weight: IrisStyle.weight(Font.DemiBold)
                        elide: Text.ElideRight
                    }
                    IrisText {
                        Layout.fillWidth: true
                        text: nowPlaying.hasPlayer ? media.effectiveArtist : Translation.tr("Music will show here")
                        color: IrisStyle.textSecondary
                        font.pixelSize: IrisStyle.typeMeta
                        elide: Text.ElideRight
                    }
                    Transport {
                        visible: !nowPlaying.strip
                        Layout.fillWidth: true
                        Layout.topMargin: Math.round(4 * root.d)
                        player: media
                        live: nowPlaying.hasPlayer
                    }
                }
                Transport {
                    visible: nowPlaying.strip
                    Layout.preferredWidth: Math.round(112 * root.d)
                    player: media
                    live: nowPlaying.hasPlayer
                }
            }
        }
    }

    component Transport: RowLayout {
        id: transport
        property var player: null
        property bool live: false
        spacing: 0
        Repeater {
            model: [
                { glyph: "fast_rewind", action: "previous" },
                { glyph: transport.player?.effectiveIsPlaying ? "pause" : "play_arrow", action: "toggle" },
                { glyph: "fast_forward", action: "next" }
            ]
            IrisButton {
                id: transportButton
                required property var modelData
                Layout.fillWidth: true
                quiet: true
                enabled: transport.live && !root.editing
                implicitHeight: Math.round(30 * root.d)
                buttonRadius: height / 2
                Accessible.name: transportButton.modelData.action
                onClicked: transportButton.modelData.action === "previous" ? transport.player.previous()
                    : transportButton.modelData.action === "next" ? transport.player.next() : transport.player.togglePlaying()
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: transportButton.modelData.glyph
                    fill: 1
                    iconSize: Math.round((transportButton.modelData.action === "toggle" ? 26 : 20) * root.d)
                    color: transport.live ? IrisStyle.text : IrisStyle.textTertiary
                }
            }
        }
    }
}
