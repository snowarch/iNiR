pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import "lib/fuzzy.js" as Fuzzy
import "lib/calc.js" as Calc

/**
 * Launcher surface: search field over a ranked application list, drawn as one
 * of the pill's surfaces. Desktop entries are ranked by fuzzy match and prior
 * launch frequency (stored under iNiR's state dir), the chosen entry executes
 * directly. Upstream's AppImage rename/remove editing rode a Ricelin-only
 * install script, so it is not carried over.
 */
PillSurface {
    id: root

    mTop: 15
    mLeft: 11
    mRight: 11
    mBottom: 12

    property string query: ""
    property int selectedIndex: 0
    property var usage: ({})

    /**
     * Calc mode: when the whole query parses as a real calculation (an
     * expression with at least one operation, so lone numbers and app names like
     * i3 or python3 fall through to app search), a result row appears above the
     * list and Enter copies the value. The parser in lib/calc.js never evals, so
     * a query cannot run code.
     */
    readonly property var calc: Calc.evaluate(query)
    readonly property bool calcActive: calc.ok
    property bool calcCopied: false
    onQueryChanged: calcCopied = false

    function copyResult() {
        if (!root.calcActive)
            return;
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "_", root.calc.display]);
        root.calcCopied = true;
    }

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
    amePoint: Qt.point(caretPoint.x, caretPoint.y)

    readonly property string usageFile: Directories.stateUserPath + "/pill-launcher-usage.json"

    readonly property var allEntries: {
        var src = DesktopEntries.applications.values;
        var out = [];
        for (var i = 0; i < src.length; i++)
            if (src[i] && !src[i].noDisplay) out.push(src[i]);
        return out;
    }
    readonly property int totalCount: allEntries.length
    readonly property var results: Fuzzy.rank(allEntries, query, usage)

    function focusField() { search.input.forceActiveFocus(); }

    function mapCategory(raw) {
        const order = [
            ["TerminalEmulator", "Terminal"], ["WebBrowser", "Browser"],
            ["InstantMessaging", "Chat"], ["Audio", "Media"], ["AudioVideo", "Media"],
            ["Video", "Media"], ["Game", "Game"], ["Development", "Dev"],
            ["Graphics", "Graphics"], ["Office", "Office"], ["Settings", "System"],
            ["System", "System"], ["Utility", "Tool"], ["Network", "Net"]
        ];
        const cats = String(raw).split(/[;,]/);
        for (let i = 0; i < order.length; i++)
            if (cats.includes(order[i][0]))
                return order[i][1];
        return "";
    }

    function move(delta) {
        if (results.length === 0)
            return;
        selectedIndex = Math.max(0, Math.min(results.length - 1, selectedIndex + delta));
        list.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function activate() {
        if (root.calcActive) {
            root.copyResult();
            return;
        }
        if (results.length === 0 || selectedIndex < 0 || selectedIndex >= results.length)
            return;
        var entry = results[selectedIndex];
        if (entry) {
            if (entry.id) {
                root.usage[entry.id] = (root.usage[entry.id] || 0) + 1;
                usageStore.setText(JSON.stringify(root.usage));
            }
            AppSearch.launchEntry(entry);
        }
        root.requestClose();
    }

    onActiveChanged: {
        if (active) {
            query = "";
            search.text = "";
            selectedIndex = 0;
            Qt.callLater(root.focusField);
        }
    }
    onResultsChanged: if (selectedIndex >= results.length) selectedIndex = 0

    FileView {
        id: usageStore
        path: root.usageFile
        blockLoading: true
        atomicWrites: true
        printErrors: false
    }

    Component.onCompleted: {
        var raw = usageStore.text();
        try {
            root.usage = raw && raw.length ? JSON.parse(raw) : ({});
        } catch (e) {
            root.usage = ({});
        }
    }

    SearchField {
        id: search
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        s: root.s
        kanji: PillTheme.glyph("launcher")
        placeholder: Translation.tr("Search apps")
        counterText: root.results.length + " / " + root.totalCount
        onTextChanged: {
            root.query = text;
            root.selectedIndex = 0;
        }
        onMoved: (d) => root.move(d)
        onAccepted: root.activate()
        onDismissed: root.requestClose()
    }

    Rectangle {
        id: divider
        anchors.top: search.bottom
        anchors.topMargin: 8 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: PillTheme.hair
    }

    Item {
        id: calcRow
        visible: root.calcActive
        anchors.top: divider.bottom
        anchors.topMargin: 6 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: visible ? 52 * root.s : 0

        Rectangle {
            anchors.fill: parent
            radius: 9 * root.s
            color: PillTheme.frameBg
            border.width: 1
            border.color: PillTheme.frameBorder
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.copyResult()
        }

        Item {
            anchors.fill: parent
            anchors.leftMargin: 12 * root.s
            anchors.rightMargin: 12 * root.s

            Column {
                anchors.left: parent.left
                anchors.right: copyHint.left
                anchors.rightMargin: 8 * root.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1 * root.s

                Text {
                    width: parent.width
                    text: "= " + root.calc.display
                    color: PillTheme.bright
                    font.family: PillTheme.font
                    font.pixelSize: 17 * root.s
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: root.query
                    color: PillTheme.faint
                    font.family: PillTheme.font
                    font.pixelSize: 11.5 * root.s
                    elide: Text.ElideRight
                }
            }

            Text {
                id: copyHint
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.calcCopied ? Translation.tr("copied") : "↵ " + Translation.tr("copy")
                color: root.calcCopied ? PillTheme.dim : PillTheme.vermLit
                font.family: PillTheme.font
                font.pixelSize: 12 * root.s
            }
        }
    }

    Text {
        anchors.centerIn: list
        visible: root.results.length === 0 && !root.calcActive
        text: root.query.length ? Translation.tr("No matches") : Translation.tr("No apps found")
        color: PillTheme.faint
        font.family: PillTheme.font
        font.pixelSize: 12 * root.s
    }

    ListView {
        id: list
        anchors.top: root.calcActive ? calcRow.bottom : divider.bottom
        anchors.topMargin: 6 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 5 * root.s
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.results.length

        delegate: Item {
            id: appRow
            required property int index
            width: list.width
            height: 48 * root.s

            readonly property var entry: root.results[index]
            readonly property bool selected: index === root.selectedIndex

            readonly property string secondary: {
                if (!entry)
                    return "";
                if (entry.genericName && entry.genericName.length > 0)
                    return entry.genericName;
                if (entry.categories && entry.categories.length > 0)
                    return root.mapCategory(entry.categories);
                return "";
            }

            Rectangle {
                anchors.fill: parent
                radius: 9 * root.s
                visible: appRow.selected || rowArea.containsMouse
                color: appRow.selected ? PillTheme.frameBg : Qt.alpha(PillTheme.cream, 0.03)
                border.width: appRow.selected ? 1 : 0
                border.color: PillTheme.frameBorder
            }

            MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: (m) => {
                    var g = rowArea.mapToItem(null, m.x, m.y);
                    if (g.x !== root.lastPointer.x || g.y !== root.lastPointer.y) {
                        root.lastPointer = Qt.point(g.x, g.y);
                        root.selectedIndex = appRow.index;
                    }
                }
                onClicked: {
                    root.selectedIndex = appRow.index;
                    root.activate();
                }
            }

            Item {
                anchors.fill: parent
                anchors.leftMargin: 11 * root.s
                anchors.rightMargin: 11 * root.s

                Rectangle {
                    id: iconBg
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28 * root.s
                    height: 28 * root.s
                    radius: 7 * root.s
                    color: Qt.alpha(PillTheme.cream, 0.05)
                    visible: !(icon.status === Image.Ready && icon.source != "")
                }
                Image {
                    id: icon
                    anchors.fill: iconBg
                    sourceSize.width: Math.round(40 * root.s)
                    sourceSize.height: Math.round(40 * root.s)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    visible: status === Image.Ready && source != ""
                    source: (appRow.entry && appRow.entry.icon)
                        ? Quickshell.iconPath(appRow.entry.icon, true) : ""
                }

                Text {
                    id: ret
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    text: "↵"
                    color: PillTheme.vermLit
                    font.family: PillTheme.font
                    font.pixelSize: 13 * root.s
                    visible: appRow.selected
                    width: visible ? 18 * root.s : 0
                    horizontalAlignment: Text.AlignRight
                }

                /**
                 * Name over description, each clipped on its own line. The block
                 * centres on the icon whether it shows one line or two, and an app
                 * with no description just reads as a centred name.
                 */
                Column {
                    anchors.left: iconBg.right
                    anchors.leftMargin: 10 * root.s
                    anchors.right: ret.left
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1 * root.s

                    Text {
                        width: parent.width
                        text: appRow.entry ? appRow.entry.name : ""
                        color: PillTheme.cream
                        font.family: PillTheme.font
                        font.pixelSize: 14 * root.s
                        font.weight: appRow.selected ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        visible: appRow.secondary.length > 0
                        text: appRow.secondary
                        color: appRow.selected ? PillTheme.dim : PillTheme.faint
                        font.family: PillTheme.font
                        font.pixelSize: 11.5 * root.s
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
