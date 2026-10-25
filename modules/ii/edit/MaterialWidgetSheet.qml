pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// A chosen widget's quick controls while arranging under Material, at their true size beside it on the card (the card
// is shrunk, they are not), on a raised sheet that grows out of the widget's side. Each page keeps the tallest it has
// shown, so a toggle never shrinks its own page.
Item {
    id: root

    required property string outputName
    property var card: ({ x: 0, y: 0, s: 1, p: 0 })
    // The toolbar and the shelf: the sheet never sits over them.
    property rect avoidTop: Qt.rect(0, 0, 0, 0)
    property rect avoidBottom: Qt.rect(0, 0, 0, 0)

    Component.onCompleted: DesktopEditStage.setSheetHost(root.outputName, true)
    Component.onDestruction: DesktopEditStage.setSheetHost(root.outputName, false)

    readonly property var widget: DesktopEditStage.inspected?.output === root.outputName ? DesktopEditStage.inspected.widget : null
    // Kept while it closes, so it folds back into the widget it came from.
    property var held: null
    onWidgetChanged: if (root.widget) {
        if (root.held !== root.widget) root.pageHeights = ({})
        root.held = root.widget
    }
    readonly property bool open: root.widget !== null && GlobalStates.widgetEditMode
    property real presentation: root.open ? 1 : 0
    Behavior on presentation {
        NumberAnimation {
            duration: Appearance.animation.elementMove.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.open ? Appearance.animationCurves.expressiveFastSpatial : Appearance.animationCurves.emphasizedAccel
        }
    }
    readonly property bool shown: root.presentation > 0.002
    onShownChanged: if (!root.shown && !root.open) root.held = null
    readonly property bool typing: root.open && (content.item?.activeFocusItem ?? null) !== null

    // Where the widget shows on the card, in this window's pixels.
    readonly property rect seen: {
        const w = root.held
        if (!w) return Qt.rect(root.width / 2, root.height / 2, 0, 0)
        return Qt.rect(root.card.x + w.x * root.card.s, root.card.y + w.y * root.card.s, w.width * root.card.s, w.height * root.card.s)
    }
    readonly property real pad: 14
    readonly property real gap: 16
    readonly property string page: String(root.held?.quickTab ?? "")
    property var pageHeights: ({})
    readonly property real contentHeight: content.item?.implicitHeight ?? 0
    onContentHeightChanged: if (root.open && root.contentHeight > 0) {
        const seen = Object.assign({}, root.pageHeights)
        seen[root.page] = Math.max(seen[root.page] ?? 0, root.contentHeight)
        root.pageHeights = seen
    }
    readonly property real fullWidth: Math.round((content.item?.resolvedWidth ?? content.item?.implicitWidth ?? 344) + 2 * root.pad)
    readonly property real roomTop: root.avoidTop.height > 0 ? root.avoidTop.y + root.avoidTop.height + root.gap : root.gap
    readonly property real roomBottom: root.avoidBottom.height > 0 ? root.avoidBottom.y - root.gap : root.height - root.gap
    readonly property real fullHeight: Math.min(Math.round(Math.max(root.contentHeight, root.pageHeights[root.page] ?? 0) + 2 * root.pad),
        root.roomBottom - root.roomTop)
    // Beside the widget on the side with room (right first), level with its top; centred over it if neither fits.
    readonly property string side: root.seen.x + root.seen.width + root.gap + root.fullWidth <= root.width - root.gap ? "right"
        : root.seen.x - root.gap - root.fullWidth >= root.gap ? "left" : "over"
    readonly property real restX: root.side === "right" ? root.seen.x + root.seen.width + root.gap
        : root.side === "left" ? root.seen.x - root.gap - root.fullWidth
        : Math.max(root.gap, Math.min(root.width - root.gap - root.fullWidth, root.seen.x + (root.seen.width - root.fullWidth) / 2))
    readonly property real restY: Math.max(root.roomTop, Math.min(root.roomBottom - root.fullHeight, root.seen.y))
    readonly property real g: Math.max(0, Math.min(1.08, root.presentation))
    readonly property real originX: root.side === "right" ? root.seen.x + root.seen.width
        : root.side === "left" ? root.seen.x : root.seen.x + root.seen.width / 2
    readonly property real bodyWidth: Math.round(root.fullWidth * (0.5 + 0.5 * Math.min(1, root.g)))
    readonly property real bodyHeight: Math.round(root.fullHeight * (0.6 + 0.4 * Math.min(1, root.g)))
    readonly property real bodyX: Math.round(root.side === "left" ? root.originX - (root.originX - root.restX - root.fullWidth) * root.g - root.bodyWidth
        : root.side === "right" ? root.originX + (root.restX - root.originX) * root.g
        : root.restX + (root.fullWidth - root.bodyWidth) / 2)
    readonly property real bodyY: Math.round(root.restY + (root.fullHeight - root.bodyHeight) / 2)

    readonly property rect hitRect: root.shown ? Qt.rect(root.bodyX, root.bodyY, root.bodyWidth, root.bodyHeight) : Qt.rect(0, 0, 0, 0)
    // Glass styles see through their layers; over the card that read the widgets' text under the rows, so the sheet
    // keeps a floor and asks the compositor to frost what's behind it.
    readonly property bool glassy: Appearance.colors.colLayer1.a < 0.9
    readonly property Item bodyItem: body

    Rectangle {
        id: body
        x: root.bodyX
        y: root.bodyY
        width: root.bodyWidth
        height: Math.max(0, root.bodyHeight)
        visible: root.shown
        radius: Appearance.rounding.large
        color: root.glassy ? ColorUtils.applyAlpha(Appearance.colors.colLayer1Base, 0.9) : Appearance.colors.colLayer1
        border.width: Appearance.angelEverywhere || Appearance.inirEverywhere ? 1 : 0
        border.color: Appearance.colors.colOutlineVariant
        clip: true
        StyledRectangularShadow { target: body; z: -1 }
        Behavior on height {
            enabled: root.open && root.presentation > 0.99
            NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
        }
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
            opacity: Math.max(0, Math.min(1, (root.presentation - 0.35) / 0.5))
            Loader {
                id: content
                width: scroller.width
                active: root.held !== null
                sourceComponent: root.held?._effectivePopover ?? null
            }
        }
    }
}
