pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// The Shelf as an Island page: what you copied, the screenshots you took and the files you dropped on the Island,
// newest first. A tap copies it back; a pin keeps it past the history's length.
ColumnLayout {
    id: page

    required property Item island
    readonly property real d: IrisStyle.density
    readonly property var shown: Shelf.itemsFor(Shelf.filter)
    readonly property int columns: 3
    readonly property real gap: Math.round(8 * page.d)
    readonly property real tileWidth: Math.floor((page.width - page.gap * (page.columns - 1)) / page.columns)
    readonly property real tileHeight: Math.round(page.tileWidth * 0.78)
    readonly property real tileRadius: IrisStyle.fieldChamfer ? 0 : IrisStyle.concentric(IrisStyle.radiusCard, page.gap, IrisStyle.radiusRow)
    property string justCopied: ""

    spacing: Math.round(12 * page.d)
    Component.onCompleted: Cliphist.refresh()

    IrisSegmented {
        Layout.fillWidth: true
        accessibleName: Translation.tr("Show")
        current: Shelf.filter
        options: [
            { value: "all", label: Translation.tr("All") },
            { value: "shots", label: Translation.tr("Shots") },
            { value: "copied", label: Translation.tr("Copied") },
            { value: "files", label: Translation.tr("Files") }
        ]
        onPicked: value => Shelf.filter = String(value)
    }

    Flickable {
        id: view
        visible: page.shown.length > 0
        Layout.fillWidth: true
        // Three rows in view; more scroll.
        Layout.preferredHeight: Math.min(grid.implicitHeight, page.tileHeight * 3 + page.gap * 2)
        contentHeight: grid.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Grid {
            id: grid
            width: view.width
            columns: page.columns
            spacing: page.gap
            Repeater {
                model: page.shown
                delegate: Item {
                    id: tile
                    required property var modelData
                    readonly property var item: tile.modelData
                    readonly property string thumb: Shelf.thumbOf(tile.item)
                    readonly property bool copiedNow: page.justCopied === tile.item.key
                    width: page.tileWidth
                    height: page.tileHeight
                    Component.onCompleted: Shelf.want(tile.item)

                    Rectangle {
                        id: plate
                        anchors.fill: parent
                        radius: page.tileRadius
                        color: tap.pressed ? IrisStyle.fillActive : hover.hovered ? IrisStyle.fillHover : IrisStyle.fillQuiet
                        Behavior on color { ColorAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                    }
                    ClippingRectangle {
                        anchors.fill: parent
                        visible: tile.item.kind === "image"
                        radius: page.tileRadius
                        color: "transparent"
                        IrisImage {
                            anchors.fill: parent
                            source: tile.thumb
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }
                    IrisText {
                        visible: tile.item.kind === "text"
                        // Placed, not anchored: StyledText sizes itself and fill looped on it.
                        x: Math.round(10 * page.d)
                        y: x
                        width: parent.width - 2 * x
                        // A pinned tile keeps its foot for the mark.
                        readonly property real room: page.tileHeight - 2 * x - (tile.item.pinned ? pinMark.height + Math.round(4 * page.d) : 0)
                        height: room
                        text: String(tile.item.preview ?? "").trim()
                        verticalAlignment: Text.AlignTop
                        wrapMode: Text.Wrap
                        maximumLineCount: Math.max(1, Math.floor(room / (IrisStyle.typeMeta * 1.35)))
                        elide: Text.ElideRight
                        color: IrisStyle.text
                        font.pixelSize: IrisStyle.typeMeta
                    }
                    ColumnLayout {
                        visible: tile.item.kind === "file"
                        anchors.fill: parent
                        anchors.margins: Math.round(10 * page.d)
                        spacing: Math.round(4 * page.d)
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "draft"
                            iconSize: Math.round(28 * page.d)
                            color: IrisStyle.textSecondary
                        }
                        IrisText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: String(tile.item.name ?? "")
                            wrapMode: Text.WrapAnywhere
                            maximumLineCount: 2
                            elide: Text.ElideMiddle
                            color: IrisStyle.text
                            font.pixelSize: IrisStyle.typeFootnote
                        }
                    }

                    // Pinned stays past the history's length: its pin shows at rest, in the foot (on top it sat over the text).
                    Rectangle {
                        id: pinMark
                        visible: tile.item.pinned && !keys.shown
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: Math.round(6 * page.d)
                        width: Math.round(20 * page.d)
                        height: width
                        radius: IrisStyle.fieldChamfer ? 0 : width / 2
                        color: IrisStyle.accent
                        MaterialSymbol { anchors.centerIn: parent; text: "keep"; fill: 1; iconSize: Math.round(13 * page.d); color: IrisStyle.inkOnAccent }
                    }

                    // Copied: a check over the tile for a moment.
                    Rectangle {
                        anchors.fill: parent
                        radius: page.tileRadius
                        color: Qt.alpha(IrisStyle.accent, 0.85)
                        opacity: tile.copiedNow ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
                        MaterialSymbol { anchors.centerIn: parent; text: "check"; iconSize: Math.round(26 * page.d); color: IrisStyle.inkOnAccent }
                    }

                    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: tap
                        gesturePolicy: TapHandler.WithinBounds
                        onTapped: {
                            Shelf.copy(tile.item)
                            page.justCopied = tile.item.key
                            copiedLapse.restart()
                        }
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: tile.item.kind === "text" ? String(tile.item.preview ?? "").slice(0, 80) : String(tile.item.name ?? "")

                    // Pin and remove ride the corner while the pointer is over the tile.
                    Row {
                        id: keys
                        readonly property bool shown: hover.hovered || pinKey.hovered || dropKey.hovered
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Math.round(6 * page.d)
                        spacing: Math.round(4 * page.d)
                        opacity: keys.shown && !tile.copiedNow ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                        CornerKey {
                            id: pinKey
                            glyph: "keep"
                            lit: tile.item.pinned
                            name: tile.item.pinned ? Translation.tr("Unpin") : Translation.tr("Pin")
                            onActivated: Shelf.togglePin(tile.item)
                        }
                        CornerKey {
                            id: dropKey
                            glyph: "close"
                            name: Translation.tr("Remove")
                            onActivated: Shelf.remove(tile.item)
                        }
                    }
                }
            }
        }
    }

    Timer { id: copiedLapse; interval: 1200; onTriggered: page.justCopied = "" }

    // Nothing here yet: what lands on the shelf and how, where the tiles would be.
    ColumnLayout {
        visible: page.shown.length === 0
        Layout.fillWidth: true
        Layout.topMargin: Math.round(18 * page.d)
        Layout.bottomMargin: Math.round(18 * page.d)
        spacing: Math.round(6 * page.d)
        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: Shelf.filter === "shots" ? "screenshot_region" : Shelf.filter === "copied" ? "content_paste" : Shelf.filter === "files" ? "draft" : "inventory_2"
            iconSize: Math.round(30 * page.d)
            color: IrisStyle.textTertiary
        }
        IrisText {
            Layout.alignment: Qt.AlignHCenter
            text: Shelf.filter === "shots" ? Translation.tr("No screenshots yet")
                : Shelf.filter === "copied" ? Translation.tr("Nothing copied yet")
                : Shelf.filter === "files" ? Translation.tr("No files yet") : Translation.tr("The shelf is empty")
            color: IrisStyle.text
            font.pixelSize: IrisStyle.typeBody
            font.weight: IrisStyle.weight(Font.DemiBold)
        }
        IrisText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: Translation.tr("What you copy, the screenshots you take and the files you drop on the Island land here.")
            color: IrisStyle.textSecondary
            font.pixelSize: IrisStyle.typeMeta
        }
    }

    RowLayout {
        visible: Shelf.items.length > 0
        Layout.fillWidth: true
        IrisText {
            Layout.fillWidth: true
            text: page.justCopied.length > 0 ? Translation.tr("Copied. Paste it anywhere.")
                : Translation.tr("Tap one to copy it")
            color: IrisStyle.textSecondary
            font.pixelSize: IrisStyle.typeMeta
            elide: Text.ElideRight
        }
        IrisButton {
            visible: Shelf.items.some(item => !item.pinned)
            text: Translation.tr("Clear")
            quiet: true
            onClicked: Shelf.clear()
        }
    }

    component CornerKey: Rectangle {
        id: key
        property string glyph: ""
        property string name: ""
        property bool lit: false
        readonly property bool hovered: keyHover.hovered
        signal activated()
        width: Math.round(22 * page.d)
        height: width
        radius: IrisStyle.fieldChamfer ? 0 : width / 2
        color: key.lit ? IrisStyle.accent : keyHover.hovered ? IrisStyle.surfaceHigh : IrisStyle.surface
        border.width: key.lit ? 0 : 1
        border.color: IrisStyle.hairline
        MaterialSymbol {
            anchors.centerIn: parent
            text: key.glyph
            fill: key.lit ? 1 : 0
            iconSize: Math.round(14 * page.d)
            color: key.lit ? IrisStyle.inkOnAccent : IrisStyle.text
        }
        HoverHandler { id: keyHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: key.activated() }
        Accessible.role: Accessible.Button
        Accessible.name: key.name
    }
}
