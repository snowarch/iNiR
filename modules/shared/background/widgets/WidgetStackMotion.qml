import QtQuick
import qs
import qs.modules.common
import qs.services

// One widget as a page of a stack: pages turning, and the drop that makes a stack (carried over another it lights it as
// a target; let go, it glides onto that place, dissolves and joins). A widget that can't stack builds none of this.
Item {
    id: root

    required property var widget
    // 0 while this page is shown; a page's length away (+1 below, -1 above) while it waits or leaves.
    property real pos: 0
    readonly property bool moving: slide.running
    property string dropKey: ""
    // 0 at rest, 1 once the widget has glided into the stack it was dropped on.
    property real absorb: 0

    function probe(): void {
        const canvas = root.widget._canvas
        if (!canvas || typeof canvas.stackDropCandidate !== "function")
            return
        const key = root.widget.isDragging && root.widget.stackable ? canvas.stackDropCandidate(root.widget.editInstanceKey) : ""
        if (key === root.dropKey)
            return
        root.dropKey = key
        canvas.stackHint = key
    }
    function clearDrop(): void {
        root.dropKey = ""
        if (root.widget._canvas && root.widget._canvas.stackHint !== undefined)
            root.widget._canvas.stackHint = ""
    }
    function drop(): void {
        const target = root.widget._canvas?.loadedWidget(root.dropKey) ?? null
        if (!target) {
            root.clearDrop()
            return
        }
        absorbing.targetKey = target.configEntryName
        absorbing.toX = Math.round(target.x + (target.width - root.widget.width) / 2)
        absorbing.toY = Math.round(target.y + (target.height - root.widget.height) / 2)
        if (root.widget.animationsActive)
            absorbing.restart()
        else
            root._join(absorbing.targetKey)
    }
    function _join(targetName: string): void {
        const id = DesktopWidgetStacks.merge(targetName, root.widget.configEntryName)
        root.clearDrop()
        root.absorb = 0
        // Joined, this widget stands where its stack does; refused, where it stood.
        root.widget.x = root.widget.placement.targetX
        root.widget.y = root.widget.placement.targetY
        if (id.length > 0)
            land.restart()
    }
    Component.onDestruction: if (absorbing.running) root._join(absorbing.targetKey)
    ParallelAnimation {
        id: absorbing
        property string targetKey: ""
        property real toX: 0
        property real toY: 0
        NumberAnimation { target: root.widget; property: "x"; to: absorbing.toX; duration: FamilyStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: FamilyStyle.moveCurve }
        NumberAnimation { target: root.widget; property: "y"; to: absorbing.toY; duration: FamilyStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: FamilyStyle.moveCurve }
        NumberAnimation { target: root; property: "absorb"; from: 0; to: 1; duration: FamilyStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: FamilyStyle.moveCurve }
        onFinished: root._join(absorbing.targetKey)
    }
    // Once it has joined, the stack turns to it, so the drop is seen to have landed.
    Timer {
        id: land
        interval: 260
        onTriggered: {
            const id = DesktopWidgetStacks.memberMap[root.widget.configEntryName]
            if (id !== undefined)
                DesktopWidgetStacks.show(root.widget.outputName, id, root.widget.configEntryName)
        }
    }

    // The page shown changes: the one leaving slides out, the one arriving slides in from the side it was turned from.
    // Forming or dissolving a stack never animates.
    readonly property var stack: root.widget.stack
    property string _memo: ""
    function _key(): string {
        return root.stack === null ? "" : root.stack.id + (root.stack.shown ? "+" : "-")
    }
    Component.onCompleted: root._memo = root._key()
    onStackChanged: {
        const memo = root._key()
        if (memo === root._memo)
            return
        const before = root._memo
        root._memo = memo
        const turned = before.length > 0 && memo.length > 0 && before.slice(0, -1) === memo.slice(0, -1)
        if (!turned || !root.widget.animationsActive || !root.widget.familyFaced || !root.widget.visible && memo.endsWith("-")) {
            slide.stop()
            root.pos = 0
            return
        }
        const arriving = memo.endsWith("+")
        slide.stop()
        root.pos = arriving ? root.stack.dir : 0
        slide.to = arriving ? 0 : -root.stack.dir
        slide.restart()
        // Arranging: the page that comes up is the one being arranged.
        if (arriving && GlobalStates.widgetEditMode
                && DesktopWidgetStacks.memberMap[String(GlobalStates.selectedDesktopWidget).split("::")[1]] === root.stack.id)
            GlobalStates.selectDesktopWidget(root.widget.editInstanceKey)
    }
    NumberAnimation {
        id: slide
        target: root
        property: "pos"
        duration: FamilyStyle.moveDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: FamilyStyle.moveCurve
    }
}
