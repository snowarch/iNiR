pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style

// A pop-up button: the current choice and an up-down mark, quiet at rest (a plate only under the pointer, or always when
// button rows carry one), opening iRiS's menu with that choice laid over the button so the pointer already rests on it.
// For a flat list of choices a segmented control cannot hold (more than four, or names too long to share a track).
// options: [{ value, label, glyph? }]; `fontFor(option)` gives a face per option; `extra` entries follow a separator.
MouseArea {
    id: root

    property var options: []
    property var current
    property string accessibleName: ""
    property var fontFor: null
    property var extra: []
    // What the button says when the value is none of the options (a preset edited elsewhere, a font picked by name).
    property string otherText: Translation.tr("Custom")
    property string otherFamily: ""
    property real maxWidth: Math.round(300 * root.d)
    // Discloses: the click asks its owner to open the choices in place (Settings' rows) instead of the menu.
    property bool discloses: false
    property bool expanded: false
    signal picked(var value)
    signal disclose()

    readonly property real d: IrisStyle.density
    readonly property int selectedIndex: root.options.findIndex(option => option.value === root.current)
    readonly property var chosen: root.selectedIndex >= 0 ? root.options[root.selectedIndex] : null
    readonly property bool open: menu.active || root.expanded
    readonly property bool plated: IrisStyle.controlPlated
    readonly property real lead: Math.round(10 * root.d)
    readonly property real glyphSlot: chosenGlyph.visible ? chosenGlyph.width + Math.round(6 * root.d) : 0

    implicitHeight: Math.round(28 * root.d)
    implicitWidth: Math.min(root.maxWidth, Math.ceil(root.lead + root.glyphSlot + valueText.implicitWidth + Math.round(4 * root.d)
        + mark.width + Math.round(6 * root.d)))
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    activeFocusOnTab: true
    Accessible.role: Accessible.ComboBox
    Accessible.name: root.accessibleName
    Accessible.description: valueText.text

    function entries(): var {
        const list = root.options.map(option => ({
            text: Translation.tr(String(option.label ?? "")),
            iconName: String(option.glyph ?? ""),
            checked: option.value === root.current,
            family: root.fontFor ? root.fontFor(option) : "",
            action: () => root.picked(option.value)
        }))
        return root.extra.length > 0 ? list.concat([{ type: "separator" }], root.extra) : list
    }
    function popUp(at: point): void {
        menu.pointerAt = at
        menu.model = root.entries()
        menu.requestOpen()
    }
    function activate(at: point): void { if (root.discloses) root.disclose(); else root.popUp(at) }
    onClicked: mouse => root.activate(Qt.point(mouse.x, mouse.y))
    Keys.onSpacePressed: root.activate(Qt.point(root.width / 2, root.height / 2))
    Keys.onReturnPressed: root.activate(Qt.point(root.width / 2, root.height / 2))

    Rectangle {
        anchors.fill: parent
        radius: IrisStyle.fieldChamfer ? 0 : root.plated ? IrisStyle.pieceRadius(height) : height / 2
        color: root.open || root.pressed ? IrisStyle.fillActive
            : root.containsMouse ? IrisStyle.fillHover
            : root.plated ? IrisStyle.plateFillFor(IrisStyle.controlPlate) : ColorUtils.applyAlpha(IrisStyle.fillHover, 0)
        border.width: root.activeFocus ? 1 : 0
        border.color: IrisStyle.tintBorder(IrisStyle.accent)
        Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
        IrisGlassEdge {
            anchors.fill: parent
            visible: root.plated && (IrisStyle.controlPlate === "glass" || IrisStyle.edgeLit) && shown
            radius: parent.radius
        }
    }

    MaterialSymbol {
        id: chosenGlyph
        visible: String(root.chosen?.glyph ?? "").length > 0
        x: root.lead
        anchors.verticalCenter: parent.verticalCenter
        text: String(root.chosen?.glyph ?? "")
        iconSize: Math.round(16 * root.d)
        color: IrisStyle.subtext
    }
    IrisText {
        id: valueText
        x: root.lead + root.glyphSlot
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, root.width - x - mark.width - Math.round(10 * root.d))
        text: root.chosen ? Translation.tr(String(root.chosen.label ?? "")) : root.otherText
        // A mono-caption Design reads the value like a part number: mono capitals (a font choice keeps its own face).
        readonly property bool mono: IrisStyle.monoCaptions && !(root.chosen && root.fontFor) && root.otherFamily.length === 0
        font.family: root.chosen && root.fontFor ? root.fontFor(root.chosen)
            : !root.chosen && root.otherFamily.length > 0 ? root.otherFamily : valueText.mono ? IrisStyle.fontMono : IrisStyle.fontMain
        font.capitalization: valueText.mono ? Font.AllUppercase : Font.MixedCase
        font.letterSpacing: valueText.mono ? Math.round(IrisStyle.typeFootnote * 0.12) : 0
        font.pixelSize: valueText.mono ? IrisStyle.typeFootnote : IrisStyle.typeLabel
        font.weight: IrisStyle.weight(valueText.mono ? Font.Medium : Font.Normal)
        elide: Text.ElideRight
    }
    MaterialSymbol {
        id: mark
        anchors.right: parent.right
        anchors.rightMargin: Math.round(6 * root.d)
        anchors.verticalCenter: parent.verticalCenter
        // A plate Design points at the menu with the chevron, the seal when it is open.
        text: IrisStyle.plateSelection ? "chevron_right" : root.discloses ? "expand_more" : "unfold_more"
        rotation: root.discloses && root.expanded ? (IrisStyle.plateSelection ? 90 : 180) : 0
        Behavior on rotation { NumberAnimation { duration: IrisStyle.duration(200); easing.type: IrisStyle.feedbackEasing } }
        iconSize: Math.round(16 * root.d)
        color: IrisStyle.plateSelection && (root.open || root.expanded) ? IrisStyle.accent
            : root.containsMouse || root.open ? IrisStyle.text : IrisStyle.subtext
    }

    // The menu's text lands where the button's was: the anchor's text column, past its glyph.
    IrisDesktopMenu {
        id: menu
        anchorItem: root
        opensToward: "over"
        overIndex: Math.max(0, root.selectedIndex)
        overTextX: root.lead + root.glyphSlot
    }
}
