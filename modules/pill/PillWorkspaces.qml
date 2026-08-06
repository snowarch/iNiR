pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.services
import qs.modules.common

/**
 * Workspace dots for one monitor. No numbers, no icons. Active one is a larger
 * filled accent stick; the rest are small and dim, brightening on hover.
 *
 * Upstream drove this through a Hyprland-Lua dispatcher that only exists in that
 * config. Here both compositors are served through their own service: Niri via
 * NiriService.allWorkspaces / switchToWorkspace, Hyprland via the stock model and
 * dispatcher. The layout maths (slot centres, active stick width) is unchanged,
 * because Ame's bead maps onto slotCenterX to park on a dot.
 */
Item {
    id: workspaces

    property string screenName: ""
    property real s: 1
    property real stickW: 17 * s
    property real dotW: 5 * s
    property real gap: 4 * s

    property int hoverIndex: -1

    /**
     * Slots as {key, active} pairs so both compositors share one delegate. Niri
     * keys on the workspace index, Hyprland on the workspace id.
     */
    readonly property var slots: {
        if (CompositorService.isNiri) {
            const all = NiriService.allWorkspaces ?? [];
            const mine = all
                .filter(w => !workspaces.screenName || w.output === workspaces.screenName)
                .sort((a, b) => a.idx - b.idx);

            /**
             * Niri always keeps one empty workspace past the last used one, and
             * creates/destroys it as windows come and go. Rendering it makes the
             * dot row change width on every window event, which drags the pill's
             * hover geometry (and Ame's anchor) with it. Drop it unless it is the
             * one you are actually looking at.
             */
            const trimmed = mine.filter((w, i) =>
                !(i === mine.length - 1 && !w.is_focused && !w.active_window_id));

            return trimmed.map(w => ({ key: w.idx, active: w.is_focused === true }));
        }

        const out = [];
        const seen = ({});
        const wss = Hyprland.workspaces?.values ?? [];
        for (let i = 0; i < wss.length; i++) {
            const w = wss[i];
            if (w.id >= 1 && w.monitor && w.monitor.name === workspaces.screenName && !seen[w.id]) {
                seen[w.id] = true;
                out.push(w.id);
            }
        }
        out.sort((x, y) => x - y);

        const activeId = workspaces.hyprActiveId;
        if (activeId >= 1 && !seen[activeId])
            out.push(activeId);
        return out.map(id => ({ key: id, active: id === activeId }));
    }

    readonly property int hyprActiveId: {
        if (CompositorService.isNiri)
            return -1;
        const mons = Hyprland.monitors?.values ?? [];
        for (let i = 0; i < mons.length; i++)
            if (mons[i].name === workspaces.screenName)
                return mons[i].activeWorkspace ? mons[i].activeWorkspace.id : -1;
        return -1;
    }

    readonly property int activeIndex: slots.findIndex(sl => sl.active)

    function focusSlot(key) {
        if (CompositorService.isNiri)
            NiriService.switchToWorkspace(key);
        else
            Hyprland.dispatch("workspace " + key);
    }

    /**
     * Centre x of a dot slot from target layout widths (the active stick is
     * wider). Uses the animation end values, so a focus marker aimed here lands
     * where the dot settles and doesn't chase the width Behavior.
     */
    function slotCenterX(idx) {
        let x = 0;
        for (let i = 0; i < idx; i++)
            x += (i === activeIndex ? stickW : dotW) + gap;
        return x + (idx === activeIndex ? stickW : dotW) / 2;
    }

    readonly property point activeDotPoint: {
        void workspaces.activeIndex;
        void workspaces.width;
        return Qt.point(slotCenterX(Math.max(0, activeIndex)), height / 2);
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: workspaces.gap

        Repeater {
            model: workspaces.slots

            delegate: Item {
                id: slot

                required property var modelData
                required property int index

                readonly property bool isActive: slot.modelData.active

                Layout.preferredWidth: slot.isActive ? workspaces.stickW : workspaces.dotW
                Layout.preferredHeight: 22 * workspaces.s
                Behavior on Layout.preferredWidth {
                    NumberAnimation { duration: PillMotion.fast; easing.type: PillMotion.easeStandard }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: workspaces.dotW
                    radius: height / 2
                    color: slot.isActive ? PillTheme.vermLit : PillTheme.cream
                    opacity: slot.isActive ? 1.0 : (area.containsMouse ? 0.7 : 0.3)
                    Behavior on opacity { NumberAnimation { duration: PillMotion.fast } }
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    anchors.leftMargin: -workspaces.gap / 2
                    anchors.rightMargin: -workspaces.gap / 2
                    anchors.topMargin: -8 * workspaces.s
                    anchors.bottomMargin: -8 * workspaces.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: workspaces.focusSlot(slot.modelData.key)
                    onContainsMouseChanged: {
                        if (containsMouse)
                            workspaces.hoverIndex = slot.index;
                        else if (workspaces.hoverIndex === slot.index)
                            workspaces.hoverIndex = -1;
                    }
                }
            }
        }
    }
}
