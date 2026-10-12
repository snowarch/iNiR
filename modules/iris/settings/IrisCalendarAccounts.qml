pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.components
import qs.modules.iris.style

// Settings › Sources › Calendar: the iCal feeds CalendarSync reads. Each one says what its last fetch found;
// its colour (the dot) steps through CalendarSync's presets on a click, since it marks that feed's events.
ColumnLayout {
    id: root

    readonly property real d: IrisStyle.settingsDensity
    readonly property var sources: Config.options?.calendar?.externalSync?.sources ?? []
    readonly property string link: url.text.trim()
    function stateOf(source: var): string {
        const status = CalendarSync.sourceStatuses?.[source.id] ?? null
        if (!source.enabled) return Translation.tr("Paused")
        if (!status) return CalendarSync.fetching ? Translation.tr("Fetching…") : ""
        // The service keeps curl's and the parser's words; the row says what they mean (curl 22 is an HTTP error).
        const error = String(status.error ?? "")
        if (error.startsWith("Parse error")) return Translation.tr("That link is not a calendar")
        if (/code 22\b/.test(error)) return Translation.tr("The link answered with an error")
        if (error.length > 0) return Network.online ? Translation.tr("Couldn't reach it") : Translation.tr("Offline")
        return Translation.tr("%1 events").arg(Number(status.eventCount ?? 0))
    }
    function nextColour(colour: string): string {
        const presets = CalendarSync.presetColors
        const at = presets.findIndex(entry => entry.toLowerCase() === String(colour).toLowerCase())
        return presets[(at + 1) % presets.length]
    }
    function add(): void {
        if (root.link.length === 0) return
        const typed = name.text.trim()
        CalendarSync.addSource(typed.length > 0 ? typed : Translation.tr("Calendar"), root.link, "")
        name.text = ""
        url.text = ""
        CalendarSync.forceRefreshAll()
    }

    spacing: Math.round(4 * root.d)

    Repeater {
        model: root.sources
        delegate: Item {
            id: row
            required property var modelData
            readonly property string said: root.stateOf(row.modelData)
            readonly property bool failed: row.modelData.enabled && String(CalendarSync.sourceStatuses?.[row.modelData.id]?.error ?? "").length > 0
            Layout.fillWidth: true
            implicitHeight: Math.round(46 * root.d)

            MouseArea {
                id: dot
                anchors.left: parent.left
                anchors.leftMargin: Math.round(10 * root.d)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(26 * root.d)
                height: width
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.Button
                Accessible.name: Translation.tr("Colour")
                onClicked: CalendarSync.updateSource(row.modelData.id, { color: root.nextColour(row.modelData.color) })
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.round((dot.containsMouse ? 16 : 14) * root.d)
                    height: width
                    radius: width / 2
                    color: row.modelData.color ?? IrisStyle.accent
                    opacity: row.modelData.enabled ? 1 : 0.4
                }
            }
            ColumnLayout {
                anchors.left: dot.right
                anchors.leftMargin: Math.round(12 * root.d)
                anchors.right: controls.left
                anchors.rightMargin: Math.round(8 * root.d)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                IrisText {
                    Layout.fillWidth: true
                    text: String(row.modelData.name ?? "")
                    font.pixelSize: IrisStyle.typeLabel
                    color: row.modelData.enabled ? IrisStyle.text : IrisStyle.subtext
                    elide: Text.ElideRight
                }
                IrisText {
                    Layout.fillWidth: true
                    visible: row.said.length > 0
                    text: row.said
                    font.pixelSize: IrisStyle.typeFootnote
                    color: row.failed ? IrisStyle.danger : IrisStyle.subtext
                    elide: Text.ElideRight
                }
            }
            RowLayout {
                id: controls
                anchors.right: parent.right
                anchors.rightMargin: Math.round(10 * root.d)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(6 * root.d)
                IrisIconButton {
                    materialIcon: "close"
                    iconSize: Math.round(16 * root.d)
                    Accessible.name: Translation.tr("Remove")
                    onClicked: CalendarSync.removeSource(row.modelData.id)
                }
                IrisSwitch {
                    on: row.modelData.enabled === true
                    name: String(row.modelData.name ?? "")
                    onToggled: CalendarSync.toggleSource(row.modelData.id, !on)
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Math.round(root.sources.length > 0 ? 6 * root.d : 0)
        spacing: Math.round(8 * root.d)
        IrisField {
            id: name
            Layout.preferredWidth: Math.round(150 * root.d)
            implicitHeight: Math.round(36 * root.d)
            font.pixelSize: IrisStyle.typeLabel
            placeholderText: Translation.tr("Name")
            onAccepted: url.forceActiveFocus()
        }
        IrisField {
            id: url
            Layout.fillWidth: true
            implicitHeight: Math.round(36 * root.d)
            font.pixelSize: IrisStyle.typeLabel
            placeholderText: Translation.tr("iCal link (.ics)")
            onAccepted: root.add()
        }
        IrisButton {
            text: Translation.tr("Add")
            enabled: root.link.length > 0
            opacity: enabled ? 1 : 0.5
            colBackground: IrisStyle.fill
            colBackgroundHover: IrisStyle.fillHover
            onClicked: root.add()
        }
    }
}
