pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.services
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style

// One segmented control for iRiS (DESIGN.md S4): a quiet capsule track and the chosen segment as an inverted capsule
// (ink fill, paper word) that slides on a spring and keeps its velocity when the choice changes mid-flight.
// options: [{ value, label, glyph?, swatch? }]. `pictured` stacks glyph over label in a taller
// tile; `glyphOnly` draws square glyph segments sized by the track height.
Rectangle {
    id: root

    property var options: []
    property var current
    property bool pictured: false
    property bool glyphOnly: false
    property string accessibleName: ""
    property var fontFor: null
    property string voice: ""
    readonly property real d: IrisStyle.density
    // Apple lifts the chosen segment as a raised thumb with the accent on its word; Nothing inverts it (S4). Synth sets
    // each choice on a key of its own, the chosen one pressed and capped; Gel's thumb is a glossy accent bead.
    readonly property string look: IrisStyle.lookOf(root)
    readonly property bool nothing: root.look === "nothing"
    readonly property bool synth: root.look === "synth" && !root.skinned
    readonly property bool gel: root.look === "gel" && !root.skinned
    readonly property int inset: 2
    readonly property int count: Math.max(1, root.options.length)
    readonly property int selectedIndex: root.options.findIndex(option => option.value === root.current)
    readonly property real slot: (root.width - 2 * root.inset) / root.count
    signal picked(var value)
    // Which segment the pointer is over and which is held, for a skin that answers them per segment.
    property int hoveredIndex: -1
    property int pressedIndex: -1
    property int focusedIndex: -1
    // A Design may draw it its own way (AIRISU: positions that click into place); the picking stays here.
    readonly property bool skinned: skin.active
    // The width that holds the longest label in every language with its air: a caller with a fixed slot takes at least
    // this, so a translated label never spills past its segment.
    readonly property real fitWidth: {
        let widest = 0
        for (const option of root.options)
            widest = Math.max(widest, labelMetrics.advanceWidth(Translation.tr(String(option.label ?? "")))
                + (String(option.swatch ?? "").length > 0 ? 18 * root.d : 0))
        return Math.ceil(root.count * (widest + 24 * root.d) + 2 * root.inset)
    }
    FontMetrics {
        id: labelMetrics
        font.family: IrisStyle.fontMain
        font.pixelSize: IrisStyle.typeMeta
        font.weight: IrisStyle.weight(Font.DemiBold)
    }

    // A layout's voice (Folio, Console) measures each name with its own type: every segment hugs its name and the track
    // ends where they do. Squeezed below that, the names share the track evenly again.
    readonly property var hugWidths: typeof skin.item?.widthFor === "function"
        ? root.options.map(option => Number(skin.item.widthFor(Translation.tr(String(option.label ?? ""))))) : []
    readonly property real hugWidth: root.hugWidths.length > 0 ? Math.ceil(root.hugWidths.reduce((sum, w) => sum + w, 0)) + 2 * root.inset : 0
    readonly property bool hugs: root.hugWidth > 0 && root.width >= root.hugWidth - 1
    // Even shares cut a long name while a short one has air: then each segment takes its name's width plus an even part
    // of what is left (Apple's apportionsSegmentWidthsByContent); squeezed further, all shrink by the same ratio.
    readonly property var needs: root.glyphOnly ? [] : root.hugWidths.length > 0 ? root.hugWidths
        : labelMetrics.font.pixelSize <= 0 ? [] : root.options.map(option => labelMetrics.advanceWidth(Translation.tr(String(option.label ?? "")))
            + (String(option.swatch ?? "").length > 0 ? 18 * root.d : 0) + 24 * root.d)
    readonly property real needTotal: root.needs.reduce((sum, w) => sum + w, 0)
    // Squeezed, a name breaks between words but never inside one: its longest word is its floor.
    readonly property var floors: root.needs.length === 0 || labelMetrics.font.pixelSize <= 0 ? [] : root.options.map(option => Math.max(0,
        ...Translation.tr(String(option.label ?? "")).split(/\s+/).map(word => labelMetrics.advanceWidth(word)))
        + (String(option.swatch ?? "").length > 0 ? 18 * root.d : 0) + 16 * root.d)
    readonly property var shares: {
        if (root.hugs || !root.needs.some(need => need > root.slot)) return []
        const room = root.width - 2 * root.inset
        if (root.needTotal <= room) return root.needs.map(w => w + (room - root.needTotal) / root.count)
        const floorTotal = root.floors.reduce((sum, w) => sum + w, 0)
        if (floorTotal >= room) return root.floors.map(w => w * room / floorTotal)
        return root.floors.map((w, i) => w + (root.needs[i] - w) * (room - floorTotal) / (root.needTotal - floorTotal))
    }
    // Names that cannot share one line even so take two, and the track grows to hold them.
    readonly property bool squeezed: !root.pictured && !root.skinned && root.width > 0 && root.needTotal > root.width - 2 * root.inset + 1
    implicitHeight: Math.round((skin.item?.wantHeight ?? (root.pictured ? 52 : root.glyphOnly ? 32 : root.squeezed ? 42 : 28)) * root.d)
    implicitWidth: root.hugWidth > 0 ? root.hugWidth : root.glyphOnly ? root.count * (root.implicitHeight - 2 * root.inset) + 2 * root.inset : 0
    readonly property real thumbRadius: root.pictured ? IrisStyle.radiusTile - root.inset
        : IrisStyle.controlPlated ? IrisStyle.pieceRadius(root.height - 2 * root.inset) : (root.height - 2 * root.inset) / 2
    radius: root.pictured ? IrisStyle.radiusTile : IrisStyle.controlPlated ? root.thumbRadius + root.inset : height / 2
    color: root.skinned || root.synth ? "transparent" : IrisStyle.controlPlated ? IrisStyle.plateFillFor(IrisStyle.controlPlate) : IrisStyle.fillQuiet

    IrisSkin { id: skin; part: "segmented"; voice: root.voice }
    IrisGlassEdge {
        anchors.fill: parent
        visible: !root.skinned && (IrisStyle.controlPlate === "glass" || (IrisStyle.controlPlated && IrisStyle.edgeLit)) && shown
        radius: root.radius
    }

    function slotX(index: int): int {
        const widths = root.hugs ? root.hugWidths : root.shares
        if (widths.length > 0) {
            let x = root.inset
            for (let i = 0; i < Math.min(index, widths.length); i++) x += widths[i]
            return Math.round(x)
        }
        return root.inset + Math.round(index * root.slot)
    }

    // The thumb rides an index, not pixels: a resize keeps it on its slot, a new choice springs from wherever it is.
    IrisSpring {
        id: travel
        intent: "move"
        to: Math.max(0, root.selectedIndex)
        animate: IrisStyle.motionEnabled && root.visible
    }
    Component.onCompleted: travel.jump()
    readonly property real thumbAt: Math.max(-0.15, Math.min(root.count - 0.85, travel.value))
    function edgeAt(position: real): real {
        const base = Math.max(0, Math.min(root.count - 1, Math.floor(position)))
        const t = position - base
        return root.slotX(base) + (root.slotX(base + 1) - root.slotX(base)) * t
    }
    // How chosen a segment reads (0..1) while the thumb travels: its word inverts as the capsule passes under it.
    function chosenness(index: int): real { return root.selectedIndex < 0 ? 0 : Math.max(0, 1 - Math.abs(root.thumbAt - index)) }
    function inkFor(index: int): color {
        return ColorUtils.mix(root.nothing ? IrisStyle.selectionLabel : root.synth ? IrisStyle.synthInkOnCap
            : root.gel ? IrisStyle.inkOnGel : IrisStyle.appleAccent, IrisStyle.subtext, root.chosenness(index))
    }
    RectangularShadow {
        visible: thumb.visible && !root.nothing && !root.gel
        anchors.fill: thumb
        radius: thumb.radius
        offset.y: root.d
        blur: 3 * root.d
        color: IrisStyle.shadow
    }
    Rectangle {
        id: thumb
        visible: root.selectedIndex >= 0 && !root.skinned && !root.synth
        y: root.inset
        height: root.height - 2 * root.inset
        x: Math.round(root.edgeAt(root.thumbAt))
        width: Math.round(root.edgeAt(root.thumbAt + 1)) - x
        radius: root.thumbRadius
        color: root.nothing ? IrisStyle.selectionFill : IrisStyle.raised
        Loader {
            active: root.gel
            anchors.fill: parent
            sourceComponent: Rectangle {
                radius: thumb.radius
                gradient: Gradient {
                    GradientStop { position: 0; color: IrisStyle.gelTop }
                    GradientStop { position: 0.55; color: IrisStyle.gelBody }
                    GradientStop { position: 1; color: IrisStyle.gelBottom }
                }
                Rectangle {
                    x: Math.round(parent.height * 0.3)
                    y: Math.round(2 * root.d)
                    width: parent.width - 2 * x
                    height: Math.round(parent.height * 0.42)
                    radius: height / 2
                    gradient: Gradient {
                        GradientStop { position: 0; color: IrisStyle.gelShineTop }
                        GradientStop { position: 1; color: IrisStyle.gelShineBottom }
                    }
                }
            }
        }
    }

    Repeater {
        model: root.options
        MouseArea {
            id: segment
            required property var modelData
            required property int index
            readonly property bool selected: root.selectedIndex === segment.index
            x: root.slotX(segment.index)
            y: root.inset
            width: root.slotX(segment.index + 1) - x
            height: root.height - 2 * root.inset
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            activeFocusOnTab: true
            Accessible.role: Accessible.RadioButton
            Accessible.name: (root.accessibleName.length > 0 ? root.accessibleName + ": " : "") + Translation.tr(String(segment.modelData.label ?? ""))
            Accessible.checked: segment.selected
            Keys.onSpacePressed: root.picked(segment.modelData.value)
            Keys.onLeftPressed: if (segment.index > 0) root.picked(root.options[segment.index - 1].value)
            Keys.onRightPressed: if (segment.index < root.count - 1) root.picked(root.options[segment.index + 1].value)
            Keys.onReturnPressed: root.picked(segment.modelData.value)
            onClicked: root.picked(segment.modelData.value)
            onContainsMouseChanged: if (segment.containsMouse) root.hoveredIndex = segment.index
                else if (root.hoveredIndex === segment.index) root.hoveredIndex = -1
            onPressedChanged: if (segment.pressed) root.pressedIndex = segment.index
                else if (root.pressedIndex === segment.index) root.pressedIndex = -1
            onActiveFocusChanged: if (segment.activeFocus) root.focusedIndex = segment.index
                else if (root.focusedIndex === segment.index) root.focusedIndex = -1

            // Synth: the segment's key, its edge under the face; chosen, pressed down and capped.
            Loader {
                active: root.synth
                anchors.fill: parent
                anchors.leftMargin: segment.index > 0 ? Math.round(3 * root.d) : 0
                anchors.rightMargin: segment.index < root.count - 1 ? Math.round(3 * root.d) : 0
                sourceComponent: Item {
                    readonly property real edge: Math.round(3 * root.d)
                    Rectangle {
                        y: parent.edge
                        width: parent.width
                        height: parent.height - parent.edge
                        radius: IrisStyle.synthKeyRadius
                        color: IrisStyle.synthKeyEdge
                    }
                    Rectangle {
                        y: Math.round(parent.edge * (2 / 3) * root.chosenness(segment.index) + (segment.pressed ? root.d : 0))
                        width: parent.width
                        height: parent.height - parent.edge
                        radius: IrisStyle.synthKeyRadius
                        color: ColorUtils.mix(IrisStyle.synthCap, segment.containsMouse ? ColorUtils.mix(IrisStyle.text, IrisStyle.synthKey, 0.08) : IrisStyle.synthKey, root.chosenness(segment.index))
                    }
                }
            }
            Rectangle {
                visible: !root.synth
                anchors.fill: parent
                radius: thumb.radius
                // Under a skin the hover and the focus are the skin's to draw.
                color: !segment.selected && segment.containsMouse && !root.skinned ? IrisStyle.fillQuiet : "transparent"
                border.width: segment.activeFocus && !root.skinned ? 1 : 0
                border.color: root.nothing ? IrisStyle.text : IrisStyle.appleAccent
                Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
            }
            MaterialSymbol {
                visible: root.glyphOnly && !root.skinned
                anchors.centerIn: parent
                text: String(segment.modelData.glyph ?? "")
                fill: segment.selected ? 1 : 0
                iconSize: Math.round(16 * root.d)
                color: root.inkFor(segment.index)
            }
            Column {
                visible: root.pictured && !root.skinned
                anchors.centerIn: parent
                width: parent.width - Math.round(8 * root.d)
                spacing: Math.round(2 * root.d)
                MaterialSymbol {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: String(segment.modelData.glyph ?? "")
                    iconSize: Math.round(20 * root.d)
                    fill: segment.selected ? 1 : 0
                    color: root.inkFor(segment.index)
                }
                IrisText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: Translation.tr(String(segment.modelData.label ?? ""))
                    font.pixelSize: IrisStyle.typeFootnote
                    font.weight: IrisStyle.weight(segment.selected ? Font.DemiBold : Font.Normal)
                    color: root.inkFor(segment.index)
                    elide: Text.ElideRight
                }
            }
            Row {
                visible: !root.pictured && !root.glyphOnly && !root.skinned
                anchors.centerIn: parent
                spacing: Math.round(6 * root.d)
                Rectangle {
                    visible: String(segment.modelData.swatch ?? "").length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(12 * root.d)
                    height: width
                    radius: IrisStyle.capsule(width)
                    color: segment.modelData.swatch ?? "transparent"
                    border.width: 1
                    border.color: IrisStyle.borderStrong
                }
                IrisText {
                    anchors.verticalCenter: parent.verticalCenter
                    // Bounded by its segment: a slot too narrow for a translation elides instead of spilling over its neighbour.
                    width: Math.min(implicitWidth, Math.max(0, segment.width - Math.round(16 * root.d)))
                    wrapMode: root.squeezed ? Text.WordWrap : Text.NoWrap
                    maximumLineCount: 2
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: root.squeezed ? 0.9 : 1
                    elide: Text.ElideRight
                    text: Translation.tr(String(segment.modelData.label ?? ""))
                    font.family: (root.fontFor ? root.fontFor(segment.modelData) : "") || (root.synth ? IrisStyle.fontSynthLabel : IrisStyle.fontMain)
                    font.capitalization: root.synth ? Font.AllLowercase : Font.MixedCase
                    // Mono runs wider: Synth's keys print a step smaller so a word still fits its key.
                    font.pixelSize: root.synth ? IrisStyle.typeFootnote : IrisStyle.typeMeta
                    font.weight: IrisStyle.weight(segment.selected ? Font.DemiBold : Font.Normal)
                    color: root.inkFor(segment.index)
                }
            }
        }
    }
}
