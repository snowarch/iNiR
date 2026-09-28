pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
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
    function marked(text: string): string {
        const plain = part => part.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        const terms = root.highlight.trim().split(/\s+/).filter(term => term.length > 1)
            .map(term => term.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"))
        if (terms.length === 0) return plain(text)
        return text.split(new RegExp("(" + terms.join("|") + ")", "i"))
            .map((part, index) => index % 2 ? "<font color='" + IrisStyle.accent + "'><b>" + plain(part) + "</b></font>" : plain(part))
            .join("")
    }
    readonly property real d: IrisStyle.density
    readonly property var value: {
        Config.revision
        return IrisOptions.currentValue(root.spec)
    }
    function commit(next: var): void { IrisOptions.commit(root.spec, next) }
    function previewFace(choice: var): string {
        if (!root.spec.previewFont) return IrisStyle.fontMain
        const bundle = root.spec.bundle ?? []
        return bundle.length > 0 ? IrisStyle.face(bundle[0], choice.values[0]) : IrisStyle.face(root.spec.path, choice.value)
    }
    readonly property var choices: {
        IrisNiri.revision
        return IrisOptions.choicesOf(root.spec)
    }
    readonly property bool resettable: IrisOptions.resettable(root.spec)
    readonly property bool modified: root.resettable && !IrisOptions.same(root.value, root.spec.fallback)
    readonly property bool pictured: root.choices.some(choice => String(choice.glyph ?? "").length > 0)
    readonly property bool swatched: root.spec.kind === "choice" && root.choices.length > 0
        && root.choices.every(choice => choice.swatch !== undefined || ["wallpaper", "accent", "custom", "theme"].includes(choice.value))
        && root.choices.some(choice => choice.swatch !== undefined)
    readonly property bool inlineChoice: root.spec.kind === "choice" && root.choices.length <= 3 && !root.pictured && !root.swatched
        && root.choices.every(choice => String(choice.label).length <= 11)

    implicitHeight: layout.implicitHeight + Math.round(22 * root.d)

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
                        font.pixelSize: IrisStyle.typeLabel
                        font.weight: IrisStyle.weight(Font.Medium)
                        wrapMode: Text.WordWrap
                    }
                    Item {
                        id: resetMark
                        x: label.x + Math.min(label.contentWidth, label.width) + Math.round(6 * root.d)
                        y: Math.round((label.font.pixelSize * 1.4 - height) / 2)
                        width: Math.round(18 * root.d)
                        height: width
                        opacity: root.modified ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                        Rectangle {
                            anchors.centerIn: parent
                            width: resetArea.containsMouse ? resetMark.width : Math.round(7 * root.d)
                            height: width
                            radius: width / 2
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
                    color: IrisStyle.muted
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
            }

            // A trailing value reads on the title's line, in the interface face: the title leads, the value answers.
            IrisText {
                visible: root.swatched
                Layout.alignment: Qt.AlignTop
                Layout.preferredHeight: label.implicitHeight
                verticalAlignment: Text.AlignVCenter
                text: Translation.tr(String(root.choices.find(choice => choice.value === root.value)?.label ?? ""))
                color: IrisStyle.subtext
                font.pixelSize: IrisStyle.typeLabel
            }

            IrisText {
                visible: root.spec.kind === "range"
                Layout.alignment: Qt.AlignTop
                Layout.preferredHeight: label.implicitHeight
                verticalAlignment: Text.AlignVCenter
                text: Translation.tr(IrisOptions.rangeText(root.spec, root.value))
                color: IrisStyle.subtext
                font.features: ({ "tnum": 1 })
                font.pixelSize: IrisStyle.typeLabel
            }

            IrisSwitch {
                id: toggle
                visible: root.spec.kind === "switch"
                on: root.spec.invert ? !Boolean(root.value) : Boolean(root.value)
                name: Translation.tr(root.spec.label)
                onToggled: root.commit(root.spec.invert ? toggle.on : !toggle.on)
            }

            IrisButton {
                visible: root.spec.kind === "action"
                Layout.alignment: Qt.AlignVCenter
                text: Translation.tr(String(root.spec.button ?? ""))
                colBackground: IrisStyle.fill
                colBackgroundHover: IrisStyle.fillHover
                onClicked: root.spec.run()
            }

            Loader {
                active: root.inlineChoice
                visible: active
                Layout.preferredWidth: Math.round(Math.min(90 * root.choices.length, 270) * root.d)
                sourceComponent: segmentedComponent
            }

            Loader {
                active: root.spec.kind === "zone"
                visible: active
                sourceComponent: zoneComponent
            }
        }

        IrisScrubber {
            id: rangeScrubber
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(22 * root.d)
            visible: root.spec.kind === "range"
            knob: true
            Accessible.name: Translation.tr(root.spec.label)
            stepSize: (root.spec.step ?? 1) / Math.max(1, root.spec.max - root.spec.min)
            fillColor: IrisStyle.accent
            trackColor: IrisStyle.fill
            value: root.spec.kind === "range" ? (Number(root.value) - root.spec.min) / (root.spec.max - root.spec.min) : 0
            onMoved: next => {
                const step = root.spec.step ?? 1
                const span = root.spec.max - root.spec.min
                const raw = root.spec.min + next * span
                // A drag passing the default holds there, so it can always be found again; keys and the wheel step freely.
                const home = Number(root.spec.fallback)
                const held = rangeScrubber.dragging && Number.isFinite(home) && Math.abs(raw - home) < span * 0.02
                const value = held ? home : Number((Math.round(raw / step) * step).toFixed(4))
                if (value !== Number(root.value)) root.commit(value)
            }
        }

        Loader {
            Layout.fillWidth: true
            active: root.spec.kind === "choice" && !root.inlineChoice && !root.swatched
            visible: active
            sourceComponent: !root.pictured && labelMeasure.implicitWidth > layout.width ? chipsComponent : segmentedComponent
        }

        Loader {
            Layout.fillWidth: true
            active: root.swatched
            visible: active
            sourceComponent: swatchComponent
        }

        Loader {
            Layout.fillWidth: true
            active: root.spec.kind === "curve"
            visible: active
            sourceComponent: curveComponent
        }

        Loader {
            Layout.fillWidth: true
            active: root.spec.kind === "hue"
            visible: active
            sourceComponent: hueComponent
        }

        Loader {
            Layout.fillWidth: true
            active: root.spec.kind === "pieces"
            visible: active
            sourceComponent: piecesComponent
        }

        Loader {
            Layout.fillWidth: true
            // A field sized by its text feeds its width back through fillWidth: a loop.
            Layout.preferredWidth: 0
            active: root.spec.kind === "text"
            visible: active
            sourceComponent: textComponent
        }

        Loader {
            Layout.fillWidth: true
            active: root.spec.kind === "icon"
            visible: active
            sourceComponent: iconComponent
        }

        Loader {
            Layout.fillWidth: true
            active: root.spec.kind === "niriMotion"
            visible: active
            sourceComponent: IrisNiriMotionGallery {}
        }

        Loader {
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
                    order: picker.picked.indexOf(String(chip.modelData.value))
                    selected: chip.order >= 0
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

    Component {
        id: swatchComponent

        Flow {
            spacing: Math.round(10 * root.d)
            Repeater {
                model: root.choices
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
                        radius: width / 2
                        color: "transparent"
                        border.width: Math.max(2, Math.round(2 * root.d))
                        border.color: swatch.selected ? IrisStyle.text : swatch.containsMouse ? IrisStyle.borderStrong : "transparent"
                        Behavior on border.color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - Math.round(8 * root.d)
                        height: width
                        radius: width / 2
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
                            color: IrisStyle.onAccent
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
                    radius: width / 2
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
            readonly property real fraction: Math.max(0, Math.min(1, Number(root.value ?? 0) / 359))
            implicitHeight: Math.round(24 * root.d)
            Accessible.role: Accessible.Slider
            Accessible.name: Translation.tr(root.spec.label)
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: Math.round(10 * root.d)
                radius: height / 2
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
                radius: width / 2
                x: hue.fraction * (parent.width - width)
                color: Qt.hsla(hue.fraction, 0.8, 0.62, 1) // iris-literal: the hue itself
                border.width: Math.max(2, Math.round(2.5 * root.d))
                border.color: IrisStyle.text
                scale: hueArea.pressed ? 1.12 : 1
                Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
            }
            MouseArea {
                id: hueArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                function pick(x: real): void {
                    const value = Math.round(Math.max(0, Math.min(1, x / Math.max(1, width))) * 359)
                    if (value !== Number(root.value)) root.commit(value)
                }
                onPressed: mouse => hueArea.pick(mouse.x)
                onPositionChanged: mouse => { if (hueArea.pressed) hueArea.pick(mouse.x) }
            }
        }
    }

    Row {
        id: labelMeasure
        visible: false
        spacing: Math.round(22 * root.d)
        Repeater {
            model: root.spec.kind === "choice" ? root.choices : []
            IrisText {
                required property var modelData
                text: Translation.tr(modelData.label)
                font.pixelSize: IrisStyle.typeMeta
                font.weight: IrisStyle.weight(Font.DemiBold)
            }
        }
    }

    Component {
        id: chipsComponent

        Flow {
            spacing: Math.round(6 * root.d)
            Repeater {
                model: root.choices
                MouseArea {
                    id: chip
                    required property var modelData
                    readonly property bool selected: chip.modelData.value === root.value
                    width: chipLabel.implicitWidth + Math.round(24 * root.d)
                    height: Math.round(28 * root.d)
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    activeFocusOnTab: true
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: Translation.tr(root.spec.label) + ": " + Translation.tr(chip.modelData.label)
                    Accessible.checked: chip.selected
                    Keys.onSpacePressed: root.commit(chip.modelData.value)
                    Keys.onReturnPressed: root.commit(chip.modelData.value)
                    onClicked: root.commit(chip.modelData.value)
                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: chip.selected ? IrisStyle.fillActive : chip.containsMouse ? IrisStyle.fillHover : IrisStyle.fillQuiet
                        border.width: chip.activeFocus ? 1 : 0
                        border.color: IrisStyle.accent
                        Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                    }
                    IrisText {
                        id: chipLabel
                        anchors.centerIn: parent
                        text: Translation.tr(chip.modelData.label)
                        font.family: root.previewFace(chip.modelData)
                        font.pixelSize: IrisStyle.typeMeta
                        font.weight: chip.selected ? Font.DemiBold : Font.Normal
                        color: chip.selected ? IrisStyle.text : IrisStyle.subtext
                    }
                }
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
            text: String(root.value ?? "")
            Accessible.name: Translation.tr(root.spec.label)
            onTextChanged: if (field.text !== String(root.value ?? "")) commitDelay.restart()
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
                        radius: height / 2
                        color: iconTile.selected ? IrisStyle.accent : IrisStyle.muted
                    }
                }
            }
        }
    }

    Component {
        id: segmentedComponent

        IrisSegmented {
            options: root.choices
            current: root.value
            pictured: root.pictured
            accessibleName: Translation.tr(root.spec.label)
            fontFor: choice => root.previewFace(choice)
            onPicked: value => root.commit(value)
        }
    }
}
