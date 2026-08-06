pragma ComponentBehavior: Bound

import QtQuick

// Full-length edge drop zones for the shell layout editor. Each legal slot
// renders one strip along its screen edge; the hovered or drag-previewed
// strip lights up to show exactly where the surface will land.
Item {
    id: root

    required property var slots
    required property string currentSlot
    required property string previewedSlot
    required property string topLabel
    required property string rightLabel
    required property string bottomLabel
    required property string leftLabel
    required property color accentColor
    required property color surfaceColor
    required property color textColor
    required property real radius
    required property string fontFamily
    required property int fontPixelSize
    required property int animationDuration

    property bool active: false
    property var validations: ({})
    property real stripThickness: 64
    property real cornerGap: 88
    property real edgeMargin: 14
    property real topEdgeMargin: edgeMargin
    property real bottomEdgeMargin: edgeMargin

    property alias topTargetItem: topTarget
    property alias rightTargetItem: rightTarget
    property alias bottomTargetItem: bottomTarget
    property alias leftTargetItem: leftTarget

    signal previewRequested(string slot)
    signal placementRequested(string slot)

    visible: root.active
    enabled: root.active
    z: 9000

    function supports(slot: string): bool {
        return Array.isArray(root.slots) && root.slots.includes(slot)
    }

    function validationFor(slot: string): var {
        return root.validations?.[slot] ?? ({
            ok: root.supports(slot),
            changed: root.currentSlot !== slot
        })
    }

    function targetValid(slot: string): bool {
        const validation = root.validationFor(slot)
        return validation.ok && (validation.changed ?? true)
    }

    function targetOccupied(slot: string): bool {
        const validation = root.validationFor(slot)
        return root.currentSlot === slot
            || String(validation.swapWith ?? "").length > 0
            || String(validation.occupiedBy ?? "").length > 0
    }

    function targetLabel(baseLabel: string, slot: string): string {
        const validation = root.validationFor(slot)
        if (root.currentSlot === slot)
            return baseLabel + " · " + qsTr("Current")
        if (!validation.ok)
            return baseLabel + " · " + qsTr("Unavailable")
        if (String(validation.swapWith ?? "").length > 0)
            return baseLabel + " · " + qsTr("Swap")
        return baseLabel
    }

    ShellEditDropTarget {
        id: topTarget
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: root.topEdgeMargin
            leftMargin: root.cornerGap
            rightMargin: root.cornerGap
        }
        height: root.stripThickness
        slot: "top"
        label: root.targetLabel(root.topLabel, slot)
        active: root.active && root.supports(slot)
        valid: root.targetValid(slot)
        occupied: root.targetOccupied(slot)
        previewed: root.previewedSlot === slot
        accentColor: root.accentColor
        surfaceColor: root.surfaceColor
        textColor: root.textColor
        radius: root.radius
        fontFamily: root.fontFamily
        fontPixelSize: root.fontPixelSize
        animationDuration: root.animationDuration
        onPreviewRequested: target => root.previewRequested(target)
        onPlacementRequested: target => root.placementRequested(target)
    }

    ShellEditDropTarget {
        id: rightTarget
        anchors {
            right: parent.right
            top: parent.top
            bottom: parent.bottom
            rightMargin: root.edgeMargin
            topMargin: root.topEdgeMargin + root.stripThickness + root.cornerGap / 2
            bottomMargin: root.bottomEdgeMargin + root.stripThickness + root.cornerGap / 2
        }
        width: root.stripThickness
        slot: "right"
        label: root.targetLabel(root.rightLabel, slot)
        active: root.active && root.supports(slot)
        valid: root.targetValid(slot)
        occupied: root.targetOccupied(slot)
        previewed: root.previewedSlot === slot
        accentColor: root.accentColor
        surfaceColor: root.surfaceColor
        textColor: root.textColor
        radius: root.radius
        fontFamily: root.fontFamily
        fontPixelSize: root.fontPixelSize
        animationDuration: root.animationDuration
        onPreviewRequested: target => root.previewRequested(target)
        onPlacementRequested: target => root.placementRequested(target)
    }

    ShellEditDropTarget {
        id: bottomTarget
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            bottomMargin: root.bottomEdgeMargin
            leftMargin: root.cornerGap
            rightMargin: root.cornerGap
        }
        height: root.stripThickness
        slot: "bottom"
        label: root.targetLabel(root.bottomLabel, slot)
        active: root.active && root.supports(slot)
        valid: root.targetValid(slot)
        occupied: root.targetOccupied(slot)
        previewed: root.previewedSlot === slot
        accentColor: root.accentColor
        surfaceColor: root.surfaceColor
        textColor: root.textColor
        radius: root.radius
        fontFamily: root.fontFamily
        fontPixelSize: root.fontPixelSize
        animationDuration: root.animationDuration
        onPreviewRequested: target => root.previewRequested(target)
        onPlacementRequested: target => root.placementRequested(target)
    }

    ShellEditDropTarget {
        id: leftTarget
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            leftMargin: root.edgeMargin
            topMargin: root.topEdgeMargin + root.stripThickness + root.cornerGap / 2
            bottomMargin: root.bottomEdgeMargin + root.stripThickness + root.cornerGap / 2
        }
        width: root.stripThickness
        slot: "left"
        label: root.targetLabel(root.leftLabel, slot)
        active: root.active && root.supports(slot)
        valid: root.targetValid(slot)
        occupied: root.targetOccupied(slot)
        previewed: root.previewedSlot === slot
        accentColor: root.accentColor
        surfaceColor: root.surfaceColor
        textColor: root.textColor
        radius: root.radius
        fontFamily: root.fontFamily
        fontPixelSize: root.fontPixelSize
        animationDuration: root.animationDuration
        onPreviewRequested: target => root.previewRequested(target)
        onPlacementRequested: target => root.placementRequested(target)
    }
}
