pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.frame
import qs.modules.iris.pieces
import qs.modules.iris.settings
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.field as Field

// Customize iRiS on the shell itself. The Island grows an edit capsule (Themes, Look, Pieces, undo, redo,
// Done); each tool is a sheet grown from the capsule; touching anything on screen grows its inspector out
// of that object. Every one of them is a body of the chassis field, so they join what they grew from.
Item {
    id: root

    property var screenData: null
    // The chassis field's bodies: what the pointer is over, and what is selected, is outlined from them.
    property var shapes: []
    readonly property real d: IrisStyle.density
    readonly property bool present: GlobalStates.irisEdit
    // The capsule and its sheets appear and leave in place, with no morph: sliding under the Island and
    // folding back into the capsule read as being swallowed.
    readonly property bool shown: root.entered && root.present
    // Shown on the turn after loading, so the compositor's blur never lands ahead of the body's tint.
    property bool entered: false
    Timer { id: enterTimer; interval: 0; onTriggered: root.entered = true }

    // ── What is open ─────────────────────────────────────────────────────
    property string tool: ""
    property string lookTab: "material"
    onToolChanged: sheetFlick.contentY = 0
    onLookTabChanged: sheetFlick.contentY = 0
    readonly property var lookTabs: [
        { id: "material", label: "Material" }, { id: "colour", label: "Colour" }, { id: "type", label: "Type" },
        { id: "motion", label: "Motion" }, { id: "bodies", label: "Cards" }, { id: "places", label: "Panels" },
        { id: "transients", label: "Feedback" }, { id: "desktop", label: "Desktop" }
    ]
    function openTool(name: string): void {
        GlobalStates.irisEditSelection = ""
        if (GlobalStates.irisEditTarget === "island" || GlobalStates.irisEditTarget === "dock") GlobalStates.irisEditTarget = ""
        root.tool = root.tool === name ? "" : name
    }
    function route(target: string): void {
        if (target.length === 0 || target === "island" || target === "dock") return
        if (target === "themes") root.tool = "themes"
        else if (target === "pieces") root.tool = "pieces"
        else if (root.lookTabs.some(tab => tab.id === target)) { root.lookTab = target; root.tool = "look" }
    }
    Connections {
        target: GlobalStates
        function onIrisEditTargetChanged(): void { root.route(GlobalStates.irisEditTarget) }
        function onIrisEditChanged(): void { if (!GlobalStates.irisEdit) root.tool = "" }
    }
    Component.onCompleted: {
        root.route(GlobalStates.irisEditTarget)
        enterTimer.start()
    }
    // Escape folds the innermost thing open; false when there was nothing left but the mode itself.
    function fold(): bool {
        if (root.inspecting) { GlobalStates.irisEditSelection = ""; GlobalStates.irisEditTarget = ""; return true }
        if (root.tool.length > 0) { root.tool = ""; return true }
        return false
    }

    // ── Selection on screen ──────────────────────────────────────────────
    function labelFor(id: string): string {
        if (id === "island") return Translation.tr("Island")
        if (id === "dock") return Translation.tr("Dock")
        if (id.startsWith("satellite:")) return Translation.tr(IrisPieces.labelOf(id.slice(10)))
        if (id.startsWith("piece:")) {
            const slot = id.slice(6)
            return IrisPieces.isApp(slot) ? IrisPieces.appIdOf(slot) : Translation.tr(IrisPieces.labelOf(slot.replace(/^extra-/, "")))
        }
        return ""
    }
    readonly property string selectedId: {
        const target = GlobalStates.irisEditTarget
        if (target === "island" || target === "dock") return target
        const selection = GlobalStates.irisEditSelection
        if (selection.length === 0) return ""
        if (["left", "right", "utility"].includes(selection)) return "satellite:" + selection
        return "piece:" + selection.replace(/^extra:/, "extra-")
    }
    function shapeAt(x: real, y: real): var {
        let best = null
        for (const shape of root.shapes ?? []) {
            if (root.labelFor(String(shape.id ?? "")).length === 0) continue
            if (x < shape.x || y < shape.y || x > shape.x + shape.width || y > shape.y + shape.height) continue
            if (!best || shape.width * shape.height < best.width * best.height) best = shape
        }
        return best
    }
    // The Dock is entered like a group: until it (or something in it) is selected, pointing at an app names the Dock,
    // which is what a click there selects (IrisDock.editSelect).
    readonly property bool dockEntered: root.selectedId === "dock" || Boolean(root.selected?.inDock)
    readonly property var hovered: {
        if (!root.present || !pointer.hovered) return null
        const hit = root.shapeAt(pointer.point.position.x, pointer.point.position.y)
        if (hit?.inDock && !root.dockEntered) return root.shapeOf("dock") ?? hit
        return hit
    }
    // A piece has two shapes under one id: its body in the field (melted into the edge, it reaches the edge) and
    // its face. The ring goes around the face, the last one listed, as the hover does.
    function shapeOf(id: string): var {
        const list = root.shapes ?? []
        for (let i = list.length - 1; i >= 0; i--) if (list[i].id === id) return list[i]
        return null
    }
    // A piece that is not on screen (off, or carried out of sight) is still selectable: its inspector grows from
    // the capsule, with no ring and no knob, so it can be switched on or placed.
    readonly property var selected: {
        if (!root.present || root.selectedId.length === 0) return null
        const face = root.shapeOf(root.selectedId)
        if (face || !root.selectedId.startsWith("piece:")) return face
        return { id: root.selectedId, orphan: true, x: root.capsuleX, y: root.capsuleY, width: root.capsuleW, height: root.capsuleH, radius: root.capsuleH / 2 }
    }
    readonly property bool inspecting: root.selected !== null
    onInspectingChanged: if (root.inspecting) root.tool = ""
    readonly property string selectionKind: GlobalStates.irisEditSelection.replace(/^extra[:-]/, "")
    readonly property var inspectorSpecs: {
        Config.revision
        const id = root.selectedId
        // An app or piece in the Dock is shaped by the Dock: its inspector is the Dock's.
        if (id === "dock" || root.selected?.inDock) return IrisOptions.studio.filter(spec => spec.target === "dock")
        if (id === "island") return IrisOptions.studio.filter(spec => spec.target === "island")
        if (id.length === 0) return []
        const own = IrisPieces.isApp(GlobalStates.irisEditSelection) ? []
            : IrisOptions.behaviour.filter(spec => spec.piece === root.selectionKind)
                .map(spec => Object.assign({}, spec, { group: spec.group ?? root.labelFor(id) }))
        return own.length > 0 ? own : IrisOptions.studio.filter(spec => spec.target === "pieces")
    }
    HoverHandler { id: pointer; enabled: root.present }
    Outline { shape: root.selected?.orphan ? null : root.selected; strong: true }
    Outline { shape: root.hovered && root.hovered.id !== root.selectedId ? root.hovered : null; strong: false }

    // ── Geometry ─────────────────────────────────────────────────────────
    readonly property var island: GlobalStates.irisIslandGeometry?.[root.screenData?.name ?? ""] ?? null
    readonly property string edge: root.island ? String(root.island.edge ?? (root.island.bottomEdge ? "bottom" : "top")) : "top"
    readonly property bool vertical: root.edge === "left" || root.edge === "right"
    readonly property real gap: Math.round(8 * root.d)
    readonly property real lo: IrisFrame.band + Math.round(12 * root.d)
    function clampX(x: real, w: real): real { return Math.round(Math.max(root.lo, Math.min(root.width - root.lo - w, x))) }
    function clampY(y: real, h: real): real { return Math.round(Math.max(root.lo, Math.min(root.height - root.lo - h, y))) }

    readonly property real capsuleW: Math.round(capsuleRow.implicitWidth + 12 * root.d)
    readonly property real capsuleH: Math.round(44 * root.d)
    readonly property real islandX: root.island ? root.island.x : root.width / 2
    readonly property real islandY: root.island ? root.island.y : 0
    readonly property real islandW: root.island ? root.island.width : 0
    readonly property real islandH: root.island ? root.island.height : Math.round(40 * root.d)
    readonly property real capsuleRestX: root.edge === "left" ? root.islandX + root.islandW + root.gap
        : root.edge === "right" ? root.islandX - root.gap - root.capsuleW
        : root.clampX(root.islandX + root.islandW / 2 - root.capsuleW / 2, root.capsuleW)
    readonly property real capsuleRestY: root.edge === "bottom" ? root.islandY - root.gap - root.capsuleH
        : root.edge === "top" ? root.islandY + root.islandH + root.gap
        : root.clampY(root.islandY + root.islandH / 2 - root.capsuleH / 2, root.capsuleH)
    readonly property real capsuleX: root.capsuleRestX
    readonly property real capsuleY: root.capsuleRestY

    readonly property bool sheetShown: root.shown && root.tool.length > 0
    readonly property real sheetW: Math.min(root.width - 2 * root.lo, Math.round((root.tool === "themes" ? 640 : root.tool === "look" ? 600 : 520) * root.d))
    // Room on the side the sheet grows toward: away from the edge the Island rests on.
    readonly property real sheetRoom: root.vertical ? root.height
        : root.edge === "bottom" ? root.capsuleRestY - root.gap - root.lo
        : root.height - root.capsuleRestY - root.capsuleH
    readonly property real sheetMaxH: Math.round(Math.min(root.sheetRoom, root.height * 0.62))
    readonly property real sheetFullH: Math.min(root.sheetMaxH, sheetContent.implicitHeight + Math.round(32 * root.d))
    readonly property real sheetLiveW: root.sheetW
    readonly property real sheetH: Math.round(root.sheetFullH)
    readonly property real sheetX: root.edge === "left" ? root.capsuleX + root.capsuleW + root.gap
        : root.edge === "right" ? root.capsuleX - root.gap - root.sheetLiveW
        : root.clampX(root.capsuleX + root.capsuleW / 2 - root.sheetLiveW / 2, root.sheetLiveW)
    readonly property real sheetY: root.edge === "top" ? root.capsuleY + root.capsuleH + root.gap
        : root.edge === "bottom" ? root.capsuleY - root.gap - root.sheetH
        : root.clampY(root.capsuleY + root.capsuleH / 2 - root.sheetH / 2, root.sheetH)

    IrisSpring { id: inspectorSpring; surface: "cards"; to: root.shown && root.inspecting ? 1 : 0; intent: "auto"; minimum: 0 }
    readonly property real inspectorP: inspectorSpring.value
    // The inspector grows from what was touched, but leaves with the mode at once, never after the capsule.
    readonly property bool inspectorShown: root.shown && root.inspectorP > 0.002
    property var anchorShape: null
    // Latched a tick later: the shapes `selected` is found in include the inspector's own body.
    onSelectedChanged: anchorLatch.restart()
    Timer {
        id: anchorLatch
        interval: 0
        onTriggered: {
            const shape = root.selected
            if (!shape) return
            const held = root.anchorShape
            if (!held || held.id !== shape.id || held.x !== shape.x || held.y !== shape.y
                    || held.width !== shape.width || held.height !== shape.height)
                root.anchorShape = shape
            const body = String(shape.id) === "island" || shape.orphan ? "editcapsule" : root.holderOf(shape)
            if (body !== root.anchorBody) root.anchorBody = body
        }
    }
    // The Island's own options grow from the capsule it grew, never from the same edge as the capsule.
    readonly property bool fromCapsule: String(root.anchorShape?.id ?? "") === "island" || Boolean(root.anchorShape?.orphan)
    readonly property var a: root.fromCapsule
        ? ({ x: root.capsuleX, y: root.capsuleY, width: root.capsuleW, height: root.capsuleH, id: "editcapsule" })
        : root.anchorShape ?? ({ x: root.width / 2, y: root.height / 2, width: 0, height: 0 })
    // A plated piece is part of its plate in the field: the inspector joins the body that really holds it.
    // Resolved when the selection lands, not bound: the shapes include the inspector's own body.
    property string anchorBody: ""
    function holderOf(shape: var): string {
        const id = String(shape?.id ?? "")
        if (!id.startsWith("piece:")) return id
        const cx = shape.x + shape.width / 2, cy = shape.y + shape.height / 2
        const holder = (root.shapes ?? []).find(body => !String(body.id ?? "").startsWith("piece:") && body.paints
            && !["editcapsule", "editsheet", "inspector"].includes(String(body.id ?? ""))
            && cx >= body.x && cx <= body.x + body.width && cy >= body.y && cy <= body.y + body.height)
        return holder ? String(holder.id) : id
    }
    // Out of the object toward the middle of the screen, away from the edge it rests on.
    readonly property string inspectorSide: {
        if (root.fromCapsule) return ({ top: "down", bottom: "up", left: "right", right: "left" })[root.edge] ?? "down"
        const cx = root.a.x + root.a.width / 2, cy = root.a.y + root.a.height / 2
        const near = [{ side: "down", gap: cy }, { side: "up", gap: root.height - cy }, { side: "right", gap: cx }, { side: "left", gap: root.width - cx }]
        near.sort((p, q) => p.gap - q.gap)
        return near[0].side
    }
    readonly property real inspectorW: Math.min(root.width - 2 * root.lo, Math.round(380 * root.d))
    // Room on the side it grows toward, past the capsule when the capsule is in the way.
    readonly property real inspectorRoom: root.inspectorSide === "up" ? root.a.y - root.gap - root.lo
        : root.inspectorSide === "down" ? root.height - root.lo - (root.a.y + root.a.height + root.gap)
        : root.height - 2 * root.lo
    readonly property real inspectorFullH: Math.max(Math.round(120 * root.d), Math.min(Math.round(root.height * 0.64), root.inspectorRoom,
        inspectorContent.implicitHeight + Math.round(28 * root.d)))
    readonly property real inspectorH: Math.round(Math.max(Math.round(36 * root.d), root.inspectorFullH * root.inspectorP))
    readonly property real inspectorRawX: root.inspectorSide === "right" ? Math.round(root.a.x + root.a.width + root.gap)
        : root.inspectorSide === "left" ? Math.round(root.a.x - root.gap - root.inspectorW)
        : root.clampX(root.a.x + root.a.width / 2 - root.inspectorW / 2, root.inspectorW)
    readonly property real inspectorRawY: root.inspectorSide === "down" ? Math.round(root.a.y + root.a.height + root.gap)
        : root.inspectorSide === "up" ? Math.round(root.a.y - root.gap - root.inspectorH)
        : root.clampY(root.a.y + root.a.height / 2 - root.inspectorFullH / 2, root.inspectorFullH)
    // Bodies never stack: an inspector that would land on the capsule moves on past it, the way it grows.
    readonly property bool overCapsule: !root.fromCapsule
        && root.inspectorRawX < root.capsuleX + root.capsuleW && root.inspectorRawX + root.inspectorW > root.capsuleX
        && root.inspectorRawY < root.capsuleY + root.capsuleH && root.inspectorRawY + root.inspectorFullH > root.capsuleY
    readonly property real inspectorX: !root.overCapsule ? root.inspectorRawX
        : root.inspectorSide === "right" ? Math.max(root.inspectorRawX, root.capsuleX + root.capsuleW + root.gap)
        : root.inspectorSide === "left" ? Math.min(root.inspectorRawX, root.capsuleX - root.gap - root.inspectorW)
        : root.inspectorRawX
    readonly property real inspectorY: !root.overCapsule ? root.inspectorRawY
        : root.inspectorSide === "down" ? Math.max(root.inspectorRawY, root.capsuleY + root.capsuleH + root.gap)
        : root.inspectorSide === "up" ? Math.min(root.inspectorRawY, root.capsuleY - root.gap - root.inspectorH)
        : root.inspectorRawY

    readonly property var capsuleRect: root.shown ? Qt.rect(root.capsuleX, root.capsuleY, root.capsuleW, root.capsuleH) : Qt.rect(0, 0, 0, 0)
    readonly property var sheetRect: root.sheetShown ? Qt.rect(root.sheetX, root.sheetY, root.sheetLiveW, root.sheetH) : Qt.rect(0, 0, 0, 0)
    readonly property var inspectorRect: root.inspectorShown ? Qt.rect(root.inspectorX, root.inspectorY, root.inspectorW, root.inspectorH) : Qt.rect(0, 0, 0, 0)
    readonly property var hitRect: root.capsuleRect
    readonly property var fieldShapes: {
        if (!root.shown) return []
        const out = [{ x: root.capsuleX, y: root.capsuleY, width: root.capsuleW, height: root.capsuleH,
            radius: root.capsuleH / 2, fuse: IrisStyle.fuse, paints: true, id: "editcapsule", joins: "island" }]
        if (root.sheetShown) out.push({ x: root.sheetX, y: root.sheetY, width: root.sheetLiveW, height: root.sheetH,
            radius: Math.min(IrisStyle.radiusSheet, root.sheetH / 2), fuse: IrisStyle.fuse, paints: true, id: "editsheet", joins: "editcapsule" })
        if (root.inspectorShown) out.push({ x: root.inspectorX, y: root.inspectorY, width: root.inspectorW, height: root.inspectorH,
            radius: Math.min(IrisStyle.radiusCard, root.inspectorH / 2), fuse: IrisStyle.fuse, paints: true, id: "inspector",
            joins: root.anchorBody })
        return out
    }

    // ── The capsule ──────────────────────────────────────────────────────
    Item {
        x: root.capsuleX
        y: root.capsuleY
        width: root.capsuleW
        height: root.capsuleH
        visible: root.shown
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
        RowLayout {
            id: capsuleRow
            anchors.centerIn: parent
            spacing: Math.round(2 * root.d)
            ToolChip { glyph: "style"; label: Translation.tr("Themes"); on: root.tool === "themes"; onActivated: root.openTool("themes") }
            ToolChip { glyph: "palette"; label: Translation.tr("Look"); on: root.tool === "look"; onActivated: root.openTool("look") }
            ToolChip { glyph: "add_circle"; label: Translation.tr("Pieces"); on: root.tool === "pieces"; onActivated: root.openTool("pieces") }
            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: Math.round(20 * root.d); Layout.leftMargin: Math.round(4 * root.d); Layout.rightMargin: Math.round(4 * root.d); color: IrisStyle.hairline }
            IrisIconButton { materialIcon: "undo"; enabled: IrisEditHistory.undoStack.length > 0; opacity: enabled ? 1 : 0.35; Accessible.name: Translation.tr("Undo"); onClicked: IrisEditHistory.undo() }
            IrisIconButton { materialIcon: "redo"; enabled: IrisEditHistory.redoStack.length > 0; opacity: enabled ? 1 : 0.35; Accessible.name: Translation.tr("Redo"); onClicked: IrisEditHistory.redo() }
            IrisIconButton {
                materialIcon: "view_sidebar"
                Accessible.name: Translation.tr("Open in Studio")
                onClicked: {
                    GlobalStates.irisStudioTarget = root.tool === "look" ? root.lookTab : root.tool
                    GlobalStates.irisStudioOpen = true
                }
            }
            IrisText {
                visible: IrisEditHistory.notice.length > 0
                Layout.leftMargin: Math.round(4 * root.d)
                text: IrisEditHistory.notice
                color: IrisStyle.textSecondary
                font.pixelSize: IrisStyle.typeMeta
            }
            IrisButton {
                Layout.leftMargin: Math.round(6 * root.d)
                emphasized: true
                text: Translation.tr("Done")
                implicitHeight: Math.round(32 * root.d)
                buttonRadius: height / 2
                onClicked: GlobalStates.irisEdit = false
            }
        }
    }

    // ── The tool sheet ───────────────────────────────────────────────────
    Item {
        x: root.sheetX
        y: root.sheetY
        width: root.sheetLiveW
        height: root.sheetH
        visible: root.sheetShown
        clip: true
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: root.edge === "bottom" ? undefined : parent.top
            anchors.bottom: root.edge === "bottom" ? parent.bottom : undefined
            width: root.sheetW
            height: root.sheetFullH
            Flickable {
                id: sheetFlick
                anchors.fill: parent
                anchors.margins: Math.round(16 * root.d)
                contentHeight: sheetContent.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                ScrollBar.vertical: IrisScrollBar {}
                ColumnLayout {
                    id: sheetContent
                    width: sheetFlick.width
                    spacing: Math.round(12 * root.d)
                    Loader {
                        Layout.fillWidth: true
                        active: root.tool === "themes"
                        visible: active
                        sourceComponent: themesSheet
                    }
                    Loader {
                        Layout.fillWidth: true
                        active: root.tool === "look"
                        visible: active
                        sourceComponent: lookSheet
                    }
                    Loader {
                        Layout.fillWidth: true
                        active: root.tool === "pieces"
                        visible: active
                        sourceComponent: ColumnLayout {
                            spacing: Math.round(12 * root.d)
                            TipLine { Layout.fillWidth: true; area: "pieces" }
                            IrisPieceLibrary { Layout.fillWidth: true }
                        }
                    }
                }
            }
        }
    }

    // ── The inspector of what is selected ────────────────────────────────
    Item {
        x: root.inspectorX
        y: root.inspectorY
        width: root.inspectorW
        height: root.inspectorH
        visible: root.inspectorShown
        clip: true
        opacity: IrisStyle.contentAt(root.inspectorP)
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
        Flickable {
            id: inspectorFlick
            anchors.fill: parent
            anchors.margins: Math.round(14 * root.d)
            contentHeight: inspectorContent.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            ScrollBar.vertical: IrisScrollBar {}
            ColumnLayout {
                id: inspectorContent
                width: inspectorFlick.width
                spacing: Math.round(10 * root.d)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(8 * root.d)
                    IrisText {
                        Layout.fillWidth: true
                        Layout.leftMargin: Math.round(4 * root.d)
                        text: root.labelFor(String(root.anchorShape?.id ?? ""))
                        font.family: IrisStyle.fontTitle
                        font.pixelSize: IrisStyle.typeHeadline
                        font.weight: IrisStyle.weight(Font.DemiBold)
                        elide: Text.ElideRight
                    }
                    IrisIconButton {
                        materialIcon: "close"
                        Accessible.name: Translation.tr("Close")
                        onClicked: { GlobalStates.irisEditSelection = ""; GlobalStates.irisEditTarget = "" }
                    }
                }
                IrisEditRows {
                    Layout.fillWidth: true
                    specs: root.inspectorSpecs
                    tint: IrisOptions.customizeArea(root.selectedId === "dock" ? "dock" : root.selectedId === "island" ? "island" : "pieces").tint
                }
            }
        }
    }

    // ── Sheets ───────────────────────────────────────────────────────────
    Component {
        id: themesSheet
        ColumnLayout {
            id: themes
            property string filter: "all"
            readonly property var list: IrisThemes.all.filter(theme => themes.filter === "all" || (theme.tags ?? []).includes("anime"))
            spacing: Math.round(12 * root.d)
            TipLine { Layout.fillWidth: true; area: "themes" }
            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(6 * root.d)
                ToolChip { glyph: ""; label: Translation.tr("All"); on: themes.filter === "all"; onActivated: themes.filter = "all" }
                ToolChip { glyph: ""; label: Translation.tr("Anime"); on: themes.filter === "anime"; onActivated: themes.filter = "anime" }
                Item { Layout.fillWidth: true }
                ColoursOnly { Layout.rightMargin: Math.round(6 * root.d) }
                IrisButton {
                    quiet: true
                    text: Translation.tr("Paste")
                    buttonRadius: height / 2
                    onClicked: {
                        const theme = IrisThemes.importText(String(Quickshell.clipboardText ?? ""))
                        IrisEditHistory.say(theme ? Translation.tr("Imported “%1”").arg(theme.name) : Translation.tr("The clipboard does not hold an iRiS theme"))
                    }
                }
                IrisButton {
                    text: Translation.tr("Save current")
                    buttonRadius: height / 2
                    onClicked: {
                        IrisThemes.save(Translation.tr("My theme %1").arg(IrisThemes.all.filter(theme => theme.user).length + 1), "")
                        IrisEditHistory.say(Translation.tr("Saved as a theme"))
                    }
                }
            }
            GridLayout {
                id: cells
                Layout.fillWidth: true
                columns: 3
                rowSpacing: Math.round(12 * root.d)
                columnSpacing: Math.round(10 * root.d)
                Repeater {
                    model: themes.list
                    IrisThemeCard {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: (cells.width - 2 * cells.columnSpacing) / 3
                        theme: modelData
                        screen: root.screenData
                        onShareRequested: {
                            Quickshell.clipboardText = IrisThemes.exportText(modelData)
                            IrisEditHistory.say(Translation.tr("Copied “%1”, paste it anywhere to share it").arg(modelData.name))
                        }
                    }
                }
            }
        }
    }

    Component {
        id: lookSheet
        ColumnLayout {
            spacing: Math.round(12 * root.d)
            Flow {
                Layout.fillWidth: true
                spacing: Math.round(4 * root.d)
                Repeater {
                    model: root.lookTabs
                    ToolChip {
                        required property var modelData
                        glyph: ""
                        label: Translation.tr(modelData.label)
                        on: root.lookTab === modelData.id
                        onActivated: root.lookTab = modelData.id
                    }
                }
            }
            RowLayout {
                visible: root.lookTab === "material"
                Layout.fillWidth: true
                spacing: Math.round(6 * root.d)
                Repeater {
                    model: ["iris", "soft", "round", "crisp", "angular", "contrast"]
                    IrisPresetTile {
                        required property string modelData
                        Layout.fillWidth: true
                        name: modelData
                    }
                }
            }
            TipLine { Layout.fillWidth: true; area: root.lookTab }
            IrisEditRows {
                Layout.fillWidth: true
                specs: IrisOptions.studio.filter(spec => spec.target === root.lookTab)
                tint: IrisOptions.customizeArea(root.lookTab).tint
            }
        }
    }

    // ── Parts ────────────────────────────────────────────────────────────
    // Choosing a theme can take only its colours (iris.appearance.themeColoursOnly), said beside the switch.
    component ColoursOnly: RowLayout {
        spacing: Math.round(8 * root.d)
        IrisText {
            text: Translation.tr("Colours only")
            color: IrisThemes.coloursOnly ? IrisStyle.text : IrisStyle.subtext
            font.pixelSize: IrisStyle.typeLabel
        }
        IrisSwitch {
            on: IrisThemes.coloursOnly
            name: Translation.tr("Colours only")
            onToggled: Config.setNestedValue("iris.appearance.themeColoursOnly", !IrisThemes.coloursOnly)
        }
    }
    // One line worth knowing about an area, marked in its colour (IrisOptions.customizeAreas).
    component TipLine: RowLayout {
        id: tipLine
        property string area: ""
        readonly property string tip: IrisOptions.customizeTip(tipLine.area)
        visible: tipLine.tip.length > 0
        spacing: Math.round(6 * root.d)
        MaterialSymbol {
            Layout.alignment: Qt.AlignTop
            text: "lightbulb"
            fill: 1
            iconSize: Math.round(14 * root.d)
            color: IrisOptions.customizeArea(tipLine.area).tint
        }
        IrisText {
            Layout.fillWidth: true
            text: tipLine.tip
            color: IrisStyle.muted
            font.pixelSize: IrisStyle.typeFootnote
            wrapMode: Text.WordWrap
        }
    }

    component ToolChip: MouseArea {
        id: chip
        property string glyph: ""
        property string label: ""
        property bool on: false
        signal activated()
        implicitWidth: chipRow.implicitWidth + Math.round(22 * root.d)
        implicitHeight: Math.round(32 * root.d)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: chip.label
        Accessible.checked: chip.on
        onClicked: chip.activated()
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: chip.on ? IrisStyle.tintFill(IrisStyle.accent) : chip.containsMouse ? IrisStyle.fillHover : "transparent"
            Behavior on color { ColorAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
        }
        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: Math.round(6 * root.d)
            MaterialSymbol {
                visible: chip.glyph.length > 0
                text: chip.glyph
                fill: chip.on ? 1 : 0
                iconSize: Math.round(17 * root.d)
                color: chip.on ? IrisStyle.accent : IrisStyle.text
            }
            IrisText {
                text: chip.label
                color: chip.on ? IrisStyle.accent : IrisStyle.text
                font.pixelSize: IrisStyle.typeLabel
                font.weight: IrisStyle.weight(chip.on ? Font.DemiBold : Font.Medium)
            }
        }
    }

    // An outline ring on a body of the chassis; hovered, its name on a capsule beside it.
    component Outline: Item {
        id: outline
        property var shape: null
        property bool strong: false
        readonly property real gap: Math.round(3 * root.d)
        readonly property bool below: (outline.shape?.y ?? 0) + (outline.shape?.height ?? 0) / 2 < root.height / 2
        // A piece is labelled beside itself, toward the middle; a wide body under or over it.
        readonly property bool beside: (outline.shape?.width ?? 0) < 2 * (outline.shape?.height ?? 0)
        readonly property bool toRight: (outline.shape?.x ?? 0) + (outline.shape?.width ?? 0) / 2 < root.width / 2
        visible: outline.shape !== null
        opacity: outline.shape !== null ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
        x: Math.round((outline.shape?.x ?? 0) - outline.gap)
        y: Math.round((outline.shape?.y ?? 0) - outline.gap)
        width: Math.round((outline.shape?.width ?? 0) + 2 * outline.gap)
        height: Math.round((outline.shape?.height ?? 0) + 2 * outline.gap)
        // A body melted into the edge has no side there: its ring opens toward the edge and stops at the band,
        // so it follows the silhouette instead of closing a capsule inside it or across the frame.
        readonly property real band: IrisFrame.band
        // A piece's face is a disc: its ring stays whole, it reads better than arms up to the band.
        readonly property bool opens: outline.shape !== null && !String(outline.shape.id ?? "").startsWith("piece:")
        readonly property bool edgeTop: outline.opens && outline.shape.y <= outline.band + 1
        readonly property bool edgeBottom: outline.opens && outline.shape.y + outline.shape.height >= root.height - outline.band - 1
        readonly property bool edgeLeft: outline.opens && outline.shape.x <= outline.band + 1
        readonly property bool edgeRight: outline.opens && outline.shape.x + outline.shape.width >= root.width - outline.band - 1
        readonly property real ringRadius: Number(outline.shape?.radius ?? 0) + outline.gap
        readonly property int openSides: (outline.edgeTop ? 1 : 0) + (outline.edgeBottom ? 1 : 0) + (outline.edgeLeft ? 1 : 0) + (outline.edgeRight ? 1 : 0)
        readonly property color ringColor: outline.strong ? IrisStyle.accent : Qt.alpha(IrisStyle.accent, 0.55) // iris-literal: a hover ring is the selection ring at half strength
        readonly property real ringWidth: Math.max(1, Math.round((outline.strong ? 2 : 1.5) * root.d))
        // A body melted into its edge is outlined by the field itself: the same body, grown by the ring's gap, drawn
        // with no fill and an accent rim, joined to the same edge, so its shoulders are the body's own curves. The
        // clip stops it at the band's line; a floating body is a plain rounded ring, which is already exact.
        Item {
            id: fieldRing
            readonly property var body: outline.shape
            readonly property real bandBottom: root.height - outline.band
            readonly property real bandRight: root.width - outline.band
            readonly property real flare: Number(fieldRing.body?.fuse ?? 0) + outline.gap
            visible: outline.openSides > 0
            clip: true
            x: (outline.edgeLeft ? outline.band : (fieldRing.body?.x ?? 0) - fieldRing.flare) - outline.x
            y: (outline.edgeTop ? outline.band : (fieldRing.body?.y ?? 0) - fieldRing.flare) - outline.y
            width: (outline.edgeRight ? fieldRing.bandRight : (fieldRing.body?.x ?? 0) + (fieldRing.body?.width ?? 0) + fieldRing.flare) - outline.x - fieldRing.x
            height: (outline.edgeBottom ? fieldRing.bandBottom : (fieldRing.body?.y ?? 0) + (fieldRing.body?.height ?? 0) + fieldRing.flare) - outline.y - fieldRing.y
            readonly property var ringShapes: {
                const s = fieldRing.body
                if (!s || !fieldRing.visible) return []
                const g = outline.gap
                const joins = Array.isArray(s.joins) ? s.joins : s.joins ? [s.joins] : []
                const out = [{ id: "ring", x: s.x - g, y: s.y - g, width: s.width + 2 * g, height: s.height + 2 * g,
                    radius: Number(s.radius ?? 0) + g, fuse: Number(s.fuse ?? IrisStyle.fuse), paints: true, glass: "solid", joins: [] }]
                for (const name of joins) {
                    if (name === "frame") {
                        const deep = outline.band + 200
                        const band = outline.edgeBottom ? { x: -200, y: root.height - outline.band, width: root.width + 400, height: deep }
                            : outline.edgeTop ? { x: -200, y: outline.band - deep, width: root.width + 400, height: deep }
                            : outline.edgeRight ? { x: root.width - outline.band, y: -200, width: deep, height: root.height + 400 }
                            : { x: outline.band - deep, y: -200, width: deep, height: root.height + 400 }
                        out.push(Object.assign({ id: "ringEdge", radius: 0, fuse: 0, paints: true, glass: "solid" }, band))
                        out[0].joins.push("ringEdge")
                    } else {
                        const partner = (root.shapes ?? []).find(shape => shape.id === name)
                        if (!partner) continue
                        out.push(Object.assign({}, partner, { id: "ringJoin" + out.length, paints: true, glass: "solid", joins: [] }))
                        out[0].joins.push("ringJoin" + (out.length - 1))
                    }
                }
                return out
            }
            Field.IrisField {
                x: -fieldRing.x - outline.x
                y: -fieldRing.y - outline.y
                width: root.width
                height: root.height
                framed: false
                tint: "transparent"
                rim: outline.ringColor
                rimWidth: outline.ringWidth
                shapes: fieldRing.ringShapes
            }
        }
        Rectangle {
            visible: outline.openSides === 0
            anchors.fill: parent
            radius: outline.ringRadius
            color: "transparent"
            border.width: outline.ringWidth
            border.color: outline.ringColor
        }
        Rectangle {
            // The inspector already names what is selected; the capsule is for what the pointer is over.
            visible: !outline.strong
            readonly property real along: Math.max(IrisFrame.band + outline.gap, Math.min(root.width - width - IrisFrame.band - outline.gap,
                outline.x + (outline.width - width) / 2))
            x: !outline.beside ? Math.round(along - outline.x)
                : outline.toRight ? outline.width + outline.gap : -width - outline.gap
            y: outline.beside ? Math.round((outline.height - height) / 2)
                : outline.below ? outline.height + outline.gap : -height - outline.gap
            width: Math.round(caption.implicitWidth + 20 * root.d)
            height: Math.round(24 * root.d)
            radius: height / 2
            color: IrisStyle.bodySurface
            IrisText {
                id: caption
                anchors.centerIn: parent
                text: root.labelFor(String(outline.shape?.id ?? ""))
                color: IrisStyle.text
                font.pixelSize: IrisStyle.typeMeta
                font.weight: IrisStyle.weight(Font.DemiBold)
            }
        }
    }

    // A selected piece carries a knob on its corner toward the middle of the screen: dragging it sizes every bubble.
    readonly property bool knobShown: root.selected !== null && !root.selected.orphan && !root.selected.inDock
        && String(root.selected.id).startsWith("piece:")
    readonly property var knobRect: root.knobShown && root.shown
        ? Qt.rect(knob.x - knob.reach, knob.y - knob.reach, knob.width + 2 * knob.reach, knob.height + 2 * knob.reach) : null
    Item {
        id: knob
        readonly property var shape: root.selected
        readonly property real size: Math.round(14 * root.d)
        readonly property real reach: Math.round(6 * root.d)
        readonly property int sx: (knob.shape?.x ?? 0) + (knob.shape?.width ?? 0) / 2 < root.width / 2 ? 1 : -1
        readonly property int sy: (knob.shape?.y ?? 0) + (knob.shape?.height ?? 0) / 2 < root.height / 2 ? 1 : -1
        // On the ring's corner arc at 45°, not the corner of its box.
        readonly property real gap: Math.round(3 * root.d)
        readonly property real arc: (Number(knob.shape?.radius ?? 0) + knob.gap) * (1 - Math.SQRT1_2)
        readonly property real cornerX: (knob.shape?.x ?? 0) + (knob.sx > 0 ? (knob.shape?.width ?? 0) + knob.gap : -knob.gap) - knob.sx * knob.arc
        readonly property real cornerY: (knob.shape?.y ?? 0) + (knob.sy > 0 ? (knob.shape?.height ?? 0) + knob.gap : -knob.gap) - knob.sy * knob.arc
        visible: root.knobShown
        width: knob.size
        height: knob.size
        x: Math.round(knob.cornerX - knob.size / 2)
        y: Math.round(knob.cornerY - knob.size / 2)
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: IrisStyle.accent
            border.width: Math.max(1, Math.round(2 * root.d))
            border.color: IrisStyle.bodySurface
            scale: knobDrag.active || knobHover.hovered ? 1.25 : 1
            Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
        }
        HoverHandler { id: knobHover; cursorShape: knob.sx === knob.sy ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor }
        DragHandler {
            id: knobDrag
            target: null
            property real startScale: 100
            property IrisConfigDrag write: IrisConfigDrag { path: "iris.bubbles.scale" }
            onActiveChanged: {
                if (active) {
                    knobDrag.startScale = Number(Config.options?.iris?.bubbles?.scale ?? 100)
                } else knobDrag.write.flush()
            }
            onCentroidChanged: {
                if (!active) return
                const dx = centroid.scenePosition.x - centroid.scenePressPosition.x
                const dy = centroid.scenePosition.y - centroid.scenePressPosition.y
                // One percent per pixel along the diagonal, in steps of 5, held at 100 so the default is easy to find again.
                const raw = knobDrag.startScale + (dx * knob.sx + dy * knob.sy) / Math.SQRT2
                const stepped = Math.abs(raw - 100) < 4 ? 100 : Math.round(raw / 5) * 5
                knobDrag.write.push(Math.max(60, Math.min(140, stepped)))
            }
        }
        Rectangle {
            visible: knobDrag.active
            x: knob.sx > 0 ? knob.width + Math.round(6 * root.d) : -width - Math.round(6 * root.d)
            y: Math.round((knob.height - height) / 2)
            width: Math.round(figure.implicitWidth + 16 * root.d)
            height: Math.round(22 * root.d)
            radius: height / 2
            color: IrisStyle.accent
            IrisText {
                id: figure
                anchors.centerIn: parent
                text: Number(knobDrag.write.pending ?? Config.options?.iris?.bubbles?.scale ?? 100) + "%"
                color: IrisStyle.inkOnAccent
                font.family: IrisStyle.fontNumbers
                font.features: ({ "tnum": 1 })
                font.pixelSize: IrisStyle.typeMeta
                font.weight: IrisStyle.weight(Font.DemiBold)
            }
        }
    }
}
