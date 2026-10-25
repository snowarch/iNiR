pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.widgets
import qs.modules.shared.background.widgets

// A chosen widget's controls while arranging, at their true size beside the widget on the card (the card is shrunk,
// they are not). A body of the edit window's field that grows out of the side of the widget it belongs to.
Item {
    id: root

    required property string outputName
    property var card: ({ x: 0, y: 0, s: 1, p: 0 })
    // The shelf's rect: the sheet never sits over it.
    property rect avoid: Qt.rect(0, 0, 0, 0)

    readonly property real d: IrisStyle.density
    // Everything Settings offers for this widget, minus what the sheet already draws (size, Look, Arrange).
    readonly property var rows: {
        const key = String(root.held?.configEntryName ?? "")
        const drawn = ["iris.size", "iris.design", "iris.material", "widgetScale", "placementStrategy", "locked"]
        return DesktopWidgetOptions.widgetRows.filter(spec => spec.widget === key && !spec.widgetEnable && !drawn.includes(spec.key))
            .map(spec => Object.assign({}, spec, { group: "" }))
    }
    Component {
        id: rowsComponent
        IrisEditRows { specs: root.rows }
    }
    Component.onCompleted: DesktopEditStage.setSheetHost(root.outputName, true)
    Component.onDestruction: DesktopEditStage.setSheetHost(root.outputName, false)

    readonly property var widget: DesktopEditStage.inspected?.output === root.outputName ? DesktopEditStage.inspected.widget : null
    // Kept while it closes, so it shrinks back into the widget it came from.
    property var held: null
    onWidgetChanged: if (root.widget) root.held = root.widget
    readonly property bool open: root.widget !== null && GlobalStates.widgetEditMode
    readonly property real presentation: spring.value
    readonly property bool shown: root.presentation > 0.002
    onShownChanged: if (!root.shown && !root.open) root.held = null
    readonly property bool typing: root.open && (content.item?.activeFocusItem ?? null) !== null

    IrisSpring {
        id: spring
        surface: "panels"
        to: root.open ? 1 : 0
        intent: "auto"
        minimum: 0
    }

    // Where the widget shows on the card, in this window's pixels.
    readonly property rect seen: {
        const w = root.held
        if (!w) return Qt.rect(root.width / 2, root.height / 2, 0, 0)
        return Qt.rect(root.card.x + w.x * root.card.s, root.card.y + w.y * root.card.s, w.width * root.card.s, w.height * root.card.s)
    }
    readonly property real pad: Math.round(12 * root.d)
    readonly property real gap: Math.round(14 * root.d)
    readonly property real fullWidth: Math.round((content.item?.resolvedWidth ?? 336 * root.d) + 2 * root.pad)
    readonly property real roomBottom: root.avoid.height > 0 ? root.avoid.y - root.gap : root.height - root.gap
    readonly property real fullHeight: Math.min(Math.round((content.item?.implicitHeight ?? 0) + 2 * root.pad),
        root.roomBottom - root.gap)
    // Beside the widget on the side with room (right first), level with its top; above the shelf if neither fits.
    readonly property string side: root.seen.x + root.seen.width + root.gap + root.fullWidth <= root.width - root.gap ? "right"
        : root.seen.x - root.gap - root.fullWidth >= root.gap ? "left" : "over"
    readonly property real restX: root.side === "right" ? root.seen.x + root.seen.width + root.gap
        : root.side === "left" ? root.seen.x - root.gap - root.fullWidth
        : Math.max(root.gap, Math.min(root.width - root.gap - root.fullWidth, root.seen.x + (root.seen.width - root.fullWidth) / 2))
    readonly property real restY: Math.max(root.gap, Math.min(root.roomBottom - root.fullHeight, root.seen.y))
    // It grows from the widget's near edge: at 0 it is a sliver against that edge.
    readonly property real g: Math.max(0, Math.min(1, root.presentation))
    readonly property real originX: root.side === "right" ? root.seen.x + root.seen.width
        : root.side === "left" ? root.seen.x : root.seen.x + root.seen.width / 2
    readonly property real bodyWidth: Math.round(root.fullWidth * (0.4 + 0.6 * root.g))
    readonly property real bodyHeight: Math.round(root.fullHeight * (0.55 + 0.45 * root.g))
    readonly property real bodyX: Math.round(root.side === "left" ? root.originX - (root.originX - root.restX - root.fullWidth) * root.g - root.bodyWidth
        : root.side === "right" ? root.originX + (root.restX - root.originX) * root.g
        : root.restX + (root.fullWidth - root.bodyWidth) / 2)
    readonly property real bodyY: Math.round(root.restY + (root.fullHeight - root.bodyHeight) / 2)
    readonly property real bodyRadius: Math.min(IrisStyle.radiusPlate, root.bodyHeight / 2)

    readonly property rect hitRect: root.shown ? Qt.rect(root.bodyX, root.bodyY, root.bodyWidth, root.bodyHeight) : Qt.rect(0, 0, 0, 0)
    readonly property var fieldShapes: root.shown ? [{
        x: root.bodyX, y: root.bodyY, width: root.bodyWidth, height: root.bodyHeight,
        radius: root.bodyRadius, fuse: IrisStyle.fuse, paints: true, id: "widgetsheet", joins: "",
        frost: Math.min(1, root.presentation * 1.6)
    }] : []

    Item {
        x: root.bodyX
        y: root.bodyY
        width: root.bodyWidth
        height: root.bodyHeight
        clip: true
        visible: root.shown
        // The press lands here, not on the card under it.
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
        Flickable {
            id: scroller
            x: root.pad + (root.bodyWidth - root.fullWidth) / 2
            y: root.pad
            width: root.fullWidth - 2 * root.pad
            height: root.fullHeight - 2 * root.pad
            contentHeight: content.item?.implicitHeight ?? 0
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            opacity: IrisStyle.contentAt(root.presentation)
            Loader {
                id: content
                width: scroller.width
                active: root.held !== null
                sourceComponent: IrisWidgetControls {
                    widget: root.held
                    plateRadius: IrisStyle.concentric(IrisStyle.radiusPlate, root.pad, IrisStyle.radiusChip)
                    plateCut: IrisStyle.nestedCut(IrisStyle.chamferCut, root.pad)
                    optionRows: root.rows.length > 0 ? rowsComponent : null
                }
            }
        }
    }
}
