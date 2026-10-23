pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import "../components"

// AIRISU's palette: a printer's colour swatch. Each colour is a plate cut with the bodies' die, its hex in the data
// face; a tap copies it, a right tap keeps it through the next read (a pin on the plate). The large face's chosen
// colour is registered with crop marks, and its keys say where the colours come from and what to do with them. The
// engine's face keeps the colours, the copying and the accent.
Item {
    id: root
    property var face
    readonly property var widget: root.face?.widget ?? null
    readonly property bool small: root.face?.small ?? true
    readonly property bool large: root.face?.large ?? false
    function dp(v: real): real { return root.face ? root.face.dp(v) : Math.round(v) }
    function px(v: real): real { return root.face ? root.face.px(v) : Math.round(v) }
    readonly property int pad: root.dp(14)
    readonly property var colours: root.face?.colours ?? []
    readonly property var kept: root.face?.kept ?? []

    AStock {
        id: stock
        anchors.fill: parent
        face: root.face
        subject: "rest"
    }

    component Plate: Item {
        id: plate
        required property int index
        property bool hexInside: false
        readonly property string value: String(root.colours[plate.index] ?? "")
        readonly property color pigment: plate.value.length > 0 ? plate.value : Airisu.slot
        readonly property color onPlate: Airisu.inkOn(plate.pigment)
        readonly property bool held: String(root.kept[plate.index] ?? "").length > 0
        readonly property bool justCopied: (root.face?.copied ?? -1) === plate.index
        ADie {
            id: die
            x: tap.pressed ? Airisu.offset : 0
            y: x
            width: parent.width
            height: parent.height
            kind: "chamfer"
            cut: Airisu.cutFor(Math.min(width, height))
            fill: plate.pigment
            stroke: hover.hovered ? plate.onPlate : "transparent"
            strokeWidth: hover.hovered ? Airisu.hair : 0
            Behavior on fill { ColorAnimation { duration: Airisu.tear; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve } }
        }
        AMarks {
            anchors.fill: parent
            shown: root.large && (root.face?.chosen ?? -1) === plate.index
            color: Airisu.seal
        }
        MaterialSymbol {
            visible: plate.held
            anchors.top: die.top
            anchors.right: die.right
            anchors.margins: root.dp(5)
            text: "push_pin"
            fill: 1
            iconSize: root.px(11)
            color: plate.onPlate
        }
        AText {
            visible: plate.hexInside || plate.justCopied
            x: die.x + (plate.hexInside ? root.dp(10) : root.dp(2))
            anchors.verticalCenter: die.verticalCenter
            width: parent.width - (plate.hexInside ? root.dp(20) : root.dp(4))
            horizontalAlignment: plate.hexInside ? Text.AlignLeft : Text.AlignHCenter
            voice: plate.justCopied ? "mono" : "data"
            size: IrisStyle.typeCaption
            color: plate.onPlate
            text: plate.justCopied ? Translation.tr("Copied") : plate.value.toUpperCase()
        }
        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: tap; gesturePolicy: TapHandler.WithinBounds; onTapped: root.face?.copyOne(plate.index) }
        TapHandler { acceptedButtons: Qt.RightButton; onTapped: root.widget?.keep(plate.index) }
        Accessible.role: Accessible.Button
        Accessible.name: plate.value
    }

    // A worded key: quiet with its die ruled, or lacquered a rung up when it is the one in force.
    component Key: Item {
        id: key
        property string glyph: ""
        property string label: ""
        property bool on: false
        signal activated()
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: root.dp(28)
        AKey {
            id: kp
            anchors.fill: parent
            lacquer: key.on ? stock.coat : "transparent"
            under: stock.lacquer
            hovered: keyHover.hovered
            pressed: keyTap.pressed
        }
        ADie {
            visible: !key.on
            x: kp.shift
            y: kp.shift
            width: parent.width
            height: parent.height
            kind: "chamfer"
            cut: Airisu.cutFor(height)
            stroke: stock.inkThird
            strokeWidth: Airisu.hair
        }
        Row {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: kp.shift
            anchors.verticalCenterOffset: kp.shift
            spacing: root.dp(4)
            width: Math.min(implicitWidth, key.width - root.dp(10))
            // A narrow key keeps its word whole and lets the glyph go.
            MaterialSymbol {
                visible: word.implicitWidth + root.dp(32) <= key.width
                anchors.verticalCenter: parent.verticalCenter
                text: key.glyph
                fill: key.on ? 1 : 0
                iconSize: root.px(13)
                color: key.on ? stock.ink : stock.inkSecond
            }
            AText {
                id: word
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, key.width - root.dp(10))
                size: IrisStyle.typeFootnote
                font.weight: Font.Bold
                color: key.on ? stock.ink : stock.inkSecond
                text: key.label
            }
        }
        HoverHandler { id: keyHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: keyTap; gesturePolicy: TapHandler.WithinBounds; onTapped: key.activated() }
        Accessible.role: Accessible.Button
        Accessible.name: key.label
    }

    ColumnLayout {
        visible: root.small
        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        height: root.height - 2 * root.pad
        spacing: root.dp(3)
        Repeater {
            model: 5
            Plate {
                Layout.fillWidth: true
                Layout.fillHeight: true
                hexInside: true
            }
        }
    }

    ColumnLayout {
        visible: !root.small
        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        height: root.height - 2 * root.pad
        spacing: root.dp(root.large ? 10 : 8)

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.dp(18)
            AText {
                anchors.verticalCenter: parent.verticalCenter
                voice: "mono"
                size: IrisStyle.typeCaption
                color: stock.inkSecond
                text: Translation.tr("Palette")
            }
            AText {
                visible: !root.large
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                voice: "data"
                size: IrisStyle.typeCaption
                color: stock.inkSecond
                text: root.face?.fromLabel ?? ""
            }
        }
        RowLayout {
            visible: root.large
            Layout.fillWidth: true
            spacing: root.dp(4)
            Repeater {
                model: root.face?.sources ?? []
                Key {
                    required property var modelData
                    glyph: modelData.glyph
                    label: modelData.label
                    on: root.widget?.colourSource === modelData.value
                    onActivated: modelData.value === "random" && root.widget.colourSource === "random"
                        ? root.widget.shuffle() : root.widget.setIrisOption("source", modelData.value)
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.dp(6)
            Repeater {
                model: 5
                ColumnLayout {
                    id: column
                    required property int index
                    readonly property bool chosen: root.large && (root.face?.chosen ?? -1) === column.index
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    spacing: root.dp(5)
                    Plate {
                        index: column.index
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                    AText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        voice: "data"
                        size: IrisStyle.typeCaption
                        color: column.chosen ? stock.ink : stock.inkSecond
                        text: String(root.colours[column.index] ?? "").slice(1).toUpperCase()
                    }
                }
            }
        }
        RowLayout {
            visible: root.large
            Layout.fillWidth: true
            spacing: root.dp(4)
            Key {
                glyph: "shuffle"
                label: Translation.tr("Shuffle")
                onActivated: root.widget.shuffle()
            }
            Key {
                glyph: (root.face?.copiedAll ?? false) ? "check" : "content_copy"
                label: (root.face?.copiedAll ?? false) ? Translation.tr("Copied") : Translation.tr("Copy all")
                onActivated: root.face.copyAll()
            }
            Key {
                readonly property bool undo: (root.face?.accentBefore ?? null) !== null
                visible: root.face?.canUseAccent ?? false
                glyph: undo ? "undo" : "format_paint"
                label: undo ? Translation.tr("Undo") : Translation.tr("Use as accent")
                on: undo
                onActivated: undo ? root.face.undoAccent() : root.face.useAsAccent(root.colours[root.face.chosen])
            }
        }
    }
}
