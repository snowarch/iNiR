pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import "root:"

Item {
    id: root
    implicitHeight: card.implicitHeight + Appearance.sizes.elevationMargin

    // ── Settings ──────────────────────────────────────────────────────
    readonly property var configTimezones: Config.options?.sidebar?.widgets?.worldClock_settings?.timezones ?? []
    readonly property bool showSeconds: Config.options?.sidebar?.widgets?.worldClock_settings?.showSeconds ?? false
    readonly property bool use24Hour: Config.options?.sidebar?.widgets?.worldClock_settings?.use24Hour ?? true
    readonly property bool showDate: Config.options?.sidebar?.widgets?.worldClock_settings?.showDate ?? true
    readonly property bool highlightLocal: Config.options?.sidebar?.widgets?.worldClock_settings?.highlightLocal ?? true

    // ── Runtime state ─────────────────────────────────────────────────
    property string systemTz: ""
    // Map of tz -> { time, offset, date, doy, hour24, dayDelta }
    property var clockData: ({})

    readonly property var effectiveTimezones: configTimezones.length > 0
        ? configTimezones
        : _suggestedTimezones()

    // Pin the local timezone to the top ONLY when it is actually part of the
    // list — if the user removed it, it stays gone.
    readonly property var orderedTimezones: {
        const tzs = effectiveTimezones.slice()
        if (!highlightLocal || !systemTz || !tzs.includes(systemTz)) return tzs
        const withoutLocal = tzs.filter(t => t !== systemTz)
        return [systemTz, ...withoutLocal]
    }

    // ── Theme tokens ──────────────────────────────────────────────────
    readonly property color colText: Appearance.zzzEverywhere ? Appearance.zzz.ink
        : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
    readonly property color colSubtext: Appearance.zzzEverywhere ? Appearance.zzz.inkMuted
        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
    readonly property color colPrimary: Appearance.zzzEverywhere ? Appearance.zzz.accent
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
    readonly property color colSurface: Appearance.zzzEverywhere ? "transparent"
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer2
    readonly property color colSurfaceHover: Appearance.zzzEverywhere ? Appearance.zzz.chrome
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover
        : Appearance.colors.colLayer2Hover
    readonly property real radiusCard: Appearance.zzzEverywhere ? Appearance.zzz.cardRadius
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
    readonly property real radiusInner: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small

    // ── System timezone detection ─────────────────────────────────────
    Process {
        id: systemTzProcess
        command: ["/usr/bin/readlink", "/etc/localtime"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim()
                const parts = raw.split("/zoneinfo/")
                root.systemTz = parts.length === 2 ? parts[1] : raw
                root._refresh()
            }
        }
    }

    // ── Periodic refresh (gated on sidebar visibility) ────────────────
    Timer {
        id: refreshTimer
        interval: root.showSeconds ? 1000 : 30000
        running: GlobalStates.sidebarLeftOpen
        repeat: true
        triggeredOnStart: true
        onTriggered: root._refresh()
    }

    onEffectiveTimezonesChanged: _refresh()
    onShowSecondsChanged: _refresh()
    onUse24HourChanged: _refresh()

    function _refresh() {
        const tzs = effectiveTimezones
        if (tzs.length === 0) return
        const timeFmt = use24Hour
            ? (showSeconds ? "%H:%M:%S" : "%H:%M")
            : (showSeconds ? "%I:%M:%S %p" : "%I:%M %p")
        // One shell pass: emit "tz|time|offset|date|doy|hour24" per line.
        let script = ""
        for (let i = 0; i < tzs.length; i++) {
            const tz = tzs[i]
            script += `printf '%s|%s\\n' "${tz}" "$(TZ='${tz}' date '+${timeFmt}|%:z|%a %d %b|%j|%H')"\n`
        }
        clockProcess.command = ["/usr/bin/bash", "-c", script]
        clockProcess.running = true
    }

    Process {
        id: clockProcess
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim()
                if (out.length === 0) return
                const data = {}
                let localDoy = -1
                const lines = out.split("\n")
                for (const line of lines) {
                    const sep = line.indexOf("|")
                    if (sep < 0) continue
                    const tz = line.slice(0, sep)
                    const rest = line.slice(sep + 1).split("|")
                    if (rest.length < 5) continue
                    const doy = parseInt(rest[3])
                    if (tz === root.systemTz) localDoy = doy
                    data[tz] = {
                        time: rest[0],
                        offset: rest[1],
                        date: rest[2],
                        doy: doy,
                        hour24: parseInt(rest[4])
                    }
                }
                if (localDoy >= 0) {
                    for (const tz in data) {
                        const diff = data[tz].doy - localDoy
                        data[tz].dayDelta = (diff > 300) ? -1 : (diff < -300) ? 1 : diff
                    }
                }
                root.clockData = data
            }
        }
    }

    // ── Smart default suggestions by region ───────────────────────────
    function _suggestedTimezones() {
        const region = systemTz.split("/")[0] || ""
        const base = systemTz ? [systemTz] : []
        const global = ["America/New_York", "Europe/London", "Asia/Tokyo"]
        let regional = []
        switch (region) {
        case "America": regional = ["America/Los_Angeles", "Europe/London"]; break
        case "Europe": regional = ["America/New_York", "Asia/Tokyo"]; break
        case "Asia": regional = ["Europe/London", "America/New_York"]; break
        case "Australia":
        case "Pacific": regional = ["Asia/Tokyo", "Europe/London"]; break
        case "Africa": regional = ["Europe/London", "Asia/Dubai"]; break
        }
        const seen = new Set(base)
        const result = [...base]
        for (const tz of [...regional, ...global]) {
            if (!seen.has(tz)) { seen.add(tz); result.push(tz) }
        }
        return result.slice(0, 4)
    }

    // ── Display helpers ───────────────────────────────────────────────
    function _cityName(tz) {
        const parts = tz.split("/")
        return parts[parts.length - 1].replace(/_/g, " ")
    }

    function _isDaytime(hour24) {
        return hour24 >= 6 && hour24 < 19
    }

    // ── UI ────────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: parent.width
        implicitHeight: col.implicitHeight + 20
        radius: root.radiusCard
        color: "transparent"

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            // ── Header ────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                MaterialSymbol {
                    text: "language"
                    iconSize: 16
                    fill: 1
                    color: root.colPrimary
                }
                StyledText {
                    text: Translation.tr("World Clock")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Medium
                    color: root.colText
                }
                Item { Layout.fillWidth: true }

                // "Auto" chip — shown when using region suggestions
                Rectangle {
                    visible: root.configTimezones.length === 0
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: autoRow.implicitWidth + 14
                    implicitHeight: autoRow.implicitHeight + 6
                    radius: height / 2
                    color: "transparent"
                    border.width: 1
                    border.color: ColorUtils.transparentize(root.colSubtext, 0.7)

                    RowLayout {
                        id: autoRow
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            text: "my_location"
                            iconSize: 11
                            color: root.colSubtext
                        }
                        StyledText {
                            text: Translation.tr("Auto")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: Font.Medium
                            color: root.colSubtext
                        }
                    }

                    MouseArea {
                        id: autoHover
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                    StyledToolTip {
                        extraVisibleCondition: autoHover.containsMouse
                        text: Translation.tr("Showing region-based suggestions. Add your own timezones in Settings.")
                    }
                }
            }

            // ── Clock rows ────────────────────────────────────────────
            Repeater {
                model: root.orderedTimezones

                delegate: Rectangle {
                    id: clockRow
                    required property var modelData
                    required property int index
                    readonly property string tz: modelData
                    readonly property var d: root.clockData[tz] ?? null
                    readonly property bool isLocal: tz === root.systemTz
                    readonly property bool isDay: d ? root._isDaytime(d.hour24) : true

                    Layout.fillWidth: true
                    implicitHeight: rowContent.implicitHeight + 16
                    radius: root.radiusInner

                    // All rows share the same dark surface; the local row is
                    // distinguished only by a left accent bar + accented time,
                    // keeping the elegant dark look intact.
                    readonly property bool accentLocal: isLocal && root.highlightLocal
                    color: rowHover.containsMouse ? root.colSurfaceHover : root.colSurface

                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }

                    // Accent bar on the left edge for the local row
                    Rectangle {
                        visible: clockRow.accentLocal
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                            topMargin: 7
                            bottomMargin: 7
                        }
                        width: 3
                        radius: width / 2
                        color: root.colPrimary
                    }

                    readonly property color rowTextCol: root.colText
                    readonly property color rowSubCol: root.colSubtext
                    readonly property color rowAccentCol: root.colPrimary

                    MouseArea {
                        id: rowHover
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                    StyledToolTip {
                        extraVisibleCondition: rowHover.containsMouse
                        text: clockRow.tz.replace(/_/g, " ")
                    }

                    RowLayout {
                        id: rowContent
                        anchors {
                            left: parent.left; right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: 10; rightMargin: 12
                        }
                        spacing: 10

                        // Day/night indicator
                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 30
                            implicitHeight: 30
                            radius: height / 2
                            color: clockRow.accentLocal
                                ? ColorUtils.transparentize(root.colPrimary, 0.85)
                                : (Appearance.inirEverywhere ? Appearance.inir.colLayer1 : Appearance.colors.colLayer1)

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: clockRow.isDay ? "light_mode" : "dark_mode"
                                iconSize: 16
                                fill: clockRow.isDay ? 1 : 0
                                color: clockRow.isDay ? root.colPrimary : root.colSubtext
                            }
                        }

                        // City name + offset/date (flexible width, elides)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 5

                                StyledText {
                                    text: root._cityName(clockRow.tz)
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.DemiBold
                                    color: clockRow.rowTextCol
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                // Local pill
                                Rectangle {
                                    visible: clockRow.accentLocal
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitWidth: localLabel.implicitWidth + 10
                                    implicitHeight: localLabel.implicitHeight + 3
                                    radius: height / 2
                                    color: ColorUtils.transparentize(root.colPrimary, 0.8)
                                    StyledText {
                                        id: localLabel
                                        anchors.centerIn: parent
                                        text: Translation.tr("LOCAL")
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        font.weight: Font.Bold
                                        color: root.colPrimary
                                    }
                                }
                            }

                            StyledText {
                                visible: clockRow.d !== null
                                Layout.fillWidth: true
                                text: {
                                    if (!clockRow.d) return ""
                                    let s = "GMT" + clockRow.d.offset
                                    if (root.showDate) s += "  ·  " + clockRow.d.date
                                    return s
                                }
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: clockRow.rowSubCol
                                elide: Text.ElideRight
                            }
                        }

                        // Time column — FIXED width + tabular numbers → all rows align
                        ColumnLayout {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: timeText.implicitWidth
                            spacing: 0

                            StyledText {
                                id: timeText
                                Layout.alignment: Qt.AlignRight
                                text: clockRow.d?.time ?? "--:--"
                                font.pixelSize: Appearance.font.pixelSize.larger ?? Appearance.font.pixelSize.normal
                                font.weight: Appearance.zzzEverywhere ? Font.Black : Font.DemiBold
                                font.family: Appearance.font.family.numbers
                                font.italic: Appearance.zzzEverywhere
                                color: clockRow.accentLocal ? root.colPrimary : clockRow.rowTextCol
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignRight
                                visible: (clockRow.d?.dayDelta ?? 0) !== 0
                                text: {
                                    const delta = clockRow.d?.dayDelta ?? 0
                                    return delta > 0 ? Translation.tr("Tomorrow")
                                                     : Translation.tr("Yesterday")
                                }
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.weight: Font.Medium
                                color: clockRow.rowAccentCol
                            }
                        }
                    }
                }
            }
        }
    }
}
