pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// Tiles' desktop page: the day and the sky on one tile, the switches you reach for most, what is next, the machine,
// and you. Every tile is a quiet plate on the Island's body.
GridLayout {
    id: page
    property Item island: null
    readonly property real d: IrisStyle.density
    readonly property bool showBanner: false
    readonly property bool live: page.island?.effectivePage === "desktop" && (page.island?.visualExpanded ?? false)
    readonly property date now: DateTime.clock.date
    readonly property real pad: Math.round(12 * page.d)
    readonly property bool weatherReady: Weather.enabled && !String(Weather.data?.temp ?? "--").startsWith("--")
    readonly property var nextEvent: {
        void DateTime.clock.date
        return Events.getUpcomingEvents(7)[0] ?? null
    }
    readonly property int pendingTasks: Todo.list.filter(task => !task.done).length
    onLiveChanged: if (page.live) ResourceUsage.ensureRunning()
    columns: 2
    rowSpacing: Math.round(8 * page.d)
    columnSpacing: Math.round(8 * page.d)

    component Tile: Rectangle {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        radius: IrisStyle.radiusTile
        color: IrisStyle.fillQuiet
    }
    component Eyebrow: IrisText {
        font.pixelSize: Math.round(10 * page.d)
        font.weight: IrisStyle.weight(Font.DemiBold)
        color: IrisStyle.textTertiary
    }
    component Bar: Item {
        id: bar
        property real value: 0
        property string label: ""
        width: parent.width
        height: Math.round(26 * page.d)
        IrisText {
            text: Translation.tr(bar.label)
            font.pixelSize: IrisStyle.typeMeta
            color: IrisStyle.subtext
        }
        IrisText {
            anchors.right: parent.right
            text: Math.round(bar.value * 100) + "%"
            font.pixelSize: IrisStyle.typeMeta
            font.family: IrisStyle.fontNumbers
            font.features: ({ "tnum": 1 })
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: Math.round(4 * page.d)
            radius: height / 2
            color: IrisStyle.fillHoverOf(IrisStyle.text)
            Rectangle {
                width: parent.width * Math.max(0.02, Math.min(1, bar.value))
                height: parent.height
                radius: height / 2
                color: bar.value > 0.85 ? IrisStyle.danger : bar.value > 0.65 ? IrisStyle.warning : IrisStyle.accent
                Behavior on width { NumberAnimation { duration: IrisStyle.duration(300); easing.type: IrisStyle.feedbackEasing } }
            }
        }
    }

    // The day and the sky.
    Tile {
        Layout.columnSpan: 2
        implicitHeight: Math.round(84 * page.d)
        IrisClock {
            id: bigClock
            x: page.pad
            y: Math.round(8 * page.d)
            pixelSize: Math.round(40 * page.d)
            separatorColor: IrisStyle.clockAccent
        }
        IrisText {
            x: page.pad
            anchors.top: bigClock.bottom
            text: Translation.locale.toString(page.now, "dddd, d MMMM")
            font.pixelSize: IrisStyle.typeMeta
            color: IrisStyle.subtext
        }
        Row {
            visible: page.weatherReady
            anchors.right: parent.right
            anchors.rightMargin: page.pad
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(8 * page.d)
            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
                iconSize: Math.round(34 * page.d)
                fill: 1
                color: IrisStyle.skyLight(text)
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                IrisText {
                    text: String(Weather.data?.temp ?? "").replace(/[CF]$/, "")
                    font.pixelSize: IrisStyle.typeTitle
                    font.family: IrisStyle.fontNumbers
                    font.weight: IrisStyle.weight(Font.DemiBold)
                }
                IrisText {
                    text: String(Weather.data?.description ?? "")
                    font.pixelSize: IrisStyle.typeMeta
                    color: IrisStyle.subtext
                }
            }
        }
    }

    // The switches.
    Tile {
        Layout.columnSpan: 2
        implicitHeight: Math.round(74 * page.d)
        Row {
            anchors.centerIn: parent
            spacing: Math.round(14 * page.d)
            Repeater {
                model: [
                    { glyph: "wifi", label: "Wi-Fi", on: Network.wifiEnabled },
                    { glyph: "bluetooth", label: "Bluetooth", on: BluetoothStatus.enabled, shown: BluetoothStatus.available },
                    { glyph: "do_not_disturb_on", label: "Silent", on: Notifications.silent },
                    { glyph: "nightlight", label: "Night", on: Hyprsunset.active },
                    { glyph: "coffee", label: "Awake", on: Idle.inhibit }
                ].filter(entry => entry.shown !== false)
                delegate: Column {
                    id: toggle
                    required property var modelData
                    spacing: Math.round(4 * page.d)
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.round(38 * page.d)
                        height: width
                        radius: width / 2
                        color: toggle.modelData.on ? IrisStyle.accent : tap.hovered ? IrisStyle.fillHoverOf(IrisStyle.text) : IrisStyle.fillQuiet
                        scale: press.pressed ? IrisStyle.pressScale(0.9) : 1
                        Behavior on color { ColorAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
                        Behavior on scale { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: toggle.modelData.glyph
                            iconSize: Math.round(18 * page.d)
                            fill: toggle.modelData.on ? 1 : 0
                            color: toggle.modelData.on ? IrisStyle.onTint : IrisStyle.text
                        }
                        HoverHandler { id: tap; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            id: press
                            onTapped: {
                                const glyph = toggle.modelData.glyph
                                if (glyph === "wifi") Network.toggleWifi()
                                else if (glyph === "bluetooth") { if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled }
                                else if (glyph === "do_not_disturb_on") Notifications.silent = !Notifications.silent
                                else if (glyph === "nightlight") Hyprsunset.toggle()
                                else Idle.toggleInhibit()
                            }
                        }
                        Accessible.role: Accessible.Button
                        Accessible.name: Translation.tr(toggle.modelData.label)
                    }
                    IrisText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Translation.tr(toggle.modelData.label)
                        font.pixelSize: Math.round(10 * page.d)
                        color: IrisStyle.subtext
                    }
                }
            }
        }
    }

    // What is next.
    Tile {
        implicitHeight: Math.round(88 * page.d)
        Column {
            x: page.pad
            y: page.pad
            width: parent.width - 2 * page.pad
            spacing: Math.round(4 * page.d)
            Eyebrow { text: Translation.tr("Next") }
            IrisText {
                width: parent.width
                text: page.nextEvent ? String(page.nextEvent.title ?? "")
                    : page.pendingTasks > 0 ? Translation.tr("%1 tasks waiting").arg(page.pendingTasks)
                    : Translation.tr("Nothing on the calendar")
                font.pixelSize: IrisStyle.typeBody
                font.weight: IrisStyle.weight(Font.DemiBold)
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            IrisText {
                visible: page.nextEvent !== null
                text: page.nextEvent ? Translation.locale.toString(new Date(page.nextEvent.dateTime), "ddd " + (Config.options?.time?.format ?? "hh:mm")) : ""
                font.pixelSize: IrisStyle.typeMeta
                color: IrisStyle.clockAccent
            }
        }
    }

    // The machine.
    Tile {
        implicitHeight: Math.round(88 * page.d)
        Column {
            x: page.pad
            y: page.pad
            width: parent.width - 2 * page.pad
            spacing: Math.round(4 * page.d)
            Eyebrow { text: Translation.tr("Machine") }
            Bar { value: ResourceUsage.cpuUsage; label: "Processor" }
            Bar { value: ResourceUsage.memoryUsedPercentage; label: "Memory" }
        }
    }

    // You.
    Tile {
        Layout.columnSpan: 2
        implicitHeight: Math.round(52 * page.d)
        IrisArtwork {
            id: avatar
            x: page.pad
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(30 * page.d)
            height: width
            circular: true
            source: Directories.avatarSourceAt(0)
        }
        Column {
            anchors.left: avatar.right
            anchors.leftMargin: Math.round(10 * page.d)
            anchors.right: actions.left
            anchors.verticalCenter: parent.verticalCenter
            IrisText {
                width: parent.width
                text: SystemInfo.displayName || SystemInfo.username || "user"
                font.pixelSize: IrisStyle.typeBody
                font.weight: IrisStyle.weight(Font.DemiBold)
                elide: Text.ElideRight
            }
            IrisText {
                width: parent.width
                text: Translation.tr("Up %1").arg(DateTime.uptime)
                font.pixelSize: IrisStyle.typeMeta
                color: IrisStyle.textTertiary
                elide: Text.ElideRight
            }
        }
        Row {
            id: actions
            anchors.right: parent.right
            anchors.rightMargin: Math.round(6 * page.d)
            anchors.verticalCenter: parent.verticalCenter
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
