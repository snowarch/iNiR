pragma Singleton
pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * A nice wrapper for date and time strings.
 */
Singleton {
    property var clock: SystemClock {
        id: clock
        precision: {
            if ((Config.options?.time?.secondPrecision ?? false) || GlobalStates.screenLocked)
                return SystemClock.Seconds;
            // The lock screen may show seconds, and it is rehearsed while unlocked.
            if ((Config.options?.iris?.lock?.type?.seconds ?? false)
                    && (GlobalStates.irisLockEdit || GlobalStates.screenLocked))
                return SystemClock.Seconds;
            return SystemClock.Minutes;
        }
    }
    property string time: Qt.locale().toString(clock.date, Config.options?.time.format ?? "hh:mm")
    // Like time, but appends :ss when secondPrecision is enabled — used by bar clocks
    property string timeDisplay: {
        const fmt = Config.options?.time?.format ?? "hh:mm";
        if (!(Config.options?.time?.secondPrecision ?? false) || fmt.includes("s"))
            return Qt.locale().toString(clock.date, fmt);
        const ap = fmt.indexOf(" AP");
        return Qt.locale().toString(clock.date, ap >= 0 ? fmt.slice(0, ap) + ":ss" + fmt.slice(ap) : fmt + ":ss");
    }
    property string shortDate: Qt.locale().toString(clock.date, Config.options?.time.shortDateFormat ?? "dd/MM")
    property string date: Qt.locale().toString(clock.date, Config.options?.time.dateFormat ?? "dddd, dd/MM")
    property string collapsedCalendarFormat: Qt.locale().toString(clock.date, "dd MMMM yyyy")
    property string uptime: "0h, 0m"

    Timer {
        triggeredOnStart: true
        // Uptime doesn't change fast - 60s updates are sufficient and reduce I/O
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            fileUptime.reload();
            const textUptime = fileUptime.text();
            const uptimeSeconds = Number(textUptime.split(" ")[0] ?? 0);

            // Convert seconds to days, hours, and minutes
            const days = Math.floor(uptimeSeconds / 86400);
            const hours = Math.floor((uptimeSeconds % 86400) / 3600);
            const minutes = Math.floor((uptimeSeconds % 3600) / 60);

            // Build the formatted uptime string
            let formatted = "";
            if (days > 0)
                formatted += `${days}d`;
            if (hours > 0)
                formatted += `${formatted ? ", " : ""}${hours}h`;
            if (minutes > 0 || !formatted)
                formatted += `${formatted ? ", " : ""}${minutes}m`;
            uptime = formatted;
        }
    }

    FileView {
        id: fileUptime

        path: "/proc/uptime"
    }
}
