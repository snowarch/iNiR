pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import qs.modules.common
import qs.services

/**
 * Calendar surface: a weather glance, the month grid, and an event editor that
 * grows out to the right when a day is picked.
 *
 * The centre is the month grid (header with month/year and prev/next nav, weekday
 * row, day cells sized to exactly the rows the month needs). Today keeps its warm
 * frame and the Ame ring; a day that holds a stored event marks its number warm
 * with a small ember dot. To the left, when PillWeather.ready, a slim panel shows the
 * current temperature, the condition kanji and city, and the next few hours. To
 * the right, selecting a day slides open an editor listing that day's events with
 * a delete tap and an add form (start, end, title).
 *
 * The date math (offset/monthLen/rows/today/shiftMonth/resetToday) is unchanged;
 * the grid is wrapped, not rewritten. implicitWidth sums the visible panels so the
 * pill morphs wider as the editor opens; implicitHeight still drives the height
 * down to the live row count. View date resets to the real today on every open,
 * and Ame keeps targeting today via ameForm/amePoint.
 */
PillSurface {
    id: root

    mTop: 16
    mLeft: 18
    mRight: 18
    mBottom: 16

    readonly property var loc: Qt.locale("en_US")

    readonly property date today: sysClock.date
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()

    readonly property int offset: firstWeekdayOffset(viewYear, viewMonth)
    readonly property int monthLen: daysInMonth(viewYear, viewMonth)
    readonly property int rows: Math.ceil((offset + monthLen) / 7)

    readonly property real cellH: 34 * s
    readonly property real rowGap: 4 * s

    readonly property real gridW: 350 * s
    readonly property real weatherW: 196 * s
    readonly property real editorW: 238 * s
    readonly property real gutter: 22 * s

    readonly property bool weatherShown: PillWeather.ready
    readonly property bool editorShown: selectedDate.length > 0

    /**
     * Selection: selectedDate is the picked day (and a span's start), selEndDate
     * the span's last day or "" for a single day. pickingEnd arms the grid so the
     * next day click closes the span; hoverDay previews that span live while the
     * pointer moves. Keys are zero-padded "YYYY-MM-DD" so a string compare spans
     * them, even across months.
     */
    property string selectedDate: ""
    property string selEndDate: ""
    property bool pickingEnd: false
    property int hoverDay: 0

    /** Span end the grid paints: the live hover while arming, else the set end. */
    readonly property string rangeEndKey: pickingEnd && hoverDay > 0 ? dateKey(hoverDay) : selEndDate
    readonly property string rangeLo: {
        if (selectedDate.length === 0) return "";
        var b = rangeEndKey;
        if (b.length === 0) return selectedDate;
        return selectedDate < b ? selectedDate : b;
    }
    readonly property string rangeHi: {
        if (selectedDate.length === 0) return "";
        var b = rangeEndKey;
        if (b.length === 0) return selectedDate;
        return selectedDate < b ? b : selectedDate;
    }
    function inRange(key) {
        return key.length > 0 && rangeLo.length > 0 && key >= rangeLo && key <= rangeHi;
    }

    /** "ddd d MMM" for a single day, "d MMM" without the weekday. */
    function fmtDay(key, dow) {
        var p = key.split("-");
        var d = new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]));
        return loc.toString(d, dow ? "ddd d MMM" : "d MMM");
    }

    /** "22–25 Jun" within a month, "29 Jun – 2 Jul" across one. */
    function fmtSpan(loKey, hiKey) {
        var lp = loKey.split("-");
        var hp = hiKey.split("-");
        if (lp[0] === hp[0] && lp[1] === hp[1]) {
            var d = new Date(Number(lp[0]), Number(lp[1]) - 1, Number(lp[2]));
            return Number(lp[2]) + "–" + Number(hp[2]) + " " + loc.toString(d, "MMM");
        }
        return fmtDay(loKey, false) + " – " + fmtDay(hiKey, false);
    }

    readonly property real gridHeight: grid.y + rows * cellH + (rows - 1) * rowGap

    /** The weather panel and the editor each add their column plus a divider gutter only when visible. */
    implicitWidth: gridW
        + (weatherShown ? weatherW + gutter : 0)
        + (editorShown ? editorW + gutter : 0)

    implicitHeight: editorShown ? Math.max(gridHeight, edCol.implicitHeight) : gridHeight

    readonly property bool todayVisible: viewMonth === today.getMonth()
        && viewYear === today.getFullYear()

    /**
     * Ame is the focus cursor: it rings the picked day, or today when this month
     * is in view with nothing picked. Browsing another month with nothing picked
     * leaves no focus, so the bead parks as a soul ember on the 暦 header glyph
     * (the calendar's lantern, mirroring Sysmon) rather than floating over a
     * random date cell — which is what read as Ame jumping somewhere random.
     */
    readonly property bool selectedInView: selectedDate.length > 0
        && Number(selectedDate.split("-")[1]) === viewMonth + 1
        && Number(selectedDate.split("-")[0]) === viewYear
    readonly property int focusDay: selectedInView
        ? Number(selectedDate.split("-")[2])
        : (todayVisible ? today.getDate() : 0)
    readonly property bool focused: focusDay > 0
    readonly property int focusIndex: offset + focusDay - 1
    readonly property real cellW: grid.width / 7
    readonly property real focusX: gridPane.x + grid.x + (focusIndex % 7 + 0.5) * cellW
    readonly property real focusY: gridPane.y + grid.y + (Math.floor(focusIndex / 7) + 0.5) * (cellH + rowGap) - rowGap / 2

    readonly property point soulPoint: {
        void width;
        void height;
        if (PillTheme.showGlyphs)
            return calGlyph.mapToItem(root, calGlyph.width / 2, -3 * s);
        return monthLabel.mapToItem(root, -8 * s, monthLabel.height / 2);
    }

    ameForm: focused ? "ring" : "soul"
    amePoint: focused ? Qt.point(focusX, focusY) : soulPoint

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    function firstWeekdayOffset(year, month) {
        var d = new Date(year, month, 1).getDay();
        return (d + 6) % 7;
    }

    function daysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate();
    }

    function isToday(day) {
        return day === today.getDate()
            && viewMonth === today.getMonth()
            && viewYear === today.getFullYear();
    }

    /** "YYYY-MM-DD" for a day number in the viewed month, zero-padded for keys. */
    function dateKey(day) {
        var m = viewMonth + 1;
        var mm = m < 10 ? "0" + m : "" + m;
        var dd = day < 10 ? "0" + day : "" + day;
        return viewYear + "-" + mm + "-" + dd;
    }

    function shiftMonth(delta) {
        var m = viewMonth + delta;
        var y = viewYear;
        while (m < 0) { m += 12; y -= 1; }
        while (m > 11) { m -= 12; y += 1; }
        viewMonth = m;
        viewYear = y;
        hoverDay = 0;
        if (!pickingEnd) {
            selectedDate = "";
            selEndDate = "";
        }
    }

    function resetToday() {
        viewYear = today.getFullYear();
        viewMonth = today.getMonth();
        selectedDate = "";
        selEndDate = "";
        pickingEnd = false;
        hoverDay = 0;
    }

    /**
     * Click handling: while arming a span the next click sets its end (clicking
     * the start again drops the span); a click below the start swaps the two so
     * the earlier day stays the start. Otherwise it toggles a single day and
     * re-clicking the open day closes the editor.
     */
    function selectDay(day) {
        var key = dateKey(day);
        if (pickingEnd) {
            pickingEnd = false;
            hoverDay = 0;
            if (key === selectedDate)
                selEndDate = "";
            else if (key < selectedDate) {
                selEndDate = selectedDate;
                selectedDate = key;
            } else {
                selEndDate = key;
            }
            return;
        }
        if (selectedDate === key && selEndDate.length === 0) {
            selectedDate = "";
            return;
        }
        selectedDate = key;
        selEndDate = "";
    }

    onActiveChanged: if (active) resetToday()

    Item {
        id: weather
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.weatherShown ? root.weatherW : 0
        clip: true
        visible: width > 1
        opacity: root.weatherShown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: PillMotion.standard; easing.type: PillMotion.easeStandard } }

        Column {
            id: wxCol
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 20 * root.s
            spacing: 11 * root.s

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 9 * root.s

                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32 * root.s
                    height: 32 * root.s
                    name: PillWeather.glyphFor(PillWeather.codeNow, PillWeather.isDay)
                    color: PillTheme.todayWarm
                    stroke: 1.9
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    Text {
                        text: PillWeather.tempNow + "°"
                        color: PillTheme.cream
                        font.family: PillTheme.font
                        font.pixelSize: 30 * root.s
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }
                    Text {
                        text: PillWeather.labelFor(PillWeather.codeNow)
                        color: PillTheme.subtle
                        font.family: PillTheme.font
                        font.pixelSize: 11.5 * root.s
                        font.weight: Font.Medium
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 8 * root.s

                /**
                 * IP geolocation only ever resolves to the ISP city, so the town
                 * is editable in place: tap to type, which sets bar.weather.city
                 * and re-geocodes through Open-Meteo for the exact spot. Blank it
                 * to fall back to auto IP detection.
                 */
                Item {
                    id: cityBox
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - humidityRow.width - 8 * root.s
                    height: 24 * root.s

                    property bool editing: false

                    Text {
                        id: cityText
                        visible: !cityBox.editing
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: PillWeather.city.length > 0 ? PillWeather.city : "set town"
                        color: cityArea.containsMouse ? PillTheme.subtle : PillTheme.dim
                        font.family: PillTheme.font
                        font.pixelSize: 10.5 * root.s
                        font.weight: Font.Medium
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 0.8 * root.s
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: cityArea
                        visible: !cityBox.editing
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            cityField.text = PillWeather.configCity;
                            cityBox.editing = true;
                            cityField.forceActiveFocus();
                            cityField.selectAll();
                        }
                    }
                    TextField {
                        id: cityField
                        visible: cityBox.editing
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        background: null
                        padding: 0
                        verticalAlignment: TextInput.AlignVCenter
                        color: PillTheme.cream
                        font.family: PillTheme.font
                        font.pixelSize: 10.5 * root.s
                        font.weight: Font.Medium
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 0.8 * root.s
                        placeholderText: "town"
                        placeholderTextColor: PillTheme.faint
                        selectByMouse: true
                        selectionColor: PillTheme.verm
                        onAccepted: {
                            PillWeather.setCity(text);
                            cityBox.editing = false;
                        }
                        Keys.onEscapePressed: cityBox.editing = false
                        onActiveFocusChanged: if (!activeFocus) cityBox.editing = false
                    }
                }
                Row {
                    id: humidityRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3 * root.s

                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 13 * root.s
                        height: 13 * root.s
                        name: "droplet"
                        color: PillTheme.faint
                        stroke: 1.6
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: PillWeather.humidity + "%"
                        color: PillTheme.faint
                        font.family: PillTheme.font
                        font.pixelSize: 10.5 * root.s
                        font.weight: Font.Medium
                        font.features: { "tnum": 1 }
                    }
                }
            }

            Rectangle {
                width: wxCol.width
                height: 1
                color: PillTheme.hairSoft
            }

            Row {
                width: wxCol.width

                Repeater {
                    model: PillWeather.daily.slice(0, 4)

                    Column {
                        id: dayCol
                        required property var modelData
                        width: wxCol.width / 4
                        spacing: 5 * root.s

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: dayCol.modelData.day
                            color: PillTheme.faint
                            font.family: PillTheme.font
                            font.pixelSize: 10.5 * root.s
                            font.weight: Font.DemiBold
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 0.5 * root.s
                        }
                        GlyphIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 18 * root.s
                            height: 18 * root.s
                            name: PillWeather.glyphFor(dayCol.modelData.code, true)
                            color: PillTheme.subtle
                            stroke: 1.7
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: dayCol.modelData.temp + "°"
                            color: PillTheme.cream
                            font.family: PillTheme.font
                            font.pixelSize: 12.5 * root.s
                            font.weight: Font.Medium
                            font.features: { "tnum": 1 }
                        }
                        /**
                         * Upstream showed per-day humidity. iNiR's forecast carries
                         * the day's low instead — humidity is only known for right
                         * now — so the strip shows the low rather than a blank or an
                         * invented number.
                         */
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 2 * root.s
                            visible: dayCol.modelData.lo !== undefined

                            GlyphIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 9 * root.s
                                height: 9 * root.s
                                name: "arrow-up"
                                rotation: 180
                                color: PillTheme.faint
                                stroke: 1.6
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: dayCol.modelData.lo + "°"
                                color: PillTheme.faint
                                font.family: PillTheme.font
                                font.pixelSize: 10.5 * root.s
                                font.weight: Font.Medium
                                font.features: { "tnum": 1 }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: weatherSeam
        anchors.left: weather.right
        anchors.leftMargin: root.gutter / 2
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: PillTheme.hair
        visible: root.weatherShown
        opacity: weather.opacity
    }

    Item {
        id: gridPane
        anchors.left: root.weatherShown ? weather.right : parent.left
        anchors.leftMargin: root.weatherShown ? root.gutter : 0
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.gridW

        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 24 * root.s

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.s

                Text {
                    id: calGlyph
                    anchors.verticalCenter: parent.verticalCenter
                    visible: PillTheme.showGlyphs
                    text: PillTheme.glyph("calendar")
                    color: PillTheme.cream
                    font.family: PillTheme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: 16 * root.s
                }
                Text {
                    id: monthLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.loc.standaloneMonthName(root.viewMonth, Locale.LongFormat)
                        + " " + root.viewYear
                    color: PillTheme.subtle
                    font.family: PillTheme.font
                    font.pixelSize: 13 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.0 * root.s
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2 * root.s

                Repeater {
                    model: [-1, 1]

                    Rectangle {
                        id: nav
                        required property int modelData
                        width: 28 * root.s
                        height: 28 * root.s
                        radius: PillMotion.rSmall * root.s
                        color: navArea.containsMouse ? PillTheme.frameBg : "transparent"
                        border.width: navArea.containsMouse ? 1 : 0
                        border.color: PillTheme.frameBorder

                        GlyphIcon {
                            anchors.centerIn: parent
                            width: 16 * root.s
                            height: 16 * root.s
                            name: nav.modelData < 0 ? "chevron-left" : "chevron-right"
                            color: navArea.containsMouse ? PillTheme.cream : PillTheme.iconDim
                            stroke: 1.8
                        }

                        MouseArea {
                            id: navArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.shiftMonth(nav.modelData)
                        }
                    }
                }
            }
        }

        Rectangle {
            id: divider
            anchors.top: header.bottom
            anchors.topMargin: 9 * root.s
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: PillTheme.hair
        }

        Row {
            id: weekdays
            anchors.top: divider.bottom
            anchors.topMargin: 8 * root.s
            anchors.left: parent.left
            anchors.right: parent.right

            Repeater {
                model: 7

                Item {
                    id: wd
                    required property int index
                    readonly property bool weekend: index >= 5
                    width: weekdays.width / 7
                    height: 16 * root.s

                    Text {
                        anchors.centerIn: parent
                        text: root.loc.standaloneDayName((wd.index + 1) % 7, Locale.NarrowFormat)
                        color: wd.weekend ? PillTheme.faint : PillTheme.dim
                        font.family: PillTheme.font
                        font.pixelSize: 10.5 * root.s
                        font.weight: Font.Medium
                        font.letterSpacing: 0.5 * root.s
                    }
                }
            }
        }

        Grid {
            id: grid
            y: weekdays.y + weekdays.height + 4 * root.s
            anchors.left: parent.left
            anchors.right: parent.right
            columns: 7
            rowSpacing: root.rowGap
            columnSpacing: 0

            Repeater {
                model: root.rows * 7

                Item {
                    id: cell
                    required property int index
                    readonly property int weekday: index % 7
                    readonly property bool weekend: weekday >= 5
                    width: grid.width / 7
                    height: root.cellH

                    readonly property int dayNum: index - root.offset + 1
                    readonly property bool inMonth: dayNum >= 1 && dayNum <= root.monthLen
                    readonly property bool current: inMonth && root.isToday(dayNum)
                    readonly property string dayKey: inMonth ? root.dateKey(dayNum) : ""
                    readonly property bool hasEvent: inMonth && PillEvents.hasEvents(cell.dayKey)
                    readonly property bool sel: inMonth && root.inRange(cell.dayKey)
                    readonly property bool selEdge: cell.sel
                        && (cell.dayKey === root.rangeLo || cell.dayKey === root.rangeHi)
                    readonly property int ghostNum: dayNum < 1
                        ? root.daysInMonth(root.viewYear, root.viewMonth - 1) + dayNum
                        : dayNum - root.monthLen

                    Rectangle {
                        anchors.centerIn: parent
                        width: 28 * root.s
                        height: 28 * root.s
                        radius: PillMotion.rSmall * root.s
                        color: cellArea.containsMouse && cell.inMonth && !cell.current
                            ? PillTheme.frameBg : "transparent"
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 28 * root.s
                        height: 28 * root.s
                        radius: PillMotion.rSmall * root.s
                        visible: cell.current || cell.sel
                        color: cell.sel && !cell.current ? Qt.alpha(PillTheme.vermLit, 0.12) : PillTheme.frameBg
                        border.width: 1
                        border.color: cell.selEdge ? Qt.alpha(PillTheme.vermLit, 0.55)
                            : (cell.sel ? Qt.alpha(PillTheme.vermLit, 0.22) : PillTheme.frameBorder)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: cell.inMonth ? cell.dayNum : cell.ghostNum
                        color: cell.inMonth
                            ? (cell.current ? PillTheme.todayWarm
                                : (cell.hasEvent ? PillTheme.flameGlow
                                    : (cell.weekend ? PillTheme.subtle : PillTheme.cream)))
                            : PillTheme.ghost
                        opacity: cell.inMonth && !cell.current && !cell.weekend && !cell.hasEvent ? 0.85 : 1.0
                        font.family: PillTheme.font
                        font.pixelSize: 13 * root.s
                        font.weight: cell.current || cell.hasEvent ? Font.DemiBold : Font.Normal
                        font.features: { "tnum": 1 }
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.verticalCenter
                        anchors.topMargin: 9 * root.s
                        visible: cell.hasEvent && !cell.current
                        width: 3 * root.s
                        height: 3 * root.s
                        radius: width / 2
                        color: PillTheme.flameGlow
                    }

                    MouseArea {
                        id: cellArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: cell.inMonth
                        cursorShape: cell.inMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: if (cell.inMonth) root.selectDay(cell.dayNum)
                        onContainsMouseChanged: if (root.pickingEnd && cell.inMonth && containsMouse)
                            root.hoverDay = cell.dayNum
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: grid.horizontalCenter
            anchors.top: grid.bottom
            anchors.topMargin: 6 * root.s
            visible: root.pickingEnd
            text: Translation.tr("click the end day")
            color: PillTheme.flameGlow
            font.family: PillTheme.font
            font.pixelSize: 10.5 * root.s
            font.weight: Font.DemiBold
            font.letterSpacing: 0.4 * root.s
        }

        MouseArea {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: grid.bottom
            anchors.bottom: parent.bottom
            enabled: root.editorShown && !root.pickingEnd
            onClicked: {
                root.selectedDate = "";
                root.selEndDate = "";
                root.pickingEnd = false;
            }
        }
    }

    Rectangle {
        id: editorSeam
        anchors.left: gridPane.right
        anchors.leftMargin: root.gutter / 2
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: PillTheme.hair
        visible: root.editorShown
        opacity: editor.opacity
    }

    Item {
        id: editor
        anchors.left: gridPane.right
        anchors.leftMargin: root.gutter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.editorShown ? root.editorW : 0
        clip: true
        visible: width > 1
        opacity: root.editorShown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: PillMotion.standard; easing.type: PillMotion.easeStandard } }

        /** Events covering the picked day (a span's start), empty until a day is picked. */
        readonly property var dayEvents: root.selectedDate.length > 0
            ? PillEvents.forDate(root.selectedDate) : []

        /** Single day reads "Mon 9 Jun"; a span reads its range. */
        readonly property string heading: {
            if (root.selectedDate.length === 0)
                return "";
            if (root.selEndDate.length === 0)
                return root.fmtDay(root.selectedDate, true);
            return root.fmtSpan(root.rangeLo, root.rangeHi);
        }

        readonly property string spanLabel: root.selEndDate.length === 0
            ? root.fmtDay(root.selectedDate, false)
            : root.fmtSpan(root.rangeLo, root.rangeHi)

        /** "allday" (default) hides the time fields; "timed" reveals start/end. */
        property string mode: "allday"
        property string startVal: ""
        property string endVal: ""
        property string titleVal: ""

        /**
         * recur is "" / "month" / "year". It suggests yearly by itself once the
         * title reads like a birthday and then stays as the user left it after they
         * work the Repeat toggle by hand (recurManual).
         */
        property string recur: ""
        property bool recurManual: false

        /** Suggest yearly for a birthday title, unless the user already chose. */
        function autoRecur() {
            if (!recurManual)
                recur = PillEvents.isBirthday(titleVal) ? "year" : "";
        }

        function clearForm() {
            startVal = "";
            endVal = "";
            titleVal = "";
            recur = "";
            recurManual = false;
            startField.text = "";
            endField.text = "";
            titleField.text = "";
        }

        /** A time is kept only when it reads as HH:MM, otherwise it drops to an all-day blank. */
        function cleanTime(t) {
            var v = t.trim();
            return /^\d{1,2}:\d{2}$/.test(v) ? v : "";
        }

        /** Add the form's event when a title is set, then reset the inputs. */
        function commit() {
            if (titleVal.trim().length === 0)
                return;
            var t = editor.mode === "timed" ? editor.cleanTime(startVal) : "";
            var e = editor.mode === "timed" ? editor.cleanTime(endVal) : "";
            PillEvents.add(root.selectedDate, editor.recur !== "" ? "" : root.selEndDate,
                       t, e, titleVal.trim(), editor.recur);
            clearForm();
            titleField.forceActiveFocus();
        }

        onWidthChanged: if (width < 1) { clearForm(); mode = "allday"; }

        Column {
            id: edCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 8 * root.s

            Text {
                width: parent.width
                text: editor.heading
                color: PillTheme.cream
                font.family: PillTheme.font
                font.pixelSize: 12 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 0.8 * root.s
                elide: Text.ElideRight
            }

            Rectangle {
                width: parent.width
                height: 1
                color: PillTheme.hair
            }

            /** Capped so a day stacked with events scrolls instead of growing the surface. */
            Item {
                width: parent.width
                height: edFlick.height

                Flickable {
                    id: edFlick
                    width: parent.width
                    height: Math.min(edList.implicitHeight, 230 * root.s)
                    contentHeight: edList.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    onContentHeightChanged: returnToBounds()

                    Column {
                        id: edList
                        width: edFlick.width
                        spacing: 4 * root.s

                        Text {
                            visible: editor.dayEvents.length === 0
                            text: Translation.tr("Nothing yet")
                            color: PillTheme.faint
                            font.family: PillTheme.font
                            font.pixelSize: 11 * root.s
                            font.weight: Font.Medium
                            font.italic: true
                        }

                        Repeater {
                            model: editor.dayEvents

                            Rectangle {
                                id: evRow
                                required property var modelData
                                width: edList.width
                                height: evBody.implicitHeight + 12 * root.s
                                radius: PillMotion.rSmall * root.s
                                color: evArea.hovered ? PillTheme.frameBg : "transparent"

                                /** "all day" or "09:00–10:00", a date span when multi-day, "every year" when recurring. */
                                readonly property string meta: {
                                    var datePart = "";
                                    if (evRow.modelData.endDate && evRow.modelData.endDate.length > 0)
                                        datePart = root.fmtSpan(evRow.modelData.date, evRow.modelData.endDate);
                                    var t = evRow.modelData.time || "";
                                    var e = evRow.modelData.endTime || "";
                                    var timePart = t.length === 0 ? "all day"
                                        : (e.length > 0 ? t + "–" + e : t);
                                    var base = datePart.length > 0 ? datePart + " · " + timePart : timePart;
                                    var r = evRow.modelData.recur;
                                    if (r === "year") return "every year · " + base;
                                    if (r === "month") return "every month · " + base;
                                    return base;
                                }

                                HoverHandler { id: evArea }

                                Column {
                                    id: evBody
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8 * root.s
                                    anchors.right: evDel.left
                                    anchors.rightMargin: 6 * root.s
                                    anchors.top: parent.top
                                    anchors.topMargin: 6 * root.s
                                    spacing: 2 * root.s

                                    Text {
                                        text: evRow.modelData.text
                                        width: parent.width
                                        color: PillTheme.cream
                                        font.family: PillTheme.font
                                        font.pixelSize: 11 * root.s
                                        font.weight: Font.Medium
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 4
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: evRow.meta
                                        width: parent.width
                                        color: PillTheme.flameGlow
                                        font.family: PillTheme.font
                                        font.pixelSize: 10 * root.s
                                        font.weight: Font.DemiBold
                                        font.features: { "tnum": 1 }
                                        wrapMode: Text.Wrap
                                        elide: Text.ElideRight
                                    }
                                }

                                Item {
                                    id: evDel
                                    anchors.right: parent.right
                                    anchors.rightMargin: 7 * root.s
                                    anchors.top: parent.top
                                    anchors.topMargin: 7 * root.s
                                    width: 16 * root.s
                                    height: 16 * root.s
                                    opacity: evArea.hovered ? 1 : 0.32
                                    Behavior on opacity { NumberAnimation { duration: PillMotion.fast } }

                                    GlyphIcon {
                                        anchors.fill: parent
                                        name: "close"
                                        color: delArea.containsMouse ? PillTheme.vermLit : PillTheme.iconDim
                                        stroke: 1.6
                                    }

                                    MouseArea {
                                        id: delArea
                                        anchors.fill: parent
                                        anchors.margins: -5 * root.s
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: PillEvents.remove(evRow.modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }

                WheelScroller {
                    anchors.fill: parent
                    s: root.s
                    flick: edFlick
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: PillTheme.hair
            }

            Row {
                width: parent.width
                spacing: 8 * root.s

                Item {
                    width: parent.width - addBtn.width - 8 * root.s
                    height: 28 * root.s

                    TextField {
                        id: titleField
                        anchors.fill: parent
                        background: null
                        padding: 0
                        leftPadding: 2 * root.s
                        verticalAlignment: TextInput.AlignVCenter
                        color: PillTheme.cream
                        font.family: PillTheme.font
                        font.pixelSize: 13 * root.s
                        placeholderText: Translation.tr("what's on")
                        placeholderTextColor: PillTheme.faint
                        selectByMouse: true
                        selectionColor: PillTheme.verm
                        onTextChanged: { editor.titleVal = text; editor.autoRecur(); }
                        Keys.onReturnPressed: editor.commit()
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: PillTheme.faint
                        opacity: titleField.activeFocus ? 0.7 : 0.2
                        Behavior on opacity { NumberAnimation { duration: PillMotion.standard; easing.type: PillMotion.easeStandard } }
                    }
                }

                Rectangle {
                    id: addBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28 * root.s
                    height: 28 * root.s
                    radius: PillMotion.rSmall * root.s
                    readonly property bool armed: editor.titleVal.trim().length > 0
                    color: addArea.containsMouse && armed ? Qt.alpha(PillTheme.vermLit, 0.22)
                        : (armed ? Qt.alpha(PillTheme.vermLit, 0.12) : PillTheme.frameBg)
                    border.width: 1
                    border.color: armed ? Qt.alpha(PillTheme.vermLit, 0.5) : PillTheme.frameBorder
                    Behavior on color { ColorAnimation { duration: PillMotion.fast } }

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: addBtn.armed ? PillTheme.vermLit : PillTheme.iconDim
                        font.family: PillTheme.font
                        font.pixelSize: 18 * root.s
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: addArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: editor.commit()
                    }
                }
            }

            SettingsSeg {
                s: root.s
                options: [
                    { label: "All day", value: "allday" },
                    { label: "Timed", value: "timed" }
                ]
                value: editor.mode
                onPicked: (v) => editor.mode = v
            }

            Row {
                width: parent.width
                spacing: 8 * root.s
                visible: editor.mode === "timed"

                Item {
                    width: (parent.width - 8 * root.s) / 2
                    height: 26 * root.s

                    TextField {
                        id: startField
                        anchors.fill: parent
                        background: null
                        padding: 0
                        leftPadding: 2 * root.s
                        verticalAlignment: TextInput.AlignVCenter
                        color: PillTheme.cream
                        font.family: PillTheme.font
                        font.pixelSize: 13 * root.s
                        font.features: { "tnum": 1 }
                        placeholderText: "09:00"
                        placeholderTextColor: PillTheme.faint
                        inputMethodHints: Qt.ImhPreferNumbers
                        selectByMouse: true
                        selectionColor: PillTheme.verm
                        onTextChanged: editor.startVal = text
                        Keys.onReturnPressed: editor.commit()
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: PillTheme.faint
                        opacity: startField.activeFocus ? 0.7 : 0.2
                        Behavior on opacity { NumberAnimation { duration: PillMotion.standard; easing.type: PillMotion.easeStandard } }
                    }
                }

                Item {
                    width: (parent.width - 8 * root.s) / 2
                    height: 26 * root.s

                    TextField {
                        id: endField
                        anchors.fill: parent
                        background: null
                        padding: 0
                        leftPadding: 2 * root.s
                        verticalAlignment: TextInput.AlignVCenter
                        color: PillTheme.cream
                        font.family: PillTheme.font
                        font.pixelSize: 13 * root.s
                        font.features: { "tnum": 1 }
                        placeholderText: "until"
                        placeholderTextColor: PillTheme.faint
                        inputMethodHints: Qt.ImhPreferNumbers
                        selectByMouse: true
                        selectionColor: PillTheme.verm
                        onTextChanged: editor.endVal = text
                        Keys.onReturnPressed: editor.commit()
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: PillTheme.faint
                        opacity: endField.activeFocus ? 0.7 : 0.2
                        Behavior on opacity { NumberAnimation { duration: PillMotion.standard; easing.type: PillMotion.easeStandard } }
                    }
                }
            }

            SettingsSeg {
                s: root.s
                options: [
                    { label: "Once", value: "" },
                    { label: "Monthly", value: "month" },
                    { label: "Yearly", value: "year" }
                ]
                value: editor.recur
                onPicked: (v) => {
                    editor.recurManual = true;
                    editor.recur = v;
                    if (v !== "") {
                        root.selEndDate = "";
                        root.pickingEnd = false;
                    }
                }
            }

            /**
             * Span control: the chip shows the day or range, the button arms the
             * grid so the next day click closes a span (the under-grid hint and
             * range tint guide it), and ✕ drops a set span back to a single day.
             * Hidden for a recurring entry, which is a single repeating day.
             */
            Row {
                width: parent.width
                spacing: 8 * root.s
                visible: editor.recur === ""

                Rectangle {
                    id: spanChip
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - extendBtn.width - clearSpan.width - 16 * root.s
                    height: 28 * root.s
                    radius: PillMotion.rSmall * root.s
                    color: PillTheme.frameBg
                    border.width: 1
                    border.color: PillTheme.frameBorder

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 9 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 7 * root.s

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 9 * root.s
                            height: 9 * root.s
                            radius: 3 * root.s
                            color: PillTheme.flameGlow
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: editor.spanLabel
                            color: root.selEndDate.length > 0 ? PillTheme.cream : PillTheme.subtle
                            font.family: PillTheme.font
                            font.pixelSize: 11 * root.s
                            font.weight: Font.Medium
                            font.features: { "tnum": 1 }
                        }
                    }
                }

                Rectangle {
                    id: extendBtn
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property bool armed: root.pickingEnd
                    width: extendLabel.implicitWidth + 18 * root.s
                    height: 28 * root.s
                    radius: PillMotion.rSmall * root.s
                    color: armed ? Qt.alpha(PillTheme.vermLit, 0.14) : PillTheme.frameBg
                    border.width: 1
                    border.color: armed ? Qt.alpha(PillTheme.vermLit, 0.5) : PillTheme.frameBorder
                    Behavior on color { ColorAnimation { duration: PillMotion.fast } }

                    Text {
                        id: extendLabel
                        anchors.centerIn: parent
                        text: root.pickingEnd ? "pick…" : (root.selEndDate.length > 0 ? "edit" : "+ days")
                        color: extendBtn.armed ? PillTheme.vermLit : PillTheme.dim
                        font.family: PillTheme.font
                        font.pixelSize: 10.5 * root.s
                        font.weight: Font.Bold
                        font.letterSpacing: 0.3 * root.s
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.pickingEnd) {
                                root.pickingEnd = false;
                                root.hoverDay = 0;
                            } else {
                                root.selEndDate = "";
                                root.pickingEnd = true;
                            }
                        }
                    }
                }

                Item {
                    id: clearSpan
                    anchors.verticalCenter: parent.verticalCenter
                    width: visible ? 16 * root.s : 0
                    height: 16 * root.s
                    visible: root.selEndDate.length > 0 && !root.pickingEnd

                    GlyphIcon {
                        anchors.fill: parent
                        name: "close"
                        color: clearArea.containsMouse ? PillTheme.vermLit : PillTheme.iconDim
                        stroke: 1.6
                    }
                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        anchors.margins: -5 * root.s
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selEndDate = ""
                    }
                }
            }
        }
    }
}
