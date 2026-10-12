pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.components
import qs.modules.iris.style

// Settings › Sources › Calendar: the iCal feeds CalendarSync reads, each shown by what it brings: its next event and
// the next fourteen days as bars in its colour. A click pauses a feed (it dims) or brings it back; hovering offers the
// remove mark; the dot steps the feed's colour through CalendarSync's presets. A failed fetch keeps its last events,
// greyed, and says why in plain words. Adding is one field: paste the link, the name comes from where it points.
ColumnLayout {
    id: root

    readonly property real d: IrisStyle.settingsDensity
    readonly property var sources: Config.options?.calendar?.externalSync?.sources ?? []
    // A webcal:// link is the same feed over https; curl only speaks the latter.
    readonly property string link: url.text.trim().replace(/^webcal:\/\//i, "https://")
    readonly property var today: { const t = new Date(); t.setHours(0, 0, 0, 0); return t }
    function failure(source: var): string {
        const error = String(CalendarSync.sourceStatuses?.[source.id]?.error ?? "")
        if (error.length === 0) return ""
        // The service keeps curl's and the parser's words; this says what they mean (curl 22 is an HTTP error).
        if (error.startsWith("Parse error")) return Translation.tr("That link is not a calendar")
        if (/code 22\b/.test(error)) return Translation.tr("The link answered with an error")
        return Network.online ? Translation.tr("Couldn't reach it") : Translation.tr("Offline")
    }
    function eventsOf(source: var): var {
        return (CalendarSync.events ?? []).filter(event => event.sourceId === source.id)
    }
    // How many events start on each of the next fourteen days.
    function daysOf(events: var): var {
        const counts = []
        for (let day = 0; day < 14; day++) counts.push(0)
        for (const event of events) {
            const at = new Date(event.startDate)
            at.setHours(0, 0, 0, 0)
            const day = Math.round((at - root.today) / 86400000)
            if (day >= 0 && day < 14) counts[day]++
        }
        return counts
    }
    function nextOf(events: var): string {
        const now = new Date()
        const next = events.filter(event => new Date(event.endDate) >= now).sort((a, b) => new Date(a.startDate) - new Date(b.startDate))[0]
        if (!next) return Translation.tr("Nothing in the next weeks")
        const at = new Date(next.startDate)
        const day = new Date(at); day.setHours(0, 0, 0, 0)
        const gap = Math.round((day - root.today) / 86400000)
        const when = gap === 0 ? Translation.tr("Today") : gap === 1 ? Translation.tr("Tomorrow") : at.toLocaleDateString(Qt.locale(), "ddd d MMM")
        return Translation.tr("Next: %1, %2").arg(String(next.title)).arg(when)
    }
    function nextColour(colour: string): string {
        const presets = CalendarSync.presetColors
        const at = presets.findIndex(entry => entry.toLowerCase() === String(colour).toLowerCase())
        return presets[(at + 1) % presets.length]
    }
    // A name from where the link points; the feed's own title is not read before it is added.
    function nameFor(link: string): string {
        const host = (String(link).match(/^[a-z]+:\/\/([^\/:?#]+)/i)?.[1] ?? "").toLowerCase().replace(/^www\./, "")
        if (host.includes("google")) return "Google Calendar"
        if (host.includes("outlook") || host.includes("office") || host.includes("live.com")) return "Outlook"
        if (host.includes("icloud")) return "iCloud"
        if (String(link).includes("remote.php/dav")) return "Nextcloud"
        return host.length > 0 ? host : Translation.tr("Calendar")
    }
    function add(): void {
        if (root.link.length === 0) return
        CalendarSync.addSource(root.nameFor(root.link), root.link, "")
        url.text = ""
        CalendarSync.forceRefreshAll()
    }

    spacing: Math.round(4 * root.d)

    Repeater {
        model: root.sources
        delegate: MouseArea {
            id: feed
            required property var modelData
            readonly property var events: root.eventsOf(feed.modelData)
            readonly property string failed: feed.modelData.enabled ? root.failure(feed.modelData) : ""
            readonly property color tone: feed.failed.length > 0 ? IrisStyle.textTertiary : Qt.color(String(feed.modelData.color ?? IrisStyle.accent))
            Layout.fillWidth: true
            implicitHeight: Math.round(58 * root.d)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.CheckBox
            Accessible.name: String(feed.modelData.name ?? "")
            Accessible.checked: feed.modelData.enabled === true
            onClicked: CalendarSync.toggleSource(feed.modelData.id, !feed.modelData.enabled)

            Rectangle {
                anchors.fill: parent
                radius: IrisStyle.radiusRow
                color: feed.containsMouse ? IrisStyle.fillQuiet : "transparent"
                Behavior on color {
                    enabled: IrisStyle.motionEnabled
                    ColorAnimation { duration: IrisStyle.duration(110) }
                }
            }
            Item {
                anchors.fill: parent
                opacity: feed.modelData.enabled ? 1 : 0.4
                Behavior on opacity {
                    enabled: IrisStyle.motionEnabled
                    NumberAnimation { duration: IrisStyle.duration(160) }
                }

                MouseArea {
                    id: dot
                    anchors.left: parent.left
                    anchors.leftMargin: Math.round(8 * root.d)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(28 * root.d)
                    height: width
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.Button
                    Accessible.name: Translation.tr("Colour")
                    onClicked: CalendarSync.updateSource(feed.modelData.id, { color: root.nextColour(feed.modelData.color) })
                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.round((dot.containsMouse ? 18 : 14) * root.d)
                        height: width
                        radius: IrisStyle.capsule(width)
                        color: feed.modelData.color ?? IrisStyle.accent
                        Behavior on width {
                            enabled: IrisStyle.motionEnabled
                            NumberAnimation { duration: IrisStyle.duration(120) }
                        }
                    }
                }
                ColumnLayout {
                    anchors.left: dot.right
                    anchors.leftMargin: Math.round(10 * root.d)
                    anchors.right: days.left
                    anchors.rightMargin: Math.round(16 * root.d)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(2 * root.d)
                    IrisText {
                        Layout.fillWidth: true
                        text: String(feed.modelData.name ?? "")
                        font.pixelSize: IrisStyle.typeLabel
                        elide: Text.ElideRight
                    }
                    IrisText {
                        Layout.fillWidth: true
                        text: !feed.modelData.enabled ? Translation.tr("Paused · click to bring it back")
                            : feed.failed.length > 0 ? feed.failed
                            : feed.events.length === 0 && CalendarSync.fetching ? Translation.tr("Fetching…")
                            : root.nextOf(feed.events)
                        font.pixelSize: IrisStyle.typeFootnote
                        color: feed.failed.length > 0 ? IrisStyle.danger : IrisStyle.subtext
                        elide: Text.ElideRight
                    }
                }
                // The next fourteen days, today first: a bar per day, as tall as its events are many.
                Row {
                    id: days
                    anchors.right: parent.right
                    anchors.rightMargin: Math.round(40 * root.d)
                    anchors.verticalCenter: parent.verticalCenter
                    height: Math.round(22 * root.d)
                    spacing: Math.round(4 * root.d)
                    Repeater {
                        model: root.daysOf(feed.events)
                        delegate: Item {
                            required property int modelData
                            required property int index
                            width: Math.round(6 * root.d)
                            height: days.height
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: modelData > 0 ? Math.round(Math.min(22, 6 + modelData * 4) * root.d) : width
                                radius: IrisStyle.capsule(width)
                                color: modelData > 0 ? feed.tone : IrisStyle.fill
                            }
                        }
                    }
                }
            }
            IrisIconButton {
                visible: feed.containsMouse || hovered
                anchors.right: parent.right
                anchors.rightMargin: Math.round(4 * root.d)
                anchors.verticalCenter: parent.verticalCenter
                materialIcon: "close"
                iconSize: Math.round(16 * root.d)
                Accessible.name: Translation.tr("Remove")
                onClicked: CalendarSync.removeSource(feed.modelData.id)
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Math.round(root.sources.length > 0 ? 6 * root.d : 0)
        spacing: Math.round(8 * root.d)
        IrisField {
            id: url
            Layout.fillWidth: true
            implicitHeight: Math.round(36 * root.d)
            font.pixelSize: IrisStyle.typeLabel
            placeholderText: Translation.tr("Paste a calendar's iCal link")
            onAccepted: root.add()
        }
        IrisButton {
            visible: root.link.length > 0
            text: Translation.tr("Add %1").arg(root.nameFor(root.link))
            colBackground: IrisStyle.tintFill(IrisStyle.accent)
            colBackgroundHover: IrisStyle.tintFillHover(IrisStyle.accent)
            foreground: IrisStyle.accent
            onClicked: root.add()
        }
    }
}
