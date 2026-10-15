pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.components
import qs.modules.iris.style
import qs.modules.iris.pieces
import qs.modules.iris.widgets

Item {
    id: root
    required property var spec
    property bool last: false
    property string highlight: ""
    // Arrived at from a search: the row glows once in the accent, then settles.
    property bool landing: false
    onLandingChanged: if (root.landing) landingGlow.restart()
    function marked(text: string): string {
        const plain = part => part.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        const terms = root.highlight.trim().split(/\s+/).filter(term => term.length > 1)
            .map(term => term.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"))
        if (terms.length === 0) return plain(text)
        return text.split(new RegExp("(" + terms.join("|") + ")", "i"))
            .map((part, index) => index % 2 ? "<font color='" + IrisStyle.accent + "'><b>" + plain(part) + "</b></font>" : plain(part))
            .join("")
    }
    readonly property real d: IrisStyle.settingsDensity
    // A picked card: iRiS tints it and sets its name in the accent; a Design that selects with a plate (AIRISU) lays the
    // picked one a step of ink over the others and rules its die in the seal: a card is never a plate of the ink itself
    // (a white card on lacquer), and its name stays in the ink.
    readonly property bool platePick: IrisStyle.plateSelection
    function pickFill(selected: bool, hovered: bool): color {
        if (selected && root.platePick)
            return ColorUtils.mix(IrisStyle.text, IrisStyle.surfaceOpaque, 0.12) // iris-literal: one step of ink
        return selected ? IrisStyle.tintFill(IrisStyle.accent) : hovered ? IrisStyle.fillHover : IrisStyle.fillQuiet
    }
    function pickInk(selected: bool): color { return !selected || root.platePick ? IrisStyle.text : IrisStyle.accent }
    function pickDetail(selected: bool): color { return IrisStyle.muted }
    // The seal's rule round a picked card under a plate-selecting Design.
    function pickRule(selected: bool): color { return selected && root.platePick ? IrisStyle.accentFill : "transparent" }
    readonly property var value: {
        Config.revision
        return IrisOptions.currentValue(root.spec)
    }
    function commit(next: var): void { IrisOptions.commit(root.spec, next) }
    // A range shows the drag's own value while it moves. Its consumers see it live (Config.previewNestedValue: no
    // revision, no file write); the drag writes once, on release. A value the palette solver or Niri reads is not
    // previewed at all: each step would solve and recolour the whole shell, or rewrite Niri's config.
    property real dragValue: NaN
    readonly property var shownValue: Number.isFinite(root.dragValue) ? root.dragValue : root.value
    readonly property bool livePath: !root.spec.niri && !root.spec.bundle && String(root.spec.path ?? "").length > 0
        && !/^iris\.appearance\.tune\.|^iris\.widgets\.vibrance$|^appearance\./.test(String(root.spec.path))
    function previewDrag(): void {
        if (Number.isFinite(root.dragValue) && root.livePath) Config.previewNestedValue(root.spec.path, root.dragValue)
    }
    function flushDrag(): void {
        if (!Number.isFinite(root.dragValue)) return
        if (root.dragValue !== Number(root.value) || root.livePath) root.commit(root.dragValue)
    }
    function previewFace(choice: var): string {
        if (!root.spec.previewFont) return IrisStyle.fontMain
        const bundle = root.spec.bundle ?? []
        return bundle.length > 0 ? IrisStyle.face(bundle[0], choice.values[0]) : IrisStyle.face(root.spec.path, choice.value)
    }
    readonly property var choices: {
        IrisNiri.revision
        return IrisOptions.choicesOf(root.spec)
    }
    // A row can say why it does not answer right now (`locked`) and what state it is in (`note`), so it never reads as broken.
    readonly property bool locked: { Config.revision; return root.spec.locked ? Boolean(root.spec.locked()) : false }
    readonly property string noteText: { Config.revision; return root.spec.note ? String(root.spec.note() ?? "") : "" }
    readonly property real controlOpacity: root.locked ? 0.42 : 1
    readonly property bool resettable: IrisOptions.resettable(root.spec)
    readonly property bool modified: root.resettable && !IrisOptions.same(root.value, root.spec.fallback)
    readonly property bool pictured: root.choices.some(choice => String(choice.glyph ?? "").length > 0)
    readonly property bool swatched: root.spec.kind === "choice" && root.choices.length > 0
        && root.choices.every(choice => choice.swatch !== undefined || ["wallpaper", "accent", "custom", "theme"].includes(choice.value))
        && root.choices.some(choice => choice.swatch !== undefined)
    readonly property bool tiled: root.spec.kind === "choice" && root.spec.tiles === true && root.choices.length > 0
    readonly property bool carded: root.spec.kind === "choice" && (root.spec.cards === "material" || root.spec.cards === "design") && root.choices.length > 0
    // Every control that fits answers in one right-hand column, the same width on every row, so a page reads as names on
    // the left and answers on the right. What needs more room (pictures, four or more choices, galleries) sits under the
    // text at full width.
    readonly property bool roomy: layout.width >= 480 * root.d
    // 43 %: in the Settings pane (about 700·d of row) the column still reaches its 300·d, so a three-way choice keeps it.
    readonly property real controlWidth: Math.round(Math.min(300 * root.d, Math.max(200 * root.d, layout.width * 0.43)))
    FontMetrics {
        id: choiceMetrics
        font.family: IrisStyle.fontMain
        font.pixelSize: IrisStyle.typeMeta
        font.weight: IrisStyle.weight(Font.DemiBold)
    }
    FontMetrics {
        id: figureMetrics
        font.family: IrisStyle.fontNumbers
        font.pixelSize: IrisStyle.typeHeadline
        font.weight: IrisStyle.figureWeight
    }
    // Segments share the track evenly, so the widest name sets every slot.
    readonly property real segmentNatural: root.spec.kind !== "choice" || root.choices.length === 0 ? 0
        : root.choices.length * (Math.max(...root.choices.map(choice => choiceMetrics.advanceWidth(Translation.tr(String(choice.label ?? ""))))) + 26 * root.d) + 4
    readonly property bool inlineChoice: root.spec.kind === "choice" && root.roomy && root.choices.length >= 2 && root.choices.length <= 4
        && !root.swatched && !root.tiled && !root.carded && root.segmentNatural <= root.controlWidth
    // A flat list the column's track cannot hold (HIG: past a few choices, or names too long to share it) answers as a
    // pop-up button in the same column. Pictures stay pictures: up to five glyph choices keep their track under the text.
    readonly property bool menuChoice: root.spec.kind === "choice" && root.choices.length > 0 && !root.inlineChoice
        && !root.swatched && !root.tiled && !root.carded && !(root.pictured && root.choices.length <= 5)
    // A typeface from the installed ones: the list's last entry opens a search under the row.
    property bool fontSearch: false
    // The list a menu choice opens in place under the row (IrisStyle.choiceList); one open on the page at a time.
    readonly property string listKey: String(root.spec.path ?? "") + "|" + String(root.spec.section ?? "") + "|" + String(root.spec.label ?? "")
    readonly property bool listInline: IrisStyle.choiceList === "inline"
    readonly property bool listOpen: root.menuChoice && root.listInline && IrisOptions.openList === root.listKey
    function toggleList(): void { IrisOptions.openList = root.listOpen ? "" : root.listKey }
    property real listProgress: root.listOpen ? 1 : 0
    Behavior on listProgress { NumberAnimation { duration: IrisStyle.duration(240); easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
    Timer { id: listClose; interval: 160; onTriggered: if (root.listOpen) IrisOptions.openList = "" }
    readonly property bool inlineRange: root.spec.kind === "range" && root.roomy
    // A text answer sits in the column too: a prefix (`short`) in a small field, anything longer at the column's width.
    readonly property bool inlineText: root.spec.kind === "text" && root.roomy
    // A few fixed colours answer beside their name; sources (wallpaper, theme, your own hue) stay pictured as cards.
    readonly property bool inlineSwatch: root.swatched && root.spec.sources !== true && !root.carded && !root.tiled && root.roomy
        && root.choices.length * 40 * root.d <= root.controlWidth + 10 * root.d
    // The figure keeps one width from end to end of its range, so the track never shifts while it moves.
    readonly property real figureWidth: root.spec.kind !== "range" ? 0
        : Math.ceil(Math.max(...[root.spec.min, root.spec.max, root.spec.fallback, root.value].filter(value => value !== undefined)
            .map(value => figureMetrics.advanceWidth(Translation.tr(IrisOptions.rangeText(root.spec, value)))))) + Math.round(4 * root.d)

    implicitHeight: Math.max(Math.round(50 * root.d), layout.implicitHeight + Math.round(22 * root.d))
    enabled: !root.locked

    Rectangle {
        id: glow
        anchors.fill: parent
        anchors.margins: Math.round(4 * root.d)
        radius: IrisStyle.radiusRow
        color: IrisStyle.tintFillHover(IrisStyle.accent)
        opacity: 0
        SequentialAnimation {
            id: landingGlow
            PauseAnimation { duration: IrisStyle.duration(260) }
            NumberAnimation { target: glow; property: "opacity"; to: 1; duration: IrisStyle.duration(180); easing.type: IrisStyle.feedbackEasing }
            PauseAnimation { duration: IrisStyle.duration(900) }
            NumberAnimation { target: glow; property: "opacity"; to: 0; duration: IrisStyle.duration(700); easing.type: IrisStyle.feedbackEasing }
        }
    }

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16 * root.d
        anchors.rightMargin: 16 * root.d
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10 * root.d

        RowLayout {
            Layout.fillWidth: true
            spacing: 12 * root.d

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2 * root.d
                Item {
                    Layout.fillWidth: true
                    implicitHeight: label.implicitHeight
                    IrisText {
                        id: label
                        width: Math.min(implicitWidth, parent.width - resetMark.width - Math.round(6 * root.d))
                        text: root.highlight.length > 0 ? root.marked(Translation.tr(root.spec.label)) : Translation.tr(root.spec.label)
                        textFormat: root.highlight.length > 0 ? Text.StyledText : Text.PlainText
                        font.pixelSize: IrisStyle.typeBody
                        font.weight: IrisStyle.weight(Font.Normal)
                        wrapMode: Text.WordWrap
                    }
                    FontMetrics { id: labelMetrics; font: label.font }
                    Item {
                        id: resetMark
                        x: label.x + Math.min(label.contentWidth, label.width) + Math.round(6 * root.d)
                        // Centred on the first line's lowercase, where the eye reads the word's middle.
                        y: Math.round(label.baselineOffset - labelMetrics.xHeight / 2 - height / 2)
                        width: Math.round(18 * root.d)
                        height: width
                        opacity: root.modified ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                        Rectangle {
                            anchors.centerIn: parent
                            width: resetArea.containsMouse ? resetMark.width : Math.round(7 * root.d)
                            height: width
                            radius: IrisStyle.capsule(width)
                            color: resetArea.containsMouse ? IrisStyle.tintFill(IrisStyle.accent) : IrisStyle.accent
                            Behavior on width { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "undo"
                                iconSize: Math.round(12 * root.d)
                                color: IrisStyle.accent
                                opacity: resetArea.containsMouse ? 1 : 0
                            }
                        }
                        MouseArea {
                            id: resetArea
                            anchors.fill: parent
                            enabled: root.modified
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            Accessible.role: Accessible.Button
                            Accessible.name: Translation.tr("Reset %1").arg(Translation.tr(root.spec.label))
                            onClicked: root.commit(root.spec.fallback)
                        }
                    }
                }
                IrisText {
                    id: description
                    property bool full: false
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: root.spec.description ? Translation.tr(root.spec.description) : ""
                    // A chamfered Design prints its row in two inks, the name in the ink and what it does a tone down: at
                    // the shared subtext (nine tenths of the ink) both read as one black block.
                    color: IrisStyle.fieldChamfer ? IrisStyle.muted : IrisStyle.subtext
                    font.pixelSize: IrisStyle.typeMeta
                    wrapMode: Text.WordWrap
                    maximumLineCount: description.full ? 12 : 2
                    elide: Text.ElideRight
                    MouseArea {
                        anchors.fill: parent
                        enabled: description.truncated || description.full
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: description.full = !description.full
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.noteText.length > 0
                    spacing: Math.round(6 * root.d)
                    MaterialSymbol {
                        Layout.alignment: Qt.AlignTop
                        text: root.locked ? "link" : "info"
                        iconSize: Math.round(14 * root.d)
                        color: IrisStyle.accent
                    }
                    IrisText {
                        Layout.fillWidth: true
                        text: root.noteText
                        color: IrisStyle.accent
                        font.pixelSize: IrisStyle.typeMeta
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // A trailing value reads on the title's line, in the interface face: the title leads, the value answers.
            IrisText {
                visible: root.swatched
                Layout.alignment: root.inlineSwatch ? Qt.AlignVCenter : Qt.AlignTop
                Layout.preferredHeight: root.inlineSwatch ? -1 : label.implicitHeight
                verticalAlignment: Text.AlignVCenter
                text: Translation.tr(String(root.choices.find(choice => choice.value === root.value)?.label ?? ""))
                color: IrisStyle.subtext
                font.pixelSize: IrisStyle.typeLabel
            }

            IrisText {
                visible: root.spec.kind === "range" && !root.inlineRange
                Layout.alignment: Qt.AlignTop
                Layout.preferredHeight: label.implicitHeight
                verticalAlignment: Text.AlignVCenter
                text: Translation.tr(IrisOptions.rangeText(root.spec, root.shownValue))
                color: IrisStyle.subtext
                font.features: ({ "tnum": 1 })
                font.pixelSize: IrisStyle.typeLabel
            }

            IrisSwitch {
                id: toggle
                opacity: root.controlOpacity
                visible: root.spec.kind === "switch"
                on: root.spec.invert ? !Boolean(root.value) : Boolean(root.value)
                name: Translation.tr(root.spec.label)
                onToggled: root.commit(root.spec.invert ? toggle.on : !toggle.on)
            }

            IrisButton {
                id: actionButton
                visible: root.spec.kind === "action"
                opacity: root.controlOpacity
                Layout.alignment: Qt.AlignVCenter
                text: Translation.tr(String(root.spec.button ?? ""))
                colBackground: actionButton.skinned ? "transparent" : IrisStyle.fill
                colBackgroundHover: actionButton.skinned ? "transparent" : IrisStyle.fillHover
                onClicked: root.spec.run()
            }

            Loader {
                opacity: root.controlOpacity
                active: root.inlineChoice
                visible: active
                Layout.preferredWidth: Math.round(Math.max(root.segmentNatural, root.controlWidth * 0.66))
                sourceComponent: segmentedComponent
            }

            Loader {
                opacity: root.controlOpacity
                active: root.menuChoice
                visible: active
                Layout.alignment: Qt.AlignVCenter
                sourceComponent: popupComponent
            }

            Loader {
                opacity: root.controlOpacity
                active: root.inlineSwatch
                visible: active
                Layout.preferredWidth: Math.round((root.choices.length * 40 - 10) * root.d)
                sourceComponent: swatchComponent
            }

            Loader {
                opacity: root.controlOpacity
                active: root.inlineText
                visible: active
                Layout.preferredWidth: root.spec.short ? Math.round(64 * root.d) : root.controlWidth
                sourceComponent: textComponent
            }

            RowLayout {
                visible: root.inlineRange
                // Fixed: the track's fillWidth would otherwise spread to the row and eat the label's column.
                Layout.fillWidth: false
                Layout.minimumWidth: root.controlWidth
                Layout.maximumWidth: root.controlWidth
                spacing: Math.round(12 * root.d)
                Item {
                    id: inlineRangeSlot
                    Layout.fillWidth: true
                    implicitHeight: Math.round(22 * root.d)
                }
                // One figure column on every row (wider only for a longer word), so the tracks of a page start on one line.
                // The figure is also a field: a click types an exact value, ↑ ↓ step it, Return sets it, Escape leaves it.
                Item {
                    id: figure
                    property bool editing: false
                    readonly property real scale: Number(root.spec.scale ?? 1)
                    readonly property real shownStep: Math.abs(Number(root.spec.step ?? 1) * figure.scale)
                    readonly property int decimals: figure.shownStep > 0 && figure.shownStep < 1
                        ? Math.min(2, Math.ceil(-Math.log10(figure.shownStep) - 1e-9)) : 0
                    function plain(value: real): string {
                        return Number(value * figure.scale).toFixed(figure.decimals).replace(/(\.\d*?)0+$/, "$1").replace(/\.$/, "")
                    }
                    function begin(): void {
                        figureInput.text = figure.plain(Number(root.value))
                        figure.editing = true
                        figureInput.forceActiveFocus()
                        figureInput.selectAll()
                    }
                    function settle(text: string): void {
                        figure.editing = false
                        const typed = Number(String(text).trim().replace(",", "."))
                        if (!Number.isFinite(typed)) return
                        const step = Number(root.spec.step ?? 1)
                        const raw = Math.max(root.spec.min, Math.min(root.spec.max, typed / figure.scale))
                        const value = Number((Math.round(raw / step) * step).toFixed(4))
                        if (value !== Number(root.value)) root.commit(value)
                    }
                    Layout.preferredWidth: Math.max(root.figureWidth, Math.round(60 * root.d))
                    implicitHeight: Math.round(24 * root.d)
                    opacity: root.controlOpacity
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: -Math.round(6 * root.d)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(parent.width, (figure.editing ? parent.width : figureText.contentWidth)) + Math.round(12 * root.d)
                        height: parent.height
                        radius: IrisStyle.radiusChip
                        color: figure.editing ? IrisStyle.fill : figureHover.hovered ? IrisStyle.fillQuiet : "transparent"
                        border.width: figure.editing ? 1 : 0
                        border.color: IrisStyle.tintBorder(IrisStyle.accent)
                        Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                    }
                    IrisText {
                        id: figureText
                        anchors.fill: parent
                        visible: !figure.editing
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                        text: Translation.tr(IrisOptions.rangeText(root.spec, root.shownValue))
                        // The range's answer is a figure, set in the figures' voice like every value iRiS shows large.
                        color: IrisStyle.text
                        font.family: IrisStyle.fontNumbers
                        font.features: ({ "tnum": 1 })
                        font.pixelSize: IrisStyle.typeHeadline
                        font.weight: IrisStyle.figureWeight
                    }
                    TextInput {
                        id: figureInput
                        anchors.fill: parent
                        visible: figure.editing
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                        color: IrisStyle.text
                        selectionColor: IrisStyle.accentContainer
                        selectedTextColor: IrisStyle.inkOnAccentContainer
                        font.family: IrisStyle.fontNumbers
                        font.features: ({ "tnum": 1 })
                        font.pixelSize: IrisStyle.typeHeadline
                        font.weight: IrisStyle.figureWeight
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        Accessible.name: Translation.tr(root.spec.label)
                        onEditingFinished: if (figure.editing) figure.settle(figureInput.text)
                        onActiveFocusChanged: if (!activeFocus && figure.editing) figure.settle(figureInput.text)
                        // Escape leaves the field without a change, before it closes anything else.
                        Keys.onShortcutOverride: event => { if (event.key === Qt.Key_Escape) event.accepted = true }
                        Keys.onEscapePressed: { figure.editing = false; figureInput.focus = false }
                        Keys.onUpPressed: figureInput.text = figure.plain(Math.min(root.spec.max, Number(figureInput.text.replace(",", ".")) / figure.scale + Number(root.spec.step ?? 1)))
                        Keys.onDownPressed: figureInput.text = figure.plain(Math.max(root.spec.min, Number(figureInput.text.replace(",", ".")) / figure.scale - Number(root.spec.step ?? 1)))
                    }
                    HoverHandler { id: figureHover; enabled: !figure.editing; cursorShape: Qt.IBeamCursor }
                    TapHandler { enabled: !figure.editing; onTapped: figure.begin() }
                }
            }

            Loader {
                opacity: root.controlOpacity
                active: root.spec.kind === "zone"
                visible: active
                sourceComponent: zoneComponent
            }
        }

        Item {
            id: belowRangeSlot
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(22 * root.d)
            visible: root.spec.kind === "range" && !root.inlineRange
        }
        IrisScrubber {
            id: rangeScrubber
            parent: root.inlineRange ? inlineRangeSlot : belowRangeSlot
            anchors.fill: parent
            visible: root.spec.kind === "range"
            opacity: root.controlOpacity
            knob: true
            Accessible.name: Translation.tr(root.spec.label)
            stepSize: (root.spec.step ?? 1) / Math.max(1, root.spec.max - root.spec.min)
            fillColor: IrisStyle.accent
            trackColor: IrisStyle.fill
            value: root.spec.kind === "range" ? (Number(root.shownValue) - root.spec.min) / (root.spec.max - root.spec.min) : 0
            onMoved: next => {
                const step = root.spec.step ?? 1
                const span = root.spec.max - root.spec.min
                const raw = root.spec.min + next * span
                // A drag passing the default holds there, so it can always be found again; keys and the wheel step freely.
                const home = Number(root.spec.fallback)
                const held = rangeScrubber.dragging && Number.isFinite(home) && Math.abs(raw - home) < span * 0.02
                const value = held ? home : Number((Math.round(raw / step) * step).toFixed(4))
                if (!rangeScrubber.dragging) { if (value !== Number(root.value)) root.commit(value); return }
                if (value === root.dragValue) return
                root.dragValue = value
                if (!rangePreview.running) { root.previewDrag(); rangePreview.restart() }
            }
            onDraggingChanged: if (!dragging) { rangePreview.stop(); root.flushDrag(); root.dragValue = NaN }
        }
        // The live preview moves at most at frame pace's half: a step can re-layout a whole surface.
        Timer {
            id: rangePreview
            interval: 32
            onTriggered: root.previewDrag()
        }

        Loader {
            opacity: root.controlOpacity
            Layout.fillWidth: true
            active: root.spec.kind === "choice" && !root.inlineChoice && !root.swatched && !root.menuChoice && !root.tiled && !root.carded
            visible: active
            sourceComponent: segmentedComponent
        }

        // The list grows out of the row: one scalar opens it, the cells fade in behind the edge it pushes down.
        Item {
            Layout.fillWidth: true
            visible: root.listProgress > 0
            implicitHeight: Math.round((choiceGrid.item?.implicitHeight ?? 0) * root.listProgress)
            clip: true
            Loader {
                id: choiceGrid
                width: parent.width
                active: root.listOpen || root.listProgress > 0
                opacity: root.listProgress
                sourceComponent: choiceGridComponent
            }
        }

        Loader {
            opacity: root.controlOpacity
            Layout.fillWidth: true
            active: root.spec.installedFonts === true && root.fontSearch
            visible: active
            sourceComponent: installedFontsComponent
        }

        Loader {
            opacity: root.controlOpacity
            Layout.fillWidth: true
            active: root.swatched && !root.tiled && !root.carded && !root.inlineSwatch
            visible: active
            sourceComponent: swatchComponent
        }

        Loader {
            opacity: root.controlOpacity
            Layout.fillWidth: true
            active: root.carded
            visible: active
            sourceComponent: root.spec.cards === "design" ? designCardsComponent : materialCardsComponent
        }

        Loader {
            Layout.fillWidth: true
            opacity: root.controlOpacity
            active: root.tiled
            visible: active
            sourceComponent: tilesComponent
        }

        Loader {
            opacity: root.controlOpacity
            Layout.fillWidth: true
            active: root.spec.kind === "curve"
            visible: active
            sourceComponent: curveComponent
        }

        Loader {
            opacity: root.controlOpacity
            Layout.fillWidth: true
            active: root.spec.kind === "hue"
            visible: active
            sourceComponent: hueComponent
        }

        Loader {
            opacity: root.controlOpacity
            Layout.fillWidth: true
            active: root.spec.kind === "pieces"
            visible: active
            sourceComponent: piecesComponent
        }

        // A list the row edits in place (Autostart, calendar accounts): its own view, the row only frames it.
        Loader {
            opacity: root.controlOpacity
            Layout.fillWidth: true
            active: root.spec.kind === "list"
            visible: active
            source: active ? root.spec.view : ""
        }

        Loader {
            opacity: root.controlOpacity
            Layout.fillWidth: true
            // A field sized by its text feeds its width back through fillWidth: a loop.
            Layout.preferredWidth: 0
            active: root.spec.kind === "text" && !root.inlineText
            visible: active
            sourceComponent: textComponent
        }

        Loader {
            opacity: root.controlOpacity
            Layout.fillWidth: true
            active: root.spec.kind === "icon"
            visible: active
            sourceComponent: iconComponent
        }

        Loader {
            opacity: root.controlOpacity
            Layout.fillWidth: true
            active: root.spec.kind === "niriMotion"
            visible: active
            sourceComponent: IrisNiriMotionGallery {}
        }

        Loader {
            opacity: root.controlOpacity
            Layout.fillWidth: true
            active: root.spec.kind === "widgets"
            visible: active
            sourceComponent: IrisWidgetGallery {}
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16 * root.d
        height: 1
        visible: !root.last
        color: IrisStyle.hairline
    }

    Component {
        id: piecesComponent

        Flow {
            id: picker
            readonly property var picked: Array.from(root.value ?? [])
            spacing: Math.round(8 * root.d)

            Repeater {
                model: root.choices
                delegate: IrisChip {
                    id: chip
                    required property var modelData
                    readonly property int place: picker.picked.indexOf(String(chip.modelData.value))
                    // A flags row is a set: no order to number.
                    order: root.spec.flags ? -1 : chip.place
                    selected: chip.place >= 0
                    label: Translation.tr(String(chip.modelData.label))
                    Accessible.role: Accessible.CheckBox
                    onClicked: {
                        const value = String(chip.modelData.value)
                        const next = picker.picked.filter(entry => entry !== value)
                        if (!chip.selected) next.push(value)
                        root.commit(next)
                    }
                }
            }
        }
    }

    Component {
        id: zoneComponent

        RowLayout {
            id: zonePicker
            readonly property string base: String(root.spec.path).replace(/\.place$/, "")
            spacing: 12 * root.d

            IrisText {
                Layout.alignment: Qt.AlignVCenter
                text: Translation.tr(root.choices.find(choice => choice.value === root.value)?.label ?? "")
                color: IrisStyle.subtext
                font.pixelSize: IrisStyle.typeMeta
            }

            IrisPlacePicker {
                place: String(root.value ?? "")
                fx: { Config.revision; return Number(Config.getNestedValue(zonePicker.base + ".fx", 0.5)) }
                fy: { Config.revision; return Number(Config.getNestedValue(zonePicker.base + ".fy", 0.5)) }
                hasIsland: root.choices.some(choice => choice.value === "island")
                label: Translation.tr(root.spec.label)
                onPlaced: zone => root.commit(zone)
                onPlacedFree: (x, y) => {
                    const updates = {}
                    updates[zonePicker.base + ".fx"] = Math.round(x * 1000) / 1000
                    updates[zonePicker.base + ".fy"] = Math.round(y * 1000) / 1000
                    updates[root.spec.path] = "free"
                    Config.setNestedValues(updates)
                }
            }
        }
    }

    // Palettes as cards that paint themselves in their own colours, so each reads as the theme it is, light ones and dark ones apart.
    Component {
        id: tilesComponent
        Column {
            id: tiles
            readonly property real gap: Math.round(8 * root.d)
            readonly property int columns: width >= 640 * root.d ? 4 : width >= 440 * root.d ? 3 : 2
            readonly property real tileWidth: Math.floor((width - (tiles.columns - 1) * tiles.gap) / tiles.columns)
            spacing: Math.round(14 * root.d)
            Repeater {
                // Styles share the mode in use: one band. Themes split into wallpaper, light and dark.
                model: root.spec.flatTiles ? [{ title: "", pick: choice => true }] : [
                    { title: "", pick: choice => Boolean(choice.palette?.wallpaper) },
                    { title: "Light mode", pick: choice => !choice.palette?.wallpaper && !choice.palette?.dark },
                    { title: "Dark mode", pick: choice => !choice.palette?.wallpaper && Boolean(choice.palette?.dark) }
                ]
                Column {
                    id: band
                    required property var modelData
                    readonly property var members: root.choices.filter(band.modelData.pick)
                    visible: band.members.length > 0
                    width: tiles.width
                    spacing: Math.round(8 * root.d)
                    IrisText {
                        visible: band.modelData.title.length > 0
                        text: Translation.tr(band.modelData.title)
                        color: IrisStyle.muted
                        font.pixelSize: IrisStyle.typeMeta
                        font.weight: IrisStyle.weight(Font.DemiBold)
                    }
                    Flow {
                        width: band.width
                        spacing: tiles.gap
                        Repeater {
                            model: band.members
                            // A row, not a card: a chip draws the palette in miniature (paper, two lines of its ink,
                            // its colours; night and day side by side for a style), the name reads in Settings' own ink.
                            Rectangle {
                                id: tile
                                required property var modelData
                                readonly property bool selected: root.value === tile.modelData.value
                                readonly property var pal: tile.modelData.palette ?? ({})
                                readonly property bool wall: Boolean(tile.pal.wallpaper)
                                readonly property var sides: tile.pal.split ?? [tile.pal]
                                width: tiles.tileWidth
                                height: Math.round(44 * root.d)
                                radius: IrisStyle.radiusTile
                                readonly property color stuff: root.pickFill(tile.selected, tileHover.hovered)
                                color: IrisStyle.fieldChamfer ? "transparent" : tile.stuff
                                IrisCutPlate { anchors.fill: parent; visible: IrisStyle.fieldChamfer; color: tile.stuff; stroke: root.pickRule(tile.selected); strokeWidth: tile.selected ? 2 : 0 }
                                scale: tileTap.pressed ? IrisStyle.pressScale(0.97) : 1
                                Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                                Behavior on color { ColorAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                                Accessible.name: Translation.tr(root.spec.label) + ": " + Translation.tr(tile.modelData.label)
                                Accessible.role: Accessible.Button
                                Accessible.checked: tile.selected
                                ClippingRectangle {
                                    id: chip
                                    readonly property real inset: Math.round(7 * root.d)
                                    x: chip.inset
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.round(30 * root.d)
                                    height: width
                                    // Concentric with the row: the row's radius less the air around the chip.
                                    radius: IrisStyle.fieldChamfer ? 0 : Math.max(Math.round(5 * root.d), tile.radius - chip.inset)
                                    color: tile.sides[0]?.bg ?? IrisStyle.fillQuiet
                                    IrisImage {
                                        visible: tile.wall
                                        anchors.fill: parent
                                        source: tile.wall ? Wallpapers.stillUrlFor(String(Wallpapers.effectiveWallpaperPath ?? "")) : ""
                                    }
                                    Row {
                                        visible: !tile.wall
                                        anchors.fill: parent
                                        Repeater {
                                            model: tile.wall ? [] : tile.sides
                                            Rectangle {
                                                id: half
                                                required property var modelData
                                                required property int index
                                                readonly property real pad: Math.round((tile.sides.length > 1 ? 3 : 5) * root.d)
                                                width: chip.width / tile.sides.length
                                                height: chip.height
                                                color: modelData.bg ?? IrisStyle.fillQuiet
                                                Column {
                                                    x: half.pad
                                                    y: Math.round(7 * root.d)
                                                    spacing: Math.round(4 * root.d)
                                                    Repeater {
                                                        model: [0.62, 0.4]
                                                        Rectangle {
                                                            required property real modelData
                                                            width: Math.max(2, Math.round((half.width - 2 * half.pad) * modelData / 0.62))
                                                            height: Math.max(2, Math.round(2.5 * root.d))
                                                            radius: IrisStyle.capsule(height)
                                                            color: half.modelData.fg ?? IrisStyle.text
                                                            opacity: 0.8
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    Row {
                                        visible: !tile.wall
                                        x: Math.round(5 * root.d)
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: Math.round(6 * root.d)
                                        spacing: Math.round(2 * root.d)
                                        Repeater {
                                            model: (tile.sides[tile.sides.length - 1]?.dots ?? tile.pal.dots ?? []).slice(0, 3)
                                            Rectangle { required property var modelData; width: Math.round(5 * root.d); height: width; radius: width / 2; color: modelData }
                                        }
                                    }
                                    // The chip's own edge, so a paper chip never melts into a paper row.
                                    Rectangle { anchors.fill: parent; radius: chip.radius; color: "transparent"; border.width: 1; border.color: IrisStyle.border }
                                }
                                IrisText {
                                    anchors.left: chip.right
                                    anchors.leftMargin: Math.round(10 * root.d)
                                    anchors.right: check.left
                                    anchors.rightMargin: Math.round(6 * root.d)
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Translation.tr(tile.modelData.label)
                                    color: root.pickInk(tile.selected)
                                    elide: Text.ElideRight
                                    font.pixelSize: IrisStyle.typeLabel
                                    font.weight: IrisStyle.weight(tile.selected ? Font.DemiBold : Font.Medium)
                                }
                                MaterialSymbol {
                                    id: check
                                    anchors.right: parent.right
                                    anchors.rightMargin: Math.round(10 * root.d)
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "check"
                                    iconSize: Math.round(16 * root.d)
                                    color: IrisStyle.accent
                                    opacity: tile.selected ? 1 : 0
                                    scale: tile.selected ? 1 : 0.6
                                    Behavior on opacity { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                                    Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                                }
                                HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler { id: tileTap; onTapped: root.commit(tile.modelData.value) }
                            }
                        }
                    }
                }
            }
        }
    }

    // Where a colour comes from (the wallpaper, the theme, the accent, a hue of your own) is a choice of its own, read
    // as cards that show that source; the fixed colours follow as swatches. Rows without `sources` keep swatches only.
    readonly property var sourceRank: ["wallpaper", "theme", "accent", "custom"]
    readonly property color liveColour: String(root.spec.path) === "iris.appearance.highlight" ? IrisStyle.secondaryAccent : IrisStyle.accent
    function sourceDetail(kind: string): string {
        if (kind === "wallpaper") return Translation.tr("Follows every new wallpaper")
        if (kind === "theme") return Translation.tr("The colour theme's own")
        if (kind === "accent") return Translation.tr("Matches the accent")
        return Translation.tr("Any hue you choose")
    }

    // A Design is shown as itself: each draws its own picture (designs/<id>/parts/Preview.qml), large, side by side, so
    // the choice reads as two products and not as two words.
    Component {
        id: designCardsComponent

        // Laid by hand, not a Row: the cards' width comes from the width the layout gives, and a Row feeding its own
        // implicit width back into that loops its polish.
        Item {
            id: designs
            readonly property real gap: Math.round(10 * root.d)
            readonly property real cardWidth: Math.floor((width - (root.choices.length - 1) * designs.gap) / Math.max(1, root.choices.length))
            implicitHeight: Math.round(designs.cardWidth * 0.56)

            Repeater {
                model: root.choices
                Item {
                    id: designCard
                    required property var modelData
                    required property int index
                    readonly property bool selected: root.value === designCard.modelData.value
                    x: designCard.index * (designs.cardWidth + designs.gap)
                    width: designs.cardWidth
                    height: Math.round(designCard.width * 0.56)
                    scale: designTap.pressed ? IrisStyle.pressScale(0.98) : 1
                    Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: Translation.tr(root.spec.label) + ": " + designCard.modelData.label
                    Accessible.checked: designCard.selected

                    ClippingRectangle {
                        id: picture
                        anchors.fill: parent
                        radius: IrisStyle.radiusTile
                        color: IrisStyle.fillQuiet
                        // A chamfered Design cuts the picture by its own die, as every plate on its field.
                        layer.enabled: IrisStyle.fieldChamfer
                        layer.smooth: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: designDie
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1
                        }
                        Loader {
                            anchors.fill: parent
                            source: designCard.modelData.preview
                            asynchronous: true
                        }
                    }
                    IrisCutPlate {
                        id: designDie
                        anchors.fill: parent
                        visible: false
                        layer.enabled: IrisStyle.fieldChamfer
                        color: "white" // iris-literal: a mask, never shown
                    }
                    // Chosen: the accent ring the material cards wear, outside the picture so it never covers it.
                    Rectangle {
                        visible: !IrisStyle.fieldChamfer
                        anchors.fill: parent
                        anchors.margins: -Math.round(3 * root.d)
                        radius: IrisStyle.radiusTile + Math.round(3 * root.d)
                        color: "transparent"
                        border.width: designCard.selected ? 2 : designHover.hovered ? 1 : 0
                        border.color: designCard.selected ? IrisStyle.accent : IrisStyle.borderStrong
                    }
                    IrisCutPlate {
                        readonly property int out: Math.round(3 * root.d)
                        visible: IrisStyle.fieldChamfer && (designCard.selected || designHover.hovered)
                        anchors.fill: parent
                        anchors.margins: -out
                        cutLength: IrisStyle.chamferCut + Math.round(out * (2 - Math.SQRT2))
                        stroke: designCard.selected ? (root.platePick ? IrisStyle.accentFill : IrisStyle.accent) : IrisStyle.borderStrong
                        strokeWidth: designCard.selected ? 2 : 1
                    }
                    HoverHandler { id: designHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: designTap; onTapped: root.commit(designCard.modelData.value) }
                }
            }
        }
    }

    // A material is shown as what it is: a body made of it, over your own wallpaper, glass or solid as the shell draws it
    // now, carrying its ink and the accent. Its name and one line under it, so no two read as the same pale dot.
    Component {
        id: materialCardsComponent

        Flow {
            id: materials
            readonly property real gap: Math.round(8 * root.d)
            readonly property int count: root.choices.length
            // All in one line when they fit at a readable width; else two lines as even as the count allows.
            readonly property int columns: {
                const fits = Math.max(1, Math.floor((width + gap) / (128 * root.d + gap)))
                return fits >= materials.count ? materials.count : Math.max(1, Math.min(fits, Math.ceil(materials.count / 2)))
            }
            readonly property real cardWidth: Math.floor((width - (materials.columns - 1) * materials.gap) / materials.columns)
            readonly property url picture: Wallpapers.stillUrlFor(String(Wallpapers.effectiveWallpaperPath ?? ""))
            spacing: materials.gap

            Repeater {
                model: root.choices
                Rectangle {
                    id: card
                    required property var modelData
                    readonly property bool selected: root.value === card.modelData.value
                    readonly property color stuff: card.modelData.swatch ?? IrisStyle.surfaceOpaque
                    readonly property real inset: Math.round(6 * root.d)
                    width: materials.cardWidth
                    height: scene.height + cardText.implicitHeight + card.inset + Math.round(18 * root.d)
                    radius: IrisStyle.radiusTile
                    readonly property color plate: root.pickFill(card.selected, cardHover.hovered)
                    color: IrisStyle.fieldChamfer ? "transparent" : card.plate
                    IrisCutPlate { anchors.fill: parent; visible: IrisStyle.fieldChamfer; color: card.plate; stroke: root.pickRule(card.selected); strokeWidth: card.selected ? 2 : 0 }
                    scale: cardTap.pressed ? IrisStyle.pressScale(0.97) : 1
                    Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                    Behavior on color { ColorAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: Translation.tr(root.spec.label) + ": " + Translation.tr(card.modelData.label)
                    Accessible.description: Translation.tr(card.modelData.detail ?? "")
                    Accessible.checked: card.selected

                    // The paper itself, as large as the card allows: the frame (when it is on) round a strip of the desktop
                    // with the Island hanging in it, and a panel below with a group in the fill step, its ink and the
                    // accent. Solid on purpose: side by side the papers can be told apart; how glass lays one over what is
                    // behind is the scene above (Black and Graphite under the same glass read the same at this size).
                    ClippingRectangle {
                        id: scene
                        readonly property bool framed: Boolean(Config.options?.iris?.surround?.enable ?? false)
                        readonly property real band: scene.framed ? Math.round(5 * root.d) : 0
                        x: card.inset
                        y: card.inset
                        width: card.width - 2 * card.inset
                        height: Math.round(76 * root.d)
                        // Concentric with the card: its radius less the air around the picture.
                        radius: IrisStyle.fieldChamfer ? 0 : Math.max(Math.round(5 * root.d), card.radius - card.inset)
                        color: card.stuff
                        // A chamfered card's picture is cut concentric with it: the card's cut less the air around it.
                        layer.enabled: IrisStyle.fieldChamfer
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: sceneDie
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1
                        }
                        ClippingRectangle {
                            id: desk
                            x: scene.band
                            y: scene.band
                            width: scene.width - 2 * scene.band
                            height: Math.round(scene.height * 0.42)
                            radius: scene.framed && !IrisStyle.fieldChamfer ? Math.max(Math.round(4 * root.d), scene.radius - scene.band) : 0
                            color: IrisStyle.fillQuiet
                            IrisImage { anchors.fill: parent; source: materials.picture }
                            // Melted into the frame's edge when there is one; floating under the screen's edge when not.
                            Rectangle {
                                width: Math.round(desk.width * 0.42)
                                height: Math.round(18 * root.d)
                                x: Math.round((desk.width - width) / 2)
                                y: scene.framed ? -Math.round(height / 2) : Math.round(3 * root.d)
                                radius: IrisStyle.capsule(height)
                                color: card.stuff
                            }
                        }
                        Rectangle {
                            id: group
                            x: Math.round(8 * root.d)
                            width: scene.width - 2 * x
                            y: desk.y + desk.height + Math.round(6 * root.d)
                            height: scene.height - y - Math.round(7 * root.d)
                            radius: IrisStyle.fieldChamfer ? 0 : Math.max(Math.round(4 * root.d), scene.radius - Math.round(6 * root.d))
                            // Fills are the ink at a low alpha over the paper, as on every surface.
                            color: IrisStyle.fill
                            Column {
                                x: Math.round(8 * root.d)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Math.round(4 * root.d)
                                Rectangle { width: Math.round(group.width * 0.46); height: Math.round(4 * root.d); radius: IrisStyle.capsule(height); color: IrisStyle.text }
                                Rectangle { width: Math.round(group.width * 0.3); height: Math.round(4 * root.d); radius: IrisStyle.capsule(height); color: IrisStyle.textTertiary }
                            }
                            Rectangle {
                                anchors.right: parent.right
                                anchors.rightMargin: Math.round(8 * root.d)
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.round(10 * root.d)
                                height: width
                                radius: IrisStyle.capsule(width)
                                color: IrisStyle.accent
                            }
                        }
                        // The picture's own edge, so a light paper never melts into a light card.
                        Rectangle { visible: !IrisStyle.fieldChamfer; anchors.fill: parent; radius: scene.radius; color: "transparent"; border.width: 1; border.color: IrisStyle.border }
                    }
                    IrisCutPlate {
                        id: sceneDie
                        x: scene.x
                        y: scene.y
                        width: scene.width
                        height: scene.height
                        visible: false
                        layer.enabled: IrisStyle.fieldChamfer
                        cutLength: IrisStyle.chamferCut - Math.round(card.inset * (2 - Math.SQRT2))
                        color: "white" // iris-literal: a mask, never shown
                    }
                    IrisCutPlate {
                        visible: IrisStyle.fieldChamfer
                        x: scene.x
                        y: scene.y
                        width: scene.width
                        height: scene.height
                        cutLength: sceneDie.cutLength
                        stroke: IrisStyle.border
                        strokeWidth: 1
                    }
                    Column {
                        id: cardText
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: scene.bottom
                        anchors.leftMargin: Math.round(10 * root.d)
                        anchors.rightMargin: Math.round(8 * root.d)
                        anchors.topMargin: Math.round(8 * root.d)
                        spacing: 0
                        RowLayout {
                            width: parent.width
                            spacing: Math.round(4 * root.d)
                            IrisText {
                                Layout.fillWidth: true
                                text: Translation.tr(card.modelData.label)
                                color: root.pickInk(card.selected)
                                elide: Text.ElideRight
                                font.pixelSize: IrisStyle.typeLabel
                                font.weight: IrisStyle.weight(card.selected ? Font.DemiBold : Font.Medium)
                            }
                            MaterialSymbol {
                                text: "check"
                                iconSize: Math.round(16 * root.d)
                                color: IrisStyle.accent
                                opacity: card.selected ? 1 : 0
                                scale: card.selected ? 1 : 0.6
                                Behavior on opacity { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                                Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                            }
                        }
                        IrisText {
                            width: parent.width
                            text: Translation.tr(card.modelData.detail ?? "")
                            color: root.pickDetail(card.selected)
                            elide: Text.ElideRight
                            font.pixelSize: IrisStyle.typeMeta
                        }
                    }
                    HoverHandler { id: cardHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: cardTap; onTapped: root.commit(card.modelData.value) }
                }
            }
        }
    }

    Component {
        id: swatchComponent

        Column {
            id: swatchSet
            readonly property var sources: root.spec.sources === true
                ? root.choices.filter(choice => root.sourceRank.indexOf(String(choice.value)) >= 0)
                    .sort((a, b) => root.sourceRank.indexOf(String(a.value)) - root.sourceRank.indexOf(String(b.value))) : []
            readonly property var named: root.choices.filter(choice => swatchSet.sources.indexOf(choice) < 0)
            readonly property real gap: Math.round(8 * root.d)
            // As many in a line as fit at a readable width; four that do not all fit sit two by two, never three and one.
            readonly property int fits: Math.max(1, Math.floor((width + gap) / (150 * root.d + gap)))
            readonly property int columns: {
                const count = Math.max(1, swatchSet.sources.length)
                const across = Math.min(count, swatchSet.fits)
                return count === 4 && across === 3 ? 2 : across
            }
            readonly property real cardWidth: Math.floor((width - (swatchSet.columns - 1) * swatchSet.gap) / swatchSet.columns)
            spacing: Math.round(14 * root.d)

            Flow {
                visible: swatchSet.sources.length > 0
                width: swatchSet.width
                spacing: swatchSet.gap
                Repeater {
                    model: swatchSet.sources
                    Rectangle {
                        id: source
                        required property var modelData
                        readonly property string kind: String(source.modelData.value)
                        readonly property bool selected: root.value === source.modelData.value
                        readonly property color gives: source.modelData.swatch !== undefined ? source.modelData.swatch : root.liveColour
                        readonly property real inset: Math.round(6 * root.d)
                        width: swatchSet.cardWidth
                        height: picture.height + sourceText.implicitHeight + source.inset + Math.round(18 * root.d)
                        radius: IrisStyle.radiusTile
                        readonly property color plate: root.pickFill(source.selected, sourceHover.hovered)
                        color: IrisStyle.fieldChamfer ? "transparent" : source.plate
                        IrisCutPlate { anchors.fill: parent; visible: IrisStyle.fieldChamfer; color: source.plate; stroke: root.pickRule(source.selected); strokeWidth: source.selected ? 2 : 0 }
                        scale: sourceTap.pressed ? IrisStyle.pressScale(0.97) : 1
                        Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                        Behavior on color { ColorAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                        Accessible.role: Accessible.RadioButton
                        Accessible.name: Translation.tr(root.spec.label) + ": " + Translation.tr(source.modelData.label)
                        Accessible.description: root.sourceDetail(source.kind)
                        Accessible.checked: source.selected

                        // The source itself: your picture, the theme's colour, the accent it borrows, the whole wheel.
                        ClippingRectangle {
                            id: picture
                            x: source.inset
                            y: source.inset
                            width: source.width - 2 * source.inset
                            height: Math.round(46 * root.d)
                            // Concentric with the card: its radius less the air around the picture.
                            radius: IrisStyle.fieldChamfer ? 0 : Math.max(Math.round(5 * root.d), source.radius - source.inset)
                            color: source.kind === "custom" ? "transparent" : source.gives
                            layer.enabled: IrisStyle.fieldChamfer
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: pictureDie
                                maskThresholdMin: 0.5
                                maskSpreadAtMin: 1
                            }
                            IrisImage {
                                visible: source.kind === "wallpaper"
                                anchors.fill: parent
                                source: source.kind === "wallpaper" ? Wallpapers.stillUrlFor(String(Wallpapers.effectiveWallpaperPath ?? "")) : ""
                            }
                            Rectangle {
                                visible: source.kind === "custom"
                                anchors.fill: parent
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: Qt.hsla(0, 0.8, 0.62, 1) } // iris-literal: hue ramp
                                    GradientStop { position: 0.17; color: Qt.hsla(0.17, 0.8, 0.62, 1) } // iris-literal: hue ramp
                                    GradientStop { position: 0.33; color: Qt.hsla(0.33, 0.8, 0.62, 1) } // iris-literal: hue ramp
                                    GradientStop { position: 0.5; color: Qt.hsla(0.5, 0.8, 0.62, 1) } // iris-literal: hue ramp
                                    GradientStop { position: 0.67; color: Qt.hsla(0.67, 0.8, 0.62, 1) } // iris-literal: hue ramp
                                    GradientStop { position: 0.83; color: Qt.hsla(0.83, 0.8, 0.62, 1) } // iris-literal: hue ramp
                                    GradientStop { position: 1; color: Qt.hsla(0.999, 0.8, 0.62, 1) } // iris-literal: hue ramp
                                }
                            }
                            // A theme brings its pair: the colour this row takes, and beside it the other one it sets.
                            Rectangle {
                                visible: source.kind === "theme"
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.round(parent.width * 0.3)
                                color: String(root.spec.path) === "iris.appearance.highlight"
                                    ? (IrisStyle.accents.theme ?? IrisStyle.accent) : (IrisStyle.highlights.theme ?? IrisStyle.secondaryAccent)
                            }
                            MaterialSymbol {
                                visible: source.kind === "accent"
                                anchors.centerIn: parent
                                text: "link"
                                iconSize: Math.round(18 * root.d)
                                color: IrisStyle.onTintFor(source.gives)
                            }
                            // The colour this source gives right now: on the picture it is taken from, or at its hue on the wheel.
                            Rectangle {
                                readonly property real hueAt: Math.max(0, Math.min(1, Number(Config.options?.iris?.appearance?.theme?.[
                                    String(root.spec.path) === "iris.appearance.highlight" ? "highlightHue" : "accentHue"] ?? 0) / 359))
                                visible: source.kind === "wallpaper" || (source.kind === "custom" && source.selected)
                                width: Math.round(16 * root.d)
                                height: width
                                radius: IrisStyle.capsule(width)
                                x: source.kind === "custom" ? Math.round(hueAt * (parent.width - width))
                                    : parent.width - width - Math.round(6 * root.d)
                                y: source.kind === "custom" ? Math.round((parent.height - height) / 2) : parent.height - height - Math.round(6 * root.d)
                                color: source.gives
                                border.width: Math.max(2, Math.round(2 * root.d))
                                border.color: IrisStyle.bodySurface
                            }
                            // The picture's own edge, so a light colour never melts into a light card.
                            Rectangle { visible: !IrisStyle.fieldChamfer; anchors.fill: parent; radius: picture.radius; color: "transparent"; border.width: 1; border.color: IrisStyle.border }
                        }
                        IrisCutPlate {
                            id: pictureDie
                            x: picture.x
                            y: picture.y
                            width: picture.width
                            height: picture.height
                            visible: false
                            layer.enabled: IrisStyle.fieldChamfer
                            cutLength: IrisStyle.chamferCut - Math.round(source.inset * (2 - Math.SQRT2))
                            color: "white" // iris-literal: a mask, never shown
                        }
                        IrisCutPlate {
                            visible: IrisStyle.fieldChamfer
                            x: picture.x
                            y: picture.y
                            width: picture.width
                            height: picture.height
                            cutLength: pictureDie.cutLength
                            stroke: IrisStyle.border
                            strokeWidth: 1
                        }
                        Column {
                            id: sourceText
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: picture.bottom
                            anchors.leftMargin: Math.round(10 * root.d)
                            anchors.rightMargin: Math.round(8 * root.d)
                            anchors.topMargin: Math.round(8 * root.d)
                            spacing: 0
                            RowLayout {
                                width: parent.width
                                spacing: Math.round(4 * root.d)
                                IrisText {
                                    Layout.fillWidth: true
                                    text: Translation.tr(source.modelData.label)
                                    color: root.pickInk(source.selected)
                                    elide: Text.ElideRight
                                    font.pixelSize: IrisStyle.typeLabel
                                    font.weight: IrisStyle.weight(source.selected ? Font.DemiBold : Font.Medium)
                                }
                                MaterialSymbol {
                                    text: "check"
                                    iconSize: Math.round(16 * root.d)
                                    color: IrisStyle.accent
                                    opacity: source.selected ? 1 : 0
                                    scale: source.selected ? 1 : 0.6
                                    Behavior on opacity { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                                    Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                                }
                            }
                            IrisText {
                                width: parent.width
                                text: root.sourceDetail(source.kind)
                                color: root.pickDetail(source.selected)
                                elide: Text.ElideRight
                                font.pixelSize: IrisStyle.typeMeta
                            }
                        }
                        HoverHandler { id: sourceHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { id: sourceTap; onTapped: root.commit(source.modelData.value) }
                    }
                }
            }

            Flow {
                width: swatchSet.width
                visible: swatchSet.named.length > 0
                spacing: Math.round(10 * root.d)
                Repeater {
                    model: swatchSet.named
                    MouseArea {
                        id: swatch
                        required property var modelData
                        readonly property bool selected: root.value === swatch.modelData.value
                        readonly property string special: swatch.modelData.swatch !== undefined ? "" : String(swatch.modelData.value)
                        width: Math.round(30 * root.d)
                        height: width
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.RadioButton
                        Accessible.name: Translation.tr(root.spec.label) + ": " + Translation.tr(swatch.modelData.label)
                        Accessible.checked: swatch.selected
                        activeFocusOnTab: true
                        Keys.onSpacePressed: root.commit(swatch.modelData.value)
                        onClicked: root.commit(swatch.modelData.value)
                        Rectangle {
                            anchors.fill: parent
                            radius: IrisStyle.capsule(width)
                            color: "transparent"
                            border.width: Math.max(2, Math.round(2 * root.d))
                            border.color: swatch.selected ? IrisStyle.text : swatch.containsMouse ? IrisStyle.borderStrong : "transparent"
                            Behavior on border.color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width - Math.round(8 * root.d)
                            height: width
                            radius: IrisStyle.capsule(width)
                            border.width: 1
                            border.color: IrisStyle.borderStrong
                            color: swatch.special === "wallpaper" ? IrisStyle.wallpaperLight
                                : swatch.special === "accent" ? IrisStyle.accent
                                : swatch.special === "custom" ? "transparent"
                                : swatch.modelData.swatch
                            gradient: swatch.special === "custom" ? spectrum : null
                            Gradient {
                                id: spectrum
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Qt.hsla(0, 0.8, 0.62, 1) } // iris-literal: hue ramp
                                GradientStop { position: 0.33; color: Qt.hsla(0.33, 0.8, 0.62, 1) } // iris-literal: hue ramp
                                GradientStop { position: 0.66; color: Qt.hsla(0.66, 0.8, 0.62, 1) } // iris-literal: hue ramp
                                GradientStop { position: 1; color: Qt.hsla(0.95, 0.8, 0.62, 1) } // iris-literal: hue ramp
                            }
                            MaterialSymbol {
                                anchors.centerIn: parent
                                visible: swatch.special === "wallpaper" || swatch.special === "accent"
                                text: swatch.special === "wallpaper" ? "wallpaper" : "link"
                                iconSize: Math.round(13 * root.d)
                                color: IrisStyle.inkOnAccent
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: curveComponent

        Item {
            id: curve
            property var points: IrisStyle.directCurve.slice()
            property int dragging: -1
            readonly property real inset: Math.round(14 * root.d)
            readonly property real side: width - 2 * inset
            readonly property real low: -0.3
            readonly property real high: 1.3
            implicitHeight: Math.round(170 * root.d)
            Accessible.name: Translation.tr(root.spec.label)
            Connections {
                target: IrisStyle
                function onDirectCurveChanged(): void { if (curve.dragging < 0) curve.points = IrisStyle.directCurve.slice() }
            }
            function px(x: real): real { return curve.inset + x * curve.side }
            function py(y: real): real { return curve.inset + (curve.high - y) / (curve.high - curve.low) * (curve.height - 2 * curve.inset) }
            function commit(): void {
                Config.setNestedValues({ "iris.appearance.theme.curve": "custom",
                    "iris.appearance.theme.curvePoints": curve.points.map(v => Math.round(v * 100) / 100) })
            }
            onPointsChanged: path.requestPaint()

            Rectangle {
                anchors.fill: parent
                radius: IrisStyle.radiusTile
                color: IrisStyle.fillQuiet
            }
            Rectangle { x: curve.px(0); y: curve.py(1); width: curve.side; height: 1; color: IrisStyle.hairline }
            Rectangle { x: curve.px(0); y: curve.py(0); width: curve.side; height: 1; color: IrisStyle.hairline }
            Canvas {
                id: path
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const p = curve.points
                    ctx.lineWidth = Math.max(1, root.d)
                    ctx.strokeStyle = IrisStyle.textTertiary
                    ctx.beginPath(); ctx.moveTo(curve.px(0), curve.py(0)); ctx.lineTo(curve.px(p[0]), curve.py(p[1])); ctx.stroke()
                    ctx.beginPath(); ctx.moveTo(curve.px(1), curve.py(1)); ctx.lineTo(curve.px(p[2]), curve.py(p[3])); ctx.stroke()
                    ctx.lineWidth = Math.max(2, 2.5 * root.d)
                    ctx.strokeStyle = IrisStyle.accent
                    ctx.beginPath()
                    ctx.moveTo(curve.px(0), curve.py(0))
                    ctx.bezierCurveTo(curve.px(p[0]), curve.py(p[1]), curve.px(p[2]), curve.py(p[3]), curve.px(1), curve.py(1))
                    ctx.stroke()
                }
            }
            Repeater {
                model: 2
                Rectangle {
                    id: handle
                    required property int index
                    width: Math.round(16 * root.d)
                    height: width
                    radius: IrisStyle.capsule(width)
                    x: curve.px(curve.points[handle.index * 2]) - width / 2
                    y: curve.py(curve.points[handle.index * 2 + 1]) - height / 2
                    color: IrisStyle.text
                    border.width: Math.max(2, Math.round(2 * root.d))
                    border.color: IrisStyle.accent
                    scale: curve.dragging === handle.index ? 1.2 : 1
                    Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                }
            }
            MouseArea {
                anchors.fill: parent
                preventStealing: true
                cursorShape: Qt.PointingHandCursor
                function valueAt(mx: real, my: real): var {
                    const x = Math.max(0, Math.min(1, (mx - curve.inset) / curve.side))
                    const y = Math.max(curve.low, Math.min(curve.high, curve.high - (my - curve.inset) / (curve.height - 2 * curve.inset) * (curve.high - curve.low)))
                    return [x, y]
                }
                onPressed: mouse => {
                    const d0 = Math.hypot(mouse.x - curve.px(curve.points[0]), mouse.y - curve.py(curve.points[1]))
                    const d1 = Math.hypot(mouse.x - curve.px(curve.points[2]), mouse.y - curve.py(curve.points[3]))
                    curve.dragging = d0 <= d1 ? 0 : 1
                }
                onPositionChanged: mouse => {
                    if (curve.dragging < 0) return
                    const v = valueAt(mouse.x, mouse.y)
                    const next = curve.points.slice()
                    next[curve.dragging * 2] = v[0]
                    next[curve.dragging * 2 + 1] = v[1]
                    curve.points = next
                }
                onReleased: { if (curve.dragging >= 0) curve.commit(); curve.dragging = -1 }
            }
        }
    }

    Component {
        id: hueComponent

        Item {
            id: hue
            // Like a range: the drag is seen live in memory (Config.previewNestedValue) and written once, on release.
            // Writing per pixel bumped Config.revision and re-read every row of Settings on each step.
            property real dragHue: NaN
            readonly property real shownHue: Number.isFinite(hue.dragHue) ? hue.dragHue : Number(root.value ?? 0)
            readonly property real fraction: Math.max(0, Math.min(1, hue.shownHue / 359))
            function preview(): void { if (Number.isFinite(hue.dragHue)) Config.previewNestedValue(root.spec.path, hue.dragHue) }
            function settle(): void {
                huePreview.stop()
                // A tap on the hue already chosen writes nothing; a drag that moved writes once.
                if (Number.isFinite(hue.dragHue) && hue.dragHue !== Number(root.value)) root.commit(hue.dragHue)
                else if (Number.isFinite(hue.dragHue)) Config.previewNestedValue(root.spec.path, Number(root.value))
                hue.dragHue = NaN
            }
            // A step re-solves the palette: half the frame pace is as live as the eye needs.
            Timer { id: huePreview; interval: 48; onTriggered: hue.preview() }
            implicitHeight: Math.round(24 * root.d)
            Accessible.role: Accessible.Slider
            Accessible.name: Translation.tr(root.spec.label)
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: Math.round(10 * root.d)
                radius: IrisStyle.capsule(height)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.hsla(0, 0.8, 0.62, 1) } // iris-literal: hue ramp
                    GradientStop { position: 0.17; color: Qt.hsla(0.17, 0.8, 0.62, 1) } // iris-literal: hue ramp
                    GradientStop { position: 0.33; color: Qt.hsla(0.33, 0.8, 0.62, 1) } // iris-literal: hue ramp
                    GradientStop { position: 0.5; color: Qt.hsla(0.5, 0.8, 0.62, 1) } // iris-literal: hue ramp
                    GradientStop { position: 0.67; color: Qt.hsla(0.67, 0.8, 0.62, 1) } // iris-literal: hue ramp
                    GradientStop { position: 0.83; color: Qt.hsla(0.83, 0.8, 0.62, 1) } // iris-literal: hue ramp
                    GradientStop { position: 1; color: Qt.hsla(0.999, 0.8, 0.62, 1) } // iris-literal: hue ramp
                }
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(20 * root.d)
                height: width
                radius: IrisStyle.capsule(width)
                x: hue.fraction * (parent.width - width)
                color: Qt.hsla(hue.fraction, 0.8, 0.62, 1) // iris-literal: the hue itself
                border.width: Math.max(2, Math.round(2.5 * root.d))
                // Focus from the keyboard shows on the knob: ← and → step the hue.
                border.color: hue.activeFocus && !hueArea.pressed ? IrisStyle.accent : IrisStyle.text
                scale: hueArea.pressed ? 1.12 : 1
                Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
            }
            MouseArea {
                id: hueArea
                anchors.fill: parent
                // A sideways drag inside a scrolling page stays with the hue.
                preventStealing: true
                cursorShape: Qt.PointingHandCursor
                function pick(x: real): void {
                    const value = Math.round(Math.max(0, Math.min(1, x / Math.max(1, width))) * 359)
                    if (value === hue.dragHue) return
                    hue.dragHue = value
                    if (!huePreview.running) { hue.preview(); huePreview.restart() }
                }
                onPressed: mouse => { hue.forceActiveFocus(); hueArea.pick(mouse.x) }
                onPositionChanged: mouse => { if (hueArea.pressed) hueArea.pick(mouse.x) }
                onReleased: hue.settle()
                onCanceled: hue.settle()
            }
            Keys.onLeftPressed: root.commit((Math.round(hue.shownHue) + 355) % 360)
            Keys.onRightPressed: root.commit((Math.round(hue.shownHue) + 5) % 360)
            activeFocusOnTab: true
        }
    }

    component FaceChip: IrisChip {
        implicitHeight: Math.round(28 * root.d)
        colBackground: IrisStyle.fillQuiet
        colBackgroundHover: IrisStyle.fillHover
        colBackgroundToggled: IrisStyle.fillActive
        colBackgroundToggledHover: IrisStyle.fillActive
        foreground: selected ? IrisStyle.text : IrisStyle.subtext
    }

    Component {
        id: installedFontsComponent

        ColumnLayout {
            id: fonts
            property string query: ""
            readonly property string current: String(root.value ?? "")
            readonly property var families: {
                const seen = {}
                return Qt.fontFamilies().filter(family => {
                    if (family.startsWith(".") || seen[family]) return false
                    seen[family] = true
                    return true
                })
            }
            readonly property var matches: {
                const words = fonts.query.trim().toLowerCase()
                const found = words.length > 0 ? fonts.families.filter(family => family.toLowerCase().includes(words)) : fonts.families
                return found.slice(0, 48)
            }
            spacing: Math.round(8 * root.d)

            IrisField {
                id: search
                Layout.fillWidth: true
                implicitHeight: Math.round(36 * root.d)
                font.pixelSize: IrisStyle.typeLabel
                placeholderText: Translation.tr("Search installed fonts")
                onTextChanged: fonts.query = search.text
                Component.onCompleted: search.forceActiveFocus()
                onAccepted: if (fonts.matches.length > 0) { root.commit(fonts.matches[0]); root.fontSearch = false }
                // Escape closes the search before it closes anything else.
                Keys.onShortcutOverride: event => { if (event.key === Qt.Key_Escape) event.accepted = true }
                Keys.onEscapePressed: root.fontSearch = false
            }
            Flow {
                visible: fonts.matches.length > 0
                Layout.fillWidth: true
                spacing: Math.round(6 * root.d)
                Repeater {
                    model: fonts.matches
                    FaceChip {
                        required property string modelData
                        label: modelData
                        labelFamily: modelData
                        labelCap: Math.round(220 * root.d)
                        selected: modelData === fonts.current
                        onClicked: { root.commit(modelData); root.fontSearch = false }
                    }
                }
            }
            IrisText {
                visible: fonts.matches.length === 0
                text: Translation.tr("No installed font matches")
                color: IrisStyle.subtext
                font.pixelSize: IrisStyle.typeMeta
            }
        }
    }

    Component {
        id: textComponent

        IrisField {
            id: field
            implicitWidth: Math.round(160 * root.d)
            implicitHeight: Math.round(36 * root.d)
            font.pixelSize: IrisStyle.typeLabel
            placeholderText: Translation.tr(String(root.spec.placeholder ?? ""))
            horizontalAlignment: root.spec.short ? Text.AlignHCenter : Text.AlignLeft
            echoMode: root.spec.secret ? TextInput.Password : TextInput.Normal
            // A numeric row's 0 means unset: the field shows its placeholder.
            readonly property string stored: root.spec.numeric && Number(root.value ?? 0) === 0 ? "" : String(root.value ?? "")
            text: field.stored
            Accessible.name: Translation.tr(root.spec.label)
            onTextChanged: if (field.text !== field.stored) commitDelay.restart()
            Timer {
                id: commitDelay
                interval: 400
                onTriggered: root.commit(field.text.trim())
            }
            onEditingFinished: { commitDelay.stop(); root.commit(field.text.trim()) }
        }
    }

    Component {
        id: iconComponent

        Flow {
            id: iconFlow
            readonly property string piece: String(root.spec.piece ?? "")
            spacing: Math.round(6 * root.d)
            Repeater {
                model: [""].concat(root.spec.glyphs ?? [])
                MouseArea {
                    id: iconTile
                    required property string modelData
                    readonly property bool isDefault: iconTile.modelData.length === 0
                    readonly property bool selected: iconTile.modelData === String(root.value)
                    readonly property string glyph: iconTile.isDefault
                        ? IrisPieces.defaultGlyph(iconFlow.piece) : iconTile.modelData
                    width: Math.round(40 * root.d)
                    height: width
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    activeFocusOnTab: true
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: iconTile.isDefault ? Translation.tr("Default") : iconTile.modelData
                    Accessible.checked: iconTile.selected
                    Keys.onSpacePressed: root.commit(iconTile.modelData)
                    Keys.onReturnPressed: root.commit(iconTile.modelData)
                    onClicked: root.commit(iconTile.modelData)
                    Rectangle {
                        anchors.fill: parent
                        radius: IrisStyle.radiusTile
                        color: iconTile.selected ? IrisStyle.fillActive
                            : iconTile.containsMouse ? IrisStyle.fillHover : IrisStyle.fillQuiet
                        border.width: iconTile.activeFocus ? 1 : 0
                        border.color: IrisStyle.accent
                        Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                    }
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: iconTile.glyph
                        iconSize: Math.round(20 * root.d)
                        fill: iconTile.selected ? 1 : 0
                        color: iconTile.selected ? IrisStyle.accent
                            : iconTile.isDefault ? IrisStyle.muted : IrisStyle.subtext
                    }
                    Rectangle {
                        visible: iconTile.isDefault
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Math.round(4 * root.d)
                        width: Math.round(10 * root.d)
                        height: Math.max(1, Math.round(1.5 * root.d))
                        radius: IrisStyle.capsule(height)
                        color: iconTile.selected ? IrisStyle.accent : IrisStyle.muted
                    }
                }
            }
        }
    }

    Component {
        id: popupComponent

        IrisPopupButton {
            readonly property string chosenFace: String(root.value ?? "")
            options: root.choices
            current: root.value
            maxWidth: root.controlWidth
            accessibleName: Translation.tr(root.spec.label)
            fontFor: root.spec.previewFont ? (choice => root.previewFace(choice)) : null
            otherText: root.spec.installedFonts === true && chosenFace.length > 0 ? chosenFace : Translation.tr("Custom")
            otherFamily: root.spec.installedFonts === true ? chosenFace : ""
            extra: root.spec.installedFonts === true
                ? [{ text: Translation.tr("Other font…"), action: () => { root.fontSearch = true } }] : []
            discloses: root.listInline
            expanded: root.listOpen
            onDisclose: root.toggleList()
            onPicked: value => root.commit(value)
        }
    }

    Component {
        id: choiceGridComponent

        IrisChoiceGrid {
            options: root.choices
            current: root.value
            accessibleName: Translation.tr(root.spec.label)
            fontFor: root.spec.previewFont ? (choice => root.previewFace(choice)) : null
            extra: root.spec.installedFonts === true
                ? [{ text: Translation.tr("Other font…"), glyph: "search", action: () => { IrisOptions.openList = ""; root.fontSearch = true } }] : []
            // The pick lands, then the list folds back into its row.
            onPicked: value => { root.commit(value); listClose.restart() }
            onDismissed: IrisOptions.openList = ""
        }
    }

    Component {
        id: segmentedComponent

        IrisSegmented {
            options: root.choices
            current: root.value
            // In the row's column the names carry the choice; glyphs stack only in the full-width track.
            pictured: root.pictured && !root.inlineChoice
            accessibleName: Translation.tr(root.spec.label)
            fontFor: choice => root.previewFace(choice)
            onPicked: value => root.commit(value)
        }
    }
}
