pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property string text: ""
    property string fontFamily: "serif"
    property real fontPixelSize: 48
    property int fontWeight: Font.Normal
    property real letterSpacing: 0
    property real columnGap: 10
    property int maxColumns: 4
    property bool rotateLatin: false
    property color color: Appearance.colors.colOnLayer0
    property int textStyle: Text.Normal
    property color styleColor: "transparent"

    readonly property real cellSize: Math.max(1, Math.round(root.fontPixelSize * 1.08))
    readonly property real cellAdvance: Math.max(root.cellSize, Math.round(root.cellSize + root.letterSpacing))
    readonly property int rowsPerColumn: Math.max(1, Math.floor(root.height / root.cellAdvance))
    readonly property int columnsByWidth: Math.max(1, Math.floor((root.width + root.columnGap) / (root.cellSize + root.columnGap)))
    readonly property int visibleColumnLimit: Math.max(1, Math.min(root.maxColumns, root.columnsByWidth))
    readonly property var columns: root._buildColumns()
    readonly property bool overflowed: root._allColumnCount() > root.visibleColumnLimit

    clip: true

    function _characters(value: string): var {
        const points = Array.from(String(value ?? "").replace(/\r/g, ""));
        let graphemes = [];
        for (let i = 0; i < points.length; i++) {
            const point = points[i];
            const code = point.codePointAt(0);
            const joinsPrevious = graphemes.length > 0 && (
                point === "\u200D" || graphemes[graphemes.length - 1].endsWith("\u200D")
                || code === 0xFE0E || code === 0xFE0F
                || (code >= 0x0300 && code <= 0x036F)
                || code === 0x3099 || code === 0x309A
                || (code >= 0x1F3FB && code <= 0x1F3FF)
            );
            if (joinsPrevious)
                graphemes[graphemes.length - 1] += point;
            else
                graphemes.push(point);
        }
        return graphemes;
    }

    function _allColumns(): var {
        const lines = String(root.text ?? "").replace(/\r/g, "").split("\n");
        const rows = root.rowsPerColumn;
        let result = [];

        for (let lineIndex = 0; lineIndex < lines.length; lineIndex++) {
            const chars = root._characters(lines[lineIndex]);
            if (chars.length === 0) {
                if (lines.length > 1)
                    result.push([]);
                continue;
            }
            for (let offset = 0; offset < chars.length; offset += rows)
                result.push(chars.slice(offset, offset + rows));
        }
        return result;
    }

    function _allColumnCount(): int {
        return root._allColumns().length;
    }

    function _buildColumns(): var {
        return root._allColumns().slice(0, root.visibleColumnLimit);
    }

    function _isCornerPunctuation(glyph: string): bool {
        return "、。，．・：；！？゛゜ヽヾ々〻".indexOf(glyph) >= 0;
    }

    function _isLatinGlyph(glyph: string): bool {
        return /^[A-Za-z0-9@#%&+_=:\/.\-]$/.test(glyph);
    }

    function _rotatesInVertical(glyph: string): bool {
        if ("ー―—…‥〜～（）〔〕［］｛｝〈〉《》「」『』【】".indexOf(glyph) >= 0)
            return true;
        return root.rotateLatin && root._isLatinGlyph(glyph);
    }

    Row {
        id: columnsRow
        anchors {
            top: parent.top
            right: parent.right
        }
        spacing: root.columnGap
        layoutDirection: Qt.RightToLeft

        Repeater {
            model: root.columns

            delegate: Column {
                required property var modelData
                width: root.cellSize
                spacing: 0

                Repeater {
                    model: parent.modelData

                    delegate: Item {
                        required property string modelData
                        width: root.cellSize
                        height: root.cellAdvance
                        clip: true

                        StyledText {
                            anchors.fill: parent
                            text: parent.modelData
                            color: root.color
                            style: root.textStyle
                            styleColor: root.styleColor
                            maximumLineCount: 1
                            wrapMode: Text.NoWrap
                            horizontalAlignment: root._isCornerPunctuation(text) ? Text.AlignRight : Text.AlignHCenter
                            verticalAlignment: root._isCornerPunctuation(text) ? Text.AlignTop : Text.AlignVCenter
                            rotation: root._rotatesInVertical(text) ? 90 : 0
                            font {
                                family: root.fontFamily
                                pixelSize: root._isCornerPunctuation(text)
                                    ? Math.max(1, Math.round(root.fontPixelSize * 0.68))
                                    : root.fontPixelSize
                                weight: root.fontWeight
                            }
                        }
                    }
                }
            }
        }
    }
}
