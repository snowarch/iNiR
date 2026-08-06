pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// Floating drag ghost for moving a window between workspaces.
//
// Window rows live clipped inside the detail flyout, so they can't visually
// leave it while being dragged. This proxy is a single shared item parented to
// the strip content: rows drive it (placeAt / beginDrag / moveTo / endDrag) and
// it carries the Qt drag payload that the rail cards' DropAreas accept.
//
// `dragKey` matches the `keys` on each card DropArea. The drop target reads
// `win` to know which window to move.
Item {
    id: proxy

    readonly property string dragKey: "workspaceStripWindow"

    property bool dragging: false
    property var win: null
    property string title: ""
    property string appId: ""

    width: 168
    height: 40
    visible: dragging
    z: 10000

    Drag.active: dragging
    Drag.source: proxy
    Drag.keys: [dragKey]
    Drag.hotSpot.x: 0
    Drag.hotSpot.y: 0

    readonly property bool _zzz: Appearance.zzzEverywhere

    function _moveUnderPointer(src: Item, mx: real, my: real): void {
        if (!parent) return
        const p = src.mapToItem(parent, mx, my)
        proxy.x = p.x
        proxy.y = p.y - height / 2
    }

    function placeAt(src: Item, mx: real, my: real): void {
        _moveUnderPointer(src, mx, my)
    }

    function beginDrag(w, t: string, a: string): void {
        win = w
        title = t
        appId = a
        dragging = true
    }

    function moveTo(src: Item, mx: real, my: real): void {
        if (dragging) _moveUnderPointer(src, mx, my)
    }

    function _reset(): void {
        dragging = false
        win = null
        title = ""
        appId = ""
    }

    function endDrag(): void {
        if (dragging) Drag.drop()
        _reset()
    }

    function cancelDrag(): void {
        if (dragging) Drag.cancel()
        _reset()
    }

    Rectangle {
        anchors.fill: parent
        radius: proxy._zzz ? Appearance.zzz.controlRadius : Appearance.rounding.small
        color: proxy._zzz ? Appearance.zzz.bg3 : Appearance.colors.colLayer3
        border.width: 1
        border.color: proxy._zzz ? Appearance.zzz.accent
            : ColorUtils.transparentize(Appearance.colors.colPrimary, 0.4)
        opacity: 0.95

        Row {
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: 8
                rightMargin: 8
            }
            spacing: 8

            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 22
                source: proxy.appId.length > 0 ? AppSearch.getIconSource(proxy.appId) : ""
                visible: source.toString().length > 0
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 30
                text: proxy.title
                elide: Text.ElideRight
                maximumLineCount: 1
                font.pixelSize: Appearance.font.pixelSize.small
                color: proxy._zzz ? Appearance.zzz.onColor : Appearance.colors.colOnLayer3
            }
        }
    }
}
