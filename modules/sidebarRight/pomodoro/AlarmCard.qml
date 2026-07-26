pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * One alarm in the Alarms tab: time, name, schedule summary, next fire,
 * arm toggle, edit and delete.
 *
 * Reads only; every mutation goes back through AlarmService so the record and
 * the file stay the single source of truth.
 */
Rectangle {
    id: root

    required property var alarm
    // Ticks with the shell clock so "Tomorrow" and the next-fire line stay true
    // without a timer of their own.
    property real nowMs: DateTime.clock.date.getTime()

    signal editRequested(int id)
    signal deleteRequested(int id)

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
    readonly property color colBorder: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
        : Appearance.inirEverywhere ? Appearance.inir.colBorder
        : Appearance.auroraEverywhere ? "transparent"
        : Appearance.colors.colOutlineVariant

    readonly property string timeFormat: Config.options?.time?.format ?? "hh:mm"
    readonly property real nextAt: AlarmService.nextOccurrence(root.alarm, root.nowMs)
    readonly property string pipelineState: AlarmService.alarmState(root.alarm.id)

    function _time(ms: real): string {
        return Qt.locale().toString(new Date(ms), root.timeFormat);
    }

    // the three modes must be distinguishable at a glance, so each one
    // gets its own phrasing rather than a shared "next fire" line.
    function scheduleSummary(): string {
        if (root.alarm.mode === AlarmService.modeDate) {
            const parts = String(root.alarm.date).split("-").map(Number);
            return Qt.locale().toString(new Date(parts[0], parts[1] - 1, parts[2]), "ddd, d MMM yyyy");
        }
        if (root.alarm.mode === AlarmService.modeRepeat) {
            const days = root.alarm.repeatDays;
            if (days === 0x7F)
                return Translation.tr("Every day");
            if (days === 0x3E)
                return Translation.tr("Every weekday");
            if (days === 0x41)
                return Translation.tr("Every weekend");
            const names = [];
            for (let d = 0; d < 7; d++)
                if (days & (1 << d))
                    names.push(Qt.locale().dayName(d, Locale.ShortFormat));
            return names.join(", ");
        }
        if (root.nextAt < 0)
            return Translation.tr("Once");
        const today = new Date(root.nowMs);
        const at = new Date(root.nextAt);
        return at.getDate() === today.getDate() && at.getMonth() === today.getMonth() ? Translation.tr("Today") : Translation.tr("Tomorrow");
    }

    // dismissed and missed are different facts and must not share a
    // style. Live pipeline state outranks a past outcome — what the alarm is
    // doing now matters more than how the last one ended.
    readonly property var badge: {
        if (root.pipelineState === "ringing")
            return {
                text: Translation.tr("Ringing"),
                icon: "notifications_active",
                fg: Appearance.colors.colOnPrimary,
                bg: root.colPrimary
            };
        if (root.pipelineState === "snoozed")
            return {
                text: Translation.tr("Snoozed"),
                icon: "snooze",
                fg: Appearance.colors.colOnTertiaryContainer,
                bg: Appearance.colors.colTertiaryContainer
            };
        if (root.pipelineState === "queued")
            return {
                text: Translation.tr("Waiting"),
                icon: "hourglass_top",
                fg: Appearance.colors.colOnSecondaryContainer,
                bg: Appearance.colors.colSecondaryContainer
            };
        if (root.alarm.lastOutcome === AlarmService.outcomeMissed)
            return {
                text: Translation.tr("Missed"),
                icon: "notifications_off",
                fg: Appearance.colors.colOnError,
                bg: Appearance.colors.colError
            };
        if (root.alarm.lastOutcome === AlarmService.outcomeDismissed)
            return {
                text: Translation.tr("Dismissed"),
                icon: "check_circle",
                fg: Appearance.colors.colOnSecondaryContainer,
                bg: Appearance.colors.colSecondaryContainer
            };
        return null;
    }

    // The row as one announced thing, so the three controls inside it are read
    // in context instead of as three orphans.
    Accessible.role: Accessible.ListItem
    Accessible.name: root._time(new Date(2000, 0, 1, root.alarm.hour, root.alarm.minute).getTime()) + " " + AlarmService.displayName(root.alarm)
    Accessible.description: root.scheduleSummary() + (root.badge ? ", " + root.badge.text : "") + (root.alarm.enabled ? "" : ", " + Translation.tr("disarmed"))

    implicitHeight: cardColumn.implicitHeight + 20
    radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
    color: root.colCard
    border.width: root.colBorder === "transparent" ? 0 : 1
    border.color: root.colBorder

    ColumnLayout {
        id: cardColumn
        anchors.fill: parent
        anchors.margins: 10
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText {
                text: root._time(new Date(2000, 0, 1, root.alarm.hour, root.alarm.minute).getTime())
                font.pixelSize: Math.round(28 * Appearance.fontSizeScale)
                color: root.alarm.enabled ? root.colText : root.colTextSecondary
            }

            // Post-fire / live state. Colour AND wording differ per state so
            // neither colour blindness nor a monochrome style loses the
            // distinction.
            Rectangle {
                visible: root.badge !== null
                implicitWidth: badgeRow.implicitWidth + 12
                implicitHeight: badgeRow.implicitHeight + 4
                radius: Appearance.rounding.full
                color: root.badge?.bg ?? "transparent"

                RowLayout {
                    id: badgeRow
                    anchors.centerIn: parent
                    spacing: 3
                    MaterialSymbol {
                        text: root.badge?.icon ?? ""
                        iconSize: 14
                        color: root.badge?.fg ?? "transparent"
                    }
                    StyledText {
                        text: root.badge?.text ?? ""
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: root.badge?.fg ?? "transparent"
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }

            StyledSwitch {
                Layout.alignment: Qt.AlignVCenter
                checked: root.alarm.enabled
                // Three identical-looking row controls per row and one row per
                // alarm: without the alarm's own name on each of them, a
                // keyboard or screen-reader user reaches "switch, button,
                // button" six times over and cannot tell the rows apart.
                Accessible.name: Translation.tr("Arm %1").arg(AlarmService.displayName(root.alarm))
                Accessible.description: Translation.tr("Arm or disarm this alarm")
                onToggled: {
                    if (checked === root.alarm.enabled)
                        return;
                    // disarming must leave nothing sounding under it.
                    if (!checked)
                        AlarmService.cancelAlarm(root.alarm.id);
                    if (!AlarmService.updateAlarm(root.alarm.id, {
                        enabled: checked
                    }))
                        checked = root.alarm.enabled; // refused; say so by snapping back
                }

                StyledToolTip {
                    text: Translation.tr("Arm or disarm this alarm")
                }
            }

            IconToolbarButton {
                implicitHeight: 30
                text: "edit"
                // `text` here is a Material Symbol ligature name, which is what
                // a screen reader would otherwise read out.
                Accessible.role: Accessible.Button
                Accessible.name: Translation.tr("Edit %1").arg(AlarmService.displayName(root.alarm))
                onClicked: root.editRequested(root.alarm.id)
                StyledToolTip {
                    text: Translation.tr("Edit alarm")
                }
            }

            IconToolbarButton {
                implicitHeight: 30
                text: "delete"
                Accessible.role: Accessible.Button
                Accessible.name: Translation.tr("Delete %1").arg(AlarmService.displayName(root.alarm))
                onClicked: root.deleteRequested(root.alarm.id)
                StyledToolTip {
                    text: Translation.tr("Delete alarm")
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: AlarmService.displayName(root.alarm)
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.colText
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            MaterialSymbol {
                text: root.alarm.mode === AlarmService.modeRepeat ? "repeat"
                    : root.alarm.mode === AlarmService.modeDate ? "event" : "arrow_forward"
                iconSize: 15
                color: root.colTextSecondary
            }
            StyledText {
                text: root.scheduleSummary()
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.colTextSecondary
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
            StyledText {
                Layout.fillWidth: true
                text: root.nextAt < 0 ? Translation.tr("• Not scheduled")
                    : Translation.tr("• Rings %1").arg(Qt.locale().toString(new Date(root.nextAt), "ddd " + root.timeFormat))
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.nextAt < 0 ? root.colTextSecondary : root.colPrimary
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
        }
    }
}
