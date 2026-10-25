pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// Ledger's desktop page: the day set large, then the day kept as a ledger, one line an entry, its name in the margin.
// Words and figures only, no plates: the Island's body is the page.
ColumnLayout {
    id: page
    property Item island: null
    readonly property real d: IrisStyle.density
    readonly property bool showBanner: false
    readonly property bool live: page.island?.effectivePage === "desktop" && (page.island?.visualExpanded ?? false)
    readonly property date now: DateTime.clock.date
    readonly property real margin: Math.round(64 * page.d)
    readonly property bool weatherReady: Weather.enabled && !String(Weather.data?.temp ?? "--").startsWith("--")
    readonly property var hours: Array.from(Weather.data?.hourly ?? []).slice(0, 6)
    readonly property var nextEvent: {
        void DateTime.clock.date
        return Events.getUpcomingEvents(7)[0] ?? null
    }
    readonly property int pendingTasks: Todo.list.filter(task => !task.done).length
    onLiveChanged: if (page.live) ResourceUsage.ensureRunning()
    spacing: 0

    component Entry: RowLayout {
        id: entry
        property string name: ""
        default property alias content: body.data
        Layout.fillWidth: true
        Layout.topMargin: Math.round(10 * page.d)
        spacing: 0
        IrisText {
            Layout.preferredWidth: page.margin
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: Math.round(2 * page.d)
            text: Translation.tr(entry.name).toUpperCase()
            font.pixelSize: Math.round(9 * page.d)
            font.weight: IrisStyle.weight(Font.Bold)
            font.letterSpacing: 1.1
            color: IrisStyle.textTertiary
            elide: Text.ElideRight
        }
        Item {
            id: body
            Layout.fillWidth: true
            implicitHeight: childrenRect.height
        }
    }
    component Rule: Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: Math.round(10 * page.d)
        implicitHeight: 1
        color: IrisStyle.hairline
    }
    component Figure: Column {
        id: figure
        property string value: ""
        property string unit: ""
        property string label: ""
        Row {
            spacing: Math.round(2 * page.d)
            IrisText {
                id: figureValue
                text: figure.value
                font.pixelSize: Math.round(22 * page.d)
                font.family: IrisStyle.fontNumbers
                font.weight: IrisStyle.weight(Font.DemiBold)
                font.features: ({ "tnum": 1 })
            }
            IrisText {
                anchors.baseline: figureValue.baseline
                text: figure.unit
                font.pixelSize: IrisStyle.typeMeta
                color: IrisStyle.subtext
            }
        }
        IrisText {
            text: Translation.tr(figure.label)
            font.pixelSize: IrisStyle.typeMeta
            color: IrisStyle.textTertiary
        }
    }

    // The day, large.
    RowLayout {
        Layout.fillWidth: true
        spacing: Math.round(12 * page.d)
        ColumnLayout {
            spacing: 0
            IrisText {
                text: Translation.locale.toString(page.now, "dddd").toUpperCase()
                font.pixelSize: Math.round(10 * page.d)
                font.weight: IrisStyle.weight(Font.Bold)
                font.letterSpacing: 1.4
                color: IrisStyle.clockAccent
            }
            IrisText {
                text: Translation.locale.toString(page.now, "d MMMM")
                font.pixelSize: IrisStyle.typeTitle
                font.weight: IrisStyle.weight(Font.DemiBold)
            }
        }
        Item { Layout.fillWidth: true }
        IrisClock {
            Layout.alignment: Qt.AlignBottom
            pixelSize: Math.round(46 * page.d)
            separatorColor: IrisStyle.clockAccent
        }
    }
    Rule {}

    Entry {
        name: "Today"
        IrisText {
            width: parent.width
            text: page.nextEvent ? String(page.nextEvent.title ?? "")
                : page.pendingTasks > 0 ? Translation.tr("%1 tasks waiting").arg(page.pendingTasks)
                : Translation.tr("Nothing on the calendar")
            font.pixelSize: IrisStyle.typeBody
            font.weight: IrisStyle.weight(Font.Medium)
            elide: Text.ElideRight
        }
        IrisText {
            y: Math.round(20 * page.d)
            visible: page.nextEvent !== null
            width: parent.width
            text: {
                if (!page.nextEvent) return ""
                const when = new Date(page.nextEvent.dateTime)
                const days = Math.round((new Date(when).setHours(0, 0, 0, 0) - new Date(page.now).setHours(0, 0, 0, 0)) / 86400000)
                const time = Translation.locale.toString(when, Config.options?.time?.format ?? "hh:mm")
                return days === 0 ? Translation.tr("Today · %1").arg(time) : days === 1 ? Translation.tr("Tomorrow · %1").arg(time)
                    : Translation.locale.toString(when, "dddd") + " · " + time
            }
            font.pixelSize: IrisStyle.typeMeta
            color: IrisStyle.subtext
        }
    }
    Rule { visible: page.weatherReady }
    Entry {
        name: "Sky"
        visible: page.weatherReady
        Row {
            width: parent.width
            Repeater {
                model: page.hours
                delegate: Column {
                    id: hour
                    required property var modelData
                    required property int index
                    width: Math.floor(parent.width / Math.max(1, page.hours.length))
                    spacing: Math.round(4 * page.d)
                    IrisText {
                        text: hour.index === 0 ? Translation.tr("Now") : String(hour.modelData.label ?? "")
                        font.pixelSize: IrisStyle.typeMeta
                        color: hour.index === 0 ? IrisStyle.text : IrisStyle.textTertiary
                        font.weight: IrisStyle.weight(hour.index === 0 ? Font.DemiBold : Font.Normal)
                    }
                    MaterialSymbol {
                        text: Icons.getWeatherIcon(hour.modelData.code, hour.modelData.isNight) ?? "cloud"
                        iconSize: Math.round(16 * page.d)
                        fill: 1
                        color: IrisStyle.skyLight(text)
                    }
                    IrisText {
                        text: String(hour.modelData.temp ?? "").replace(/[CF]$/, "")
                        font.pixelSize: IrisStyle.typeBody
                        font.family: IrisStyle.fontNumbers
                        font.features: ({ "tnum": 1 })
                    }
                }
            }
        }
    }
    Rule {}
    Entry {
        name: "Machine"
        Row {
            width: parent.width
            spacing: Math.round(22 * page.d)
            Figure { value: String(Math.round(ResourceUsage.cpuUsage * 100)); unit: "%"; label: "Processor" }
            Figure { value: String(Math.round(ResourceUsage.memoryUsedPercentage * 100)); unit: "%"; label: "Memory" }
            Figure { value: String(DateTime.uptime).split(",")[0]; unit: ""; label: "Up" }
            Figure {
                visible: Battery.available
                value: String(Math.round(Battery.percentage * 100)); unit: "%"; label: Battery.isCharging ? "Charging" : "Battery"
            }
        }
    }
    Rule {}
    Entry {
        name: "You"
        Layout.bottomMargin: Math.round(2 * page.d)
        Row {
            width: parent.width
            spacing: Math.round(10 * page.d)
            IrisArtwork {
                width: Math.round(30 * page.d)
                height: width
                circular: true
                source: Directories.avatarSourceAt(0)
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Math.round(40 * page.d) - actions.width
                IrisText {
                    width: parent.width
                    text: SystemInfo.displayName || SystemInfo.username || "user"
                    font.pixelSize: IrisStyle.typeBody
                    font.weight: IrisStyle.weight(Font.DemiBold)
                    elide: Text.ElideRight
                }
                IrisText {
                    width: parent.width
                    text: (SystemInfo.username || "user") + "@" + String(SystemInfo.hostname ?? "")
                    font.pixelSize: IrisStyle.typeMeta
                    font.family: IrisStyle.fontMono
                    color: IrisStyle.textTertiary
                    elide: Text.ElideRight
                }
            }
            Row {
                id: actions
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(2 * page.d)
                Repeater {
                    model: [{ glyph: "wallpaper", label: "Wallpaper" }, { glyph: "lock", label: "Lock" }, { glyph: "power_settings_new", label: "Session" }]
                    delegate: IrisIconButton {
                        required property var modelData
                        materialIcon: modelData.glyph
                        Accessible.name: Translation.tr(modelData.label)
                        onClicked: {
                            page.island.expanded = false
                            if (modelData.glyph === "wallpaper") GlobalStates.wallpaperSelectorOpen = true
                            else if (modelData.glyph === "lock") Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "lock", "activate"])
                            else GlobalStates.sessionOpen = true
                        }
                    }
                }
            }
        }
    }
}
