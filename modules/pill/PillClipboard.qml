pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import qs.services.deferred

/**
 * 控 CLIPBOARD surface: search field over the cliphist history, drawn as one of
 * the pill's surfaces. Entries come from iNiR's Cliphist service snapshot so the
 * list is populated as soon as the pill finishes morphing; typing runs the
 * service's fuzzy query. Return copies the selected entry and closes, hovering a
 * row cross-fades a dismiss glyph that deletes it (Ctrl+X does the same for the
 * keyboard selection). Image entries render through CliphistImage, which decodes
 * the cliphist blob to a cached file. Holding the 掃 glyph for the heat duration
 * wipes the whole history; progress sweeps along the header divider and drains
 * on early release. This is the pill's own face for the clipboard — the standalone
 * ClipboardPanel and its keybind are untouched.
 */
PillSurface {
    id: root

    mTop: 15
    mLeft: 17
    mRight: 17
    mBottom: 14

    property string query: ""
    property int selectedIndex: 0

    /**
     * Window-coordinate position of the last hover event that was allowed to
     * move the selection. Rows sliding under a stationary cursor during
     * keyboard scrolling produce hover events at an unchanged window position,
     * which must not steal the keyboard selection.
     */
    property point lastPointer: Qt.point(-1, -1)

    readonly property point caretPoint: {
        void root.width;
        void root.height;
        void search.input.width;
        return search.input.mapToItem(root,
            search.input.cursorRectangle.x + search.input.cursorRectangle.width / 2,
            search.input.cursorRectangle.y + search.input.cursorRectangle.height / 2);
    }

    ameForm: "caret"
    amePoint: caretPoint

    readonly property var results: {
        void Cliphist.entries;
        return Cliphist.fuzzyQuery(query);
    }

    function entryPreview(entry) {
        const cleaned = String(entry ?? "").replace(/^\s*\S+\s+/, "");
        const unwrapped = StringUtils.cliphistMarkupPreview(cleaned);
        if (unwrapped === cleaned)
            return cleaned;
        return unwrapped.length > 0 ? unwrapped : Translation.tr("Rich text");
    }

    function focusField() { search.input.forceActiveFocus(); }

    function move(delta) {
        if (results.length === 0)
            return;
        selectedIndex = Math.max(0, Math.min(results.length - 1, selectedIndex + delta));
        list.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function activate() {
        if (results.length === 0 || selectedIndex < 0 || selectedIndex >= results.length)
            return;
        Cliphist.copy(results[selectedIndex]);
        root.requestClose();
    }

    function removeAt(index) {
        if (index < 0 || index >= results.length)
            return;
        Cliphist.deleteEntry(results[index]);
    }

    onActiveChanged: {
        if (active) {
            query = "";
            search.text = "";
            selectedIndex = 0;
            Cliphist.refresh();
            Qt.callLater(root.focusField);
        }
    }
    onResultsChanged: if (selectedIndex >= results.length) selectedIndex = Math.max(0, results.length - 1)

    SearchField {
        id: search
        z: 5
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        s: root.s
        kanji: PillTheme.glyph("clipboardSearch")
        placeholder: Translation.tr("Search clipboard")
        counterText: root.results.length + " / " + Cliphist.entries.length
        onTextChanged: {
            root.query = text;
            root.selectedIndex = 0;
        }
        onMoved: (d) => root.move(d)
        onAccepted: root.activate()
        onDismissed: root.requestClose()
        onKeyPressed: (e) => {
            if (e.key === Qt.Key_X && (e.modifiers & Qt.ControlModifier)
                && search.input.selectedText.length === 0) {
                root.removeAt(root.selectedIndex);
                e.accepted = true;
            }
        }

        Item {
            id: wipeBtn
            anchors.verticalCenter: parent.verticalCenter
            width: 16 * root.s
            height: 16 * root.s

            readonly property real hold: wipeHeat.hold
            readonly property bool holding: wipeHeat.holding
            readonly property color tone: holding ? PillTheme.vermLit : (wipeArea.containsMouse ? PillTheme.cream : PillTheme.faint)

            Tooltip {
                s: root.s
                placement: "below"
                title: Translation.tr("hold to wipe")
                show: wipeArea.containsMouse || wipeBtn.holding
            }

            Text {
                visible: PillTheme.showGlyphs
                anchors.centerIn: parent
                text: PillTheme.glyph("clipboard")
                color: wipeBtn.tone
                font.family: PillTheme.fontJp
                font.pixelSize: 12 * root.s
                Behavior on color { ColorAnimation { duration: PillMotion.fast } }
            }

            GlyphIcon {
                visible: !PillTheme.showGlyphs
                anchors.centerIn: parent
                width: 12 * root.s
                height: 12 * root.s
                name: "trash"
                color: wipeBtn.tone
                Behavior on color { ColorAnimation { duration: PillMotion.fast } }
            }

            HeatHold {
                id: wipeHeat
                onConfirmed: Cliphist.wipe()
            }

            MouseArea {
                id: wipeArea
                anchors.fill: parent
                anchors.margins: -5 * root.s
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: wipeHeat.press()
                onReleased: wipeHeat.release()
                onExited: wipeHeat.cancel()
            }
        }
    }

    Rectangle {
        id: divider
        anchors.top: search.bottom
        anchors.topMargin: 8 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: PillTheme.hair

        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: parent.width * wipeBtn.hold
            visible: wipeBtn.holding
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.alpha(PillTheme.vermLit, 0.15) }
                GradientStop { position: 1.0; color: PillTheme.vermLit }
            }
        }
    }

    Text {
        anchors.centerIn: list
        visible: root.results.length === 0
        text: root.query.length ? Translation.tr("No matches") : Translation.tr("History empty")
        color: PillTheme.faint
        font.family: PillTheme.font
        font.pixelSize: 10.5 * root.s
    }

    ListView {
        id: list
        anchors.top: divider.bottom
        anchors.topMargin: 6 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 2 * root.s
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.results.length

        delegate: Item {
            id: row
            required property int index
            width: list.width
            height: (isImage ? 44 : 28) * root.s

            readonly property string entry: root.results[index] ?? ""
            readonly property bool isImage: Cliphist.entryIsImage(entry)
            readonly property bool selected: index === root.selectedIndex

            HoverHandler {
                id: rowHover
                onPointChanged: {
                    if (!hovered)
                        return;
                    var sp = point.scenePosition;
                    if (sp.x !== root.lastPointer.x || sp.y !== root.lastPointer.y) {
                        root.lastPointer = Qt.point(sp.x, sp.y);
                        root.selectedIndex = row.index;
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: 9 * root.s
                visible: row.selected || rowHover.hovered
                color: row.selected ? PillTheme.frameBg : Qt.alpha(PillTheme.cream, 0.03)
                border.width: row.selected ? 1 : 0
                border.color: PillTheme.frameBorder
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.selectedIndex = row.index;
                    root.activate();
                }
            }

            Item {
                anchors.fill: parent
                anchors.leftMargin: 11 * root.s
                anchors.rightMargin: 11 * root.s

                Rectangle {
                    id: thumbTile
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.isImage
                    width: visible ? 52 * root.s : 0
                    height: 32 * root.s
                    radius: 6 * root.s
                    color: PillTheme.tileBg
                    border.width: 1
                    border.color: PillTheme.border
                    clip: true

                    Loader {
                        anchors.fill: parent
                        anchors.margins: 1
                        active: row.isImage
                        sourceComponent: CliphistImage {
                            entry: row.entry
                            maxWidth: thumbTile.width - 2
                            maxHeight: thumbTile.height - 2
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: thumbTile.visible ? thumbTile.right : parent.left
                    anchors.leftMargin: thumbTile.visible ? 9 * root.s : 0
                    anchors.right: tail.left
                    anchors.rightMargin: 8 * root.s
                    text: root.entryPreview(row.entry)
                    color: row.isImage
                        ? (row.selected ? PillTheme.dim : PillTheme.faint)
                        : (row.selected ? PillTheme.cream : PillTheme.subtle)
                    font.family: PillTheme.font
                    font.pixelSize: 11.5 * root.s
                    font.weight: row.selected ? Font.DemiBold : Font.Medium
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    textFormat: Text.PlainText
                }

                Item {
                    id: tail
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(ret.implicitWidth, dismiss.implicitWidth)
                    height: Math.max(ret.implicitHeight, dismiss.implicitHeight)

                    Text {
                        id: ret
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: row.selected && !rowHover.hovered ? 1 : 0
                        text: "↵"
                        color: PillTheme.vermLit
                        font.family: PillTheme.font
                        font.pixelSize: 12 * root.s
                        Behavior on opacity { NumberAnimation { duration: PillMotion.fast } }
                    }

                    Text {
                        id: dismiss
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: rowHover.hovered ? 1 : 0
                        text: "✕"
                        color: dismissArea.containsMouse ? PillTheme.cream : PillTheme.dim
                        font.pixelSize: 10 * root.s
                        Behavior on opacity { NumberAnimation { duration: PillMotion.fast } }

                        MouseArea {
                            id: dismissArea
                            anchors.fill: parent
                            anchors.margins: -6 * root.s
                            enabled: rowHover.hovered
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.removeAt(row.index)
                        }
                    }
                }
            }
        }
    }
}
