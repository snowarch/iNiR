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

    // Optional visual overrides for other shell surfaces reusing the proven
    // drag lifecycle. Defaults preserve WorkspaceStrip exactly.
    property color surfaceColor: proxy._zzz ? Appearance.zzz.bg3 : Appearance.colors.colLayer3
    property color outlineColor: proxy._zzz ? Appearance.zzz.accent
        : ColorUtils.transparentize(Appearance.colors.colPrimary, 0.4)
    property color foregroundColor: proxy._zzz ? Appearance.zzz.onColor : Appearance.colors.colOnLayer3
    property real cornerRadius: proxy._zzz ? Appearance.zzz.controlRadius : Appearance.rounding.small
    property real surfaceOpacity: 0.95
    property bool previewEnabled: false
    property string previewSource: ""
    property real compactWidth: 168
    property real compactHeight: 40
    property real previewWidth: 196
    property real previewHeight: 118
    property bool centerOnPointer: false

    width: previewEnabled ? previewWidth : compactWidth
    height: previewEnabled ? previewHeight : compactHeight
    visible: dragging
    z: 10000

    Drag.active: dragging
    Drag.source: proxy
    Drag.keys: [dragKey]
    Drag.hotSpot.x: centerOnPointer ? width / 2 : 0
    Drag.hotSpot.y: centerOnPointer ? height / 2 : 0

    readonly property bool _zzz: Appearance.zzzEverywhere

    function _moveUnderPointer(src: Item, mx: real, my: real): void {
        if (!parent) return
        const p = src.mapToItem(parent, mx, my)
        proxy.x = centerOnPointer ? p.x - width / 2 : p.x
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
        radius: proxy.cornerRadius
        color: proxy.surfaceColor
        border.width: 1
        border.color: proxy.outlineColor
        opacity: proxy.surfaceOpacity

        Row {
            visible: !proxy.previewEnabled
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
                color: proxy.foregroundColor
            }
        }

        ClippingRectangle {
            visible: proxy.previewEnabled
            anchors.fill: parent
            anchors.margins: 3
            radius: Math.max(2, proxy.cornerRadius - 3)
            color: proxy.surfaceColor

            Image {
                id: previewImage
                anchors.fill: parent
                source: proxy.previewSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                mipmap: true
                visible: status === Image.Ready
            }

            Rectangle {
                anchors.fill: parent
                visible: !previewImage.visible
                color: proxy.surfaceColor

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 34
                    source: proxy.appId.length > 0 ? AppSearch.getIconSource(proxy.appId) : ""
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 30
                color: ColorUtils.applyAlpha(proxy.surfaceColor, 0.92)

                Row {
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 8
                        rightMargin: 8
                    }
                    spacing: 7

                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 18
                        source: proxy.appId.length > 0 ? AppSearch.getIconSource(proxy.appId) : ""
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, parent.width - 28)
                        text: proxy.title
                        renderType: Text.QtRendering
                        font.hintingPreference: Font.PreferNoHinting
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: proxy.foregroundColor
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
            }
        }
    }
}
