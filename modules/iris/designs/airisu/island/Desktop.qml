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

// AIRISU's desktop page, on the engine's blocks, in the order and with the blocks Settings keeps. The head is a panel of
// time's lacquer whose second coat is the part of the hour gone, as on the desk clock, with the day's time set
// large and leaning on it; when Settings puts the wallpaper there it is seen through the lacquer, as shunkei-nuri shows
// the grain of the wood. Below it, everything is cut out of the body's ink: whose machine it is, the window in front with
// the workspaces as keys, the forecast with the hour that is now on the chosen plate, the next date on a small panel of
// its own, the vitals each with its run. While the page is being arranged the engine's own page stands in.
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

    // A small mark: AIRISU cuts marks out of the ink, it does not plate them.
    component Mark: MaterialSymbol {
        iconSize: Math.round(17 * page.d)
        fill: 0
        color: Airisu.ink
    }
    // A key that is only its mark (the Button skin draws the die, its coat and the press).
    component Key: IrisButton {
        id: key
        property string glyph
        property color under: Airisu.ground
        skinData: ({ under: key.under })
        implicitWidth: Math.round(32 * page.d)
        implicitHeight: Math.round(30 * page.d)
        MaterialSymbol {
            anchors.centerIn: parent
            text: key.glyph
            iconSize: Math.round(17 * page.d)
            fill: 0
            color: key.danger ? Airisu.danger : key.quiet ? Airisu.inkOn(key.under) : Airisu.ink
        }
    }
    // A workspace: a small die with its index leaning in it. The one you are on wears the chosen plate; one with windows
    // is the body's next coat; an empty one is sunk into the body.
    component Stop: Item {
        id: stop
        property string figure
        property bool chosen: false
        property bool occupied: false
        property bool hovered: false
        property real side: Math.round(24 * page.d)
        readonly property color face: stop.chosen ? IrisStyle.selectionFill : stop.occupied ? Airisu.groundRaised : Airisu.slot
        implicitWidth: stop.side
        implicitHeight: stop.side
        AKey {
            anchors.fill: parent
            lacquer: stop.face
            hovered: stop.hovered && !stop.chosen
        }
        AText {
            anchors.centerIn: parent
            voice: "figure"
            lean: Airisu.lean
            size: Math.round(stop.side * (stop.figure.length > 1 ? 0.42 : 0.52))
            text: stop.figure
            color: stop.chosen ? IrisStyle.selectionLabel : stop.occupied ? Airisu.ink : Airisu.inkThird
        }
    }

    // ── The head: a panel of time's lacquer, the part of the hour gone as its coat, the wallpaper seen through it.
    Item {
        id: head
        Layout.row: 0
        Layout.fillWidth: true
        implicitHeight: Math.round(122 * page.d)
        readonly property color pigment: Airisu.pigment("time")
        readonly property date now: DateTime.clock.date
        readonly property bool pictured: page.banner.length > 0
        readonly property color lacquer: Airisu.lacquerOf(head.pigment)
        readonly property color coat: Airisu.coat(head.pigment)
        readonly property color ink: Airisu.inkOver(head.lacquer, head.coat)
        readonly property color inkSecond: ColorUtils.mix(head.ink, head.lacquer, 0.74) // iris-literal: second tone on lacquer

        Image {
            id: wall
            width: head.width
            height: head.height
            visible: head.pictured
            // Kept once it has loaded, so a page that stops being live keeps its picture; read from the status it would
            // change, the source looped on itself.
            property bool kept: false
            onStatusChanged: if (wall.status === Image.Ready) wall.kept = true
            source: head.pictured && (page.live || wall.kept) ? page.banner : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: Math.max(1, Math.round(head.width * 1.25))
            asynchronous: true
        }
        ShaderEffectSource {
            id: grain
            visible: false
            width: head.width
            height: head.height
            sourceItem: head.pictured ? wall : null
            hideSource: true
            live: true
        }
        ALacquer {
            anchors.fill: parent
            texture: head.pictured && wall.status === Image.Ready ? grain : null
            glaze: IrisStyle.light ? 0.8 : 0.74 // iris-literal: how much of the picture the lacquer lets through
            lacquer: head.lacquer
            coat: head.coat
            share: 0
            travel: 0
        }

        Column {
            id: day
            x: Airisu.u(4)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Airisu.u(3)
            spacing: 0
            AText {
                size: IrisStyle.typeLabel
                font.weight: Font.Bold
                text: Translation.locale.toString(head.now, "dddd · d MMMM")
                color: head.inkSecond
            }
            AText {
                id: time
                voice: "figure"
                lean: Airisu.lean
                size: Math.round(2 * IrisStyle.typeDisplay)
                text: String(DateTime.timeDisplay)
                color: head.ink
            }
        }

        // The weather: the sky over the figure, its unit set small against it.
        Column {
            visible: page.weatherReady
            anchors.right: parent.right
            anchors.rightMargin: Airisu.u(4)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Airisu.u(3) + Math.round(time.size * 0.1)
            spacing: 0
            Row {
                anchors.right: parent.right
                spacing: Airisu.u(1)
                Mark {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
                    iconSize: IrisStyle.typeLabel
                    color: head.inkSecond
                }
                AText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, Math.round(130 * page.d))
                    size: IrisStyle.typeMeta
                    font.weight: Font.Bold
                    text: String(Weather.data?.description ?? "")
                    color: head.inkSecond
                }
            }
            Row {
                anchors.right: parent.right
                readonly property string raw: String(Weather.data?.temp ?? "")
                readonly property string figure: raw.replace(/°?[CF]$/, "")
                AText {
                    id: temperature
                    voice: "figure"
                    lean: Airisu.lean
                    size: IrisStyle.typeDisplay
                    text: parent.figure
                    color: head.ink
                }
                AText {
                    anchors.baseline: temperature.baseline
                    size: IrisStyle.typeLabel
                    font.weight: Font.Bold
                    text: parent.raw.slice(parent.figure.length)
                    color: head.ink
                }
            }
        }

        // What the page itself does: arrange its blocks, change the picture under the lacquer.
        Row {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Airisu.u(1.5)
            spacing: Airisu.u(1)
            Key {
                glyph: "edit"
                quiet: true
                under: head.lacquer
                Accessible.name: Translation.tr("Arrange this page")
                onClicked: {
                    if (page.island) page.island.pinned = true
                    GlobalStates.irisArrange = true
                }
            }
            Key {
                visible: head.pictured
                glyph: "wallpaper"
                quiet: true
                under: head.lacquer
                Accessible.name: Translation.tr("Change wallpaper")
                onClicked: {
                    GlobalStates.wallpaperSelectorTargetMonitor = page.island?.targetScreen?.name ?? ""
                    GlobalStates.wallpaperSelectorOpen = true
                }
            }
        }
    }

    // ── Profile: whose machine this is, the avatar cut as a disc; locking and the session are keys.
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
            // The pointer rings the disc in the accent.
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: avatarHover.hovered ? Airisu.strong : 0
                border.color: Airisu.seal
            }
        }
        Column {
            Layout.fillWidth: true
            spacing: 0
            AText {
                width: parent.width
                size: IrisStyle.typeFootnote
                font.weight: Font.Bold
                color: Airisu.inkSecond
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

    // ── The window in front, its app over its title; the workspaces are keys.
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
                size: IrisStyle.typeFootnote
                font.weight: Font.Bold
                color: Airisu.inkSecond
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
                    Stop {
                        id: number
                        figure: String(stop.modelData.idx)
                        chosen: stop.modelData.is_active
                        occupied: stop.occupied
                        hovered: stop.containsMouse
                    }
                }
            }
        }
    }

    // ── The forecast: the hours side by side, the hour at the head, the sky, the figure leaning; the hour that is now
    // stands on the chosen plate. No rules: the columns are their own air.
    Item {
        Layout.row: Math.max(1, page.rowOf("forecast"))
        Layout.fillWidth: true
        visible: page.shows("forecast")
        implicitHeight: Math.round(76 * page.d)
        Row {
            anchors.fill: parent
            Repeater {
                model: page.hours
                Item {
                    id: hour
                    required property var modelData
                    required property int index
                    readonly property bool now: hour.index === 0
                    readonly property color ink: hour.now ? IrisStyle.selectionLabel : Airisu.ink
                    width: Math.floor(parent.width / Math.max(1, page.hours.length))
                    height: parent.height
                    Accessible.name: hour.modelData.label + ", " + hour.modelData.temp
                    ALacquer {
                        anchors.fill: parent
                        visible: hour.now
                        lacquer: IrisStyle.selectionFill
                        moving: false
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: Airisu.u(1)
                        AText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            size: IrisStyle.typeCaption
                            font.weight: Font.Bold
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
                            lean: Airisu.lean
                            size: IrisStyle.typeLabel
                            text: String(hour.modelData.temp)
                            color: hour.ink
                        }
                    }
                }
            }
        }
    }

    // ── The next date: its day on a small panel, what it is and when; open tasks are a key beside it.
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
        readonly property bool sunday: agenda.when.getDay() === 0
        // The date on a small panel of time's lacquer (a Sunday's in the accent, as calendars here print it): the
        // weekday over the day, leaning.
        ALacquer {
            id: date
            Layout.preferredWidth: Math.round(46 * page.d)
            Layout.preferredHeight: Layout.preferredWidth
            readonly property color face: agenda.sunday ? Airisu.seal : Airisu.lacquerOf(Airisu.pigment("time"))
            lacquer: date.face
            moving: false
            Column {
                anchors.centerIn: parent
                spacing: -Math.round(2 * page.d)
                AText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    size: IrisStyle.typeCaption
                    font.weight: Font.Bold
                    text: Translation.locale.toString(agenda.when, "ddd").replace(/\./g, "")
                    color: Airisu.inkSecondOn(date.face)
                }
                AText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    voice: "figure"
                    lean: Airisu.lean
                    size: IrisStyle.typeTitle
                    text: agenda.when.getDate()
                    color: Airisu.inkOn(date.face)
                }
            }
        }
        Column {
            Layout.fillWidth: true
            spacing: 0
            AText {
                width: parent.width
                size: IrisStyle.typeFootnote
                font.weight: Font.Bold
                color: Airisu.inkSecond
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

    // ── Vitals: four columns, the name over the figure leaning with its unit, and under it its run in energy's
    // pigment. Past its warning a vital runs and prints in the caution's yamabuki.
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
                    { label: Translation.tr("Heat"), level: ResourceUsage.tempPercentage, value: ResourceUsage.maxTemp, unit: "°C", warn: ResourceUsage.tempWarningThreshold / 100 },
                    { label: Translation.tr("Disk"), level: ResourceUsage.diskUsedPercentage, value: Math.round(ResourceUsage.diskUsedPercentage * 100), unit: "%", warn: 0.9 }
                ]
                Item {
                    id: vital
                    required property var modelData
                    readonly property real level: Math.max(0, Math.min(1, Number(vital.modelData.level) || 0))
                    readonly property bool warned: vital.level >= vital.modelData.warn
                    readonly property color ink: vital.warned ? Airisu.caution : Airisu.ink
                    readonly property color pigment: Airisu.vivid(Airisu.pigment(vital.warned ? "caution" : "energy"))
                    width: Math.floor((parent.width - 3 * parent.spacing) / 4)
                    height: parent.height
                    Accessible.name: vital.modelData.label + ", " + vital.modelData.value + vital.modelData.unit
                    AText {
                        width: parent.width
                        size: IrisStyle.typeFootnote
                        font.weight: Font.Bold
                        color: Airisu.inkSecond
                        text: vital.modelData.label
                    }
                    Row {
                        y: Math.round(14 * page.d)
                        AText {
                            id: figure
                            voice: "figure"
                            lean: Airisu.lean
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
                    ARun {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.max(3, Math.round(5 * page.d))
                        value: vital.level
                        pigment: vital.pigment
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
