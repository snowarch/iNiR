pragma ComponentBehavior: Bound

import qs.modules.common
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * iOS-style time picker: an hour column, a minute column and — in 12-hour mode
 * only — a two-state AM/PM selector (the spec). One `WheelColumn` definition is
 * instantiated three times; nothing about a column knows which unit it shows.
 *
 * Built on `Tumbler`, which already gives momentum, smooth deceleration, an
 * animated snap and continuous wrap. Writing that flick physics by hand would
 * be a worse copy of what QtQuick.Controls ships.
 *
 * `hour` (0-23) and `minute` (0-59) are the STORED time and are format
 * independent — `time.format` only decides which columns are shown and how the
 * labels read. Switching format can never move an alarm, because the format
 * never touches these two properties.
 */
Item {
    id: root

    property int hour: 0
    property int minute: 0

    // Follows the shell's one existing time preference (Config: time.format,
    // "hh:mm" / "h:mm ap" / "h:mm AP"). No alarm-specific format key.
    readonly property string timeFormat: Config.options?.time?.format ?? "hh:mm"
    readonly property bool use12Hour: /a/i.test(root.timeFormat)
    readonly property bool pm: root.hour >= 12

    // The entire 12/24-hour boundary lives in these four functions and nowhere
    // else. scripts/alarm-timewheel-check.js extracts them straight out of this
    // file and asserts against them, so the check cannot drift from the picker.
    function to12(h: int): var {
        return {
            h12: ((h + 11) % 12) + 1,
            pm: h >= 12
        };
    }
    function from12(h12: int, isPm: bool): int {
        return (h12 % 12) + (isPm ? 12 : 0);
    }
    // The 12-hour column reads 12, 1, 2 … 11, so row 0 is the twelve.
    function hourIndex(h: int): int {
        return h % 12;
    }
    function hourFromIndex(index: int, isPm: bool): int {
        return root.from12(index === 0 ? 12 : index, isPm);
    }

    // Style tokens
    readonly property color colText: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
    readonly property color colPrimary: Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
    readonly property color colBand: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer2
    readonly property real bandRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small

    readonly property int rowHeight: Math.round(Appearance.font.pixelSize.huge * 1.7)
    readonly property int visibleRows: 5

    // "AM"/"PM" for "h:mm AP", "am"/"pm" for "h:mm ap" — same distinction the
    // rest of the shell already draws from that one key.
    readonly property bool upperMeridiem: root.timeFormat.indexOf("AP") !== -1
    readonly property string amText: root.upperMeridiem ? Qt.locale().amText.toUpperCase() : Qt.locale().amText.toLowerCase()
    readonly property string pmText: root.upperMeridiem ? Qt.locale().pmText.toUpperCase() : Qt.locale().pmText.toLowerCase()

    readonly property var hourLabels24: Array.from({
        length: 24
    }, (ignored, i) => String(i).padStart(2, "0"))
    readonly property var hourLabels12: Array.from({
        length: 12
    }, (ignored, i) => String(i === 0 ? 12 : i))
    readonly property var minuteLabels: Array.from({
        length: 60
    }, (ignored, i) => String(i).padStart(2, "0"))

    // True while the columns are being positioned from hour/minute, so the
    // write-back below cannot fight the value it is being handed.
    property bool syncing: false

    function sync(): void {
        root.syncing = true;
        hourColumn24.currentIndex = root.hour;
        hourColumn12.currentIndex = root.hourIndex(root.hour);
        minuteColumn.currentIndex = root.minute;
        root.syncing = false;
    }

    // Editing an existing alarm opens on that alarm's time, and a format change
    // re-seats the newly visible column on the same stored time.
    Component.onCompleted: root.sync()
    onHourChanged: root.sync()
    onMinuteChanged: root.sync()
    onUse12HourChanged: root.sync()

    implicitWidth: columns.implicitWidth
    implicitHeight: root.rowHeight * root.visibleRows

    // Up/Down previously only worked once Tab had explicitly reached a
    // column — a keyboard user had to Tab through the row before the arrow
    // keys did anything. These are window-level shortcuts (not per-column
    // Keys handlers) precisely so they fire with no column focused yet;
    // they grab focus for whichever column is active (or the first one)
    // and step it in the same keypress.
    readonly property var wheelColumns: root.use12Hour ? [hourColumn12, minuteColumn] : [hourColumn24, minuteColumn]

    function stepFocusedColumn(delta: int): void {
        const target = root.wheelColumns.find(c => c.activeFocus) ?? root.wheelColumns[0];
        target.forceActiveFocus();
        target.step(delta);
    }

    Shortcut {
        sequence: "Up"
        enabled: root.visible
        onActivated: root.stepFocusedColumn(-1)
    }
    Shortcut {
        sequence: "Down"
        enabled: root.visible
        onActivated: root.stepFocusedColumn(1)
    }
    Shortcut {
        sequence: "PgUp"
        enabled: root.visible
        onActivated: root.stepFocusedColumn(-10)
    }
    Shortcut {
        sequence: "PgDown"
        enabled: root.visible
        onActivated: root.stepFocusedColumn(10)
    }

    /**
     * One scrolling column. `wrap` is what removes the dead end at 59/23; the
     * delegate's reaction to `Tumbler.displacement` is what makes exactly one
     * value read as chosen and its neighbours as context.
     */
    component WheelColumn: Tumbler {
        id: column

        required property string a11yName
        // A touchpad sends many small deltas; one detent is 120 units, so this
        // accumulates rather than firing a step per fragment.
        property real wheelAccumulator: 0
        readonly property string currentLabel: String(column.model[column.currentIndex] ?? "")

        signal stepped

        function step(delta: int): void {
            column.currentIndex = (column.currentIndex + column.count + delta) % column.count;
        }

        visibleItemCount: root.visibleRows
        wrap: true
        activeFocusOnTab: true
        implicitHeight: root.rowHeight * root.visibleRows
        Layout.preferredHeight: implicitHeight

        // The value goes in the NAME, not only the description: a plain Item
        // exposes no value interface, so the name is the one string a screen
        // reader re-reads when the column steps. "Hour 07", not "Hour".
        Accessible.role: Accessible.SpinBox
        Accessible.name: `${column.a11yName} ${column.currentLabel}`
        Accessible.description: Translation.tr("Up and down arrow keys change the value; it wraps at both ends.")

        // Momentum is an affordance, never the only route to a value (the spec).
        // Tumbler's own view does not take arrow keys, so without these the
        // column could only be reached by flicking or scrolling it.
        Keys.onUpPressed: column.step(-1)
        Keys.onDownPressed: column.step(1)
        Keys.onPressed: event => {
            // Ten at a time, the same coarse step the wheel gives on a long
            // flick — 59 minutes should not cost 59 keystrokes.
            if (event.key === Qt.Key_PageUp)
                column.step(-10);
            else if (event.key === Qt.Key_PageDown)
                column.step(10);
            else
                return;
            event.accepted = true;
        }

        onCurrentIndexChanged: {
            if (root.syncing)
                return;
            // The discrete tick: the band flinches as each value passes the
            // selection point, so the column reads as detented.
            if (Appearance.animationsEnabled)
                tick.restart();
            column.stepped();
        }

        // The selection point, drawn under the values so the chosen one sits
        // inside it.
        background: Item {
            Rectangle {
                id: band
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: root.rowHeight
                radius: root.bandRadius
                color: root.colBand
                // Which column the arrow keys are talking to. The band is
                // already the "this is the chosen value" mark, so ringing it
                // costs no extra chrome.
                border.width: column.activeFocus ? 2 : 0
                border.color: root.colPrimary

                SequentialAnimation {
                    id: tick
                    NumberAnimation {
                        target: band
                        property: "scale"
                        to: 1.04
                        duration: Appearance.animation.elementMoveFast.duration / 3
                    }
                    NumberAnimation {
                        target: band
                        property: "scale"
                        to: 1
                        duration: Appearance.animation.elementMoveFast.duration / 2
                    }
                }
            }
        }

        // Tumbler's own view does not take wheel events, so without this the
        // sidebar's flickable would eat them. Stepping the index instead of
        // flicking also guarantees the wrap and the exact landing.
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                column.wheelAccumulator += event.angleDelta.y;
                while (column.wheelAccumulator >= 120) {
                    column.wheelAccumulator -= 120;
                    column.currentIndex = (column.currentIndex + column.count - 1) % column.count;
                }
                while (column.wheelAccumulator <= -120) {
                    column.wheelAccumulator += 120;
                    column.currentIndex = (column.currentIndex + 1) % column.count;
                }
            }
        }

        delegate: StyledText {
            required property var modelData
            // Tumbler only hands out `displacement` to a delegate that takes
            // `index`; without this the attached property is never populated
            // and every row would render as the chosen one.
            required property int index
            // Distance from the selection point: 0 is the chosen row.
            readonly property real offset: Math.abs(Tumbler.displacement ?? 0)

            text: modelData
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: Appearance.font.pixelSize.huge
            font.weight: offset < 0.5 ? Font.DemiBold : Font.Normal
            color: offset < 0.5 ? root.colPrimary : root.colText
            opacity: Math.max(0, 1 - offset / 2.5)
            scale: 1 - offset * 0.12
        }
    }

    RowLayout {
        id: columns
        anchors.centerIn: parent
        spacing: 2

        WheelColumn {
            id: hourColumn24
            visible: !root.use12Hour
            implicitWidth: root.rowHeight * 1.6
            a11yName: Translation.tr("Hour")
            model: root.hourLabels24
            onStepped: {
                root.hour = hourColumn24.currentIndex;
            }
        }

        WheelColumn {
            id: hourColumn12
            visible: root.use12Hour
            implicitWidth: root.rowHeight * 1.6
            a11yName: Translation.tr("Hour")
            model: root.hourLabels12
            onStepped: {
                root.hour = root.hourFromIndex(hourColumn12.currentIndex, root.pm);
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: ":"
            textFormat: Text.PlainText
            font.pixelSize: Appearance.font.pixelSize.huge
            color: root.colPrimary
        }

        WheelColumn {
            id: minuteColumn
            implicitWidth: root.rowHeight * 1.6
            a11yName: Translation.tr("Minute")
            model: root.minuteLabels
            onStepped: {
                root.minute = minuteColumn.currentIndex;
            }
        }

        // Two states, not a third column to scroll (the spec). Both write through
        // the same conversion the hour column uses, so noon and midnight cannot
        // take a different path here than they do there.
        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: 6
            visible: root.use12Hour
            spacing: 4

            Repeater {
                model: [
                    {
                        label: root.amText,
                        pm: false
                    },
                    {
                        label: root.pmText,
                        pm: true
                    }
                ]
                delegate: SelectionGroupButton {
                    required property var modelData
                    Layout.fillWidth: true
                    // The row is five values tall; without this the pair would
                    // share that height instead of sitting at its own size.
                    Layout.fillHeight: false
                    Layout.preferredHeight: implicitHeight
                    leftmost: true
                    rightmost: true
                    buttonText: modelData.label
                    toggled: root.pm === modelData.pm
                    // buttonText is this repo's own property, so without this
                    // the control's accessible name is empty and the pair reads
                    // as two unlabelled buttons.
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: modelData.label
                    Accessible.checkable: true
                    Accessible.checked: toggled
                    onClicked: root.hour = root.from12(root.to12(root.hour).h12, modelData.pm)
                }
            }
        }
    }
}
