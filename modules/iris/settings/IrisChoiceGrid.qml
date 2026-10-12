pragma ComponentBehavior: Bound
import QtQuick
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.components
import qs.modules.iris.style

// A list of choices opened in place under its row (2026-10-11, the maintainer rejected the pop-up menu for them: "no es
// estético ni la mejor solución"). Cells in as many columns as the longest name allows, the choice in the accent; past a
// dozen a filter takes what you type. Nothing floats over the page and nothing leaves the panel.
// options: [{ value, label, glyph? }]; `fontFor(option)` gives a face per option; `extra`: [{ text, glyph, action }].
Item {
    id: root

    property var options: []
    property var current
    property var fontFor: null
    property var extra: []
    property string accessibleName: ""
    signal picked(var value)
    signal dismissed()

    readonly property real d: IrisStyle.settingsDensity
    readonly property real gap: Math.round(4 * root.d)
    readonly property real cellHeight: Math.round(32 * root.d)
    readonly property real lead: Math.round(10 * root.d)
    readonly property real checkSlot: Math.round(22 * root.d)
    readonly property bool filtering: root.options.length > 12
    property string filter: ""
    readonly property var shown: {
        const terms = root.filter.trim().toLowerCase()
        const list = root.options.map(option => ({ option: option, text: Translation.tr(String(option.label ?? "")) }))
        if (terms.length === 0) return list
        return list.filter(entry => entry.text.toLowerCase().includes(terms)
            || String(entry.option.label ?? "").toLowerCase().includes(terms) || String(entry.option.value ?? "").toLowerCase().includes(terms))
    }
    readonly property var cells: root.shown.concat(root.filter.length > 0 ? [] : root.extra.map(entry => ({ extra: entry, text: String(entry.text ?? "") })))

    FontMetrics {
        id: metrics
        font.family: IrisStyle.fontMain
        font.pixelSize: IrisStyle.typeLabel
        font.weight: IrisStyle.weight(Font.DemiBold)
    }
    // Every cell as wide as the longest name, measured over the whole list so filtering never reflows the columns.
    readonly property real natural: Math.ceil(Math.max(Math.round(96 * root.d), ...root.options.map(option => metrics.advanceWidth(Translation.tr(String(option.label ?? ""))))
        , ...root.extra.map(entry => metrics.advanceWidth(String(entry.text ?? "")) + Math.round(22 * root.d))))
        + root.lead + root.checkSlot + Math.round(4 * root.d)
    readonly property int columns: Math.max(1, Math.min(4, Math.floor((root.width + root.gap) / (root.natural + root.gap))))
    readonly property real cellWidth: Math.floor((root.width - root.gap * (root.columns - 1)) / root.columns)
    readonly property int rowCount: Math.ceil(root.cells.length / root.columns)

    implicitHeight: (root.filtering ? filterField.height + root.gap * 2 : 0) + Math.max(1, root.rowCount) * (root.cellHeight + root.gap) - root.gap
    Accessible.role: Accessible.List
    Accessible.name: root.accessibleName

    function pickFirst(): void {
        const first = root.shown[0]
        if (first) root.picked(first.option.value)
    }
    Component.onCompleted: if (root.filtering) filterInput.forceActiveFocus()

    Rectangle {
        id: filterField
        visible: root.filtering
        width: parent.width
        height: visible ? Math.round(32 * root.d) : 0
        radius: IrisStyle.radiusRow
        color: IrisStyle.fillQuiet
        MaterialSymbol {
            id: filterGlyph
            x: root.lead
            anchors.verticalCenter: parent.verticalCenter
            text: "search"
            iconSize: Math.round(16 * root.d)
            color: IrisStyle.muted
        }
        TextInput {
            id: filterInput
            anchors.left: filterGlyph.right
            anchors.leftMargin: Math.round(8 * root.d)
            anchors.right: parent.right
            anchors.rightMargin: root.lead
            anchors.verticalCenter: parent.verticalCenter
            color: IrisStyle.text
            selectionColor: IrisStyle.tintFillHover(IrisStyle.accent)
            font.family: IrisStyle.fontMain
            font.pixelSize: IrisStyle.typeLabel
            clip: true
            onTextChanged: root.filter = text
            Keys.onReturnPressed: root.pickFirst()
            Keys.onEscapePressed: root.dismissed()
            IrisText {
                anchors.verticalCenter: parent.verticalCenter
                visible: filterInput.text.length === 0
                text: Translation.tr("Search %1").arg(root.accessibleName)
                color: IrisStyle.muted
                font.pixelSize: IrisStyle.typeLabel
            }
        }
    }

    IrisText {
        visible: root.cells.length === 0
        y: filterField.height + root.gap * 2 + Math.round((root.cellHeight - height) / 2)
        x: root.lead
        text: Translation.tr("No match")
        color: IrisStyle.muted
        font.pixelSize: IrisStyle.typeLabel
    }

    Repeater {
        model: root.cells
        MouseArea {
            id: cell
            required property var modelData
            required property int index
            readonly property bool isExtra: cell.modelData.extra !== undefined
            readonly property bool chosen: !cell.isExtra && cell.modelData.option.value === root.current
            x: (cell.index % root.columns) * (root.cellWidth + root.gap)
            y: (root.filtering ? filterField.height + root.gap * 2 : 0) + Math.floor(cell.index / root.columns) * (root.cellHeight + root.gap)
            width: root.cellWidth
            height: root.cellHeight
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.RadioButton
            Accessible.name: cell.modelData.text
            Accessible.checked: cell.chosen
            onClicked: {
                if (cell.isExtra) cell.modelData.extra.action()
                else root.picked(cell.modelData.option.value)
            }
            Rectangle {
                anchors.fill: parent
                radius: IrisStyle.radiusRow
                // Where you are reads in the accent; the wash under it only supports it. Hover is a fill step.
                color: cell.pressed ? IrisStyle.fillActive
                    : cell.chosen ? IrisStyle.selectionFill
                    : cell.containsMouse ? IrisStyle.fillHover : "transparent"
                Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
            }
            MaterialSymbol {
                id: extraGlyph
                visible: cell.isExtra
                x: root.lead
                anchors.verticalCenter: parent.verticalCenter
                text: String(cell.modelData.extra?.glyph ?? "add")
                iconSize: Math.round(16 * root.d)
                color: IrisStyle.subtext
            }
            IrisText {
                x: cell.isExtra ? extraGlyph.x + extraGlyph.width + Math.round(6 * root.d) : root.lead
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - root.checkSlot
                // Names in right-to-left scripts keep the column's alignment: a grid reads down one edge.
                horizontalAlignment: Text.AlignLeft
                text: cell.modelData.text
                color: cell.chosen ? IrisStyle.selectionInk : cell.isExtra ? IrisStyle.subtext : IrisStyle.text
                font.family: !cell.isExtra && root.fontFor ? root.fontFor(cell.modelData.option) : IrisStyle.fontMain
                font.pixelSize: IrisStyle.typeLabel
                font.weight: IrisStyle.weight(cell.chosen ? Font.DemiBold : Font.Normal)
                elide: Text.ElideRight
            }
            MaterialSymbol {
                visible: cell.chosen
                anchors.right: parent.right
                anchors.rightMargin: Math.round(8 * root.d)
                anchors.verticalCenter: parent.verticalCenter
                text: "check"
                iconSize: Math.round(16 * root.d)
                color: IrisStyle.selectionInk
            }
        }
    }
}
