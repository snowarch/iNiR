pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

ColumnLayout {
    id: root

    required property var widget
    // Hosted by the lock inspector: closing lets go of the selection and removing takes it off the lock only.
    property bool onLock: false
    signal closeRequested()
    function close(): void {
        if (root.onLock) root.closeRequested()
        else root.widget.closeQuickControls()
    }
    readonly property real d: IrisStyle.density
    // The corner of its plates: the sheet that hosts it sets it, so they stay concentric with that sheet (DI29).
    property real plateRadius: IrisStyle.radiusRow
    // Under a chamfered Design the plates take the cut instead, nested in the sheet's (`IrisStyle.nestedCut`).
    property real plateCut: IrisStyle.chamferCut
    readonly property var pages: [
        { value: "widget", label: Translation.tr("Widget") },
        { value: "look", label: Translation.tr("Look") },
        { value: "arrange", label: Translation.tr("Arrange") }
    ].concat(root.widget.stacked ? [{ value: "stack", label: Translation.tr("Stack") }] : [])
    readonly property string page: root.pages.some(entry => entry.value === root.widget._quickTab) ? root.widget._quickTab : "widget"
    readonly property string title: {
        const words = String(root.widget.configEntryName).split(".").pop().replace(/([A-Z])/g, " $1").toLowerCase()
        return words.charAt(0).toUpperCase() + words.slice(1)
    }
    readonly property string wallpaperUrl: WallpaperListener.wallpaperUrlForScreen(root.QsWindow?.window?.screen ?? null)
    readonly property string ownMaterial: String(root.widget._readConfigKey("iris.material") ?? "auto")
    readonly property string sharedMaterial: String(Config.options?.iris?.widgets?.material ?? "glass")
    readonly property var materials: [
        { value: "auto", label: Translation.tr("Default") },
        { value: "glass", label: Translation.tr("Glass") },
        { value: "clear", label: Translation.tr("Transparent") },
        { value: "solid", label: Translation.tr("Solid") },
        { value: "tinted", label: Translation.tr("Tinted") }
    ]
    readonly property real cornerMax: 40
    readonly property int cornerValue: Number(root.widget.cornerRadiusOverride)
    function cornerFrom(value: real): int {
        const px = Math.round(value * root.cornerMax / 2) * 2
        return px <= 0 ? -1 : px
    }
    readonly property real opacityMin: 20
    readonly property int opacityValue: Math.round(root.widget.irisSurfaceOpacity * 100)
    function opacityFrom(value: real): int {
        return Math.round((root.opacityMin + value * (100 - root.opacityMin)) / 5) * 5
    }
    readonly property real scaleMin: 60
    readonly property real scaleMax: 160
    readonly property real scaleValue: Math.round(root.widget.scaleFactor * 100)
    readonly property var zones: root.widget._snapZones ?? []
    readonly property var zoneGlyphs: ({ topLeft: "north_west", topCenter: "north", topRight: "north_east",
        centerLeft: "west", center: "filter_center_focus", centerRight: "east",
        bottomLeft: "south_west", bottomCenter: "south", bottomRight: "south_east" })

    function materialColor(value: string): color {
        const material = value === "auto" ? root.sharedMaterial : value
        if (material === "tinted")
            return root.widget.irisTintedPlate
        if (material === "solid")
            return IrisStyle.surface
        return ColorUtils.applyAlpha(IrisStyle.surface, IrisStyle.materialVeil[material] ?? 1)
    }

    readonly property real resolvedWidth: Math.round(336 * root.d)
    spacing: Math.round(14 * root.d)

    component Caption: IrisText {
        Layout.fillWidth: true
        color: IrisStyle.textSecondary
        font.pixelSize: IrisStyle.typeMeta
        font.weight: IrisStyle.weight(Font.DemiBold)
    }

    // One pick drawn as what it gives: the room it takes, the design it wears.
    component ChoiceTile: Rectangle {
        id: tile
        property bool chosen: false
        property string label: ""
        default property alias mark: markBox.data
        signal picked()
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.maximumWidth: Number.POSITIVE_INFINITY
        Layout.preferredHeight: Math.round(78 * root.d)
        radius: root.plateRadius
        readonly property color stuff: tile.chosen ? IrisStyle.tintFill(IrisStyle.accent)
            : tileHover.hovered ? IrisStyle.fillHover : IrisStyle.fillQuiet
        color: IrisStyle.fieldChamfer ? "transparent" : tile.stuff
        border.width: tile.chosen && !IrisStyle.fieldChamfer ? 1 : 0
        border.color: IrisStyle.tintBorder(IrisStyle.accent)
        scale: tileTap.pressed ? IrisStyle.pressScale(0.96) : 1
        Behavior on color { ColorAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
        Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
        IrisCutPlate {
            anchors.fill: parent
            visible: IrisStyle.fieldChamfer
            cutLength: root.plateCut
            color: tile.stuff
            stroke: IrisStyle.tintBorder(IrisStyle.accent)
            strokeWidth: tile.chosen ? 1 : 0
        }
        Item {
            id: markBox
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Math.round(11 * root.d) // iris-literal: a design specimen, drawn to scale
            width: Math.round(40 * root.d)
            height: Math.round(32 * root.d)
        }
        IrisText {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Math.round(4 * root.d)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(9 * root.d) // iris-literal: a design specimen, drawn to scale
            horizontalAlignment: Text.AlignHCenter
            text: tile.label
            color: tile.chosen ? IrisStyle.text : IrisStyle.textSecondary
            font.pixelSize: IrisStyle.typeMeta
            font.weight: tile.chosen ? Font.DemiBold : Font.Medium
            elide: Text.ElideRight
        }
        HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: tileTap; gesturePolicy: TapHandler.WithinBounds; onTapped: tile.picked() }
        Accessible.role: Accessible.RadioButton
        Accessible.name: tile.label
        Accessible.checked: tile.chosen
    }

    // A design's specimen, drawn in its own manner: the face's big figure, Material's pill,
    // the instrument's dial, the readout's ruled rows.
    component DesignMark: Item {
        id: mark
        property string design: ""
        property bool on: false
        readonly property color ink: mark.on ? IrisStyle.accent : IrisStyle.textTertiary
        readonly property real line: Math.max(1, Math.round(1.5 * root.d))
        anchors.fill: parent

        Rectangle {
            visible: mark.design === "iris"
            anchors.centerIn: parent
            width: Math.round(36 * root.d)
            height: Math.round(30 * root.d)
            radius: Math.round(9 * root.d) // iris-literal: a design specimen, drawn to scale
            color: ColorUtils.applyAlpha(mark.ink, 0.16) // iris-literal: a design specimen, drawn to scale
            Rectangle {
                x: Math.round(6 * root.d)
                y: Math.round(6 * root.d)
                width: Math.round(9 * root.d)
                height: Math.round(3 * root.d)
                radius: height / 2
                color: mark.ink
            }
            IrisText {
                x: Math.round(5 * root.d)
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round(1 * root.d) // iris-literal: a design specimen, drawn to scale
                text: "21"
                color: mark.on ? IrisStyle.text : IrisStyle.textSecondary
                font.family: IrisStyle.fontTitle
                font.pixelSize: Math.round(17 * root.d)
                font.weight: Font.Bold
            }
        }

        Rectangle {
            visible: mark.design === "material"
            anchors.centerIn: parent
            width: Math.round(38 * root.d)
            height: Math.round(20 * root.d)
            radius: height / 2
            color: ColorUtils.applyAlpha(mark.ink, 0.2) // iris-literal: a design specimen, drawn to scale
            Rectangle {
                id: materialDot
                x: Math.round(4 * root.d)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(12 * root.d)
                height: width
                radius: width / 2
                color: mark.ink
            }
            Column {
                anchors.left: materialDot.right
                anchors.leftMargin: Math.round(4 * root.d)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(2 * root.d)
                Rectangle { width: Math.round(14 * root.d); height: Math.round(3 * root.d); radius: height / 2; color: mark.on ? IrisStyle.text : IrisStyle.textSecondary }
                Rectangle { width: Math.round(9 * root.d); height: Math.round(3 * root.d); radius: height / 2; color: ColorUtils.applyAlpha(mark.ink, 0.6) } // iris-literal: a design specimen, drawn to scale
            }
        }

        Item {
            visible: mark.design === "instrument"
            anchors.centerIn: parent
            width: Math.round(30 * root.d)
            height: width
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: mark.line
                border.color: ColorUtils.applyAlpha(mark.ink, 0.45) // iris-literal: a design specimen, drawn to scale
            }
            Repeater {
                model: 12
                Item {
                    id: tick
                    required property int index
                    anchors.fill: parent
                    rotation: tick.index * 30
                    Rectangle {
                        x: (parent.width - width) / 2
                        y: Math.round(4 * root.d)
                        width: mark.line
                        height: tick.index % 3 === 0 ? Math.round(5 * root.d) : Math.round(3 * root.d)
                        radius: width / 2
                        color: tick.index % 3 === 0 ? mark.ink : ColorUtils.applyAlpha(mark.ink, 0.5) // iris-literal: a design specimen, drawn to scale
                    }
                }
            }
            Item {
                anchors.fill: parent
                rotation: 52
                Rectangle {
                    x: (parent.width - width) / 2
                    y: Math.round(6 * root.d)
                    width: Math.max(1.5, Math.round(2 * root.d))
                    height: parent.height / 2 - y
                    radius: width / 2
                    color: mark.on ? IrisStyle.text : IrisStyle.textSecondary
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: Math.round(4 * root.d)
                height: width
                radius: width / 2
                color: mark.ink
            }
        }

        Column {
            visible: mark.design === "readout"
            anchors.centerIn: parent
            spacing: Math.round(6 * root.d)
            Repeater {
                model: [12, 7, 10]
                Item {
                    id: readRow
                    required property int modelData
                    required property int index
                    width: Math.round(38 * root.d)
                    height: Math.round(3 * root.d)
                    Rectangle {
                        id: readName
                        width: Math.round(9 * root.d)
                        height: parent.height
                        radius: Math.round(1 * root.d) // iris-literal: a design specimen, drawn to scale
                        color: ColorUtils.applyAlpha(mark.on ? IrisStyle.text : IrisStyle.textSecondary, 0.55) // iris-literal: a design specimen, drawn to scale
                    }
                    Rectangle {
                        id: readValue
                        anchors.right: parent.right
                        width: Math.round(readRow.modelData * root.d)
                        height: parent.height
                        radius: Math.round(1 * root.d) // iris-literal: a design specimen, drawn to scale
                        color: readRow.index === 0 ? mark.ink : (mark.on ? IrisStyle.text : IrisStyle.textSecondary)
                    }
                    Row {
                        anchors.left: readName.right
                        anchors.right: readValue.left
                        anchors.margins: Math.round(2 * root.d)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Math.round(2 * root.d)
                        clip: true
                        Repeater {
                            model: 8
                            Rectangle { width: Math.max(1, Math.round(1 * root.d)); height: width; color: ColorUtils.applyAlpha(mark.ink, 0.5) } // iris-literal: a design specimen, drawn to scale
                        }
                    }
                }
            }
        }
    }

    component ActionRow: Rectangle {
        id: action
        property string glyph: ""
        property string label: ""
        property bool danger: false
        signal activated()
        readonly property color ink: action.danger ? IrisStyle.danger : IrisStyle.text
        Layout.fillWidth: true
        implicitHeight: Math.round(36 * IrisStyle.density)
        radius: root.plateRadius
        readonly property color stuff: actionTap.pressed ? (action.danger ? IrisStyle.tintFillHover(IrisStyle.danger) : IrisStyle.fillActive)
            : actionHover.hovered ? (action.danger ? IrisStyle.tintFill(IrisStyle.danger) : IrisStyle.fillHover) : "transparent"
        color: IrisStyle.fieldChamfer ? "transparent" : action.stuff
        Behavior on color { ColorAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
        IrisCutPlate { anchors.fill: parent; visible: IrisStyle.fieldChamfer; cutLength: root.plateCut; color: action.stuff }

        MaterialSymbol {
            id: actionGlyph
            anchors.left: parent.left
            anchors.leftMargin: Math.round(10 * IrisStyle.density)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(22 * IrisStyle.density)
            horizontalAlignment: Text.AlignHCenter
            text: action.glyph
            iconSize: Math.round(18 * IrisStyle.density)
            color: action.danger ? IrisStyle.danger : IrisStyle.textSecondary
        }
        IrisText {
            anchors.left: actionGlyph.right
            anchors.leftMargin: Math.round(10 * IrisStyle.density)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: action.label
            color: action.ink
            font.pixelSize: IrisStyle.typeLabel
            elide: Text.ElideRight
        }
        HoverHandler { id: actionHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: actionTap; gesturePolicy: TapHandler.WithinBounds; onTapped: action.activated() }
        Accessible.role: Accessible.Button
        Accessible.name: action.label
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Math.round(8 * root.d)

        Rectangle {
            Layout.preferredWidth: Math.round(28 * root.d)
            Layout.preferredHeight: Layout.preferredWidth
            radius: IrisStyle.iconRadius(width)
            gradient: Gradient {
                GradientStop { position: 0; color: IrisStyle.tileTop(root.widget.identityTint) }
                GradientStop { position: 1; color: root.widget.identityTint }
            }
            MaterialSymbol {
                anchors.centerIn: parent
                text: root.widget.identityGlyph
                fill: 1
                iconSize: Math.round(17 * root.d)
                color: IrisStyle.onTint
            }
        }
        IrisText {
            Layout.fillWidth: true
            text: Translation.tr(root.title)
            font.family: IrisStyle.fontTitle
            font.pixelSize: IrisStyle.typeTitle
            font.weight: IrisStyle.weight(Font.DemiBold)
            elide: Text.ElideRight
        }
        IrisIconButton {
            materialIcon: "close"
            iconSize: Math.round(16 * root.d)
            implicitWidth: Math.round(28 * root.d)
            onClicked: root.close()
            Accessible.name: Translation.tr("Close")
        }
    }

    IrisSegmented {
        Layout.fillWidth: true
        options: root.pages
        current: root.page
        accessibleName: Translation.tr("Quick controls")
        onPicked: value => root.widget._quickTab = value
    }

    ColumnLayout {
        visible: root.page === "widget"
        Layout.fillWidth: true
        spacing: Math.round(14 * root.d)

        ColumnLayout {
            visible: root.widget.irisSizeChoices.length > 1
            Layout.fillWidth: true
            spacing: Math.round(8 * root.d)

            Caption { text: Translation.tr("Size") }

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(8 * root.d)

                Repeater {
                    model: root.widget.irisSizeChoices

                    ChoiceTile {
                        id: sizeTile
                        required property string modelData
                        readonly property real cell: Math.round(14 * root.d)
                        chosen: root.widget.irisSize === sizeTile.modelData
                        label: root.widget.irisSizeLabels[sizeTile.modelData] ?? sizeTile.modelData
                        onPicked: root.widget.setIrisOption("size", sizeTile.modelData)
                        Rectangle {
                            anchors.centerIn: parent
                            width: sizeTile.modelData === "small" ? sizeTile.cell : sizeTile.cell * 2 + 2
                            height: sizeTile.modelData === "large" ? sizeTile.cell * 2 + 2 : sizeTile.cell
                            radius: IrisStyle.radiusMicro
                            color: sizeTile.chosen ? IrisStyle.accent : IrisStyle.fillActive
                        }
                    }
                }
            }
        }

        Repeater {
            model: root.widget.irisOptions

            ColumnLayout {
                id: option
                required property var modelData
                readonly property var value: option.modelData.raw
                    ? root.widget._readConfigKey(option.modelData.key) ?? option.modelData.fallback
                    : root.widget.irisOption(option.modelData.key, option.modelData.fallback)
                function store(value: var): void {
                    if (option.modelData.raw)
                        root.widget._setOutputValue(option.modelData.key, value)
                    else
                        root.widget.setIrisOption(option.modelData.key, value)
                }
                readonly property var picks: option.modelData.choices ?? []
                readonly property bool choice: option.picks.length > 0
                Layout.fillWidth: true
                spacing: Math.round(6 * root.d)

                Caption {
                    visible: option.choice
                    text: option.modelData.label
                }
                RowLayout {
                    visible: option.choice
                    Layout.fillWidth: true
                    spacing: Math.round(4 * root.d)
                    Repeater {
                        model: option.picks
                        FaceChoice {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            icon: modelData.icon ?? ""
                            label: modelData.label
                            selected: option.value === modelData.value
                            onClicked: option.store(modelData.value)
                        }
                    }
                }
                Rectangle {
                    id: optionPlate
                    visible: !option.choice
                    Layout.fillWidth: true
                    implicitHeight: Math.round(40 * root.d)
                    radius: root.plateRadius
                    readonly property color stuff: optionHover.hovered ? IrisStyle.fillHover : IrisStyle.fillQuiet
                    color: IrisStyle.fieldChamfer ? "transparent" : optionPlate.stuff
                    Behavior on color { ColorAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                    IrisCutPlate { anchors.fill: parent; visible: IrisStyle.fieldChamfer; cutLength: root.plateCut; color: optionPlate.stuff }

                    MaterialSymbol {
                        id: optionGlyph
                        anchors.left: parent.left
                        anchors.leftMargin: Math.round(12 * root.d)
                        anchors.verticalCenter: parent.verticalCenter
                        text: option.modelData.icon ?? ""
                        iconSize: Math.round(18 * root.d)
                        color: Boolean(option.value) ? IrisStyle.text : IrisStyle.textSecondary
                    }
                    IrisText {
                        anchors.left: optionGlyph.right
                        anchors.leftMargin: Math.round(10 * root.d)
                        anchors.right: optionSwitch.left
                        anchors.rightMargin: Math.round(10 * root.d)
                        anchors.verticalCenter: parent.verticalCenter
                        text: option.modelData.label
                        font.pixelSize: IrisStyle.typeLabel
                        elide: Text.ElideRight
                    }
                    Item {
                        anchors.left: parent.left
                        anchors.right: optionSwitch.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        HoverHandler { id: optionHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: option.store(!Boolean(option.value)) }
                    }
                    IrisSwitch {
                        id: optionSwitch
                        anchors.right: parent.right
                        anchors.rightMargin: Math.round(10 * root.d)
                        anchors.verticalCenter: parent.verticalCenter
                        on: Boolean(option.value)
                        name: option.modelData.label
                        onToggled: option.store(!Boolean(option.value))
                    }
                }
            }
        }
    }

    IrisStackControls {
        visible: root.page === "stack"
        widget: root.widget
        rowRadius: root.plateRadius
        part: "manage"
    }

    ColumnLayout {
        visible: root.page === "look"
        Layout.fillWidth: true
        spacing: Math.round(14 * root.d)

        ColumnLayout {
            visible: !root.widget.stacked
            Layout.fillWidth: true
            spacing: Math.round(8 * root.d)

            RowLayout {
                Layout.fillWidth: true
                Caption { text: Translation.tr("Design") }
                IrisText {
                    text: root.widget.widgetDesignShared
                        ? Translation.tr("Same as every widget") : Translation.tr("This widget only")
                    color: IrisStyle.textTertiary
                    font.pixelSize: IrisStyle.typeMeta
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(8 * root.d)
                Repeater {
                    model: root.widget.designChoices
                    ChoiceTile {
                        id: designTile
                        required property var modelData
                        chosen: root.widget.widgetDesign === designTile.modelData.value
                        label: designTile.modelData.label
                        onPicked: root.widget.pickDesign(designTile.modelData.value)
                        DesignMark { design: designTile.modelData.value; on: designTile.chosen }
                    }
                }
            }

            IrisButton {
                visible: root.widget.widgetDesignMatchable
                Layout.fillWidth: true
                text: Translation.tr("Use on every widget")
                onClicked: root.widget.useDesignEverywhere()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Math.round(8 * root.d)

            RowLayout {
                Layout.fillWidth: true
                Caption { text: Translation.tr("Material") }
                IrisText {
                    visible: root.ownMaterial === "auto" || !root.materials.some(entry => entry.value === root.ownMaterial)
                    text: (root.materials.find(entry => entry.value === root.sharedMaterial)?.label ?? "") + " · " + Translation.tr("from Settings")
                    color: IrisStyle.textTertiary
                    font.pixelSize: IrisStyle.typeMeta
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(6 * root.d)

                Repeater {
                    model: root.materials

                    ColumnLayout {
                        id: swatch
                        required property var modelData
                        readonly property bool chosen: root.ownMaterial === swatch.modelData.value
                            || (swatch.modelData.value === "auto" && !root.materials.some(entry => entry.value === root.ownMaterial))
                        readonly property string shown: swatch.modelData.value === "auto" ? root.sharedMaterial : swatch.modelData.value
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.maximumWidth: Number.POSITIVE_INFINITY
                        spacing: Math.round(5 * root.d) // iris-literal: the material swatch, a miniature

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.round(58 * root.d)

                            Rectangle {
                                anchors.fill: parent
                                radius: root.plateRadius
                                color: "transparent"
                                border.width: swatch.chosen ? 2 : 0
                                border.color: IrisStyle.accent
                            }
                            ClippingRectangle {
                                anchors.fill: parent
                                anchors.margins: Math.round(3 * root.d) // iris-literal: the material swatch, a miniature
                                radius: IrisStyle.concentric(root.plateRadius, 3 * root.d, IrisStyle.radiusMicro)
                                color: IrisStyle.fillQuiet

                                IrisImage {
                                    anchors.fill: parent
                                    source: root.wallpaperUrl
                                    layer.enabled: swatch.shown === "glass"
                                    layer.effect: MultiEffect {
                                        blurEnabled: true
                                        blur: IrisStyle.glassBlur
                                        blurMax: Math.round(IrisStyle.glassBlurMax / 3)
                                        saturation: IrisStyle.glassSaturation
                                    }
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: Math.round(8 * root.d)
                                    radius: IrisStyle.radiusChip
                                    color: root.materialColor(swatch.modelData.value)
                                    border.width: swatch.shown === "clear" ? 0 : 1
                                    border.color: IrisStyle.rim
                                    IrisText {
                                        anchors.centerIn: parent
                                        text: "Aa"
                                        font.family: IrisStyle.fontTitle
                                        font.pixelSize: IrisStyle.typeHeadline
                                        font.weight: IrisStyle.weight(Font.DemiBold)
                                        style: swatch.shown === "clear" ? Text.Raised : Text.Normal
                                        styleColor: IrisStyle.plateShadow
                                    }
                                }
                            }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: root.widget._setOutputValue("iris.material", swatch.modelData.value) }
                            Accessible.role: Accessible.RadioButton
                            Accessible.name: swatch.modelData.label
                            Accessible.checked: swatch.chosen
                        }
                        IrisText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: swatch.modelData.label
                            color: swatch.chosen ? IrisStyle.text : IrisStyle.textSecondary
                            font.pixelSize: IrisStyle.typeMeta
                            font.weight: swatch.chosen ? Font.DemiBold : Font.Normal
                            fontSizeMode: Text.HorizontalFit
                            minimumPixelSize: Math.round(9 * IrisStyle.typeScale)
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Math.round(8 * root.d)

            RowLayout {
                Layout.fillWidth: true
                Caption { text: Translation.tr("Corners") }
                IrisText {
                    text: cornerScrubber.dragValue >= 0
                        ? (Math.round(cornerScrubber.dragValue * root.cornerMax) <= 0
                            ? Translation.tr("Auto") : Math.round(cornerScrubber.dragValue * root.cornerMax) + " px")
                        : (root.cornerValue < 0 ? Translation.tr("Auto") : root.cornerValue + " px")
                    color: IrisStyle.textSecondary
                    font.family: IrisStyle.fontNumbers
                    font.features: ({ "tnum": 1 })
                    font.pixelSize: IrisStyle.typeMeta
                }
            }
            IrisScrubber {
                id: cornerScrubber
                Layout.fillWidth: true
                knob: true
                fillColor: IrisStyle.accent
                stepSize: 2 / root.cornerMax
                value: Math.max(0, root.cornerValue) / root.cornerMax
                onMoved: value => root.widget.previewIrisValue("cornerRadius", root.cornerFrom(value))
                onSeekRequested: value => root.widget.commitIrisValue("cornerRadius", root.cornerFrom(value))
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Math.round(8 * root.d)

            RowLayout {
                Layout.fillWidth: true
                Caption { text: Translation.tr("Surface opacity") }
                IrisText {
                    text: (opacityScrubber.dragValue >= 0
                        ? root.opacityFrom(opacityScrubber.dragValue) : root.opacityValue) + "%"
                    color: IrisStyle.textSecondary
                    font.family: IrisStyle.fontNumbers
                    font.features: ({ "tnum": 1 })
                    font.pixelSize: IrisStyle.typeMeta
                }
            }
            IrisScrubber {
                id: opacityScrubber
                Layout.fillWidth: true
                knob: true
                fillColor: IrisStyle.accent
                stepSize: 5 / (100 - root.opacityMin)
                value: (root.opacityValue - root.opacityMin) / (100 - root.opacityMin)
                onMoved: value => root.widget.previewIrisValue("iris.opacity", root.opacityFrom(value))
                onSeekRequested: value => {
                    const chosen = root.opacityFrom(value)
                    root.widget.commitIrisValue("iris.opacity",
                        chosen === Math.round(Number(Config.options?.iris?.widgets?.opacity ?? 100)) ? -1 : chosen)
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Math.round(8 * root.d)

            RowLayout {
                Layout.fillWidth: true
                Caption { text: Translation.tr("Scale") }
                IrisText {
                    text: (scaleScrubber.dragValue >= 0
                        ? Math.round(root.scaleMin + scaleScrubber.dragValue * (root.scaleMax - root.scaleMin))
                        : root.scaleValue) + "%"
                    color: IrisStyle.textSecondary
                    font.family: IrisStyle.fontNumbers
                    font.features: ({ "tnum": 1 })
                    font.pixelSize: IrisStyle.typeMeta
                }
            }
            IrisScrubber {
                id: scaleScrubber
                Layout.fillWidth: true
                knob: true
                fillColor: IrisStyle.accent
                stepSize: 5 / (root.scaleMax - root.scaleMin)
                value: (root.scaleValue - root.scaleMin) / (root.scaleMax - root.scaleMin)
                onMoved: value => root.widget.previewIrisScale(Math.round((root.scaleMin + value * (root.scaleMax - root.scaleMin)) / 5) * 5)
                onSeekRequested: value => root.widget.commitIrisScale(Math.round((root.scaleMin + value * (root.scaleMax - root.scaleMin)) / 5) * 5)
            }
        }
    }

    ColumnLayout {
        visible: root.page === "arrange"
        Layout.fillWidth: true
        spacing: Math.round(10 * root.d)

        Caption { text: Translation.tr("Position") }

        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(12 * root.d)

            Grid {
                columns: 3
                spacing: Math.round(4 * root.d)
                Repeater {
                    model: root.zones
                    Rectangle {
                        id: zone
                        required property string modelData
                        readonly property bool chosen: root.widget.placementStrategy === zone.modelData
                        width: Math.round(32 * root.d)
                        height: Math.round(28 * root.d)
                        radius: IrisStyle.radiusChip
                        color: zone.chosen ? IrisStyle.tintFill(IrisStyle.accent)
                            : zoneHover.hovered ? IrisStyle.fillHover : IrisStyle.fillQuiet
                        border.width: zone.chosen ? 1 : 0
                        border.color: IrisStyle.tintBorder(IrisStyle.accent)
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: root.zoneGlyphs[zone.modelData] ?? "circle"
                            iconSize: Math.round(15 * root.d)
                            color: zone.chosen ? IrisStyle.accent : IrisStyle.textSecondary
                        }
                        HoverHandler { id: zoneHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.widget.snapToZone(zone.modelData) }
                        Accessible.role: Accessible.RadioButton
                        Accessible.name: zone.modelData
                        Accessible.checked: zone.chosen
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Math.round(6 * root.d)
                FaceChoice {
                    Layout.fillWidth: true
                    icon: "open_with"
                    label: Translation.tr("Free position")
                    selected: root.widget.placementStrategy === "free"
                    onClicked: root.widget._setOutputValues({ placementStrategy: "free",
                        x: Math.round(root.widget.x), y: Math.round(root.widget.y) })
                }
                FaceChoice {
                    Layout.fillWidth: true
                    icon: "auto_awesome"
                    label: Translation.tr("Quietest spot")
                    selected: root.widget.placementStrategy === "leastBusy"
                    onClicked: root.widget._setOutputValue("placementStrategy", "leastBusy")
                }
            }
        }

        IrisStackControls {
            widget: root.widget
            rowRadius: root.plateRadius
            part: "join"
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(4 * root.d)
            implicitHeight: 1
            color: IrisStyle.hairline
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            ActionRow {
                glyph: root.widget.locked ? "lock_open" : "lock"
                label: root.widget.locked ? Translation.tr("Unlock position") : Translation.tr("Lock position")
                onActivated: root.widget._setOutputValue("locked", !root.widget.locked)
            }
            ActionRow {
                glyph: "flip_to_front"
                label: Translation.tr("Bring to front")
                onActivated: root.widget._bringToFront()
            }
            ActionRow {
                glyph: "restart_alt"
                label: Translation.tr("Reset widget")
                onActivated: root.widget.resetToDefaults()
            }
            ActionRow {
                glyph: "remove_circle"
                label: root.onLock ? Translation.tr("Remove widget") : Translation.tr("Remove from desktop")
                danger: true
                onActivated: {
                    const widget = root.widget
                    root.close()
                    if (root.onLock) widget._setOutputValue("enable", false)
                    else widget.takeAway()
                }
            }
        }
    }
}
