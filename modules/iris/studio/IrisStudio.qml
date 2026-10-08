pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.settings
import qs.modules.iris.style
import qs.modules.iris.preview
import qs.modules.iris.edit

// Studio: Customize as a panel beside the screen (iris.appearance.customize "studio"). Every area in one
// column, one forgiving search across all of them, the same rows and history as Customize on the shell.
PanelWindow {
    id: root
    readonly property real d: IrisStyle.density
    property string target: "material"

    readonly property var areas: IrisOptions.customizeAreas
    readonly property var railGroups: [["material", "colour", "type", "motion"],
        ["island", "pieces", "bodies", "places", "transients", "dock", "desktop"], ["themes"]]
    function areaOf(id: string): var { return IrisOptions.customizeArea(id) }
    function tipOf(area: var): string { return IrisOptions.customizeTip(area.id) }

    readonly property var specifications: IrisOptions.studio
    readonly property var groups: {
        Config.revision
        const out = []
        for (const spec of root.specifications) {
            if (spec.target !== root.target || !IrisOptions.shown(spec)) continue
            if (out.length === 0 || out[out.length - 1].title !== spec.group) out.push({ title: spec.group, rows: [] })
            out[out.length - 1].rows.push(spec)
        }
        return out
    }
    function modifiedIn(id: string): int {
        void Config.revision
        const counted = new Set()
        for (const spec of root.specifications) {
            if (spec.target !== id || !String(spec.path).startsWith("iris.") || spec.fallback === undefined || counted.has(spec.path)) continue
            if (!IrisOptions.same(Config.getNestedValue(spec.path, spec.fallback), spec.fallback)) counted.add(spec.path)
        }
        return counted.size
    }
    function resetArea(): void {
        const updates = {}
        for (const spec of root.specifications)
            if (spec.target === root.target && String(spec.path).startsWith("iris.") && spec.fallback !== undefined) updates[spec.path] = spec.fallback
        Config.setNestedValues(updates)
        IrisEditHistory.say(Translation.tr("%1 is back to how iRiS comes").arg(Translation.tr(root.areaOf(root.target).label)))
    }

    // Search reads every area the forgiving way Spotlight does; results stay grouped under their area.
    property string query: ""
    readonly property var searchable: root.specifications.filter(spec => !spec.mirror).map(spec => IrisSearch.prepare({
        name: Translation.tr(spec.label), english: spec.label, detail: Translation.tr(spec.group ?? ""),
        areaName: Translation.tr(root.areaOf(spec.target).label), words: [spec.group ?? ""].concat(spec.keywords ?? []).join(" "), description: spec.description ?? "",
        spec: spec }))
    readonly property var matches: {
        void Config.revision
        const q = root.query.trim()
        if (q.length === 0) return []
        const scored = root.searchable.filter(entry => IrisOptions.shown(entry.spec))
            .map(entry => ({ entry: entry, score: IrisSearch.score(q, entry) })).filter(hit => hit.score >= 0.55)
        scored.sort((a, b) => b.score - a.score)
        const out = []
        for (const hit of scored) {
            const area = root.areaOf(hit.entry.spec.target)
            let block = out.find(item => item.area.id === area.id)
            if (!block) { block = { area: area, title: area.label, rows: [] }; out.push(block) }
            block.rows.push(hit.entry.spec)
        }
        return out
    }

    function select(id: string): void {
        if (id === root.target) return
        root.target = id
        flick.contentY = 0
    }
    function takeRequest(): void {
        const wanted = GlobalStates.irisStudioTarget
        if (wanted.length === 0) return
        GlobalStates.irisStudioTarget = ""
        if (wanted.startsWith("search:")) searchField.text = wanted.slice(7)
        else if (root.areas.some(area => area.id === wanted)) { searchField.text = ""; root.select(wanted) }
    }
    Component.onCompleted: root.takeRequest()
    Connections {
        target: GlobalStates
        function onIrisStudioTargetChanged(): void { root.takeRequest() }
    }

    visible: GlobalStates.irisStudioOpen || frame.progress > 0
    IrisOutputHold {
        id: outputHold
        wanted: GlobalStates.focusedScreen
        live: root.visible
    }
    screen: outputHold.output
    color: "transparent"
    anchors { left: true; top: true; bottom: true }
    implicitWidth: frame.width + Math.round(24 * root.d) + IrisFrame.clear("left")
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell:iris-studio"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: GlobalStates.irisStudioOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region { item: frame }

    Shortcut {
        sequence: "Escape"
        enabled: GlobalStates.irisStudioOpen
        onActivated: {
            if (root.query.length > 0) searchField.text = ""
            else GlobalStates.irisStudioOpen = false
        }
    }
    Shortcut { sequences: [StandardKey.Undo]; enabled: GlobalStates.irisStudioOpen; onActivated: IrisEditHistory.undo() }
    Shortcut { sequences: [StandardKey.Redo, "Ctrl+Shift+Z"]; enabled: GlobalStates.irisStudioOpen; onActivated: IrisEditHistory.redo() }
    Shortcut { sequence: "Ctrl+F"; enabled: GlobalStates.irisStudioOpen; onActivated: searchField.forceActiveFocus() }

    IrisMorphSurface {
        id: frame
        open: GlobalStates.irisStudioOpen
        motionSurface: "settings"
        radius: IrisStyle.surfaceRadius("settings", IrisStyle.radiusPanel)
        light: IrisStyle.surfaceLight("settings", IrisStyle.wallpaperLight)
        x: Math.round(12 * root.d) + IrisFrame.clear("left")
        y: (parent.height - height) / 2
        width: Math.min((root.screen?.width ?? 1920) - Math.round(48 * root.d) - IrisFrame.band * 2, Math.round(560 * root.d))
        height: Math.min(parent.height - Math.round(24 * root.d) - IrisFrame.band * 2, Math.round(960 * root.d))
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: IrisStyle.concentricPad(frame.radius, 16 * root.d)
            spacing: Math.round(12 * root.d)

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(8 * root.d)
                IrisMark { implicitSize: Math.round(24 * root.d) }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    IrisText {
                        text: Translation.tr("Studio")
                        font.family: IrisStyle.fontTitle
                        font.pixelSize: IrisStyle.typeTitle
                        font.weight: IrisStyle.weight(Font.Bold)
                    }
                    IrisText {
                        Layout.fillWidth: true
                        text: IrisEditHistory.notice.length > 0 ? IrisEditHistory.notice : Translation.tr("Everything you change is the shell itself")
                        color: IrisEditHistory.notice.length > 0 ? IrisStyle.accent : IrisStyle.muted
                        font.pixelSize: IrisStyle.typeFootnote
                        elide: Text.ElideRight
                    }
                }
                IrisIconButton {
                    materialIcon: "undo"
                    enabled: IrisEditHistory.undoStack.length > 0
                    opacity: enabled ? 1 : 0.35
                    Accessible.name: Translation.tr("Undo")
                    onClicked: IrisEditHistory.undo()
                }
                IrisIconButton {
                    materialIcon: "redo"
                    enabled: IrisEditHistory.redoStack.length > 0
                    opacity: enabled ? 1 : 0.35
                    Accessible.name: Translation.tr("Redo")
                    onClicked: IrisEditHistory.redo()
                }
                Rectangle { implicitWidth: 1; implicitHeight: Math.round(18 * root.d); color: IrisStyle.hairline }
                IrisIconButton {
                    materialIcon: "touch_app"
                    Accessible.name: Translation.tr("Customize on the shell")
                    onClicked: {
                        GlobalStates.irisEditTarget = root.target
                        GlobalStates.irisEdit = true
                    }
                }
                IrisIconButton {
                    materialIcon: "tune"
                    Accessible.name: Translation.tr("All settings")
                    onClicked: { GlobalStates.irisStudioOpen = false; GlobalStates.openSettings() }
                }
                IrisIconButton {
                    materialIcon: "close"
                    Accessible.name: Translation.tr("Close Studio")
                    onClicked: GlobalStates.irisStudioOpen = false
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Math.round(36 * root.d)
                radius: height / 2
                color: searchField.activeFocus ? IrisStyle.fill : IrisStyle.fillQuiet
                Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.round(12 * root.d)
                    anchors.rightMargin: Math.round(6 * root.d)
                    spacing: Math.round(8 * root.d)
                    MaterialSymbol {
                        text: "search"
                        iconSize: Math.round(18 * root.d)
                        color: searchField.text.length > 0 ? IrisStyle.accent : IrisStyle.muted
                    }
                    TextInput {
                        id: searchField
                        Layout.fillWidth: true
                        verticalAlignment: TextInput.AlignVCenter
                        color: IrisStyle.text
                        selectionColor: IrisStyle.accentContainer
                        font.family: IrisStyle.fontMain
                        font.pixelSize: IrisStyle.typeLabel
                        clip: true
                        onTextChanged: { root.query = text; flick.contentY = 0 }
                        IrisText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchField.text.length === 0
                            text: Translation.tr("Search every area: blur, corners, dock…")
                            color: IrisStyle.muted
                            font.pixelSize: searchField.font.pixelSize
                        }
                    }
                    IrisIconButton {
                        visible: searchField.text.length > 0
                        implicitWidth: Math.round(24 * root.d)
                        materialIcon: "close"
                        iconSize: Math.round(14 * root.d)
                        Accessible.name: Translation.tr("Clear search")
                        onClicked: searchField.text = ""
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Math.round(12 * root.d)

                Flickable {
                    Layout.preferredWidth: Math.round(64 * root.d)
                    Layout.fillHeight: true
                    contentHeight: rail.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    opacity: root.query.length > 0 ? 0.4 : 1
                    Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }

                    ColumnLayout {
                        id: rail
                        width: parent.width
                        spacing: Math.round(2 * root.d)
                        Repeater {
                            model: root.railGroups
                            ColumnLayout {
                                id: railGroup
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                spacing: Math.round(2 * root.d)
                                Rectangle {
                                    visible: railGroup.index > 0
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.topMargin: Math.round(4 * root.d)
                                    Layout.bottomMargin: Math.round(4 * root.d)
                                    implicitWidth: Math.round(24 * root.d)
                                    implicitHeight: 1
                                    color: IrisStyle.hairline
                                }
                                Repeater {
                                    model: railGroup.modelData
                                    RailButton {
                                        required property string modelData
                                        Layout.fillWidth: true
                                        area: root.areaOf(modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Math.round(10 * root.d)

                    RowLayout {
                        id: areaHead
                        readonly property var area: root.areaOf(root.target)
                        Layout.fillWidth: true
                        visible: root.query.length === 0
                        spacing: Math.round(10 * root.d)
                        IrisSquircle {
                            Layout.alignment: Qt.AlignTop
                            implicitWidth: Math.round(36 * root.d)
                            implicitHeight: implicitWidth
                            tint: areaHead.area.tint
                            glyph: areaHead.area.glyph
                            glyphShare: 0.56
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(2 * root.d)
                            IrisText {
                                text: Translation.tr(areaHead.area.label)
                                font.family: IrisStyle.fontTitle
                                font.pixelSize: IrisStyle.typeTitle
                                font.weight: IrisStyle.weight(Font.Bold)
                            }
                            IrisText {
                                Layout.fillWidth: true
                                text: Translation.tr(areaHead.area.about)
                                color: IrisStyle.subtext
                                font.pixelSize: IrisStyle.typeFootnote
                                wrapMode: Text.WordWrap
                            }
                        }
                        IrisButton {
                            readonly property int changed: root.modifiedIn(root.target)
                            visible: root.target !== "themes" && changed > 0
                            Layout.alignment: Qt.AlignTop
                            quiet: true
                            buttonRadius: height / 2
                            text: Translation.tr("Reset %1").arg(changed)
                            Accessible.name: Translation.tr("Reset what changed here")
                            onClicked: root.resetArea()
                        }
                    }

                    // One line worth knowing about this area, marked in its colour; never a paragraph.
                    RowLayout {
                        readonly property string tip: root.tipOf(root.areaOf(root.target))
                        Layout.fillWidth: true
                        visible: root.query.length === 0 && tip.length > 0
                        spacing: Math.round(6 * root.d)
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignTop
                            text: "lightbulb"
                            fill: 1
                            iconSize: Math.round(14 * root.d)
                            color: root.areaOf(root.target).tint
                        }
                        IrisText {
                            Layout.fillWidth: true
                            text: parent.tip
                            color: IrisStyle.muted
                            font.pixelSize: IrisStyle.typeFootnote
                            wrapMode: Text.WordWrap
                        }
                    }

                    Loader {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round((root.target === "island" || root.target === "dock" ? 150 : 200) * root.d)
                        active: (Config.options?.iris?.appearance?.previews ?? true) && root.query.length === 0 && root.target !== "themes"
                        visible: active
                        sourceComponent: root.target === "island" || root.target === "dock" ? screenPreview : scenePreview
                    }
                    Component {
                        id: screenPreview
                        IrisScreenPreview {
                            id: screenMiniature
                            screen: root.screen
                            focusRect: root.target === "dock" ? screenMiniature.dockReach : screenMiniature.islandReach
                        }
                    }
                    Component {
                        id: scenePreview
                        IrisTargetPreview {
                            target: root.target
                            playing: GlobalStates.irisStudioOpen
                        }
                    }

                    Flickable {
                        id: flick
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentHeight: rows.implicitHeight + Math.round(8 * root.d)
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: IrisScrollBar {}

                        ColumnLayout {
                            id: rows
                            width: flick.width
                            spacing: Math.round(14 * root.d)

                            IrisText {
                                visible: root.query.length > 0 && root.matches.length === 0
                                Layout.fillWidth: true
                                Layout.topMargin: Math.round(24 * root.d)
                                horizontalAlignment: Text.AlignHCenter
                                text: Translation.tr("Nothing here matches “%1”. Try a shorter word, or look in All settings.").arg(root.query)
                                color: IrisStyle.muted
                                wrapMode: Text.WordWrap
                            }

                            GroupCard {
                                Layout.fillWidth: true
                                visible: root.query.length === 0 && root.target === "material"
                                title: Translation.tr("Character")
                                tint: root.areaOf("material").tint
                                plain: true
                                RowLayout {
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
                            }

                            // Found rows sit under their area, named and marked in its colour.
                            Repeater {
                                model: root.query.length > 0 ? root.matches : []
                                ColumnLayout {
                                    id: found
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: Math.round(6 * root.d)
                                    RowLayout {
                                        spacing: Math.round(6 * root.d)
                                        IrisSquircle {
                                            implicitWidth: Math.round(18 * root.d)
                                            implicitHeight: implicitWidth
                                            tint: found.modelData.area.tint
                                            glyph: found.modelData.area.glyph
                                            glyphShare: 0.62
                                        }
                                        IrisText {
                                            text: Translation.tr(found.modelData.title)
                                            color: found.modelData.area.tint
                                            font.family: IrisStyle.fontTitle
                                            font.pixelSize: IrisStyle.typeLabel
                                            font.weight: IrisStyle.weight(Font.DemiBold)
                                        }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: foundRows.implicitHeight
                                        radius: IrisStyle.radiusTile
                                        color: IrisStyle.readingCard
                                        ColumnLayout {
                                            id: foundRows
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            spacing: 0
                                            Repeater {
                                                model: found.modelData.rows
                                                IrisSetting {
                                                    required property var modelData
                                                    required property int index
                                                    Layout.fillWidth: true
                                                    spec: modelData
                                                    highlight: root.query
                                                    last: index === found.modelData.rows.length - 1
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Repeater {
                                model: root.query.length > 0 || root.target === "themes" ? [] : root.groups
                                GroupCard {
                                    id: groupCard
                                    required property var modelData
                                    Layout.fillWidth: true
                                    title: groupCard.modelData.title
                                    tint: root.areaOf(root.target).tint
                                    Repeater {
                                        model: groupCard.modelData.rows
                                        IrisSetting {
                                            required property var modelData
                                            required property int index
                                            Layout.fillWidth: true
                                            spec: modelData
                                            last: index === groupCard.modelData.rows.length - 1
                                        }
                                    }
                                }
                            }

                            Loader {
                                Layout.fillWidth: true
                                active: root.query.length === 0 && root.target === "themes"
                                visible: active
                                sourceComponent: themesPage
                            }
                        }
                    }
                }
            }
        }
    }

    component RailButton: MouseArea {
        id: railButton
        required property var area
        readonly property bool selected: root.target === railButton.area.id && root.query.length === 0
        readonly property int changed: root.modifiedIn(railButton.area.id)
        implicitHeight: Math.round(52 * root.d)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.PageTab
        Accessible.name: Translation.tr(railButton.area.label)
        Accessible.checked: railButton.selected
        onClicked: {
            if (root.query.length > 0) searchField.text = ""
            root.select(railButton.area.id)
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(2 * root.d)
            width: Math.round(40 * root.d)
            height: Math.round(30 * root.d)
            radius: height / 2
            color: railButton.selected ? IrisStyle.tintFill(railButton.area.tint)
                : railButton.containsMouse ? IrisStyle.fillHover : "transparent"
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
            MaterialSymbol {
                anchors.centerIn: parent
                text: railButton.area.glyph
                iconSize: Math.round(19 * root.d)
                fill: railButton.selected ? 1 : 0
                animateFill: true
                color: railButton.selected ? railButton.area.tint : IrisStyle.textSecondary
            }
            Rectangle {
                visible: railButton.changed > 0
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: Math.round(4 * root.d)
                anchors.topMargin: Math.round(4 * root.d)
                width: Math.round(6 * root.d)
                height: width
                radius: width / 2
                color: railButton.area.tint
            }
        }
        IrisText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(2 * root.d)
            width: Math.min(implicitWidth, railButton.width)
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: Translation.tr(railButton.area.label)
            color: railButton.selected ? IrisStyle.text : IrisStyle.muted
            font.pixelSize: IrisStyle.typeCaption
            font.weight: IrisStyle.weight(railButton.selected ? Font.DemiBold : Font.Normal)
        }
    }

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

    // A group's title carries its area's colour: the one accent that says where you are.
    component GroupCard: ColumnLayout {
        id: card
        property string title: ""
        property color tint: IrisStyle.accent
        property bool plain: false
        default property alias rows: body.data
        spacing: Math.round(6 * root.d)
        IrisText {
            Layout.leftMargin: Math.round(14 * root.d)
            text: Translation.tr(card.title)
            color: card.tint
            font.family: IrisStyle.fontTitle
            font.pixelSize: IrisStyle.typeMeta
            font.weight: IrisStyle.weight(Font.DemiBold)
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: body.implicitHeight
            radius: IrisStyle.radiusTile
            color: card.plain ? "transparent" : IrisStyle.readingCard
            ColumnLayout {
                id: body
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 0
            }
        }
    }

    Component {
        id: themesPage
        ColumnLayout {
            spacing: Math.round(12 * root.d)
            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(6 * root.d)
                IrisText {
                    Layout.fillWidth: true
                    text: IrisThemes.active ? IrisThemes.active.name : Translation.tr("Your own mix")
                    font.pixelSize: IrisStyle.typeBody
                    font.weight: IrisStyle.weight(Font.DemiBold)
                    elide: Text.ElideRight
                }
                ColoursOnly {}
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
                columns: 2
                rowSpacing: Math.round(12 * root.d)
                columnSpacing: Math.round(10 * root.d)
                Repeater {
                    model: IrisThemes.all
                    IrisThemeCard {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: (cells.width - cells.columnSpacing) / 2
                        theme: modelData
                        screen: root.screen
                        onShareRequested: {
                            Quickshell.clipboardText = IrisThemes.exportText(modelData)
                            IrisEditHistory.say(Translation.tr("Copied “%1”, paste it anywhere to share it").arg(modelData.name))
                        }
                    }
                }
            }
        }
    }
}
