pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * Create or edit one alarm. A form over AlarmService, never a second source of
 * truth: it holds a draft while it is open, and the only thing that ever
 * reaches the record is one addAlarm()/updateAlarm() call on Save.
 *
 * 's either/or lives in the service; this makes it VISIBLE — picking a
 * date empties the day chips in front of the user and vice versa, rather than
 * letting them build a schedule the service will silently rewrite.
 */
Item {
    id: root

    // -1 = creating a new alarm.
    property int alarmId: -1
    signal closed

    property int draftHour: 7
    property int draftMinute: 0
    property string draftName: ""
    property string draftDate: ""
    property int draftRepeatDays: 0
    // null is the inherit sentinel on both — never "" / 0 / false.
    property var draftSound: null
    property var draftSnoozeMinutes: null

    readonly property bool creating: root.alarmId === -1
    readonly property string mode: root.draftDate !== "" ? AlarmService.modeDate
        : root.draftRepeatDays !== 0 ? AlarmService.modeRepeat : AlarmService.modeNext

    // Style tokens
    readonly property color colText: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
    readonly property color colTextSecondary: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
    readonly property color colPrimary: Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
    readonly property color colCard: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer1

    // The record Save would write, so validation and the preview below judge
    // exactly what the user is about to get.
    readonly property var draftAlarm: ({
            id: root.alarmId,
            hour: root.draftHour,
            minute: root.draftMinute,
            name: root.draftName,
            enabled: true,
            date: root.draftDate,
            repeatDays: root.draftRepeatDays
        })
    // , surfaced while typing rather than as a silent refusal on Save.
    readonly property string scheduleError: AlarmService.validateSchedule(root.draftAlarm, DateTime.clock.date.getTime()).reason
    readonly property real previewAt: AlarmService.nextOccurrence(root.draftAlarm, DateTime.clock.date.getTime())

    function load(): void {
        const alarm = root.alarmId === -1 ? null : AlarmService.alarmById(root.alarmId);
        const now = new Date();
        root.draftHour = alarm?.hour ?? now.getHours();
        root.draftMinute = alarm?.minute ?? now.getMinutes();
        root.draftName = alarm?.name ?? "";
        root.draftDate = alarm?.date ?? "";
        root.draftRepeatDays = alarm?.repeatDays ?? 0;
        root.draftSound = alarm?.sound ?? null;
        root.draftSnoozeMinutes = alarm?.snoozeMinutes ?? null;
        nameField.text = root.draftName;
        // Seeded, not bound: the picker owns its own value once it is running,
        // so re-opening is the one moment the draft gets to push into it.
        timeWheel.hour = root.draftHour;
        timeWheel.minute = root.draftMinute;
    }

    function save(): void {
        const fields = {
            date: root.draftDate,
            repeatDays: root.draftRepeatDays,
            sound: root.draftSound,
            snoozeMinutes: root.draftSnoozeMinutes
        };
        if (root.creating) {
            if (AlarmService.addAlarm(root.draftHour, root.draftMinute, root.draftName, fields) === -1)
                return;
        } else {
            // an edit must not leave the old settings sounding.
            AlarmService.cancelAlarm(root.alarmId);
            if (!AlarmService.updateAlarm(root.alarmId, Object.assign({
                hour: root.draftHour,
                minute: root.draftMinute,
                name: root.draftName,
                enabled: true
            }, fields)))
                return;
        }
        root.closed();
    }

    //  made visible: only one of the two can hold at a time, and the
    // control the user just abandoned empties in front of them.
    function setDate(date: string): void {
        root.draftDate = date;
        if (date !== "")
            root.draftRepeatDays = 0;
    }

    function toggleDay(day: int): void {
        root.draftRepeatDays ^= (1 << day);
        if (root.draftRepeatDays !== 0)
            root.draftDate = "";
    }

    Component.onCompleted: root.load()
    onAlarmIdChanged: root.load()
    // Re-opened on the same id (two "Add alarm" presses in a row) must not
    // inherit the previous draft.
    onVisibleChanged: if (root.visible)
        root.load()

    StyledFlickable {
        anchors.fill: parent
        contentHeight: form.implicitHeight
        clip: true

        ColumnLayout {
            id: form
            width: parent.width
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                IconToolbarButton {
                    implicitHeight: 32
                    text: "arrow_back"
                    // `text` is a Material Symbol ligature name; say what the
                    // button does rather than let a reader spell the icon.
                    Accessible.role: Accessible.Button
                    Accessible.name: Translation.tr("Discard and go back")
                    onClicked: root.closed()
                    StyledToolTip {
                        text: Translation.tr("Discard and go back")
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.creating ? Translation.tr("New alarm") : Translation.tr("Edit alarm")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: root.colText
                }
                RippleButtonWithIcon {
                    materialIcon: "check"
                    mainText: Translation.tr("Save")
                    enabled: root.scheduleError === ""
                    Accessible.role: Accessible.Button
                    Accessible.name: mainText
                    // Save going grey is the only sign of a refused schedule;
                    // a reader that cannot see the inline error still gets it.
                    Accessible.description: root.scheduleError
                    onClicked: root.save()
                }
            }

            // draftHour/draftMinute are the whole contract with the picker: it
            // reads and writes the stored 0-23 / 0-59 time and decides on its
            // own what the shell's time.format means for the display.
            TimeWheel {
                id: timeWheel
                Layout.alignment: Qt.AlignHCenter
                onHourChanged: root.draftHour = timeWheel.hour
                onMinuteChanged: root.draftMinute = timeWheel.minute
            }

            MaterialTextField {
                id: nameField
                Layout.fillWidth: true
                placeholderText: Translation.tr("Name (optional)")
                onTextChanged: root.draftName = text
            }

            // Which mode is active, stated rather than inferred.
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: [
                        {
                            value: AlarmService.modeNext,
                            label: Translation.tr("Next time"),
                            icon: "arrow_forward"
                        },
                        {
                            value: AlarmService.modeRepeat,
                            label: Translation.tr("Repeat"),
                            icon: "repeat"
                        },
                        {
                            value: AlarmService.modeDate,
                            label: Translation.tr("On a date"),
                            icon: "event"
                        }
                    ]
                    delegate: SelectionGroupButton {
                        required property var modelData
                        Layout.fillWidth: true
                        leftmost: true
                        rightmost: true
                        buttonIcon: modelData.icon
                        buttonText: modelData.label
                        toggled: root.mode === modelData.value
                        Accessible.role: Accessible.RadioButton
                        Accessible.name: modelData.label
                        Accessible.checkable: true
                        Accessible.checked: toggled
                        onClicked: {
                            if (modelData.value === AlarmService.modeNext) {
                                root.draftRepeatDays = 0;
                                root.draftDate = "";
                            } else if (modelData.value === AlarmService.modeRepeat) {
                                root.setDate("");
                                if (root.draftRepeatDays === 0)
                                    root.draftRepeatDays = 0x7F;
                            } else if (root.draftDate === "") {
                                const today = new Date();
                                root.setDate(Qt.formatDate(today, "yyyy-MM-dd"));
                            }
                        }
                    }
                }
            }

            // Repeat days. Visible only in repeat mode, which is itself the
            // signal that a date has taken over.
            RowLayout {
                Layout.fillWidth: true
                visible: root.mode === AlarmService.modeRepeat
                spacing: 3

                Repeater {
                    model: 7
                    delegate: SelectionGroupButton {
                        required property int index
                        Layout.fillWidth: true
                        leftmost: true
                        rightmost: true
                        // The visible label is one narrow letter ("M", "T");
                        // the reader gets the day it actually means.
                        buttonText: Qt.locale().dayName(index, Locale.NarrowFormat)
                        toggled: (root.draftRepeatDays & (1 << index)) !== 0
                        Accessible.role: Accessible.CheckBox
                        Accessible.name: Qt.locale().dayName(index, Locale.LongFormat)
                        Accessible.checkable: true
                        Accessible.checked: toggled
                        onClicked: root.toggleDay(index)
                    }
                }
            }

            //  made visible rather than punitive: everything before today
            // and everything past the owner's one-year horizon is dimmed and
            // inert, so a date that would be refused on Save cannot be picked.
            DatePicker {
                Layout.fillWidth: true
                visible: root.mode === AlarmService.modeDate
                minimumDate: new Date()
                maximumDate: {
                    const horizon = new Date();
                    horizon.setFullYear(horizon.getFullYear() + AlarmService.dateHorizonYears);
                    return horizon;
                }
                selectedDate: {
                    const parts = root.draftDate.split("-").map(Number);
                    return parts.length === 3 ? new Date(parts[0], parts[1] - 1, parts[2]) : new Date();
                }
                onDateSelected: date => root.setDate(Qt.formatDate(date, "yyyy-MM-dd"))
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.mode !== AlarmService.modeNext
                text: root.mode === AlarmService.modeDate
                    ? Translation.tr("A date and repeat days are exclusive — picking a date cleared the repeat days.")
                    : Translation.tr("A date and repeat days are exclusive — picking days cleared the date.")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.colTextSecondary
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
            }

            //  rejection, inline. Save is disabled while this is showing.
            StyledText {
                Layout.fillWidth: true
                visible: root.scheduleError !== ""
                text: root.scheduleError
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colError
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.scheduleError === "" && root.previewAt >= 0
                // The shell's own date and time keys, both of them — this
                // feature introduces no presentation format of its own.
                text: Translation.tr("Rings %1").arg(Qt.locale().toString(new Date(root.previewAt), (Config.options?.time?.dateFormat ?? "ddd, dd/MM") + " " + (Config.options?.time?.format ?? "hh:mm")))
                font.pixelSize: Appearance.font.pixelSize.small
                color: root.colPrimary
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
            }

            // Not documentation — the one place the user decides to
            // rely on this is right here, so the limit is stated right here.
            NoticeBox {
                Layout.fillWidth: true
                materialIcon: "bedtime_off"
                text: Translation.tr("Alarms only ring while this session is awake. A suspended, hibernated or powered-off machine will not be woken.")
            }

            StyledText {
                Layout.topMargin: 4
                text: Translation.tr("Just for this alarm")
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: root.colText
            }

            SoundPicker {
                Layout.fillWidth: true
                label: Translation.tr("Sound")
                eventId: "alarmDone"
                boundToConfig: false
                value: root.draftSound ?? ""
                inheritLabel: Translation.tr("Same as every other alarm")
                // "" is the inherit choice, and it must go back to null — not
                // to whatever the global happens to say today.
                onValueChosen: chosen => root.draftSound = (chosen === "" ? null : chosen)
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    Layout.fillWidth: true
                    text: root.draftSnoozeMinutes === null
                        ? Translation.tr("Snooze: %1 min (shared)").arg(AlarmService.resolveSnoozeMinutes(null))
                        : Translation.tr("Snooze")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: root.colText
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
                StyledSpinBox {
                    visible: root.draftSnoozeMinutes !== null
                    from: 1
                    to: 120
                    value: root.draftSnoozeMinutes ?? AlarmService.resolveSnoozeMinutes(null)
                    Accessible.name: Translation.tr("Snooze minutes")
                    onValueChanged: if (root.draftSnoozeMinutes !== null)
                        root.draftSnoozeMinutes = value
                }
                StyledSwitch {
                    checked: root.draftSnoozeMinutes !== null
                    Accessible.name: Translation.tr("Use a snooze length just for this alarm")
                    onToggled: root.draftSnoozeMinutes = checked ? AlarmService.resolveSnoozeMinutes(null) : null
                    StyledToolTip {
                        text: Translation.tr("Use a snooze length just for this alarm")
                    }
                }
            }

        }
    }
}
