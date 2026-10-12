pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.pieces
import qs.modules.iris.bar
import "../components"

// AIRISU's desktop page: the shop's work order for the day (作業伝票), on the engine's blocks, in the order and with the
// blocks Settings keeps. The head is the day set in the wide face, the date as its ruby, the wallpaper printed under it
// in one ink as a halftone; the forecast is a station timetable whose current column is the solid plate; the window
// in front is the job, its workspace a station number; the vitals are a spec sheet; the next date is a form box. While
// the page is being arranged the engine's own page stands in, so moving blocks works the same in every Design.
GridLayout {
    id: page
    property Item island: null
    readonly property real d: Airisu.d
    readonly property bool current: page.island?.effectivePage === "desktop"
    readonly property bool live: page.current && (page.island?.visualExpanded ?? false)
    // The engine reads these from its own page; this page prints inside the body and never bleeds.
    readonly property bool showBanner: false
    columns: 1
    rowSpacing: Airisu.u(4)
    columnSpacing: 0

    readonly property var blocks: page.island?.desktopBlocks ?? []
    readonly property var workspaces: CompositorService.isNiri
        ? (NiriService.allWorkspaces ?? []).filter(ws => ws.output === page.island?.targetScreen?.name) : []
    readonly property var activeWorkspace: page.workspaces.find(ws => ws.is_active) ?? null
    readonly property var focusedWindow: {
        const ws = page.activeWorkspace
        if (!ws) return null
        const onWorkspace = (NiriService.windows ?? []).filter(w => w.workspace_id === ws.id)
        const stamp = w => (w.focus_timestamp?.secs ?? 0) * 1e9 + (w.focus_timestamp?.nanos ?? 0)
        return onWorkspace.find(w => w.id === ws.active_window_id)
            ?? onWorkspace.slice().sort((a, b) => stamp(b) - stamp(a))[0] ?? null
    }
    readonly property var customModules: ["left", "center", "right"]
        .reduce((all, slot) => all.concat(page.island?.options?.[slot + "Modules"] ?? []), [])
        .filter(id => String(id).startsWith("custom:"))
    readonly property bool weatherReady: Weather.enabled && !String(Weather.data?.temp ?? "--").startsWith("--")
    readonly property var hours: Array.from(Weather.data?.hourly ?? []).slice(0, 6)
    readonly property var nextEvent: {
        void DateTime.clock.date
        return Events.getUpcomingEvents(7)[0] ?? null
    }
    readonly property int pendingTasks: Todo.list.filter(task => !task.done).length
    readonly property string banner: String(page.island?.options?.desktopBanner ?? "wallpaper") === "wallpaper"
        ? WallpaperListener.wallpaperUrlForScreen(page.island?.targetScreen) : ""
    function available(kind: string): bool {
        if (kind === "context") return page.focusedWindow !== null || page.workspaces.length > 1
        if (kind === "modules") return page.customModules.length > 0
        if (kind === "forecast") return page.weatherReady && page.hours.length > 1
        if (kind === "agenda") return page.nextEvent !== null || page.pendingTasks > 0
        return (page.island?.desktopBlockKinds ?? []).includes(kind)
    }
    readonly property var rows: page.blocks.filter(kind => page.available(kind))
    function rowOf(kind: string): int { return page.rows.indexOf(kind) + 1 }
    function shows(kind: string): bool { return page.rows.includes(kind) }
    function closeAnd(action): void { if (page.island) page.island.expanded = false; action() }

    // A small mark: AIRISU draws marks, it does not plate them.
    component Mark: MaterialSymbol {
        iconSize: Math.round(17 * page.d)
        fill: 0
        color: Airisu.ink
    }
    // A key that is only its mark, in a tag's rule (the Button skin draws the die, the crop marks and the press).
    component Key: IrisButton {
        id: key
        property string glyph
        implicitWidth: Math.round(32 * page.d)
        implicitHeight: Math.round(30 * page.d)
        MaterialSymbol {
            anchors.centerIn: parent
            text: key.glyph
            iconSize: Math.round(17 * page.d)
            fill: 0
            color: key.danger ? Airisu.danger : Airisu.ink
        }
    }
    // A station number: the disc with its ring, a workspace's index inside. The chosen one is the solid plate.
    component Station: Item {
        id: station
        property string figure
        property bool chosen: false
        property bool faint: false
        property real side: Math.round(22 * page.d)
        implicitWidth: station.side
        implicitHeight: station.side
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: station.chosen ? Airisu.ink : Airisu.ground
            border.width: station.chosen ? 0 : Math.max(Airisu.hair, Math.round(station.side * 0.09))
            border.color: station.faint ? Airisu.inkThird : Airisu.ink
        }
        AText {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: Math.round(station.side * 0.03)
            size: Math.round(station.side * (station.figure.length > 1 ? 0.42 : 0.5))
            font.weight: Font.Bold
            text: station.figure
            color: station.chosen ? Airisu.reverse : station.faint ? Airisu.inkThird : Airisu.ink
        }
    }

    // ── The head: the day, the time and the weather, over the wallpaper printed in one ink.
    Item {
        id: head
        Layout.row: 0
        Layout.fillWidth: true
        implicitHeight: Math.round(122 * page.d)

        AHalftone {
            anchors.fill: parent
            visible: page.banner.length > 0
            source: page.live || ready ? page.banner : ""
            ink: ColorUtils.mix(Airisu.ink, Airisu.ground, 0.34) // iris-literal: the poster's one ink, under the third
            cell: Math.max(4, Math.round(4 * page.d))
            // A night picture is mostly shadow: the screen is opened up so its lights print as a picture, not as dust.
            gain: 2.2
            fadeFrom: 0.0
            fadeTo: 0.55
        }
        // The rule that closes a head, the full measure.
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: Airisu.strong
            color: Airisu.ruleStrong
        }

        Column {
            id: day
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Airisu.u(3)
            spacing: 0
            AText {
                voice: "ruby"
                size: IrisStyle.typeLabel
                text: Translation.locale.toString(DateTime.clock.date, "dddd · d MMMM")
                color: Airisu.inkSecond
            }
            Row {
                id: time
                readonly property real size: Math.round(2 * IrisStyle.typeDisplay)
                readonly property var parts: String(DateTime.timeDisplay).split(":")
                spacing: Math.round(time.size * 0.1)
                AText {
                    anchors.verticalCenter: parent.verticalCenter
                    voice: "figure"
                    size: time.size
                    text: time.parts[0] ?? ""
                }
                // The colon is two seal squares, as on the strip.
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: Math.round(time.size * 0.05)
                    spacing: Math.round(time.size * 0.2)
                    Repeater {
                        model: 2
                        Rectangle {
                            width: Math.round(time.size * 0.13)
                            height: width
                            color: Airisu.seal
                        }
                    }
                }
                AText {
                    anchors.verticalCenter: parent.verticalCenter
                    voice: "figure"
                    size: time.size
                    text: (time.parts[1] ?? "").trim()
                }
            }
        }

        // The weather: the figure with its unit set small against it, the sky as its ruby.
        Column {
            visible: page.weatherReady
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Airisu.u(3) + Math.round(time.size * 0.12)
            spacing: 0
            Row {
                anchors.right: parent.right
                spacing: Airisu.u(1)
                Mark {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
                    iconSize: IrisStyle.typeLabel
                    color: Airisu.inkSecond
                }
                AText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, Math.round(130 * page.d))
                    voice: "ruby"
                    size: IrisStyle.typeMeta
                    text: String(Weather.data?.description ?? "")
                }
            }
            Row {
                anchors.right: parent.right
                readonly property string raw: String(Weather.data?.temp ?? "")
                readonly property string figure: raw.replace(/°?[CF]$/, "")
                AText {
                    id: temperature
                    voice: "figure"
                    size: IrisStyle.typeDisplay
                    text: parent.figure
                }
                AText {
                    anchors.baseline: temperature.baseline
                    size: IrisStyle.typeLabel
                    font.weight: Font.Bold
                    text: parent.raw.slice(parent.figure.length)
                }
            }
        }

        // What the page itself does: arrange its blocks, change the picture it prints.
        Row {
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: Airisu.u(1)
            Key {
                glyph: "edit"
                quiet: true
                Accessible.name: Translation.tr("Arrange this page")
                onClicked: {
                    if (page.island) page.island.pinned = true
                    GlobalStates.irisArrange = true
                }
            }
            Key {
                visible: page.banner.length > 0
                glyph: "wallpaper"
                quiet: true
                Accessible.name: Translation.tr("Change wallpaper")
                onClicked: {
                    GlobalStates.wallpaperSelectorTargetMonitor = page.island?.targetScreen?.name ?? ""
                    GlobalStates.wallpaperSelectorOpen = true
                }
            }
        }
    }

    // ── Profile: whose machine this is, the avatar cut as a disc; locking and the session are tags.
    RowLayout {
        Layout.row: Math.max(1, page.rowOf("profile"))
        Layout.fillWidth: true
        visible: page.shows("profile")
        spacing: Airisu.u(3)
        Item {
            id: avatar
            Layout.preferredWidth: Math.round(40 * page.d)
            Layout.preferredHeight: Layout.preferredWidth
            property int sourceIndex: 0
            readonly property string primarySource: Directories.userAvatarSourcePrimary
            onPrimarySourceChanged: avatar.sourceIndex = 0
            Accessible.role: Accessible.Button
            Accessible.name: Translation.tr("Change profile picture")
            HoverHandler { id: avatarHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { gesturePolicy: TapHandler.WithinBounds; onTapped: page.island?.chooseAvatar() }
            ClippingRectangle {
                anchors.fill: parent
                radius: width / 2
                color: Airisu.groundRaised
                IrisImage {
                    id: avatarImage
                    anchors.fill: parent
                    source: Directories.avatarSourceAt(avatar.sourceIndex)
                    onStatusChanged: {
                        if (status === Image.Error && avatar.sourceIndex + 1 < Directories.userAvatarPaths.length)
                            Qt.callLater(() => avatar.sourceIndex++)
                    }
                }
                AText {
                    anchors.centerIn: parent
                    visible: avatarImage.status !== Image.Ready
                    voice: "figure"
                    text: (SystemInfo.displayName || SystemInfo.username || "?").charAt(0).toUpperCase()
                }
            }
            ATombo { anchors.fill: parent; shown: avatarHover.hovered }
        }
        Column {
            Layout.fillWidth: true
            spacing: 0
            AText {
                width: parent.width
                voice: "ruby"
                readonly property string distro: String(SystemInfo.distroId ?? "").trim()
                text: (SystemInfo.username || "user") + (distro.length > 0 && distro !== "unknown" ? "@" + distro : "")
                    + " · " + Translation.tr("Up %1").arg(DateTime.uptime)
            }
            AText {
                width: parent.width
                size: IrisStyle.typeLabel
                font.weight: Font.Bold
                text: SystemInfo.displayName || SystemInfo.username || "user"
            }
        }
        Key {
            glyph: "lock"
            Accessible.name: Translation.tr("Lock")
            onClicked: page.closeAnd(() => Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "lock", "activate"]))
        }
        Key {
            glyph: "power_settings_new"
            Accessible.name: Translation.tr("Session")
            onClicked: page.closeAnd(() => GlobalStates.sessionOpen = true)
        }
    }

    // ── The job: the window in front, its app as ruby over its title; the workspaces are station numbers.
    RowLayout {
        id: job
        Layout.row: Math.max(1, page.rowOf("context"))
        Layout.fillWidth: true
        visible: page.shows("context")
        spacing: Airisu.u(3)
        readonly property var entry: AppSearch.lookupDesktopEntry(page.focusedWindow?.app_id ?? "")
        readonly property string workspaceName: page.activeWorkspace
            ? (String(page.activeWorkspace.name ?? "").length > 0 ? page.activeWorkspace.name
                : Translation.tr("Workspace %1").arg(page.activeWorkspace.idx)) : ""
        Item {
            Layout.preferredWidth: Math.round(40 * page.d)
            Layout.preferredHeight: Math.round(32 * page.d)
            SmartAppIcon {
                visible: page.focusedWindow !== null
                anchors.centerIn: parent
                icon: IrisPieces.appIcon(page.focusedWindow?.app_id ?? "")
                fallback: "application-x-executable"
                iconSize: Math.round(30 * page.d)
            }
            Mark {
                visible: page.focusedWindow === null
                anchors.centerIn: parent
                text: "desktop_windows"
                color: Airisu.inkThird
            }
        }
        Column {
            Layout.fillWidth: true
            spacing: 0
            AText {
                width: parent.width
                voice: "ruby"
                readonly property string app: job.entry?.name ?? String(page.focusedWindow?.app_id ?? "")
                text: page.focusedWindow ? app + (job.workspaceName.length > 0 ? " · " + job.workspaceName : "")
                    : Translation.tr("No windows")
            }
            AText {
                width: parent.width
                size: IrisStyle.typeLabel
                font.weight: Font.Bold
                text: page.focusedWindow ? String(page.focusedWindow.title ?? "") : job.workspaceName
            }
        }
        Row {
            visible: page.workspaces.length > 1
            spacing: Airisu.u(1)
            Repeater {
                model: page.workspaces.slice(0, 9)
                MouseArea {
                    id: stop
                    required property var modelData
                    readonly property bool occupied: (NiriService.windows ?? []).some(w => w.workspace_id === stop.modelData.id)
                    width: number.implicitWidth
                    height: number.implicitHeight
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.Button
                    Accessible.name: Translation.tr("Workspace %1").arg(stop.modelData.idx)
                    onClicked: NiriService.switchToWorkspaceById(stop.modelData.id)
                    Station {
                        id: number
                        figure: String(stop.modelData.idx)
                        chosen: stop.modelData.is_active
                        faint: !stop.occupied && !stop.modelData.is_active
                    }
                    ATombo { anchors.fill: parent; shown: stop.containsMouse && !stop.modelData.is_active; air: Airisu.hair; length: Airisu.m }
                }
            }
        }
    }

    // ── The forecast as a station timetable: the hour at the head of each column, the sky, the figure; the column
    // that is now is printed solid. The rules are the timetable's own.
    Item {
        Layout.row: Math.max(1, page.rowOf("forecast"))
        Layout.fillWidth: true
        visible: page.shows("forecast")
        implicitHeight: Math.round(76 * page.d)
        Rectangle { width: parent.width; height: Airisu.hair; color: Airisu.ink }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Airisu.hair; color: Airisu.ink }
        Row {
            anchors.fill: parent
            Repeater {
                model: page.hours
                Item {
                    id: hour
                    required property var modelData
                    required property int index
                    readonly property bool now: hour.index === 0
                    readonly property color ink: hour.now ? Airisu.reverse : Airisu.ink
                    width: Math.floor(parent.width / Math.max(1, page.hours.length))
                    height: parent.height
                    Accessible.name: hour.modelData.label + ", " + hour.modelData.temp
                    Rectangle {
                        anchors.fill: parent
                        visible: hour.now
                        color: Airisu.ink
                    }
                    Rectangle {
                        visible: hour.index > 0
                        width: Airisu.hair
                        height: parent.height
                        color: Airisu.rule
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: Airisu.u(1)
                        AText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            voice: "data"
                            size: IrisStyle.typeCaption
                            text: hour.now ? Translation.tr("Now") : String(hour.modelData.label).slice(0, 2)
                            color: hour.now ? hour.ink : Airisu.inkSecond
                        }
                        Mark {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Icons.getWeatherIcon(hour.modelData.code, hour.modelData.isNight) ?? "cloud"
                            iconSize: Math.round(18 * page.d)
                            color: hour.ink
                        }
                        AText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            voice: "figure"
                            size: IrisStyle.typeLabel
                            text: String(hour.modelData.temp)
                            color: hour.ink
                        }
                    }
                }
            }
        }
    }

    // ── The next date: a form box with the day in it, what it is and when; open tasks are a tag beside it.
    RowLayout {
        id: agenda
        Layout.row: Math.max(1, page.rowOf("agenda"))
        Layout.fillWidth: true
        visible: page.shows("agenda")
        spacing: Airisu.u(3)
        readonly property var event: page.nextEvent
        readonly property date when: agenda.event ? new Date(agenda.event.dateTime) : DateTime.clock.date
        readonly property string whenText: {
            if (!agenda.event) return ""
            const now = DateTime.clock.date
            const minutes = Math.round((agenda.when.getTime() - now.getTime()) / 60000)
            const time = Qt.locale().toString(agenda.when, Qt.locale().timeFormat(Locale.ShortFormat))
            if (minutes < 1) return Translation.tr("Now")
            if (minutes < 60) return Translation.tr("In %1 min").arg(minutes)
            const today = new Date(now); today.setHours(0, 0, 0, 0)
            const day = new Date(agenda.when); day.setHours(0, 0, 0, 0)
            const days = Math.round((day.getTime() - today.getTime()) / 86400000)
            if (days === 0) return Translation.tr("Today · %1").arg(time)
            if (days === 1) return Translation.tr("Tomorrow · %1").arg(time)
            return Translation.locale.toString(agenda.when, "dddd") + " · " + time
        }
        // A Sunday is printed in the seal, as calendars here do.
        readonly property bool sunday: agenda.when.getDay() === 0
        Item {
            Layout.preferredWidth: Math.round(44 * page.d)
            Layout.preferredHeight: Layout.preferredWidth
            ADie {
                anchors.fill: parent
                kind: "rect"
                stroke: Airisu.ink
                strokeWidth: Airisu.hair
            }
            Rectangle {
                id: weekday
                width: parent.width
                height: Math.round(parent.height * 0.32)
                color: agenda.sunday ? Airisu.seal : Airisu.ink
                AText {
                    anchors.centerIn: parent
                    size: IrisStyle.typeCaption
                    font.weight: Font.Bold
                    text: Translation.locale.toString(agenda.when, "ddd").replace(/\./g, "")
                    color: agenda.sunday ? Airisu.inkOnSeal : Airisu.reverse
                }
            }
            AText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: weekday.bottom
                anchors.topMargin: Airisu.hair
                voice: "figure"
                size: IrisStyle.typeTitle
                text: agenda.when.getDate()
            }
        }
        Column {
            Layout.fillWidth: true
            spacing: 0
            AText {
                width: parent.width
                voice: "ruby"
                text: agenda.event ? agenda.whenText : Translation.tr("This week is clear")
            }
            AText {
                width: parent.width
                size: IrisStyle.typeLabel
                font.weight: Font.Bold
                text: agenda.event ? String(agenda.event.title || Translation.tr("Event")) : Translation.tr("Nothing scheduled")
            }
        }
        IrisButton {
            id: tasks
            visible: page.pendingTasks > 0
            implicitHeight: Math.round(30 * page.d)
            implicitWidth: tasksRow.implicitWidth + Airisu.u(5)
            Accessible.name: Translation.tr("%1 open tasks").arg(page.pendingTasks)
            onClicked: page.closeAnd(() => GlobalStates.sidebarRightOpen = true)
            Row {
                id: tasksRow
                anchors.centerIn: parent
                spacing: Airisu.u(1)
                Mark { anchors.verticalCenter: parent.verticalCenter; text: "checklist"; iconSize: Math.round(16 * page.d) }
                AText {
                    anchors.verticalCenter: parent.verticalCenter
                    voice: "figure"
                    size: IrisStyle.typeLabel
                    text: page.pendingTasks
                }
            }
        }
        Key {
            glyph: "chevron_right"
            quiet: true
            Accessible.name: Translation.tr("Open Today")
            onClicked: page.closeAnd(() => GlobalStates.sidebarRightOpen = true)
        }
    }

    // ── Vitals as a spec sheet: four columns, the name as ruby, the figure with its unit, and under it how full it is
    // as a rule run on a screen. Past its warning a vital prints in caution.
    Item {
        id: sheet
        Layout.row: Math.max(1, page.rowOf("vitals"))
        Layout.fillWidth: true
        visible: page.shows("vitals")
        implicitHeight: Math.round(52 * page.d)
        readonly property bool polling: page.live && sheet.visible
        property bool holding: false
        onPollingChanged: {
            if (polling && !holding) { ResourceUsage.keepAlive(); holding = true }
            else if (!polling && holding) { ResourceUsage.releaseKeepAlive(); holding = false }
        }
        Component.onDestruction: if (holding) ResourceUsage.releaseKeepAlive()
        Row {
            anchors.fill: parent
            spacing: Airisu.u(3)
            Repeater {
                model: [
                    { label: Translation.tr("CPU"), level: ResourceUsage.cpuUsage, value: Math.round(ResourceUsage.cpuUsage * 100), unit: "%", warn: 0.85 },
                    { label: Translation.tr("Memory"), level: ResourceUsage.memoryUsedPercentage, value: Math.round(ResourceUsage.memoryUsedPercentage * 100), unit: "%", warn: 0.85 },
                    { label: Translation.tr("Heat"), level: ResourceUsage.tempPercentage, value: ResourceUsage.maxTemp, unit: "°", warn: ResourceUsage.tempWarningThreshold / 100 },
                    { label: Translation.tr("Disk"), level: ResourceUsage.diskUsedPercentage, value: Math.round(ResourceUsage.diskUsedPercentage * 100), unit: "%", warn: 0.9 }
                ]
                Item {
                    id: vital
                    required property var modelData
                    readonly property real level: Math.max(0, Math.min(1, Number(vital.modelData.level) || 0))
                    readonly property bool warned: vital.level >= vital.modelData.warn
                    readonly property color ink: vital.warned ? Airisu.caution : Airisu.ink
                    width: Math.floor((parent.width - 3 * parent.spacing) / 4)
                    height: parent.height
                    Accessible.name: vital.modelData.label + ", " + vital.modelData.value + vital.modelData.unit
                    AText {
                        voice: "ruby"
                        width: parent.width
                        text: vital.modelData.label
                    }
                    Row {
                        y: Math.round(14 * page.d)
                        AText {
                            id: figure
                            voice: "figure"
                            size: IrisStyle.typeTitle
                            text: vital.modelData.value
                            color: vital.ink
                        }
                        AText {
                            anchors.baseline: figure.baseline
                            size: IrisStyle.typeMeta
                            font.weight: Font.Bold
                            text: vital.modelData.unit
                            color: vital.ink
                        }
                    }
                    Item {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Airisu.m
                        AScreen {
                            anchors.fill: parent
                            pigment: Airisu.inkThird
                            density: 25
                        }
                        Rectangle {
                            width: Math.round(parent.width * vital.level)
                            height: parent.height
                            color: vital.ink
                            Behavior on width { enabled: Airisu.moving; NumberAnimation { duration: Airisu.detent } }
                        }
                    }
                }
            }
        }
    }

    // ── The scripts' own modules, as they draw themselves.
    Flow {
        Layout.row: Math.max(1, page.rowOf("modules"))
        Layout.fillWidth: true
        visible: page.shows("modules")
        spacing: Airisu.u(1.5)
        Repeater {
            model: page.shows("modules") ? page.customModules : []
            IrisCustomModule {
                required property string modelData
                widgetId: modelData.slice("custom:".length)
                targetScreen: page.island?.targetScreen ?? null
                slot: "island.desktop"
            }
        }
    }
}
