pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// Every row of a piece's areas, the same on the desktop (grown out of the piece) and on the map in Settings.
Item {
    id: root

    property var entry: null
    // A desktop widget's id narrows the Widgets piece to its own rows.
    property string widget: ""
    // Rows shown first under their own group (a bubble's own behaviour).
    property var lead: []
    property string area: ""
    property string query: ""
    // Settings' own field searches every area; the inspector's searches its piece.
    property bool searchAll: false
    property bool showSearch: true
    property bool closable: false
    property string landingGroup: ""
    property string landingPath: ""
    property bool tuneAll: false
    // Host actions beside the title ("On the desktop", "Open in Settings").
    property Component extra: null
    property real pad: Math.round(14 * root.d)
    signal closeRequested()
    // The areas a hovered row lands on, for a map to light them.
    signal reaching(var sections)
    // A search result's caption opens where it lives.
    signal openArea(string section, string group, string path)

    readonly property real d: IrisStyle.settingsDensity
    readonly property var areas: (root.entry?.areas ?? []).filter(id => id !== "battery" || Battery.available)
    // A tab picked here wins over the host's area until the host asks for another one.
    property string pickedArea: ""
    onAreaChanged: root.pickedArea = ""
    readonly property string currentArea: root.areas.includes(root.pickedArea) ? root.pickedArea
        : root.areas.includes(root.area) ? root.area : (root.areas[0] ?? "")
    readonly property bool searching: root.query.trim().length > 0
    readonly property string title: root.widget.length > 0 ? Translation.tr(IrisWidgetRows.groups[root.widget] ?? root.widget) : IrisOptions.entryLabel(root.entry)
    readonly property color tint: IrisOptions.entryTint(root.entry)
    readonly property real fullHeight: head.implicitHeight + head.anchors.topMargin + rowsCol.implicitHeight + root.pad * 2
    implicitHeight: root.fullHeight
    onEntryChanged: { root.pickedArea = ""; ownQuery.text = ""; flick.contentY = 0 }
    onCurrentAreaChanged: flick.contentY = 0
    onSearchingChanged: flick.contentY = 0

    function fits(spec: var): bool {
        if (root.entry?.id !== "widget" || root.widget.length === 0) return true
        return spec.widget === root.widget || String(spec.group ?? "") === "Arranging"
    }
    function rowsOf(area: string): var {
        return IrisOptions.settings.filter(spec => spec.section === area && root.fits(spec) && IrisOptions.shown(spec))
    }
    function grouped(rows: var, captioned: bool): var {
        const out = []
        for (const spec of rows) {
            const name = String(spec.group ?? "")
            const key = (captioned ? String(spec.section) + "/" : "") + name
            if (out.length === 0 || out[out.length - 1].home !== key) {
                const area = IrisOptions.sectionById(String(spec.section ?? ""))
                const caption = captioned ? Translation.tr(area.title) + (name.length > 0 ? " · " + Translation.tr(name) : "") : Translation.tr(name)
                out.push({ home: key, key: key + "#" + out.filter(group => group.home === key).length, name: name, caption: caption, rows: [] })
            }
            out[out.length - 1].rows.push(spec)
        }
        return out
    }
    readonly property var groups: {
        Config.revision
        if (root.searching) return root.grouped(root.hits, true)
        let rows = root.rowsOf(root.currentArea)
        const order = root.entry?.lead ?? []
        if (order.length > 0 && root.currentArea === root.areas[0]) {
            const rank = spec => { const at = order.indexOf(String(spec.group ?? "")); return at < 0 ? order.length : at }
            rows = rows.map((spec, at) => ({ spec: spec, at: at })).sort((a, b) => rank(a.spec) - rank(b.spec) || a.at - b.at).map(item => item.spec)
        }
        const own = root.currentArea === root.areas[0] ? (root.lead ?? []).filter(spec => IrisOptions.shown(spec)) : []
        const ownPaths = new Set(own.map(spec => spec.path))
        return root.grouped(own.concat(rows.filter(spec => !ownPaths.has(spec.path))), false)
    }

    // Matching forgives the way Spotlight's does: word starts, the short words people type, keywords.
    readonly property var hits: {
        Config.revision
        const terms = IrisSearch.tokens(root.query)
        if (terms.length === 0) return []
        const pool = root.searchAll ? IrisOptions.settings : IrisOptions.settings.filter(spec => root.areas.includes(spec.section) && root.fits(spec))
        const scored = []
        for (const spec of pool) {
            if (spec.mirror || !IrisOptions.shown(spec)) continue
            const label = IrisSearch.tokens(Translation.tr(String(spec.label ?? "")))
            const rest = IrisSearch.tokens([Translation.tr(String(spec.group ?? "")), Translation.tr(String(spec.description ?? "")),
                (spec.keywords ?? []).join(" "), Translation.tr(IrisOptions.sectionById(String(spec.section ?? "")).title)].join(" "))
            let score = 0
            for (const term of terms) {
                const near = word => word.startsWith(term) || (term.length >= 4 && word.includes(term))
                if (label.some(near)) score += 3
                else if (rest.some(near)) score += 1
                else { score = 0; break }
            }
            if (score > 0) scored.push({ spec: spec, score: score })
        }
        scored.sort((a, b) => b.score - a.score)
        // Best first, then kept together by where they live.
        const top = scored.slice(0, 40).map(item => item.spec)
        const sections = [...new Set(top.map(spec => spec.section))]
        return sections.reduce((out, section) => out.concat(top.filter(spec => spec.section === section)), [])
    }

    function reveal(item: Item): void {
        if (!item) return
        const at = item.mapToItem(rowsCol, 0, 0).y
        flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, at - Math.round(12 * root.d)))
    }

    // ── Head: what it is, its areas, its search ─────────────────────────
    ColumnLayout {
        id: head
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.pad
        spacing: Math.round(10 * root.d)
        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(10 * root.d)
            IrisSquircle {
                Layout.preferredWidth: Math.round(26 * root.d)
                Layout.preferredHeight: Math.round(26 * root.d)
                tint: root.tint
                glyph: IrisOptions.entryGlyph(root.entry)
            }
            IrisText {
                Layout.fillWidth: true
                text: root.title
                font.family: IrisStyle.fontTitle
                font.pixelSize: IrisStyle.typeTitle
                font.weight: IrisStyle.weight(Font.DemiBold)
                elide: Text.ElideRight
            }
            IrisIconButton {
                readonly property var resettable: root.rowsOf(root.currentArea).filter(spec => String(spec.path ?? "").startsWith("iris."))
                visible: { Config.revision; return !root.searching && resettable.some(spec => IrisOptions.modified(spec)) }
                materialIcon: "restart_alt"
                Accessible.name: Translation.tr("Restore defaults")
                onClicked: resettable.forEach(spec => IrisOptions.commit(spec, spec.fallback))
            }
            IrisIconButton {
                visible: !root.searching && (root.currentArea === "lock" || root.currentArea === "controlCenter")
                materialIcon: root.currentArea === "lock" ? "visibility" : "dashboard_customize"
                Accessible.name: root.currentArea === "lock" ? Translation.tr("Rehearse it") : Translation.tr("Arrange it")
                onClicked: {
                    GlobalStates.settingsOverlayOpen = false
                    GlobalStates.irisEdit = false
                    if (root.currentArea === "lock") { GlobalStates.irisLockEdit = true; return }
                    GlobalStates.irisMorphOwner = ""
                    GlobalStates.controlPanelOpen = true
                    GlobalStates.irisControlEdit = true
                }
            }
            Loader { active: root.extra !== null; sourceComponent: root.extra; visible: active }
            IrisIconButton {
                visible: root.closable
                materialIcon: "close"
                Accessible.name: Translation.tr("Close")
                onClicked: root.closeRequested()
            }
        }
        IrisSegmented {
            Layout.fillWidth: true
            visible: root.areas.length > 1 && !root.searching
            options: root.areas.map(id => ({ label: Translation.tr(IrisOptions.sectionById(id).title), value: id }))
            current: root.currentArea
            accessibleName: root.title
            onPicked: value => root.pickedArea = value
        }
        Rectangle {
            Layout.fillWidth: true
            visible: root.showSearch
            implicitHeight: Math.round(34 * root.d)
            radius: IrisStyle.fieldChamfer ? 0 : IrisStyle.capsule(height)
            color: IrisStyle.fillQuiet
            border.width: ownQuery.activeFocus ? Math.max(1, Math.round(root.d)) : 0
            border.color: IrisStyle.hairline
            MaterialSymbol {
                id: lens
                anchors.left: parent.left
                anchors.leftMargin: Math.round(10 * root.d)
                anchors.verticalCenter: parent.verticalCenter
                text: "search"
                iconSize: Math.round(16 * root.d)
                color: IrisStyle.textTertiary
            }
            TextInput {
                id: ownQuery
                anchors.left: lens.right
                anchors.leftMargin: Math.round(8 * root.d)
                anchors.right: clear.left
                anchors.rightMargin: Math.round(6 * root.d)
                anchors.verticalCenter: parent.verticalCenter
                color: IrisStyle.text
                selectionColor: IrisStyle.accentContainer
                selectedTextColor: IrisStyle.text
                font.family: IrisStyle.fontMain
                font.pixelSize: IrisStyle.typeLabel
                clip: true
                onTextChanged: queryDelay.restart()
                Keys.onEscapePressed: event => { if (text.length > 0) text = ""; else event.accepted = false }
                Timer { id: queryDelay; interval: 120; onTriggered: if (root.showSearch) root.query = ownQuery.text }
                IrisText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: ownQuery.text.length === 0
                    text: Translation.tr("Search %1").arg(root.title)
                    color: IrisStyle.muted
                    font.pixelSize: ownQuery.font.pixelSize
                    elide: Text.ElideRight
                    width: parent.width
                }
            }
            MaterialSymbol {
                id: clear
                anchors.right: parent.right
                anchors.rightMargin: Math.round(10 * root.d)
                anchors.verticalCenter: parent.verticalCenter
                visible: ownQuery.text.length > 0
                width: visible ? implicitWidth : 0
                text: "cancel"
                fill: 1
                iconSize: Math.round(15 * root.d)
                color: IrisStyle.muted
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: ownQuery.text = "" }
            }
        }
    }

    // ── Rows ─────────────────────────────────────────────────────────────
    Flickable {
        id: flick
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: head.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: Math.round(12 * root.d)
        contentHeight: rowsCol.implicitHeight + root.pad
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: IrisScrollBar {}
        ColumnLayout {
            id: rowsCol
            x: root.pad
            width: flick.width - 2 * root.pad
            spacing: Math.round(18 * root.d)
            IrisText {
                visible: root.searching && root.hits.length === 0
                Layout.fillWidth: true
                Layout.topMargin: Math.round(12 * root.d)
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("Nothing matches “%1”").arg(root.query.trim())
                color: IrisStyle.textSecondary
                font.pixelSize: IrisStyle.typeLabel
            }
            Repeater {
                model: ScriptModel { objectProp: "key"; values: root.groups }
                Loader {
                    id: block
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    // The first cards come at once, the rest as they're ready: a long area never holds the morph.
                    asynchronous: block.index > 2
                    sourceComponent: GroupCard { model: block.modelData }
                    onLoaded: if (root.landingGroup.length > 0 && block.modelData.name === root.landingGroup) Qt.callLater(root.reveal, block)
                }
            }
        }
    }

    component GroupCard: ColumnLayout {
        id: group
        required property var model
        spacing: Math.round(6 * root.d)
        function gateOf(spec: var): string { return String(spec.visibleWhen ?? "").replace(/^!/, "").split("=")[0] }
        // A row that hangs on another row of its card reads right under it, set in.
        function hangs(spec: var, rows: var): bool {
            const gate = String(spec.visibleWhen ?? "").startsWith("!") ? "" : group.gateOf(spec)
            return !root.searching && gate.length > 0 && rows.some(other => other !== spec && String(other.path ?? "") === gate)
        }
        function nested(rows: var): var {
            if (root.searching) return rows
            const out = rows.filter(spec => !group.hangs(spec, rows))
            for (let i = 0; i < out.length; i++) {
                const kids = rows.filter(spec => spec !== out[i] && group.hangs(spec, rows) && group.gateOf(spec) === String(out[i].path ?? ""))
                out.splice(i + 1, 0, ...kids)
                i += kids.length
            }
            return out.concat(rows.filter(spec => !out.includes(spec)))
        }
        // Essentials first: two or more fine-tuning rows wait behind one row at the card's foot.
        property bool unfolded: false
        readonly property var tuned: { Config.revision; return root.searching ? [] : group.model.rows.filter(spec => IrisOptions.fineTune(spec) && !IrisOptions.changed(spec)) }
        readonly property bool folds: group.tuned.length >= 2
        readonly property bool open: group.folds && (root.tuneAll || group.unfolded
            || group.tuned.some(spec => root.landingPath.length > 0 && String(spec.path ?? "") === root.landingPath))
        readonly property var rows: group.nested(group.folds && !group.open ? group.model.rows.filter(spec => !group.tuned.includes(spec)) : group.model.rows)
        // A group that is only a switch is its name and the switch.
        readonly property bool lone: group.model.caption.length > 0 && !group.folds && group.rows.length === 1 && group.rows[0].kind === "switch" && !root.searching
        HoverHandler {
            onHoveredChanged: {
                if (!hovered) { root.reaching([]); return }
                const reach = IrisOptions.reachOf(group.model.rows)
                root.reaching([String(group.model.rows[0]?.section ?? "")].concat(reach.touches.map(one => one.id)))
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Math.round(4 * root.d)
            visible: group.model.caption.length > 0
            spacing: Math.round(10 * root.d)
            IrisText {
                Layout.fillWidth: true
                text: group.model.caption
                color: root.searching && captionLink.containsMouse ? IrisStyle.text : root.searching ? IrisStyle.textSecondary : IrisStyle.text
                font.family: IrisStyle.fontTitle
                font.pixelSize: root.searching ? IrisStyle.typeMeta : IrisStyle.typeHeadline
                font.weight: IrisStyle.weight(Font.DemiBold)
                elide: Text.ElideRight
                MouseArea {
                    id: captionLink
                    anchors.fill: parent
                    enabled: root.searching
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openArea(String(group.model.rows[0]?.section ?? ""), group.model.name, "")
                }
            }
            IrisSwitch {
                visible: group.lone
                Layout.rightMargin: Math.round(16 * root.d)
                readonly property var spec: group.rows[0] ?? ({})
                on: group.lone && (spec.invert ? !Boolean(IrisOptions.currentValue(spec)) : Boolean(IrisOptions.currentValue(spec)))
                name: group.model.caption
                onToggled: IrisOptions.commit(spec, spec.invert ? on : !on)
            }
        }
        Item {
            Layout.fillWidth: true
            visible: !group.lone
            implicitHeight: cardRows.implicitHeight
            IrisCutPlate { anchors.fill: parent; visible: IrisStyle.fieldChamfer; color: IrisStyle.readingCard }
            Rectangle {
                anchors.fill: parent
                visible: !IrisStyle.fieldChamfer
                radius: IrisStyle.radiusTile
                color: IrisStyle.readingCard
                border.width: Math.max(1, Math.round(root.d))
                border.color: IrisStyle.hairline
            }
            ColumnLayout {
                id: cardRows
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 0
                Repeater {
                    model: ScriptModel { objectProp: "modelKey"; values: group.rows }
                    IrisSetting {
                        id: row
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spec: modelData
                        nested: group.hangs(modelData, group.rows)
                        highlight: root.query
                        last: index === group.rows.length - 1 && !group.folds
                        landing: root.landingPath.length > 0 && String(modelData.path ?? "") === root.landingPath
                        Component.onCompleted: if (landing) Qt.callLater(root.reveal, row)
                    }
                }
                MouseArea {
                    id: fold
                    visible: group.folds
                    Layout.fillWidth: true
                    implicitHeight: Math.round(40 * root.d)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.Button
                    Accessible.name: foldText.text
                    onClicked: group.unfolded = !group.open
                    IrisText {
                        id: foldText
                        anchors.left: parent.left
                        anchors.leftMargin: Math.round(16 * root.d)
                        anchors.verticalCenter: parent.verticalCenter
                        text: group.open ? Translation.tr("Fewer settings") : Translation.tr("%1 more").arg(group.tuned.length)
                        color: fold.containsMouse ? IrisStyle.text : IrisStyle.textSecondary
                        font.pixelSize: IrisStyle.typeLabel
                        font.weight: IrisStyle.weight(Font.Medium)
                    }
                    MaterialSymbol {
                        anchors.right: parent.right
                        anchors.rightMargin: Math.round(16 * root.d)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "expand_more"
                        iconSize: Math.round(18 * root.d)
                        color: fold.containsMouse ? IrisStyle.text : IrisStyle.textTertiary
                        rotation: group.open ? 180 : 0
                        Behavior on rotation { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
                    }
                }
            }
        }
    }
}
